#!/usr/bin/env python3
"""Export minute precipitation amounts and running totals, then plot three-hour curves."""
import argparse
from datetime import datetime, timezone
import difflib
import json
import os
from pathlib import Path
import resource
import shlex
import shutil
import subprocess
import sys
import time

import numpy as np
from netCDF4 import Dataset

from p3_smoke import ROOT, sha

PRECIP_FILE='precip_accumulation.bin'
PRECIP_INTERVAL=60
PRECIP_FIELDS=['time_seconds','minute_native_total_or_liquid_mm','minute_solid_mm',
               'cumulative_native_total_or_liquid_mm','cumulative_solid_mm']


def write(path,value):
    tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(path)


def replace(source,old,new):
    if source.count(old)!=1: raise ValueError('Expected one diagnostic insertion: '+old[:80])
    return source.replace(old,new,1)


def fortran_accumulator():
    return '''subroutine record_precip_accumulation(dt,liquid_or_native_total,solid)
real,intent(in)::dt,liquid_or_native_total(:),solid(:)
integer,save::unit=0
real,save::elapsed=0.,output_time=0.
real,allocatable,save::minute_liquid(:),minute_solid(:),total_liquid(:),total_solid(:)
real,parameter::interval=60.
real::tolerance
if (dt<=0. .or. size(liquid_or_native_total)/=size(solid)) error stop 'Invalid precipitation input'
if (unit==0) then
  allocate(minute_liquid(size(solid)),minute_solid(size(solid)),total_liquid(size(solid)),total_solid(size(solid)))
  minute_liquid=0.;minute_solid=0.;total_liquid=0.;total_solid=0.
  open(newunit=unit,file='precip_accumulation.bin',access='stream',form='unformatted',status='new')
  write(unit) output_time,minute_liquid,minute_solid,total_liquid,total_solid
  flush(unit)
endif
if (size(solid)/=size(minute_solid)) error stop 'Precipitation grid changed'
! kg/m2/s * seconds = kg/m2 = mm water equivalent.
minute_liquid=minute_liquid+liquid_or_native_total*dt
minute_solid=minute_solid+solid*dt
elapsed=elapsed+dt
tolerance=64*epsilon(interval)*interval
if (elapsed>interval+tolerance) error stop 'dt must divide precipitation output interval'
if (abs(elapsed-interval)<=tolerance) then
  output_time=output_time+interval
  total_liquid=total_liquid+minute_liquid
  total_solid=total_solid+minute_solid
  write(unit) output_time,minute_liquid,minute_solid,total_liquid,total_solid
  flush(unit)
  minute_liquid=0.;minute_solid=0.;elapsed=0.
endif
end subroutine record_precip_accumulation
'''


def matlab_accumulator_setup(path):
    return f'''  precip_series_fid=fopen('{path}','w');
  assert(precip_series_fid>0);
  precip_minute=zeros(model.Ni,1);precip_total=zeros(model.Ni,1);
  precip_elapsed=0;precip_time=0;
  fwrite(precip_series_fid,[0;precip_minute;zeros(model.Ni,1);precip_total;zeros(model.Ni,1)],'double');'''


def matlab_accumulator_step():
    return '''      native_rate=-reshape(sum(dQt(1:end-1,:).*model.rho_zc(1:end-1)*model.dz,1),[],1);
      precip_minute=precip_minute+native_rate*dt;
      precip_elapsed=precip_elapsed+dt;
      assert(dt>0 && precip_elapsed<=60+64*eps(60),'dt must divide precipitation output interval');
      if abs(precip_elapsed-60)<=64*eps(60)
        precip_time=precip_time+60;
        precip_total=precip_total+precip_minute;
        fwrite(precip_series_fid,[precip_time;precip_minute;zeros(model.Ni,1);precip_total;zeros(model.Ni,1)],'double');
        precip_minute(:)=0;precip_elapsed=0;
      end'''


