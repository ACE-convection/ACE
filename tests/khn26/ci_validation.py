#!/usr/bin/env python3
"""Run Ci validation sequentially on the existing disjoint 32-core allocations."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import multi
from run import ROOT, digest


def run(work):
    single=ROOT/'migration_work/khn26_single32_native_ci_3h'
    multiple=ROOT/'migration_work/khn26_multi32_bubble_ci_12h'
    common=ROOT/'migration_work/khn26_common_precip32_ci'
    try:
        for folder in (single,multiple,common):multi.verify(folder)
        if json.loads((common/'status.json').read_text())['state']!='completed':
            raise ValueError('Common-state comparison must complete first')
        multi.write(work/'configuration.json',{'workspaces':[str(p) for p in (common,single,multiple)],
            'configuration_sha256':{str(p):digest(p/'configuration.json') for p in (common,single,multiple)},
            'runner_sha256':digest(Path(__file__)),
            'policy':'Single and multi short gates both finish before long runs. All stages run sequentially; each language has cap 32 and disjoint cores. Unchanged regression limits.'})
        jobs=[('single_gate','single_precip.py',single,True),('multi_gate','multi.py',multiple,True)]
        outcomes={}

        def execute(stage,script,folder,gate_only):
            command=[sys.executable,str(ROOT/'tests/khn26'/script),str(folder),'--run']
            if gate_only:command.append('--gate-only')
            with (work/(stage+'.log')).open('x') as log:
                child=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
                while child.poll() is None:
                    multi.write(work/'status.json',{'state':stage+'_running','supervisor_pid':os.getpid(),
                         'stage_pid':child.pid,'stage_work':str(folder),'short_gate_outcomes':outcomes})
                    time.sleep(20)
            state=json.loads((folder/'status.json').read_text())
            outcomes[stage]={'exit_code':child.returncode,'status':state}
            multi.write(work/'outcomes.json',outcomes)
            return child.returncode==0 and state['state'] in ('gates_passed','completed_pending_scientific_review')

        passed=True
        for job in jobs:passed=execute(*job) and passed
        if not passed:
            multi.write(work/'status.json',{'state':'short_gates_failed_pending_review',
                        'short_gate_outcomes':outcomes,'long_runs_started':False})
            return
        # Resume from preserved successful gates without repeating the short runs.
        for job in [('single_3h','single_precip.py',single,False),('multi_12h','multi.py',multiple,False)]:
            if not execute(*job):
                multi.write(work/'status.json',{'state':'long_run_failed','outcomes':outcomes});return
        multi.write(work/'status.json',{'state':'completed_pending_scientific_review','outcomes':outcomes})
    except BaseException as exc:
        multi.write(work/'status.json',{'state':'failed','error':str(exc)});raise


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--launch',action='store_true');action.add_argument('--run',action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.run:run(work)
    if args.launch:
        work.mkdir(parents=True,exist_ok=False)
        with (work/'supervisor.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':child.pid});print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}))
