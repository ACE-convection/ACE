#!/usr/bin/env python3
"""Observe singleACE SSPRK stages and split operators in isolated driver copies.

Uses preserved three-hour drivers and requires byte-identical saved states.
Records tracer flux rates independently of the final masked tendency.
Does not time performance, change equations or certify total-energy closure.
"""
import argparse
import difflib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

import numpy as np
from single import ROOT, digest
from trajectory import replace_once

REFERENCE = ROOT/'migration_work/khn26_single_openmp6_3h'
MATLAB_REFERENCE = ROOT/'migration_work/khn26_single_3h'
RK_WEIGHTS = np.array([1/6,1/15,1/15,1/15,1/15,1/15,1/6,1/6,1/6])

MATLAB_EVENT = """function ace_budget_event(code,X,model)
global ace_budget_step ace_budget_stage ace_budget_event_fid
if code==1
  ace_budget_step=ace_budget_step+1; ace_budget_stage=0;
end
weights=model.rho_zc(1:end-1)*model.dz.*reshape(model.Ai/sum(model.Ai),1,1,[]);
anomaly=X(1:end-1,1:2,:)-[model.theta_e_zc(1:end-1),model.qt_zc(1:end-1)];
inv=sum(anomaly.*weights,[1,3]);
edge_weights=ones(model.Nzm,1)*model.dz; edge_weights([1,end])=model.dz/2;
ke=sum(0.5*X(:,3,:).^2./model.rho_zi.*edge_weights.*reshape(model.Ai/sum(model.Ai),1,1,[]),'all');
fwrite(ace_budget_event_fid,[ace_budget_step,code,inv,ke,min(X(:,2,:),[],'all')],'double');
end
"""

MATLAB_STAGE = """function ace_budget_stage_record(X,dXdt,dCdt,ioflow,rho0wC,model)
global ace_budget_step ace_budget_stage ace_budget_stage_fid
ace_budget_stage=ace_budget_stage+1;
last=model.Nzm-11; frac=model.Ai(1)/sum(model.Ai);
vertical=frac*(rho0wC(1,:,1)-rho0wC(last+1,:,1));
flow=ioflow(1:last,1);
upwind=(flow>0).*X(1:last,1:2,2)+(flow<0).*X(1:last,1:2,1);
lateral=sum(flow.*upwind,1)*model.dz/sum(model.Ai);
mix=-sum(model.eps_tur(1,1,1)*(X(1:last,1:2,1)-X(1:last,1:2,2)).*model.rho_zc(1:last),1)*model.dz*frac;
weights=model.rho_zc(1:last)*model.dz.*reshape(model.Ai/sum(model.Ai),1,1,[]);
masked=sum(dXdt(1:last,1:2,:).*weights,[1,3]);
unmasked=sum(dCdt(1:last,:,:).*weights,[1,3]);
fwrite(ace_budget_stage_fid,[ace_budget_step,ace_budget_stage,vertical,lateral,mix,masked,unmasked],'double');
end
"""