def patch_module(source):
    source=replace(source,'X(1:ncols,:,2:3)=X(1:ncols,:,2:3)+K1(:,:,1:2)*dt',
        '''call record_precip_accumulation(dt, [(-sum(K1(ii,1:nz-1,2)*Ref(1:nz-1,1)*Ref(1:nz-1,5)), ii=1,ncols)], &
                         [(0., ii=1,ncols)])
X(1:ncols,:,2:3)=X(1:ncols,:,2:3)+K1(:,:,1:2)*dt''')
    source=replace(source,'if (global_status == -1) stop "p3 stop"',
        '''if (global_status == -1) stop "p3 stop"
! P3 returns water-equivalent volume flux (m/s); convert to kg/m2/s.
call record_precip_accumulation(dt, 1000.*precip_liq, 1000.*precip_sol)''')
    return replace(source,'end module',fortran_accumulator()+'end module')


def read_minute_precip(path,ncols=101,duration=10800):
    width=1+4*ncols;count=duration//PRECIP_INTERVAL+1
    if path.stat().st_size!=count*width*8:raise ValueError('Incomplete minute precipitation series: '+str(path))
    data=np.fromfile(path,'<f8').reshape(count,width)
    if not np.array_equal(data[:,0],np.arange(count)*PRECIP_INTERVAL):raise ValueError('Invalid precipitation time axis')
    if not np.isfinite(data).all() or np.any(data[:,1:]<0):raise ValueError('Invalid precipitation amount')
    minute_liquid=data[:,1:1+ncols];minute_solid=data[:,1+ncols:1+2*ncols]
    cumulative_liquid=data[:,1+2*ncols:1+3*ncols];cumulative_solid=data[:,1+3*ncols:]
    if np.any(data[0]!=0):raise ValueError('Initial accumulation must be zero')
    for minute,cumulative in ((minute_liquid,cumulative_liquid),(minute_solid,cumulative_solid)):
        if not np.array_equal(cumulative,np.cumsum(minute,axis=0)):
            raise ValueError('Minute amounts and running accumulation disagree')
    return minute_liquid+minute_solid,cumulative_liquid+cumulative_solid


