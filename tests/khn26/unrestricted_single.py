#!/usr/bin/env python3
"""Paired native singleACE three hours: default MATLAB, Fortran 32 threads.

No MATLAB computational-thread setting, thread-control environment variables,
or taskset binding. Preserve the existing numerical case and original gates.
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
from run import ROOT, digest

THREAD_ENV=['OMP_NUM_THREADS','OMP_THREAD_LIMIT','OMP_DYNAMIC','OMP_MAX_ACTIVE_LEVELS',
    'OMP_PROC_BIND','OMP_PLACES','OMP_SCHEDULE','MKL_NUM_THREADS','MKL_DYNAMIC',
    'OPENBLAS_NUM_THREADS','GOTO_NUM_THREADS','BLIS_NUM_THREADS','VECLIB_MAXIMUM_THREADS',
    'GOMP_CPU_AFFINITY','KMP_AFFINITY','KMP_HW_SUBSET','MATLAB_NUM_THREADS',
    'MATLAB_MAX_NUM_THREADS','MW_NUM_CPUS','MW_NUM_THREADS']


def prepare(work,gate_work=None):
    if gate_work is None:
        gate_work=ROOT/'migration_work/khn26_single32_native_ci_3h'
    full_multi.prepare(work,gate_work)
    cfg=json.loads((work/'configuration.json').read_text())
    cfg['case']['threads_per_language']={'matlab':'platform_default','fortran':32}
    cfg['cpu_sets']['matlab']=sorted(os.sched_getaffinity(0))
    cfg['policy']='User requested MATLAB with no imposed thread or CPU-affinity restrictions; Fortran remains 32 threads. Both start together. No efficiency observations. CPU overlap is permitted.'
    cfg['matlab_removed_thread_environment']=THREAD_ENV
    p=work/'full_launch.m'
    lines=p.read_text().splitlines()
    lines=[line for line in lines if not ('maxNumCompThreads' in line or 'ACE_MULTI_MATLAB_CAP' in line)]
    lines.insert(0,"fprintf('ACE_MATLAB_DEFAULT_THREADS %d\\n',maxNumCompThreads);")
    lines.append("fprintf('ACE_MATLAB_DEFAULT_THREADS_FINAL %d\\n',maxNumCompThreads);")
    p.write_text('\n'.join(lines)+'\n')
    cfg['sha256'][str(p)]=digest(p)
    cfg['sha256'][str(Path(__file__).resolve())]=digest(Path(__file__))
    multi.write(work/'configuration.json',cfg)
    shutil.copyfile(Path(__file__),work/'executed_unrestricted_runner.py')
    multi.verify(work)


def launch_matlab(work,cfg):
    env=os.environ.copy()
    for key in THREAD_ENV:env.pop(key,None)
    env['MATLAB_PREFDIR']='/tmp/ace-khn26-matlab-default-3h-prefs'
    Path(env['MATLAB_PREFDIR']).mkdir(exist_ok=True)
    command=['matlab','-batch',f"run('{work}/full_launch.m')"]
    log=(work/'full/matlab.log').open('x')
    process=subprocess.Popen(command,cwd=work/'full',env=env,stdout=log,stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,start_new_session=True)
    multi.write(work/'matlab_execution_policy.json',{'command':command,
        'thread_environment_removed':THREAD_ENV,'remaining_thread_controls':{k:env[k] for k in THREAD_ENV if k in env},
        'inherited_allowed_cpus':sorted(os.sched_getaffinity(0)),
        'matlab_thread_setting':'Queried for provenance only; no setter call.',
        'cpu_binding':'No taskset or explicit CPU affinity.'})
    return {'name':'matlab','process':process,'log':log,'command':command,'cpu_set':cfg['cpu_sets']['matlab']}


def run(work):
    children=[]
    try:
        cfg=multi.verify(work);gate_work=Path(cfg['gate_work'])
        if cfg['case']['duration_seconds']!=multi.LONG_DURATION_SECONDS:
            raise ValueError('Long runs require a fresh three-hour configuration')
        gate=json.loads((gate_work/'gate_results.json').read_text())
        if not gate['passed'] or gate['configuration_sha256']!=digest(gate_work/'configuration.json'):
            raise ValueError('Short gate provenance')
        if set(os.sched_getaffinity(0))!=set(cfg['cpu_sets']['matlab']):
            raise ValueError('Supervisor inherited a different CPU allocation')
        children.append(launch_matlab(work,cfg))
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
                'ten_minute_prefix_passed':checked,'matlab_cpu_binding':False})
            time.sleep(20)
        if any(c['process'].returncode for c in children):raise RuntimeError('Driver exit failure')
        if not checked:full_multi.prefix_check(work,gate_work)
        m=(work/'full/matlab.log').read_text();f=(work/'full/fortran.log').read_text()
        caps=re.findall(r'ACE_MATLAB_DEFAULT_THREADS(?:_FINAL)?\s+(\d+)',m)
        if len(caps)!=2 or not re.search(r'ACE_MULTI_OPENMP_TEAM\s+32\b',f):raise ValueError('Missing thread-policy evidence')
        multi.write(work/'full/exits.json',{c['name']:{'exit_code':c['process'].returncode,'command':c['command']} for c in children})
        result=multi.compare_states(work,'full',strict=False)
        result['thread_evidence']={'matlab_default_reported_start_end':list(map(int,caps)),'matlab_imposed_limit':False,'fortran_openmp_team':32}
        multi.verify(work);multi.write(work/'full_state_results.json',result)
        multi.write(work/'status.json',{'state':'completed_pending_scientific_review','actual_duration_seconds':10800,
            'saved_states':181,'max_abs_error':result['max_abs_error'],'threads_per_language':cfg['case']['threads_per_language']})
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
    parser.add_argument('--gate-work',type=Path,help='Fresh completed singleACE short-gate workspace')
    action=parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare','launch','run'):action.add_argument('--'+name,action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work,args.gate_work.resolve() if args.gate_work else None)
    if args.run:run(work)
    if args.launch:
        multi.verify(work)
        with (work/'supervisor.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':child.pid});print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}))
