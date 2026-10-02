#!/usr/bin/env python3
"""Paired temporary Fortran runs isolating the reference-Tv behavior.

Reuse the reviewed mixed-phase MATLAB fixture; never edit production sources.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import netCDF4
import numpy as np
from compare import metrics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, default=Path('migration_work/mixed_precipitation_run'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve()
    baseline = args.baseline.resolve()
    if work.exists() and any(work.iterdir()):
        raise SystemExit('Use a fresh workspace; existing results are preserved')
    config = json.loads((baseline/'configuration.json').read_text())
    # Refuse stale production fixtures. Test tools may evolve independently.
    production = {name: value for name, value in config['sources_sha256'].items()
                  if name.startswith(('matlab/', 'fortran/'))}
    for name, value in production.items():
        assert digest(root/name) == value, f'Stale fixture source: {name}'
    input_file = root/'data/input/manus208.nc'
    assert digest(input_file) == config['input_file_sha256']
    work.mkdir(parents=True, exist_ok=True)
    commands = []

    def run(command, cwd, label):
        command = list(map(str, command))
        commands.append({'argv': command, 'cwd': str(cwd)})
        with (cwd/(label+'.log')).open('w') as log:
            subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=600)

    run([sys.executable, root/'tests/alignment/prepare.py', work], work, 'prepare')
    prepared = (work/'ace_module.F').read_text()
    driver = (root/'tests/alignment/fortran_case.f90').read_text()
    # Correct the diagnostic to use the actual reinverted tendency reference.
    anchor = 'call set_alignment_single(trim(mode)==\'single\')'
    recompute = '''do k=1,nz
 call inv_theta_e(X(9,k,1),X(9,k,2),X(9,k,10),temperature(1,k),vapor(1,k),liquid(1,k),ice(1,k))
 Tv0(k)=temperature(1,k)*(1.+0.607789855072462*vapor(1,k)-liquid(1,k)-ice(1,k))
enddo
'''
    assert driver.count(anchor) == 1
    control_driver = driver.replace(anchor, recompute+anchor)
    flags = ['-O2', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8', '-ffree-line-length-none']
    include = subprocess.check_output(['nf-config','--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'], text=True).split()
    rpath = '-Wl,-rpath,'+str(Path(subprocess.check_output(['nf-config','--prefix'],text=True).strip())/'lib')
    variant = prepared.replace('logical, save :: alignment_single=.false.',
        'logical, save :: alignment_single=.false.\nreal, allocatable, save :: diagnostic_reference_tv(:)\npublic :: set_reference_tv')
    variant = variant.replace('contains\n', '''contains
subroutine set_reference_tv(values)
real, intent(in) :: values(:)
diagnostic_reference_tv=values
end subroutine
''', 1)
    target = '  Tv0(k) = T0(k) * ( 1. + 0.607789855072462 * q0(k) - ql0(k) - qi0(k) )'
    assert variant.count(target) == 1
    variant = variant.replace(target, target+'\n  if (allocated(diagnostic_reference_tv)) Tv0(k)=diagnostic_reference_tv(k)')
    probe_driver = control_driver.replace('use ace_input', 'use ace_module, only: set_reference_tv\nuse ace_input')
    probe_driver = probe_driver.replace(anchor, '''call get_command_argument(6,override_file)
open(newunit=u,file=trim(override_file),access='stream',form='unformatted',status='old')
read(u) Tv0
close(u)
call set_reference_tv(Tv0)
'''+anchor)
    (work/'reference_tv_module.patch').write_text(''.join(difflib.unified_diff(
        prepared.splitlines(True),variant.splitlines(True),fromfile='control/ace_module.F',tofile='shared_tv/ace_module.F')))
    report = {'baseline_commit': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
              'scope': 'Temporary reference Tv substitution only; unchanged MATLAB fixture, equations, inverse, RK, precipitation, damping and production sources.',
              'production_sources_sha256': production, 'input_sha256': digest(input_file),
              'no_acceptance_tolerance': True, 'cases': {}, 'fixture_sha256': {}}
    outputs = {}
    for label, module, program in [('control',prepared,control_driver),('shared_tv',variant,probe_driver)]:
        directory = work/label
        directory.mkdir()
        (directory/'ace_module.F').write_text(module)
        (directory/'fortran_case.f90').write_text(program)
        (directory/'driver.patch').write_text(''.join(difflib.unified_diff(
            driver.splitlines(True),program.splitlines(True),fromfile='test/fortran_case.f90',tofile=label+'/fortran_case.f90')))
        run(['gfortran',*flags,*include,'-c',root/'fortran/src/ace_input.F'],directory,'input_build')
        run(['gfortran',*flags,*include,'-c','ace_module.F'],directory,'module_build')
        run(['gfortran',*flags,*include,'fortran_case.f90','ace_module.o','ace_input.o',*libs,rpath,'-o','case.exe'],directory,'driver_build')
        for mode in ['single','multi']:
            case = mode+'_mixed_precip'
            fixture = baseline/('matlab_'+case+'.nc')
            with netCDF4.Dataset(fixture) as ds:
                tv = np.asarray(ds['reference_tv'][:],dtype='<f8')
            tv.tofile(directory/(case+'_tv.bin'))
            output = directory/(case+'.bin')
            run([directory/'case.exe',baseline/'fortran_base_init.bin',input_file,output,mode,
                 baseline/('initial_'+case+'.bin'),directory/(case+'_tv.bin')],directory,case)
            outputs[label,case] = np.fromfile(output,dtype='<f8')
    state_size = 8*801*3
    header_size = 2*state_size+8*801*8+801+16
    def history(binary):
        assert binary.size == header_size+30*state_size
        return np.concatenate([binary[:state_size],binary[header_size:]]).reshape((8,801,3,31),order='F')
    for mode in ['single','multi']:
        case = mode+'_mixed_precip'
        fixture = baseline/('matlab_'+case+'.nc')
        with netCDF4.Dataset(fixture) as ds:
            matlab = np.asarray(ds['state'][:]).transpose(1,3,2,0)
            mtv = np.asarray(ds['reference_tv'][:])
            matlab_version = ds.getncattr('matlab_version')
            mr = np.asarray(ds['raw_tendency'][:]).transpose(0,2,1)
            mb = np.asarray(ds['initial_buoyancy'][:])
        control = outputs['control',case]
        changed = outputs['shared_tv',case]
        ch = history(control); sh = history(changed)
        old = history(np.fromfile(baseline/('fortran_'+case+'.bin'),dtype='<f8'))
        assert matlab.shape == ch.shape
        assert np.array_equal(ch,old), 'Fresh control must reproduce retained trajectory exactly'
        assert np.array_equal(ch[:,:,:,0],sh[:,:,:,0]), 'Initial state changed'
        assert np.isfinite(ch).all() and np.isfinite(sh).all()
        def diagnostic(binary, number):
            start = 2*state_size+number*8*801
            return binary[start:start+8*801].reshape((8,801),order='F')
        tv_offset = 2*state_size+8*801*8
        result = {'control_reproduces_retained_trajectory_exactly': True,
                  'initial_state_identical': True, 'all_trajectory_values_finite': True,
                  'qt_min': {'control': float(ch[:,:,1,:].min()),'shared_tv':float(sh[:,:,1,:].min())},
                  'reference_tv': metrics(mtv,control[tv_offset:tv_offset+801]),
                  'shared_reference_tv': metrics(mtv,changed[tv_offset:tv_offset+801]),
                  'initial_buoyancy_control': metrics(mb,diagnostic(control,4)),
                  'initial_buoyancy_shared_tv': metrics(mb,diagnostic(changed,4)),
                  'raw_tendency': {}, 'trajectory': {}}
        for j,name in enumerate(['theta_e','qt','MF']):
            result['raw_tendency'][name] = {
                'control': metrics(mr[:,:,j],control[state_size:2*state_size].reshape((8,801,3),order='F')[:,:,j]),
                'shared_tv': metrics(mr[:,:,j],changed[state_size:2*state_size].reshape((8,801,3),order='F')[:,:,j])}
            result['trajectory'][name] = {
                'matlab_vs_control_all_samples': metrics(matlab[:,:,j,:],ch[:,:,j,:]),
                'matlab_vs_shared_tv_all_samples': metrics(matlab[:,:,j,:],sh[:,:,j,:]),
                'control_vs_shared_tv_all_samples': metrics(ch[:,:,j,:],sh[:,:,j,:]),
                'snapshots': {str(t): {'control':metrics(matlab[:,:,j,t//4],ch[:,:,j,t//4]),
                                     'shared_tv':metrics(matlab[:,:,j,t//4],sh[:,:,j,t//4])} for t in [0,4,60,120]}}
        report['cases'][case] = result
        for file in [fixture,baseline/'fortran_base_init.bin',baseline/('initial_'+case+'.bin'),baseline/('fortran_'+case+'.bin')]:
            report['fixture_sha256'][str(file.relative_to(root))] = digest(file)
    for name, value in production.items():
        assert digest(root/name) == value, 'Production source changed during diagnostic'
    report['commands'] = commands
    report['tool_versions'] = {'gfortran':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
                               'netcdf_fortran':subprocess.check_output(['nf-config','--version'],text=True).strip(),
                               'matlab_fixture':matlab_version}
    report['artifact_sha256'] = {str(p.relative_to(work)):digest(p) for p in sorted(work.rglob('*'))
                                  if p.is_file() and p.suffix in ['.F','.f90','.patch','.bin','.exe']}
    report['runner_sha256'] = digest(Path(__file__))
    (work/'results.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    for case,row in report['cases'].items():
        print(case, {name: {key: value['max_abs'] for key,value in detail.items() if key.endswith('all_samples')}
                     for name,detail in row['trajectory'].items()})


if __name__ == '__main__':
    main()
