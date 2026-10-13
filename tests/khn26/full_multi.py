#!/usr/bin/env python3
"""Resume validated native singleACE or multiACE at MATLAB 96 / Fortran 32 threads.

Wait for the existing short gates; run three hours in the background.
No performance measurements. Keep numerical validation and source provenance.
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

import numpy as np

import multi
from run import ROOT, digest
from trajectory import replace_once

ORIGINAL_ENVIRONMENT=multi.environment


def placements():
    topology=subprocess.check_output(['lscpu','-p=CPU,CORE,SOCKET,NODE'],text=True)
    nodes={};allowed=os.sched_getaffinity(0)
    for line in topology.splitlines():
        if line.startswith('#'):continue
        cpu,core,socket,node=map(int,line.split(','))
        if cpu in allowed:nodes.setdefault(node,{}).setdefault((socket,core),[]).append(cpu)
    m=[];f=[]
    for node,cores in sorted(nodes.items()):
        ordered=sorted(cores.values(),key=min)
        if len(ordered)!=20 or any(len(cpus)!=2 for cpus in ordered):
            raise ValueError('Expected four NUMA nodes, each with 20 physical cores and two siblings')
        m.extend(cpu for cpus in ordered[:12] for cpu in cpus)
        f.extend(min(cpus) for cpus in ordered[12:])
    if len(m)!=96 or len(f)!=32 or set(m)&set(f):raise ValueError('CPU allocation')
    return {'matlab':sorted(m),'fortran':sorted(f)},topology


def prepare(work,gate_work):
    cfg=multi.verify(gate_work)
    work.mkdir(parents=True,exist_ok=False);(work/'full').mkdir();(work/'build').mkdir()
    cpus,topology=placements();(work/'cpu_topology.csv').write_text(topology)
    source=(gate_work/'multi_main.m').read_text()
    source=replace_once(source,f"tspan = 0:60:{cfg['case']['duration_seconds']};",
                        f'tspan = 0:60:{multi.LONG_DURATION_SECONDS};')
    (work/'multi_main.m').write_text(source.replace(str(gate_work),str(work)))
    launch=(gate_work/'full_launch.m').read_text().replace(str(gate_work),str(work))
    launch=launch.replace('maxNumCompThreads(32)','maxNumCompThreads(96)').replace('maxNumCompThreads==32','maxNumCompThreads==96')
    launch=launch.replace('cap 32','cap 96')
    (work/'full_launch.m').write_text(launch)
    shutil.copyfile(gate_work/'build/ace_model.exe',work/'build/ace_model.exe')
    (work/'build/ace_model.exe').chmod(0o755)
    paths=[Path(__file__).resolve(),Path(multi.__file__).resolve(),work/'multi_main.m',work/'full_launch.m',
           work/'build/ace_model.exe',gate_work/'configuration.json']
    paths.extend(Path(p) for p in cfg['sha256'])
    case=cfg['case'].copy();case['threads_per_language']={'matlab':96,'fortran':32}
    case['duration_seconds']=multi.LONG_DURATION_SECONDS
    multi.write(work/'configuration.json',{'case':case,'gate_work':str(gate_work),'gate_file':'gate_passed.json' if case['multiACE'] else 'gate_results.json','cpu_sets':cpus,
          'sha256':{str(p):digest(p) for p in paths},
          'policy':'User requested completion speed, no efficiency observations. MATLAB uses both siblings on 48 physical cores; Fortran uses one CPU on each of 32 other physical cores. No physical-core overlap.',
          'validation':'Original short gates required; changed-thread long run must match its first ten-minute gate within unchanged state limits. Bit identity reported separately.'})
    shutil.copyfile(Path(__file__),work/'executed_runner.py')
    print(json.dumps({'prepared':str(work),'threads':case['threads_per_language']}))


def environment(cfg,name):
    env=ORIGINAL_ENVIRONMENT(cfg,name)
    if name=='matlab':
        for key in ('OMP_NUM_THREADS','OMP_THREAD_LIMIT','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS','BLIS_NUM_THREADS','VECLIB_MAXIMUM_THREADS'):
            env[key]='96'
        env['MATLAB_PREFDIR']='/tmp/ace-khn26-matlab96-prefs';Path(env['MATLAB_PREFDIR']).mkdir(exist_ok=True)
    return env


def frame(work,tag,name,index):
    p=work/tag/(name+'_states.bin');size=multi.N*multi.Z*3;fsize=(multi.N+1)*multi.Z*3
    offset=index*size*8 if name=='matlab' else 12+8*(index*fsize+(multi.Z if index else 0))
    count=size if name=='matlab' else fsize
    if p.stat().st_size<offset+count*8:raise ValueError('Incomplete state frame')
    with p.open('rb') as stream:
        stream.seek(offset);value=np.fromfile(stream,'<f8',count=count)
    return value.reshape((multi.N if name=='matlab' else multi.N+1,multi.Z,3),order='F')[:multi.N]


def complete_frames(work,name):
    p=work/'full'/(name+'_states.bin')
    if not p.exists():return 0
    b=p.stat().st_size
    return b//(multi.N*multi.Z*3*8) if name=='matlab' else max(0,(b-12-multi.Z*8)//((multi.N+1)*multi.Z*3*8))


def prefix_check(work,gate_work):
    result={}
    for name in ('matlab','fortran'):
        errors=[];identical=True
        for record in range(11):
            a=frame(gate_work,'gate_native',name,record*15);b=frame(work,'full',name,record)
            if not np.isfinite(b).all() or np.min(b[:,:,2])<0:raise ValueError('Invalid long-run prefix state')
            errors.append(np.max(np.abs(a-b),axis=(0,1)))
            identical=identical and np.array_equal(a,b)
        maximum=np.max(errors,axis=0)
        result[name]={'max_abs_error':maximum.tolist(),'exact_identity':identical,
                      'passed':bool(np.all(maximum<=multi.STATE_LIMITS))}
    multi.write(work/'ten_minute_prefix_results.json',{'compared_records':11,'limits':multi.STATE_LIMITS.tolist(),'languages':result})
    if not all(value['passed'] for value in result.values()):raise ValueError('Changed-thread ten-minute prefix failed original limits')


def run(work):
    children=[]
    try:
        cfg=multi.verify(work);gate_work=Path(cfg['gate_work']);gate_path=gate_work/cfg['gate_file']
        if cfg['case']['duration_seconds']!=multi.LONG_DURATION_SECONDS:
            raise ValueError('Long runs require a fresh three-hour configuration')
        while not gate_path.exists():
            p=gate_work/'status.json'
            state=json.loads(p.read_text()) if p.exists() else {}
            if state.get('state')=='failed':raise ValueError('Short gate failed: '+state.get('error','unknown'))
            multi.write(work/'status.json',{'state':'waiting_for_short_gates','supervisor_pid':os.getpid(),'gate_state':state.get('state'),'gate_work':str(gate_work)})
            time.sleep(20)
        multi.verify(gate_work);multi.verify(work)
        gate=json.loads(gate_path.read_text())
        if not gate['passed'] or gate['configuration_sha256']!=digest(gate_work/'configuration.json'):raise ValueError('Invalid gate provenance')
        multi.write(work/'accepted_gate.json',{'gate_passed_sha256':digest(gate_path),'gate':gate})
        multi.environment=environment
        for name in ('matlab','fortran'):children.append(multi.launch_child(work,'full',name,cfg))
        prefix_done=False
        while any(c['process'].poll() is None for c in children):
            codes={c['name']:c['process'].poll() for c in children}
            if any(code not in (None,0) for code in codes.values()):raise RuntimeError('Long-run driver failed: '+str(codes))
            affinities={c['name']:multi.thread_affinity(c['process'].pid) for c in children if c['process'].poll() is None}
            for child in children:
                if not set(affinities.get(child['name'],[]))<=set(child['cpu_set']):raise ValueError('Driver escaped CPU allocation')
            records={name:complete_frames(work,name) for name in ('matlab','fortran')}
            if not prefix_done and min(records.values())>=11:
                prefix_check(work,gate_work);prefix_done=True
            multi.write(work/'status.json',{'state':'full_running','supervisor_pid':os.getpid(),
                 'driver_pids':{c['name']:c['process'].pid for c in children},'exit_codes':codes,
                 'threads_per_language':{'matlab':96,'fortran':32},'thread_cpu_unions':affinities,
                 'complete_saved_records':records,'model_seconds':{name:max(0,count-1)*60 for name,count in records.items()},
                 'ten_minute_prefix_passed':prefix_done})
            time.sleep(20)
        if any(c['process'].returncode for c in children):raise RuntimeError('Driver exit failure')
        if not prefix_done:prefix_check(work,gate_work)
        matlab=(work/'full/matlab.log').read_text();fortran=(work/'full/fortran.log').read_text()
        if not re.search(r'ACE_MULTI_MATLAB_CAP\s+96\b',matlab) or not re.search(r'ACE_MULTI_MATLAB_CAP_FINAL\s+96\b',matlab):raise ValueError('Missing MATLAB 96-thread cap evidence')
        if not re.search(r'ACE_MULTI_OPENMP_TEAM\s+32\b',fortran):raise ValueError('Missing Fortran team evidence')
        multi.write(work/'full/exits.json',{c['name']:{'exit_code':c['process'].returncode,'command':c['command']} for c in children})
        result=multi.compare_states(work,'full',strict=False)
        result['thread_evidence']={'matlab_cap_start_end':[96,96],'fortran_openmp_team':32}
        multi.verify(work);multi.write(work/'full_state_results.json',result)
        multi.make_plots(work,'full')
        multi.write(work/'status.json',{'state':'completed_pending_scientific_review','actual_duration_seconds':cfg['case']['duration_seconds'],
                     'saved_states':cfg['case']['duration_seconds']//60+1,'max_abs_error':result['max_abs_error'],'threads_per_language':{'matlab':96,'fortran':32}})
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
    parser.add_argument('--gate-work',type=Path,default=ROOT/'migration_work/khn26_multi32_bubble_ci_12h')
    action=parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare','launch','run'):action.add_argument('--'+name,action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work,args.gate_work.resolve())
    if args.run:run(work)
    if args.launch:
        multi.verify(work)
        with (work/'supervisor.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':child.pid});print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}))
