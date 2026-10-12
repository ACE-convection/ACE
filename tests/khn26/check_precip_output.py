#!/usr/bin/env python3
"""Check actual minute-output helpers using known fluxes, without running ACE."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

import numpy as np

from precip_timeseries import (ROOT,fortran_accumulator,matlab_accumulator_setup,
                               matlab_accumulator_step,patch_module,read_minute_precip)


def prepare(work):
    work.mkdir(parents=True,exist_ok=False)
    (work/'fortran').mkdir();(work/'matlab').mkdir()
    source='module test_accumulator\ncontains\n'+fortran_accumulator()+'''end module
program check
use test_accumulator
implicit none
integer::i,bytes
do i=1,14
  call record_precip_accumulation(4.,[1000.*(1./60000.),2./60.],[1./120.,0.])
enddo
inquire(file='precip_accumulation.bin',size=bytes)
if (bytes/=72) error stop 'A partial minute must not create a completed-minute record'
call record_precip_accumulation(4.,[1000.*(1./60000.),2./60.],[1./120.,0.])
do i=1,15
  call record_precip_accumulation(4.,[1./30.,2./30.],[0.,1./60.])
enddo
end program
'''
    file=work/'fortran/check.f90';file.write_text(source)
    command=['gfortran','-O2','-fdefault-real-8','-fdefault-double-8','-ffree-line-length-none',
        '-fcheck=all','-ffpe-trap=invalid,zero,overflow',str(file),'-o',str(work/'fortran/check.exe')]
    subprocess.run(command,cwd=work/'fortran',check=True)
    subprocess.run([str(work/'fortran/check.exe')],cwd=work/'fortran',check=True)
    minute,total=read_minute_precip(work/'fortran/precip_accumulation.bin',ncols=2,duration=120)
    np.testing.assert_allclose(minute,[[0,0],[1.5,2],[2,5]],rtol=0,atol=2e-14)
    np.testing.assert_allclose(total,[[0,0],[1.5,2],[3.5,7]],rtol=0,atol=2e-14)
    for modification in ('clock','truncated'):
        file=work/'fortran'/('invalid_'+modification+'.bin')
        original=np.fromfile(work/'fortran/precip_accumulation.bin','<f8').reshape(3,9)
        if modification=='clock':original[1,0]=59;original.tofile(file)
        else:file.write_bytes((work/'fortran/precip_accumulation.bin').read_bytes()[:-8])
        try:read_minute_precip(file,ncols=2,duration=120)
        except ValueError:pass
        else:raise AssertionError('Invalid output accepted: '+modification)
    paths=[ROOT/'fortran/src/ace_module.F',
        ROOT/'migration_work/khn26_single32_native_ci_3h/ace_module_multi.F',
        ROOT/'migration_work/khn26_multi_weno_three_hour_gates/ace_module_multi.F',
        ROOT/'migration_work/khn26_p3_three_hour/singleACE/source/ace_module.F']
    dependency=ROOT/'migration_work/khn26_p3_smoke/production_build'
    for i,path in enumerate(paths):
        build=work/('module_'+str(i));build.mkdir()
        file=build/'ace_module.F';file.write_text(patch_module(path.read_text()))
        subprocess.run(['gfortran','-O2','-ffree-form','-ffree-line-length-none','-fdefault-real-8',
            '-fdefault-double-8','-fopenmp','-I'+str(dependency),'-c',str(file)],cwd=build,check=True)
    matlab='''model.Ni=2;model.rho_zc=[1;2;3];model.dz=10;dt=4;
'''+matlab_accumulator_setup(work/'matlab/precip_accumulation.bin')+'''
for i=1:30
  dQt=zeros(3,2);dQt(3,:)=-100; % Nonphysical top slot must be excluded.
  if i<=15, dQt(1,:)=-[1,2]/600; else, dQt(1,:)=-[1,2]/300; end
'''+matlab_accumulator_step()+'''
  if i==14, assert(ftell(precip_series_fid)==72); end
end
fclose(precip_series_fid);
disp('MATLAB minute accumulation fixture completed')
'''
    (work/'matlab/check.m').write_text(matlab)
    result=dict(fortran_known_flux_fixture_passed=True,partial_minute_does_not_emit=True,
        invalid_clock_and_truncated_records_rejected=True,instrumented_module_compile_count=4,
        matlab_fixture_prepared=True,matlab_fixture_executed=False,no_model_integration=True)
    (work/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


def check_matlab(work):
    minute,total=read_minute_precip(work/'matlab/precip_accumulation.bin',ncols=2,duration=120)
    np.testing.assert_allclose(minute,[[0,0],[1,2],[2,4]],rtol=0,atol=2e-14)
    np.testing.assert_allclose(total,[[0,0],[1,2],[3,6]],rtol=0,atol=2e-14)
    result=json.loads((work/'results.json').read_text())
    result.update(matlab_fixture_executed=True,matlab_known_flux_fixture_passed=True,matlab_top_slot_excluded=True)
    (work/'results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    parser.add_argument('--check-matlab',action='store_true');args=parser.parse_args()
    if args.check_matlab:check_matlab(args.work.resolve())
    else:prepare(args.work.resolve())
