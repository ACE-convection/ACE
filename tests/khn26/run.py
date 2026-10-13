#!/usr/bin/env python3
"""Prepare/compare actual-basis KHN26 initialization and single-step checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

import numpy as np
from netCDF4 import Dataset

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def prepare(work, input_file):
    work.mkdir(parents=True, exist_ok=False)
    source = (ROOT / 'matlab/ace.m').read_text()
    header = (HERE / 'matlab_probe.txt').read_text().replace('__ROOT__', str(ROOT))
    (work / 'probe.m').write_text(header + source[source.index('function X = timeint('):])
    with Dataset(input_file) as data:
        basis_file = Path(data.basis_source)
        sounding_file = Path(data.sounding_source)
        if digest(basis_file) != data.basis_sha256 or digest(sounding_file) != data.sounding_sha256:
            raise ValueError('Original reference inputs changed')
        legacy_data = sounding_file.parent.parent
    with tarfile.open(ROOT / 'docs/migration/khn26_sources.tar.gz') as archive:
        original = archive.extractfile('ACE_V020_2D88ACEs_NoGlobal.m').read().decode()
    original = original.replace('dir_ace = pwd;', f"dir_ace = '{ROOT / 'matlab'}';")
    original = original.replace("dir_data = './data/';", f"dir_data = '{legacy_data}/';")
    original = original.replace('save_output = 1;', 'save_output = 0;')
    original = original.replace('tspan = [0:1:60*6]*60; % sec', 'tspan = [0,6]; % one-step fixture')
    write_reference = f"""fid=fopen('{work / 'original_native.bin'}','w');
for step=1:2
 v=permute(X(:,[3,1,2],:,step),[3,1,2]);fwrite(fid,v(:),'double');
