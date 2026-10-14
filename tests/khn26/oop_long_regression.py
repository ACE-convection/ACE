#!/usr/bin/env python3
"""Background OOP multiACE native/P3 three-hour preservation gate.

Only isolated source copies are patched (+1 K reference bubble, observational
precipitation accumulator and an actual OpenMP team assertion). Archived
references and production sources are read-only. No tolerance is allowed.
"""
import argparse
from datetime import datetime, timezone
import difflib
import json
import os
from pathlib import Path
import resource
import shlex
import shutil
import subprocess
import sys
import time
import traceback

import numpy as np

from oop_regression import FILES, INPUT_HASH, TABLE_HASH, sha
from precip_timeseries import patch_module, read_minute_precip, write
from p3_smoke import state_summary

ROOT = Path(__file__).resolve().parents[2]
FLAGS = ['-cpp', '-O2', '-ffree-form', '-ffree-line-length-none',
         '-fdefault-real-8', '-fdefault-double-8', '-fopenmp']
ENV = dict(OMP_NUM_THREADS='32', OMP_THREAD_LIMIT='32', OMP_DYNAMIC='FALSE',
           OMP_STACKSIZE='64M', OPENBLAS_NUM_THREADS='1')
NAMES = ('states.bin', 'fields.dat', 'precip_accumulation.bin')


def now():
    return datetime.now(timezone.utc).isoformat()


