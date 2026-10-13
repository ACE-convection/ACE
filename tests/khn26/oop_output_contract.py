#!/usr/bin/env python3
"""Check model-owned output against the hash-pinned frozen writer/executable.

Private helpers exist only in an isolated checked snapshot. Fresh processes
retain the current damping/P3 restriction; production source is never patched.
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
    executable = baseline / 'builds/production_plain/ace_model.exe'
    assert sha(executable) == frozen['executable_sha256']['builds/production_plain/ace_model.exe']
    input_file = ROOT / 'data/input/manaus1342_khn26.nc'
    assert sha(input_file) == INPUT_HASH
    assert sha(lookup / 'p3_lookupTable_1.dat-v6.4-2momI') == TABLE_HASH
    for name, expected in config['source_sha256'].items():
        assert sha(source / name) == expected, name
        assert sha(ROOT / 'fortran/src' / name) == expected, name
    dest = work / 'output_contract'
    dest.mkdir()
    (dest / 'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    old = subprocess.check_output(['git', 'show', BASELINE + ':fortran/src/test.F'], cwd=ROOT, text=True)
    assert hashlib.sha256(old.encode()).hexdigest() == frozen['configuration']['source_sha256']['test.F']
    oracle = old[old.index('Xout=0.'):old.index('n=n+1', old.index('subroutine write_state()'))]
    (dest / 'frozen_writer.txt').write_text(oracle)
    # Only the target unit/record is adapted; numerical and field ordering stay frozen.
    oracle = oracle.replace('write(10,rec=n)', 'write(expected,rec=record)')
    module = replace_once((source / 'ace_module.F').read_text(), 'public :: ace_t, ace_response_t',
                          'public :: ace_t, ace_response_t, oop_check_output')
    helper = '''
subroutine oop_output_snapshot(self,unit)
class(ace_t), intent(in) :: self
integer, intent(in) :: unit
write(unit) self%X,self%Ref,self%A,self%B,self%forcing,self%Tv0,self%t,self%dt
write(unit) self%thermal%reference_tv,self%thermal%Ta,self%thermal%q,self%thermal%ql,self%thermal%qi
write(unit) self%response%coarse_z,self%response%coarse_ze,self%response%coarse_F,self%response%dwdt
write(unit) self%response%coarse_nz,self%response%coarse_ratio,self%response%slab_geometry, &
            self%response%zero_ref_buoyancy,self%response%Wbar_eq_zero,self%response%turn_off_DHv,self%response%turn_off_DHh
end subroutine

subroutine oop_check_output(self,state,before,after)
class(ace_t), intent(inout) :: self
integer, intent(in) :: state,before,after
integer :: i,k,ncols,nz,n_prog,repeat,checkpoint,record,expected,record_length,actual_length
real :: dum1
real, allocatable :: X(:,:,:),Ref(:,:),Tv0(:),Tr(:,:),q(:,:),ql(:,:),qi(:,:)
real(kind=4), allocatable :: Xout(:,:,:),rh4(:,:),b4(:,:)
ncols=self%ncols; nz=self%nz; n_prog=self%n_prog
allocate(Tr(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz))
allocate(Xout(ncols+1,nz,11),rh4(ncols,nz),b4(ncols,nz))
inquire(iolength=record_length) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6), &
                              Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4,b4
open(newunit=expected,file='expected.bin',access='direct',form='unformatted',status='new',recl=record_length)
! Define only uninitialized scratch in this isolated helper before snapshotting.
self%thermal%Ta=-123.;self%thermal%q=-123.;self%thermal%ql=-123.;self%thermal%qi=-123.
self%response%coarse_F=-123.;self%response%dwdt=-123.
write(state) ncols,nz,n_prog
write(state) real(self%X,real64),real(self%Tv0,real64)
call oop_output_snapshot(self,before)
call self%open_output('actual.bin')
call oop_output_snapshot(self,after)
if (self%output_record/=1 .or. .not.self%output_open) error stop 'Open policy'
inquire(unit=self%output_unit,recl=actual_length)
if (actual_length/=record_length) error stop 'Record length'
record=1
! Initial, two interior minute checkpoints, and final; three writes per state.
do checkpoint=0,3
  if (checkpoint>0) then
    call self%integrate(real(checkpoint)*60.,reset_clock_to_target=.true.)
    write(state) real(self%X,real64)
  endif
  X=self%X; Ref=self%Ref; Tv0=self%Tv0
  do repeat=1,3
    ! A diagnostic call between writes must not consume a record or accumulate.
    call self%diagnose()
    if (self%output_record/=record) error stop 'Diagnose consumed record'
    self%diagnostics%Xout=-123.;self%diagnostics%rh4=-123.;self%diagnostics%b4=-123.
    self%diagnostics%Tr=-123.;self%diagnostics%q=-123.;self%diagnostics%ql=-123.;self%diagnostics%qi=-123.
    call oop_output_snapshot(self,before)
    call self%output()
    call oop_output_snapshot(self,after)
    if (self%output_record/=record+1) error stop 'Record increment'
''' + oracle + '''    record=record+1
  enddo
enddo
call oop_output_snapshot(self,before)
call self%close_output()
call oop_output_snapshot(self,after)
if (self%output_open) error stop 'Close policy'
close(expected)
! Reopen a fresh file on this object: reset record, preserve model/clock/cache.
call oop_output_snapshot(self,before)
call self%open_output('reopened.bin')
if (self%output_record/=1) error stop 'Reopen record reset'
call self%output()
if (self%output_record/=2) error stop 'Reopen record increment'
call self%close_output()
call oop_output_snapshot(self,after)
end subroutine oop_check_output
'''
    module = replace_once(module, 'end module ace_module', helper + '\nend module ace_module')
    (dest / 'ace_module_contract.F').write_text(module)
    driver = '''program contract
use ace_module, only: ace_t,oop_check_output
implicit none
type(ace_t) :: model
character(1024) :: input_file,lookup
character(16) :: physics,mode
integer :: ncols,nz,ncoarse,n_prog,intervals,state,before,after
logical :: khn26_case,precipitation_enabled
real :: dt
call get_command_argument(1,input_file)
call get_command_argument(2,lookup)
call get_command_argument(3,physics)
call get_command_argument(4,mode)
if (mode=='unopened') call model%output()
if (mode=='unopened_close') call model%close_output()
dt=4.;intervals=3
call model%initialize(.true.,input_file,lookup,2,physics,dt,intervals,.true., &
                      ncols,nz,ncoarse,n_prog,khn26_case,precipitation_enabled)
if (mode=='double_open') then
  call model%open_output('guard.bin')
  call model%open_output('other.bin')
elseif (mode=='after_close') then
  call model%open_output('guard.bin')
  call model%close_output()
  call model%output()
else
  open(newunit=state,file='states.bin',access='stream',form='unformatted',status='new')
  open(newunit=before,file='before.bin',access='stream',form='unformatted',status='new')
  open(newunit=after,file='after.bin',access='stream',form='unformatted',status='new')
  call oop_check_output(model,state,before,after)
  close(state);close(before);close(after)
endif
end program
'''
    (dest / 'contract.f90').write_text(driver)
    flags = ['-cpp', '-O2', '-ffree-form', '-ffree-line-length-none', '-fdefault-real-8',
             '-fdefault-double-8', '-fopenmp', '-fcheck=all,no-array-temps',
             '-ffpe-trap=invalid,zero,overflow', '-fbacktrace']
    includes = shlex.split(subprocess.check_output(['nf-config', '--fflags'], text=True))
    libs = shlex.split(subprocess.check_output(['nf-config', '--flibs'], text=True))
    report = {'passed': False, 'commands': [], 'checks': {}, 'runner_sha256': sha(Path(__file__)),
              'baseline_executable_sha256': sha(executable), 'source_sha256': config['source_sha256'],
              'frozen_writer_sha256': sha(dest / 'frozen_writer.txt'),
              'scope': 'Checked real64/OpenMP32; fresh none/native/P3; three-minute initial/interior/final records, repeated/poisoned diagnostics, model/cache neutrality, reopen and error policies.'}
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS='32', OMP_THREAD_LIMIT='32', OMP_DYNAMIC='FALSE', OMP_STACKSIZE='64M')

    def execute(cmd, cwd, log, failure=None):
        report['commands'].append({'argv': list(map(str, cmd)), 'cwd': str(cwd), 'log': str(log)})
        write(dest / 'results.json', report)
        with log.open('w') as stream:
            result = subprocess.run(list(map(str, cmd)), cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        report['commands'][-1]['exit_code'] = result.returncode
        if failure:
            assert result.returncode != 0 and failure in log.read_text(), log
        else:
            result.check_returncode()

    build = work / 'builds/checked_plain'
    execute(['gfortran', *flags, *includes, '-I' + str(build), '-c', dest / 'ace_module_contract.F', '-o', 'module.o'], dest, dest / 'compile.log')
    execute(['gfortran', *flags, '-I' + str(dest), dest / 'contract.f90', 'module.o',
             *[build / (n + '.o') for n in ('ace_input', 'ace_interpolation', 'microphy_p3')],
             *libs, '-o', 'contract.exe'], dest, dest / 'link.log')
    for physics in ('none', 'native', 'p3'):
        print('Output contract', physics, flush=True)
        candidate = dest / (physics + '_candidate'); candidate.mkdir()
        reference = dest / (physics + '_baseline'); reference.mkdir()
        execute([dest / 'contract.exe', input_file, lookup, physics, 'normal'], candidate, candidate / 'run.log')
        execute([executable, '--input', input_file, '--p3-lookup-directory', lookup, '--physics', physics,
                 '--dt', '4', '--intervals', '3', '--state-output', reference / 'states.bin',
                 '--output', reference / 'fields.bin'], reference, reference / 'run.log')
        checks = {'state_cache_clock_response_unchanged': compare_file(candidate / 'before.bin', candidate / 'after.bin'),
                  'frozen_writer_twelve_records': compare_file(candidate / 'expected.bin', candidate / 'actual.bin'),
                  'three_minute_states_header_and_order': compare_file(reference / 'states.bin', candidate / 'states.bin')}
        assert all(c['bitwise_identical'] for c in checks.values()), physics
        n, z, _ = np.fromfile(candidate / 'states.bin', '<i4', count=3)
        record_bytes = int(n) * int(z) * 9 * 4
        actual = (candidate / 'actual.bin').read_bytes()
        assert len(actual) == record_bytes * 12
        baseline_fields = (reference / 'fields.bin').read_bytes()
        assert len(baseline_fields) == record_bytes * 4
        assert b''.join(actual[i * record_bytes:(i + 1) * record_bytes] for i in (0, 3, 6, 9)) == baseline_fields
        assert (candidate / 'reopened.bin').read_bytes() == baseline_fields[-record_bytes:]
        assert np.isfinite(np.frombuffer(actual, '<f4')).all()
        checks.update(record_count=12, record_bytes=record_bytes, frozen_four_checkpoint_fields=True,
                      reopened_single_final_record=True, finite_real32_fields=True)
        report['checks'][physics] = checks
        write(dest / 'results.json', report)
    errors = {}
    for mode, message in (('unopened', 'Model output is not open'), ('unopened_close', 'Model output is not open'),
                          ('double_open', 'Model output is already open'), ('after_close', 'Model output is not open')):
        directory = dest / mode; directory.mkdir()
        execute([dest / 'contract.exe', input_file, lookup, 'none', mode], directory, directory / 'run.log', message)
        if mode in ('double_open', 'after_close'):
            assert (directory / 'guard.bin').stat().st_size == 0
            assert not (directory / 'other.bin').exists()
        errors[mode] = {'rejected': True, 'message': message}
    # CLI freshness and nonexistent-directory errors must preserve the old policy.
    candidate_executable = work / 'builds/production_plain/ace_model.exe'
    for label, path in (('existing_output', dest / 'preserve.bin'), ('missing_directory', dest / 'absent/fields.bin')):
        if label == 'existing_output': path.write_bytes(b'preserve existing developer data\n')
        execute([candidate_executable, '--input', input_file, '--physics', 'none', '--intervals', '1', '--output', path],
                dest, dest / (label + '.log'), 'Cannot open model output; provide an existing output directory')
        if label == 'existing_output': assert path.read_bytes() == b'preserve existing developer data\n'
        errors[label] = {'rejected': True, 'existing_data_preserved': label == 'existing_output'}
    report.update(passed=True, errors=errors, candidate_executable_sha256=sha(dest / 'contract.exe'),
                  helper_sha256=sha(dest / 'ace_module_contract.F'), driver_sha256=sha(dest / 'contract.f90'))
    write(dest / 'results.json', report)
    print('PASS model-owned output contract', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'migration_work/fortran_v020_oop_stage0')
    parser.add_argument('--lookup-directory', type=Path, default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
    args = parser.parse_args()
    run(args.work.resolve(), args.baseline.resolve(), args.lookup_directory.resolve())