FORTRAN_HELPERS = """
subroutine ace_budget_event(ncols,nz,n_prog,X,Ref,A,code)
integer,intent(in)::ncols,nz,n_prog,code
real,intent(in)::X(ncols+1,nz,n_prog),Ref(nz,8),A(ncols)
real::inventory(2),ke,weight,edge_weight
integer::i,k,n
if (code==1) then
  if (ace_budget_event_unit==0) then
    open(newunit=ace_budget_event_unit,file='events.bin',access='stream',form='unformatted',status='new')
    open(newunit=ace_budget_stage_unit,file='stages.bin',access='stream',form='unformatted',status='new')
  endif
  ace_budget_step=ace_budget_step+1
endif
inventory=0.;ke=0.
do i=1,ncols
  do k=1,nz-1
    weight=A(i)/sum(A)*Ref(k,1)*Ref(k,5)
    do n=2,3
      inventory(n-1)=inventory(n-1)+(X(i,k,n)-X(ncols+1,k,n))*weight
    enddo
  enddo
  do k=1,nz
    edge_weight=Ref(1,5)
    if (k==1 .or. k==nz) edge_weight=edge_weight/2.
    ke=ke+0.5*X(i,k,1)**2/Ref(k,2)*edge_weight*A(i)/sum(A)
  enddo
enddo
write(ace_budget_event_unit) real(ace_budget_step),real(code),inventory,ke,minval(X(1:ncols,:,3))
if (code==6) flush(ace_budget_event_unit)
end subroutine

subroutine ace_budget_stage_record(ncols,nz,n_prog,X,Ref,A,eps_tur,ioflow,rho0wC,dXdt,rkstage)
integer,intent(in)::ncols,nz,n_prog,rkstage
real,intent(in)::X(ncols+1,nz,n_prog),Ref(nz,8),A(ncols),eps_tur(ncols,nz,2),ioflow(ncols,nz)
real,intent(in)::rho0wC(ncols,nz,2:n_prog),dXdt(ncols,nz,n_prog)
real::vertical(2),lateral(2),mix(2),masked(2),upwind,weight
integer::i,k,n
do n=2,3
  vertical(n-1)=A(1)/sum(A)*(rho0wC(1,1,n)-rho0wC(1,nz-10,n))
  lateral(n-1)=0.;mix(n-1)=0.;masked(n-1)=0.
  do k=1,nz-11
    upwind=0.
    if (ioflow(1,k)>0.) upwind=X(2,k,n)
    if (ioflow(1,k)<0.) upwind=X(1,k,n)
    lateral(n-1)=lateral(n-1)+ioflow(1,k)*upwind*Ref(k,5)/sum(A)
    mix(n-1)=mix(n-1)-eps_tur(1,k,1)*(X(1,k,n)-X(2,k,n))*Ref(k,1)*Ref(k,5)*A(1)/sum(A)
    do i=1,ncols
      weight=A(i)/sum(A)*Ref(k,1)*Ref(k,5)
      masked(n-1)=masked(n-1)+dXdt(i,k,n)*weight
    enddo
  enddo
enddo
write(ace_budget_stage_unit) real(ace_budget_step),real(rkstage),vertical,lateral,mix,masked,ace_budget_unmasked
if (rkstage==9) flush(ace_budget_stage_unit)
end subroutine
"""


def write(path, data):
    temp=path.with_suffix('.tmp')
    temp.write_text(json.dumps(data,indent=2)+'\n')
    temp.replace(path)


