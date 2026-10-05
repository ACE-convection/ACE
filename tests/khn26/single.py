#!/usr/bin/env python3
"""Prepare an isolated singleACE case using the complete KHN26 shared basis.

Case settings are explicit: no automatic choice of mean-MF policy or physics.
Only the existing dynamics tendency mask is enabled; physics and damping still
follow the original driver in all columns. No release sources are edited.
"""
import argparse
import difflib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from netCDF4 import Dataset

from run import ROOT, digest, prepare
from trajectory import replace_once


def create(work, case):
    input_file=ROOT/'data/input/manaus1342_khn26.nc'
    prepare(work,input_file)
    mean=case['mean_mf_zero']
    matlab_original=(ROOT/'matlab/ace.m').read_text()
    matlab=replace_once(matlab_original,"dir_ace = fileparts(mfilename('fullpath'));",
                        f"dir_ace = '{ROOT/'matlab'}';")
    matlab=replace_once(matlab,'one_ace_only = 0;','one_ace_only = 1;')
    matlab=replace_once(matlab,'Wbar_eq_zero = 1;',f'Wbar_eq_zero = {int(mean)};')
    matlab=replace_once(matlab,'dt = 6;',f"dt = {case['dt_seconds']};")
    matlab=replace_once(matlab,'tspan = [0:1:60*6]*60;',
                        f"tspan = 0:60:{case['duration_seconds']};")
    matlab=replace_once(matlab,'dTbl = 0.25;',f"dTbl = {case['bubble_delta_K']};")
    matlab=replace_once(matlab,'MF0 = 0*5;',f"MF0 = {case['initial_mf_amplitude']};")
    matlab=replace_once(matlab,'zt = 4e3;', 'zt = 1000;')
    matlab=replace_once(matlab,'%% Define a struc to warp static ACE attributes',
                        'X0(:,3,2:end)=0; % SingleACE initial pulse only in ACE 1.\n\n%% Define a struc to warp static ACE attributes')
    matlab=replace_once(matlab,'function X = timeint(',f"""fid=fopen(fullfile('{work}',[getenv('ACE_SINGLE_TAG') '_matlab_states.bin']),'w');
for step=1:size(X,4)
  v=permute(X(:,[3,1,2],:,step),[3,1,2]); fwrite(fid,v(:),'double');
end
fclose(fid);

function X = timeint(""")
    (work/'single_main.m').write_text(matlab)
    module_original=(ROOT/'fortran/src/ace_module.F').read_text()
    module=replace_once(module_original,'!dXdt(2:ncols,:,:)=0.','dXdt(2:ncols,:,:)=0.')
    (work/'ace_module_single.F').write_text(module)
    driver_original=(ROOT/'fortran/src/test.F').read_text()
    driver=replace_once(driver_original,'dum1=Tr(1,k)+0.25',f"dum1=Tr(1,k)+{case['bubble_delta_K']}")
    driver=replace_once(driver,'call set_p3_lookup_directory(trim(p3_directory))',f"""do k=1,nz
  if (zm(k)<=1000.) X(1,k,1)={case['initial_mf_amplitude']}*sin(4.*atan(1.)*zm(k)/1000.)
enddo
call set_p3_lookup_directory(trim(p3_directory))""")
    driver=replace_once(driver,'Tv0,netcdf_input=.true.)',
                        f"Tv0,netcdf_input=.true.,Wbar_eq_zero_input=.{str(mean).lower()}.)")
    (work/'single_driver.F').write_text(driver)
    for name,before,after in [('matlab',matlab_original,matlab),('module',module_original,module),('driver',driver_original,driver)]:
        (work/f'{name}_single.diff').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=name+'/production',tofile=name+'/single_test')))
    build=work/'build_single';build.mkdir()
    flags=['-cpp','-ffree-form','-ffree-line-length-none','-O2','-g','-fcheck=all,no-array-temps',
           '-ffpe-trap=invalid,zero,overflow','-fbacktrace','-fdefault-real-8','-fdefault-double-8']
    include=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    for name in ('ace_input.mod','ace_interpolation.mod','microphy_p3.mod'):
        (build/name).write_bytes((work/'build64'/name).read_bytes())
    commands=[['gfortran',*flags,*include,'-c',str(work/'ace_module_single.F'),'-o','ace_module.o'],
              ['gfortran',*flags,*include,'-c',str(work/'single_driver.F'),'-o','test.o'],
              ['gfortran',*flags,'test.o','ace_module.o',
               *[str(work/'build64'/(name+'.o')) for name in ('ace_input','ace_interpolation','microphy_p3')],
               *libs,'-o','ace_model.exe']]
    for command in commands:subprocess.run(command,cwd=build,check=True)
    for tag,steps in [('smoke','1'),('full','')]:
        (work/f'{tag}_launch.m').write_text(f"""setenv('ACE_INPUT_MODE','shared'); setenv('ACE_VALIDATE_INPUT','');
setenv('ACE_INPUT_FILE','{input_file}');setenv('ACE_PHYSICS','{case['physics']}');
setenv('ACE_STEPS','{steps}');setenv('ACE_SINGLE_TAG','{tag}');
setenv('ACE_OUTPUT_FILE','{work}/{tag}_matlab.nc');
run('{work}/single_main.m');
""")
    case.update({'input':str(input_file),'input_sha256':digest(input_file),
                 'active_ace_one_based':1,'full_basis_columns':101,'profile_index':1342,
                 'bubble_levels_one_based':[11,51], 'output_interval_seconds':60,
                 'policy':'Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior.',
                 'basis_policy':'Complete geometry and PMB retained; PMDv/PMD disabled.',
                 'compiled_commands':commands,
                 'generated_sha256':{name:digest(work/name) for name in ('single_main.m','ace_module_single.F','single_driver.F')},
                 'not_frozen_manus_reference':'Manaus/KHN26 basis and grid; no byte comparison to v0.18 Manus.'})
    (work/'single_case.json').write_text(json.dumps(case,indent=2)+'\n')


