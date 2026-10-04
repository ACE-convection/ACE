#!/usr/bin/env python3
"""Focused real32/real64 precipitation checks and fixed Manus runtime comparison."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np


ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--duration', type=int, default=10800)
    parser.add_argument('--baseline-revision', default='v0.18.0')
    args = parser.parse_args()
    if args.duration < 60 or args.duration % 60:
        parser.error('Duration must be a positive multiple of 60 seconds')
    work = args.work.resolve()
    if work.exists() and any(work.iterdir()):
        parser.error('Use a fresh output directory to preserve evidence')
    work.mkdir(parents=True, exist_ok=True)
    (work/'runner_executed.py').write_text(Path(__file__).read_text())
    current = (ROOT/'fortran/src/ace_module.F').read_text()
    baseline = subprocess.check_output(
        ['git', 'show', args.baseline_revision+':fortran/src/ace_module.F'], cwd=ROOT, text=True)
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    prefix = subprocess.check_output(['nf-config', '--prefix'], text=True).strip()
    libs += ['-Wl,-rpath,'+prefix+'/lib']
    commands = []

    def run(cmd, directory, label, timeout=1800):
        cmd = list(map(str, cmd))
        commands.append({'argv': cmd, 'cwd': str(directory)})
        with (directory/(label+'.log')).open('w') as log:
            subprocess.run(cmd, cwd=directory, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=timeout)

    def build(name, source, bits):
        directory = work/name
        directory.mkdir()
        # Test access only; production thermodynamic cache and single-ACE mask retained.
        source = source.replace('! defien operator',
            'public :: precip_sinks, set_probe_thermo, set_probe_single\n'
            'logical :: probe_single=.false.\n! defien operator', 1)
        source = source.replace('contains\n', '''contains
subroutine set_probe_thermo(tt,qq,ll,ii)
real :: tt(:,:),qq(:,:),ll(:,:),ii(:,:)
allocate(T(size(tt,1),size(tt,2)),q(size(tt,1),size(tt,2)))
allocate(ql(size(tt,1),size(tt,2)),qi(size(tt,1),size(tt,2)))
T=tt; q=qq; ql=ll; qi=ii
end subroutine
subroutine set_probe_single(enabled)
logical :: enabled
probe_single=enabled
end subroutine
''', 1)
        assert source.count('!dXdt(2:ncols,:,:)=0.') == 1
        source = source.replace('!dXdt(2:ncols,:,:)=0.',
                                'if (probe_single) dXdt(2:ncols,:,:)=0.')
        if name.startswith('corrected'):
            anchor = '  call precip_sinks(ncols,nz,X(1:ncols,1:nz,10),K1(:,:,1),K1(:,:,2)) ! simplified precipitation'
            assert source.count(anchor) == 1
            source = source.replace(anchor, anchor+'''
  if (any(K1(:,:,2)>0.)) error stop 'Positive precipitation water tendency'
  write(97,*) t+dt,sum(-K1(:,:,2)*dt),maxval(-K1(:,:,2)*dt),minval(-K1(:,:,2)*dt)
''')
        (directory/'ace_module.F').write_text(source)
        flags = ['-O2', '-ffree-form', '-ffree-line-length-none']
        if bits == 64:
            flags += ['-fdefault-real-8', '-fdefault-double-8']
        if name.startswith('corrected'):
            flags += ['-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
        run(['gfortran', *flags, *include, '-c', ROOT/'fortran/src/ace_input.F'], directory, 'input_build')
        run(['gfortran', *flags, *include, '-c', 'ace_module.F'], directory, 'module_build')
        for source_file, target in [('tests/precision/precipitation_probe.f90', 'probe'),
                                    ('fortran/src/test.F', 'base'),
                                    ('tests/precision/fortran_case.f90', 'case')]:
            run(['gfortran', *flags, *include, ROOT/source_file, 'ace_module.o', 'ace_input.o',
                 *libs, '-o', target+'.exe'], directory, target+'_build')
        run([directory/'probe.exe'], directory, 'probe')
        lines = (directory/'probe.log').read_text().splitlines()
        assert int(lines[0]) == bits
        probe = np.array([[float(v) for v in line.split()] for line in lines[1:]])
        return directory, probe

    builds = {}
    for name, source, bits in [('baseline32', baseline, 32), ('baseline64', baseline, 64),
                               ('corrected32', current, 32), ('corrected64', current, 64)]:
        builds[name] = build(name, source, bits)
        print(name, 'built and probed', flush=True)
    reference = builds['baseline64'][1][1:, 3]
    report = {'baseline_revision': args.baseline_revision,
              'git_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'compiler': subprocess.check_output(['gfortran', '--version'], text=True).splitlines()[0],
              'source_sha256': {str(file.relative_to(ROOT)): hashlib.sha256(file.read_bytes()).hexdigest()
                                for file in [ROOT/'fortran/src/ace_module.F', ROOT/'fortran/src/ace_input.F',
                                             ROOT/'fortran/src/test.F', Path(__file__),
                                             ROOT/'tests/precision/precipitation_probe.f90',
                                             ROOT/'tests/precision/fortran_case.f90']},
              'baseline_commit': subprocess.check_output(['git', 'rev-parse', args.baseline_revision+'^{commit}'],
                                                        cwd=ROOT, text=True).strip(),
              'duration_seconds': args.duration, 'dt_seconds': 4, 'probes': {}, 'runtime': {},
              'scope': 'Default real32 or real64 prognostics; PMB and NetCDF input remain binary64. '
                       'Fixed Manus 208 saturated bubble seed, native precipitation, single ACE 1 mask; '
                       'eight-ACE geometry, stage-1 cache and damping retained. No P3.'}
    for name, (_, probe) in builds.items():
        finite = np.isfinite(probe[:, 1:3]).all(axis=1)
        entry = {'finite_cases': finite.tolist(),
                 'dtheta_e': [float(v) if np.isfinite(v) else None for v in probe[:, 1]],
                 'dqt': [float(v) if np.isfinite(v) else None for v in probe[:, 2]]}
        if name.startswith('corrected'):
            assert finite.all() and np.all(probe[:, 2] <= 0) and np.all(probe[0, 1:3] == 0)
            derivative = probe[1:, 1]/probe[1:, 2]
            relative_error = np.abs((derivative-reference)/reference)
            entry['derivative_vs_centered_binary64_relative_error'] = relative_error.tolist()
            assert np.max(relative_error) < (5e-5 if name.endswith('32') else 2e-7)
            # Stable scalar oracle for the existing softplus water sink.
            qc = np.array([1e-5, 5e-4, .003, 5e-4, .003, .002, .02])
            expected = -(0.0005/20/300)*np.logaddexp(0., 20/0.0005*(qc-0.0005))
            np.testing.assert_allclose(probe[1:, 2], expected, rtol=3e-5 if name.endswith('32') else 1e-12)
        report['probes'][name] = entry
    case = json.loads((ROOT/'tests/cases/manus_saturated_bubble_precip.json').read_text())
    input_file = ROOT/case['input']['path']
    seed_file = ROOT/case['reference']['path']/'initial_state.bin'
    for file, expected in [(input_file, case['input']['sha256']),
                           (seed_file, case['reference']['files_sha256']['initial_state.bin']),
                           (ROOT/case['reference']['path']/'mf.npz', case['reference']['files_sha256']['mf.npz'])]:
        assert hashlib.sha256(file.read_bytes()).hexdigest() == expected
    report['input_sha256'] = case['input']['sha256']
    report['seed_sha256'] = case['reference']['files_sha256']['initial_state.bin']

    def integrate(name):
        directory, _ = builds[name]
        run([directory/'base.exe', '--input', input_file, '--validate-input', directory/'init.bin'], directory, 'init')
        run([directory/'case.exe', directory/'init.bin', input_file, directory/'state.bin', seed_file,
             args.duration], directory, 'integration')
        print(name, 'integration completed', flush=True)

    try:
        smoke = work/'production_smoke32'
        smoke.mkdir()
        production_flags = '-O2 -ffree-form -ffree-line-length-none -fcheck=all,no-array-temps '
        production_flags += '-ffpe-trap=invalid,zero,overflow -fbacktrace'
        run(['make', '-f', ROOT/'fortran/makefile', 'VPATH='+str(ROOT/'fortran/src'),
             'FC=gfortran', 'FCFLAGS='+production_flags, 'FINCLUDE='+' '.join(include),
             'LDLIBS='+' '.join(libs)], smoke, 'production_build')
        run([smoke/'ace_model.exe', '--input', input_file, '--intervals', 1,
             '--output', smoke/'output.bin'], smoke, 'production')
        diagnostics = np.fromfile(smoke/'output.bin', dtype='<f4').reshape((2, 9, 801, 8))
        assert np.isfinite(diagnostics).all() and diagnostics[:, 1].min() >= 0
        report['production_smoke32'] = {'duration_seconds': 60, 'finite_all_nine_output_fields': True,
                                        'qt_min': float(diagnostics[:, 1].min()),
                                        'scope': 'Uninstrumented production source/makefile; native multiACE outer pulse defaults'}
        with ThreadPoolExecutor(max_workers=3) as pool:
            list(pool.map(integrate, ['baseline64', 'corrected32', 'corrected64']))
        arrays = {}
        for name in ['baseline64', 'corrected32', 'corrected64']:
            directory, _ = builds[name]
            dtype = '<f4' if name.endswith('32') else '<f8'
            data = np.fromfile(directory/'state.bin', dtype=dtype).reshape((-1, 3, 801, 8))
            assert len(data) == args.duration//60+1
            assert np.isfinite(data).all() and data[:, 1].min() >= 0
            arrays[name] = data.astype(np.float64)
            entry = {'saved_times': len(data), 'finite': True, 'qt_min': float(data[:, 1].min()),
                     'peak_abs_mf': float(np.abs(data[:, 2]).max())}
            if name.startswith('corrected'):
                sinks = np.loadtxt(directory/'fort.97')
                assert len(sinks) == args.duration//4 and np.isfinite(sinks).all()
                assert np.all(sinks[:, 1:] >= 0) and sinks[:, 1].sum() > 0
                entry['sum_unweighted_qt_removal'] = float(sinks[:, 1].sum())
            report['runtime'][name] = entry
        for name in ['corrected32', 'corrected64']:
            diff = arrays[name]-arrays['baseline64']
            report['runtime'][name]['vs_baseline64'] = {
                field: {'max_abs': float(np.abs(diff[:, i]).max()),
                        'rms': float(np.sqrt(np.mean(diff[:, i]**2)))}
                for i, field in enumerate(['theta_e_K', 'qt_kg_kg', 'mf_kg_m2_s'])}
        if args.duration == 10800:
            with np.load(ROOT/case['reference']['path']/'mf.npz') as frozen:
                report['baseline64_vs_frozen_mf_max_abs'] = float(np.abs(
                    arrays['baseline64'][:, 2, :, 0]-frozen['fortran']).max())
        report['status'] = 'passed focused numerical and runtime checks; no scientific acceptance tolerance assigned'
    except Exception as exc:
        report['status'] = 'failed'
        report['error'] = str(exc)
        raise
    finally:
        (work/'commands.json').write_text(json.dumps(commands, indent=2)+'\n')
        (work/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')
    print(json.dumps(report['runtime'], indent=2))


if __name__ == '__main__':
    main()