def prepare(work):
    case=json.loads((REFERENCE/'single_case.json').read_text())
    cfg=json.loads((REFERENCE/'timing_configuration.json').read_text())
    report=json.loads((REFERENCE/'full_results.json').read_text())
    sources=[MATLAB_REFERENCE/'single_main.m',MATLAB_REFERENCE/'single_driver.F',
             REFERENCE/'ace_module_single.F',ROOT/'matlab/util_timeint/ssprk93.m']
    if case['physics']!='none' or case['dt_seconds']!=4 or not case['mean_mf_zero']:
        raise ValueError('Expected preserved 4 s, physics-off, mean-MF-zero case')
    pinned={**cfg['sha256'],str(Path(case['input'])):case['input_sha256']}
    for p in sources[:3]:
        if digest(p)!=pinned[str(p)]:raise ValueError(f'Preserved source changed: {p}')
    for name in ('full_matlab_states.bin','full_fortran_states.bin','full_matlab.nc'):
        p=REFERENCE/name
        if digest(p)!=report['artifacts_sha256'][name]:raise ValueError(f'Reference changed: {p}')
        pinned[str(p)]=report['artifacts_sha256'][name]
    if digest(case['input'])!=case['input_sha256']:raise ValueError('Input changed')
    work.mkdir(parents=True,exist_ok=False)
    source=sources[0].read_text()
    source=replace_once(source,'addpath(dir_util_weno,dir_util_plume,dir_util_timeint,dir_util_thermodynamics)',
                        f"addpath(dir_util_weno,dir_util_plume,dir_util_timeint,dir_util_thermodynamics)\naddpath('{work}');")
    source=replace_once(source,'timeint(@ssprk93,','timeint(@ssprk93_stage_budget,')
    source=source.replace(str(MATLAB_REFERENCE),str(work))
    source=replace_once(source,'  yn = X0;',"""  yn = X0;
  global ace_budget_step ace_budget_stage ace_budget_event_fid ace_budget_stage_fid
  ace_budget_step=0; ace_budget_stage=0;
  ace_budget_event_fid=fopen(fullfile(getenv('ACE_BUDGET_OUTPUT'),'matlab_events.bin'),'w');
  ace_budget_stage_fid=fopen(fullfile(getenv('ACE_BUDGET_OUTPUT'),'matlab_stages.bin'),'w');
  assert(ace_budget_event_fid>0 && ace_budget_stage_fid>0);
""")
    source=replace_once(source,'      % Implicit Newtonian damping',
                        '      ace_budget_event(5,yn,model);\n      % Implicit Newtonian damping')
    source=replace_once(source,'      % Implicitly solving massflux diffusion',
                        '      ace_budget_event(6,yn,model);\n      % Implicitly solving massflux diffusion')
    source=replace_once(source,'end%idt\nend','end%idt\n  fclose(ace_budget_event_fid); fclose(ace_budget_stage_fid);\nend')
    source=replace_once(source,'    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end',
                        '    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end\n  ace_budget_stage_record(X,dXdt,dCdt,ioflow,rho0wC,model);')
    (work/'single_main.m').write_text(source)
    rk=sources[3].read_text().replace('function yn = ssprk93(', 'function yn = ssprk93_stage_budget(',1)
    rk=replace_once(rk,'  K1 = expFun(yn,dTH,dQt,rho0B,ace);',
                    '  ace_budget_event(1,yn,ace);\n  K1 = expFun(yn,dTH,dQt,rho0B,ace);')
    rk=replace_once(rk,'  yn(:,2,:) = yn(:,2,:).*( yn(:,2,:)>0 ); % Non-negative qt',
                    '  ace_budget_event(2,yn,ace);\n  yn(:,2,:) = yn(:,2,:).*( yn(:,2,:)>0 ); % Non-negative qt\n  ace_budget_event(3,yn,ace);')
    rk=rk.rstrip()[:-3]+'  ace_budget_event(4,yn,ace);\nend\n'
    (work/'ssprk93_stage_budget.m').write_text(rk)
    (work/'ace_budget_event.m').write_text(MATLAB_EVENT)
    (work/'ace_budget_stage_record.m').write_text(MATLAB_STAGE)
    module=sources[2].read_text()
    module=replace_once(module,'\ncontains\n\nsubroutine ace_driver', '\ninteger,save::ace_budget_step=0,ace_budget_event_unit=0,ace_budget_stage_unit=0\nreal,save::ace_budget_unmasked(2)\n\ncontains\n\nsubroutine ace_driver')
    module=replace_once(module,'  ! update ace tendency',
                        '  call ace_budget_event(ncols,nz,n_prog,X,Ref,A,1)\n  ! update ace tendency')
    module=replace_once(module,'  ! Match S20\'s end-of-SSPRK area-mean MF removal before physics/damping.',
                        '  call ace_budget_event(ncols,nz,n_prog,X,Ref,A,2)\n  ! Match S20\'s end-of-SSPRK area-mean MF removal before physics/damping.')
    module=replace_once(module,'  ! call physics here',
                        '  call ace_budget_event(ncols,nz,n_prog,X,Ref,A,4)\n  ! call physics here')
    module=replace_once(module,'    X(1:ncols,:,3)=max(X(1:ncols,:,3),0.)',
                        '    X(1:ncols,:,3)=max(X(1:ncols,:,3),0.)\n    call ace_budget_event(ncols,nz,n_prog,X,Ref,A,3)')
    module=replace_once(module,'  ! NaN check', '  call ace_budget_event(ncols,nz,n_prog,X,Ref,A,5)\n  ! NaN check')
    module=replace_once(module,'  call ImDamp(ncols,nz,n_prog,X,Ref,dt)',
                        '  call ImDamp(ncols,nz,n_prog,X,Ref,dt)\n  call ace_budget_event(ncols,nz,n_prog,X,Ref,A,6)')
    module=replace_once(module,'! single ACE',"""! Observe pre-mask scalar rates over the same active vertical extent.
ace_budget_unmasked=0.
do n=2,3
  do k=1,nz-11
    do i=1,ncols
      ace_budget_unmasked(n-1)=ace_budget_unmasked(n-1)+dXdt(i,k,n)*A(i)/sum(A)*Ref(k,1)*Ref(k,5)
    enddo
  enddo
enddo
! single ACE""")
    module=replace_once(module,'dXdt(:,nz-10:nz,:)=0.',
                        'dXdt(:,nz-10:nz,:)=0.\ncall ace_budget_stage_record(ncols,nz,n_prog,X,Ref,A,eps_tur,ioflow,rho0wC,dXdt,rkstage)')
    module=replace_once(module,'end module',FORTRAN_HELPERS+'\nend module')
    (work/'ace_module_budget.F').write_text(module)
    shutil.copyfile(sources[1],work/'single_driver.F')
    for label,before,after in [('matlab',sources[0].read_text(),source),('rk',sources[3].read_text(),rk),('fortran',sources[2].read_text(),module)]:
        (work/(label+'.diff')).write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=label+'/reference',tofile=label+'/diagnostic')))
    build=work/'build';build.mkdir()
    objects=[]
    for name in ('ace_input','ace_interpolation','microphy_p3'):
        for suffix in ('.mod','.o'):
            p=REFERENCE/'build'/(name+suffix)
            if suffix=='.o' and digest(p)!=pinned[str(p)]:raise ValueError('Dependency changed')
            shutil.copyfile(p,build/p.name)
        objects.append(build/(name+'.o'))
    flags=cfg['production_flags']
    include=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    commands=[['gfortran',*flags,*include,'-c',str(work/'ace_module_budget.F'),'-o','ace_module.o'],
              ['gfortran',*flags,*include,'-c',str(work/'single_driver.F'),'-o','test.o'],
              ['gfortran',*flags,*map(str,objects),'ace_module.o','test.o',*libs,'-o','ace_model.exe']]
    for command in commands:
        with (build/'compile.log').open('a') as log:
            subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    for tag,steps in [('smoke','1'),('full','')]:
        out=work/tag;out.mkdir()
        (work/(tag+'_launch.m')).write_text(f"""setenv('ACE_INPUT_MODE','shared');setenv('ACE_VALIDATE_INPUT','');
setenv('ACE_INPUT_FILE','{case['input']}');setenv('ACE_PHYSICS','none');
setenv('ACE_STEPS','{steps}');setenv('ACE_SINGLE_TAG','{tag}');
setenv('ACE_BUDGET_OUTPUT','{out}');setenv('ACE_OUTPUT_FILE','{out}/matlab.nc');
run('{work}/single_main.m');
""")
    generated=list(work.glob('*.m'))+[work/'ace_module_budget.F',work/'single_driver.F']+list(build.glob('*.o'))+[build/'ace_model.exe']
    provenance={str(p):digest(p) for p in sources+generated}
    provenance.update({str(REFERENCE/name):report['artifacts_sha256'][name] for name in report['artifacts_sha256']})
    provenance[str(Path(case['input']))]=case['input_sha256']
    write(work/'configuration.json',{'case':case,'compiled_commands':commands,'threads':6,
          'sha256':provenance,'analysis_script_sha256':digest(Path(__file__)),
          'rk_weights':RK_WEIGHTS.tolist(),'event_codes':{'before':1,'raw_rk':2,'clip':3,'mean_projection':4,'physics':5,'damped':6},
          'limits':'Tracer stage accounting and vertical-KE operator increments; no total-energy acceptance.'})
    print(f'Prepared {work}',flush=True)


