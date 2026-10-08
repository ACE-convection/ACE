#!/usr/bin/env python3
"""Run only dry/native ten-minute multiACE gates: default MATLAB, Fortran 32."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import multi
from run import ROOT, digest
from unrestricted_single import THREAD_ENV


def prepare(work):
    multi.prepare(work, 0.0, duration=600)
    cfg = json.loads((work / 'configuration.json').read_text())
    for tag in ('gate_none', 'gate_native'):
        path = work / (tag + '_launch.m')
        lines = [line for line in path.read_text().splitlines()
                 if 'maxNumCompThreads' not in line and 'ACE_MULTI_MATLAB_CAP' not in line]
        lines.insert(0, "fprintf('ACE_MATLAB_DEFAULT_THREADS %d\\n',maxNumCompThreads);")
        lines.append("fprintf('ACE_MATLAB_DEFAULT_THREADS_FINAL %d\\n',maxNumCompThreads);")
        path.write_text('\n'.join(lines)+'\n')
        cfg['sha256'][str(path)] = digest(path)
    cfg['cpu_sets']['matlab'] = sorted(os.sched_getaffinity(0))
    cfg['case']['threads_per_language'] = {'matlab': 'platform_default', 'fortran': 32}
    cfg['policy'] = 'Only two ten-minute gates; no MATLAB thread/affinity restriction; Fortran 32. No long run or performance study.'
    cfg['fairness'] = 'User-requested execution policy; CPU overlap is allowed. No efficiency comparison.'
    cfg['sha256'][str(Path(__file__).resolve())] = digest(Path(__file__).resolve())
    cfg['sha256'][str(ROOT / 'tests/khn26/unrestricted_single.py')] = digest(ROOT / 'tests/khn26/unrestricted_single.py')
    multi.write(work / 'configuration.json', cfg)
    shutil.copyfile(Path(__file__), work / 'executed_gate_runner.py')
    multi.verify(work)


def launch_matlab(work, tag, cfg):
    env = os.environ.copy()
    for key in THREAD_ENV:
        env.pop(key, None)
    env['MATLAB_PREFDIR'] = str(work / 'matlab_prefs')
    Path(env['MATLAB_PREFDIR']).mkdir(exist_ok=True)
    command = ['matlab', '-batch', f"run('{work}/{tag}_launch.m')"]
    log = (work / tag / 'matlab.log').open('x')
    process = subprocess.Popen(command, cwd=work / tag, env=env, stdout=log,
        stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
    multi.write(work / tag / 'matlab_execution_policy.json', {
        'command': command, 'thread_environment_removed': THREAD_ENV,
        'remaining_thread_controls': {k: env[k] for k in THREAD_ENV if k in env},
        'cpu_binding': 'No imposed binding', 'allowed_cpus': sorted(os.sched_getaffinity(0)),
        'thread_setting': 'Queried only; no setter call'})
    return {'name': 'matlab', 'process': process, 'log': log,
            'command': command, 'cpu_set': cfg['cpu_sets']['matlab']}


def thread_evidence(work, tag):
    m = (work / tag / 'matlab.log').read_text()
    f = (work / tag / 'fortran.log').read_text()
    caps = re.findall(r'ACE_MATLAB_DEFAULT_THREADS(?:_FINAL)?\s+(\d+)', m)
    if len(caps) != 2 or not re.search(r'ACE_MULTI_OPENMP_TEAM\s+32\b', f):
        raise ValueError('Missing thread-policy evidence')
    return {'matlab_default_reported_start_end': list(map(int, caps)),
            'matlab_imposed_limit': False, 'fortran_openmp_team': 32}


def run(work):
    original_launch = multi.launch_child

    def launch_child(work, tag, name, cfg, debug=False):
        if name == 'matlab':
            return launch_matlab(work, tag, cfg)
        return original_launch(work, tag, name, cfg, debug=debug)

    multi.launch_child = launch_child
    multi.thread_evidence = thread_evidence
    # Explicitly stop after gates; never enter multi.run's long-run path.
    multi.run(work, gate_only=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    action = parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare', 'launch', 'run'):
        action.add_argument('--'+name, action='store_true')
    args = parser.parse_args()
    work = args.work.resolve()
    if args.prepare:
        prepare(work)
    if args.run:
        run(work)
    if args.launch:
        multi.verify(work)
        with (work / 'supervisor.log').open('x') as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), str(work), '--run'],
                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                start_new_session=True, close_fds=True)
        multi.write(work / 'supervisor.json', {'pid': child.pid})
        print(json.dumps({'supervisor_pid': child.pid, 'work': str(work)}))
