#!/usr/bin/env python3
"""Plot native Fortran and Fortran P3 MF in the established paired snapshot layout."""
import argparse
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from netCDF4 import Dataset

from p3_smoke import sha
from plot_p3 import frames


def plot(p3_work,native_work,case_name,out):
    p3cfg=json.loads((p3_work/'configuration.json').read_text())
    nativecfg=json.loads((native_work/'configuration.json').read_text())
    native_report=json.loads((native_work/'full_state_results.json').read_text())
    p3_report=json.loads((p3_work/case_name/'full/results.json').read_text())
    native_case=nativecfg['case']; p3_case=p3cfg['case']
    if native_case['multiACE']!=(case_name=='multiACE') or native_case['physics']!='native':
        raise ValueError('Wrong native case')
    for key in ('input_sha256','dt_seconds','bubble_delta_K'):
        if native_case[key]!=p3_case[key]: raise ValueError('Different comparison case setting: '+key)
    if native_report['saved_states']!=181 or native_report['actual_duration_seconds']!=10800:
        raise ValueError('Native run is not complete three hours')
    if not p3_report['passed'] or p3_report['complete_saved_states']!=181:
        raise ValueError('P3 run is incomplete or invalid')
    input_path=Path(p3_case['input'])
    if sha(input_path)!=p3_case['input_sha256']: raise ValueError('Input changed')
    with Dataset(input_path) as ds:
        height=np.asarray(ds['zm'][:])/1000
    if not np.array_equal(height,np.asarray(native_case['height_m'])/1000):
        raise ValueError('MF heights differ')
    paths=[native_work/'full/fortran_states.bin',p3_work/case_name/'full/states.bin']
    expected=[native_report['artifacts_sha256']['fortran_states.bin'],p3_report['state_sha256']]
    for path,digest in zip(paths,expected):
        if sha(path)!=digest: raise ValueError('Changed state stream: '+str(path))
    selected=range(20,161,20)
    snapshots=[]
    initial=[]
    for path,nv in zip(paths,(3,11)):
        values={}
        for minute,state in enumerate(frames(path,nv)):
            if minute==0: initial.append(float(np.max(np.abs(state[:,:,0]))))
            if minute in selected:
                field=state[:,:,0].copy()
                if not np.isfinite(field).all(): raise ValueError('Nonfinite MF snapshot')
                values[minute]=field
        snapshots.append(values)
    out.mkdir(parents=True,exist_ok=True)
    fig=plt.figure(figsize=(16,16))
    panel_w,panel_h=6.5,1.3
    gap,top=.48,14.6
    records=[]
    for row,minute in enumerate(selected):
        for col,label in enumerate(('Fortran','Fortran P3')):
            ax=fig.add_axes([(.8+col*7.6)/16,(top-row*(panel_h+gap)-panel_h)/16,panel_w/16,panel_h/16])
            field=snapshots[col][minute]
            mesh=ax.pcolormesh(np.arange(1,102),height,field.T,shading='nearest',
                cmap='RdBu_r',vmin=-1,vmax=1,rasterized=True)
            ax.set(xlim=(.5,101.5),ylim=(0,20),ylabel='Height (km)',title=f'{minute} min')
            ax.set_xticks([1,20,40,60,80,101])
            if row==7: ax.set_xlabel('ACE column')
            else: ax.tick_params(labelbottom=False)
            records.append(dict(implementation=label,time_minutes=minute,
                mf_min=float(field.min()),mf_max=float(field.max()),
                mf_sha256=hashlib.sha256(field.tobytes()).hexdigest()))
    fig.text(4.05/16,15.35/16,'Fortran',ha='center',fontsize=17)
    fig.text(11.65/16,15.35/16,'Fortran P3',ha='center',fontsize=17)
    fig.text(.5,15.02/16,f'{case_name} / both real64 / native precipitation left, P3 right',ha='center',fontsize=11)
    cax=fig.add_axes([.33,.027,.34,.012])
    fig.colorbar(mesh,cax=cax,orientation='horizontal',extend='both',ticks=[-1,-.5,0,.5,1],
        label='MF (kg m$^{-2}$ s$^{-1}$)')
    matched_initial=native_case['initial_mf_amplitude']==p3_case['initial_MF']
    if not matched_initial:
        fig.text(.5,.009,'Initial MF pulse differs: native amplitude 0.03; P3 zero MF. Preserved-run comparison.',
            ha='center',fontsize=10)
    stem=case_name+'_mf_20min_snapshots'
    for ext in ('png','pdf'): fig.savefig(out/(stem+'.'+ext),dpi=180)
    plt.close(fig)
    report=dict(case=case_name,left='Fortran native precipitation real64',right='Fortran P3 real64',
        native_workspace=str(native_work),p3_workspace=str(p3_work),
        native_state_sha256=expected[0],p3_state_sha256=expected[1],
        native_configuration_sha256=sha(native_work/'configuration.json'),
        p3_configuration_sha256=sha(p3_work/'configuration.json'),
        input_sha256=p3_case['input_sha256'],dt_seconds=4,bubble_delta_K=1,
        saved_states=181,run_duration_seconds=10800,snapshot_minutes=list(selected),
        height_km=[0,20],color_limits=[-1,1],panel_height_to_width=[1,5],
        x_axis='ACE column index 1–101; unequal physical widths are not represented as distance',
        initial_MF_matches=matched_initial,initial_MF_amplitude_native=native_case['initial_mf_amplitude'],
        initial_MF_amplitude_P3=p3_case['initial_MF'],initial_max_abs_MF_native_P3=initial,
        records=records,scope='Descriptive MF-only comparison of preserved runs with different physics; not a precision-error or physics-only attribution test.')
    (out/(stem+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    (out/(case_name+'_native_configuration.json')).write_bytes((native_work/'configuration.json').read_bytes())
    print(json.dumps({'case':case_name,'figure':str(out/(stem+'.png')),'initial_MF_matches':matched_initial}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('p3_work',type=Path)
    parser.add_argument('--native-single',type=Path,required=True)
    parser.add_argument('--native-multi',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); out=args.output.resolve()
    for name,work in (('singleACE',args.native_single),('multiACE',args.native_multi)):
        plot(args.p3_work.resolve(),work.resolve(),name,out)
    (out/'p3_configuration.json').write_bytes((args.p3_work/'configuration.json').read_bytes())
    manifest={p.name:sha(p) for p in out.iterdir() if p.is_file() and p.name!='manifest.json'}
    manifest['plot_script_sha256']=sha(Path(__file__))
    manifest['state_reader_sha256']=sha(Path(__file__).with_name('plot_p3.py'))
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
