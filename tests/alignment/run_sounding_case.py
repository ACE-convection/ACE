#!/usr/bin/env python3
"""Run a single active ACE with precipitation disabled in temporary sources."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

import netCDF4
import numpy as np
from compare import metrics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--input', type=Path, default=Path('data/input/goamazon314.nc'))
    parser.add_argument('--duration', type=int, default=10800)
    parser.add_argument('--output-step', type=int, default=60)
    parser.add_argument('--matlab', default='matlab')
    parser.add_argument('--saturated-bubble', action='store_true',
                        help='Enable original MATLAB bubble: levels 11:51, +1 K, saturated, no initial condensate')
    parser.add_argument('--analyze-existing', action='store_true',
                        help='Analyze preserved integration outputs without rerunning models')
    args = parser.parse_args()
    if args.duration <= 0 or args.output_step <= 0 or args.duration % args.output_step or args.output_step % 4:
        parser.error('Duration must be a positive output-step multiple; output-step must be a positive 4-second multiple')
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve(); input_file = args.input.resolve()
    if not args.analyze_existing and work.exists() and any(work.iterdir()):
        raise SystemExit('Use a fresh directory; existing evidence is preserved')
    with netCDF4.Dataset(input_file) as ds:
        case = ds.case_name; profile = int(ds.profile_index)
        heights = np.asarray(ds['zm'][:])
    work.mkdir(parents=True, exist_ok=True)
    commands = []

    def run(command, label):
        command = list(map(str, command))
        commands.append({'argv': command, 'cwd': str(work)})
        started = time.monotonic()
        with (work/(label+'.log')).open('w') as log:
            subprocess.run(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=14400)
        print(label, 'completed in', round(time.monotonic()-started, 1), 's', flush=True)

    if not args.analyze_existing:
        shutil.copyfile(Path(__file__), work/'runner_executed.py')
        run([sys.executable, root/'tests/alignment/prepare.py', work], 'prepare')
    manifest = json.loads((work/'configuration.json').read_text())
    if not args.analyze_existing:
        manifest['input_file_sha256'] = digest(input_file)
        manifest['input_file'] = str(input_file)
        manifest['scope'] = 'single ACE 1; precipitation disabled in temporary sources; actual active numerical routines'
        (work/'configuration.json').write_text(json.dumps(manifest, indent=2)+'\n')
    if not args.analyze_existing:
        original = (work/'ace_module.F').read_text()
        call = '  call precip_sinks(ncols,nz,X(1:ncols,1:nz,10),K1(:,:,1),K1(:,:,2)) ! simplified precipitation'
        update = '  X(1:ncols,:,1:2) = X(1:ncols,:,1:2) +  K1(:,:,1:2) * dt'
        assert original.count(call) == original.count(update) == 1
        changed = original.replace(call, '  ! Precipitation disabled for this experiment').replace(update, '')
        (work/'ace_module.F').write_text(changed)
        (work/'fortran_no_precip.diff').write_text(''.join(difflib.unified_diff(
            original.splitlines(True), changed.splitlines(True), fromfile='prepared/ace_module.F', tofile='no_precip/ace_module.F')))
        source = (root/'matlab/active/ace.m').read_text()
        initialization = source
        if args.saturated_bubble:
            for before, after in [('BL = [];', 'BL = 11:51;'), ('dTbl = 0;', 'dTbl = 1;')]:
                assert initialization.count(before) == 1
                initialization = initialization.replace(before, after)
        (work/'initialize_sounding.m').write_text(initialization)
        (work/'bubble_initialization.diff').write_text(''.join(difflib.unified_diff(
            source.splitlines(True), initialization.splitlines(True),
            fromfile='active/ace.m', tofile='experiment/initialize_sounding.m')))
        original_local = source[source.index('function X = timeint('):]
        call = '      yn = ApplyPrecip(yn,dt);'
        assert original_local.count(call) == 1
        local = original_local.replace(call, '      % Precipitation disabled for this experiment')
        local = local.replace('      yn = ImDamp(yn);',
            "      yn = ImDamp(yn);\n      assert(all(isfinite(yn)),'Nonfinite trajectory');", 1)
        (work/'matlab_no_precip.diff').write_text(''.join(difflib.unified_diff(
            original_local.splitlines(True), local.splitlines(True), fromfile='active/local_functions', tofile='no_precip/local_functions')))
        header = (root/'tests/alignment/matlab_sounding_case.txt').read_text()
        (work/'run_sounding_case.m').write_text(header+'\n'+local)
        flags = ['-O2', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8', '-ffree-line-length-none']
        include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
        libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
        rpath = '-Wl,-rpath,'+subprocess.check_output(['nf-config', '--prefix'], text=True).strip()+'/lib'
        run(['gfortran', *flags, *include, '-c', 'ace_module.F'], 'module_build')
        for source_name, executable in [('fortran/active/src/test.F', 'base_model.exe'),
                                       ('tests/alignment/fortran_sounding_case.f90', 'case.exe')]:
            run(['gfortran', *flags, *include, root/source_name, 'ace_module.o', 'ace_input.o',
                 *libs, rpath, '-o', executable], executable+'_build')
        run([work/'base_model.exe', '--input', input_file, '--validate-input', work/'fortran_init.bin'], 'base_init')
        quote = lambda p: str(p).replace("'", "''")
        statement = (f"addpath('{quote(work)}'); run_sounding_case('{quote(root)}',"
                     f"'{quote(work)}','{quote(input_file)}',{args.duration},{args.output_step});")
        fortran_command = [work/'case.exe', work/'fortran_init.bin', input_file,
                           work/'fortran.bin', args.duration, args.output_step]
        if args.saturated_bubble:
            initializer = statement.replace(f'{args.output_step});', f'{args.output_step},true);')
            run([args.matlab, '-batch', initializer], 'bubble_initialization')
            fortran_command.append(work/'initial_override.bin')
        with ThreadPoolExecutor(max_workers=2) as pool:
            jobs = [pool.submit(run, [args.matlab, '-batch', statement], 'matlab'),
                    pool.submit(run, fortran_command, 'fortran')]
            for job in jobs:
                job.result()
        (work/'commands.json').write_text(json.dumps(commands, indent=2)+'\n')
    elif (work/'commands.json').exists():
        commands = json.loads((work/'commands.json').read_text())
    times = np.arange(0, args.duration+1, args.output_step)
    f = np.fromfile(work/'fortran.bin', dtype='<f8').reshape((8, 801, 3, len(times)), order='F').transpose(3, 2, 1, 0)
    with netCDF4.Dataset(work/'matlab.nc') as ds:
        assert ds['state'].dimensions == ('time', 'ace', 'variable', 'level')
        m = np.asarray(ds['state'][:]).transpose(0, 2, 3, 1)
        matlab_version = ds.matlab_version
        assert np.array_equal(ds['time'][:], times)
        assert np.array_equal(ds['zm'][:], heights)
        assert int(ds.profile_index) == profile
    assert f.shape == m.shape and np.isfinite(f).all() and np.isfinite(m).all()
    np.savez_compressed(work/'mf.npz', time_seconds=times, height_m=heights,
                        matlab=m[:, 2, :, 0], fortran=f[:, 2, :, 0])
    report = {'case': case, 'profile_index': profile, 'duration_seconds': args.duration,
              'dt_seconds': 4, 'output_step_seconds': args.output_step, 'precipitation': 'disabled',
              'single_policy': 'ACE 1 tendency active; 8 ACE geometry/PMB retained; original damping retained',
              'pulse': 'ACE 1: 0.03*sin(pi*z/1000) kg m-2 s-1 at 0-1000 m',
              'mf_diffusion': 'disabled as in active defaults',
              'bubble': {'enabled': args.saturated_bubble,
                         'levels_one_based': [11, 51] if args.saturated_bubble else [],
                         'delta_T_K': 1 if args.saturated_bubble else 0,
                         'saturation': 'original eval_qsat; no initial condensate',
                         'coordinate_policy': 'original MATLAB T_zm and p_mf; applied to prognostic theta_e/qt slots',
                         'fortran_initialization': 'common MATLAB-exported state' if args.saturated_bubble else 'native'},
              'finite_outputs': True, 'input_file': str(input_file), 'input_sha256': digest(input_file),
              'baseline_commit': manifest['baseline_commit'], 'production_sources_sha256': manifest['sources_sha256'],
              'commands': commands, 'matlab_version': matlab_version,
              'gfortran_version': subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0],
              'comparison_status': 'Descriptive errors only; no byte equality or acceptance tolerance required',
              'mf': metrics(m[:, 2, :, 0], f[:, 2, :, 0]),
              'initial_state': {field: metrics(m[0, j], f[0, j]) for j, field in enumerate(['theta_e','qt','MF'])},
              'ranges': {name: {'mf_min': float(a[:, 2, :, 0].min()), 'mf_max': float(a[:, 2, :, 0].max()),
                                'qt_min': float(a[:, 1].min()), 'qt_max': float(a[:, 1].max())}
                         for name, a in [('matlab', m), ('fortran', f)]}}
    for name, value in manifest['sources_sha256'].items():
        assert digest(root/name) == value, 'Source changed during experiment: '+name
    report['experiment_sources_sha256'] = {str(p.relative_to(root)): digest(p) for p in
        [Path(__file__), root/'tests/alignment/matlab_sounding_case.txt', root/'tests/alignment/fortran_sounding_case.f90']}
    if (work/'runner_executed.py').exists():
        report['original_runner_sha256'] = digest(work/'runner_executed.py')
        report['execution_record'] = 'Original runner preserved as runner_executed.py; see generated sources, patches and model logs'
    report['analysis_only'] = args.analyze_existing
    report['artifacts_sha256'] = {str(p.relative_to(work)): digest(p) for p in work.iterdir()
                                if p.is_file() and p.suffix in ['.F', '.m', '.py', '.diff', '.bin', '.nc', '.npz', '.exe']}
    (work/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')
    print('Complete:', work, flush=True)


if __name__ == '__main__':
    main()
