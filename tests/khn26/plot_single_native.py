#!/usr/bin/env python3
"""Inspect completed native singleACE states without rerunning the model."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from netCDF4 import Dataset

import multi
from run import digest


def plot(work,out):
    report=json.loads((work/'full_state_results.json').read_text());case=report['case']
    if case['multiACE'] or case['physics']!='native' or report['saved_states']!=181:
        raise ValueError('Expected completed three-hour native singleACE case')
    for name in ['matlab_states.bin','fortran_states.bin','matlab.nc']:
        if digest(work/'full'/name)!=report['artifacts_sha256'][name]:raise ValueError('Changed artifact: '+name)
    with Dataset(case['input']) as ds:
        z=np.asarray(ds['z'][:400])/1000;zm=np.asarray(ds['zm'][:])/1000
        rho=np.asarray(ds['rho_zc'][:400]);rhom=np.asarray(ds['rho_mf'][:])
        area=np.asarray(ds['ace_area'][:]);dz=float(ds['dz'][...])
        reference=np.stack([ds['theta_e_zc'][:400],ds['qt_zc'][:400]],axis=1)
    t=np.asarray(report['time_seconds'])/3600
    if not np.array_equal(t,np.arange(181)/60):raise ValueError('Incomplete time axis')
    active=np.zeros((2,181,401,3));water=np.zeros((2,181));column=np.zeros((2,181));ke=np.zeros((2,181));mean=np.zeros((2,181))
    fractions=area/area.sum();weights=fractions[:,None]*rho[None,:]*dz
    edge_weights=np.full(401,dz);edge_weights[[0,-1]]*=.5
    for i,(m,f) in enumerate(zip(multi.state_frames(work,'full','matlab',181),multi.state_frames(work,'full','fortran',181))):
        for language,state in enumerate((m,f)):
            if not np.isfinite(state).all() or np.min(state[:,:,2])<0:raise ValueError('Invalid saved state')
            active[language,i]=state[0]
            water[language,i]=np.sum(state[:,:400,2]*weights)
            column[language,i]=np.sum(state[0,:400,2]*rho*dz)
            ke[language,i]=.5*np.sum(fractions[:,None]*state[:,:,0]**2/rhom[None,:]*edge_weights[None,:])
            mean[language,i]=np.max(np.abs(np.sum(state[:,:,0]*fractions[:,None],axis=0)))
    out.mkdir(parents=True,exist_ok=True)
    plt.rcParams.update({'font.size':10,'axes.formatter.use_mathtext':True})

    def save(fig,name):
        for extension in ['png','pdf']:fig.savefig(out/(name+'.'+extension),dpi=180)
        plt.close(fig)

    fig,axes=plt.subplots(3,3,figsize=(15,10),layout='constrained')
    fields=[active[:,:,:,0],active[:,:,:400,1]-reference[None,None,:,0],1000*(active[:,:,:400,2]-reference[None,None,:,1])]
    names=['MF','theta_e anomaly','qt anomaly']
    units=['kg m$^{-2}$ s$^{-1}$','K','g kg$^{-1}$']
    for row,(field,name,unit) in enumerate(zip(fields,names,units)):
        height=zm if row==0 else z;visible=height<=20
        matrices=[field[0][:,visible],field[1][:,visible],(field[1]-field[0])[:,visible]]
        bound=max(np.max(np.abs(matrices[0])),np.max(np.abs(matrices[1]))) or 1
        for col,data in enumerate(matrices):
            limit=(np.max(np.abs(data)) or 1e-30) if col==2 else bound
            mesh=axes[row,col].pcolormesh(t,height[visible],data.T,shading='nearest',cmap='RdBu_r',vmin=-limit,vmax=limit,rasterized=True)
            axes[row,col].set(title=['MATLAB','Fortran','Fortran minus MATLAB'][col]+' / '+name,
                xlabel='Time (hours)',ylabel='Height (km)',xlim=(0,3),ylim=(0,20))
            fig.colorbar(mesh,ax=axes[row,col],label=unit)
    fig.suptitle('KHN26 singleACE / native precipitation / ACE 1 / three hours\nAnomalies are relative to the reference profile; difference panels use amplified color scales')
    save(fig,'time_height_comparison')

    fig,axes=plt.subplots(1,3,figsize=(14,6),layout='constrained')
    records=[0,10,60,120,180];colors=plt.cm.viridis(np.linspace(0,1,len(records)))
    for record,color in zip(records,colors):
        for language,style in [(0,'-'),(1,'--')]:
            values=[active[language,record,:,0],active[language,record,:400,1]-reference[:,0],active[language,record,:400,2]*1000]
            for col,value in enumerate(values):
                axes[col].plot(value,zm if col==0 else z,style,color=color,lw=1.5,label=f'{record} min' if language==0 else None)
    for ax,title,unit in zip(axes,['MF','theta_e anomaly','Total water'],units):
        ax.set(title=title,xlabel=unit,ylabel='Height (km)',ylim=(0,20));ax.grid(alpha=.2)
    axes[0].legend();fig.suptitle('ACE 1 profiles / solid: MATLAB, dashed: Fortran / native precipitation')
    save(fig,'vertical_profiles')

    errors=np.asarray(report['max_abs_error_each_state'])
    fig,axes=plt.subplots(2,3,figsize=(14,8),layout='constrained')
    for col,(field,unit) in enumerate(zip(['MF','theta_e','qt'],['kg m$^{-2}$ s$^{-1}$','K','kg kg$^{-1}$'])):
        axes[0,col].semilogy(t,np.where(errors[:,col]>0,errors[:,col],np.nan),color='tab:purple')
        axes[0,col].axhline(multi.STATE_LIMITS[col],color='tab:red',ls=':',label='10-minute regression limit')
        axes[0,col].set(title='All ACEs / max '+field+' difference',xlabel='Time (hours)',ylabel=unit,xlim=(0,3))
        axes[0,col].legend(fontsize=8);axes[0,col].grid(alpha=.2)
    series=[np.max(active[:,:,:,0],axis=2),np.max(active[:,:,:,0]/rhom[None,None,:],axis=2),ke]
    for ax,data,title,unit in zip(axes[1],series,['ACE 1 maximum MF','ACE 1 maximum vertical velocity','Domain vertical kinetic energy'],['kg m$^{-2}$ s$^{-1}$','m s$^{-1}$','J m$^{-2}$']):
        for language,label,style in [(0,'MATLAB','-'),(1,'Fortran','--')]:ax.plot(t,data[language],style,label=label)
        ax.set(title=title,xlabel='Time (hours)',ylabel=unit,xlim=(0,3));ax.grid(alpha=.2);ax.legend()
    fig.suptitle('Numerical differences and vertical-flow diagnostics\nShort-test limits shown; zero errors omitted on log axes; vertical KE is not total energy')
    save(fig,'agreement_and_flow')

    fig,axes=plt.subplots(1,3,figsize=(14,4.5),layout='constrained')
    for ax,data,title in [(axes[0],water-water[:,0,None],'Domain mean water inventory change'),(axes[1],column-column[:,0,None],'ACE 1 water inventory change')]:
        for language,label,style in [(0,'MATLAB','-'),(1,'Fortran','--')]:ax.plot(t,data[language],style,label=label)
        ax.set(title=title,xlabel='Time (hours)',ylabel='kg m$^{-2}$',xlim=(0,3));ax.grid(alpha=.2);ax.legend()
    for language,label,style in [(0,'MATLAB','-'),(1,'Fortran','--')]:axes[2].semilogy(t[1:],np.maximum(mean[language,1:],1e-30),style,label=label)
    axes[2].set(title='Area mean MF residual after initial state',xlabel='Time (hours)',ylabel='kg m$^{-2}$ s$^{-1}$',xlim=(0,3));axes[2].legend();axes[2].grid(alpha=.2)
    fig.suptitle('Water storage and MF constraint / precipitation, mixing and damping all affect storage\nInventory change is not surface rain or a closed water budget')
    save(fig,'water_and_constraint')
    peaks=[]
    for language in range(2):
        i,k=np.unravel_index(np.argmax(active[language,:,:,0]),(181,401))
        peaks.append({'time_minutes':int(i),'height_km':float(zm[k]),'MF':float(active[language,i,k,0]),
            'max_vertical_velocity_m_s':float(np.max(active[language,:,:,0]/rhom[None,:]))})
    summary={'source_work':str(work),'case':case,'saved_states':181,'max_abs_error':report['max_abs_error'],
        'relative_L2_error':report['relative_L2_error'],'peak_updraft_matlab_fortran':peaks,
        'domain_water_change_kg_m2_matlab_fortran':(water[:,-1]-water[:,0]).tolist(),
        'ACE1_water_change_kg_m2_matlab_fortran':(column[:,-1]-column[:,0]).tolist(),
        'vertical_KE_initial_peak_final_matlab_fortran':[[float(v[0]),float(v.max()),float(v[-1])] for v in ke],
        'area_mean_MF_max_after_initial_matlab_fortran':mean[:,1:].max(axis=1).tolist(),
        'source_report_sha256':digest(work/'full_state_results.json'),'plotter_sha256':digest(Path(__file__)),
        'scope':'SingleACE with full basis and other ACE dynamics masked. Descriptive stored-state diagnostics; not a multiACE gravity-wave test or closed precipitation/energy budget.',
        'figures':[str(out/(name+'.png')) for name in ['time_height_comparison','vertical_profiles','agreement_and_flow','water_and_constraint']]}
    multi.write(out/'review.json',summary)
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();plot(args.work.resolve(),args.output.resolve())
