#!/usr/bin/env python3
"""Compare unchanged native thermodynamics/sinks on byte-identical saved states."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
from netCDF4 import Dataset

import multi
from run import ROOT, digest
from trajectory import replace_once

FIELDS=['T','q','ql','qi','theta_e_base','theta_e_perturbed',
        'theta_e_condensate_derivative','theta_e_sink','qt_sink']


def prepare(work,source,sample_data=None,provenance=()):
    work.mkdir(parents=True,exist_ok=False)
    cfg=json.loads((source/'configuration.json').read_text())
    records=[0,45,48,53,88,150]  # 0, 180, 192, 212, 352, 600 seconds.
    aces=np.array([0,1,50,100])
    with Dataset(cfg['case']['input']) as ds:p=np.asarray(ds['p_zc'][:])
    samples=[];labels=[]
    if sample_data is None:
        for language in ('matlab','fortran'):
            for record,state in enumerate(multi.state_frames(source,'gate_native',language,151)):
                if record not in records:continue
                for ace in aces:
                    samples.extend(np.column_stack([state[ace,:,1],state[ace,:,2],p]))
                    labels.extend([[language,record*4,int(ace+1),level+1] for level in range(multi.Z)])
    else:
        samples,labels=sample_data
    samples=np.asarray(samples,dtype='<f8');samples.ravel(order='F').tofile(work/'inputs.bin')
    multi.write(work/'sample_labels.json',labels)
    n=len(samples)
    # Copy the exact production local functions; external thermodynamic helpers
    # continue to come from the hashed production directory.
    original=(ROOT/'matlab/ace.m').read_text()
    local=original[original.index('function [dtheta_e, dqt] = PRECIP_SINKS'):original.index('function X = ImDamp')]
    matlab=f"""function common_probe()
maxNumCompThreads(32);assert(maxNumCompThreads==32);
fprintf('COMMON_MATLAB_CAP %d\\n',maxNumCompThreads);
addpath('{ROOT}/matlab/util_thermodynamics');
fid=fopen('{work}/inputs.bin','r');s=fread(fid,[{n},3],'double');fclose(fid);
assert(isequal(size(s),[{n},3]));
fid=fopen('{work}/matlab_inputs_echo.bin','w');fwrite(fid,s,'double');fclose(fid);
[T,q,ql,qi]=INV_THETA_E(s(:,1),s(:,2),s(:,3),true);
[sinkth,sinkqt]=PRECIP_SINKS(T,q,ql,qi,s(:,3),0.5e-3,20,300);
base=eval_theta_e(T,q,ql,qi,s(:,3));qc=ql+qi;
dql=1e-8*ql./qc;dqi=1e-8*qi./qc;
pert=eval_theta_e(T,q,ql+dql,qi+dqi,s(:,3));
deriv=(pert-base)/1e-8;deriv(qc<=0)=0;pert(qc<=0)=base(qc<=0);
out=[T,q,ql,qi,base,pert,deriv,sinkth,sinkqt];assert(all(isfinite(out(:))));
fid=fopen('{work}/matlab_outputs.bin','w');fwrite(fid,out,'double');fclose(fid);
fid=fopen('{work}/common_thermo.bin','w');fwrite(fid,out(:,1:4),'double');fclose(fid);
assert(maxNumCompThreads==32);fprintf('COMMON_MATLAB_CAP_FINAL %d\\n',maxNumCompThreads);
end
"""+local
    (work/'common_probe.m').write_text(matlab)
    original_f=(ROOT/'fortran/src/ace_module.F').read_text()
    module=replace_once(original_f,'public :: weno,','public :: common_probe_native\npublic :: weno,')
    wrapper="""
