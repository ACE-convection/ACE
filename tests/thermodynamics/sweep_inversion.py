#!/usr/bin/env python3
"""Compare actual scalar MATLAB/Fortran inverse routines on shared binary64 inputs.

Full grid: 2101 pressures x 401 theta_e x 1001 qt = 843,343,501 cases.
Test-only instrumentation records branches, iterations, complex/nonfinite outcomes
and stops a branch at max_iterations. Production source and APIs are not changed
by the instrumentation. A capped call is an unfinished inversion, never a pass.
MATLAB retains its original complex arithmetic. No acceptance tolerance is set.
"""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def instrument(work, limit):
    source = (ROOT / 'matlab/util_thermodynamics/inv_T_from_theta_e.m').read_text()
    modified = source.replace('function [T, q, ql, qi] = inv_T_from_theta_e(',
        'function [T,q,ql,qi,branch,n1,n2,status,initial_failure] = reference_inversion(', 1)
    modified = modified.replace('T0 = 273.1636783445389;',
        'T=NaN; q=NaN; ql=NaN; qi=NaN; branch=0; n1=0; n2=0; status=0; initial_failure=0;\nT0 = 273.1636783445389;', 1)
    guard = f'\n  if COUNTER >= {limit}, status=1; return; end\n  COUNTER=COUNTER+1;'
    old = 'while abs(dT)>ABS_TOL && isreal(dT) && ~isnan(T)'
    assert modified.count(old) == 1
    modified = modified.replace(old, old + guard.replace('COUNTER', 'n1'), 1)
    old = 'while max(abs(dT))>ABS_TOL'
    assert modified.count(old) == 2
    modified = modified.replace(old, old + guard.replace('COUNTER', 'n2'))
    modified = modified.replace('\nbsmeter = ', '\ninitial_failure = ~isreal(dT) || isnan(T);\nbsmeter = ', 1)
    modified = modified.replace('if G0>GT0 && G0>HT0 % Liquid-only',
        'if G0>GT0 && G0>HT0 % Liquid-only\n    branch=1;', 1)
    modified = modified.replace('elseif G0<GT0 && G0<HT0 % Ice-only',
        'elseif G0<GT0 && G0<HT0 % Ice-only\n    branch=2;', 1)
    modified = modified.replace('else % Liquid-ice co-existing',
        'else % Liquid-ice co-existing\n    branch=3;', 1)
    modified += '''
if ~isreal([T,q,ql,qi])
  status=3;
elseif any(~isfinite([T,q,ql,qi])) || (branch~=3 && (~isfinite(dT) || abs(dT)>ABS_TOL))
  status=2;
end
'''
    (work / 'reference_inversion.m').write_text(modified)
    # Diagnose the no-condensate reference state to apply a common test-only
    # exclusion before either full inversion is called.
    start = source.index('if nargin==3')
    stop = source.index('q = qt;', start)
    diagnostic = source[start:stop]
    diagnostic = diagnostic.replace('dT = 9999;', 'diagnostic_iterations=0;\ndT = 9999;', 1)
    diagnostic = diagnostic.replace('while abs(dT)>ABS_TOL && isreal(dT) && ~isnan(T)',
        'while abs(dT)>ABS_TOL && isreal(dT) && ~isnan(T)\n'
        f'  if diagnostic_iterations>={limit}, es=NaN; return; end\n'
        '  diagnostic_iterations=diagnostic_iterations+1;', 1)
    (work / 'diagnostic_reference.m').write_text(
        'function [T,es] = diagnostic_reference(theta_e,qt,p,ABS_TOL)\n' + diagnostic + '''
es=NaN;
if isreal(T) && isfinite(T) && T>0
  if T>=T0, es=eval_es(T); else, es=eval_esi(T); end
end
end
''')
    (work / 'matlab_instrumentation.diff').write_text(''.join(difflib.unified_diff(
        source.splitlines(True), modified.splitlines(True), fromfile='active MATLAB', tofile='test MATLAB')))
    source = (ROOT / 'fortran/src/ace_module.F').read_text()
    start = source.index('subroutine inv_theta_e(')
    stop = source.index('endsubroutine inv_theta_e', start)
    routine = source[start:stop]
    modified = routine.replace('subroutine inv_theta_e(theta_e,qt,p,T,q,ql,qi)',
        'subroutine inv_theta_e(theta_e,qt,p,T,q,ql,qi,branch,n1,n2,status,initial_failure)', 1)
    modified = modified.replace('only: ieee_is_nan, ieee_is_finite',
        'only: ieee_is_nan, ieee_is_finite, ieee_value, ieee_quiet_nan', 1)
    modified = modified.replace('real, intent(out) :: T,q,ql,qi',
        'real, intent(out) :: T,q,ql,qi\ninteger, optional, intent(out) :: branch,n1,n2,status,initial_failure', 1)
    # Optional diagnostics preserve all other callers in this temporary module.
    modified = modified.replace('integer :: ice', 'integer :: ice, bdiag, ndiag1, ndiag2', 1)
    modified = modified.replace('Cpl = Cpd + (Cl-CPd)*qt', '''bdiag=0; ndiag1=0; ndiag2=0
if (present(status)) status=0
if (present(initial_failure)) initial_failure=0
T=ieee_value(0.,ieee_quiet_nan); q=T; ql=T; qi=T
Cpl = Cpd + (Cl-CPd)*qt''', 1)
    guard = f'''
  if (COUNTER >= {limit}) then
    if (present(status)) status=1
    if (present(branch)) branch=bdiag
    if (present(n1)) n1=ndiag1
    if (present(n2)) n2=ndiag2
    return
  endif
  COUNTER=COUNTER+1'''
    old = 'do while (abs(dT)>tol .and. .not.ieee_is_nan(T))'
    assert modified.count(old) == 1
    modified = modified.replace(old, old + guard.replace('COUNTER', 'ndiag1'), 1)
    # Anchored line replacement excludes historical commented loops.
    import re
    modified, count = re.subn(r'(?m)^    do while \(abs\(dT\)>tol\)$',
        '    do while (abs(dT)>tol)' + guard.replace('COUNTER', 'ndiag2'), modified)
    assert count == 2
    modified = modified.replace('\nif (ieee_is_nan(T) .or. q-qsat>sat_roundoff) then',
        '\nif (present(initial_failure)) then\n  if (ieee_is_nan(T)) initial_failure=1\nendif\nif (ieee_is_nan(T) .or. q-qsat>sat_roundoff) then', 1)
    modified = modified.replace('then ! liquid-only', 'then ! liquid-only\n    bdiag=1;', 1)
    modified = modified.replace('then ! ice-only', 'then ! ice-only\n    bdiag=2;', 1)
    modified = modified.replace('else ! co_existing', 'else ! co_existing\n    bdiag=3;', 1)
    modified += '''
if (present(branch)) branch=bdiag
if (present(n1)) n1=ndiag1
if (present(n2)) n2=ndiag2
if (present(status)) then
  if (.not.all(ieee_is_finite([T,q,ql,qi]))) status=2
  if (bdiag/=3) then
    if (.not.ieee_is_finite(dT) .or. abs(dT)>tol) status=2
  endif
endif
'''
    changed = source[:start] + modified + source[stop:]
    (work / 'ace_module.F').write_text(changed)
    (work / 'fortran_instrumentation.diff').write_text(''.join(difflib.unified_diff(
        source.splitlines(True), changed.splitlines(True), fromfile='active Fortran', tofile='test Fortran')))
    flags = ['-O2', '-ffree-form', '-ffree-line-length-none', '-fdefault-real-8', '-fdefault-double-8']
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    commands = [
        ['gfortran', *flags, *include, '-c', str(ROOT / 'fortran/src/ace_input.F')],
        ['gfortran', *flags, *include, '-c', 'ace_module.F'],
        ['gfortran', *flags, str(HERE / 'inversion_probe.f90'), 'ace_module.o', 'ace_input.o', *libs, '-o', 'inversion_probe'],
    ]
    for command in commands:
        subprocess.run(command, cwd=work, check=True)
    return commands


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--mode', choices=['focused', 'pilot', 'full'], default='focused')
    parser.add_argument('--max-iterations', type=int, default=1000)
    parser.add_argument('--chunk-size', type=int, default=10000)
    parser.add_argument('--first-pressure-index', type=int, default=0)
    parser.add_argument('--stop-pressure-index', type=int, default=2101)
    parser.add_argument('--matlab', default='matlab')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--exclude-es-above-p', action='store_true',
                        help='Skip full inversions when the reference no-condensate es > p; test-only rule')
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    if args.max_iterations < 1 or args.chunk_size < 1:
        parser.error('Iteration limit and chunk size must be positive')
    if not 0 <= args.first_pressure_index < args.stop_pressure_index <= 2101:
        parser.error('Pressure indices must satisfy 0 <= first < stop <= 2101')
    work = args.work.resolve()
    if work.exists() and any(work.iterdir()) and not args.resume:
        parser.error('Use a fresh work directory or --resume; prior results are preserved')
    work.mkdir(parents=True, exist_ok=True)
    files = ['fortran/src/ace_module.F', 'fortran/src/ace_input.F']
    files += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'matlab/util_thermodynamics').glob('*.m'))]
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}
    config = {'schema_version': 2, 'root': str(ROOT), 'work': str(work), 'mode': args.mode,
              'max_iterations': args.max_iterations, 'chunk_size': args.chunk_size,
              'first_pressure_index': args.first_pressure_index, 'stop_pressure_index': args.stop_pressure_index,
              'exclude_es_above_p': args.exclude_es_above_p,
              'source_sha256': hashes, 'full_grid_count': 2101 * 401 * 1001,
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'acceptance_tolerance': 'None; reports exact-value equality, bitwise equality and raw differences',
              'status_codes': {'0': 'finite real converged', '1': 'test-only iteration cap; unfinished',
                               '2': 'nonfinite or nonconverged exit', '3': 'complex MATLAB result',
                               '4': 'excluded: reference no-condensate es > p; full inversions not called'},
              'branch_codes': {'0': 'no condensate', '1': 'liquid', '2': 'ice', '3': 'mixed'}}
    config_path = work / 'configuration.json'
    if args.resume:
        previous = json.loads(config_path.read_text())
        if previous.get('schema_version') != config['schema_version']:
            parser.error('Checkpoint format changed; use a fresh work directory')
        for key in ['source_sha256','mode','max_iterations','chunk_size','first_pressure_index','stop_pressure_index','exclude_es_above_p']:
            if config[key] != previous.get(key, False if key=='exclude_es_above_p' else None):
                parser.error('Resume configuration/source mismatch: ' + key)
    config['build_commands'] = instrument(work, args.max_iterations)
    config['gfortran'] = subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0]
    config_path.write_text(json.dumps(config, indent=2) + '\n')
    shutil.copyfile(HERE / 'sweep_inversion.m', work / 'sweep_inversion.m')
    if not args.prepare_only:
        quote = lambda value: str(value).replace("'", "''")
        statement = f"addpath('{quote(work)}'); sweep_inversion('{quote(config_path)}');"
        with (work / 'matlab.log').open('a') as log:
            environment = dict(os.environ)
            environment.setdefault('MATLAB_PREFDIR', str(work / 'matlab-prefs'))
            subprocess.run([args.matlab, '-batch', statement], cwd=work, env=environment,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        summary = json.loads((work / 'summary.json').read_text())
        print(json.dumps({key: summary[key] for key in [
            'processed', 'requested_cases', 'comparable', 'exact_value_pairs',
            'status_mismatches', 'branch_mismatches', 'iteration_mismatches',
            'excluded_cases',
            'matlab_status_counts', 'fortran_status_counts', 'max_abs',
            'max_rel_nonzero_reference', 'full_cartesian_grid_complete']}, indent=2))
        print('Metrics only; agreement is not certified. Full report:', work / 'summary.json')
    else:
        print('Prepared:', config_path)


if __name__ == '__main__':
    main()
