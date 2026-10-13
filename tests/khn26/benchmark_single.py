#!/usr/bin/env python3
"""Time 900 simulated seconds with validated serial Fortran and frozen MATLAB settings.

Runs languages sequentially; does not set MATLAB computational threads or affinity.
Rebuilds serial production from current sources and checks the frozen ten-step gate.
"""
import argparse
import difflib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from datetime import datetime, timezone

import numpy as np
from single import ROOT, compare, digest

BASE = ROOT/'migration_work/khn26_single_3h'
SERIAL = ROOT/'migration_work/khn26_single_production_3h'
PARALLEL = ROOT/'migration_work/khn26_single_openmp6_3h'


def write(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2)+'\n');temp.replace(path)


def main(work):
    cfg = json.loads((SERIAL/'timing_configuration.json').read_text())
    gate = json.loads((SERIAL/'debug_gate_results.json').read_text())
    if cfg['openmp'] or not gate['binary_identical'] or not gate['finite_states_nonnegative_qt']:
        raise ValueError('Expected a validated serial production build')
    interpolation = ROOT/'fortran/src/ace_interpolation.F'
    for path, expected in cfg['sha256'].items():
        # PCHIP binary search was committed after the preserved serial build.
        # Rebuild this source below, and check model identity before timing.
        if Path(path) in (interpolation, ROOT/'tests/khn26/serial_timing.py'):
            continue
        if digest(path) != expected:
            raise ValueError('Serial build provenance changed: '+path)
    case = json.loads((BASE/'single_case.json').read_text())
    original = (BASE/'single_main.m').read_text()
    if digest(BASE/'single_main.m') != case['generated_sha256']['single_main.m']:
        raise ValueError('Frozen MATLAB source changed')
    case['duration_seconds'] = 900
    steps = int(case['duration_seconds']/case['dt_seconds'])
    assert steps == 225
    work.mkdir(parents=True,exist_ok=False)
    build = work/'build';build.mkdir()
    flags = cfg['production_flags']
    inc = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    sources = [ROOT/'fortran/src'/name for name in ('ace_input.F','ace_interpolation.F','microphy_p3.F')]
    sources += [SERIAL/'ace_module_single.F', SERIAL/'timed_driver.F']
    compile_commands = []
    objects = []
    for source, name in zip(sources, ('ace_input','ace_interpolation','microphy_p3','ace_module','test')):
        obj = build/(name+'.o');objects.append(obj)
        command = ['gfortran',*flags,*inc,'-c',str(source),'-o',str(obj)]
        compile_commands.append(command)
        with (build/(name+'.compile.log')).open('x') as log:
            subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    executable = build/'ace_model.exe'
    command = ['gfortran',*flags,*map(str,objects),*libs,'-o',str(executable)]
    compile_commands.append(command)
    subprocess.run(command,cwd=build,check=True)
    linked = subprocess.check_output(['ldd',str(executable)],text=True)
    if 'libgomp' in linked or 'libiomp' in linked:
        raise ValueError('Serial executable links OpenMP')
    matlab = original.replace('tspan = 0:60:10800;', 'tspan = 0:60:900;')
    if matlab == original:
        raise ValueError('Expected exactly the frozen three-hour duration')
    matlab = matlab.replace(str(BASE),str(work))
    (work/'single_main.m').write_text(matlab)
    (work/'matlab_duration_paths.diff').write_text(''.join(difflib.unified_diff(
        original.splitlines(True),matlab.splitlines(True),fromfile=str(BASE/'single_main.m'),tofile=str(work/'single_main.m'))))
    launcher = (BASE/'full_launch.m').read_text().replace(str(BASE),str(work))
    # Query the natural cap, without setting it. Preserve the original batch invocation.
    launcher = "fprintf('Natural MATLAB computational thread cap = %d\\n',maxNumCompThreads);\n" + launcher
    (work/'full_launch.m').write_text(launcher)
    case['generated_sha256'] = {'single_main.m':digest(work/'single_main.m')}
    case['compiled_commands'] = compile_commands
    write(work/'single_case.json',case)
    commands = {
        'fortran':[str(executable),'--input',case['input'],'--physics',case['physics'],
                   '--dt',str(case['dt_seconds']),'--intervals','15',
                   '--output',str(work/'full_fortran.dat'),
                   '--state-output',str(work/'full_fortran_states.bin')],
        'matlab':['matlab','-batch',f"run('{work}/full_launch.m')"]}
    paths = [executable,SERIAL/'timed_driver.F',SERIAL/'ace_module_single.F',
             BASE/'single_main.m',BASE/'full_launch.m',Path(case['input']),
             work/'single_main.m',work/'full_launch.m',*sources,*objects,Path(__file__).resolve()]
    hashes = {str(p):digest(p) for p in paths}
    manifest = {'case':case,'steps':steps,'commands':commands,'sha256':hashes,'compiled_commands':compile_commands,
                'fortran_flags':cfg['production_flags'],'fortran_linked_libraries':linked,
                'execution_order':['fortran','matlab'],
                'matlab_settings':'Original matlab -batch launcher; no thread setter, no affinity pinning.',
                'timing_scope':'Fortran: ace_driver wall timers; MATLAB: original timeint tic/toc including loop/reporting. Initialization and postprocessing excluded; process wall separately recorded.',
                'environment':{k:os.environ.get(k) for k in ('OMP_NUM_THREADS','OMP_THREAD_LIMIT','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS','MATLAB_PREFDIR')},
                'cpu_affinity':sorted(os.sched_getaffinity(0))}
    write(work/'benchmark_configuration.json',manifest)
    gate_command = [str(executable),'--input',case['input'],'--physics',case['physics'],
                    '--dt',str(case['dt_seconds']),'--steps','10','--state-output',str(work/'production_gate.bin')]
    write(work/'benchmark_status.json',{'state':'serial_gate_running'})
    with (work/'production_gate.log').open('x') as log:
        subprocess.run(gate_command,cwd=work,stdout=log,stderr=subprocess.STDOUT,check=True)
    if (work/'production_gate.bin').read_bytes() != (SERIAL/'production_gate.bin').read_bytes():
        raise ValueError('Current serial build differs from frozen ten-step gate')
    write(work/'gate_results.json',{'serial_ten_step_binary_identical':True,'command':gate_command,
                                  'sha256':digest(work/'production_gate.bin')})
    process_wall = {}
    for name in ('fortran','matlab'):
        for path, expected in hashes.items():
            if digest(path) != expected:raise ValueError('Provenance changed: '+path)
        start = time.monotonic()
        with (work/f'full_{name}.log').open('x') as log:
            child = subprocess.Popen(commands[name],cwd=work,stdin=subprocess.DEVNULL,
                                     stdout=log,stderr=subprocess.STDOUT)
            while child.poll() is None:
                write(work/'benchmark_status.json',{'state':name+'_running',
                    'updated_utc':datetime.now(timezone.utc).isoformat(),
                    'driver_pid':child.pid,'elapsed_process_wall_seconds':time.monotonic()-start,
                    'completed_process_wall_seconds':process_wall})
                try:child.wait(timeout=20)
                except subprocess.TimeoutExpired:pass
        process_wall[name] = time.monotonic()-start
        if child.returncode != 0:
            write(work/'benchmark_status.json',{'state':'failed','language':name,'exit_code':child.returncode})
            raise RuntimeError(f'{name} exited {child.returncode}; inspect log')
    summarize(work, process_wall)


