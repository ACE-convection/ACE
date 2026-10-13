#!/usr/bin/env python3
"""Gate multiACE dynamics/precipitation for 10 min, then run 3 h, 32 cores each.

Isolated production copies; all tendencies enabled, bubble-only forcing.
Independent 32-core placements have eight physical cores on each NUMA node.
The long run starts only after the paired gate and debug/production check.
"""
import argparse
import difflib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone

import numpy as np
from netCDF4 import Dataset

from run import ROOT, digest
from trajectory import replace_once

N, Z = 101, 401
LONG_DURATION_SECONDS = 10800
STATE_LIMITS = np.array([1e-9,1e-7,1e-11])
TENDENCY_LIMITS = np.array([1e-9,1e-8,1e-11])
PRECIPITATION_LIMITS = np.array([1e-7,1e-11])


def write(path, data):
    temporary=path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data,indent=2)+'\n')
    temporary.replace(path)


def cpu_sets():
    topology=subprocess.check_output(['lscpu','-p=CPU,CORE,SOCKET,NODE'],text=True)
    allowed=os.sched_getaffinity(0)
    nodes={};seen=set()
    for line in topology.splitlines():
        if line.startswith('#'):continue
        cpu,core,socket,node=map(int,line.split(','))
        if cpu not in allowed or (socket,core) in seen:continue
        seen.add((socket,core));nodes.setdefault(node,[]).append(cpu)
    if len(nodes)!=4 or any(len(cpus)<16 for cpus in nodes.values()):
        raise ValueError('Expected at least sixteen allowed physical cores on each of four NUMA nodes')
    return ({'matlab':[cpu for _,cpus in sorted(nodes.items()) for cpu in sorted(cpus)[:8]],
             'fortran':[cpu for _,cpus in sorted(nodes.items()) for cpu in sorted(cpus)[8:16]]},topology)