def load_budgets(work,tag,name):
    steps=1 if tag=='smoke' else 2700
    folder=work/tag
    events=np.fromfile(folder/(name+'_events.bin' if name=='matlab' else 'events.bin'),'<f8')
    stages=np.fromfile(folder/(name+'_stages.bin' if name=='matlab' else 'stages.bin'),'<f8')
    if events.size!=steps*6*6 or stages.size!=steps*9*12:raise ValueError('Incomplete budget streams')
    events=events.reshape(steps,6,6);stages=stages.reshape(steps,9,12)
    if not np.isfinite(events).all() or not np.isfinite(stages).all():raise ValueError('Nonfinite budget')
    if not np.array_equal(events[:,:,0],np.broadcast_to(np.arange(1,steps+1)[:,None],(steps,6))):raise ValueError('Event step IDs')
    codes=[1,2,3,4,5,6] if name=='matlab' else [1,2,4,3,5,6]
    if not np.array_equal(events[:,:,1],np.broadcast_to(codes,(steps,6))):raise ValueError('Event codes')
    if not np.array_equal(stages[:,:,0],np.broadcast_to(np.arange(1,steps+1)[:,None],(steps,9))):raise ValueError('Stage step IDs')
    if not np.array_equal(stages[:,:,1],np.broadcast_to(np.arange(1,10),(steps,9))):raise ValueError('Stage numbers')
    aligned=np.stack([events[:,codes.index(code),2:5] for code in range(1,7)],axis=1)
    rates=stages[:,:,2:].reshape(steps,9,5,2)
    observed=aligned[:,1,:2]-aligned[:,0,:2]
    integrated=np.sum(rates[:,:,:3,:]*RK_WEIGHTS[None,:,None,None],axis=1)*4
    residual=observed-integrated.sum(axis=1)
    increments=np.diff(events[:,:,2:5],axis=1)
    net=events[-1,-1,2:5]-events[0,0,2:5]
    accounting=net-increments.sum(axis=(0,1))
    continuity=events[1:,0,2:5]-events[:-1,-1,2:5]
    rate_residual=rates[:,:,3,:]-rates[:,:,:3,:].sum(axis=2)
    result={'steps':steps,'stage_evaluations':steps*9,'net_inventory_theta_e_water_vertical_KE':net.tolist(),
            'stage_integrals_vertical_lateral_mixing':integrated.sum(axis=0).tolist(),
            'max_abs_stage_rate_residual':np.max(np.abs(rate_residual),axis=(0,1)).tolist(),
            'max_abs_step_transport_residual':np.max(np.abs(residual),axis=0).tolist(),
            'cumulative_transport_residual':residual.sum(axis=0).tolist(),
            'accounting_residual_theta_e_water_vertical_KE':accounting.tolist(),
            'max_abs_step_continuity_error':np.max(np.abs(continuity),axis=0).tolist() if steps>1 else [0,0,0],
            'max_abs_unmasked_scalar_rate':np.max(np.abs(rates[:,:,4,:]),axis=(0,1)).tolist(),
            'min_preclip_qt':float(events[:,codes.index(2),5].min()),
            'min_postclip_qt':float(events[:,codes.index(3),5].min()),
            'operator_increments_in_actual_order':{f'{codes[i]}_to_{codes[i+1]}':increments[:,i].sum(axis=0).tolist() for i in range(5)}}
    if np.any(np.max(np.abs(rate_residual),axis=(0,1))>[1e-9,1e-12]):raise ValueError('Flux/tendency decomposition failed')
    if np.any(np.max(np.abs(residual),axis=0)>[1e-8,1e-11]):raise ValueError('SSPRK transport budget failed')
    if np.any(np.abs(accounting)>[1e-8,1e-11,1e-8]):raise ValueError('Split accounting failed')
    if np.any(continuity!=0):raise ValueError('State continuity failed')
    if result['min_postclip_qt']<0:raise ValueError('Negative postclip qt')
    return result,aligned,stages


