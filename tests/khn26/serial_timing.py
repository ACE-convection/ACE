#!/usr/bin/env python3
"""Time serial/optional OpenMP packed singleACE against frozen MATLAB outputs."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

import numpy as np

from single import ROOT, compare, digest

BASE = ROOT / 'migration_work/khn26_single_3h'
PACKED = ROOT / 'migration_work/khn26_packed_model'


def write(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)


def prepare(work, threads=1):
    case = json.loads((BASE / 'single_case.json').read_text())
    report = json.loads((PACKED / 'validation_results.json').read_text())
    source = ROOT / 'fortran/src/ace_module.F'
    if digest(source) != report['source_sha256']:
        raise ValueError('Production module differs from the validated packed module')
    expected = source.read_text().replace('!dXdt(2:ncols,:,:)=0.', 'dXdt(2:ncols,:,:)=0.')
    if (PACKED / 'ace_module_single.F').read_text() != expected:
        raise ValueError('Frozen packed singleACE source differs')
    if digest(case['input']) != case['input_sha256']:
        raise ValueError('Shared input changed')
    for name in ('single_main.m', 'single_driver.F'):
        if digest(BASE / name) != case['generated_sha256'][name]:
            raise ValueError('Baseline source changed: ' + name)
    n, z, count = 101, 401, case['duration_seconds'] // 60 + 1
    if (BASE / 'full_matlab_states.bin').stat().st_size != count * n * z * 3 * 8:
        raise ValueError('MATLAB trajectory is incomplete')
    log = (BASE / 'full_matlab.log').read_text()
    matches = re.findall(r'ODE solver time = ([0-9.]+) sec', log)
    if len(matches) != 1:
        raise ValueError('Expected one completed MATLAB integration timing')
    work.mkdir(parents=True, exist_ok=False)
    driver = (BASE / 'single_driver.F').read_text()
    driver = driver.replace('use iso_fortran_env, only: real64',
                            'use iso_fortran_env, only: real64, int64', 1)
    driver = driver.replace('integer :: intervals\n',
                            'integer :: intervals\ninteger(int64) :: clock_start, clock_end, clock_rate\n'
                            'real(real64) :: integration_wall=0.0_real64\n', 1)
    call = '  call ace_driver(ncols,nz,n_weno,n_prog,X,Ref,A,B,ts,te,dt,forcing,precipitation_enabled)'
    if driver.count(call) != 2:
        raise ValueError('Unexpected driver integration sites')
    driver = driver.replace(call, '  call system_clock(clock_start,clock_rate)\n' + call +
                            '\n  call system_clock(clock_end)\n'
                            '  integration_wall=integration_wall+real(clock_end-clock_start,real64)/real(clock_rate,real64)')
    driver = driver.replace("write(*,*) 'time cost =',finish-start",
                            "write(*,*) 'time cost =',finish-start\n"
                            "write(*,*) 'integration wall seconds =',integration_wall", 1)
    (work / 'timed_driver.F').write_text(driver)
    (work / 'ace_module_single.F').write_text(expected)
    flags = ['-cpp', '-ffree-form', '-ffree-line-length-none', '-O2',
             '-fdefault-real-8', '-fdefault-double-8']
    if threads > 1:
        flags.append('-fopenmp')
    debug_flags = ['-g', '-fcheck=all,no-array-temps',
                   '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
    inc = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    commands, products = [], []
    sources = [ROOT / 'fortran/src' / (name + '.F')
               for name in ('ace_input', 'ace_interpolation', 'microphy_p3')]
    sources += [work / 'ace_module_single.F', work / 'timed_driver.F']
    for label, options in [('debug', flags + debug_flags), ('build', flags)]:
        build = work / label; build.mkdir()
        objects = []
        for src, name in zip(sources, ('ace_input', 'ace_interpolation', 'microphy_p3', 'ace_module', 'test')):
            obj = build / (name + '.o'); objects.append(obj)
            command = ['gfortran', *options, *inc, '-c', str(src), '-o', str(obj)]
            commands.append(command)
            with (build / (name + '.compile.log')).open('w') as log:
                subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
        command = ['gfortran', *options, *map(str, objects), *libs, '-o', 'ace_model.exe']
        commands.append(command); subprocess.run(command, cwd=build, check=True)
        linked = subprocess.check_output(['ldd', str(build / 'ace_model.exe')], text=True)
        has_openmp = 'libgomp' in linked or 'libiomp' in linked
        if has_openmp != (threads > 1):
            raise ValueError('OpenMP runtime linkage differs from requested mode')
        (build / 'linked_libraries.txt').write_text(linked)
        products += [build / 'ace_model.exe', *objects]
    for name in ('full_matlab_states.bin', 'full_matlab.nc'):
        (work / name).symlink_to(BASE / name)
    (work / 'single_case.json').write_text(json.dumps(case, indent=2) + '\n')
    paths = [source, ROOT / 'matlab/ace.m', BASE / 'single_main.m', BASE / 'single_driver.F',
             BASE / 'full_matlab_states.bin', BASE / 'full_matlab.log', BASE / 'full_matlab.nc',
             Path(case['input']), *sources, *products,
             Path(__file__).resolve()]
    serial_reference = ROOT / 'migration_work/khn26_single_production_3h/production_gate.bin'
    if threads > 1:
        if not serial_reference.exists():
            raise ValueError('Completed serial ten-step reference is required for OpenMP timing')
        paths.append(serial_reference)
    write(work / 'timing_configuration.json', {
        'case': case, 'openmp': threads > 1, 'threads': threads, 'compiled_commands': commands,
        'serial_gate_reference': str(serial_reference) if threads > 1 else None,
        'debug_gate_steps': 10, 'production_flags': flags, 'debug_flags': debug_flags,
        'sha256': {str(p): digest(p) for p in paths},
        'matlab_integration_wall_seconds': float(matches[0]),
        'matlab_reference': str(BASE),
        'timing_scope': 'Fortran: sum of wall times around ace_driver calls; MATLAB: existing timeint tic/toc. '
                        'Fortran full process wall includes initialization and output; MATLAB process wall unavailable. '
                        'Historical MATLAB run and new serial Fortran run share a host, without load isolation.'})


def run(work):
    cfg = json.loads((work / 'timing_configuration.json').read_text())
    case = cfg['case']; child = None
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS=str(cfg['threads']), OMP_THREAD_LIMIT=str(cfg['threads']),
               OMP_DYNAMIC='FALSE', OMP_PROC_BIND='close', OMP_PLACES='cores',
               OMP_DISPLAY_ENV='TRUE')

    def verify():
        for name, expected in cfg['sha256'].items():
            if digest(name) != expected:
                raise ValueError('Provenance changed: ' + name)

    def status(state, **extra):
        write(work / 'timing_status.json', {'updated_utc': datetime.now(timezone.utc).isoformat(),
              'state': state, 'supervisor_pid': os.getpid(),
              'openmp': cfg['openmp'], 'threads': cfg['threads'], **extra})

    try:
        verify()
        gate_commands, gate_wall = {}, {}
        for label, folder in [('debug', 'debug'), ('production', 'build')]:
            command = [str(work / folder / 'ace_model.exe'), '--input', case['input'],
                       '--physics', case['physics'], '--dt', str(case['dt_seconds']),
                       '--steps', str(cfg['debug_gate_steps']),
                       '--state-output', str(work / (label + '_gate.bin'))]
            gate_commands[label] = command
            started = time.monotonic()
            with (work / (label + '_gate.log')).open('x') as log:
                child = subprocess.Popen(command, cwd=work, env=env, stdin=subprocess.DEVNULL,
                                         stdout=log, stderr=subprocess.STDOUT)
                while child.poll() is None:
                    status(label + '_gate_running', driver_pid=child.pid,
                           gate_steps=cfg['debug_gate_steps'], elapsed_wall_seconds=time.monotonic()-started)
                    try: child.wait(timeout=30)
                    except subprocess.TimeoutExpired: pass
            gate_wall[label] = time.monotonic()-started
            if child.returncode != 0:
                raise RuntimeError(f'{label} 10-step gate exited {child.returncode}')
        debug = (work / 'debug_gate.bin').read_bytes()
        production = (work / 'production_gate.bin').read_bytes()
        expected_bytes = 12 + (11 * 102 * 401 * 3 + 401) * 8
        if len(debug) != expected_bytes or debug != production:
            raise ValueError('Debug/production 10-step stream incomplete or not byte-identical')
        frozen = (BASE / 'smoke_fortran_states.bin').read_bytes()
        if debug[:len(frozen)] != frozen:
            raise ValueError('10-step gate differs from frozen legacy initial/single-step state')
        if cfg['serial_gate_reference'] and debug != Path(cfg['serial_gate_reference']).read_bytes():
            raise ValueError('OpenMP ten-step output differs from the preserved serial output')
        if not np.array_equal(np.frombuffer(debug[:12], '<i4'), [101, 401, 3]):
            raise ValueError('Invalid gate state header')
        for index in range(11):
            offset = 12 + 8 * (index * 102 * 401 * 3 + (401 if index else 0))
            state = np.frombuffer(debug, '<f8', count=102*401*3, offset=offset).reshape((102,401,3), order='F')
            if not np.isfinite(state).all() or np.any(state[:,:,2] < 0):
                raise ValueError('Nonfinite state or negative qt in 10-step gate')
        write(work / 'debug_gate_results.json', {
            'steps':10, 'saved_states':11, 'debug_exit_code':0, 'production_exit_code':0,
            'binary_identical':True, 'frozen_single_step_identical':True,
            'openmp':cfg['openmp'], 'threads':cfg['threads'],
            'serial_ten_step_identical': True if cfg['serial_gate_reference'] else None,
            'finite_states_nonnegative_qt':True, 'wall_seconds':gate_wall,
            'commands':gate_commands, 'debug_sha256':digest(work/'debug_gate.bin'),
            'production_sha256':digest(work/'production_gate.bin')})
        verify()
        command = [str(work / 'build/ace_model.exe'), '--input', case['input'],
                   '--physics', case['physics'], '--dt', str(case['dt_seconds']),
                   '--intervals', str(case['duration_seconds'] // 60),
                   '--output', str(work / 'full_fortran.dat'),
                   '--state-output', str(work / 'full_fortran_states.bin')]
        start = time.monotonic()
        with (work / 'full_fortran.log').open('x') as log:
            child = subprocess.Popen(command, cwd=work, env=env, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT)
            while child.poll() is None:
                path = work / 'full_fortran_states.bin'
                size = path.stat().st_size if path.exists() else 0
                records = max(0, (size - 12 - 401 * 8) // (102 * 401 * 3 * 8))
                status('running', driver_pid=child.pid, elapsed_wall_seconds=time.monotonic()-start,
                       complete_saved_states=records, simulated_seconds=max(0, records-1)*60)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
            process_wall = time.monotonic() - start
        if child.returncode != 0:
            raise RuntimeError(f'Fortran driver exited {child.returncode}')
        status('comparing', driver_exit_code=0)
        verify()
        result = compare(work, 'full')
        text = (work / 'full_fortran.log').read_text()
        integration = float(re.search(r'integration wall seconds =\s*([\d.Ee+\-]+)', text)[1])
        hours = case['duration_seconds'] / 3600
        m = cfg['matlab_integration_wall_seconds'] / hours
        f = integration / hours
        write(work / 'efficiency_results.json', {
            'simulated_hours': hours, 'fortran_openmp': cfg['openmp'], 'fortran_threads': cfg['threads'],
            'production_flags': cfg['production_flags'], 'debug_gate_steps': cfg['debug_gate_steps'],
            'fortran_integration_wall_seconds': integration,
            'fortran_process_wall_seconds': process_wall,
            'matlab_integration_wall_seconds': cfg['matlab_integration_wall_seconds'],
            'wall_seconds_per_simulated_hour': {'fortran': f, 'matlab': m},
            'wall_minutes_per_simulated_hour': {'fortran': f/60, 'matlab': m/60},
            'matlab_over_fortran_integration_wall_ratio': m/f,
            'driver_exit_code': child.returncode, 'saved_states': result['saved_states'],
            'max_abs_error_MF_theta_e_qt': result['max_abs_error'],
            'command': command, 'timing_scope': cfg['timing_scope'],
            'artifacts_sha256': result['artifacts_sha256']})
        status('completed_pending_scientific_review', driver_exit_code=0,
               efficiency_report=str(work / 'efficiency_results.json'))
    except BaseException as exc:
        if child is not None and child.poll() is None:
            child.terminate(); child.wait()
        status('failed', error=str(exc))
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--threads', type=int, default=1,
                        help='1 builds serial; greater values enable OpenMP only at existing PMB directives')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--launch', action='store_true')
    group.add_argument('--run', action='store_true')
    args = parser.parse_args(); work = args.work.resolve()
    if args.threads < 1:
        parser.error('--threads must be positive')
    if args.run:
        run(work)
    else:
        prepare(work, args.threads)
        with (work / 'supervisor.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), str(work), '--run'],
                                     cwd=ROOT, stdin=subprocess.DEVNULL, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
        (work / 'supervisor.pid').write_text(str(child.pid) + '\n')
        print(json.dumps({'supervisor_pid': child.pid, 'work': str(work)}))
