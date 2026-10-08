#!/usr/bin/env python3
"""Replay saved multiACE states through unchanged dynamics/physics in isolated probes."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
from netCDF4 import Dataset

from run import ROOT, digest
from trajectory import replace_once
from unrestricted_single import THREAD_ENV

FIELDS = ['theta_e_vertical_flux', 'qt_vertical_flux', 'mfc', 'wc',
          'area_dMF_dz', 'horizontal_flow', 'local_MF_forcing', 'raw_buoyancy',
          'adjusted_buoyancy', 'MF_tendency', 'theta_e_tendency', 'qt_tendency',
          'SSPRK_MF', 'SSPRK_theta_e', 'SSPRK_qt',
          'physics_MF', 'physics_theta_e', 'physics_qt',
          'damped_MF', 'damped_theta_e', 'damped_qt']
MINUTES = [90, 120, 155, 158, 180]


def frame(source, name, minute):
    width = 101 if name == 'matlab' else 102
    size = width * 401 * 3 * 8
    offset = minute * size + (0 if name == 'matlab' else 12 + (401 * 8 if minute else 0))
    with (source / 'full' / (name + '_states.bin')).open('rb') as stream:
        stream.seek(offset)
        raw = stream.read(size)
    if len(raw) != size:
        raise ValueError('Incomplete saved state')
    return np.frombuffer(raw, '<f8').reshape((width, 401, 3), order='F')[:101].copy()


def prepare(work, source):
    work.mkdir(exist_ok=False, parents=True)
    cfg = json.loads((source / 'configuration.json').read_text())
    gate = Path(cfg['gate_work'])
    labels = [{'minute': minute, 'seed': name} for minute in MINUTES for name in ('matlab', 'fortran')]
    with (work / 'inputs.bin').open('wb') as stream:
        for label in labels:
            stream.write(frame(source, label['seed'], label['minute']).tobytes(order='F'))
    original = (ROOT / 'matlab/ace.m').read_text()
    prefix = original.split('%% Time-integration')[0]
    prefix = replace_once(prefix, "dir_ace = fileparts(mfilename('fullpath'));", f"dir_ace = '{ROOT}/matlab';")
    prefix = replace_once(prefix, 'dt = 6;', 'dt = 4;')
    local = original[original.index('function dXdt = expFun'):]
    local = replace_once(local, '  dXdt = [ dCdt+', """  global replay_capture
  if replay_capture
    replay_field(rho0wC(:,1,:));replay_field(rho0wC(:,2,:));
    replay_field(mfc);replay_field(wc);replay_field([Admfdz;zeros(1,model.Ni)]);
    replay_field(ioflow); % helper pads the unused top cell
    replay_field(F);replay_field(rho0B);
  end
  dXdt = [ dCdt+""")
    local = replace_once(local, '  if coarse_z==1', """  global replay_capture
  if replay_capture, replay_field(rho0B); end
  if coarse_z==1""")
    local = replace_once(local, '    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end',
                         '    dXdt(:,:,2:end) = 0; % Shut down additional ACEs\n  end\n  if replay_capture, replay_state(dXdt); end')
    main = f"""function replay_probe()
setenv('ACE_INPUT_MODE','shared');setenv('ACE_INPUT_FILE','{cfg['case']['input']}');
setenv('ACE_VALIDATE_INPUT','');setenv('ACE_PHYSICS','native');
{prefix}
global replay_capture replay_unit
replay_capture=false;
f=fopen('{work}/reference_tv.bin','w');fwrite(f,model.Tv_zc,'double');fclose(f);
f=fopen('{work}/inputs.bin','r');replay_unit=fopen('{work}/matlab_outputs.bin','w');
for sample=1:{len(labels)}
  raw=fread(f,[101*401*3,1],'double');assert(numel(raw)==101*401*3);
  raw=reshape(raw,[101,401,3]);
  state=cat(2,permute(raw(:,:,[2,3,1]),[2,3,1]),zeros(401,2,101));
  [dTH,dQt,rho0B]=microrad(state(:,1:2,:),model.p_zc,model.rho_zc,model.Tv_zc,model.theta_e_diag,model);
  dTH(:)=0;dQt(:)=0;
  replay_capture=true;expFun(state,dTH,dQt,rho0B,model);replay_capture=false;
  state=ssprk93(@expFun,state,dTH,dQt,rho0B,4,model.Wbar_eq_zero,model.Ai,model);
  replay_state(state);
  [dTH,dQt]=microrad(state(:,1:2,:),model.p_zc,model.rho_zc,model.Tv_zc,model.theta_e_diag,model);
  state(:,1:2,:)=state(:,1:2,:)+permute(cat(3,dTH,dQt),[1,3,2])*4;
  replay_state(state);
  state=ImDamp(state,model.theta_e_zc,model.qt_zc,model.Nzm,model.damp);
  replay_state(state);
  fprintf('REPLAY_SAMPLE %d\\n',sample);
end
fclose(f);fclose(replay_unit);
end
function replay_field(v)
global replay_unit
v=squeeze(v);if size(v,1)==400,v=[v;zeros(1,101)];end
assert(isequal(size(v),[401,101]));fwrite(replay_unit,v','double');
end
function replay_state(v)
for k=[3,1,2],replay_field(v(:,k,:));end
end
"""
    (work / 'replay_probe.m').write_text(main + local)
    original_f = (ROOT / 'fortran/src/ace_module.F').read_text()
    module = replace_once(original_f, 'public :: weno,', 'public :: ace_tendency,replay_capture,replay_unit\npublic :: weno,')
    module = replace_once(module, '\ncontains\n\nsubroutine ace_driver',
                          '\nlogical :: replay_capture=.false.\ninteger :: replay_unit\ncontains\n\nsubroutine ace_driver')
    module = replace_once(module, '! MATLAB S20 removes the area-weighted mean buoyancy', """if (replay_capture) then
  write(replay_unit) rho0wC(:,:,2),rho0wC(:,:,3),mfc(1:ncols,:),Wc(1:ncols,:),Admfdz,ioflow,F,rho0B
endif
! MATLAB S20 removes the area-weighted mean buoyancy""")
    module = replace_once(module, 'do i=1,ncols\n  F(i,:)=F(i,:)+rho0B(i,:)',
                          'if (replay_capture) write(replay_unit) rho0B\ndo i=1,ncols\n  F(i,:)=F(i,:)+rho0B(i,:)')
    module = replace_once(module, 'end subroutine ace_tendency',
                          'if (replay_capture) write(replay_unit) dXdt\nend subroutine ace_tendency')
    module = replace_once(module, '  ! call physics here', '  write(replay_unit) X(1:ncols,:,:)\n  ! call physics here')
    module = replace_once(module, '  ! implicit damping', '  write(replay_unit) X(1:ncols,:,:)\n  ! implicit damping')
    module = replace_once(module, '  t = t + dt', '  write(replay_unit) X(1:ncols,:,:)\n  t = t + dt')
    (work / 'ace_module_replay.F').write_text(module)
    program = f"""program replay
use ace_module
use ace_input
implicit none
integer,parameter::nc=101,nz=401,nb=200
integer::k,u,sample
real::profile(nz,12),widths(7),cz(nb),ce(nb+1),area(nc),perimeter(nc),reference(nz),ref(nz,8)
real::x(nc+1,nz,3),tendency(nc,nz,3),forcing(nc,nz),lx,ly,dz,now
character(*),parameter::input_file='{cfg['case']['input']}'
call read_case_profile(input_file,profile,widths,lx,ly,dz,cz,ce)
call read_case_geometry(input_file,area,perimeter)
do k=1,nz
  ref(k,:)=[profile(k,11),profile(k,5),profile(k,12),profile(k,6),dz,dz,profile(k,10), &
    (profile(k,10)/1.e5)**(287.04/1005.7)]
enddo
open(newunit=u,file='{work}/reference_tv.bin',access='stream',form='unformatted',status='old')
read(u)reference;close(u)
call ace_initialization(nc,nz,nb,cz,ce,input_file,reference,netcdf_input=.true.)
open(newunit=u,file='{work}/inputs.bin',access='stream',form='unformatted',status='old')
open(newunit=replay_unit,file='{work}/fortran_outputs.bin',access='stream',form='unformatted',status='new')
forcing=0.
do sample=1,{len(labels)}
  x=0.;x(nc+1,:,2)=profile(:,7);x(nc+1,:,3)=profile(:,8)
  read(u)x(1:nc,:,:)
  replay_capture=.true.
  call ace_tendency(nc,nz,2,3,4.,area,perimeter,x,ref,tendency,1)
  replay_capture=.false.;now=0.
  call ace_driver(nc,nz,2,3,x,ref,area,perimeter,now,4.,4.,forcing,precipitation_input=.true.)
  write(*,*) 'REPLAY_SAMPLE',sample
enddo
close(u);close(replay_unit)
end program
"""
    (work / 'probe.F').write_text(program)
    build = work / 'build'; build.mkdir()
    flags = ['-cpp','-ffree-form','-ffree-line-length-none','-O2','-fdefault-real-8','-fdefault-double-8','-fopenmp']
    inc = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    objects = [gate/'build'/name for name in ('ace_input.o','ace_interpolation.o','microphy_p3.o')]
    commands=[]
    for name in ['ace_module_replay','probe']:
        command=['gfortran',*flags,*inc,'-I'+str(gate/'build'),'-c',str(work/(name+'.F')),'-o',str(build/(name+'.o'))]
        commands.append(command)
        with (build/(name+'.log')).open('w') as log:
            subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    command=['gfortran',*flags,*map(str,objects),str(build/'ace_module_replay.o'),str(build/'probe.o'),*libs,'-o',str(build/'probe.exe')]
    commands.append(command);subprocess.run(command,cwd=build,check=True)
    paths=[Path(__file__),ROOT/'matlab/ace.m',ROOT/'fortran/src/ace_module.F',work/'inputs.bin',work/'replay_probe.m',work/'ace_module_replay.F',work/'probe.F',*objects]
    (work/'configuration.json').write_text(json.dumps({'source':str(source),'labels':labels,'fields':FIELDS,'commands':commands,'sha256':{str(p.resolve()):digest(p) for p in paths},'scope':'Single-step saved-state replays, dt=4 s. Common MATLAB reference Tv removes reference-inversion differences; no production edits or long integration.'},indent=2)+'\n')


def analyze(work):
    cfg=json.loads((work/'configuration.json').read_text()); n=len(cfg['labels'])
    values={name:np.fromfile(work/(name+'_outputs.bin'),'<f8').reshape((n,len(FIELDS),401,101)).transpose(0,3,2,1) for name in ('matlab','fortran')}
    # MATLAB's slab areas are in km^2, Fortran's are in m^2. These two
    # diagnostic fluxes carry area units; compare them in SI, without
    # changing either calculation or its saved raw output.
    values['matlab'][:,:,:,4:6] *= 1e6
    if not all(np.isfinite(v).all() for v in values.values()):raise ValueError('Nonfinite replay output')
    results=[]
    for i,label in enumerate(cfg['labels']):
        a,b=values['matlab'][i],values['fortran'][i]; d=np.abs(b-a)
        fields=[]
        for j,name in enumerate(FIELDS):
            ace,k=np.unravel_index(np.argmax(d[:,:,j]),(101,401))
            fields.append({'field':name,'max_abs_error':float(d[ace,k,j]),'ACE':int(ace+1),'level':int(k+1),'boundary_max_abs_error':float(d[97:,:,j].max())})
        results.append({**label,'components':fields})
    decomposition=[]
    for i in range(0,n,2):
        m=values['matlab'][i]; f=values['fortran'][i]; ff=values['fortran'][i+1]
        items={}
        for section,start in [('SSPRK',12),('physics',15),('damped',18)]:
            items[section]={'same_seed_implementation_difference':np.max(np.abs(f[:,:,start:start+3]-m[:,:,start:start+3]),axis=(0,1)).tolist(),'different_seed_same_fortran_difference':np.max(np.abs(ff[:,:,start:start+3]-f[:,:,start:start+3]),axis=(0,1)).tolist(),'independent_seed_output_difference':np.max(np.abs(ff[:,:,start:start+3]-m[:,:,start:start+3]),axis=(0,1)).tolist()}
        decomposition.append({'minute':cfg['labels'][i]['minute'],'field_order':['MF','theta_e','qt'],'steps':items})
    report={'samples':n,'results':results,'input_difference_decomposition':decomposition,'scope':cfg['scope'],'analysis_source_sha256':digest(Path(__file__)),'diagnostic_unit_conversion':'MATLAB area_dMF_dz and horizontal_flow multiplied by 1e6 to convert area from km^2 to m^2. Raw output bytes are preserved.','artifacts_sha256':{name:digest(work/name) for name in ('inputs.bin','reference_tv.bin','matlab_outputs.bin','fortran_outputs.bin')}}
    (work/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


def run(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for p,expected in cfg['sha256'].items():
        if digest(Path(p))!=expected:raise ValueError('Changed replay source/input: '+p)
    env=os.environ.copy()
    for key in THREAD_ENV:env.pop(key,None)
    env['MATLAB_PREFDIR']=str(work/'matlab_prefs')
    for name,command in [('matlab',['matlab','-batch',f"addpath('{work}');replay_probe"]),('fortran',[str(work/'build/probe.exe')])]:
        if name=='fortran':env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE')
        (work/'status.json').write_text(json.dumps({'state':name+'_running','supervisor_pid':os.getpid()})+'\n')
        with (work/(name+'.log')).open('w') as log:
            subprocess.run(command,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    analyze(work)
    (work/'status.json').write_text(json.dumps({'state':'completed','samples':len(cfg['labels'])})+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    parser.add_argument('--source',type=Path,default=ROOT/'migration_work/khn26_multi_matlab_default_fortran32_12h')
    parser.add_argument('--prepare',action='store_true');parser.add_argument('--run',action='store_true');parser.add_argument('--analyze',action='store_true')
    args=parser.parse_args();work=args.work.resolve()
    if args.prepare:prepare(work,args.source.resolve())
    if args.run:run(work)
    if args.analyze:analyze(work)