def compare(work, tag):
    case=json.loads((work/'single_case.json').read_text())
    count=2 if tag=='smoke' else case['duration_seconds']//60+1
    times=np.array([0,case['dt_seconds']]) if tag=='smoke' else np.arange(count)*60
    n,z=101,401;size=n*z*3;fsize=(n+1)*z*3
    mpath=work/f'{tag}_matlab_states.bin';fpath=work/f'{tag}_fortran_states.bin'
    if mpath.stat().st_size!=count*size*8 or fpath.stat().st_size!=12+(count*fsize+z)*8:
        raise ValueError('Incorrect or incomplete state stream length')
    if not np.array_equal(np.fromfile(fpath,'<i4',count=3),[n,z,3]):
        raise ValueError('Incorrect Fortran state header')
    with Dataset(case['input']) as ds:
        areas=np.asarray(ds['ace_area'][:]);weights=areas/areas.sum()
        reference=np.stack([ds['theta_e_zc'][:],ds['qt_zc'][:]],axis=1)
        height=np.asarray(ds['zm'][:])
    matlab=np.memmap(mpath,'<f8',mode='r',shape=(count,size))
    errors=[];means=[];inactive=[];ranges=[];active=[]
    mf=[]
    for index in range(count):
        offset=12+8*(0 if index==0 else index*fsize+z)
        f=np.memmap(fpath,'<f8',mode='r',offset=offset,shape=(fsize,)).reshape((n+1,z,3),order='F')[:n]
        m=matlab[index].reshape((n,z,3),order='F')
        if not np.isfinite(f).all() or not np.isfinite(m).all() or min(f[:,:,2].min(),m[:,:,2].min())<0:
            raise ValueError(f'Nonfinite state or negative water at {times[index]} s')
        errors.append(np.max(np.abs(f-m),axis=(0,1)).tolist())
        means.append([float(np.max(np.abs(np.sum(v[:,:,0]*weights[:,None],axis=0)))) for v in (m,f)])
        inactive.append([np.max(np.abs(v[1:,:,1:3]-reference[None,:,:]),axis=(0,1)).tolist() for v in (m,f)])
        ranges.append([[v.min(axis=(0,1)).tolist(),v.max(axis=(0,1)).tolist()] for v in (m,f)])
        active.append([float(np.max(np.abs(v[0,:,0]))) for v in (m,f)])
        mf.append(np.stack([m[0,:,0],f[0,:,0]]))
        if index==0:
            pulse=case['initial_mf_amplitude']*np.sin(np.pi*height/1000)
            pulse[height>1000]=0
            for v in (m,f):
                if np.max(np.abs(v[0,:,0]-pulse))>1e-14 or np.any(v[1:,:,0]!=0):
                    raise ValueError('Initial MF is not the declared singleACE pulse')
        else:
            for v in (m,f):
                if case['mean_mf_zero']:
                    if np.max(np.abs(np.sum(v[:,:,0]*weights[:,None],axis=0)))>1e-10:
                        raise ValueError('Domain-mean MF correction is not satisfied')
                    if np.max(np.abs(v[1:,:,0]-v[1:2,:,0]))>1e-10:
                        raise ValueError('Inactive columns have unequal compensation MF')
                elif np.any(v[1:,:,0]!=0):
                    raise ValueError('Inactive MF is nonzero with mean correction disabled')
                if case['physics']=='none' and np.any(np.max(np.abs(v[1:,:,1:3]-reference[None,:,:]),axis=(0,1))>[1e-7,1e-11]):
                    raise ValueError('Inactive scalar fields changed beyond roundoff')
    result={'tag':tag,'saved_states':count,'time_seconds':times.tolist(),
            'field_order':['MF','theta_e','qt'],'max_abs_error':np.max(errors,axis=0).tolist(),
            'max_abs_error_each_state':errors,'area_mean_MF_max_matlab_fortran':means,
            'inactive_scalar_deviation_matlab_fortran':inactive,
            'extrema_matlab_fortran':ranges,'active_MF_abs_max_matlab_fortran':active,
            'finite_saved_states':True,'nonnegative_saved_qt':True,
            'case':case,'scientific_acceptance':'Descriptive metrics; developer review required for long-run acceptance.'}
    if tag=='smoke' and np.any(np.max(errors,axis=0)>[1e-9,1e-7,1e-11]):
        raise ValueError(f'Single-step agreement failed: {result["max_abs_error"]}')
    result['artifacts_sha256']={path.name:digest(path) for path in (mpath,fpath,work/f'{tag}_matlab.nc')}
    (work/f'{tag}_results.json').write_text(json.dumps(result,indent=2)+'\n')
    np.savez_compressed(work/f'{tag}_mf.npz',time_seconds=times,height_m=height,
                        matlab=np.asarray(mf)[:,0],fortran=np.asarray(mf)[:,1])
    return result