def analyze(work,tag):
    cfg=json.loads((work/'configuration.json').read_text())
    results={};arrays={};hashes={}
    count=2 if tag=='smoke' else 181
    size,fsize=101*401*3,102*401*3
    for name in ('matlab','fortran'):
        p=work/(tag+'_matlab_states.bin') if name=='matlab' else work/tag/'fortran_states.bin'
        ref=MATLAB_REFERENCE/'smoke_matlab_states.bin' if tag=='smoke' and name=='matlab' else REFERENCE/'production_gate.bin' if tag=='smoke' else REFERENCE/('full_'+name+'_states.bin')
        expected=count*size*8 if name=='matlab' else 12+(count*fsize+401)*8
        if p.stat().st_size!=expected:raise ValueError(f'Incomplete {name} states')
        with p.open('rb') as a,ref.open('rb') as b:
            while chunk:=a.read(1024*1024):
                if chunk!=b.read(len(chunk)):raise ValueError(f'{name}: diagnostic changed saved trajectory')
        hashes[str(p)]=digest(p)
        results[name],aligned,stages=load_budgets(work,tag,name)
        arrays[name]=(aligned,stages)
    differences={'aligned_inventory_max_abs':np.max(np.abs(arrays['matlab'][0]-arrays['fortran'][0]),axis=(0,1)).tolist(),
                 'stage_rate_max_abs':np.max(np.abs(arrays['matlab'][1][:,:,2:]-arrays['fortran'][1][:,:,2:]),axis=(0,1)).tolist()}
    for name in ('events.bin','stages.bin','matlab_events.bin','matlab_stages.bin'):
        p=work/tag/name;hashes[str(p)]=digest(p)
    for p,sha in cfg['sha256'].items():
        if digest(p)!=sha:raise ValueError(f'Provenance changed: {p}')
    report={'case':cfg['case'],'tag':tag,'exact_saved_state_identity_matlab_fortran':[True,True],
            'results':results,'cross_language':differences,'artifacts_sha256':hashes,
            'configuration_sha256':digest(work/'configuration.json'),'analysis_script_sha256':digest(Path(__file__)),
            'limits':cfg['limits'],'units':['K kg m-2','kg m-2','J m-2'],
            'field_order':['theta_e_inventory_anomaly','water_inventory_anomaly','vertical_kinetic_energy']}
    write(work/(tag+'_budget_results.json'),report)
    print(json.dumps({'tag':tag,'results':results,'cross_language':differences},indent=2),flush=True)
    return report