subroutine common_probe_native(n,s,common,out,common_out)
integer,intent(in)::n
real,intent(in)::s(n,3),common(n,4)
real,intent(out)::out(n,9),common_out(n,9)
real::sinks(1,n,2),qc,dql,dqi
integer::k,mode
allocate(Ta(1,n),q(1,n),ql(1,n),qi(1,n))
do mode=1,2
  do k=1,n
    if(mode==1) then
      call inv_theta_e(s(k,1),s(k,2),s(k,3),Ta(1,k),q(1,k),ql(1,k),qi(1,k))
    else
      Ta(1,k)=common(k,1);q(1,k)=common(k,2);ql(1,k)=common(k,3);qi(1,k)=common(k,4)
    endif
    out(k,1:4)=[Ta(1,k),q(1,k),ql(1,k),qi(1,k)]
    out(k,5)=theta_e(Ta(1,k),q(1,k),ql(1,k),qi(1,k),s(k,3))
    out(k,6)=out(k,5);out(k,7)=0.
    qc=ql(1,k)+qi(1,k)
    if(qc>0.) then
      dql=1.e-8*ql(1,k)/qc;dqi=1.e-8*qi(1,k)/qc
      out(k,6)=theta_e(Ta(1,k),q(1,k),ql(1,k)+dql,qi(1,k)+dqi,s(k,3))
      out(k,7)=(out(k,6)-out(k,5))/1.e-8
    endif
  enddo
  call precip_sinks(1,n,3,s(:,3),sinks)
  out(:,8)=sinks(1,:,1);out(:,9)=sinks(1,:,2)
  if(mode==1) common_out=out
enddo
! out now holds the fixed-MATLAB-thermodynamic-state calculation.
block
real::temporary(n,9)
temporary=out;out=common_out;common_out=temporary
end block
deallocate(Ta,q,ql,qi)
end subroutine
"""
    if "type :: ace_thermal_t" in original_f:
        from oop_regression import thermal_code
        wrapper = thermal_code(wrapper, "legacy_thermal%")
    module=replace_once(module,'end module ace_module',wrapper+'\nend module ace_module')
    (work/'ace_module_probe.F').write_text(module)
    (work/'probe.F').write_text(f"""program probe
