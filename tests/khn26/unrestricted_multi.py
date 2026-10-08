#!/usr/bin/env python3
"""Native multiACE twelve hours: default MATLAB and Fortran 32, in parallel.

Use validated bubble-only short gates, no imposed MATLAB thread/CPU controls,
and no efficiency observations. Preserve state comparison and wave figures.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

import full_multi
import multi
import unrestricted_single
from run import ROOT, digest


def prepare(work):
    gate_work=ROOT/'migration_work/khn26_multi32_bubble_ci_12h'
    full_multi.prepare(work,gate_work)
    cfg=json.loads((work/'configuration.json').read_text())
    if not cfg['case']['multiACE'] or cfg['case']['initial_mf_amplitude']!=0 or cfg['case']['duration_seconds']!=43200:
        raise ValueError('Expected twelve-hour bubble-only multiACE case')
    cfg['case']['threads_per_language']={'matlab':'platform_default','fortran':32}
    cfg['cpu_sets']['matlab']=sorted(os.sched_getaffinity(0))
    cfg['policy']='MATLAB has no imposed thread limit or CPU binding; Fortran has 32 threads. Both start together, CPU overlap allowed, no efficiency observations.'
    cfg['matlab_removed_thread_environment']=unrestricted_single.THREAD_ENV
    p=work/'full_launch.m'
    lines=[line for line in p.read_text().splitlines() if not ('maxNumCompThreads' in line or 'ACE_MULTI_MATLAB_CAP' in line)]
    lines.insert(0,"fprintf('ACE_MATLAB_DEFAULT_THREADS %d\\n',maxNumCompThreads);")
    lines.append("fprintf('ACE_MATLAB_DEFAULT_THREADS_FINAL %d\\n',maxNumCompThreads);")
    p.write_text('\n'.join(lines)+'\n')
    cfg['sha256'][str(p)]=digest(p)
    for source in [Path(__file__).resolve(),Path(unrestricted_single.__file__).resolve()]:
        cfg['sha256'][str(source)]=digest(source)
    multi.write(work/'configuration.json',cfg)
    shutil.copyfile(Path(__file__),work/'executed_unrestricted_runner.py')
    multi.verify(work)
    print(json.dumps({'threads':cfg['case']['threads_per_language'],'duration_seconds':43200,'initial_MF':0,'physics':'native'}))


def run(work):
    children=[]
    try:
        cfg=multi.verify(work);gate_work=Path(cfg['gate_work']);multi.verify(gate_work)
        gate=json.loads((gate_work/'gate_passed.json').read_text())
        if not gate['passed'] or gate['configuration_sha256']!=digest(gate_work/'configuration.json'):
            raise ValueError('Short gate provenance')
        if set(os.sched_getaffinity(0))!=set(cfg['cpu_sets']['matlab']):
            raise ValueError('Supervisor inherited a different CPU allocation')
        multi.write(work/'accepted_gate.json',{'gate_passed_sha256':digest(gate_work/'gate_passed.json'),'gate':gate})
        children.append(unrestricted_single.launch_matlab(work,cfg))
        children.append(multi.launch_child(work,'full','fortran',cfg))
        checked=False
        while any(c['process'].poll() is None for c in children):
            codes={c['name']:c['process'].poll() for c in children}
            if any(code not in (None,0) for code in codes.values()):raise RuntimeError('Driver failed: '+str(codes))
            records={name:full_multi.complete_frames(work,name) for name in ('matlab','fortran')}
            affinities={c['name']:multi.thread_affinity(c['process'].pid) for c in children if c['process'].poll() is None}
            if not set(affinities.get('fortran',[]))<=set(cfg['cpu_sets']['fortran']):raise ValueError('Fortran escaped allocated CPUs')
            if not checked and min(records.values())>=11:
                full_multi.prefix_check(work,gate_work);checked=True
            multi.write(work/'status.json',{'state':'full_running','supervisor_pid':os.getpid(),
                'driver_pids':{c['name']:c['process'].pid for c in children},'exit_codes':codes,
                'threads_per_language':cfg['case']['threads_per_language'],'thread_cpu_unions':affinities,
                'complete_saved_records':records,'model_seconds':{k:max(0,v-1)*60 for k,v in records.items()},
                'target_model_seconds':43200,'ten_minute_prefix_passed':checked,'matlab_cpu_binding':False})
            time.sleep(20)
        if any(c['process'].returncode for c in children):raise RuntimeError('Driver exit failure')
        if not checked:full_multi.prefix_check(work,gate_work)
        m=(work/'full/matlab.log').read_text();f=(work/'full/fortran.log').read_text()
        caps=re.findall(r'ACE_MATLAB_DEFAULT_THREADS(?:_FINAL)?\s+(\d+)',m)
        if len(caps)!=2 or not re.search(r'ACE_MULTI_OPENMP_TEAM\s+32\b',f):raise ValueError('Missing thread-policy evidence')
        multi.write(work/'full/exits.json',{c['name']:{'exit_code':c['process'].returncode,'command':c['command']} for c in children})
        multi.write(work/'status.json',{'state':'comparing_completed_outputs','actual_duration_seconds':43200,'saved_states':721})
        result=multi.compare_states(work,'full',strict=False)
        result['thread_evidence']={'matlab_default_reported_start_end':list(map(int,caps)),'matlab_imposed_limit':False,'fortran_openmp_team':32}
        multi.verify(work);multi.write(work/'full_state_results.json',result)
        multi.make_plots(work,'full')
        multi.write(work/'status.json',{'state':'completed_pending_scientific_review','actual_duration_seconds':43200,
            'saved_states':721,'max_abs_error':result['max_abs_error'],'threads_per_language':cfg['case']['threads_per_language']})
    except BaseException as exc:
        for child in children:
            if child['process'].poll() is None:os.killpg(child['process'].pid,signal.SIGTERM)
        for child in children:
            try:child['process'].wait(timeout=10)
            except subprocess.TimeoutExpired:os.killpg(child['process'].pid,signal.SIGKILL);child['process'].wait()
        multi.write(work/'status.json',{'state':'failed','error':str(exc)});raise
    finally:
        for child in children:child['log'].close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    action=parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare','launch','run'):action.add_argument('--'+name,action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work)
    if args.run:run(work)
    if args.launch:
        multi.verify(work)
        with (work/'supervisor.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':child.pid});print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}))