def prepare(work,initial_mf,*,single=False,duration=LONG_DURATION_SECONDS):
    input_file=ROOT/'data/input/manaus1342_khn26.nc'
    placements,topology=cpu_sets()
    work.mkdir(parents=True,exist_ok=False)
    source=(ROOT/'matlab/ace.m').read_text()
    if 'one_ace_only = 0;' not in source:raise ValueError('Expected multiACE production driver')
    matlab=replace_once(source,"dir_ace = fileparts(mfilename('fullpath'));",f"dir_ace = '{ROOT/'matlab'}';")
    if single:matlab=replace_once(matlab,'one_ace_only = 0;','one_ace_only = 1;')
    matlab=replace_once(matlab,'dt = 6;','dt = 4;')
    matlab=replace_once(matlab,'dTbl = 0.25;','dTbl = 1.0;')
    matlab=replace_once(matlab,'MF0 = 0*5;',f'MF0 = {initial_mf};')
    matlab=replace_once(matlab,'zt = 4e3;', 'zt = 1000;')
    matlab=replace_once(matlab,'tspan = [0:1:60*6]*60;', f'tspan = 0:60:{duration};')
    matlab=replace_once(matlab,'%% Define a struc to warp static ACE attributes',
                        'X0(:,3,2:end)=0; % Optional initial pulse only in ACE 1.\n\n%% Define a struc to warp static ACE attributes')
    matlab=replace_once(matlab,'  yn = X0;',f"""  yn = X0;
  global ace_multi_tendency_fid ace_multi_precip_fid
  ace_multi_tendency_fid=0;ace_multi_precip_fid=0;
  if startsWith(getenv('ACE_MULTI_TAG'),'gate_')
    ace_multi_tendency_fid=fopen(fullfile('{work}',getenv('ACE_MULTI_TAG'),'matlab_tendencies.bin'),'w');
    assert(ace_multi_tendency_fid>0);
  end
  if strcmp(getenv('ACE_MULTI_TAG'),'gate_native')
    ace_multi_precip_fid=fopen('{work}/gate_native/matlab_precip_sinks.bin','w');
    assert(ace_multi_precip_fid>0);
  end
  state_fid=fopen(fullfile('{work}',getenv('ACE_MULTI_TAG'),'matlab_states.bin'),'w');
  assert(state_fid>0);
  state_export=permute(yn(:,[3,1,2],:),[3,1,2]);fwrite(state_fid,state_export(:),'double');
""")
    matlab=replace_once(matlab,'    X(:,:,:,idt+1) = yn;',
                        "    X(:,:,:,idt+1) = yn;\n    state_export=permute(yn(:,[3,1,2],:),[3,1,2]);fwrite(state_fid,state_export(:),'double');")
    matlab=replace_once(matlab,'end%idt\nend',
                        'end%idt\n  fclose(state_fid);\n  if ace_multi_tendency_fid>0, fclose(ace_multi_tendency_fid); end\n  if ace_multi_precip_fid>0, fclose(ace_multi_precip_fid); end\nend')
    matlab=replace_once(matlab,'      if model.precip_enabled',
                        "      if ace_multi_precip_fid>0\n        precip_export=permute(cat(3,dTH,dQt),[2,1,3]);\n        fwrite(ace_multi_precip_fid,precip_export(:),'double');\n      end\n      if model.precip_enabled")
    matlab=replace_once(matlab,'    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end',
                        "    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end\n  global ace_multi_tendency_fid\n  if ace_multi_tendency_fid>0\n    tendency_export=permute(dXdt(:,[3,1,2],:),[3,1,2]);\n    fwrite(ace_multi_tendency_fid,tendency_export(:),'double');\n  end")
    (work/'multi_main.m').write_text(matlab)
    original=(ROOT/'fortran/src/ace_module.F').read_text()
    if '!dXdt(2:ncols,:,:)=0.' not in original:raise ValueError('Expected unmasked production tendencies')
    module=replace_once(original,'\ncontains\n\nsubroutine ace_driver',
                        '\ninteger,save::multi_tendency_unit=0,multi_precip_unit=0\n\ncontains\n\nsubroutine ace_driver')
    if single:module=replace_once(module,'!dXdt(2:ncols,:,:)=0.','dXdt(2:ncols,:,:)=0.')
    module=replace_once(module,'call precip_sinks(ncols,nz,n_prog,Ref(:,7),K1(:,:,1:2))',
                        'call precip_sinks(ncols,nz,n_prog,Ref(:,7),K1(:,:,1:2))\ncall dump_multi_precip(ncols,nz,K1(:,:,1:2))')
    module=replace_once(module,'end subroutine ace_tendency',
                        'call dump_multi_tendency(ncols,nz,n_prog,dXdt)\nend subroutine ace_tendency')
    module=replace_once(module,'end module',"""
subroutine dump_multi_tendency(ncols,nz,n_prog,tendency)
integer,intent(in)::ncols,nz,n_prog
real,intent(in)::tendency(ncols,nz,n_prog)
character(1024)::path
if (multi_tendency_unit==0) then
  call get_environment_variable('ACE_MULTI_TENDENCY_FILE',path)
  if (len_trim(path)==0) return
  open(newunit=multi_tendency_unit,file=trim(path),access='stream',form='unformatted',status='new')
endif
write(multi_tendency_unit) tendency
flush(multi_tendency_unit)
end subroutine
subroutine dump_multi_precip(ncols,nz,sinks)
integer,intent(in)::ncols,nz
real,intent(in)::sinks(ncols,nz,2)
character(1024)::path
if (multi_precip_unit==0) then
  call get_environment_variable('ACE_MULTI_PRECIP_FILE',path)
  if (len_trim(path)==0) return
  open(newunit=multi_precip_unit,file=trim(path),access='stream',form='unformatted',status='new')
endif
write(multi_precip_unit) sinks
flush(multi_precip_unit)
end subroutine
end module""")
    (work/'ace_module_multi.F').write_text(module)
    driver_original=(ROOT/'fortran/src/test.F').read_text()
    driver=replace_once(driver_original,'dum1=Tr(1,k)+0.25','dum1=Tr(1,k)+1.0')
    if initial_mf:
        driver=replace_once(driver,'call set_p3_lookup_directory(trim(p3_directory))',
                            f"do k=1,nz\n  if (zm(k)<=1000.) X(1,k,1)={initial_mf}*sin(4.*atan(1.)*zm(k)/1000.)\nenddo\ncall set_p3_lookup_directory(trim(p3_directory))")
    driver=replace_once(driver,'use ace_module\n','use ace_module\nuse omp_lib, only: omp_get_max_threads,omp_get_num_threads\n')
    driver=replace_once(driver,'shared_input=.true.',"""if (omp_get_max_threads()/=32) error stop 'Expected OpenMP cap 32'
!$omp parallel
!$omp single
write(*,*) 'ACE_MULTI_OPENMP_TEAM',omp_get_num_threads()
if (omp_get_num_threads()/=32) error stop 'Expected OpenMP team 32'
!$omp end single
!$omp end parallel
shared_input=.true.""")
    (work/'multi_driver.F').write_text(driver)
    for label,before,after in [('matlab',source,matlab),('module',original,module),('driver',driver_original,driver)]:
        (work/(label+'.diff')).write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=label+'/production',tofile=label+'/multi_test')))
    flags=['-cpp','-ffree-form','-ffree-line-length-none','-O2','-fdefault-real-8','-fdefault-double-8','-fopenmp']
    checks=['-g','-fcheck=all,no-array-temps','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
    inc=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    commands=[];products=[]
    sources=[ROOT/'fortran/src'/(name+'.F') for name in ('ace_input','ace_interpolation','microphy_p3')]
    sources.extend([work/'ace_module_multi.F',work/'multi_driver.F'])
    for label,options in [('build',flags),('debug',flags+checks)]:
        build=work/label;build.mkdir();objects=[]
        for src,name in zip(sources,('ace_input','ace_interpolation','microphy_p3','ace_module','test')):
            obj=build/(name+'.o');objects.append(obj)
            command=['gfortran',*options,*inc,'-c',str(src),'-o',str(obj)];commands.append(command)
            with (build/(name+'.compile.log')).open('w') as log:
                subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
        command=['gfortran',*options,*map(str,objects),*libs,'-o','ace_model.exe'];commands.append(command)
        subprocess.run(command,cwd=build,check=True)
        products.extend([*objects,build/'ace_model.exe'])
    for tag,steps in [('gate_none','150'),('gate_native','150'),('full','')]:
        (work/tag).mkdir()
        physics='none' if tag=='gate_none' else 'native'
        (work/(tag+'_launch.m')).write_text(f"""maxNumCompThreads(32);
assert(maxNumCompThreads==32,'Expected MATLAB computational cap 32');
fprintf('ACE_MULTI_MATLAB_CAP %d\\n',maxNumCompThreads);
setenv('ACE_INPUT_MODE','shared');setenv('ACE_VALIDATE_INPUT','');
setenv('ACE_INPUT_FILE','{input_file}');setenv('ACE_PHYSICS','{physics}');
setenv('ACE_STEPS','{steps}');setenv('ACE_MULTI_TAG','{tag}');
setenv('ACE_OUTPUT_FILE','{work}/{tag}/matlab.nc');
run('{work}/multi_main.m');
assert(maxNumCompThreads==32,'MATLAB computational cap changed');
fprintf('ACE_MULTI_MATLAB_CAP_FINAL %d\\n',maxNumCompThreads);
""")
    with Dataset(input_file) as ds:
        widths=np.asarray(ds['ace_width'][:]);areas=np.asarray(ds['ace_area'][:])
        case={'input':str(input_file),'input_sha256':digest(input_file),'geometry':str(ds.geometry),
              'profile_index':int(ds.profile_index),'full_basis_columns':len(widths),
              'ace_width_m':widths.tolist(),'ace_area_m2':areas.tolist(),
              'ace_center_from_left_boundary_m':(np.cumsum(widths)-widths/2).tolist(),
              'height_m':np.asarray(ds['zm'][:]).tolist(),'dt_seconds':4,'bubble_delta_K':1,
              'bubble_ace_one_based':1,'bubble_levels_one_based':[11,51],
              'initial_mf_amplitude':initial_mf,'physics':'native','gate_physics':['native'] if single else ['none','native'],'multiACE':not single,'mean_mf_zero':True,
              'gate_duration_seconds':600,'gate_steps':150,'duration_seconds':duration,
              'output_interval_seconds':60,'threads_per_language':32,
              'basis_policy':'Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion.'}
    if case['geometry']!='slab' or len(widths)!=101:raise ValueError('Unexpected basis geometry')
    paths=[ROOT/'matlab/ace.m',ROOT/'fortran/src/ace_module.F',ROOT/'fortran/src/test.F',input_file,
           *sources,*products,work/'multi_main.m',work/'gate_none_launch.m',work/'gate_native_launch.m',work/'full_launch.m',Path(__file__).resolve(),ROOT/'tests/khn26/plot_multi.py']
    paths.extend(sorted((ROOT/'matlab').rglob('*.m')))
    (work/'cpu_topology.csv').write_text(topology)
    shutil.copyfile(Path(__file__),work/'executed_runner.py')
    write(work/'configuration.json',{'case':case,'cpu_sets':placements,'compiled_commands':commands,
          'production_flags':flags,'debug_flags':checks,'state_gate_limits':STATE_LIMITS.tolist(),
          'tendency_gate_limits':TENDENCY_LIMITS.tolist(),'precipitation_gate_limits':PRECIPITATION_LIMITS.tolist(),
          'sha256':{str(p):digest(p) for p in paths},
          'fairness':'32 disjoint physical cores per program, 8 per NUMA node, computational/OpenMP cap 32; shared host and separate runtimes remain.',
          'limits':'Regression gates are numerical checks, not physical gravity-wave or three-hour acceptance criteria.'})
    print(json.dumps({'prepared':str(work),'case':case,'cpu_sets':placements},indent=2),flush=True)


def state_frames(work,tag,name,count):
    p=work/tag/(name+'_states.bin');size=N*Z*3;fsize=(N+1)*Z*3
    expected=count*size*8 if name=='matlab' else 12+(count*fsize+Z)*8
    if p.stat().st_size!=expected:raise ValueError(f'{name}: incomplete {tag} state stream')
    if name=='fortran' and not np.array_equal(np.fromfile(p,'<i4',count=3),[N,Z,3]):raise ValueError('State header')
    for i in range(count):
        if name=='matlab':
            yield np.memmap(p,'<f8',mode='r',offset=i*size*8,shape=(size,)).reshape((N,Z,3),order='F')
        else:
            offset=12+8*(i*fsize+(Z if i else 0))
            yield np.memmap(p,'<f8',mode='r',offset=offset,shape=(fsize,)).reshape((N+1,Z,3),order='F')[:N]


def compare_states(work,tag,*,strict=True):
    cfg=json.loads((work/'configuration.json').read_text());case=cfg['case']
    count=151 if tag.startswith('gate_') else case['duration_seconds']//60+1
    areas=np.asarray(case['ace_area_m2']);fractions=areas/areas.sum()
    heights=np.asarray(case['height_m']);errors=[];means=[];mf=[];ranges=[]
    sums=np.zeros(3);ref_sums=np.zeros(3)
    for i,(m,f) in enumerate(zip(state_frames(work,tag,'matlab',count),state_frames(work,tag,'fortran',count))):
        if not np.isfinite(m).all() or not np.isfinite(f).all() or min(m[:,:,2].min(),f[:,:,2].min())<0:
            raise ValueError(f'Nonfinite state or negative qt at record {i}')
        errors.append(np.max(np.abs(f-m),axis=(0,1)).tolist())
        means.append([float(np.max(np.abs(np.sum(v[:,:,0]*fractions[:,None],axis=0)))) for v in (m,f)])
        mf.append(np.stack([m[:,:,0],f[:,:,0]]))
        ranges.append([[v.min(axis=(0,1)).tolist(),v.max(axis=(0,1)).tolist()] for v in (m,f)])
        sums+=np.sum((f-m)**2,axis=(0,1));ref_sums+=np.sum(m**2,axis=(0,1))
        if i==0:
            pulse=case['initial_mf_amplitude']*np.sin(np.pi*heights/1000);pulse[heights>1000]=0
            for v in (m,f):
                if np.any(v[1:,:,0]!=0) or np.max(np.abs(v[0,:,0]-pulse))>1e-14:raise ValueError('Initial MF policy')
            if np.any(np.asarray(errors[0])>STATE_LIMITS):raise ValueError('Initial state mismatch')
        if i and max(means[-1])>1e-10:raise ValueError('Area-mean MF constraint failed')
    errors=np.asarray(errors);mf=np.asarray(mf)
    maximum=errors.max(axis=0)
    if np.max(np.abs(mf[1:,:,1:]))==0:raise ValueError('No multiACE MF response')
    times=np.arange(count)*(4 if tag.startswith('gate_') else 60)
    response=np.max(np.abs(mf),axis=3)
    result={'tag':tag,'saved_states':count,'actual_duration_seconds':int(times[-1]),
            'time_seconds':times.tolist(),'field_order':['MF','theta_e','qt'],
            'max_abs_error':maximum.tolist(),'max_abs_error_each_state':errors.tolist(),
            'rms_error':np.sqrt(sums/(count*N*Z)).tolist(),
            'relative_L2_error':np.sqrt(sums/ref_sums).tolist(),
            'area_mean_MF_max_matlab_fortran':np.max(means,axis=0).tolist(),
            'finite_saved_states':True,'nonnegative_saved_qt':True,
            'extrema_each_state_matlab_fortran':ranges,
            'response_peak_per_ace_matlab_fortran':response.max(axis=0).tolist(),
            'response_final_per_ace_matlab_fortran':response[-1].tolist(),
            'case':case,'scope':'Complete saved-state comparison; wave interpretation and long-run tolerances require review.'}
    result['limits']=STATE_LIMITS.tolist()
    result['passed']=bool(np.all(maximum<=STATE_LIMITS))
    result['artifacts_sha256']={name:digest(work/tag/name) for name in ('matlab_states.bin','fortran_states.bin','matlab.nc')}
    np.savez_compressed(work/tag/'mf_all_aces.npz',time_seconds=times,height_m=heights,
                        x_center_m=np.asarray(case['ace_center_from_left_boundary_m']),
                        matlab=mf[:,0],fortran=mf[:,1])
    write(work/(tag+'_state_results.json'),result)
    if strict and tag.startswith('gate_') and not result['passed']:raise ValueError(f'10-minute state gate failed: {maximum}')
    return result


def compare_tendencies(work,tag,*,strict=True):
    frames=150*9;size=N*Z*3
    paths=[work/tag/(name+'_tendencies.bin') for name in ('matlab','fortran')]
    if any(p.stat().st_size!=frames*size*8 for p in paths):raise ValueError('Incomplete 1350-frame tendency streams')
    streams=[p.open('rb') for p in paths]
    maxima=np.zeros(3);sum_error=np.zeros(3);sums=np.zeros(3);per_step=[]
    for step in range(150):
        error=np.zeros(3)
        for stage in range(9):
            index=step*9+stage
            m,f=[np.fromfile(v,'<f8',count=size).reshape((N,Z,3),order='F') for v in streams]
            if not np.isfinite(m).all() or not np.isfinite(f).all():raise ValueError('Nonfinite tendency')
            difference=np.abs(f-m);error=np.maximum(error,difference.max(axis=(0,1)))
            sum_error+=np.sum((f-m)**2,axis=(0,1));sums+=np.sum(m**2,axis=(0,1))
        per_step.append(error.tolist());maxima=np.maximum(maxima,error)
    for stream in streams:stream.close()
    result={'steps':150,'SSPRK_stages_per_step':9,'compared_frames':frames,
            'field_order':['MF_tendency','theta_e_tendency','qt_tendency'],
            'max_abs_error':maxima.tolist(),'max_abs_error_each_step':per_step,
            'rms_error':np.sqrt(sum_error/(frames*N*Z)).tolist(),
            'relative_L2_error':np.sqrt(np.divide(sum_error,sums,out=np.zeros(3),where=sums>0)).tolist(),
            'limits':TENDENCY_LIMITS.tolist(),'passed':bool(np.all(maxima<=TENDENCY_LIMITS)),
            'scope':'Corresponding stages on independently evolving trajectories, not a forced common-state tendency test.',
            'artifacts_sha256':{str(p):digest(p) for p in paths}}
    write(work/(tag+'_tendency_results.json'),result)
    if strict and not result['passed']:raise ValueError(f'10-minute tendency gate failed: {maxima}')
    return result


def compare_precipitation(work,*,strict=True):
    tag='gate_native';frames=150;size=N*Z*2
    paths=[work/tag/(name+'_precip_sinks.bin') for name in ('matlab','fortran')]
    if any(p.stat().st_size!=frames*size*8 for p in paths):raise ValueError('Incomplete precipitation sink streams')
    streams=[np.memmap(p,'<f8',mode='r',shape=(frames,size)) for p in paths]
    maxima=np.zeros(2);minimum_water_removal=np.inf;nonzero=[];removal=[]
    with Dataset(ROOT/'data/input/manaus1342_khn26.nc') as ds:
        area=np.asarray(ds['ace_area'][:]);weights=area[:,None]/area.sum()*np.asarray(ds['rho_zc'][:400])[None,:]*float(ds['dz'][...])
    for index in range(frames):
        m,f=[v[index].reshape((N,Z,2),order='F') for v in streams]
        if not np.isfinite(m).all() or not np.isfinite(f).all():raise ValueError('Nonfinite precipitation sinks')
        maxima=np.maximum(maxima,np.max(np.abs(f-m),axis=(0,1)))
        minimum_water_removal=min(minimum_water_removal,float(-m[:,:,1].max()),float(-f[:,:,1].max()))
        nonzero.append([int(np.count_nonzero(v[:,:,1]<0)) for v in (m,f)])
        removal.append([float(-np.sum(v[:,:400,1]*weights)*4) for v in (m,f)])
    if minimum_water_removal < 0:raise ValueError('Native precipitation added total water')
    if not np.any(nonzero):raise ValueError('No nonzero water sink: precipitation branch not exercised')
    result={'steps':frames,'field_order':['theta_e_sink','qt_sink'],'max_abs_error':maxima.tolist(),
            'finite_sinks':True,'nonnegative_water_removal':True,
            'nonzero_water_sink_cells_each_step_matlab_fortran':nonzero,
            'domain_integrated_water_removal_kg_m2_matlab_fortran':np.sum(removal,axis=0).tolist(),
            'water_removal_each_step_matlab_fortran':removal,'limits':PRECIPITATION_LIMITS.tolist(),
            'passed':bool(np.all(maxima<=PRECIPITATION_LIMITS)),
            'scope':'Actual post-SSPRK native sinks on evolving states; removal is not transported surface rain or a closed water budget.',
            'artifacts_sha256':{str(p):digest(p) for p in paths}}
    write(work/'gate_native_precipitation_results.json',result)
    if strict and not result['passed']:raise ValueError(f'Precipitation gate failed: {maxima}')
    return result


def verify(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for p,expected in cfg['sha256'].items():
        if digest(p)!=expected:raise ValueError(f'Provenance changed: {p}')
    return cfg


def environment(cfg,name):
    env=os.environ.copy()
    env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE',
               OMP_MAX_ACTIVE_LEVELS='1',MKL_NUM_THREADS='32',MKL_DYNAMIC='FALSE',
               OPENBLAS_NUM_THREADS='32',BLIS_NUM_THREADS='32',VECLIB_MAXIMUM_THREADS='32')
    if name=='fortran':
        places=','.join('{'+str(cpu)+'}' for cpu in cfg['cpu_sets'][name])
        env.update(OMP_PROC_BIND='spread',OMP_PLACES=places,OMP_DISPLAY_ENV='TRUE')
    else:
        env.pop('OMP_PROC_BIND',None);env.pop('OMP_PLACES',None)
        env['MATLAB_PREFDIR']=str(Path('/tmp')/'ace-khn26-multi32-prefs')
        Path(env['MATLAB_PREFDIR']).mkdir(exist_ok=True)
    return env


def launch_child(work,tag,name,cfg,debug=False):
    out=work/tag
    cpus=','.join(map(str,cfg['cpu_sets'][name]))
    prefix=['taskset','-c',cpus]
    env=environment(cfg,name)
    if name=='matlab':command=prefix+['matlab','-batch',f"run('{work}/{tag}_launch.m')"]
    else:
        folder='debug' if debug else 'build'
        state='debug_states.bin' if debug else 'fortran_states.bin'
        physics='none' if tag=='gate_none' else 'native'
        command=prefix+[str(work/folder/'ace_model.exe'),'--input',cfg['case']['input'],'--physics',physics,
                        '--dt','4','--state-output',str(out/state)]
        if debug:command+=['--steps','10']
        elif tag.startswith('gate_'):command+=['--steps','150']
        else:command+=['--intervals',str(cfg['case']['duration_seconds']//60),'--output',str(out/'fortran.dat')]
        env['ACE_MULTI_TENDENCY_FILE']=str(out/('debug_tendencies.bin' if debug else 'fortran_tendencies.bin')) if tag.startswith('gate_') else ''
        env['ACE_MULTI_PRECIP_FILE']=str(out/('debug_precip_sinks.bin' if debug else 'fortran_precip_sinks.bin')) if tag=='gate_native' else ''
    label='debug' if debug else name
    log=(out/(label+'.log')).open('x')
    process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,
                             stdin=subprocess.DEVNULL,start_new_session=True)
    # taskset must apply its mask before the first supervisor observation.
    deadline=time.monotonic()+5
    while process.poll() is None:
        if set(os.sched_getaffinity(process.pid))<=set(cfg['cpu_sets'][name]):break
        if time.monotonic()>deadline:
            import signal
            os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=10);log.close()
            raise ValueError('taskset did not establish the requested CPU mask')
        time.sleep(.01)
    return {'name':label,'process':process,'log':log,'command':command,'cpu_set':cfg['cpu_sets'][name]}


def thread_affinity(pid):
    masks=[]
    try:tasks=list((Path('/proc')/str(pid)/'task').iterdir())
    except FileNotFoundError:return []
    for task in tasks:
        try:masks.append(sorted(os.sched_getaffinity(int(task.name))))
        except ProcessLookupError:pass
    return sorted(set(cpu for mask in masks for cpu in mask))


def monitor(work,tag,children):
    try:
        while any(c['process'].poll() is None for c in children):
            codes={c['name']:c['process'].poll() for c in children}
            if any(code not in (None,0) for code in codes.values()):raise RuntimeError(f'{tag} driver failed: {codes}')
            affinities={c['name']:thread_affinity(c['process'].pid) for c in children if c['process'].poll() is None}
            info={'state':tag+'_running','updated_utc':datetime.now(timezone.utc).isoformat(),'supervisor_pid':os.getpid(),
                  'driver_pids':{c['name']:c['process'].pid for c in children},'exit_codes':codes,
                  'thread_cpu_unions':affinities,
                  'artifact_bytes':{p.name:p.stat().st_size for p in (work/tag).glob('*.bin')}}
            for c in children:
                if not set(affinities.get(c['name'],[]))<=set(c['cpu_set']):
                    raise ValueError('Driver thread escaped its allocated CPU set')
            write(work/'status.json',info)
            print(json.dumps(info),flush=True)
            time.sleep(20)
        if any(c['process'].returncode!=0 for c in children):raise RuntimeError('Driver exited unsuccessfully')
        write(work/tag/'exits.json',{c['name']:{'exit_code':c['process'].returncode,'command':c['command']} for c in children})
    except BaseException:
        for c in children:
            if c['process'].poll() is None:
                import signal
                os.killpg(c['process'].pid,signal.SIGTERM)
        for c in children:
            try:c['process'].wait(timeout=10)
            except subprocess.TimeoutExpired:
                import signal
                os.killpg(c['process'].pid,signal.SIGKILL);c['process'].wait()
        write(work/'status.json',{'state':'failed','tag':tag,'driver_exit_codes':{c['name']:c['process'].returncode for c in children}})
        raise
    finally:
        for c in children:c['log'].close()


def thread_evidence(work,tag):
    matlab=(work/tag/'matlab.log').read_text();fortran=(work/tag/'fortran.log').read_text()
    if not re.search(r'ACE_MULTI_MATLAB_CAP\s+32\b',matlab) or not re.search(r'ACE_MULTI_MATLAB_CAP_FINAL\s+32\b',matlab):
        raise ValueError('Missing MATLAB thread-cap evidence')
    if not re.search(r'ACE_MULTI_OPENMP_TEAM\s+32\b',fortran):raise ValueError('Missing Fortran team evidence')
    return {'matlab_cap_start_end':[32,32],'fortran_openmp_team':32,
            'scope':'Computational cap/team and CPU affinity; background threads may exist and not all model sections are parallel.'}


def run(work,gate_only=False):
    cfg=verify(work)
    try:
        if not gate_only and cfg['case']['duration_seconds']!=LONG_DURATION_SECONDS:
            raise ValueError('Long runs require a fresh three-hour configuration')
        if not (work/'gate_passed.json').exists():
            gates={}
            for tag in ('gate_none','gate_native'):
                # Debug check runs alongside MATLAB on disjoint core sets.
                matlab=launch_child(work,tag,'matlab',cfg)
                debug=launch_child(work,tag,'fortran',cfg,debug=True)
                try:
                    while debug['process'].poll() is None:
                        write(work/'status.json',{'state':tag+'_debug_running','supervisor_pid':os.getpid(),
                              'driver_pids':{'matlab':matlab['process'].pid,'debug':debug['process'].pid},
                              'exit_codes':{'matlab':matlab['process'].poll(),'debug':debug['process'].poll()}})
                        if matlab['process'].poll() not in (None,0):raise RuntimeError('MATLAB gate startup failed')
                        time.sleep(10)
                    debug['log'].close()
                    if debug['process'].returncode:raise RuntimeError('Checked Fortran gate failed')
                    production=launch_child(work,tag,'fortran',cfg)
                    monitor(work,tag,[matlab,production])
                except BaseException:
                    import signal
                    for child in (matlab,debug):
                        if child['process'].poll() is None:
                            os.killpg(child['process'].pid,signal.SIGTERM)
                            child['process'].wait(timeout=10)
                        child['log'].close()
                    raise
                checks={'states':12+(11*(N+1)*Z*3+Z)*8,'tendencies':90*N*Z*3*8}
                if tag=='gate_native':checks['precip_sinks']=10*N*Z*2*8
                for suffix,expected_size in checks.items():
                    debug_path=work/tag/('debug_'+suffix+'.bin')
                    if debug_path.stat().st_size!=expected_size:raise ValueError('Incomplete checked gate stream')
                    with debug_path.open('rb') as a,(work/tag/('fortran_'+suffix+'.bin')).open('rb') as b:
                        while chunk:=a.read(1024*1024):
                            if chunk!=b.read(len(chunk)):raise ValueError(f'Checked/production {suffix} prefix differs')
                states=compare_states(work,tag,strict=False);tendencies=compare_tendencies(work,tag,strict=False)
                gates[tag]={'passed':True,'actual_duration_seconds':600,
                            'checked_production_ten_step_byte_identity':True,'thread_evidence':thread_evidence(work,tag),
                            'state_max_abs_error':states['max_abs_error'],'tendency_max_abs_error':tendencies['max_abs_error']}
                if tag=='gate_native':gates[tag]['precipitation']=compare_precipitation(work,strict=False)
                gates[tag]['passed']=states['passed'] and tendencies['passed'] and (tag!='gate_native' or gates[tag]['precipitation']['passed'])
                write(work/(tag+'_gate_results.json'),gates[tag])
                if not gates[tag]['passed']:raise ValueError(f'{tag}: numerical gate failed; all comparison reports saved')
                verify(work)
                write(work/(tag+'_passed.json'),gates[tag])
                make_plots(work,tag)
            write(work/'gate_passed.json',{'passed':True,'gates':gates,
                  'configuration_sha256':digest(work/'configuration.json'),'cpu_sets':cfg['cpu_sets']})
            print('Both ten-minute gates passed.',flush=True)
        else:
            gate=json.loads((work/'gate_passed.json').read_text())
            if gate['configuration_sha256']!=digest(work/'configuration.json'):raise ValueError('Gate configuration changed')
        if gate_only:
            write(work/'status.json',{'state':'gates_passed','actual_duration_seconds':600,'full_started':False})
            return
        print('Starting native-precipitation three-hour runs.',flush=True)
        children=[]
        try:
            for name in ('matlab','fortran'):children.append(launch_child(work,'full',name,cfg))
            monitor(work,'full',children)
        except BaseException:
            for child in children:
                if child['process'].poll() is None:
                    import signal
                    os.killpg(child['process'].pid,signal.SIGTERM)
            raise
        result=compare_states(work,'full');result['thread_evidence']=thread_evidence(work,'full')
        # Independently initialized long run must reproduce its own 10-min gate.
        for name in ('matlab','fortran'):
            gate=list(state_frames(work,'gate_native',name,151))[::15]
            full=state_frames(work,'full',name,LONG_DURATION_SECONDS//60+1)
            if any(not np.array_equal(a,b) for a,b in zip(gate,full)):
                raise ValueError(f'{name}: full prefix differs from ten-minute gate')
        result['exact_gate_prefix_identity_matlab_fortran']=[True,True]
        verify(work);result['provenance_rechecked']=True
        write(work/'full_state_results.json',result)
        make_plots(work,'full')
        write(work/'status.json',{'state':'completed_pending_scientific_review','saved_states':LONG_DURATION_SECONDS//60+1,
              'actual_duration_seconds':LONG_DURATION_SECONDS,'max_abs_error':result['max_abs_error']})
    except BaseException as exc:
        write(work/'status.json',{'state':'failed','error':str(exc)})
        raise


def make_plots(work,tag):
    env=os.environ.copy()
    env['PYTHONPATH']='/tmp/ace-mf-plot-deps'
    env['MPLCONFIGDIR']='/tmp/ace-mf-matplotlib'
    command=[sys.executable,str(ROOT/'tests/khn26/plot_multi.py'),str(work),'--tag',tag]
    with (work/tag/'plots.log').open('w') as log:
        process=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    write(work/tag/'plot_status.json',{'exit_code':process.returncode,'command':command,
          'state':'completed' if process.returncode==0 else 'failed'})
    if process.returncode:print(f'{tag}: plotting failed; numerical reports preserved',flush=True)


def launch(work):
    verify(work)
    with (work/'supervisor.log').open('x') as log:
        child=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
                               stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,
                               start_new_session=True,close_fds=True)
    write(work/'supervisor.json',{'pid':child.pid,'work':str(work),'log':str(work/'supervisor.log')})
    print(json.dumps({'supervisor_pid':child.pid,'work':str(work)}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--initial-mf',type=float,default=0.)
    parser.add_argument('--gate-only',action='store_true')
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--prepare',action='store_true')
    action.add_argument('--run',action='store_true')
    action.add_argument('--launch',action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work,args.initial_mf)
    if args.run:run(work,gate_only=args.gate_only)
    if args.launch:launch(work)
