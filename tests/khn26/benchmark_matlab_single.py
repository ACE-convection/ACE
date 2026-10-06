#!/usr/bin/env python3
"""Run frozen KHN26 MATLAB for 15 minutes with one computational thread."""
import argparse
import difflib
import json
import os
from pathlib import Path
import re
import subprocess
import time

import numpy as np
from single import ROOT, digest
from trajectory import replace_once

BASE=ROOT/'migration_work/khn26_single_3h'
REFERENCE=ROOT/'migration_work/khn26_single_serial_15min'


def prepare(work):
    case=json.loads((BASE/'single_case.json').read_text())
    original=BASE/'single_main.m'
    if digest(original)!=case['generated_sha256']['single_main.m']:
        raise ValueError('Frozen MATLAB source changed')
    if digest(case['input'])!=case['input_sha256']:
        raise ValueError('Input changed')
    work.mkdir(parents=True,exist_ok=False)
    source=replace_once(original.read_text(),'tspan = 0:60:10800;','tspan = 0:60:900;')
    source=source.replace(str(BASE),str(work))
    source=replace_once(source,'tic;\nX = timeint(',
                        'ace_single_cpu_started=cputime;\ntic;\nX = timeint(')
    source=replace_once(source,'Tcost = toc;',
        "Tcost = toc;\nace_single_cpu_seconds=cputime-ace_single_cpu_started;\n"
        "fprintf('ACE_SINGLE_MEASUREMENT %.17g %.17g\\n',Tcost,ace_single_cpu_seconds);")
    main=work/'single_main.m';main.write_text(source)
    (work/'duration_paths_cpu.diff').write_text(''.join(difflib.unified_diff(
        original.read_text().splitlines(True),source.splitlines(True))))
    launch=work/'full_launch.m'
    launcher=(BASE/'full_launch.m').read_text().replace(str(BASE),str(work))
    launch.write_text("ace_cap=maxNumCompThreads;\nassert(ace_cap==1,'Expected one computational thread');\n"
        "fprintf('ACE_SINGLE_THREAD_CAP %d\\n',ace_cap);\n"+launcher+
        "assert(maxNumCompThreads==1,'Computational cap changed');\n")
    paths=[original,BASE/'full_launch.m',Path(case['input']),main,launch,
           ROOT/'matlab/util_timeint/ssprk93.m',REFERENCE/'full_matlab_states.bin',
           ROOT/'tests/khn26/serial_benchmark_results.json',
           ROOT/'tests/basis_layout/blocked_15min_results.json',Path(__file__).resolve()]
    cfg=dict(case=case,duration_seconds=900,steps=225,dt_seconds=4,
        command=['matlab','-singleCompThread','-batch',f"run('{launch}')"],
        sha256={str(p):digest(p) for p in paths},
        environment={k:os.environ.get(k) for k in ('OMP_NUM_THREADS','MKL_NUM_THREADS',
                      'OPENBLAS_NUM_THREADS','MATLAB_PREFDIR')},
        cpu_affinity=sorted(os.sched_getaffinity(0)),
        settings='Original frozen MATLAB expression and driver; startup -singleCompThread. '
                 'No section timers, thread setter or affinity pinning. CPU time sampled '
                 'outside the original integration wall timer.')
    (work/'configuration.json').write_text(json.dumps(cfg,indent=2)+'\n')
    (work/'benchmark_runner.py').write_bytes(Path(__file__).read_bytes())
    print('Prepared '+str(work),flush=True)