def status(work,state,**extra):
    report={'updated_utc':datetime.now(timezone.utc).isoformat(),'supervisor_pid':os.getpid(),
            'state':state,**extra}
    temp=work/'single_status.tmp';temp.write_text(json.dumps(report,indent=2)+'\n')
    temp.replace(work/'single_status.json')


def run(work):
    case=json.loads((work/'single_case.json').read_text())
    config=json.loads((work/'configuration.json').read_text())
    for tag in ('smoke','full'):
        processes=[];logs=[]
        status(work,f'{tag}_starting')
        try:
            if digest(case['input'])!=case['input_sha256']:
                raise ValueError('Input changed after preparation')
            for name,sha in config['sources'].items():
                if digest(ROOT/name)!=sha:raise ValueError(f'Source changed after preparation: {name}')
            for name,sha in case['generated_sha256'].items():
                if digest(work/name)!=sha:raise ValueError(f'Generated driver changed: {name}')
            args=[str(work/'build_single/ace_model.exe'),'--input',case['input'],
                  '--physics',case['physics'],'--dt',str(case['dt_seconds']),
                  '--state-output',str(work/f'{tag}_fortran_states.bin')]
            args+=['--steps','1'] if tag=='smoke' else ['--intervals',str(case['duration_seconds']//60),
                                                    '--output',str(work/'full_fortran.dat')]
            commands=[['matlab','-batch',f"run('{work}/{tag}_launch.m')"],args]
            for name,command in zip(('matlab','fortran'),commands):
                log=(work/f'{tag}_{name}.log').open('w');logs.append(log)
                processes.append(subprocess.Popen(command,cwd=work,stdin=subprocess.DEVNULL,
                                                  stdout=log,stderr=subprocess.STDOUT))
            while any(p.poll() is None for p in processes):
                codes=[p.poll() for p in processes]
                if any(code is not None and code!=0 for code in codes):
                    raise RuntimeError(f'{tag} driver failed; exit codes {codes}')
                status(work,f'{tag}_running',driver_pids=[p.pid for p in processes],exit_codes=codes,
                       artifacts_bytes={name:p.stat().st_size for p in work.glob(f'{tag}_*states.bin') for name in [p.name]})
                time.sleep(10 if tag=='smoke' else 60)
            if any(p.returncode!=0 for p in processes):
                raise RuntimeError(f'{tag} driver failed; check logs')
            result=compare(work,tag)
            status(work,f'{tag}_passed' if tag=='smoke' else 'completed_pending_scientific_review',
                   max_abs_error=result['max_abs_error'],exit_codes=[p.returncode for p in processes])
        except BaseException as exc:
            for p in processes:
                if p.poll() is None:p.terminate()
            for p in processes:
                try:p.wait(timeout=10)
                except subprocess.TimeoutExpired:p.kill();p.wait()
            status(work,'failed',stage=tag,error=str(exc))
            raise
        finally:
            for log in logs:log.close()


def launch(work):
    path=work/'supervisor.log'
    with path.open('x') as log:
        child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],
                               cwd=ROOT,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,
                               start_new_session=True,close_fds=True)
    (work/'supervisor.pid').write_text(str(child.pid)+'\n')
    print(json.dumps({'supervisor_pid':child.pid,'work':str(work),'log':str(path)}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    action=parser.add_mutually_exclusive_group()
    action.add_argument('--run',action='store_true')
    action.add_argument('--launch',action='store_true')
    action.add_argument('--compare',choices=['smoke','full'])
    parser.add_argument('--duration',type=int)
    parser.add_argument('--dt',type=float)
    parser.add_argument('--bubble',type=float)
    parser.add_argument('--physics',choices=['native','none'])
    parser.add_argument('--mean-mf',choices=['zero','free'])
    parser.add_argument('--initial-mf',type=float)
    args=parser.parse_args()
    work=args.work.resolve()
    if args.run:run(work);sys.exit()
    if args.launch:launch(work);sys.exit()
    if args.compare:compare(work,args.compare);sys.exit()
    if any(value is None for value in (args.duration,args.dt,args.bubble,args.physics,args.mean_mf,args.initial_mf)):
        parser.error('Preparation requires explicit duration, dt, bubble, physics, mean-mf and initial-mf.')
    if args.duration<=0 or args.duration%60 or args.dt<=0 or abs(round(60/args.dt)*args.dt-60)>1e-10:
        parser.error('Positive duration must be a multiple of 60 s; dt must divide 60 s.')
    create(args.work.resolve(),{'duration_seconds':args.duration,'dt_seconds':args.dt,
                               'bubble_delta_K':args.bubble,'physics':args.physics,
                               'mean_mf_zero':args.mean_mf=='zero','initial_mf_amplitude':args.initial_mf})