def run(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for p,sha in cfg['sha256'].items():
        if digest(p)!=sha:raise ValueError(f'Changed provenance: {p}')
    env=os.environ.copy()
    env.update(OMP_NUM_THREADS='6',OMP_THREAD_LIMIT='6',OMP_DYNAMIC='FALSE',
               OMP_PROC_BIND='close',OMP_PLACES='cores')
    env.setdefault('MATLAB_PREFDIR','/tmp/ace-khn26-stage-budget-prefs')
    Path(env['MATLAB_PREFDIR']).mkdir(exist_ok=True)
    for tag in ('smoke','full'):
        children=[]
        for name in ('matlab','fortran'):
            out=work/tag
            done=out/(name+'_exit.json')
            if done.exists() and json.loads(done.read_text())['exit_code']==0:continue
            if name=='matlab':
                # These names isolate MATLAB records from the Fortran streams.
                command=['matlab','-batch',f"run('{work}/{tag}_launch.m')"]
            else:
                command=[str(work/'build/ace_model.exe'),'--input',cfg['case']['input'],
                         '--physics','none','--dt','4','--state-output',str(out/'fortran_states.bin')]
                command+=['--steps','1'] if tag=='smoke' else ['--intervals','180','--output',str(out/'fortran.dat')]
            attempts=len(list(out.glob(name+'_attempt*.log')))
            if attempts and (out/('matlab_events.bin' if name=='matlab' else 'events.bin')).exists():
                raise ValueError('Incomplete numerical run exists; preserve it and use a fresh workspace')
            log=(out/f'{name}_attempt{attempts+1}.log').open('x')
            process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL)
            children.append((name,process,log,command,done))
        try:
            while any(p.poll() is None for _,p,_,_,_ in children):
                state={'state':tag+'_running','supervisor_pid':os.getpid(),
                       'driver_pids':{name:p.pid for name,p,_,_,_ in children},
                       'exit_codes':{name:p.poll() for name,p,_,_,_ in children},
                       'budget_bytes':{p.name:p.stat().st_size for p in (work/tag).glob('*events.bin')}}
                write(work/'status.json',state)
                print(json.dumps(state),flush=True)
                time.sleep(30)
            for name,p,log,command,done in children:
                log.close();write(done,{'exit_code':p.returncode,'command':command})
            if any(p.returncode!=0 for _,p,_,_,_ in children):raise RuntimeError(f'{tag} driver failed; see preserved logs')
        except BaseException:
            for _,p,log,_,_ in children:
                if p.poll() is None:p.terminate()
            for _,p,log,_,_ in children:
                try:p.wait(timeout=10)
                except subprocess.TimeoutExpired:p.kill();p.wait()
                log.close()
            write(work/'status.json',{'state':'failed','tag':tag})
            raise
        analyze(work,tag)
        write(work/'status.json',{'state':tag+'_passed','supervisor_pid':os.getpid()})
    write(work/'status.json',{'state':'completed_pending_scientific_review'})


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--prepare',action='store_true')
    action.add_argument('--run',action='store_true')
    action.add_argument('--analyze',choices=['smoke','full'])
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work)
    if args.run:run(work)
    if args.analyze:analyze(work,args.analyze)