end
fwrite(fid,ace.Tv_zc,'double');fclose(fid);
"""
    original = original.replace('%% Operator-splitting Time-integration interacting with both CPU & GPU',
                                write_reference + '\n%% Operator-splitting Time-integration interacting with both CPU & GPU', 1)
    (work / 'original_main.m').write_text(original)
    module = (ROOT / 'fortran/src/ace_module.F').read_text()
    access = module.replace('! defien operator',
                            'public :: ace_tendency, weno_up3, precip_sinks, set_probe_thermodynamics\n\n! defien operator', 1)
    access = access.replace('\ncontains\n\nsubroutine ace_driver', '''
contains
subroutine set_probe_thermodynamics(t_in,q_in,ql_in,qi_in)
real, intent(in) :: t_in(:),q_in(:),ql_in(:),qi_in(:)
deallocate(Ta,q,ql,qi)
allocate(Ta(1,size(t_in)),q(1,size(t_in)),ql(1,size(t_in)),qi(1,size(t_in)))
Ta(1,:)=t_in;q(1,:)=q_in;ql(1,:)=ql_in;qi(1,:)=qi_in
end subroutine

subroutine ace_driver''', 1)
    if "type :: ace_thermal_t" in module:
        from oop_regression import thermal_code
        begin = access.index("subroutine set_probe_thermodynamics(")
        end = access.index("end subroutine", begin)
        access = access[:begin] + thermal_code(access[begin:end], "legacy_thermal%") + access[end:]
    (work / 'ace_module_probe.F').write_text(access)
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    commands = []
    for precision in (64, 32):
        build = work / f'build{precision}'
        build.mkdir()
        flags = ['-cpp', '-ffree-form', '-ffree-line-length-none', '-O2', '-g',
                 '-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
        if precision == 64:
            flags += ['-fdefault-real-8', '-fdefault-double-8']
        files = ['ace_input.F', 'ace_interpolation.F', 'microphy_p3.F', 'ace_module.F', 'test.F']
        for file in files:
            command = ['gfortran', *flags, *include, '-c', str(ROOT / 'fortran/src' / file)]
            commands.append(command)
            with (build / (file + '.compile.log')).open('w') as log:
                subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
        command = ['gfortran', *flags, *[file.replace('.F', '.o') for file in files], *libs, '-o', 'ace_model.exe']
        commands.append(command)
        subprocess.run(command, cwd=build, check=True)
        if precision == 64:
            command = ['gfortran', *flags, *include, '-c', str(work / 'ace_module_probe.F'), '-o', 'ace_module_probe.o']
            commands.append(command)
            subprocess.run(command, cwd=build, check=True)
            command = ['gfortran', *flags, *include, str(HERE / 'components.f90'), 'ace_module_probe.o',
                       'ace_input.o', 'ace_interpolation.o', 'microphy_p3.o', *libs, '-o', 'components.exe']
            commands.append(command)
            subprocess.run(command, cwd=build, check=True)
    files = ['matlab/ace.m', 'matlab/read_shared_input.m', 'fortran/src/ace_module.F',
             'fortran/src/test.F', 'fortran/src/ace_input.F', 'fortran/src/ace_interpolation.F',
             'fortran/src/microphy_p3.F', 'docs/migration/khn26_sources.tar.gz',
             'tests/khn26/run.py', 'tests/khn26/components.f90', 'tests/khn26/matlab_probe.txt',
             'tests/khn26/guard.f90']
    files += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'matlab/util_thermodynamics').glob('*.m'))]
    (work / 'configuration.json').write_text(json.dumps({
        'input': str(input_file), 'input_sha256': digest(input_file),
        'sources': {file: digest(ROOT / file) for file in files}, 'commands': commands,
        'precision_scope': 'real64 numerical comparison; real32 compile compatibility',
    }, indent=2) + '\n')
    print('Prepared actual-basis tests. Run MATLAB probe and original_main, then --fortran and --compare.')


def run_fortran(work, input_file):
    for mode in ('none', 'native'):
        with (work / f'{mode}.log').open('w') as log:
            subprocess.run([str(work / 'build64/ace_model.exe'), '--input', str(input_file),
                            '--physics', mode, '--steps', '1', '--state-output', str(work / f'fortran_{mode}.bin')],
                           cwd=work, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (work / 'components.log').open('w') as log:
        subprocess.run([str(work / 'build64/components.exe'), str(input_file), str(work)],
                       cwd=work, stdout=log, stderr=subprocess.STDOUT, check=True)


def check_guards(work):
    """Reject disabled operators through the production initialization API."""
    with Dataset(work / 'guard.nc', 'w') as data:
        data.ace_input_schema = 'ACE-case-input-2'
        data.geometry = 'slab'
        for name, length in [('mf_level', 13), ('zc_level', 13), ('forcing_ace', 2),
                             ('response_ace', 2), ('ace', 2), ('coarse_level', 3), ('basis_edge', 4)]:
            data.createDimension(name, length)
        for name in ('PMB', 'PMDv', 'PMD'):
            variable = data.createVariable(name, 'f8', ('response_ace', 'forcing_ace', 'coarse_level', 'basis_edge'))
            variable.units = '1' if name == 'PMB' else 'native'
            variable[:] = 0
            if name != 'PMB':
                variable.source_status = 'disabled_zero_placeholder'
    build = work / 'build64'
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    command = ['gfortran', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8',
               str(HERE / 'guard.f90'), 'ace_module.o', 'ace_input.o', 'ace_interpolation.o',
               'microphy_p3.o', *libs, '-o', 'guard.exe']
    subprocess.run(command, cwd=build, check=True)
    for name in ('PMDv', 'PMD'):
        result = subprocess.run([str(build / 'guard.exe'), str(work / 'guard.nc'), name], capture_output=True, text=True)
        (work / (name + '_guard.log')).write_text(result.stdout + result.stderr)
        if result.returncode == 0 or ('Cannot activate unavailable ' + name) not in result.stderr:
            raise AssertionError('Disabled placeholder was not rejected: ' + name)
    (work / 'guard_results.json').write_text(json.dumps({'PMDv_rejected': True, 'PMD_rejected': True}, indent=2) + '\n')


def compare_smoke(work):
    count = 101 * 401 * 3
    matlab = np.fromfile(work / 'matlab_smoke60.bin', '<f8')
    with (work / 'fortran_smoke60.bin').open('rb') as stream:
        header = np.fromfile(stream, '<i4', 3)
        if not np.array_equal(header, [101, 401, 3]):
            raise AssertionError('Unexpected smoke header')
        data = np.fromfile(stream, '<f8')
    size = 102 * 401 * 3
    states = [data[:size]] + list(data[size + 401:].reshape((10, size)))
    if matlab.size != 11 * count:
        raise AssertionError('Expected initial state and ten MATLAB steps')
    errors = []
    for step, state in enumerate(states):
        f = state.reshape((102, 401, 3), order='F')[:101]
        m = matlab[step * count:(step + 1) * count].reshape((101, 401, 3), order='F')
        if not np.all(np.isfinite(f)) or not np.all(np.isfinite(m)) or np.min(f[:, :, 2]) < 0 or np.min(m[:, :, 2]) < 0:
            raise AssertionError('Nonfinite state or negative total water')
        error = np.max(np.abs(f - m), axis=(0, 1))
        if np.any(error > [1e-9, 1e-7, 1e-11]):
            raise AssertionError(f'Smoke step {step}: {error}')
        errors.append(error.tolist())
    with Dataset(work / 'smoke60.nc') as output:
        if output.reference_version != 'KHN26 2025-11' or output.profile_index != 1342:
            raise AssertionError('Wrong production output provenance')
    report = {'duration_seconds': 60, 'dt_seconds': 6, 'physics': 'native',
              'field_order': ['MF', 'theta_e', 'qt'], 'max_abs_error_each_state': errors,
              'absolute_limits': [1e-9, 1e-7, 1e-11], 'finite_states': True, 'nonnegative_qt': True}
    (work / 'smoke_results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def compare(work):
    nc, nz = 101, 401
    count = nc * nz * 3
    report = {}

    def check(name, got, expected, tolerances):
        if not np.all(np.isfinite(got)) or not np.all(np.isfinite(expected)):
            raise AssertionError(f'{name}: nonfinite state')
        errors = np.max(np.abs(got - expected), axis=(0, 1))
        if np.any(errors > tolerances):
            raise AssertionError(f'{name}: {errors} exceed {tolerances}')
        report[name] = {'max_abs_error': errors.tolist(), 'absolute_limits': list(tolerances)}

    for mode in ('none', 'native'):
        m = np.fromfile(work / f'matlab_{mode}.bin', '<f8')
        with (work / f'fortran_{mode}.bin').open('rb') as stream:
            header = np.fromfile(stream, '<i4', 3)
            if not np.array_equal(header, [nc, nz, 3]):
                raise AssertionError('Unexpected native state header')
            f = np.fromfile(stream, '<f8')
        size = (nc + 1) * nz * 3
        initial = f[:size].reshape((nc + 1, nz, 3), order='F')[:nc]
        result = f[size + nz:].reshape((nc + 1, nz, 3), order='F')[:nc]
        check(mode + '_initial', initial, m[:count].reshape((nc, nz, 3), order='F'), [1e-14, 1e-9, 1e-12])
        check(mode + '_step', result, m[count:2 * count].reshape((nc, nz, 3), order='F'), [1e-10, 1e-8, 1e-12])
        if np.min(result[:, :, 2]) < 0:
            raise AssertionError('Negative total water')
        error = float(np.max(np.abs(f[size:size + nz] - m[-nz:])))
        if error > 1e-9:
            raise AssertionError('Reference Tv mismatch')
        report[mode + '_reference_tv'] = {'max_abs_error': error, 'absolute_limit': 1e-9}
    a = np.fromfile(work / 'matlab_native.bin', '<f8')
    b = np.fromfile(work / 'original_native.bin', '<f8')
    report['archived_original_vs_shared'] = {'exact_equality': bool(np.array_equal(a, b))}
    if not np.array_equal(a, b):
        raise AssertionError('Shared MATLAB adapter differs from archived original KHN26')
    a = np.fromfile(work / 'matlab_transport.bin', '<f8')
    b = np.fromfile(work / 'fortran_transport.bin', '<f8')
    for block, name in enumerate(('transport_initial', 'transport_tendency', 'transport_step')):
        check(name, b[block * count:(block + 1) * count].reshape((nc, nz, 3), order='F'),
              a[block * count:(block + 1) * count].reshape((nc, nz, 3), order='F'), [1e-10, 1e-8, 1e-12])
    a = np.fromfile(work / 'matlab_thermo.bin', '<f8').reshape((-1, 4), order='F')
    b = np.fromfile(work / 'fortran_thermo.bin', '<f8').reshape((-1, 4), order='F')
    check('thermodynamic_inversion', b[:, None, :], a[:, None, :], [1e-7, 1e-12, 1e-12, 1e-12])
    historical = np.fromfile(work / 'matlab_precip.bin', '<f8').reshape((8, 2), order='F')
    cases = np.fromfile(work / 'precip_input.bin', '<f8').reshape((8, 5), order='F')
    condensate = cases[:, 2] + cases[:, 3]
    water = -(0.5e-3 / 20 / 300) * np.logaddexp(0, (20 / 0.5e-3) * (condensate - 0.5e-3))
    water[condensate <= 0] = 0
    fd = np.fromfile(work / 'matlab_precip_fd.bin', '<f8')
    a = np.column_stack([water * fd, water])
    b = np.fromfile(work / 'fortran_precip.bin', '<f8').reshape((8, 2), order='F')
    check('native_precipitation', b[:, None, :], a[:, None, :], [1e-7, 1e-15])
    report['historical_precipitation_nonfinite_rows'] = np.flatnonzero(~np.all(np.isfinite(historical), axis=1)).tolist()
    if np.any(b[:, 1] > 0) or not np.array_equal(b[0], [0, 0]):
        raise AssertionError('Invalid water sink or nonzero dry-state sink')
    report['scope'] = 'Actual 101-ACE basis; initialization, 6 s steps, nonzero transport, 406 inversions, 8 precipitation states. No full 6 h or P3 acceptance.'
    (work / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--input', type=Path, default=ROOT / 'data/input/manaus1342_khn26.nc')
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--fortran', action='store_true')
    parser.add_argument('--compare', action='store_true')
    parser.add_argument('--guards', action='store_true')
    parser.add_argument('--compare-smoke', action='store_true')
    args = parser.parse_args()
    work, input_file = args.work.resolve(), args.input.resolve()
    if args.prepare:
        prepare(work, input_file)
    if args.fortran:
        run_fortran(work, input_file)
    if args.compare:
        compare(work)
    if args.guards:
        check_guards(work)
    if args.compare_smoke:
        compare_smoke(work)


if __name__ == '__main__':
    main()
