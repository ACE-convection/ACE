#!/usr/bin/env python3
"""Plot completed KHN26 multiACE MF spatial responses and selected ACE panels."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def plot(work,tag):
    report=json.loads((work/(tag+'_state_results.json')).read_text())
    with np.load(work/tag/'mf_all_aces.npz') as ds:
        t=ds['time_seconds']/3600;z=ds['height_m']/1000
        matlab=ds['matlab'];fortran=ds['fortran'];centers=ds['x_center_m']/1000
    if matlab.shape!=fortran.shape or len(t)!=report['saved_states'] or t[-1]*3600!=report['actual_duration_seconds']:
        raise ValueError('Figure arrays do not match completed report')
    out=work/tag/'comparison';out.mkdir(exist_ok=True)
    edges=np.r_[0,np.cumsum(report['case']['ace_width_m'])]/1000
    dt=(t[1]-t[0])/2;time_edges=np.r_[t[0]-dt,t+dt]
    levels=[int(np.argmin(np.abs(z-height))) for height in (1,5,10)]
    fig,axes=plt.subplots(3,3,figsize=(15,11),sharex=True,sharey=True,layout='constrained')
    for row,k in enumerate(levels):
        fields=[matlab[:,:,k],fortran[:,:,k],fortran[:,:,k]-matlab[:,:,k]]
        bound=max(np.max(np.abs(fields[0])),np.max(np.abs(fields[1]))) or 1
        for col,field in enumerate(fields):
            limit=(np.max(np.abs(field)) or 1) if col==2 else bound
            mesh=axes[row,col].pcolormesh(time_edges,edges,field.T,shading='flat',cmap='RdBu_r',vmin=-limit,vmax=limit,rasterized=True)
            axes[row,col].set(title=['MATLAB','Fortran','Fortran minus MATLAB'][col]+f' / z={z[k]:g} km',
                              xlim=(t[0],t[-1]),ylim=(0,edges[-1]),ylabel='Distance from left boundary (km)',xlabel='Time (hours)')
            fig.colorbar(mesh,ax=axes[row,col],label='MF (kg m-2 s-1)')
    physics='none' if tag=='gate_none' else 'native precipitation'
    fig.suptitle(f'KHN26 multiACE: bubble-driven spatial MF response / {physics} / {t[-1]:g} hours')
    for ext in ('png','pdf'):fig.savefig(out/('spatial_mf.'+ext),dpi=160)
    plt.close(fig)
    selected=[0,1,9,49,99];vertical=z<=20
    fig,axes=plt.subplots(len(selected),3,figsize=(15,13),sharex=True,sharey=True,layout='constrained')
    for row,ace in enumerate(selected):
        fields=[matlab[:,ace,vertical],fortran[:,ace,vertical],fortran[:,ace,vertical]-matlab[:,ace,vertical]]
        bound=max(np.max(np.abs(fields[0])),np.max(np.abs(fields[1]))) or 1
        for col,field in enumerate(fields):
            limit=(np.max(np.abs(field)) or 1) if col==2 else bound
            mesh=axes[row,col].pcolormesh(t,z[vertical],field.T,shading='nearest',cmap='RdBu_r',vmin=-limit,vmax=limit,rasterized=True)
            axes[row,col].set(title=['MATLAB','Fortran','Fortran minus MATLAB'][col]+f' / ACE {ace+1} / x={centers[ace]:g} km',
                              xlabel='Time (hours)',ylabel='Height (km)',xlim=(t[0],t[-1]),ylim=(0,20))
            fig.colorbar(mesh,ax=axes[row,col],label='MF (kg m-2 s-1)')
    fig.suptitle(f'KHN26 multiACE selected columns / {physics} / {t[-1]:g} hours')
    for ext in ('png','pdf'):fig.savefig(out/('selected_aces.'+ext),dpi=160)
    plt.close(fig)
    (out/'scope.json').write_text(json.dumps({'tag':tag,'actual_duration_seconds':report['actual_duration_seconds'],
        'saved_states':report['saved_states'],'selected_ACE_one_based':[v+1 for v in selected],
        'selected_heights_km':z[levels].tolist(),
        'scope':'Descriptive MF response; nonlocal pressure and mean-MF projection can cause immediate remote response. Phase/arrival interpretation needs review.'},indent=2)+'\n')
    print(str(out))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--tag',choices=['gate_none','gate_native','full'],default='full')
    args=parser.parse_args();plot(args.work.resolve(),args.tag)