def prepare(work):
    native_paths=dict(singleACE=ROOT/'migration_work/khn26_single_matlab_default_fortran32_3h',
                      multiACE=ROOT/'migration_work/khn26_multi_weno_three_hour')
    p3base=ROOT/'migration_work/khn26_p3_three_hour'
    p3cfg=json.loads((p3base/'configuration.json').read_text())
    work.mkdir(parents=True,exist_ok=False)
    shutil.copyfile(Path(__file__),work/'executed_runner.py')
    jobs=[]; commands=[]
    include=shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs=shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    flags=['-cpp','-O2','-ffree-form','-fdefault-real-8','-fdefault-double-8','-ffree-line-length-none','-fopenmp']
    for case,native in native_paths.items():
        cfg=json.loads((native/'configuration.json').read_text())
        result=json.loads((native/'full_state_results.json').read_text())
        if cfg['case']['input_sha256']!=p3cfg['case']['input_sha256']:
            raise ValueError('Different shared input')
        for language in ('matlab','fortran','p3'):
            job=work/(case+'_'+language);job.mkdir();(job/'full').mkdir()
            reference=(native/'full'/('matlab_states.bin' if language=='matlab' else 'fortran_states.bin')) if language!='p3' else p3base/case/'full/states.bin'
            expected=result['artifacts_sha256'][reference.name] if language!='p3' else json.loads((p3base/case/'full/results.json').read_text())['state_sha256']
            if sha(reference)!=expected: raise ValueError('Reference changed: '+str(reference))
            item=dict(name=job.name,case=case,language=language,reference=str(reference),reference_sha256=expected,
                initial_MF_amplitude=p3cfg['case']['initial_MF'] if language=='p3' else cfg['case']['initial_mf_amplitude'])
            if language=='matlab':
                # Keep the saved run's initialization, utilities and numerical statements.
                for path,digest in cfg['sha256'].items():
                    if str(ROOT/'matlab')+'/' in path and Path(path).exists() and sha(Path(path))!=digest:
                        raise ValueError('MATLAB utility changed since reference: '+path)
                original=(native/'multi_main.m').read_text()
                source=original.replace(str(native),str(job))
                source=replace(source,'      if model.precip_enabled',matlab_accumulator_step()+'\n      if model.precip_enabled')
                source=replace(source,'  yn = X0;','  yn = X0;\n'+matlab_accumulator_setup(job/'full'/PRECIP_FILE))
                source=replace(source,'  fclose(state_fid);','  fclose(precip_series_fid);\n  fclose(state_fid);')
                (job/'diagnostic_main.m').write_text(source)
                launch=(native/'full_launch.m').read_text().replace(str(native),str(job))
                launch=replace(launch,str(job/'multi_main.m'),str(job/'diagnostic_main.m'))
                (job/'launch.m').write_text(launch)
                (job/'diagnostic.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),source.splitlines(True),fromfile='reference',tofile='diagnostic')))
                item['command']=['matlab','-batch',f"run('{job/'launch.m'}')"]
                item['output_state']='matlab_states.bin'
            else:
                src=job/'source';src.mkdir();build=job/'build';build.mkdir()
                if language=='p3':
                    source_dir=p3base/'singleACE/source' if case=='singleACE' else ROOT/'migration_work/khn26_p3_smoke/source'
                    originals={name:(source_dir/name).read_bytes() for name in ('microphy_p3.F','ace_input.F','ace_interpolation.F','ace_module.F','test.F')}
                else:
                    gate=Path(cfg['gate_work'])
                    originals={name:(ROOT/'fortran/src'/name).read_bytes() for name in ('microphy_p3.F','ace_input.F','ace_interpolation.F')}
                    for name in originals:
                        path=str(ROOT/'fortran/src'/name)
                        if path in cfg['sha256'] and sha(Path(path))!=cfg['sha256'][path]: raise ValueError('Fortran dependency changed')
                    for name,file in (('ace_module.F',gate/'ace_module_multi.F'),('test.F',gate/'multi_driver.F')):
                        if sha(file)!=cfg['sha256'][str(file)]: raise ValueError('Recorded native source changed')
                        originals[name]=file.read_bytes()
                for name,data in originals.items(): (src/name).write_bytes(data)
                original=(src/'ace_module.F').read_text(); source=patch_module(original)
                (src/'ace_module.F').write_text(source)
                (job/'diagnostic.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),source.splitlines(True),fromfile='reference',tofile='diagnostic')))
                names=list(originals)
                for name in names:
                    cmd=['gfortran',*flags,*include,'-c',str(src/name)]
                    with (build/(name+'.compile.log')).open('w') as log:
                        subprocess.run(cmd,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
                    commands.append(cmd)
                cmd=['gfortran',*flags,*[str(build/Path(name).with_suffix('.o')) for name in names],'-o',str(build/'ace_model.exe'),*libs]
                with (build/'link.log').open('w') as log:
                    subprocess.run(cmd,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
                commands.append(cmd)
                item['command']=[str(build/'ace_model.exe'),'--input',p3cfg['case']['input'],'--physics','p3' if language=='p3' else 'native',
                    '--dt','4','--intervals','180','--state-output',str(job/'full/states.bin'),'--output',str(job/'full/fields.dat')]
                if language=='p3': item['command']+=['--p3-lookup-directory',p3cfg['case']['lookup_directory']]
                item['output_state']='states.bin';item['executable_sha256']=sha(build/'ace_model.exe')
            item['diagnostic_source_sha256']=sha(job/('diagnostic_main.m' if language=='matlab' else 'source/ace_module.F'))
            jobs.append(item)
            print('Prepared '+job.name,flush=True)
    write(work/'configuration.json',dict(input=p3cfg['case']['input'],input_sha256=p3cfg['case']['input_sha256'],
        duration_seconds=10800,dt_seconds=4,expected_steps=2700,jobs=jobs,runner_sha256=sha(Path(__file__)),
        precipitation_output_version=1,precipitation_output_interval_seconds=PRECIP_INTERVAL,
        precipitation_output_file=PRECIP_FILE,precipitation_record_fields=PRECIP_FIELDS,
        expected_precipitation_records=181,precipitation_amount_units='mm water equivalent',
        definition_native='Actual applied column-integrated native total-water removal, kg/m2/s; equivalent precipitation, not transported surface rain.',
        definition_p3='Actual P3 surface liquid plus solid precipitation flux, kg/m2/s; returned m/s converted with water density 1000 kg/m3.'))
    write(work/'build_commands.json',commands);write(work/'status.json',dict(state='prepared'))


def verify(work):
    cfg=json.loads((work/'configuration.json').read_text())
    if cfg.get('precipitation_output_version')!=1:
        raise ValueError('Legacy step-rate workspace: preserve it and prepare a fresh minute-accumulation workspace')
    if sha(work/'executed_runner.py')!=cfg['runner_sha256']:raise ValueError('Runner changed')
    if sha(Path(cfg['input']))!=cfg['input_sha256']:raise ValueError('Input changed')
    for job in cfg['jobs']:
        root=work/job['name']; source=root/('diagnostic_main.m' if job['language']=='matlab' else 'source/ace_module.F')
        if sha(source)!=job['diagnostic_source_sha256']:raise ValueError('Diagnostic source changed')
        if job['language']!='matlab' and sha(root/'build/ace_model.exe')!=job['executable_sha256']:raise ValueError('Executable changed')
    return cfg


def plot(work,out):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    cfg=verify(work)
    with Dataset(cfg['input']) as ds: areas=np.asarray(ds['ace_area'][:])
    weights=areas/areas.sum();series={};metadata=[]
    for job in cfg['jobs']:
        root=work/job['name'];states=root/'full'/job['output_state']; amounts=root/'full'/PRECIP_FILE
        if sha(states)!=job['reference_sha256']:raise ValueError('Saved-state reproduction failed: '+job['name'])
        minute_amount,accum=read_minute_precip(amounts)
        rate=minute_amount[1:]*3600/PRECIP_INTERVAL
        series[(job['case'],job['language'])]=(minute_amount,rate,accum)
        metadata.append(dict(job=job['name'],state_sha256=sha(states),precip_sha256=sha(amounts),exact_saved_state_reproduction=True,
            precipitation_record_count=181,precipitation_interval_seconds=PRECIP_INTERVAL,
            ACE1_accumulation_mm=float(accum[-1,0]),area_mean_accumulation_mm=float(accum[-1]@weights),
            peak_ACE1_minute_mean_mm_h=float(rate[:,0].max()),peak_domain_minute_mean_mm_h=float((rate@weights).max())))
    out.mkdir(parents=True,exist_ok=True)
    labels={'matlab':'MATLAB','fortran':'Fortran','p3':'Fortran P3'}
    colors={'matlab':'#1f77b4','fortran':'#ff7f0e','p3':'#2ca02c'}
    for case in ('singleACE','multiACE'):
        for scope in ('ACE1','area_mean'):
            fig,axes=plt.subplots(2,1,figsize=(11,8),sharex=True,layout='constrained')
            for language in ('matlab','fortran','p3'):
                minute_amount,rate,accum=series[(case,language)]
                r=rate[:,0] if scope=='ACE1' else rate@weights
                a=accum[:,0] if scope=='ACE1' else accum@weights
                style='--' if language=='fortran' else '-'
                axes[0].plot((np.arange(180)+.5)/60,r,style,color=colors[language],label=labels[language],lw=1.8)
                axes[1].plot(np.arange(181)/60,a,style,color=colors[language],label=labels[language],lw=1.8)
            axes[0].set(ylabel='Precipitation rate (mm h$^{-1}$)',title='One-minute mean rate derived from minute accumulation')
            axes[1].set(ylabel='Accumulation (mm)',xlabel='Time (hours)',title='Integrated amount')
            for ax in axes:ax.set_xlim(0,3);ax.set_ylim(bottom=0);ax.grid(alpha=.25);ax.legend()
            note='Native curves: column removal equivalent; P3: liquid + solid surface precipitation'
            if case=='singleACE':note+='\nInitial MF: MATLAB/Fortran 0.03, P3 0'
            fig.suptitle(f'{case} / '+('ACE 1' if scope=='ACE1' else 'Domain area mean')+' / three hours\n'+note,fontsize=11)
            for ext in ('png','pdf'):fig.savefig(out/(case+'_'+scope+'_precipitation.'+ext),dpi=180,bbox_inches='tight')
            plt.close(fig)
    arrays={}
    for (case,language),(minute_amount,rate,accum) in series.items():
        arrays[case+'_'+language+'_minute_rate_mm_h']=rate
        arrays[case+'_'+language+'_minute_amount_mm']=minute_amount
        arrays[case+'_'+language+'_accumulation_mm']=accum
    np.savez_compressed(out/'series.npz',area_weights=weights,**arrays)
    write(out/'results.json',dict(configuration=cfg,diagnostics=metadata,
        scope='Actual model-step diagnostics, exact minute-saved state reproduction. Native removal equivalent and P3 transported surface precipitation have different definitions.'))
    write(out/'manifest.json',{p.name:sha(p) for p in out.iterdir() if p.is_file() and p.name!='manifest.json'})


def supervise(work):
    cfg=verify(work);children=[]
    resource.setrlimit(resource.RLIMIT_CORE,(0,0));resource.setrlimit(resource.RLIMIT_STACK,(resource.RLIM_INFINITY,resource.RLIM_INFINITY))
    try:
        for job in cfg['jobs']:
            root=work/job['name'];env=dict(os.environ)
            if job['language']=='matlab':
                for key in ('OMP_NUM_THREADS','OMP_THREAD_LIMIT','OMP_DYNAMIC','OMP_PLACES','OMP_PROC_BIND','GOMP_CPU_AFFINITY',
                    'MKL_NUM_THREADS','MKL_DYNAMIC','OPENBLAS_NUM_THREADS','GOTO_NUM_THREADS','BLIS_NUM_THREADS','MATLAB_NUM_THREADS','MATLAB_MAX_NUM_THREADS'):
                    env.pop(key,None)
                env['MATLAB_PREFDIR']=str(root/'matlab_prefs');Path(env['MATLAB_PREFDIR']).mkdir()
            else:
                env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M',OPENBLAS_NUM_THREADS='1')
                for key in ('ACE_MULTI_TENDENCY_FILE','ACE_MULTI_PRECIP_FILE'):env.pop(key,None)
            log=(root/'full/run.log').open('x')
            process=subprocess.Popen(job['command'],cwd=root/'full',env=env,stdout=log,stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,start_new_session=True)
            children.append((job,process,log));write(root/'launch.json',dict(pid=process.pid,command=job['command']))
        while True:
            statuses={}
            for job,p,log in children:
                amounts=work/job['name']/'full'/PRECIP_FILE
                n=amounts.stat().st_size//(405*8) if amounts.exists() else 0
                statuses[job['name']]=dict(pid=p.pid,exit_code=p.poll(),complete_precip_records=n,model_minutes=max(0,n-1))
            write(work/'status.json',dict(state='running',jobs=statuses,updated_utc=datetime.now(timezone.utc).isoformat()))
            if any(p.poll() not in (None,0) for _,p,_ in children):raise RuntimeError('Diagnostic driver failed; inspect preserved logs')
            if all(p.poll() is not None for _,p,_ in children):break
            time.sleep(20)
        for job,p,log in children:
            log.close()
            if sha(work/job['name']/'full'/job['output_state'])!=job['reference_sha256']:
                raise ValueError('Saved-state reproduction failed: '+job['name'])
        out=ROOT/'docs/figures/khn26_precipitation_3h'
        plot(work,out)
        write(work/'status.json',dict(state='completed',output=str(out),exact_saved_state_reproduction_all=True,
            updated_utc=datetime.now(timezone.utc).isoformat()))
    except Exception as exc:
        write(work/'status.json',dict(state='failed',error=str(exc),running_driver_pids=[p.pid for _,p,_ in children if p.poll() is None],
            updated_utc=datetime.now(timezone.utc).isoformat()))
        raise


def launch(work):
    verify(work)
    if json.loads((work/'status.json').read_text())['state']!='prepared':raise ValueError('Already launched')
    with (work/'supervisor.log').open('x') as log:
        env=dict(os.environ,PYTHONPATH='/tmp/ace-mf-plot-deps',MPLCONFIGDIR='/tmp/ace-mf-matplotlib',OPENBLAS_NUM_THREADS='1')
        p=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--supervise'],cwd=ROOT,env=env,
            stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    write(work/'supervisor.json',dict(pid=p.pid,started_utc=datetime.now(timezone.utc).isoformat()))
    print(json.dumps({'supervisor_pid':p.pid,'workspace':str(work)}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    actions=parser.add_mutually_exclusive_group(required=True)
    for action in ('prepare','launch','supervise','plot'):actions.add_argument('--'+action,action='store_true')
    parser.add_argument('--output',type=Path,default=ROOT/'docs/figures/khn26_precipitation_3h')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work)
    elif args.launch:launch(work)
    elif args.supervise:supervise(work)
    else:plot(work,args.output.resolve())
