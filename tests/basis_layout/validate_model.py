#!/usr/bin/env python3
"""Validate the production packed PMB against frozen pre-change model outputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

import numpy as np
from netCDF4 import Dataset

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def run(work, baseline, threads):
    work.mkdir(parents=True, exist_ok=False)
    case = json.loads((baseline / 'single_case.json').read_text())
    commands, timings, checks = [], {}, []
    flags = ['-cpp', '-ffree-form', '-ffree-line-length-none', '-O2', '-g',
             '-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow',
             '-fbacktrace', '-fdefault-real-8', '-fdefault-double-8']
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    source = ROOT / 'fortran/src/ace_module.F'
    text = source.read_text()
    (work / 'ace_module_single.F').write_text(text.replace('!dXdt(2:ncols,:,:)=0.', 'dXdt(2:ncols,:,:)=0.'))
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS=str(threads), OMP_PROC_BIND='close', OMP_PLACES='cores')

    def execute(command, cwd, label):
        command = [str(v) for v in command]
        commands.append(command)
        print(label, flush=True)
        start = time.monotonic()
        with (work / (label + '.log')).open('w') as log:
            subprocess.run(command, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        timings[label] = time.monotonic() - start

    for name, parallel, single in [('serial', False, True), ('openmp', True, True), ('multi', True, False)]:
        build = work / name
        build.mkdir()
        base = baseline / ('build_single' if single else 'build64')
        for module in ('ace_input', 'ace_interpolation', 'microphy_p3'):
            (build / (module + '.mod')).write_bytes((base / (module + '.mod')).read_bytes())
        options = flags + (['-fopenmp'] if parallel else [])
        execute(['gfortran', *options, *include, '-c', work / 'ace_module_single.F' if single else source,
                 '-o', 'ace_module.o'], build, name + '_compile')
        execute(['gfortran', *options, base / 'test.o', 'ace_module.o',
                 *[baseline / 'build64' / (m + '.o') for m in ('ace_input', 'ace_interpolation', 'microphy_p3')],
                 *libs, '-o', 'ace_model.exe'], build, name + '_link')

    # Compile compatibility at default real32; the PMB reduction remains real64.
    build = work / 'real32'; build.mkdir()
    for module in ('ace_input', 'ace_interpolation', 'microphy_p3'):
        (build / (module + '.mod')).write_bytes((baseline / 'build32' / (module + '.mod')).read_bytes())
    execute(['gfortran', *[f for f in flags if f not in ('-fdefault-real-8', '-fdefault-double-8')],
             '-fopenmp', *include, '-c', source, '-o', 'ace_module.o'], build, 'real32_compile')

    def model(exe, target, intervals=None):
        command = [exe, '--input', case['input'], '--physics', 'none', '--dt', str(case['dt_seconds']),
                   '--state-output', work / target]
        command += ['--steps', '1'] if intervals is None else ['--intervals', str(intervals), '--output', work / 'trajectory.dat']
        execute(command, work, Path(target).stem)

    def identical(a, b, label, prefix=None):
        with a.open('rb') as first, b.open('rb') as second:
            remaining = prefix
            while remaining is None or remaining > 0:
                size = 8 * 1024 * 1024 if remaining is None else min(8 * 1024 * 1024, remaining)
                x, y = first.read(size), second.read(size)
                if x != y or (remaining is not None and len(x) != size):
                    raise ValueError('Binary agreement failed: ' + label)
                if not x: break
                if remaining is not None: remaining -= size
        checks.append({'check': label, 'binary_identical': True, 'bytes': prefix or a.stat().st_size})

    for name in ('serial', 'openmp'):
        model(work / name / 'ace_model.exe', name + '_smoke.bin')
        identical(work / (name + '_smoke.bin'), baseline / 'smoke_fortran_states.bin', name + '_single_step')
    model(baseline / 'build64/ace_model.exe', 'legacy_multi.bin')
    model(work / 'multi/ace_model.exe', 'packed_multi.bin')
    identical(work / 'legacy_multi.bin', work / 'packed_multi.bin', 'all_101_responses_single_step')

    n, z = 101, 401
    record = (n + 1) * z * 3 * 8
    old = baseline / 'full_fortran_states.bin'
    count = (old.stat().st_size - 12 - z * 8) // record
    if count < 2: raise ValueError('No complete trajectory interval')
    model(work / 'openmp/ace_model.exe', 'packed_trajectory.bin', intervals=count - 1)
    prefix = 12 + z * 8 + count * record
    if (work / 'packed_trajectory.bin').stat().st_size != prefix:
        raise ValueError('Incomplete packed trajectory')
    identical(work / 'packed_trajectory.bin', old, 'all_complete_legacy_trajectory_records', prefix)
    analysis = analyze_saved(work, baseline)
    report = {'source_sha256': sha(source), 'baseline': str(baseline), 'threads': threads,
              'compiled_commands': commands, 'timings_seconds': timings, 'checks': checks,
              'trajectory_saved_states': count, 'trajectory_duration_seconds': (count - 1) * 60,
              **analysis,
              'input_sha256_recorded_at_preparation': case['input_sha256'],
              'reused_object_sha256': {str(p): sha(p) for p in (baseline / 'build64').glob('*.o')},
              'limits': 'SingleACE prefix and all-response single step; not a completed three-hour trajectory.',
              'baseline_binary_sha256': sha(baseline / 'build_single/ace_model.exe'),
              'legacy_stream_sha256': sha(old), 'packed_stream_sha256': sha(work / 'packed_trajectory.bin')}
    (work / 'validation_results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)



def analyze_saved(work, baseline):
    case = json.loads((baseline / 'single_case.json').read_text())
    n, z = 101, 401
    record = (n + 1) * z * 3 * 8
    count = ((work / 'packed_trajectory.bin').stat().st_size - 12 - z * 8) // record
    errors = []
    means = []
    with Dataset(case['input']) as data:
        areas = np.asarray(data['ace_area'][:]); weights = areas / areas.sum()
    with (work / 'packed_trajectory.bin').open('rb') as stream:
        stream.seek(12)
        for index in range(count):
            state = np.fromfile(stream, '<f8', count=(n + 1) * z * 3).reshape((n + 1, z, 3), order='F')[:n]
            if index == 0: stream.seek(z * 8, 1)
            matlab = np.memmap(baseline / 'full_matlab_states.bin', '<f8', mode='r',
                               offset=index * n * z * 3 * 8, shape=(n * z * 3,)).reshape((n, z, 3), order='F')
            if not np.isfinite(state).all() or state[:, :, 2].min() < 0:
                raise ValueError('Invalid trajectory state')
            if index == 0:
                inactive_scalars = state[1:, :, 1:3].copy()
            else:
                mean = float(np.max(abs(np.sum(state[:, :, 0] * weights[:, None], axis=0))))
                means.append(mean)
                if case['mean_mf_zero'] and (mean > 1e-10 or np.max(abs(state[1:, :, 0] - state[1:2, :, 0])) > 1e-10):
                    raise ValueError('Mean MF or inactive compensation policy changed')
                if np.any(np.max(abs(state[1:, :, 1:3] - inactive_scalars), axis=(0, 1)) > [1e-7, 1e-11]):
                    raise ValueError('Inactive scalar fields changed')
            error = np.max(abs(state - matlab), axis=(0, 1))
            if np.any(error > [1e-9, 1e-7, 1e-11]): raise ValueError('MATLAB trajectory agreement failed')
            errors.append(error.tolist())
    return {'max_abs_vs_matlab_MF_theta_e_qt': np.max(errors, axis=0).tolist(),
            'poststep_area_mean_MF_max': max(means),
            'finite_states_nonnegative_qt_inactive_policy_passed': True}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'migration_work/khn26_single_3h')
    parser.add_argument('--threads', type=int, default=8)
    parser.add_argument('--analyze', action='store_true', help='Repeat saved-state numerical diagnostics only')
    args = parser.parse_args()
    if args.analyze:
        path = args.work / 'validation_results.json'
        report = json.loads(path.read_text())
        report.update(analyze_saved(args.work, args.baseline))
        report['analysis_source_sha256'] = sha(Path(__file__))
        path.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
    else:
        run(args.work.resolve(), args.baseline.resolve(), args.threads)
