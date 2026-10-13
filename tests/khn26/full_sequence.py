#!/usr/bin/env python3
"""After short gates, run native singleACE 3 h then multiACE 3 h at 96/32."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import multi
from run import ROOT, digest


def run(work):
    single=ROOT/'migration_work/khn26_single_matlab96_fortran32_3h'
    multiple=ROOT/'migration_work/khn26_multi_matlab96_fortran32_3h'
    gate_work=ROOT/'migration_work/khn26_multi32_bubble_ci_12h'
    try:
        for folder in (single,multiple):multi.verify(folder)
        multi.write(work/'configuration.json',{'sequence':[str(single),str(multiple)],
            'threads_per_language':{'matlab':96,'fortran':32},'efficiency_observations':False,
            'configuration_sha256':{str(p):digest(p/'configuration.json') for p in (single,multiple)},
            'runner_sha256':digest(Path(__file__)),
            'policy':'Finish active multiACE short gates, then native singleACE three hours, then native multiACE three hours. Sequential runs; no physical-core overlap between languages.'})
        while not (gate_work/'gate_passed.json').exists():
            state=json.loads((gate_work/'status.json').read_text())
            if state.get('state')=='failed':raise ValueError('MultiACE short gate failed: '+state.get('error','unknown'))
            multi.write(work/'status.json',{'state':'waiting_for_short_gates','supervisor_pid':os.getpid(),
                  'gate_state':state['state'],'gate_work':str(gate_work),'threads_for_long_runs':{'matlab':96,'fortran':32}})
            time.sleep(20)
        outcomes={}
        for stage,folder in [('single_3h',single),('multi_3h',multiple)]:
            command=[sys.executable,str(ROOT/'tests/khn26/full_multi.py'),str(folder),'--run']
            with (work/(stage+'.log')).open('x') as log:
                child=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
                while child.poll() is None:
                    multi.write(work/'status.json',{'state':stage+'_running','supervisor_pid':os.getpid(),
                       'stage_pid':child.pid,'stage_work':str(folder),'outcomes':outcomes,
                       'threads_per_language':{'matlab':96,'fortran':32}})
                    time.sleep(20)
            status=json.loads((folder/'status.json').read_text())
            outcomes[stage]={'exit_code':child.returncode,'status':status}
            multi.write(work/'outcomes.json',outcomes)
            if child.returncode or status['state']!='completed_pending_scientific_review':
                raise ValueError(stage+' failed; following run not started')
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
        work.mkdir(parents=True,exist_ok=False);shutil.copyfile(Path(__file__),work/'executed_runner.py')
        with (work/'supervisor.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':child.pid});print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}))