use ace_module,only:common_probe_native
use omp_lib,only:omp_get_max_threads,omp_get_num_threads
implicit none
integer,parameter::n={n}
real::s(n,3),common(n,4),out(n,9),fixed(n,9)
integer::u
if(omp_get_max_threads()/=32) error stop 'Thread cap'
!$omp parallel
!$omp single
write(*,*) 'COMMON_OPENMP_TEAM',omp_get_num_threads()
if(omp_get_num_threads()/=32) error stop 'Thread team'
!$omp end single
!$omp end parallel
open(newunit=u,file='{work}/inputs.bin',access='stream',form='unformatted',status='old')
read(u)s;close(u)
open(newunit=u,file='{work}/fortran_inputs_echo.bin',access='stream',form='unformatted',status='new')
write(u)s;close(u)
open(newunit=u,file='{work}/common_thermo.bin',access='stream',form='unformatted',status='old')
read(u)common;close(u)
call common_probe_native(n,s,common,out,fixed)
open(newunit=u,file='{work}/fortran_outputs.bin',access='stream',form='unformatted',status='new')
write(u)out;close(u)
open(newunit=u,file='{work}/fortran_fixed_thermo.bin',access='stream',form='unformatted',status='new')
write(u)fixed;close(u)
end program
""")
    build=work/'build';build.mkdir()
    flags=cfg['production_flags'];inc=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    objects=[source/'build'/name for name in ('ace_input.o','ace_interpolation.o','microphy_p3.o')]
    commands=[]
    for name in ('ace_module_probe','probe'):
        command=['gfortran',*flags,*inc,'-I'+str(source/'build'),'-c',str(work/(name+'.F')),'-o',str(build/(name+'.o'))]
        commands.append(command)
        with (build/(name+'.compile.log')).open('w') as log:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    command=['gfortran',*flags,*map(str,objects),str(build/'ace_module_probe.o'),str(build/'probe.o'),*libs,'-o',str(build/'probe.exe')]
    commands.append(command);subprocess.run(command,cwd=build,check=True)
    paths=[Path(__file__).resolve(),ROOT/'fortran/src/ace_module.F',ROOT/'matlab/ace.m',
           work/'inputs.bin',work/'sample_labels.json',work/'common_probe.m',work/'ace_module_probe.F',work/'probe.F',build/'probe.exe',*objects]
    paths.extend(sorted((ROOT/'matlab/util_thermodynamics').glob('*.m')))
    if sample_data is None:
        paths.extend(source/'gate_native'/(name+'_states.bin') for name in ('matlab','fortran'))
    paths.extend(provenance)
    multi.write(work/'configuration.json',{'source_work':str(source),'samples':n,'cpu_sets':cfg['cpu_sets'],
         'fields':FIELDS,'compiled_commands':commands,'sha256':{str(p):digest(p) for p in paths},
         'scope':'Saved post-step states; independent inverse thermodynamics and common MATLAB T/q/ql/qi. No time integration or formula edits.'})
    shutil.copyfile(Path(__file__),work/'executed_runner.py')
    print(json.dumps({'prepared':str(work),'samples':n}))


def compare(work,cfg):
    n=cfg['samples'];labels=json.loads((work/'sample_labels.json').read_text())
    values={name:np.fromfile(work/(name+'.bin'),'<f8').reshape((n,9),order='F')
            for name in ('matlab_outputs','fortran_outputs','fortran_fixed_thermo')}
    if any(not np.isfinite(v).all() for v in values.values()):raise ValueError('Nonfinite output')
    expected=digest(work/'inputs.bin')
    if any(digest(work/(name+'_inputs_echo.bin'))!=expected for name in ('matlab','fortran')):raise ValueError('Common inputs differ')
    report={'samples':n,'field_order':FIELDS,'byte_identical_inputs':True,'finite_outputs':True,'comparisons':{}}
    m=values['matlab_outputs']
    for name in ('fortran_outputs','fortran_fixed_thermo'):
        f=values[name];d=np.abs(f-m);indices=d.argmax(axis=0)
        report['comparisons'][name]={'max_abs_error':d.max(axis=0).tolist(),
            'rms_error':np.sqrt(np.mean(d*d,axis=0)).tolist(),
            'worst_samples':[{'field':field,'sample':labels[int(i)],'matlab':float(m[i,j]),'fortran':float(f[i,j])}
                             for j,(field,i) in enumerate(zip(FIELDS,indices))]}
    report['artifacts_sha256']={p.name:digest(p) for p in work.glob('*.bin')}
    multi.write(work/'results.json',report)
    return report


def run(work):
    try:
        cfg=multi.verify(work)
        for name in ('matlab','fortran'):
            env=multi.environment(cfg,name)
            command=['taskset','-c',','.join(map(str,cfg['cpu_sets'][name]))]
            command+=['matlab','-batch',f"addpath('{work}');common_probe"] if name=='matlab' else [str(work/'build/probe.exe')]
            with (work/(name+'.log')).open('x') as log:
                p=subprocess.Popen(command,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True)
                multi.write(work/'status.json',{'state':name+'_running','supervisor_pid':os.getpid(),'driver_pid':p.pid})
                if p.wait():raise RuntimeError(name+' probe failed')
        m=(work/'matlab.log').read_text();f=(work/'fortran.log').read_text()
        if 'COMMON_MATLAB_CAP 32' not in m or 'COMMON_MATLAB_CAP_FINAL 32' not in m:raise ValueError('MATLAB cap evidence')
        if not multi.re.search(r'COMMON_OPENMP_TEAM\s+32',f):raise ValueError('Fortran team evidence')
        report=compare(work,cfg);multi.verify(work)
        multi.write(work/'status.json',{'state':'completed','samples':report['samples'],'byte_identical_inputs':True,'threads_per_language':32})
    except BaseException as exc:
        multi.write(work/'status.json',{'state':'failed','error':str(exc)});raise


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    parser.add_argument('--source',type=Path,default=ROOT/'migration_work/khn26_single32_native_3h')
    action=parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare','launch','run'):action.add_argument('--'+name,action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work,args.source.resolve())
    if args.run:run(work)
    if args.launch:
        multi.verify(work)
        with (work/'supervisor.log').open('x') as log:
            p=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--run'],cwd=ROOT,
               stdout=log,stderr=subprocess.STDOUT,stdin=subprocess.DEVNULL,start_new_session=True,close_fds=True)
        multi.write(work/'supervisor.json',{'pid':p.pid});print(json.dumps({'supervisor_pid':p.pid,'work':str(work)}))