def run(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for path,expected in cfg['sha256'].items():
        if digest(path)!=expected:raise ValueError('Provenance changed: '+path)
    started=time.monotonic()
    log=work/'full_matlab.log'
    with log.open('x') as out:
        child=subprocess.Popen(cfg['command'],cwd=work,stdout=out,
                               stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
        while child.poll() is None:
            (work/'status.json').write_text(json.dumps(dict(state='running',pid=child.pid,
                elapsed_process_wall_seconds=time.monotonic()-started))+'\n')
            try:child.wait(timeout=20)
            except subprocess.TimeoutExpired:pass
    wall=time.monotonic()-started
    if child.returncode:
        (work/'status.json').write_text(json.dumps(dict(state='failed',exit_code=child.returncode))+'\n')
        raise RuntimeError('MATLAB failed; inspect '+str(log))
    text=log.read_text()
    match=re.search(r'ACE_SINGLE_MEASUREMENT\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)',text)
    cap=re.search(r'ACE_SINGLE_THREAD_CAP\s+(\d+)',text)
    if not match or not cap or int(cap[1])!=1:raise ValueError('Timing/thread evidence missing')
    seconds,cpu=map(float,match.groups())
    state=work/'full_matlab_states.bin'
    reference=REFERENCE/'full_matlab_states.bin'
    n,z,count=101,401,16
    if state.stat().st_size!=count*n*z*3*8:raise ValueError('Incomplete states')
    states=np.memmap(state,'<f8',mode='r',shape=(count,n*z*3))
    refs=np.memmap(reference,'<f8',mode='r',shape=(count,n*z*3))
    errors=[]
    for index in range(count):
        x=states[index].reshape((n,z,3),order='F')
        r=refs[index].reshape((n,z,3),order='F')
        if not np.all(np.isfinite(x)) or np.any(x[:,:,2]<0):
            raise ValueError('Nonfinite fields or negative qt')
        errors.append(np.max(np.abs(x-r),axis=(0,1)).tolist())
    identical=digest(state)==digest(reference)
    baseline=json.loads((ROOT/'tests/khn26/serial_benchmark_results.json').read_text())
    optimized=json.loads((ROOT/'tests/basis_layout/blocked_15min_results.json').read_text())
    result=dict(duration_seconds=900,steps=225,dt_seconds=4,saved_states=16,
        computational_thread_cap=1,integration_wall_seconds=seconds,
        integration_cpu_seconds=cpu,cpu_to_wall_ratio=cpu/seconds,
        process_wall_seconds=wall,wall_seconds_per_step=seconds/225,
        binary_identical_to_default_matlab=identical,
        max_abs_error_vs_default_each_state_MF_theta_e_qt=errors,
        max_abs_error_vs_default_MF_theta_e_qt=np.max(errors,axis=0).tolist(),
        finite_saved_states=True,nonnegative_saved_qt=True,
        comparison_seconds_per_step=dict(matlab_single=seconds/225,
            matlab_default_previous=baseline['wall_seconds_per_step']['matlab'],
            fortran_original_serial_previous=baseline['wall_seconds_per_step']['fortran'],
            fortran_outputs4_serial_previous=optimized['wall_seconds_per_step']['fortran_outputs4']),
        default_to_single_speedup=seconds/baseline['integration_wall_seconds']['matlab'],
        sha256={str(state):digest(state),str(log):digest(log)},
        configuration=cfg,
        limits='One fresh-process 225-step run on a shared host. One computational thread '
               'does not exclude MATLAB background threads; cap and CPU/wall provide evidence. '
               'Other timings are previous measurements, not fresh concurrent controls. '
               'Thread-dependent reduction changes, if any, are reported rather than hidden. '
               'Saved-state agreement does not test independent conservation budgets.')
    for path,expected in cfg['sha256'].items():
        if digest(path)!=expected:raise ValueError('Provenance changed: '+path)
    result['provenance_rechecked']=True
    (work/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    (work/'status.json').write_text(json.dumps(dict(state='completed',exit_code=0))+'\n')
    print(json.dumps({k:result[k] for k in ('wall_seconds_per_step','cpu_to_wall_ratio',
        'comparison_seconds_per_step','binary_identical_to_default_matlab',
        'max_abs_error_vs_default_MF_theta_e_qt')},indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--run',action='store_true')
    args=parser.parse_args()
    if args.run:run(args.work.resolve())
    else:prepare(args.work.resolve())