def summarize(work, process_wall, matlab_log='full_matlab.log'):
    manifest = json.loads((work/'benchmark_configuration.json').read_text())
    case = manifest['case'];steps = manifest['steps']
    result = compare(work,'full')
    # Verify the 15-minute run reproduces each language's completed three-hour prefix.
    prefix_identity = {}
    for name, reference in [('matlab',BASE),('fortran',PARALLEL)]:
        path = work/f'full_{name}_states.bin'
        with (reference/path.name).open('rb') as stream:
            prefix_identity[name] = path.read_bytes() == stream.read(path.stat().st_size)
    if not all(prefix_identity.values()):
        raise ValueError('15-minute state stream differs from validated three-hour prefix')
    texts = {'fortran':(work/'full_fortran.log').read_text(),
             'matlab':(work/matlab_log).read_text()}
    integration = {
        'fortran':float(re.search(r'integration wall seconds =\s*([\d.Ee+\-]+)',texts['fortran'])[1]),
        'matlab':float(re.search(r'ODE solver time = ([0-9.]+) sec',texts['matlab'])[1])}
    output = {'simulated_seconds':900,'dt_seconds':case['dt_seconds'],'steps':steps,
              'saved_states':result['saved_states'],'integration_wall_seconds':integration,
              'wall_seconds_per_step':{name:value/steps for name,value in integration.items()},
              'process_wall_seconds':process_wall,
              'matlab_over_fortran_ratio':integration['matlab']/integration['fortran'],
              'matlab_natural_thread_cap':int(re.search(r'Natural MATLAB computational thread cap = (\d+)',texts['matlab'])[1]),
              'three_hour_prefix_binary_identical':prefix_identity,
              'max_abs_error_MF_theta_e_qt':result['max_abs_error'],
              'finite_saved_states':result['finite_saved_states'],'nonnegative_saved_qt':result['nonnegative_saved_qt'],
              'exit_codes':{'fortran':0,'matlab':0},'timing_scope':manifest['timing_scope'],
              'limitation':'One evolving 225-step run per language, sequential on shared hardware; no isolated-host or repeated-run speed guarantee.',
              'artifacts_sha256':result['artifacts_sha256']}
    write(work/'benchmark_results.json',output)
    write(work/'benchmark_status.json',{'state':'completed','updated_utc':datetime.now(timezone.utc).isoformat()})
    print(json.dumps(output,indent=2),flush=True)


