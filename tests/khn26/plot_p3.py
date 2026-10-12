#!/usr/bin/env python3
"""Plot completed real64 P3 singleACE and multiACE saved-state evolution."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from netCDF4 import Dataset

from p3_smoke import sha


def frames(path, nv):
    n,z,fields=np.fromfile(path,'<i4',count=3)
    if (n,z,fields)!=(101,401,nv): raise ValueError('Unexpected state dimensions')
    size=102*401*nv*8
    if path.stat().st_size!=12+181*size+401*8: raise ValueError('Incomplete three-hour stream')
    for minute in range(181):
        offset=12+minute*size+(401*8 if minute else 0)
        yield np.memmap(path,'<f8',mode='r',offset=offset,shape=(102*401*nv,)).reshape((102,401,nv),order='F')[:101]


def plot(work,out):
    cfg=json.loads((work/'configuration.json').read_text())
    if cfg['duration_seconds']!=10800: raise ValueError('Expected three hours')
    input_path=Path(cfg['case']['input'])
    if sha(input_path)!=cfg['case']['input_sha256']: raise ValueError('Input hash changed')
    with Dataset(input_path) as ds:
        scalar_z=np.asarray(ds['z'][:400])/1000
        mf_z=np.asarray(ds['zm'][:])/1000
        width=np.asarray(ds['ace_width'][:])/1000
    xedges=np.r_[0,np.cumsum(width)]
    out.mkdir(parents=True,exist_ok=True)
    t=np.arange(181)/60
    report=dict(source_work=str(work),precision='Fortran real64 model states',input_sha256=cfg['case']['input_sha256'],
        saved_states=181,model_duration_seconds=10800,field_order=cfg['case']['field_order'],
        scope='Descriptive minute-saved state plots, no scientific acceptance threshold or closed water budget.',cases={})

    def save(fig,name):
        for ext in ('png','pdf'): fig.savefig(out/(name+'.'+ext),dpi=160,bbox_inches='tight')
        plt.close(fig)

    for case in ('singleACE','multiACE'):
        path=work/case/'full/states.bin'
        result=json.loads((work/case/'full/results.json').read_text())
        if not result['passed'] or sha(path)!=result['state_sha256']: raise ValueError('Invalid or changed P3 result')
        active=np.empty((181,401,11)); mf=np.empty((181,101,401))
        for minute,v in enumerate(frames(path,11)):
            if not np.isfinite(v).all(): raise ValueError('Nonfinite saved state')
            active[minute]=v[0]; mf[minute]=v[:,:,0]
        qt=active[:,:400,2]+active[:,:400,3]+active[:,:400,5]+active[:,:400,7]
        fields=[active[:,:,0],active[:,:400,1]-active[0,:400,1],1000*(qt-qt[0]),
                1000*active[:,:400,3],1000*active[:,:400,5],1000*active[:,:400,7]]
        labels=['MF','theta change from initial state','Total water change from initial state','Cloud water qc','Rain water qr','Total ice qi']
        units=['kg m$^{-2}$ s$^{-1}$','K','g kg$^{-1}$','g kg$^{-1}$','g kg$^{-1}$','g kg$^{-1}$']
        fig,axes=plt.subplots(2,3,figsize=(15,8),layout='constrained')
        for i,(ax,field,label,unit) in enumerate(zip(axes.flat,fields,labels,units)):
            height=mf_z if i==0 else scalar_z
            keep=height<=20; data=field[:,keep]; limit=float(np.max(np.abs(data))) or 1
            mesh=ax.pcolormesh(t,height[keep],data.T,shading='nearest',rasterized=True,
                cmap='RdBu_r' if i<3 else 'viridis',vmin=-limit if i<3 else 0,vmax=limit)
            ax.set(title=label,xlabel='Time (hours)',ylabel='Height (km)',xlim=(0,3),ylim=(0,20))
            fig.colorbar(mesh,ax=ax,label=unit)
        fig.suptitle(f'P3 / Fortran real64 / {case} / ACE 1 / three hours')
        save(fig,case+'_time_height')
        fig,axes=plt.subplots(2,3,figsize=(15,8),layout='constrained')
        for ax,index,label,unit in zip(axes.flat,(4,6,8,9,10,7),
                ('Cloud number nc','Rain number nr','Ice number ni','Rime mass qrim','Rime volume brim','Rimed fraction qrim/qi'),
                ('number kg$^{-1}$','number kg$^{-1}$','number kg$^{-1}$','g kg$^{-1}$','m$^3$ kg$^{-1}$','fraction')):
            field=active[:,:400,index].copy()
            if index==9: field*=1000
            if index==7:
                field=np.divide(active[:,:400,9],field,out=np.full_like(field,np.nan),where=field>0)
            keep=scalar_z<=20; data=field[:,keep]
            limit=1 if index==7 else (float(np.nanmax(data)) or 1)
            mesh=ax.pcolormesh(t,scalar_z[keep],data.T,shading='nearest',cmap='viridis',vmin=0,vmax=limit,rasterized=True)
            ax.set(title=label,xlabel='Time (hours)',ylabel='Height (km)',xlim=(0,3),ylim=(0,20))
            fig.colorbar(mesh,ax=ax,label=unit)
        fig.suptitle(f'P3 / Fortran real64 / {case} / ACE 1 microphysics\nRimed fraction masked where total ice is zero')
        save(fig,case+'_microphysics')
        minute,ace,k=np.unravel_index(np.argmax(np.abs(mf)),mf.shape)
        report['cases'][case]=dict(state_sha256=result['state_sha256'],
            peak_absolute_MF=dict(time_minutes=int(minute),ACE_column=int(ace+1),height_km=float(mf_z[k]),value=float(mf[minute,ace,k])),
            all_saved_values_finite=True,field_minimum=result['field_minimum'],field_maximum=result['field_maximum'])
        if case=='multiACE':
            fig,axes=plt.subplots(1,3,figsize=(15,5),layout='constrained')
            for ax,height in zip(axes,(1,5,10)):
                k=int(np.argmin(abs(mf_z-height))); data=mf[:,:,k]; limit=float(np.max(abs(data))) or 1
                mesh=ax.pcolormesh(t,(xedges[:-1]+xedges[1:])/2,data.T,shading='nearest',
                    cmap='RdBu_r',vmin=-limit,vmax=limit,rasterized=True)
                ax.set(title=f'MF / height {mf_z[k]:g} km',xlabel='Time (hours)',ylabel='Distance (km)',xlim=(0,3),ylim=(0,500))
                fig.colorbar(mesh,ax=ax,label='kg m$^{-2}$ s$^{-1}$')
            fig.suptitle('P3 / Fortran real64 / multiACE / spatial MF evolution')
            save(fig,'multiACE_spatial_mf')
            fig,axes=plt.subplots(6,1,figsize=(14,12),layout='constrained',sharex=True,sharey=True)
            keep=mf_z<=20; h=mf_z[keep]; he=np.r_[h[0]-.05,(h[:-1]+h[1:])/2,h[-1]+.05]
            for ax,minute in zip(axes,range(30,181,30)):
                mesh=ax.pcolormesh(xedges,he,mf[minute][:,keep].T,shading='flat',cmap='RdBu_r',vmin=-1,vmax=1,rasterized=True)
                ax.set(title=f'{minute} min',xlabel='Distance (km)',ylabel='Height (km)',xlim=(0,500),ylim=(0,20));ax.set_box_aspect(.2)
            fig.colorbar(mesh,ax=axes,orientation='horizontal',shrink=.6,extend='both',label='MF (kg m$^{-2}$ s$^{-1}$)')
            fig.suptitle('P3 / Fortran real64 / multiACE / 30–180 min MF snapshots / colors clipped at +/-1')
            save(fig,'multiACE_mf_snapshots')
    (out/'review_results.json').write_text(json.dumps(report,indent=2)+'\n')
    (out/'source_configuration.json').write_bytes((work/'configuration.json').read_bytes())
    manifest={p.name:sha(p) for p in out.iterdir() if p.is_file() and p.name!='manifest.json'}
    manifest['plot_script_sha256']=sha(Path(__file__))
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path); parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); plot(args.work.resolve(),args.output.resolve())
