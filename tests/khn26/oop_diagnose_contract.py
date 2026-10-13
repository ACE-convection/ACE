#!/usr/bin/env python3
"""Verify observational diagnoses against the frozen writer in isolated helpers.

Test-only access to private buffers is compiled in the candidate workspace.
The oracle is extracted verbatim from the hash-pinned OOP-0 test.F, never from
candidate diagnostics. Every physics case runs in a fresh process.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess

from oop_regression import ROOT, BASELINE, INPUT_HASH, TABLE_HASH, sha, replace_once, write, compare_file


def run(work, baseline, lookup):
    source = work / 'sources/plain'
    config = json.loads((work / 'configuration.json').read_text())
    frozen = json.loads((ROOT / 'tests/khn26/oop_stage0_results.json').read_text())
    executable = baseline / 'builds/production_plain/ace_model.exe'
    assert sha(executable) == frozen['executable_sha256']['builds/production_plain/ace_model.exe']
    input_file = ROOT / 'data/input/manaus1342_khn26.nc'
    assert sha(input_file) == INPUT_HASH
    assert sha(lookup / 'p3_lookupTable_1.dat-v6.4-2momI') == TABLE_HASH
    for name, expected in config['source_sha256'].items():
        assert sha(source / name) == expected, name
        assert sha(ROOT / 'fortran/src' / name) == expected, 'Source differs from snapshot: ' + name
    dest = work / 'diagnose_contract'
    dest.mkdir()
    (dest / 'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    old = subprocess.check_output(['git','show',BASELINE + ':fortran/src/test.F'],cwd=ROOT,text=True)
    import hashlib
    assert hashlib.sha256(old.encode()).hexdigest() == frozen['configuration']['source_sha256']['test.F']
    oracle = old[old.index('Xout=0.'):old.index('write(10,rec=n)')]
    (dest / 'frozen_diagnose_body.txt').write_text(oracle)
    module = (source / 'ace_module.F').read_text()
    # Exact extraction audit supplements runtime evidence: qualification only.
    extracted = module[module.index('self%diagnostics%Xout=0.'):module.index('if (present(Xout))')]
    extracted = extracted.replace('self%diagnostics%','').replace('self%','')
    assert extracted == oracle, 'Numerical statements differ from frozen diagnostics'
    assert re.search(r'real, parameter :: g\s*=\s*9\.80665\b',module)
    module = replace_once(module,'public :: ace_t, ace_response_t',
                          'public :: ace_t, ace_response_t, oop_check_diagnose')
    helper = '''
subroutine oop_diagnose_snapshot(self,unit)
class(ace_t), intent(in) :: self
integer, intent(in) :: unit
write(unit) self%X,self%Ref,self%A,self%B,self%forcing,self%Tv0,self%t,self%dt
write(unit) self%thermal%reference_tv,self%thermal%Ta,self%thermal%q,self%thermal%ql,self%thermal%qi
write(unit) self%response%coarse_z,self%response%coarse_ze,self%response%coarse_F,self%response%dwdt
write(unit) self%response%coarse_nz,self%response%coarse_ratio,self%response%slab_geometry, &
            self%response%zero_ref_buoyancy,self%response%Wbar_eq_zero,self%response%turn_off_DHv,self%response%turn_off_DHh
end subroutine

subroutine oop_diagnose_frame(self,before,after,actual,expected)
class(ace_t), intent(inout) :: self
integer, intent(in) :: before,after,actual,expected
integer :: i,k,ncols,nz,n_prog,repeat
real :: dum1
real, allocatable :: X(:,:,:),Ref(:,:),Tv0(:),Tr(:,:),q(:,:),ql(:,:),qi(:,:)
real(kind=4), allocatable :: Xout(:,:,:),rh4(:,:),b4(:,:)
ncols=self%ncols; nz=self%nz; n_prog=self%n_prog
X=self%X; Ref=self%Ref; Tv0=self%Tv0
allocate(Tr(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz))
allocate(Xout(ncols+1,nz,11),rh4(ncols,nz),b4(ncols,nz))
! Poison all diagnostic fields between checkpoints to prove full refresh.
if (allocated(self%diagnostics%Xout)) then
  self%diagnostics%Xout=-123.; self%diagnostics%rh4=-123.; self%diagnostics%b4=-123.
  self%diagnostics%Tr=-123.; self%diagnostics%q=-123.; self%diagnostics%ql=-123.; self%diagnostics%qi=-123.
endif
do repeat=1,3
  call oop_diagnose_snapshot(self,before)
  if (repeat==1) then
    call self%diagnose()
  elseif (repeat==2) then
    call self%diagnose(Xout,rh4,b4)
    write(actual) Xout,rh4,b4
    write(expected) self%diagnostics%Xout,self%diagnostics%rh4,self%diagnostics%b4
  else
    ! Single optional field copies must also work independently.
    call self%diagnose(rh4=rh4)
    write(actual) rh4
    write(expected) self%diagnostics%rh4
  endif
  call oop_diagnose_snapshot(self,after)
  write(actual) self%diagnostics%Xout,self%diagnostics%rh4,self%diagnostics%b4, &
                self%diagnostics%Tr,self%diagnostics%q,self%diagnostics%ql,self%diagnostics%qi
''' + oracle + '''  write(expected) Xout,rh4,b4,Tr,q,ql,qi
enddo
if (allocated(legacy_response%PMB) .or. allocated(legacy_thermal%reference_tv) .or. &
    allocated(legacy_thermal%Ta) .or. allocated(legacy_thermal%q) .or. &
    allocated(legacy_thermal%ql) .or. allocated(legacy_thermal%qi)) error stop 'Diagnose used legacy storage'
end subroutine

subroutine oop_check_diagnose(self,state,before,after,actual,expected)
class(ace_t), intent(inout) :: self
integer, intent(in) :: state,before,after,actual,expected
integer :: step
! Initialization allocates these work arrays without defining their values.
! Seed them only in this isolated helper so the initial preservation check
! reads defined values and detects a diagnose write before the first RK call.
self%thermal%Ta=-123.; self%thermal%q=-123.; self%thermal%ql=-123.; self%thermal%qi=-123.
self%response%coarse_F=-123.; self%response%dwdt=-123.
write(state) self%ncols,self%nz,self%n_prog
write(state) real(self%X,real64),real(self%Tv0,real64)
call oop_diagnose_frame(self,before,after,actual,expected)
do step=1,5
  call self%integrate(real(step)*6.)
  write(state) real(self%X,real64)
  call oop_diagnose_frame(self,before,after,actual,expected)
enddo
end subroutine
'''
    module = replace_once(module,'end module ace_module',helper+'\nend module ace_module')
    (dest / 'ace_module_contract.F').write_text(module)
    driver = '''program contract
use ace_module, only: ace_t,oop_check_diagnose
implicit none
type(ace_t) :: model
character(1024) :: input_file,lookup
character(16) :: physics
integer :: ncols,nz,ncoarse,n_prog,intervals,state,before,after,actual,expected
logical :: khn26_case,precipitation_enabled
real :: dt
call get_command_argument(1,input_file)
call get_command_argument(2,lookup)
call get_command_argument(3,physics)
dt=6.; intervals=1
call model%initialize(.true.,input_file,lookup,2,physics,dt,intervals,.true., &
                      ncols,nz,ncoarse,n_prog,khn26_case,precipitation_enabled)
open(newunit=state,file='states.bin',access='stream',form='unformatted',status='new')
open(newunit=before,file='before.bin',access='stream',form='unformatted',status='new')
open(newunit=after,file='after.bin',access='stream',form='unformatted',status='new')
open(newunit=actual,file='actual.bin',access='stream',form='unformatted',status='new')
open(newunit=expected,file='expected.bin',access='stream',form='unformatted',status='new')
call oop_check_diagnose(model,state,before,after,actual,expected)
close(state);close(before);close(after);close(actual);close(expected)
end program
'''
    (dest / 'contract.f90').write_text(driver)
    flags = ['-cpp','-O2','-ffree-form','-ffree-line-length-none','-fdefault-real-8',
             '-fdefault-double-8','-fopenmp','-fcheck=all,no-array-temps',
             '-ffpe-trap=invalid,zero,overflow','-fbacktrace']
    includes = shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs = shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    report = {'passed':False,'commands':[],'checks':{},'runner_sha256':sha(Path(__file__)),
              'baseline_executable_sha256':sha(executable),'source_sha256':config['source_sha256'],
              'frozen_oracle_sha256':sha(dest/'frozen_diagnose_body.txt'),'qualification_only_source_audit':True,
              'scope':'Checked real64/OpenMP32; fresh none/native/P3; six checkpoints, three diagnoses each; full diagnostic precision/real32 fields, repeated refresh, state/cache/clock neutrality and five-step frozen identity.'}
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M')
    def execute(cmd,cwd,log):
        report['commands'].append({'argv':list(map(str,cmd)),'cwd':str(cwd),'log':str(log)})
        write(dest/'results.json',report)
        with log.open('w') as stream:
            subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
    build = work / 'builds/checked_plain'
    execute(['gfortran',*flags,*includes,'-I'+str(build),'-c',dest/'ace_module_contract.F','-o','module.o'],dest,dest/'compile.log')
    execute(['gfortran',*flags,'-I'+str(dest),dest/'contract.f90','module.o',
             *[build/(n+'.o') for n in ('ace_input','ace_interpolation','microphy_p3')],
             *libs,'-o','contract.exe'],dest,dest/'link.log')
    for physics in ('none','native','p3'):
        print('Diagnose contract',physics,flush=True)
        candidate = dest/(physics+'_candidate');candidate.mkdir()
        reference = dest/(physics+'_baseline');reference.mkdir()
        execute([dest/'contract.exe',input_file,lookup,physics],candidate,candidate/'run.log')
        execute([executable,'--input',input_file,'--p3-lookup-directory',lookup,'--physics',physics,
                 '--dt','6','--steps','5','--state-output',reference/'states.bin'],reference,reference/'run.log')
        checks = {'state_cache_clock_response_unchanged':compare_file(candidate/'before.bin',candidate/'after.bin'),
                  'frozen_diagnostics_and_optional_copies':compare_file(candidate/'expected.bin',candidate/'actual.bin'),
                  'interspersed_diagnoses_preserve_five_steps':compare_file(reference/'states.bin',candidate/'states.bin')}
        assert all(c['bitwise_identical'] for c in checks.values()),physics
        report['checks'][physics]=checks
        write(dest/'results.json',report)
    report.update(passed=True,candidate_executable_sha256=sha(dest/'contract.exe'),
                  helper_sha256=sha(dest/'ace_module_contract.F'),driver_sha256=sha(dest/'contract.f90'))
    write(dest/'results.json',report)
    print('PASS observational diagnose contract',flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--baseline',type=Path,default=ROOT/'migration_work/fortran_v020_oop_stage0')
    parser.add_argument('--lookup-directory',type=Path,default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
    args=parser.parse_args()
    run(args.work.resolve(),args.baseline.resolve(),args.lookup_directory.resolve())
