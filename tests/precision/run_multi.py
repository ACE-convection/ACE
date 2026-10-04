#!/usr/bin/env python3
"""Run real32 or real64 multiACE against the preserved MATLAB outer-pulse case."""
import argparse
import difflib
import hashlib
import json
import re
from pathlib import Path
import subprocess
import time

import numpy as np


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--reference', type=Path, default=Path('migration_work/manus208_multi_outer_pulse_12h'))
    parser.add_argument('--duration', type=int, default=43200)
    parser.add_argument('--precision', type=int, choices=[32, 64], default=32)
    parser.add_argument('--analyze-existing', action='store_true')
    args = parser.parse_args()
    if not 60 <= args.duration <= 43200 or args.duration % 60:
        parser.error('Duration must be a multiple of 60 seconds in 60..43200')
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve(); reference = args.reference.resolve()
    accepted = json.loads((root/'docs/manus208_multi_outer_pulse_12h.json').read_text())
    input_file = root/'data/input/manus208.nc'
    seed_file = reference/'initial_override.bin'
    for file in [seed_file, reference/'mf_all_aces.npz']:
        assert digest(file) == accepted['artifacts_sha256'][file.name], 'Reference identity mismatch'
    assert digest(input_file) == accepted['input_sha256']
    assert accepted['duration_seconds'] == 43200 and accepted['ace_mode'] == 'multi'
    seed = np.fromfile(seed_file, dtype='<f8').reshape((3, 801, 8))
    assert np.isfinite(seed).all() and np.all(seed[2, :, :7] == 0)
    assert np.any(seed[2, :, 7] != 0)
    if not args.analyze_existing:
        if work.exists() and any(work.iterdir()):
            parser.error('Use a fresh output directory to preserve evidence')
        work.mkdir(parents=True, exist_ok=True)
        (work/'runner_executed.py').write_text(Path(__file__).read_text())
        report = {
            'case': 'manus', 'profile_index': 208, 'duration_seconds': args.duration,
            'dt_seconds': 4, 'output_step_seconds': 60, 'ace_mode': 'multi',
            'precipitation': 'enabled', 'bubble': {'enabled': False},
            'fortran_label': 'Fortran ('+('single' if args.precision == 32 else 'double')+' precision)',
            'precision_bits': args.precision,
            'input_sha256': digest(input_file), 'seed_sha256': digest(seed_file),
            'reference_mf_sha256': digest(reference/'mf_all_aces.npz'),
            'reference_directory': str(reference),
            'git_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
            'compiler': subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0],
            'sources_sha256': {str(p.relative_to(root)): digest(p) for p in
                               [root/'fortran/src/ace_module.F', root/'fortran/src/ace_input.F',
                                root/'fortran/src/test.F', root/'tests/precision/fortran_case.f90', Path(__file__)]},
            'scope': 'All eight ACEs, original ACE 8 outer pulse, no bubble or sustained forcing; '
                     'native precipitation, full geometry/PMB, original damping, MF diffusion off. '
                     f'Default-real{args.precision} prognostics/tendencies with existing binary64 PMB/input reads. No P3.',
            'commands': [], 'status': 'running',
        }

        def save():
            (work/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')

        def run(command, label, timeout=7200):
            command = list(map(str, command))
            report['commands'].append({'argv': command, 'cwd': str(work)})
            save()
            started = time.monotonic()
            with (work/(label+'.log')).open('w') as log:
                subprocess.run(command, cwd=work, check=True, stdout=log, stderr=subprocess.STDOUT,
                               timeout=timeout)
            elapsed = time.monotonic()-started
            print(label, 'completed in', round(elapsed, 1), 's', flush=True)
            return elapsed

        original = (root/'fortran/src/ace_module.F').read_text()
        source = original.replace('! defien operator',
            'public :: set_probe_single\nlogical :: probe_single=.false.\n! defien operator', 1)
        source = source.replace('contains\n', '''contains
subroutine set_probe_single(enabled)
logical, intent(in) :: enabled
probe_single=enabled
end subroutine
''', 1)
        assert source.count('!dXdt(2:ncols,:,:)=0.') == 1
        source = source.replace('!dXdt(2:ncols,:,:)=0.', 'if (probe_single) dXdt(2:ncols,:,:)=0.')
        anchor = '  call precip_sinks(ncols,nz,X(1:ncols,1:nz,10),K1(:,:,1),K1(:,:,2)) ! simplified precipitation'
        assert source.count(anchor) == 1
        source = source.replace(anchor, anchor+'''
  if (any(K1(:,:,2)>0.)) error stop 'Positive precipitation water tendency'
  write(97,*) t+dt,sum(-K1(:,:,2)*dt),maxval(-K1(:,:,2)*dt),minval(-K1(:,:,2)*dt)
''')
        (work/'ace_module.F').write_text(source)
        (work/'instrumentation.diff').write_text(''.join(difflib.unified_diff(
            original.splitlines(True), source.splitlines(True), fromfile='production', tofile='multiACE-test')))
        for file,target in [('fortran/src/ace_input.F','ace_input.F'), ('fortran/src/test.F','test.F'),
                            ('tests/precision/fortran_case.f90','driver.f90')]:
            (work/target).write_bytes((root/file).read_bytes())
        flags = ['-O2', '-ffree-form', '-ffree-line-length-none', '-fcheck=all,no-array-temps',
                 '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
        if args.precision == 64:
            flags += ['-fdefault-real-8', '-fdefault-double-8']
        include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
        libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
        prefix = subprocess.check_output(['nf-config', '--prefix'], text=True).strip()
        libs += ['-Wl,-rpath,'+prefix+'/lib']
        try:
            run(['gfortran', *flags, *include, '-c', 'ace_input.F'], 'input_build')
            run(['gfortran', *flags, *include, '-c', 'ace_module.F'], 'module_build')
            for file,target in [('test.F','base.exe'), ('driver.f90','case.exe')]:
                run(['gfortran', *flags, *include, file, 'ace_module.o', 'ace_input.o', *libs, '-o', target], target+'_build')
            run([work/'base.exe', '--input', input_file, '--validate-input', work/'init.bin'], 'init')
            report['integration_wall_seconds'] = run(
                [work/'case.exe', work/'init.bin', input_file, work/'state.bin', seed_file,
                 args.duration, 'multi'], 'integration')
            assert re.search(r'real bits\s+'+str(args.precision)+r'\b', (work/'integration.log').read_text())
            report['status'] = 'integration completed'
        except Exception as exc:
            report['status'] = 'failed'; report['error'] = str(exc)
            raise
        finally:
            save()
    else:
        report = json.loads((work/'results.json').read_text())
        assert report['duration_seconds'] == args.duration and report['ace_mode'] == 'multi'
        assert report['precision_bits'] == args.precision
        assert report['input_sha256'] == digest(input_file) and report['seed_sha256'] == digest(seed_file)
        assert report['reference_mf_sha256'] == digest(reference/'mf_all_aces.npz')
    ntime = args.duration//60+1
    dtype = '<f4' if args.precision == 32 else '<f8'
    state = np.fromfile(work/'state.bin', dtype=dtype).reshape((ntime, 3, 801, 8))
    assert np.isfinite(state).all() and state[:, 1].min() >= 0
    np.testing.assert_array_equal(state[0], seed.astype(dtype))
    sinks = np.loadtxt(work/'fort.97')
    assert sinks.shape == (args.duration//4, 4) and np.isfinite(sinks).all()
    assert np.all(sinks[:, 1:] >= 0)
    if args.duration == 43200:
        assert sinks[:, 1].sum() > 0
    with np.load(reference/'mf_all_aces.npz') as data:
        times = data['time_seconds'][:ntime]; height = data['height_m']; matlab = data['matlab'][:ntime]
    assert np.array_equal(times, np.arange(0, args.duration+1, 60))
    fortran = state[:, 2]
    np.savez_compressed(work/'mf_all_aces.npz', time_seconds=times, height_m=height,
                        matlab=matlab, fortran=fortran)
    report['execution_checks'] = {'saved_times': ntime, 'finite': True, 'qt_min': float(state[:, 1].min()),
                                  f'initial_state_equals_binary{args.precision}_seed': True,
                                  'positive_precipitation_steps': int(np.sum(sinks[:, 1]>0))}
    report['per_ace'] = []
    for i in range(8):
        error = fortran[:, :, i].astype(np.float64)-matlab[:, :, i]
        peak = np.unravel_index(np.abs(fortran[:, :, i]).argmax(), (ntime, 801))
        report['per_ace'].append({'ace': i+1, 'matlab_peak_abs_mf': float(np.abs(matlab[:, :, i]).max()),
                                 'fortran_peak_abs_mf': float(np.abs(fortran[:, :, i]).max()),
                                 'fortran_peak_seconds': int(times[peak[0]]), 'fortran_peak_height_m': float(height[peak[1]]),
                                 'mf_max_abs_difference': float(np.abs(error).max()),
                                 'mf_rms_difference': float(np.sqrt(np.mean(error**2)))})
    report['artifact_sha256'] = {p.name: digest(p) for p in
                                [work/'state.bin', work/'mf_all_aces.npz', work/'fort.97', work/'ace_module.F']}
    report['status'] = 'passed execution checks; MF visual comparison ready; no scientific tolerance imposed'
    (work/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')
    print(json.dumps(report['execution_checks'], indent=2), flush=True)


if __name__ == '__main__':
    main()
