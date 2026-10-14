#!/usr/bin/env python3
"""Check P3 wrapper ownership, first-use timing and the single-context boundary.

Only isolated module copies gain tracing/private helpers. Third-party source,
lookup tables and the hash-pinned frozen workspace remain unchanged. This
stage explicitly retains one P3 wrapper context per fresh process.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

import numpy as np
from oop_regression import ROOT, BASELINE, INPUT_HASH, TABLE_HASH, sha, replace_once, write, compare_file


def run(work, baseline, lookup):
    source = work / 'sources/plain'
    config = json.loads((work / 'configuration.json').read_text())
    frozen = json.loads((ROOT / 'tests/khn26/oop_stage0_results.json').read_text())
    assert sha(baseline / 'builds/production_plain/ace_model.exe') == frozen['executable_sha256']['builds/production_plain/ace_model.exe']
    input_file = ROOT / 'data/input/manaus1342_khn26.nc'
    assert sha(input_file) == INPUT_HASH
    assert sha(lookup / 'p3_lookupTable_1.dat-v6.4-2momI') == TABLE_HASH
    for name, expected in config['source_sha256'].items():
        assert sha(source / name) == expected and sha(ROOT / 'fortran/src' / name) == expected, name
    dest = work / 'p3_contract'; dest.mkdir()
    (dest / 'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    old = subprocess.check_output(['git', 'show', BASELINE + ':fortran/src/ace_module.F'], cwd=ROOT, text=True)
    assert hashlib.sha256(old.encode()).hexdigest() == frozen['configuration']['source_sha256']['ace_module.F']
    oracle = old[old.index('subroutine p3_wrapper_ace('):old.index('end subroutine p3_wrapper_ace') + len('end subroutine p3_wrapper_ace')]
    (dest / 'frozen_wrapper.txt').write_text(oracle)
    module = (source / 'ace_module.F').read_text()
    body = module[module.index('subroutine p3_wrapper_ace('):module.index('end subroutine p3_wrapper_ace') + len('end subroutine p3_wrapper_ace')]
    body = body.replace('p3_wrapper_ace(p3,', 'p3_wrapper_ace(').replace('type(ace_p3_t), intent(inout) :: p3\n', '')
    body = body.replace("  if (p3_context_claimed) error stop 'Only one P3 context per fresh process is supported'\n", '').replace('  p3_context_claimed=.true.\n', '')
    body = body.replace('! local variables\n', '! local variables\ninteger, save :: itt = 1\nlogical, save :: first = .True.\n')
    body = body.replace('p3%first', 'first').replace('p3%itt', 'itt').replace('p3%directory', 'p3_lookup_directory')
    assert body == oracle, 'Numerical wrapper statements/order differ from frozen source'
    module = replace_once(module, 'public :: ace_t, ace_response_t', 'public :: ace_t, ace_response_t, oop_check_p3')
    module = replace_once(module, '\ncontains\n\nsubroutine ace_driver', '''
! Test-only counters and open trace units; never included in production source.
integer, save :: oop_init_calls=0,oop_main_calls=0
contains

subroutine ace_driver''')
    module = replace_once(module, '  call p3_init(trim(p3%directory)',
                          '  oop_init_calls=oop_init_calls+1\n  write(75) p3%directory\n  flush(75)\n  call p3_init(trim(p3%directory)')
    module = replace_once(module, 'call p3_main(qc,nc,qr,nr,th_old,th,qv_old,qv,dt,',
                          'oop_main_calls=oop_main_calls+1\nwrite(76) p3%itt\nflush(76)\ncall p3_main(qc,nc,qr,nr,th_old,th,qv_old,qv,dt,')
    module = replace_once(module, 'p3%itt = p3%itt + 1', '''write(71) X
write(72) precip_liq
write(73) precip_sol
flush(71);flush(72);flush(73)
p3%itt = p3%itt + 1''')
    helper = '''
subroutine oop_check_p3(mode,input_file,lookup)
character(*), intent(in) :: mode,input_file,lookup
type(ace_t) :: a,b
type(ace_response_t) :: procedural_response
integer :: nc,nz,nb,nv,intervals,step,state
logical :: khn,precip
real :: dt,now
real, allocatable :: X(:,:,:),Ref(:,:),Aarea(:),Bperimeter(:),forcing(:,:)
character(16) :: physics
! Trace files exist even for expected errors, exposing calls before rejection.
open(71,file='after_physics.bin',access='stream',form='unformatted',status='new')
open(72,file='liquid.bin',access='stream',form='unformatted',status='new')
open(73,file='solid.bin',access='stream',form='unformatted',status='new')
open(75,file='init_paths.bin',access='stream',form='unformatted',status='new')
open(76,file='counters.bin',access='stream',form='unformatted',status='new')
if (mode=='empty_setter') call set_p3_lookup_directory('')
if (mode=='long_setter') call set_p3_lookup_directory(repeat('x',1025))
if (mode=='empty_model_option') call set_p3_context_directory(a%p3,'')
if (mode=='long_model_option') call set_p3_context_directory(a%p3,repeat('x',1025))

dt=4.;intervals=1;physics='p3'
call a%initialize(.true.,input_file,lookup,2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
if (.not.a%p3%first .or. a%p3%itt/=1 .or. p3_context_claimed .or. oop_init_calls/=0) error stop 'P3 initialized eagerly'
call a%integrate(0.)
call a%diagnose()
call a%open_output('fields.bin');call a%output()
if (.not.a%p3%first .or. a%p3%itt/=1 .or. p3_context_claimed .or. oop_init_calls/=0) error stop 'Observation initialized P3'
open(newunit=state,file='states.bin',access='stream',form='unformatted',status='new')
write(state) nc,nz,nv
write(state) real(a%X,real64),real(a%Tv0,real64)
if (mode=='legacy' .or. mode=='legacy_then_model') then
  call set_p3_lookup_directory(lookup)
  X=a%X;Ref=a%Ref;Aarea=a%A(1:nc);Bperimeter=a%B(1:nc);forcing=a%forcing
  call ace_initialization(nc,nz,nb,a%coarse_z,a%coarse_ze,input_file,a%Tv0,netcdf_input=.true.,response=procedural_response)
  now=0.
  do step=1,10
    call ace_driver(nc,nz,2,nv,X,Ref,Aarea,Bperimeter,now,real(step)*4.,4.,forcing, &
                    precipitation_input=.true.,response=procedural_response)
    write(state) real(X,real64)
    if (legacy_p3%first .or. legacy_p3%itt/=step+1 .or. oop_init_calls/=1 .or. oop_main_calls/=step) error stop 'Legacy P3 clock'
    if (.not.a%p3%first .or. a%p3%itt/=1) error stop 'Legacy path changed model wrapper'
    if (mode=='legacy_then_model') call a%integrate(4.)
  enddo
else
  ! A legacy setter and native initialization cannot replace A's lookup option.
  call set_p3_lookup_directory('./missing_legacy_tables/')
  if (mode=='model_native') then
    dt=4.;intervals=1;physics='native'
    call b%initialize(.true.,input_file,'./missing_native_tables/',2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
    call b%integrate(4.)
    if (p3_context_claimed .or. oop_init_calls/=0) error stop 'Native path initialized P3'
  endif
  do step=1,10
    call a%integrate(real(step)*4.)
    write(state) real(a%X,real64)
    if (a%p3%first .or. a%p3%itt/=step+1 .or. oop_init_calls/=1 .or. oop_main_calls/=step .or. .not.p3_context_claimed) error stop 'Model P3 clock'
    if (.not.legacy_p3%first .or. legacy_p3%itt/=1) error stop 'Model used legacy wrapper'
    call a%integrate(real(step)*4.)
    call a%diagnose();call a%output()
    if (a%p3%itt/=step+1 .or. oop_main_calls/=step .or. oop_init_calls/=1) error stop 'No-op/observation changed P3'
    if (mode=='model_native' .and. step==1) then
      call b%integrate(8.)
      if (.not.b%p3%first .or. b%p3%itt/=1 .or. oop_init_calls/=1 .or. oop_main_calls/=step) error stop 'Native changed active P3'
    endif
    if (mode=='second_model' .or. mode=='second_directory') then
      dt=4.;intervals=1;physics='p3'
      if (mode=='second_model') then
        call b%initialize(.true.,input_file,lookup,2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
      else
        call b%initialize(.true.,input_file,'./missing_second_tables/',2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
      endif
      call b%integrate(4.)
    endif
    if (mode=='model_then_legacy') then
      X=a%X
      call p3_wrapper_ace(legacy_p3,a%ncols,a%nz,a%n_prog,4.,X,a%X,a%Ref)
    endif
  enddo
endif
call a%close_output();close(state)
close(71);close(72);close(73);close(75);close(76)
end subroutine
'''
    module = replace_once(module, 'end module ace_module', helper + '\nend module ace_module')
    (dest / 'ace_module_contract.F').write_text(module)
    driver = '''program contract
use ace_module, only: oop_check_p3
implicit none
character(1024) :: mode,input_file,lookup
call get_command_argument(1,mode);call get_command_argument(2,input_file);call get_command_argument(3,lookup)
call oop_check_p3(trim(mode),input_file,lookup)
end program
'''
    (dest / 'contract.f90').write_text(driver)
    flags = ['-cpp', '-O2', '-ffree-form', '-ffree-line-length-none', '-fdefault-real-8',
             '-fdefault-double-8', '-fopenmp', '-fcheck=all,no-array-temps',
             '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
    includes = shlex.split(subprocess.check_output(['nf-config', '--fflags'], text=True))
    libs = shlex.split(subprocess.check_output(['nf-config', '--flibs'], text=True))
    report = {'passed': False, 'commands': [], 'checks': {}, 'errors': {}, 'runner_sha256': sha(Path(__file__)),
              'source_sha256': config['source_sha256'], 'lookup_sha256': TABLE_HASH,
              'frozen_wrapper_sha256': sha(dest / 'frozen_wrapper.txt'), 'qualification_only_numerical_audit': True,
              'scope': 'Checked real64/OpenMP32; model and public procedural ten-step P3 prefixes, per-context options/clock/init timing, one P3 context per process; no multi-P3 independence claim.'}
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS='32', OMP_THREAD_LIMIT='32', OMP_DYNAMIC='FALSE', OMP_STACKSIZE='64M')

    def execute(cmd, cwd, log, error=None):
        report['commands'].append({'argv': list(map(str, cmd)), 'cwd': str(cwd), 'log': str(log)})
        write(dest / 'results.json', report)
        with log.open('w') as stream:
            result = subprocess.run(list(map(str, cmd)), cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        report['commands'][-1]['exit_code'] = result.returncode
        if error:
            assert result.returncode != 0 and error in log.read_text(), log
        else:
            result.check_returncode()

    build = work / 'builds/checked_plain'
    execute(['gfortran', *flags, *includes, '-I' + str(build), '-c', dest / 'ace_module_contract.F', '-o', 'module.o'], dest, dest / 'compile.log')
    execute(['gfortran', *flags, '-I' + str(dest), dest / 'contract.f90', 'module.o',
             *[build / (n + '.o') for n in ('ace_input', 'ace_interpolation', 'microphy_p3')],
             *libs, '-o', 'contract.exe'], dest, dest / 'link.log')
    reference = baseline / 'runs/p3_prefix_production_observed'
    frozen_runs = json.loads((baseline / 'results.json').read_text())['artifacts']
    expected = {'states.bin': reference / 'states.bin', 'after_physics.bin': reference / 'observations/after_physics.bin',
                'liquid.bin': reference / 'observations/p3_liquid_flux.bin', 'solid.bin': reference / 'observations/p3_solid_flux.bin'}
    for path in expected.values():
        item = frozen_runs[str(path.relative_to(baseline))]
        assert sha(path) == item['sha256'] and path.stat().st_size == item['bytes'], path
    for mode in ('model', 'model_native', 'legacy'):
        print('P3 wrapper contract', mode, flush=True)
        directory = dest / mode; directory.mkdir()
        execute([dest / 'contract.exe', mode, input_file, lookup], directory, directory / 'run.log')
        checks = {name: compare_file(path, directory / name) for name, path in expected.items()}
        assert all(c['bitwise_identical'] for c in checks.values()), mode
        assert (directory / 'init_paths.bin').read_bytes() == str(lookup).ljust(1024).encode()
        assert np.array_equal(np.fromfile(directory / 'counters.bin', '<i4'), np.arange(1, 11))
        assert (directory / 'run.log').read_text().count('P3_INIT DONE.') == 1
        checks.update(first_use_init_once=True, first_itt_1_and_ten_increments=True, directory_binding=True,
                      neutral_diagnose_output_noop=True, real_library_initialization_count=1)
        report['checks'][mode] = checks
        write(dest / 'results.json', report)
    for mode in ('second_model', 'second_directory', 'model_then_legacy', 'legacy_then_model'):
        print('P3 single-context rejection', mode, flush=True)
        directory = dest / mode; directory.mkdir()
        execute([dest / 'contract.exe', mode, input_file, lookup], directory, directory / 'run.log',
                'Only one P3 context per fresh process is supported')
        assert (directory / 'init_paths.bin').read_bytes() == str(lookup).ljust(1024).encode()
        assert np.array_equal(np.fromfile(directory / 'counters.bin', '<i4'), [1])
        assert (directory / 'run.log').read_text().count('P3_INIT DONE.') == 1
        report['errors'][mode] = {'rejected_before_second_library_init_or_main': True, 'init_calls': 1, 'main_calls': 1}
    for mode in ('empty_setter', 'long_setter', 'empty_model_option', 'long_model_option'):
        directory = dest / mode; directory.mkdir()
        execute([dest / 'contract.exe', mode, input_file, lookup], directory, directory / 'run.log', 'Invalid P3 lookup directory')
        assert (directory / 'init_paths.bin').stat().st_size == (directory / 'counters.bin').stat().st_size == 0
        report['errors'][mode] = {'validation_message_preserved': True, 'no_library_calls': True}
    report.update(passed=True, candidate_executable_sha256=sha(dest / 'contract.exe'),
                  helper_sha256=sha(dest / 'ace_module_contract.F'), driver_sha256=sha(dest / 'contract.f90'))
    write(dest / 'results.json', report)
    print('PASS model-owned P3 wrapper and explicit single-context contract', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'migration_work/fortran_v020_oop_stage0')
    parser.add_argument('--lookup-directory', type=Path, default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
    args = parser.parse_args()
    run(args.work.resolve(), args.baseline.resolve(), args.lookup_directory.resolve())
