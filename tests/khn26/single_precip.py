#!/usr/bin/env python3
"""Supplement the three-hour KHN26 singleACE case with native precipitation.

Ten-minute state, tendency, and sink gates precede the three-hour paired run.
Both programs have separate 32-core allocations. Production sources are unchanged.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np

import multi
from run import ROOT, digest


def prepare(work):
    multi.prepare(work, 0.03, single=True, duration=10800)
    cfg=json.loads((work/'configuration.json').read_text())
    cfg['case']['dynamics_policy']='Only ACE 1 dynamics; native precipitation and damping retain all columns.'
    cfg['limits']='Unchanged regression limits; three-hour results require scientific review.'
    cfg['sha256'][str(Path(__file__).resolve())]=digest(Path(__file__))
    shutil.copyfile(Path(__file__),work/'executed_single_precip_runner.py')
    multi.write(work/'configuration.json',cfg)


def check_prefix(work):
    sizes={'states':12+(11*(multi.N+1)*multi.Z*3+multi.Z)*8,
           'tendencies':90*multi.N*multi.Z*3*8,
           'precip_sinks':10*multi.N*multi.Z*2*8}
    for suffix,size in sizes.items():
        a=work/'gate_native'/('debug_'+suffix+'.bin')
        b=work/'gate_native'/('fortran_'+suffix+'.bin')
        if a.stat().st_size!=size:raise ValueError('Incomplete checked stream: '+suffix)
        with a.open('rb') as checked,b.open('rb') as production:
            while chunk:=checked.read(1024*1024):
                if chunk!=production.read(len(chunk)):raise ValueError('Checked/production prefix differs: '+suffix)


def run(work,gate_only=False):
    cfg=multi.verify(work)
    if not gate_only and cfg['case']['duration_seconds']!=multi.LONG_DURATION_SECONDS:
        raise ValueError('Long runs require a fresh three-hour configuration')
    try:
        if not (work/'gate_results.json').exists():
            multi.monitor(work,'gate_native',[multi.launch_child(work,'gate_native','fortran',cfg,debug=True)])
            children=[]
            try:
                for name in ('matlab','fortran'):
                    children.append(multi.launch_child(work,'gate_native',name,cfg))
                multi.monitor(work,'gate_native',children)
            except BaseException:
                import signal
                for child in children:
                    if child['process'].poll() is None:
                        os.killpg(child['process'].pid,signal.SIGTERM)
                        child['process'].wait(timeout=10)
                raise
            check_prefix(work)
            # Preserve all three comparisons even when a numerical gate fails.
            states=multi.compare_states(work,'gate_native',strict=False)
            tendencies=multi.compare_tendencies(work,'gate_native',strict=False)
            sinks=multi.compare_precipitation(work,strict=False)
            gate={'passed':all(r['passed'] for r in (states,tendencies,sinks)),
                  'checked_production_ten_step_byte_identity':True,
                  'thread_evidence':multi.thread_evidence(work,'gate_native'),
                  'state_max_abs_error':states['max_abs_error'],
                  'tendency_max_abs_error':tendencies['max_abs_error'],
                  'precipitation_max_abs_error':sinks['max_abs_error'],
                  'configuration_sha256':digest(work/'configuration.json')}
            multi.verify(work)
            multi.write(work/'gate_results.json',gate)
            if not gate['passed']:
                multi.write(work/'status.json',{'state':'gate_failed_pending_review',
                            'actual_duration_seconds':600,'gate':gate,'three_hour_started':False})
                return
        gate=json.loads((work/'gate_results.json').read_text())
        if not gate['passed']:return
        if gate['configuration_sha256']!=digest(work/'configuration.json'):raise ValueError('Gate configuration changed')
        if gate_only:
            multi.write(work/'status.json',{'state':'gates_passed','actual_duration_seconds':600,'three_hour_started':False})
            return
        children=[]
        try:
            for name in ('matlab','fortran'):
                children.append(multi.launch_child(work,'full',name,cfg))
            multi.monitor(work,'full',children)
        except BaseException:
            import signal
            for child in children:
                if child['process'].poll() is None:os.killpg(child['process'].pid,signal.SIGTERM)
            raise
        result=multi.compare_states(work,'full',strict=False)
        result['thread_evidence']=multi.thread_evidence(work,'full')
        for name in ('matlab','fortran'):
            a=multi.state_frames(work,'gate_native',name,151)
            b=multi.state_frames(work,'full',name,181)
            # Long-run records are sixty seconds apart; gate records are four seconds apart.
            for i,state in enumerate(a):
                if i%15==0 and not np.array_equal(state,next(b)):
                    raise ValueError(name+': three-hour prefix differs from gate')
        result['exact_gate_prefix_identity_matlab_fortran']=[True,True]
        multi.verify(work)
        multi.write(work/'full_state_results.json',result)
        multi.write(work/'status.json',{'state':'completed_pending_scientific_review',
                    'actual_duration_seconds':10800,'saved_states':181,
                    'max_abs_error':result['max_abs_error']})
    except BaseException as exc:
        multi.write(work/'status.json',{'state':'failed','error':str(exc)})
        raise


def launch(work):
    multi.verify(work)
    with (work/'supervisor.log').open('x') as log:
        child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],
            cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,
            start_new_session=True,close_fds=True)
    multi.write(work/'supervisor.json',{'pid':child.pid,'work':str(work)})
    print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--gate-only',action='store_true')
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--prepare',action='store_true')
    action.add_argument('--launch',action='store_true')
    action.add_argument('--run',action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work)
    if args.launch:launch(work)
    if args.run:run(work,gate_only=args.gate_only)
