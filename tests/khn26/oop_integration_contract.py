#!/usr/bin/env python3
"""Check object clock targets, no-op cache preservation and procedural identity.

Test helpers exist only in an isolated snapshot. Each physics case uses a fresh
process; the frozen baseline executable and its workspace remain read-only.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess

from oop_regression import ROOT, INPUT_HASH, TABLE_HASH, sha, replace_once, write


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
        assert sha(ROOT / 'fortran/src' / name) == expected, 'Current source differs from snapshot: ' + name
    dest = work / 'integration_contract'
    dest.mkdir()
    (dest / 'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    module = replace_once((source / 'ace_module.F').read_text(),
                          'public :: ace_t, ace_response_t',
                          'public :: ace_t, ace_response_t, oop_check_integrate')
    helper = '''
subroutine oop_check_integrate(self,state_unit,cache_unit)
class(ace_t), intent(inout) :: self
integer, intent(in) :: state_unit,cache_unit
write(state_unit) self%ncols,self%nz,self%n_prog
write(state_unit) real(self%X,real64),real(self%Tv0,real64)
if (self%t/=0.) error stop 'Initial clock'
call self%integrate(1.)
if (self%t/=6.) error stop 'Full-dt target overshoot changed'
write(state_unit) real(self%X,real64)
write(cache_unit) self%thermal%reference_tv,self%thermal%Ta,self%thermal%q,self%thermal%ql,self%thermal%qi
! Repeated, past and exactly aligned targets must leave state/cache unchanged.
call self%integrate(1.)
call self%integrate(0.)
call self%integrate(6.)
if (self%t/=6.) error stop 'No-op target changed clock'
write(state_unit) real(self%X,real64)
write(cache_unit) self%thermal%reference_tv,self%thermal%Ta,self%thermal%q,self%thermal%ql,self%thermal%qi
call self%integrate(7.)
if (self%t/=12.) error stop 'Clock did not persist across calls'
write(state_unit) real(self%X,real64)
call self%integrate(18.)
if (self%t/=18.) error stop 'Aligned target changed clock'
write(state_unit) real(self%X,real64)
call self%integrate(19.,reset_clock_to_target=.true.)
if (self%t/=19.) error stop 'Explicit interval clock reset changed'
write(state_unit) real(self%X,real64)
call self%integrate(25.)
if (self%t/=25.) error stop 'Clock did not retain explicit reset'
write(state_unit) real(self%X,real64)
if (allocated(legacy_response%PMB) .or. allocated(legacy_thermal%Ta) .or. &
    allocated(legacy_thermal%reference_tv)) error stop 'Object used legacy storage'
end subroutine oop_check_integrate
'''
    damping_owned = "type :: ace_damping_t" in module
    if damping_owned:
        cache_write = "write(cache_unit) self%thermal%reference_tv,self%thermal%Ta,self%thermal%q,self%thermal%ql,self%thermal%qi"
        helper = helper.replace(cache_write, cache_write + "\nwrite(cache_unit) self%damping%first,self%damping%damp")
    module = replace_once(module, 'end module ace_module', helper + '\nend module ace_module')
    (dest / 'ace_module_contract.F').write_text(module)
    driver = '''program contract
use ace_module, only: ace_t,oop_check_integrate
implicit none
type(ace_t) :: model
character(1024) :: input_file,lookup
character(16) :: physics
integer :: ncols,nz,ncoarse,n_prog,intervals,state_unit,cache_unit
logical :: khn26_case,precipitation_enabled
real :: dt
call get_command_argument(1,input_file)
call get_command_argument(2,lookup)
call get_command_argument(3,physics)
dt=6.; intervals=1
call model%initialize(.true.,input_file,lookup,2,physics,dt,intervals,.true., &
                      ncols,nz,ncoarse,n_prog,khn26_case,precipitation_enabled)
open(newunit=state_unit,file='states.bin',access='stream',form='unformatted',status='new')
open(newunit=cache_unit,file='caches.bin',access='stream',form='unformatted',status='new')
call oop_check_integrate(model,state_unit,cache_unit)
close(state_unit);close(cache_unit)
end program contract
'''
    (dest / 'contract.f90').write_text(driver)
    flags = ['-cpp','-O2','-ffree-form','-ffree-line-length-none','-fdefault-real-8',
             '-fdefault-double-8','-fopenmp','-fcheck=all,no-array-temps',
             '-ffpe-trap=invalid,zero,overflow','-fbacktrace']
    includes = shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs = shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    report = {'passed':False, 'commands':[], 'checks':{}, 'runner_sha256':sha(Path(__file__)),
              'baseline_executable_sha256':sha(executable), 'source_sha256':config['source_sha256'],
              'scope':'GNU checked real64/OpenMP32; fresh none/native/P3 processes; dt=6; five steps with no-op and explicit reset targets; fractional-dt interval replay.'}
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M')
    def execute(cmd,cwd,log):
        report['commands'].append({'argv':list(map(str,cmd)), 'cwd':str(cwd), 'log':str(log)})
        write(dest/'results.json',report)
        with log.open('w') as stream:
            subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)
    build = work / 'builds/checked_plain'
    execute(['gfortran',*flags,*includes,'-I'+str(build),'-c',dest/'ace_module_contract.F','-o','module.o'],dest,dest/'compile.log')
    execute(['gfortran',*flags,'-I'+str(dest),dest/'contract.f90','module.o',
             *[build/(n+'.o') for n in ('ace_input','ace_interpolation','microphy_p3')],
             *libs,'-o','contract.exe'],dest,dest/'link.log')
    for physics in ('none','native','p3'):
        print('Integration contract',physics,flush=True)
        candidate = dest/(physics+'_candidate');candidate.mkdir()
        reference = dest/(physics+'_baseline');reference.mkdir()
        execute([dest/'contract.exe',input_file,lookup,physics],candidate,candidate/'run.log')
        execute([executable,'--input',input_file,'--p3-lookup-directory',lookup,
                 '--physics',physics,'--dt','6','--steps','5','--state-output',reference/'states.bin'],reference,reference/'run.log')
        import numpy as np
        n,z,nv=map(int,np.fromfile(reference/'states.bin','<i4',count=3))
        size=(n+1)*z*nv*8; initial=12+size+z*8
        a=(candidate/'states.bin').read_bytes();b=(reference/'states.bin').read_bytes()
        assert len(a)==initial+6*size and len(b)==initial+5*size
        assert a[:initial]==b[:initial]
        assert a[initial:initial+size]==a[initial+size:initial+2*size]==b[initial:initial+size]
        assert a[initial+2*size:]==b[initial+size:]
        caches=(candidate/'caches.bin').read_bytes();half=(z+4*n*z)*8
        if damping_owned: half += 4+z*8
        assert len(caches)==2*half and caches[:half]==caches[half:]
        report['checks'][physics]={'clock_assertions_passed':True,'full_dt_overshoot_preserved':True,
                                  'no_op_state_and_cache_bitwise_unchanged':True,'explicit_reset_and_five_steps_match_frozen_baseline':True,
                                  'candidate_state_sha256':sha(candidate/'states.bin'),
                                  'baseline_state_sha256':sha(reference/'states.bin'),
                                  'cache_sha256':sha(candidate/'caches.bin')}
        write(dest/'results.json',report)
    # The old CLI explicitly resets ts=te after every output interval. With
    # fractional dt, persisting only the accumulated clock changes step counts.
    fractional = {}
    for variant,exe in [('baseline',executable),('candidate',work/'builds/production_plain/ace_model.exe')]:
        cwd=dest/('fractional_'+variant);cwd.mkdir()
        execute([exe,'--input',input_file,'--p3-lookup-directory',lookup,'--physics','native',
                 '--dt',repr(60/13),'--intervals','3','--state-output',cwd/'states.bin',
                 '--output',cwd/'fields.bin'],cwd,cwd/'run.log')
        fractional[variant]=cwd
    from oop_regression import compare_file
    report['checks']['fractional_dt_intervals'] = {}
    for name in ('states.bin','fields.bin'):
        check=compare_file(fractional['baseline']/name,fractional['candidate']/name)
        assert check['bitwise_identical'],name
        report['checks']['fractional_dt_intervals'][name]=check
    report['fractional_cli_executable_sha256']=sha(work/'builds/production_plain/ace_model.exe')
    report.update(passed=True,candidate_executable_sha256=sha(dest/'contract.exe'),
                  helper_sha256=sha(dest/'ace_module_contract.F'),driver_sha256=sha(dest/'contract.f90'))
    write(dest/'results.json',report)
    print('PASS integration clock/cache contract',flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--baseline',type=Path,default=ROOT/'migration_work/fortran_v020_oop_stage0')
    parser.add_argument('--lookup-directory',type=Path,default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
    args=parser.parse_args()
    run(args.work.resolve(),args.baseline.resolve(),args.lookup_directory.resolve())