def replace(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Expected unique anchor: ' + old)
    return source.replace(old, new, 1)


def prepare(work):
    work.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(__file__, work/'executed_runner.py')
    report = ROOT/'docs/figures/khn26_multi_precipitation_3h/results.json'
    accepted = json.loads(report.read_text())
    original = {name: (ROOT/'fortran/src'/name).read_text() for name in FILES}
    module = replace(original['ace_module.F'], 'dum1=self%Tr(1,k)+0.25',
                     'dum1=self%Tr(1,k)+1.0')
    driver = replace(original['test.F'], 'use ace_module\n',
                     'use ace_module\nuse omp_lib, only: omp_get_max_threads,omp_get_num_threads\n')
    driver = replace(driver, 'shared_input=.true.', """if (omp_get_max_threads()/=32) error stop 'Expected OpenMP cap 32'
!$omp parallel
!$omp single
write(*,*) 'OOP_LONG_OPENMP_TEAM',omp_get_num_threads()
if (omp_get_num_threads()/=32) error stop 'Expected OpenMP team 32'
!$omp end single
!$omp end parallel
shared_input=.true.""")
    include = shlex.split(subprocess.check_output(['nf-config', '--fflags'], text=True))
    libs = shlex.split(subprocess.check_output(['nf-config', '--flibs'], text=True))
    cfg = dict(commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               compiler=subprocess.check_output(['gfortran', '--version'], text=True),
               flags=FLAGS, netcdf_flags=include, netcdf_libraries=libs,
               environment=ENV, created_utc=now(), duration_seconds=10800,
               dt_seconds=4, bubble_K=1, initial_MF=0, records=181,
               input=str(ROOT/'data/input/manaus1342_khn26.nc'),
               tables=str(ROOT.parent/'ACE_FORTRAN/input_data'), jobs=[],
               sha256={str(ROOT/'fortran/src'/n): sha(ROOT/'fortran/src'/n) for n in FILES})
    for path, expected in ((Path(cfg['input']), INPUT_HASH),
                           (Path(cfg['tables'])/'p3_lookupTable_1.dat-v6.4-2momI', TABLE_HASH)):
        if sha(path) != expected:
            raise ValueError('Input/lookup changed: ' + str(path))
        cfg['sha256'][str(path)] = expected
    cfg['sha256'][str(report)] = sha(report)
    commands = []
    for variant in ('plain', 'precip'):
        src = work/variant/'source'; src.mkdir(parents=True)
        build = work/variant/'build'; build.mkdir()
        sources = dict(original, **{'ace_module.F': module, 'test.F': driver})
        if variant == 'precip':
            sources['ace_module.F'] = patch_module(module)
        for name, content in sources.items():
            path = src/name; path.write_text(content)
            cfg['sha256'][str(path)] = sha(path)
            (src/(name+'.patch')).write_text(''.join(difflib.unified_diff(
                original[name].splitlines(True), content.splitlines(True),
                fromfile='production/'+name, tofile=variant+'/'+name)))
            command = ['gfortran', *FLAGS, *include, '-c', str(path)]
            commands.append(command)
            with (build/(name+'.log')).open('x') as log:
                subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
        command = ['gfortran', *FLAGS, *[n.replace('.F', '.o') for n in FILES],
                   *libs, '-o', 'ace_model.exe']
        commands.append(command)
        with (build/'link.log').open('x') as log:
            subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
        cfg['sha256'][str(build/'ace_model.exe')] = sha(build/'ace_model.exe')
    for physics, language in (('native', 'fortran'), ('p3', 'p3')):
        name = 'multiACE_'+language
        job = next(j for j in accepted['configuration']['jobs'] if j['name'] == name)
        diagnostic = next(j for j in accepted['diagnostics'] if j['job'] == name)
        reference = ROOT/'migration_work/khn26_multi_precipitation_three_hour'/name/'full'
        refs = {filename: str(reference/filename) for filename in NAMES}
        # State and precipitation hashes come from versioned acceptance evidence.
        for filename, key in (('states.bin', 'state_sha256'), ('precip_accumulation.bin', 'precip_sha256')):
            if sha(Path(refs[filename])) != diagnostic[key]:
                raise ValueError('Archived acceptance artifact changed: ' + filename)
        if sha(Path(job['reference'])) != job['reference_sha256']:
            raise ValueError('Original state reference changed')
        cfg['jobs'].append(dict(physics=physics, references=refs,
                                reference_sha256={n: sha(Path(p)) for n,p in refs.items()},
                                original_state_reference=job['reference'],
                                original_state_sha256=job['reference_sha256']))
    # Snapshot every helper used by the detached supervisor.
    helpers = work/'helpers'; helpers.mkdir()
    for filename in ('oop_regression.py', 'precip_timeseries.py', 'p3_smoke.py'):
        shutil.copyfile(Path(__file__).parent/filename, helpers/filename)
        cfg['sha256'][str(helpers/filename)] = sha(helpers/filename)
    cfg['runner_sha256'] = sha(work/'executed_runner.py')
    write(work/'build_commands.json', commands)
    write(work/'configuration.json', cfg)
    write(work/'status.json', dict(state='prepared', updated_utc=now()))


def compare(candidate, baseline, prefix=False):
    """Byte comparison with an exact first-divergent-byte location on failure."""
    offset = 0
    with candidate.open('rb') as a, baseline.open('rb') as b:
        while True:
            x = a.read(1024*1024); y = b.read(len(x) if prefix else 1024*1024)
            if prefix and not x:
                break
            if x != y:
                first = next((i for i,(u,v) in enumerate(zip(x,y)) if u != v), min(len(x),len(y)))
                raise ValueError(f'Bitwise mismatch: {candidate}, reference {baseline}, byte {offset+first}')
            if not x:
                break
            offset += len(x)
    return dict(bitwise_identical=True, prefix=prefix, compared_bytes=offset,
                candidate_sha256=sha(candidate), reference_sha256=sha(baseline))


def command(work, cfg, physics, variant, run, intervals):
    run.mkdir(parents=True, exist_ok=False)
    return [str(work/variant/'build/ace_model.exe'), '--input', cfg['input'],
            '--physics', physics, '--dt', '4', '--intervals', str(intervals),
            '--p3-lookup-directory', cfg['tables'], '--state-output', str(run/'states.bin'),
            '--output', str(run/'fields.dat')]


def supervise(work):
    cfg = json.loads((work/'configuration.json').read_text())
    children = []
    results = dict(started_utc=now(), jobs={}, prefix_gates={}, passed=False)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_STACK, (resource.RLIM_INFINITY, resource.RLIM_INFINITY))
    env = dict(os.environ, **ENV)
    for key in ('ACE_MULTI_TENDENCY_FILE', 'ACE_MULTI_PRECIP_FILE'):
        env.pop(key, None)
    try:
        if sha(work/'executed_runner.py') != cfg['runner_sha256']:
            raise ValueError('Supervisor source changed')
        for path, expected in cfg['sha256'].items():
            if sha(Path(path)) != expected:
                raise ValueError('Pinned source/input/build changed: ' + path)
        for job in cfg['jobs']:
            for name,path in job['references'].items():
                if sha(Path(path)) != job['reference_sha256'][name]:
                    raise ValueError('Reference changed: ' + path)
            physics = job['physics']; prefix = {}
            # Short plain/observed identity must pass before either long run.
            for variant in ('plain', 'precip'):
                run = work/'prefix'/physics/variant
                cmd = command(work, cfg, physics, variant, run, 1)
                write(run/'launch.json', dict(command=cmd, environment=ENV))
                write(work/'status.json', dict(state='prefix_running', physics=physics,
                                              variant=variant, supervisor_pid=os.getpid(), updated_utc=now()))
                with (run/'run.log').open('x') as log:
                    subprocess.run(cmd, cwd=run, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
                for name in ('states.bin', 'fields.dat'):
                    prefix[variant+'/'+name] = compare(run/name, Path(job['references'][name]), prefix=True)
            for name in ('states.bin', 'fields.dat'):
                prefix['plain_vs_precip/'+name] = compare(work/'prefix'/physics/'plain'/name,
                                                         work/'prefix'/physics/'precip'/name)
            read_minute_precip(work/'prefix'/physics/'precip/precip_accumulation.bin', duration=60)
            prefix['precipitation'] = compare(work/'prefix'/physics/'precip/precip_accumulation.bin',
                                              Path(job['references']['precip_accumulation.bin']), prefix=True)
            results['prefix_gates'][physics] = prefix
        for job in cfg['jobs']:
            run = work/job['physics']/'full'
            cmd = command(work, cfg, job['physics'], 'precip', run, 180)
            log = (run/'run.log').open('x')
            p = subprocess.Popen(cmd, cwd=run, env=env, stdout=log, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, start_new_session=True)
            children.append((job, p, log))
            write(run/'launch.json', dict(pid=p.pid, command=cmd, started_utc=now(), environment=ENV))
        while True:
            statuses = {}
            for job,p,log in children:
                path = work/job['physics']/'full/precip_accumulation.bin'
                records = path.stat().st_size//(405*8) if path.exists() else 0
                statuses[job['physics']] = dict(pid=p.pid, exit_code=p.poll(), complete_precip_records=records,
                                                model_minutes=max(0, records-1))
            write(work/'status.json', dict(state='running', supervisor_pid=os.getpid(), jobs=statuses,
                                          updated_utc=now()))
            if any(p.poll() not in (None, 0) for _,p,_ in children):
                raise RuntimeError('Long driver failed; inspect preserved run.log')
            if all(p.poll() is not None for _,p,_ in children):
                break
            time.sleep(20)
        for job,p,log in children:
            log.close(); physics = job['physics']; run = work/physics/'full'
            checks = {name: compare(run/name, Path(job['references'][name])) for name in NAMES}
            checks['original_state_reference'] = compare(run/'states.bin', Path(job['original_state_reference']))
            read_minute_precip(run/'precip_accumulation.bin')
            fields = np.memmap(run/'fields.dat', '<f4', mode='r')
            if not np.isfinite(fields).all():
                raise ValueError('Nonfinite normal output')
            if physics == 'p3':
                validity = state_summary(run/'states.bin', 60)
                if not (validity['complete_saved_states'] == 181 and validity['all_saved_values_finite']
                        and validity['water_and_number_fields_nonnegative'] and validity['rime_mass_not_above_total_ice']):
                    raise ValueError('P3 validity failed')
                checks['validity'] = validity
            checks['precipitation_records'] = 181
            results['jobs'][physics] = checks
        # Certification is tied to the source snapshot, even if checkout changes during execution.
        results.update(passed=True, completed_utc=now(), configuration=cfg,
                       current_checkout_matches_snapshot=all(sha(ROOT/'fortran/src'/n) == cfg['sha256'][str(ROOT/'fortran/src'/n)] for n in FILES))
        write(work/'results.json', results)
        write(work/'status.json', dict(state='completed', passed=True, updated_utc=now()))
    except Exception as exc:
        results.update(error=str(exc), failed_utc=now())
        write(work/'results.json', results)
        write(work/'status.json', dict(state='failed', error=str(exc), updated_utc=now(),
                                      running_driver_pids=[p.pid for _,p,_ in children if p.poll() is None]))
        traceback.print_exc()
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        prepare(args.work.resolve())
    if args.run:
        supervise(args.work.resolve())
