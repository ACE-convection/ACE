#!/usr/bin/env python3
"""Factorial temporary forward-theta_e probes: EPS spelling and evaluation staging.

Use identical MATLAB thermodynamic caches from the reviewed mixed-state replay.
Preserve production sources; do not change inverse or precipitation equations.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

import netCDF4
import numpy as np
from compare import metrics


FIELDS = ['EPS','qt','e','es','RE','R','CPL','chi','gamma','gammi','LV',
          'pressure_base','humidity_base','ice_base','exp_argument',
          'pressure_factor','humidity_factor','ice_factor','exp_factor',
          'product_pressure','product_humidity','product_ice','staged_result',
          'native_result','CPL_slope','Ci_T0']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--replay', type=Path, default=Path('migration_work/mixed_residual_review'))
    parser.add_argument('--matlab', default='matlab')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work=args.work.resolve(); replay=args.replay.resolve()
    if work.exists() and any(work.iterdir()):
        raise SystemExit('Use a fresh directory; existing evidence is preserved')
    retained=json.loads((replay/'results.json').read_text())
    production=retained['production_sources_sha256']
    for name,value in production.items():
        assert digest(root/name)==value, f'Stale replay production source: {name}'
    for name in ['matlab.bin','fortran.bin','matlab_thermo.bin']:
        assert digest(replay/name)==retained['artifact_sha256'][name], f'Stale replay artifact: {name}'
    work.mkdir(parents=True,exist_ok=True)
    m=np.fromfile(replay/'matlab.bin',dtype='<f8').reshape((8,801,24,60),order='F')
    f=np.fromfile(replay/'fortran.bin',dtype='<f8').reshape((8,801,24,60),order='F')
    cache=np.fromfile(replay/'matlab_thermo.bin',dtype='<f8').reshape((8,801,4,60),order='F')
    assert np.array_equal(cache,m[:,:,3:7,:])
    cloud=lambda a: a[0,90:110,:,:].transpose(2,0,1).reshape((1200,a.shape[2]))
    thermo=cloud(cache)
    input_file=root/'data/input/manus208.nc'
    assert digest(input_file)==retained['input_sha256']
    with netCDF4.Dataset(input_file) as ds:
        pressure=np.tile(np.asarray(ds['p_zc'][:])[90:110],60)
    inputs=np.column_stack([thermo,pressure])
    assert np.isfinite(inputs).all()
    inputs.flatten(order='F').astype('<f8').tofile(work/'input.bin')
    commands=[]

    def run(command,label,cwd=work):
        command=list(map(str,command))
        commands.append({'argv':command,'cwd':str(cwd)})
        with (cwd/(label+'.log')).open('w') as log:
            subprocess.run(command,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)

    run([sys.executable,root/'tests/alignment/prepare.py',work],'prepare')
    quote=lambda p:str(p).replace("'","''")
    statement=(f"addpath('{quote(root/'tests/alignment')}'); "
               f"matlab_forward_probe('{quote(root)}','{quote(work)}');")
    run([args.matlab,'-batch',statement],'matlab_probe')
    def read(path):
        a=np.fromfile(path,dtype='<f8').reshape((1200,54),order='F')
        assert np.isfinite(a).all(), str(path)
        return a
    matlab=read(work/'matlab.bin')
    exp_pairs=np.column_stack([np.concatenate([matlab[:,14],matlab[:,40]]),
                               np.concatenate([matlab[:,18],matlab[:,44]])])
    for argument in np.unique(exp_pairs[:,0]):
        assert np.unique(exp_pairs[exp_pairs[:,0]==argument,1]).size==1
    exp_pairs.flatten(order='F').astype('<f8').tofile(work/'matlab_exp.bin')
    original=(work/'ace_module.F').read_text()
    module=original.replace('! defien operator',
        'public :: forward_trace,set_forward_exp_override\nreal, save :: forward_trace(26)\n'
        'real, allocatable, save :: diagnostic_exp_pairs(:,:)\n\n! defien operator',1)
    module=module.replace('contains\n','''contains
subroutine set_forward_exp_override(file)
character(*), intent(in) :: file
integer :: u
allocate(diagnostic_exp_pairs(2400,2))
open(newunit=u,file=file,access='stream',form='unformatted',status='old')
read(u) diagnostic_exp_pairs
close(u)
end subroutine
function diagnostic_exp(argument) result(value)
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
real, intent(in) :: argument
real :: value
integer :: j
! Retain original behavior for the inactive qc=0 sink's pre-mask NaNs.
if (.not.ieee_is_finite(argument)) then
 value=exp(argument)
 return
endif
do j=1,size(diagnostic_exp_pairs,1)
 if (argument==diagnostic_exp_pairs(j,1)) then
  value=diagnostic_exp_pairs(j,2)
  return
 endif
enddo
error stop 'Forward exp argument absent from identical MATLAB probe'
end function
''',1)
    start=module.index('function theta_e(T,q,ql,qi,p)')
    end=module.index('end function theta_e',start)
    kernel=module[start:end]
    trace='''
forward_trace(1)=EPS
forward_trace(2)=qt
forward_trace(3)=e
forward_trace(4)=es
forward_trace(5)=Re
forward_trace(6)=R
forward_trace(7)=Cpl
forward_trace(8)=chi
forward_trace(9)=gamma
forward_trace(10)=gammi
forward_trace(11)=Lv(T)
forward_trace(12)=P0*R/p/Re
forward_trace(13)=es/e
forward_trace(14)=T0/T
forward_trace(15)=(q*Lv(T)/T-Lf*qi/T0)/Cpl
forward_trace(16)=forward_trace(12)**chi
forward_trace(17)=forward_trace(13)**gamma
forward_trace(18)=forward_trace(14)**gammi
forward_trace(19)=exp(forward_trace(15))
forward_trace(20)=T*forward_trace(16)
forward_trace(21)=forward_trace(20)*forward_trace(17)
forward_trace(22)=forward_trace(21)*forward_trace(18)
forward_trace(23)=forward_trace(22)*forward_trace(19)
forward_trace(25)=Cl-Cpd
forward_trace(26)=Ci(T0)
'''
    flags=['-O2','-ffree-form','-fdefault-real-8','-fdefault-double-8','-ffree-line-length-none']
    include=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    rpath='-Wl,-rpath,'+subprocess.check_output(['nf-config','--prefix'],text=True).strip()+'/lib'
    outputs={}
    variants=[('control',False,False,False),('eps_literal',True,False,False),
              ('staged',False,True,False),('eps_literal_staged',True,True,False),
              ('exp_override',False,False,True),('eps_literal_exp_override',True,False,True)]
    for name,literal,staged,override_exp in variants:
        directory=work/name; directory.mkdir()
        changed=kernel
        if literal:
            assert changed.count('EPS=Rd/Rv')==1
            changed=changed.replace('EPS=Rd/Rv','EPS=0.621971830985916')
        changed+=trace
        if staged:
            changed+='theta_e=forward_trace(23)\n'
        changed+='forward_trace(24)=theta_e\n\n'
        if override_exp:
            assert changed.count('exp(')==2
            changed=changed.replace('exp(','diagnostic_exp(')
        variant=module[:start]+changed+module[end:]
        # Restrict expression/constant substitutions to the forward function.
        assert variant[variant.index('subroutine inv_theta_e'):]==original[original.index('subroutine inv_theta_e'):]
        (directory/'ace_module.F').write_text(variant)
        (directory/'forward.patch').write_text(''.join(difflib.unified_diff(
            original.splitlines(True),variant.splitlines(True),fromfile='prepared/ace_module.F',tofile=name+'/ace_module.F')))
        for suffix in ['.mod','.o']:
            shutil.copyfile(work/('ace_input'+suffix),directory/('ace_input'+suffix))
        run(['gfortran',*flags,*include,'-c','ace_module.F'],'module_build',directory)
        run(['gfortran',*flags,*include,root/'tests/alignment/fortran_forward_probe.f90',
             'ace_module.o','ace_input.o',*libs,rpath,'-o','forward.exe'],'driver_build',directory)
        command=[directory/'forward.exe',work/'input.bin',directory/'output.bin']
        if override_exp:
            command.append(work/'matlab_exp.bin')
        run(command,'probe',directory)
        outputs[name]=read(directory/'output.bin')
    # Independent native evaluations must reproduce the reviewed shared-cache probes.
    expected_m=cloud(m)[:,[13,14,11,12]]
    expected_f=cloud(f)[:,[13,14,11,12]]
    positions=[23,49,52,53]
    assert np.array_equal(matlab[:,positions],expected_m), 'MATLAB native probe changed from retained replay'
    assert np.array_equal(outputs['control'][:,positions],expected_f), 'Instrumented control changed from retained replay'
    report={'parent_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'production_sources_sha256':production,'input_sha256':digest(input_file),
            'replay_result_sha256':digest(replay/'results.json'),'commands':commands,
            'fields':FIELDS,'input_count':1200,'input_selection':'ACE 1, levels 91-110; 30 states from each trajectory',
            'native_matlab_matches_retained_exactly':True,'native_control_matches_retained_exactly':True,
            'scope':'Standalone forward/sink probes; temporary EPS spelling, staged multiplication, exact-argument exp substitution; no integration',
            'tolerance_status':'No acceptance tolerance or denominator floor', 'variants':{}}
    for name,a in outputs.items():
        result={'base':metrics(matlab[:,23],a[:,23]),'perturbed':metrics(matlab[:,49],a[:,49]),
                'numerator':metrics(matlab[:,49]-matlab[:,23],a[:,49]-a[:,23]),
                'theta_e_sink':metrics(matlab[:,52],a[:,52]),'qt_sink':metrics(matlab[:,53],a[:,53]),
                'base_component_errors':{label:metrics(matlab[:,j],a[:,j]) for j,label in enumerate(FIELDS)},
                'perturbed_component_errors':{label:metrics(matlab[:,26+j],a[:,26+j]) for j,label in enumerate(FIELDS)},
                'native_vs_staged':metrics(a[:,[23,49]],a[:,[22,48]]),
                'target_116s_fortran_level110':{'matlab':matlab[-1].tolist(),'fortran':a[-1].tolist()},
                'target_numerator_difference_K':float((matlab[-1,49]-matlab[-1,23])-(a[-1,49]-a[-1,23])),
                'target_theta_e_sink_difference_K_per_s':float(matlab[-1,52]-a[-1,52])}
        for label,begin in [('matlab_trajectory',0),('fortran_trajectory',600)]:
            ix=slice(begin,begin+600)
            result[label]={'numerator':metrics(matlab[ix,49]-matlab[ix,23],a[ix,49]-a[ix,23]),
                           'theta_e_sink':metrics(matlab[ix,52],a[ix,52])}
        result['base_exact_count']=int(np.count_nonzero(matlab[:,23]==a[:,23]))
        result['perturbed_exact_count']=int(np.count_nonzero(matlab[:,49]==a[:,49]))
        result['numerator_exact_count']=int(np.count_nonzero((matlab[:,49]-matlab[:,23])==(a[:,49]-a[:,23])))
        result['theta_e_sink_exact_count']=int(np.count_nonzero(matlab[:,52]==a[:,52]))
        report['variants'][name]=result
    report['matlab_native_vs_staged']=metrics(matlab[:,[23,49]],matlab[:,[22,48]])
    report['variant_changes_from_control']={name:{
        'native_forward':metrics(outputs['control'][:,[23,49]],a[:,[23,49]]),
        'theta_e_sink':metrics(outputs['control'][:,52],a[:,52])}
        for name,a in outputs.items() if name!='control'}
    report['compiled_eps']={name:{'value':float(a[0,0]),'binary64_hex':float(a[0,0]).hex()} for name,a in outputs.items()}
    report['matlab_eps']={'value':float(matlab[0,0]),'binary64_hex':float(matlab[0,0]).hex()}
    report['tool_versions']={'gfortran':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
                             'matlab':(work/'matlab_version.txt').read_text().strip()}
    report['artifact_sha256']={str(p.relative_to(work)):digest(p) for p in sorted(work.rglob('*'))
                              if p.is_file() and p.suffix in ['.F','.patch','.bin','.exe']}
    report['probe_sources_sha256']={str(p.relative_to(root)):digest(p) for p in
        [Path(__file__),root/'tests/alignment/fortran_forward_probe.f90',root/'tests/alignment/matlab_forward_probe.m']}
    for name,value in production.items():
        assert digest(root/name)==value, 'Production source changed during probe'
    (work/'results.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    for name,r in report['variants'].items():
        print(name,{key:r[key]['max_abs'] for key in ['base','perturbed','numerator','theta_e_sink']},
              'target_sink',r['target_theta_e_sink_difference_K_per_s'])


if __name__=='__main__':
    main()
