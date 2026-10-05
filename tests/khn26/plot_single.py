#!/usr/bin/env python3
"""Use the v0.18 MF panel layout for KHN26 singleACE saved states.

Partial figures use only complete common saved timestamps and are explicitly
labelled. A watcher can make previews and the final plot without rerunning
the model. Use the same plotting dependencies as tests/alignment/plot_mf.py.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import numpy as np
from netCDF4 import Dataset

from run import ROOT, digest


def make_plot(work, tag, partial=False):
    case=json.loads((work/'single_case.json').read_text())
    mpath=work/f'{tag}_matlab_states.bin';fpath=work/f'{tag}_fortran_states.bin'
    n,z=101,401;mbytes=n*z*3*8;fbytes=(n+1)*z*3*8
    initial_bytes=12+fbytes+z*8
    if not mpath.exists() or not fpath.exists() or fpath.stat().st_size<initial_bytes:
        return None
    count=min(mpath.stat().st_size//mbytes,1+(fpath.stat().st_size-initial_bytes)//fbytes)
    expected=2 if tag=='smoke' else case['duration_seconds']//60+1
    count=min(count,expected)
    if count<2:return None
    if not partial:
        report_path=work/f'{tag}_results.json'
        if count!=expected or not report_path.exists():
            return None
        report=json.loads(report_path.read_text())
        for path in (mpath,fpath):
            if report['artifacts_sha256'][path.name]!=digest(path):
                raise ValueError('Completed-state hash differs from validation report')
    if not np.array_equal(np.fromfile(fpath,'<i4',count=3),[n,z,3]):
        raise ValueError('Unexpected Fortran state header')
    with Dataset(case['input']) as ds:height=np.asarray(ds['zm'][:])
    if digest(case['input'])!=case['input_sha256']:
        raise ValueError('Plot input hash differs from run configuration')
    times=np.array([0,case['dt_seconds']]) if tag=='smoke' else np.arange(count)*60
    out=work/('smoke_comparison' if tag=='smoke' else
              (f'preview_{int(times[-1]):06d}s' if partial else 'full_comparison'))
    if out.exists():
        if (out/'mf_three_panels.png').exists() and (out/'mf_three_panels.pdf').exists():return out
        raise ValueError(f'Incomplete plotting directory already exists: {out}')
    out.mkdir()
    m=np.memmap(mpath,'<f8',mode='r',shape=(count,mbytes//8))
    matlab=[];fortran=[]
    for t in range(count):
        state=m[t].reshape((n,z,3),order='F');matlab.append(state[0,:,0].copy())
        offset=12+(0 if t==0 else t*fbytes+z*8)
        state=np.memmap(fpath,'<f8',mode='r',offset=offset,shape=(fbytes//8,)).reshape((n+1,z,3),order='F')
        fortran.append(state[0,:,0].copy())
    if not np.isfinite(matlab).all() or not np.isfinite(fortran).all():
        raise ValueError('Nonfinite MF in plotted states')
    np.savez_compressed(out/'mf.npz',time_seconds=times,height_m=height,
                        matlab=np.asarray(matlab),fortran=np.asarray(fortran))
    scope='PARTIAL RUN' if partial else ('ONE-STEP CHECK' if tag=='smoke' else 'FULL 3-HOUR RUN')
    report={'case':f'KHN26 / Manaus — {scope}','profile_index':1342,
            'duration_seconds':float(times[-1]),'precipitation':case['physics'],
            'bubble':{'enabled':True},'fortran_label':'Fortran real64',
            'scope':scope,'configured_duration_seconds':case['duration_seconds'],
            'mean_mf_zero':case['mean_mf_zero'], 'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'source_files':{'matlab':str(mpath),'fortran':str(fpath)},
            'common_complete_saved_states':int(count),
            'input_sha256':case['input_sha256']}
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    subprocess.run([sys.executable,str(ROOT/'tests/alignment/plot_mf.py'),str(out)],check=True)
    report['artifacts_sha256']={p.name:digest(p) for p in out.iterdir() if p.suffix in ('.png','.pdf','.npz')}
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    return out


def watch(work):
    while True:
        state=json.loads((work/'single_status.json').read_text())
        if (work/'smoke_results.json').exists():make_plot(work,'smoke')
        final=make_plot(work,'full')
        if final:
            (work/'plot_status.json').write_text(json.dumps({'state':'completed','directory':str(final)},indent=2)+'\n')
            return
        if state['state']=='failed':
            (work/'plot_status.json').write_text(json.dumps({'state':'model_failed','model_status':state},indent=2)+'\n')
            return
        preview=make_plot(work,'full',partial=True)
        (work/'plot_status.json').write_text(json.dumps({'state':'waiting_for_full_run',
                                                       'latest_preview':str(preview) if preview else None},indent=2)+'\n')
        time.sleep(60)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--tag',choices=['smoke','full'],default='full')
    parser.add_argument('--partial',action='store_true')
    modes=parser.add_mutually_exclusive_group()
    modes.add_argument('--watch',action='store_true')
    modes.add_argument('--launch',action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.launch:
        with (work/'plot_watcher.log').open('x') as log:
            child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--watch'],
                                   stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,
                                   start_new_session=True,close_fds=True,env=os.environ.copy())
        (work/'plot_watcher.pid').write_text(str(child.pid)+'\n')
        print(f'Plot watcher started: {child.pid}')
    elif args.watch:watch(work)
    else:
        output=make_plot(work,args.tag,args.partial)
        if output:print(output)
        else:parser.exit(1,'No complete matched trajectory available for this plot.\n')
