#!/usr/bin/env python3
"""Replay identical full states to separate mixed-trajectory drift from local error.

Preserve production routines; add only temporary diagnostic access and writes.
Use all 30 pre-step states from each retained single mixed-phase trajectory.
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
    parser.add_argument('--baseline', type=Path, default=Path('migration_work/reference_tv_regression'))
    parser.add_argument('--matlab', default='matlab')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve(); baseline = args.baseline.resolve()
    if work.exists() and any(work.iterdir()):
        raise SystemExit('Use a fresh workspace; existing evidence is preserved')
    config = json.loads((baseline/'configuration.json').read_text())
    production = {name: value for name, value in config['sources_sha256'].items()
                  if name.startswith(('matlab/active/', 'fortran/active/'))}
    for name, value in production.items():
        assert digest(root/name) == value, f'Stale production fixture: {name}'
    input_file = root/'data/input/manus208.nc'
    assert digest(input_file) == config['input_file_sha256']
    work.mkdir(parents=True, exist_ok=True)
    commands = []

    def run(command, label):
        command = list(map(str, command))
        commands.append({'argv': command, 'cwd': str(work)})
        with (work/(label+'.log')).open('w') as log:
            subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=600)

    fixture = baseline/'matlab_single_mixed_precip.nc'
    binary_file = baseline/'fortran_single_mixed_precip.bin'
    with netCDF4.Dataset(fixture) as ds:
        mh = np.asarray(ds['state'][:]).transpose(1,3,2,0)
        matlab_version = ds.getncattr('matlab_version')
    n = 8*801*3; header = 14*8*801+801+16
    binary = np.fromfile(binary_file, dtype='<f8')
    assert binary.size == header+30*n
    fh = np.concatenate([binary[:n],binary[header:]]).reshape((8,801,3,31),order='F')
    assert np.array_equal(mh[:,:,:,0],fh[:,:,:,0])
    states = np.concatenate([mh[:,:,:,:30],fh[:,:,:,:30]],axis=3)
    assert np.isfinite(states).all()
    states.flatten(order='F').astype('<f8').tofile(work/'states.bin')
    run([sys.executable,root/'tests/alignment/prepare.py',work], 'prepare')
    original = (work/'ace_module.F').read_text()
    module = original.replace('logical, save :: alignment_single=.false.',
        'logical, save :: alignment_single=.false.\npublic :: T,q,ql,qi,replay_unit\ninteger :: replay_unit')
    anchors = [('  ! call physics here', '  write(replay_unit) X(1:ncols,:,1:3)\n'),
               ('  ! implicit damping', '  write(replay_unit) X(1:ncols,:,1:3)\n')]
    for anchor, insertion in anchors:
        assert module.count(anchor) == 1
        module = module.replace(anchor,insertion+anchor)
    (work/'ace_module.F').write_text(module)
    (work/'replay_access.patch').write_text(''.join(difflib.unified_diff(
        original.splitlines(True),module.splitlines(True),fromfile='prepared/ace_module.F',tofile='replay/ace_module.F')))
    local = (root/'matlab/active/ace.m').read_text()
    local = local[local.index('function X = timeint('):]
    (work/'replay_mixed.m').write_text((root/'tests/alignment/matlab_mixed_replay.txt').read_text()+'\n'+local)
    flags = ['-O2','-ffree-form','-fdefault-real-8','-fdefault-double-8','-ffree-line-length-none']
    include = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    rpath = '-Wl,-rpath,'+subprocess.check_output(['nf-config','--prefix'],text=True).strip()+'/lib'
    run(['gfortran',*flags,*include,'-c','ace_module.F'],'module_build')
    run(['gfortran',*flags,*include,root/'tests/alignment/fortran_mixed_replay.f90',
         'ace_module.o','ace_input.o',*libs,rpath,'-o','replay.exe'],'driver_build')
    quote = lambda p: str(p).replace("'", "''")
    statement = f"addpath('{quote(work)}'); replay_mixed('{quote(root)}','{quote(work)}');"
    run([args.matlab,'-batch',statement],'matlab_replay')
    run([work/'replay.exe',baseline/'fortran_base_init.bin',input_file,
         work/'states.bin',work/'matlab_thermo.bin',work/'fortran.bin'],'fortran_replay')
    def read(name):
        data = np.fromfile(work/name,dtype='<f8')
        assert data.size == 8*801*24*60
        data = data.reshape((8,801,24,60),order='F')
        assert np.isfinite(data).all(), name
        return data
    m = read('matlab.bin'); f = read('fortran.bin')
    # Independent replay must reproduce each implementation's own retained next state.
    assert np.array_equal(m[:,:,21:24,:30],mh[:,:,:,1:])
    assert np.array_equal(f[:,:,21:24,30:],fh[:,:,:,1:])
    slices = {'raw_tendency':(0,3), 'thermo':(3,7), 'native_sink':(7,9),
              'native_forward':(9,11), 'shared_cache_sink':(11,13),
              'shared_cache_forward':(13,15), 'dynamics':(15,18),
              'post_precip_clip':(18,21), 'final':(21,24)}
    names = {'raw_tendency':['theta_e','qt','MF'], 'thermo':['T','qv','ql','qi'],
             'native_sink':['theta_e','qt'], 'native_forward':['base','perturbed'],
             'shared_cache_sink':['theta_e','qt'], 'shared_cache_forward':['base','perturbed'],
             'dynamics':['theta_e','qt','MF'], 'post_precip_clip':['theta_e','qt','MF'],
             'final':['theta_e','qt','MF']}
    report = {'parent_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
              'production_sources_sha256':production,'input_sha256':digest(input_file),
              'matlab_fixture_version':matlab_version,'commands':commands,
              'scope':'Identical-state one-step replay; native and identical-thermodynamic-cache sink probes; production unchanged',
              'own_matlab_next_states_exact':True,'own_fortran_next_states_exact':True,
              'tolerance_status':'No acceptance tolerance or denominator floor',
              'blocks':slices,'sources':{},'trajectory':{}}
    for j,name in enumerate(['theta_e','qt','MF']):
        report['trajectory'][name] = metrics(mh[:,:,j,:],fh[:,:,j,:])
    for source,begin in [('matlab',0),('fortran',30)]:
        selection = slice(begin,begin+30)
        result = {'times_seconds':list(range(0,120,4)), 'all_samples':{},'cloud_levels':{},
                  'components':{},'level110':[]}
        for name,(lo,hi) in slices.items():
            result['all_samples'][name]=metrics(m[:,:,lo:hi,selection],f[:,:,lo:hi,selection])
            result['cloud_levels'][name]=metrics(m[0,90:110,lo:hi,selection],f[0,90:110,lo:hi,selection])
            result['components'][name]={label:{
                'full_domain':metrics(m[:,:,lo+j,selection],f[:,:,lo+j,selection]),
                'cloud_levels':metrics(m[0,90:110,lo+j,selection],f[0,90:110,lo+j,selection])}
                for j,label in enumerate(names[name])}
        result['native_phase_presence_mismatches'] = int(np.count_nonzero(
            (m[:,:,5:7,selection]>0)!=(f[:,:,5:7,selection]>0)))
        # Algebraic counterfactual on the identical cache, not a model update:
        # retain the actual Fortran dqt and replace only its fd numerator.
        numerator=m[:,:,14,selection]-m[:,:,13,selection]
        counterfactual=f[:,:,12,selection]*numerator/1.e-8
        result['shared_cache_matlab_numerator_counterfactual']={
            'theta_e_sink':metrics(m[:,:,11,selection],counterfactual),
            'scope':'Algebraic reconstruction only; not an integrated variant'}
        # Signed step decomposition. Differences of sequential diagnostics telescope;
        # the last step's prior trajectory difference must be accounted for separately.
        for t in range(30):
            s=begin+t
            def delta(variable):
                return float(m[0,109,variable,s]-f[0,109,variable,s])
            result['level110'].append({'time_seconds':4*t,
                'dynamics_difference_K':delta(15),
                'precip_clip_added_difference_K':delta(18)-delta(15),
                'damping_added_difference_K':delta(21)-delta(18),
                'final_difference_K':delta(21),
                'native_theta_e_sink_difference_K_per_s':delta(7),
                'shared_cache_theta_e_sink_difference_K_per_s':delta(11),
                'native_theta_e_fd_numerator_difference_K':delta(10)-delta(9),
                'shared_cache_theta_e_fd_numerator_difference_K':delta(14)-delta(13),
                'native_thermo_matlab':m[0,109,3:7,s].tolist(),
                'native_thermo_fortran':f[0,109,3:7,s].tolist(),
                'forward_matlab':m[0,109,9:11,s].tolist(),
                'forward_fortran':f[0,109,9:11,s].tolist(),
                'native_qt_sink_matlab':float(m[0,109,8,s]),
                'native_qt_sink_fortran':float(f[0,109,8,s])})
        report['sources'][source]=result
    report['level110_own_trajectory_process_decomposition']=[]
    for t in range(30):
        before=float(mh[0,109,0,t]-fh[0,109,0,t])
        dynamics=float(m[0,109,15,t]-f[0,109,15,30+t])
        after=float(m[0,109,18,t]-f[0,109,18,30+t])
        final=float(m[0,109,21,t]-f[0,109,21,30+t])
        assert final==float(mh[0,109,0,t+1]-fh[0,109,0,t+1])
        report['level110_own_trajectory_process_decomposition'].append({
            'time_seconds':4*t,'incoming_difference_K':before,
            'dynamics_added_difference_K':dynamics-before,
            'precip_clip_added_difference_K':after-dynamics,
            'damping_added_difference_K':final-after,'outgoing_difference_K':final})
    for name,value in production.items():
        assert digest(root/name)==value, 'Production source changed during replay'
    files=[fixture,binary_file,baseline/'fortran_base_init.bin']
    report['fixture_sha256']={str(p.relative_to(root)):digest(p) for p in files}
    report['tool_versions']={'gfortran':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
                             'netcdf_fortran':subprocess.check_output(['nf-config','--version'],text=True).strip()}
    report['artifact_sha256']={str(p.relative_to(work)):digest(p) for p in sorted(work.rglob('*'))
                              if p.is_file() and p.suffix in ['.F','.m','.patch','.bin','.exe']}
    report['runner_sha256']=digest(Path(__file__))
    report['replay_tools_sha256']={str(p.relative_to(root)):digest(p) for p in
        [root/'tests/alignment/fortran_mixed_replay.f90',root/'tests/alignment/matlab_mixed_replay.txt']}
    (work/'results.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    for name,result in report['sources'].items():
        print(name,json.dumps(result['level110'][-1],indent=2))


if __name__ == '__main__':
    main()