def resume_matlab(work):
    """Preserve completed Fortran timing after a sandbox license-network failure."""
    manifest = json.loads((work/'benchmark_configuration.json').read_text())
    for path, expected in manifest['sha256'].items():
        if Path(path) != Path(__file__).resolve() and digest(path) != expected:
            raise ValueError('Provenance changed: '+path)
    if not (work/'full_fortran.log').read_text().count('integration wall seconds =') == 1:
        raise ValueError('Fortran integration did not complete')
    if (work/'full_matlab_states.bin').exists():
        raise ValueError('Preserve existing MATLAB states; use a fresh run instead')
    write(work/'recovery_configuration.json',{
        'reason':'Sandbox MATLAB license checkout could not connect to license server (-96).',
        'current_script_sha256':digest(Path(__file__).resolve()),
        'command':manifest['commands']['matlab'],
        'fortran_process_wall_seconds':None,
        'note':'Original supervisor exited before persisting Fortran process wall time; integration timer retained.'})
    started = time.monotonic()
    with (work/'resumed_matlab.log').open('x') as log:
        child = subprocess.Popen(manifest['commands']['matlab'],cwd=work,stdin=subprocess.DEVNULL,
                                 stdout=log,stderr=subprocess.STDOUT)
        while child.poll() is None:
            write(work/'benchmark_status.json',{'state':'matlab_running',
                'updated_utc':datetime.now(timezone.utc).isoformat(),
                'driver_pid':child.pid,'elapsed_process_wall_seconds':time.monotonic()-started})
            try:child.wait(timeout=20)
            except subprocess.TimeoutExpired:pass
    if child.returncode != 0:
        write(work/'benchmark_status.json',{'state':'failed','language':'matlab','exit_code':child.returncode})
        raise RuntimeError('Resumed MATLAB failed; inspect resumed_matlab.log')
    summarize(work,{'fortran':None,'matlab':time.monotonic()-started},'resumed_matlab.log')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--resume-matlab',action='store_true')
    args = parser.parse_args()
    if args.resume_matlab:resume_matlab(args.work.resolve())
    else:main(args.work.resolve())
