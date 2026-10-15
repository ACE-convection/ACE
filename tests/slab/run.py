#!/usr/bin/env python3
"""Reproducible slab-input and momentum gates; optional gated eight-hour runs.

Uses isolated source snapshots. Never overwrites a run directory. Long-run
cross-language differences are metrics, not automatic scientific acceptance.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import time
import traceback

import numpy as np
from netCDF4 import Dataset

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FILES = ('ace_input.F', 'ace_interpolation.F', 'microphy_p3.F', 'ace_module.F', 'test.F')
FIELDS = ['MF', 'theta_e', 'qt']
# Existing KHN26 short-state limits, retained before observing this new case.
LIMITS = np.array([1e-9, 1e-7, 1e-11])
FLAGS = ['-cpp', '-O2', '-ffree-form', '-ffree-line-length-none',
         '-fdefault-real-8', '-fdefault-double-8', '-fopenmp']


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def write(path, data):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n')
    temp.replace(path)


def replace(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Expected unique insertion: ' + old[:80])
    return source.replace(old, new, 1)


def status(work, phase, **details):
    write(work/'status.json', dict(phase=phase, utc=datetime.now(timezone.utc).isoformat(),
                                 supervisor_pid=os.getpid(), **details))


def checked(command, cwd, log, env=None):
    with log.open('x') as stream:
        subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                       stderr=subprocess.STDOUT, check=True)


def budget_module(src):
    """Observation only: retain every production update and its order."""
    src=replace(src, 'do while ( t < te)',
                'do while ( t < te)\n  call slab_budget(ncols,nz,n_prog,X,Ref)')
    src=replace(src, '    if (.not.present(precipitation_input)) then',
                '    call slab_budget(ncols,nz,n_prog,X,Ref)\n    if (.not.present(precipitation_input)) then')
    src=replace(src, '  ! NaN check', '  call slab_budget(ncols,nz,n_prog,X,Ref)\n  ! NaN check')
    src=replace(src, '  t = t + dt', '  call slab_budget(ncols,nz,n_prog,X,Ref)\n  t = t + dt')
    return replace(src, 'end module', '''subroutine slab_budget(nc,nz,np,X,Ref)
integer,intent(in)::nc,nz,np
real,intent(in)::X(nc+1,nz,np),Ref(nz,8)
integer,save::unit=0
integer::i
character(1024)::path
if (np/=3) return
if (unit==0) then
  call get_environment_variable('ACE_SLAB_BUDGET',path)
  if (len_trim(path)==0) return
  open(newunit=unit,file=trim(path),access='stream',form='unformatted',status='new')
endif
write(unit) [(sum(X(i,1:nz-1,3)*Ref(1:nz-1,1)*Ref(1:nz-1,5)),i=1,nc)]
flush(unit)
end subroutine
end module''')


def prepare(work, input_file):
    work.mkdir(parents=True, exist_ok=False)
    source = work/'source'; source.mkdir()
    shutil.copytree(ROOT/'matlab', source/'matlab')
    (source/'fortran').mkdir()
    for name in FILES:
        shutil.copyfile(ROOT/'fortran/src'/name, source/'fortran'/name)
    shutil.copyfile(HERE/'components.f90', source/'components.f90')
    shutil.copyfile(__file__, work/'executed_runner.py')
    config = dict(input=str(input_file), input_sha256=sha(input_file),
                  git_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  compiler=subprocess.check_output(['gfortran', '--version'], text=True),
                  duration_seconds=28800, dt_seconds=6, dz_m=100, bubble_K=0.25,
                  initial_MF=0, field_order=FIELDS, short_absolute_limits=LIMITS.tolist(),
                  threads=32, matlab_threads=32, flags=FLAGS, sha256={})
    for path in source.rglob('*'):
        if path.is_file(): config['sha256'][str(path)] = sha(path)
    config['sha256'][str(work/'executed_runner.py')] = sha(work/'executed_runner.py')
    commands = []
    inc = shlex.split(subprocess.check_output(['nf-config', '--fflags'], text=True))
    libs = shlex.split(subprocess.check_output(['nf-config', '--flibs'], text=True))
    for variant in ('debug', 'production'):
        build = work/variant; build.mkdir()
        flags = FLAGS + (['-g', '-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow',
                          '-fbacktrace'] if variant == 'debug' else [])
        for name in FILES:
            cmd = ['gfortran', *flags, *inc, '-c', str(source/'fortran'/name)]
            commands.append(cmd); checked(cmd, build, build/(name+'.log'))
        cmd = ['gfortran', *flags, *[n.replace('.F', '.o') for n in FILES], *libs, '-o', 'ace_model.exe']
        commands.append(cmd); checked(cmd, build, build/'link.log')
        config['sha256'][str(build/'ace_model.exe')] = sha(build/'ace_model.exe')
    build = work/'components'; build.mkdir()
    exposed = (source/'fortran/ace_module.F').read_text().replace('\nprivate\n', '\n').replace('  private\n', '')
    (build/'ace_module_probe.F').write_text(exposed)
    for name in ('ace_input', 'ace_interpolation', 'microphy_p3'):
        shutil.copyfile(work/'debug'/(name+'.o'), build/(name+'.o'))
        shutil.copyfile(work/'debug'/(name+'.mod'), build/(name+'.mod'))
    flags = FLAGS + ['-g', '-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
    checked(['gfortran', *flags, *inc, '-c', str(build/'ace_module_probe.F')], build, build/'compile.log')
    checked(['gfortran', *flags, str(source/'components.f90'), 'ace_module_probe.o',
             'ace_input.o', 'ace_interpolation.o', 'microphy_p3.o', *libs, '-o', 'components.exe'],
            build, build/'link.log')
    config['sha256'][str(build/'components.exe')] = sha(build/'components.exe')
    build=work/'budget';build.mkdir()
    (build/'ace_module.F').write_text(budget_module((source/'fortran/ace_module.F').read_text()))
    for name in ('ace_input','ace_interpolation','microphy_p3'):
        for suffix in ('.o','.mod'):shutil.copyfile(work/'production'/(name+suffix),build/(name+suffix))
    checked(['gfortran',*FLAGS,*inc,'-c',str(build/'ace_module.F')],build,build/'compile.log')
    checked(['gfortran',*FLAGS,*inc,'-c',str(source/'fortran/test.F')],build,build/'driver.log')
    checked(['gfortran',*FLAGS,*[n.replace('.F','.o') for n in FILES],*libs,'-o','ace_model.exe'],build,build/'link.log')
    config['sha256'][str(build/'ace_model.exe')]=sha(build/'ace_model.exe')
    config['commands'] = commands
    write(work/'configuration.json', config)
    status(work, 'prepared')


def matlab_source(work, job, duration, dt, pulse=False):
    """Observational exports; numerical statements come from the frozen driver."""
    src = (work/'source/matlab/ace.m').read_text()
    src = replace(src, "dir_ace = fileparts(mfilename('fullpath'));",
                  f"dir_ace = '{work}/source/matlab';")
    src = replace(src, 'tspan = [0:1:60*8]*60;', f'tspan = 0:60:{duration};')
    # The one-step smoke uses output each step. Other runs save each minute.
    if duration < 60:
        src = replace(src, f'tspan = 0:60:{duration};', f'tspan = 0:{dt}:{duration};')
    if pulse:
        src = replace(src, '%% Define a struc to warp static ACE attributes', '''
X0(:,3,:)=reshape(0.05*sin((1:numel(zm))'/13).*cos((1:Ni)/7),[],1,Ni);
X0([1,end-10:end],3,:)=0;
%% Define a struc to warp static ACE attributes''')
    src = replace(src, '  yn = X0;', f'''  yn = X0;
  state_fid=fopen('{job}/matlab_states.bin','w');assert(state_fid>0);
  ref_fid=fopen('{job}/matlab_reference.bin','w');assert(ref_fid>0);
  fwrite(ref_fid,model.Tv_zc,'double');fclose(ref_fid);
  v=permute(yn(:,[3,1,2],:),[3,1,2]);fwrite(state_fid,v(:),'double');
  precip_fid=fopen('{job}/matlab_budget.bin','w');assert(precip_fid>0);''')
    # Per-step observation of dynamics/clipping, precipitation, damping and inventory.
    src = replace(src, '      disp(t)', '      disp(t)\n      before=yn;')
    src = replace(src, '      if model.precip_enabled', '      after_dynamics=yn;\n      if model.precip_enabled')
    src = replace(src, '      % Implicit Newtonian damping', '      after_precip=yn;\n      % Implicit Newtonian damping')
    src = replace(src, '    end%idn', '''      weights=model.rho_zc(1:end-1)*model.dz;
      for q={before,after_dynamics,after_precip,yn}
        inventory=reshape(sum(q{1}(1:end-1,2,:).*weights,1),[],1);
        fwrite(precip_fid,inventory,'double');
      end
    end%idn''')
    src = replace(src, '    X(:,:,:,idt+1) = yn;', '''    X(:,:,:,idt+1) = yn;
    v=permute(yn(:,[3,1,2],:),[3,1,2]);fwrite(state_fid,v(:),'double');''')
    src = replace(src, 'end%idt\nend', 'end%idt\n  fclose(state_fid);fclose(precip_fid);\nend')
    # Skip expensive postprocessing only after all prognostic exports complete.
    src = replace(src, '% Derived variables evaluated via post-processing (z,time,ACE-i)',
                  "disp('SLAB_INTEGRATION_COMPLETED');\nreturn\n% Derived variables evaluated via post-processing (z,time,ACE-i)")
    (job/'matlab_main.m').write_text(src)


def environment(config):
    env = dict(os.environ)
    env.update(OMP_NUM_THREADS=str(config['threads']), OMP_THREAD_LIMIT=str(config['threads']),
               OMP_DYNAMIC='FALSE', OMP_STACKSIZE='64M', OPENBLAS_NUM_THREADS='1')
    for key in ('ACE_VALIDATE_INPUT', 'ACE_STEPS', 'ACE_INPUT_MODE', 'ACE_LEGACY_DATA', 'ACE_OUTPUT_FILE'):
        env.pop(key, None)
    return env


def pair(work, name, duration, dt=6, h=True, v=True, physics='native', pulse=False, short=True):
    cfg = json.loads((work/'configuration.json').read_text())
    job = work/name; job.mkdir()
    matlab_source(work, job, duration, dt, pulse)
    env = environment(cfg)
    env.update(ACE_INPUT_FILE=cfg['input'], ACE_DT=str(dt), ACE_PHYSICS=physics,
               ACE_DHH='on' if h else 'off', ACE_DHV='on' if v else 'off')
    # Isolated copies receive the same deterministic nonzero-MF fixture.
    exe = work/'budget/ace_model.exe'
    env['ACE_SLAB_BUDGET']=str(job/'fortran_budget.bin')
    if pulse:
        exe = work/'pulse/ace_model.exe'
        if not exe.exists(): build_pulse(work)
    cmd = [str(exe), '--input', cfg['input'], '--physics', physics, '--dt', str(dt),
           '--dhh', env['ACE_DHH'], '--dhv', env['ACE_DHV'], '--state-output', str(job/'fortran_states.bin')]
    if duration < 60:
        cmd += ['--steps', str(round(duration/dt))]
    else:
        cmd += ['--intervals', str(duration//60), '--output', str(job/'fields.dat')]
    # Keep Fortran-specific OpenMP/BLAS controls out of the MATLAB launch.
    matlab_env = dict(os.environ)
    for key in ('ACE_VALIDATE_INPUT', 'ACE_STEPS', 'ACE_INPUT_MODE', 'ACE_LEGACY_DATA', 'ACE_OUTPUT_FILE'):
        matlab_env.pop(key, None)
    for key in ('ACE_INPUT_FILE', 'ACE_DT', 'ACE_PHYSICS', 'ACE_DHH', 'ACE_DHV'):
        matlab_env[key] = env[key]
    if cfg.get('matlab_threads') == 'default':
        launch = f"fprintf('MATLAB computation thread limit: %g\\n',maxNumCompThreads);run('{job}/matlab_main.m');"
    else:
        launch = (f"maxNumCompThreads({cfg.get('matlab_threads',cfg['threads'])});"
                  f"fprintf('MATLAB computation thread limit: %g\\n',maxNumCompThreads);run('{job}/matlab_main.m');")
    children = []
    handles = []
    try:
        for lang, command in [('matlab', ['matlab', '-batch', launch]), ('fortran', cmd)]:
            log = (job/(lang+'.log')).open('x'); handles.append(log)
            p = subprocess.Popen(command, cwd=job, env=matlab_env if lang == 'matlab' else env,
                                 stdout=log, stderr=subprocess.STDOUT)
            children.append((lang, p))
        write(job/'configuration.json', dict(duration_seconds=duration, dt=dt, h=h, v=v,
              physics=physics, pulse=pulse, matlab_threads=cfg.get('matlab_threads',cfg['threads']),
              fortran_threads=cfg['threads'], commands=[['matlab','-batch',launch], cmd]))
        while any(p.poll() is None for _, p in children):
            exits = {lang:p.poll() for lang,p in children}
            status(work, name, driver_pids={lang:p.pid for lang,p in children}, exits=exits,
                   output_bytes={lang:(job/(lang+'_states.bin')).stat().st_size
                                 if (job/(lang+'_states.bin')).exists() else 0 for lang,_ in children})
            if any(code not in (None,0) for code in exits.values()):
                raise RuntimeError('Driver failed: '+str(exits))
            time.sleep(10)
        if any(p.returncode for _,p in children): raise RuntimeError('Driver failed')
    finally:
        for _,p in children:
            if p.poll() is None: p.terminate()
        for _,p in children:
            if p.poll() is None: p.wait()
        for log in handles: log.close()
    if 'SLAB_INTEGRATION_COMPLETED' not in (job/'matlab.log').read_text():
        raise ValueError('MATLAB completion marker missing')
    result = compare(job, duration, dt, short)
    write(job/'results.json', result)
    return result


def build_pulse(work):
    build = work/'pulse';build.mkdir()
    src = (work/'source/fortran/ace_module.F').read_text()
    src = replace(src, 'call set_p3_context_directory(self%p3,trim(p3_directory))', '''
do i=1,ncols
  do k=1,nz
    self%X(i,k,1)=0.05*sin(real(k)/13.)*cos(real(i)/7.)
  enddo
enddo
self%X(:,1,1)=0.;self%X(:,nz-10:nz,1)=0.
call set_p3_context_directory(self%p3,trim(p3_directory))''')
    (build/'ace_module.F').write_text(budget_module(src))
    inc = shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs = shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    for name in ('ace_input','ace_interpolation','microphy_p3'):
        for suffix in ('.o','.mod'):shutil.copyfile(work/'production'/(name+suffix),build/(name+suffix))
    checked(['gfortran',*FLAGS,*inc,'-c',str(build/'ace_module.F')],build,build/'compile.log')
    checked(['gfortran',*FLAGS,*inc,'-c',str(work/'source/fortran/test.F')],build,build/'driver.log')
    checked(['gfortran',*FLAGS,*[n.replace('.F','.o') for n in FILES],*libs,'-o','ace_model.exe'],build,build/'link.log')


def states(job, lang, nc, nz, count):
    size = (nc if lang=='matlab' else nc+1)*nz*3
    path = job/(lang+'_states.bin')
    if lang == 'matlab':
        if path.stat().st_size != count*size*8: raise ValueError('Incomplete MATLAB states')
        data = np.memmap(path,'<f8',mode='r',shape=(count,size))
        return [a.reshape((nc,nz,3),order='F') for a in data]
    with path.open('rb') as f: header = np.fromfile(f,'<i4',3)
    if not np.array_equal(header,[nc,nz,3]): raise ValueError('Fortran header mismatch')
    if path.stat().st_size != 12+(count*size+nz)*8:raise ValueError('Incomplete Fortran states')
    initial=np.memmap(path,'<f8',mode='r',offset=12,shape=(size,))
    later=np.memmap(path,'<f8',mode='r',offset=12+(size+nz)*8,shape=(count-1,size))
    return [a.reshape((nc+1,nz,3),order='F')[:nc] for a in [initial,*later]]


def compare(job, duration, dt, short):
    cfg=json.loads((job.parent/'configuration.json').read_text())
    with Dataset(cfg['input']) as f:
        nc=len(f.dimensions['ace']);nz=len(f.dimensions['mf_level'])
        area=np.asarray(f['ace_area'][:]);area/=area.sum()
    count=round(duration/(dt if duration<60 else 60))+1
    m=states(job,'matlab',nc,nz,count);f=states(job,'fortran',nc,nz,count)
    errors=[];ranges={};means={}
    for lang,seq in [('matlab',m),('fortran',f)]:
        minimum=np.full(3,np.inf);maximum=-minimum;mean=0.
        for a in seq:
            if not np.isfinite(a).all() or np.min(a[:,:,2])<0:raise ValueError('Nonfinite or negative water: '+lang)
            minimum=np.minimum(minimum,a.min(axis=(0,1)));maximum=np.maximum(maximum,a.max(axis=(0,1)))
            mean=max(mean,float(np.max(np.abs(area@a[:,:,0]))))
        ranges[lang]=dict(min=minimum.tolist(),max=maximum.tolist());means[lang]=mean
    for a,b in zip(m,f):errors.append(np.max(np.abs(a-b),axis=(0,1)).tolist())
    errors=np.asarray(errors)
    if short and np.any(errors>LIMITS): raise ValueError('Short state limits exceeded: '+str(errors.max(axis=0)))
    if np.any(errors[0]>LIMITS):raise ValueError('Initial state mismatch')
    nwidth=(nc+1)*nz*3
    fv=np.fromfile(job/'fortran_states.bin','<f8',count=nz,offset=12+nwidth*8)
    mv=np.fromfile(job/'matlab_reference.bin','<f8')
    tv_error=float(np.max(np.abs(fv-mv)))
    if tv_error>1e-7:raise ValueError('Reference Tv mismatch')
    budget_report={}
    for lang in ('matlab','fortran'):
        budgets=np.fromfile(job/(lang+'_budget.bin'),'<f8')
        if budgets.size != round(duration/dt)*4*nc: raise ValueError('Incomplete per-step budget: '+lang)
        budgets=budgets.reshape((-1,4,nc))
        if not np.isfinite(budgets).all():raise ValueError('Nonfinite budget')
        increments=np.diff(budgets,axis=1).sum(axis=0)
        budget_report[lang]=dict(zip(['dynamics_and_clipping','native_precipitation','damping'],(increments@area).tolist()))
    return dict(duration_seconds=duration,saved_states=count,field_order=FIELDS,
                max_abs_error=errors.max(axis=0).tolist(),max_abs_error_each_state=errors.tolist(),
                short_limits=LIMITS.tolist() if short else None,reference_tv_error=tv_error,
                ranges=ranges,max_area_mean_MF=means,
                domain_water_increments_kg_m2=budget_report,
                scientific_acceptance='pending',sha256={p.name:sha(p) for p in job.glob('*.bin')})


def component_check(work):
    cfg=json.loads((work/'configuration.json').read_text())
    build=work/'components'
    checked([str(build/'components.exe'),cfg['input']],build,build/'run.log',environment(cfg))
    with (build/'components.bin').open('rb') as f:
        nc,nz,nb=np.fromfile(f,'<i4',3)
        x=np.fromfile(f,'<f8',nc*nz*3).reshape((nc,nz,3),order='F')
        ref=np.fromfile(f,'<f8',nz*8).reshape((nz,8),order='F')
        area=np.fromfile(f,'<f8',nc);perimeter=np.fromfile(f,'<f8',nc);tv=np.fromfile(f,'<f8',nz)
        modes=[];edges=[]
        for _ in range(4):
            modes.append(np.fromfile(f,'<f8',nc*nz*3).reshape((nc,nz,3),order='F'))
            edges.append(np.fromfile(f,'<f8',nc*(nb+1)).reshape((nc,nb+1),order='F'))
        if f.read(1):raise ValueError('Unexpected component data')
    # Independent NumPy evaluation of horizontal flux and vertical curvature.
    mf=x[:,:,0];dz=ref[0,4];rho=ref[:,0]
    up=7*(mf+np.roll(mf,-1,axis=1))-np.roll(mf,1,axis=1)-np.roll(mf,-2,axis=1)
    up=(up+np.sign(up)*(3*(mf-np.roll(mf,-1,axis=1))+np.roll(mf,-2,axis=1)-np.roll(mf,1,axis=1)))/12
    b=8*mf[:,1]-mf[:,2];up[:,0]=(b+np.sign(b)*(mf[:,2]-2*mf[:,1]))/12
    wc=up/rho
    flow=np.cumsum(area[:,None]*np.diff(mf,axis=1)/dz,axis=0)
    outer=np.r_[np.arange(1,nc),nc-1];inner=np.r_[0,np.arange(nc-1)]
    entrain=0.09*perimeter/area;entrain[-1]=0
    entinner=np.r_[0,0.09*perimeter[:-1]/area[1:]]
    fh=-entrain[:,None]*(up[:,:-1]-up[outer,:-1])-entinner[:,None]*(up[:,:-1]-up[inner,:-1])
    fh+=flow*np.where(flow>0,wc[outer,:-1],wc[:,:-1])/area[:,None]
    prev=np.vstack([np.zeros((1,nz-1)),flow[:-1]])
    fh-=prev*np.where(prev>0,wc[:,:-1],wc[inner,:-1])/area[:,None]
    curvature=(np.hstack([-fh[:,:1],fh[:,:-1]])-2*fh+np.hstack([fh[:,1:],np.zeros((nc,1))]))/dz**2
    # Derive native PMD forcing directly with MATLAB's km^2 area convention.
    native_flow=flow/1e6
    horizontal=(native_flow**2-(prev/1e6)**2)/rho[:-1]/(area[:,None]/1e6)
    ratio=(nz-1)//nb
    forcings={'PMDv':-curvature.reshape(nc,nb,ratio).mean(axis=2),
              'PMD':horizontal.reshape(nc,nb,ratio).mean(axis=2)}
    report={}
    with Dataset(cfg['input']) as data:
        for op,mode in [('PMDv',1),('PMD',2)]:
            actual=edges[mode]-edges[0];maximum=0.;scale=0.
            # All source cells, selected distinct responses and edge heights.
            for i in sorted({0,1,nc//2,nc-2,nc-1}):
                for k in (0,1,nb//2,nb-1,nb):
                    expected=float(np.sum(np.asarray(data[op][i,:,:,k])*forcings[op]))
                    maximum=max(maximum,abs(actual[i,k]-expected));scale=max(scale,abs(expected))
            if maximum>1e-12+1e-10*scale:raise ValueError('Momentum oracle mismatch '+op+': '+str(maximum))
            if np.max(np.abs(actual))==0:raise ValueError('Momentum test failed to excite '+op)
            report[op]=dict(max_abs_error=maximum,max_oracle_magnitude=scale,nonzero=True)
    additivity=float(np.max(np.abs(edges[3]-edges[2]-edges[1]+edges[0])))
    if additivity>1e-12:raise ValueError('Momentum switches not additive at fixed state')
    report['additivity_error']=additivity
    write(work/'component_results.json',report)


def verify(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for path,digest in {cfg['input']:cfg['input_sha256'],**cfg['sha256']}.items():
        if sha(path)!=digest:raise ValueError('Frozen input/source changed: '+path)


def pin_reference(work, reference):
    """Pin completed pre-layout artifacts before starting a fresh workspace."""
    if json.loads((work/'status.json').read_text())['phase'] != 'prepared':
        raise ValueError('Reference can only be attached before the first run')
    cfg=json.loads((work/'configuration.json').read_text())
    old=json.loads((reference/'configuration.json').read_text())
    if cfg['input_sha256']!=old['input_sha256']:
        raise ValueError('Layout preservation requires identical input')
    paths=['components/components.bin','build_gate_production/states.bin',
           'smoke/fortran_states.bin']
    paths += [f'nonzero_mf_h{h}v{v}/fortran_states.bin' for h in (0,1) for v in (0,1)]
    cfg['layout_reference']=dict(work=str(reference),configuration_sha256=sha(reference/'configuration.json'),
        artifacts={p:dict(path=str(reference/p),sha256=sha(reference/p)) for p in paths})
    # Retain complete per-step observations from an interrupted slow trajectory.
    budget=reference/'dry_10min/fortran_budget.bin'
    if budget.exists():
        with Dataset(cfg['input']) as data:ncols=len(data.dimensions['ace'])
        size=budget.stat().st_size//(4*ncols*8)*(4*ncols*8)
        if size:
            prefix=work/'reference_dry_budget_prefix.bin'
            with budget.open('rb') as stream:prefix.write_bytes(stream.read(size))
            cfg['layout_reference']['artifacts']['dry_10min/fortran_budget.bin']=dict(
                path=str(prefix),sha256=sha(prefix),prefix_bytes=size,complete_steps=size//(4*ncols*8))
    executed=work/'executed_runner.py'
    if Path(__file__).resolve()!=executed:shutil.copyfile(__file__,executed)
    cfg['sha256'][str(executed)]=sha(executed)
    write(work/'configuration.json',cfg)


def preserve_layout(work, relative):
    cfg=json.loads((work/'configuration.json').read_text())
    if 'layout_reference' not in cfg:return
    reference=cfg['layout_reference']['artifacts'][relative]
    before=sha(Path(reference['path']))
    if 'prefix_bytes' in reference:
        with (work/relative).open('rb') as stream:after=hashlib.sha256(stream.read(reference['prefix_bytes'])).hexdigest()
    else:after=sha(work/relative)
    if before!=reference['sha256'] or after!=before:
        raise ValueError('Layout change failed bitwise preservation: '+relative)
    path=work/'layout_preservation.json'
    report=json.loads(path.read_text()) if path.exists() else dict(reference=cfg['layout_reference'],checks={})
    report['checks'][relative]=dict(bitwise_equal=True,sha256=after)
    write(path,report)


def timestep_check(work):
    """Predeclared numerical screen, distinct from physical acceptance."""
    cfg=json.loads((work/'configuration.json').read_text())
    with Dataset(cfg['input']) as f:
        nc=len(f.dimensions['ace']);nz=len(f.dimensions['mf_level'])
    report={}
    for lang in ('matlab','fortran'):
        coarse=states(work/'native_10min',lang,nc,nz,11)
        medium=states(work/'dt_3',lang,nc,nz,11)
        fine=states(work/'dt_1p5',lang,nc,nz,11)
        e6=np.max([np.max(np.abs(a-b),axis=(0,1)) for a,b in zip(coarse,fine)],axis=0)
        e3=np.max([np.max(np.abs(a-b),axis=(0,1)) for a,b in zip(medium,fine)],axis=0)
        evolution=np.max([np.max(np.abs(a-fine[0]),axis=(0,1)) for a in fine],axis=0)
        bound=LIMITS+0.01*evolution
        passed=bool(np.all(e3<=e6+LIMITS) and np.all(e6<=bound))
        report[lang]=dict(error_dt6_vs_dt1p5=e6.tolist(),error_dt3_vs_dt1p5=e3.tolist(),
                          one_percent_evolution_bound=bound.tolist(),passed=passed)
    write(work/'timestep_results.json',dict(criteria='Refinement must not increase error beyond short limits; dt6 error <= short limit + 1% of observed evolution over 600 s. Numerical screening only.',results=report))
    if not all(r['passed'] for r in report.values()):raise ValueError('Timestep screening failed; review before long runs')


def continue_long(work):
    verify(work);timestep_check(work)
    pair(work,'native_1h',3600,short=False)
    pair(work,'native_8h',28800,short=False)
    status(work,'completed_pending_scientific_review',long_runs=True)


def run(work, long_runs):
    try:
        verify(work);status(work,'components');component_check(work)
        preserve_layout(work,'components/components.bin')
        # Check bounds/FPE build against production on the same one-step run.
        status(work,'debug_production_gate')
        cfg=json.loads((work/'configuration.json').read_text())
        for kind in ('debug','production'):
            job=work/('build_gate_'+kind);job.mkdir()
            checked([str(work/kind/'ace_model.exe'),'--input',cfg['input'],'--physics','native',
                     '--steps','1','--state-output',str(job/'states.bin')],job,job/'run.log',environment(cfg))
        if sha(work/'build_gate_debug/states.bin')!=sha(work/'build_gate_production/states.bin'):
            raise ValueError('Debug/production state mismatch')
        preserve_layout(work,'build_gate_production/states.bin')
        pair(work,'smoke',6)
        preserve_layout(work,'smoke/fortran_states.bin')
        if sha(work/'smoke/fortran_states.bin')!=sha(work/'build_gate_production/states.bin'):
            raise ValueError('Observational budget instrumentation changed the one-step state')
        for h,v in ((False,False),(True,False),(False,True),(True,True)):
            name=f'nonzero_mf_h{int(h)}v{int(v)}'
            pair(work,name,6,h=h,v=v,physics='none',pulse=True)
            preserve_layout(work,name+'/fortran_states.bin')
        pair(work,'dry_10min',600,physics='none')
        preserve_layout(work,'dry_10min/fortran_budget.bin')
        pair(work,'native_10min',600)
        for dt in (3,1.5):
            name='dt_'+str(dt).replace('.','p')
            pair(work,name,600,dt=dt,short=False)
        timestep_check(work)
        if long_runs:
            continue_long(work)
        status(work,'completed_pending_scientific_review',long_runs=long_runs)
    except BaseException:
        status(work,'failed',error=traceback.format_exc())
        raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--input',type=Path,default=ROOT/'data/input/goamazon314_88aces.nc')
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--long',action='store_true')
    parser.add_argument('--continue-long',action='store_true',help='Continue a completed short suite without rerunning it')
    parser.add_argument('--launch',action='store_true',help='Start the frozen runner in a detached supervisor')
    parser.add_argument('--stop',action='store_true',help='Stop this workspace supervisor and its children, retaining artifacts')
    parser.add_argument('--stop-reason',default='requested',help='Reason recorded when stopping this workspace')
    parser.add_argument('--reference-work',type=Path,help='Pin completed pre-layout artifacts before first launch')
    args=parser.parse_args();work=args.work.resolve()
    if args.stop:
        launch=json.loads((work/'launch.json').read_text());pid=launch['pid']
        command=Path(f'/proc/{pid}/cmdline').read_bytes()
        if str(work/'executed_runner.py').encode() not in command:
            raise ValueError('PID no longer belongs to this workspace supervisor')
        if os.getpgid(pid)!=pid:raise ValueError('Supervisor is not an isolated process group')
        os.killpg(pid,signal.SIGTERM)
        status(work,'stopped_'+args.stop_reason,previous_supervisor_pid=pid)
        return
    if args.prepare:prepare(work,args.input.resolve())
    if args.reference_work:pin_reference(work,args.reference_work.resolve())
    if args.launch:
        verify(work)
        if json.loads((work/'status.json').read_text())['phase']!='prepared':
            raise ValueError('Launch requires an unused prepared workspace')
        with (work/'supervisor.log').open('x') as log:
            command=[sys.executable,str(work/'executed_runner.py'),str(work),'--run']
            if args.long:command.append('--long')
            process=subprocess.Popen(command,cwd=work,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        write(work/'launch.json',dict(pid=process.pid,command=command))
        print(json.dumps(dict(pid=process.pid,workspace=str(work))))
    if args.run:run(work,args.long)
    if args.continue_long:
        try:continue_long(work)
        except BaseException:
            status(work,'failed',error=traceback.format_exc());raise


if __name__=='__main__':main()
