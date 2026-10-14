#!/usr/bin/env python3
"""Check first-use damping and sequential native-object isolation.

A hash-pinned frozen ImDamp is the independent oracle. Synthetic damping
fixtures and a cropped shared-input grid are lifecycle tests, not scientific
acceptance cases. Helpers modify isolated source copies only.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

import numpy as np
from netCDF4 import Dataset
from oop_regression import ROOT, BASELINE, INPUT_HASH, TABLE_HASH, sha, replace_once, write, compare_file


def cropped_fixture(source, target):
    """Preserve the lowest 201 fine levels/100 coarse layers; never edit source."""
    lengths = {'mf_level': 201, 'zc_level': 201, 'coarse_level': 100, 'basis_edge': 101}
    with Dataset(source) as original, Dataset(target, 'w', format='NETCDF4') as output:
        output.setncatts(original.__dict__)
        output.setncattr('case_name', 'oop_damping_lifecycle_crop')
        output.setncattr('basis_sha256', 'test-derived subset; see fixture inventory')
        output.setncattr('parent_input_sha256', INPUT_HASH)
        output.setncattr('test_scope', 'Lifecycle only: first 201 fine/100 coarse levels; no scientific acceptance')
        for name, dim in original.dimensions.items():
            output.createDimension(name, lengths.get(name, len(dim)))
        for name, var in original.variables.items():
            attrs = {k: v for k, v in var.__dict__.items() if k != '_FillValue'}
            options = {'fill_value': var.getncattr('_FillValue')} if '_FillValue' in var.ncattrs() else {}
            if len(var.dimensions) == 4:
                options.update(zlib=True, complevel=1, chunksizes=(1, 1, lengths['coarse_level'], lengths['basis_edge']))
            out = output.createVariable(name, var.datatype, var.dimensions, **options)
            out.setncatts(attrs)
            selection = tuple(slice(0, lengths.get(d, len(original.dimensions[d]))) for d in var.dimensions)
            if len(var.dimensions) == 4:
                # Bound memory to a response slab; preserve all horizontal ACEs.
                for i in range(len(original.dimensions['response_ace'])):
                    out[i, :, :, :] = var[(i, *selection[1:])]
            else:
                out[...] = var[selection] if selection else var[...]
    return {'sha256': sha(target), 'parent_sha256': INPUT_HASH,
            'dimensions': lengths, 'horizontal_ACE_count': 101,
            'derivation': 'Prefix slice of profiles/coarse coordinates/response operators, unchanged geometry; all other values copied.',
            'scope': 'Test-only lifecycle fixture; no physical validation of cropped response operators.'}


def run(work, baseline, lookup, contract_directory="damping_contract"):
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
    dest = work / contract_directory; dest.mkdir()
    (dest / 'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    old = subprocess.check_output(['git', 'show', BASELINE + ':fortran/src/ace_module.F'], cwd=ROOT, text=True)
    assert hashlib.sha256(old.encode()).hexdigest() == frozen['configuration']['source_sha256']['ace_module.F']
    oracle = old[old.index('subroutine ImDamp('):old.index('end subroutine ImDamp') + len('end subroutine ImDamp')]
    (dest / 'frozen_damping.txt').write_text(oracle)
    module = (source / 'ace_module.F').read_text()
    actual = module[module.index('subroutine ImDamp('):module.index('end subroutine ImDamp') + len('end subroutine ImDamp')]
    actual = actual.replace('ImDamp(damping,', 'ImDamp(').replace('type(ace_damping_t), intent(inout) :: damping\n', '')
    actual = actual.replace('integer :: i,k,n\n', 'integer :: i,k,n\nreal, dimension(:), allocatable, save :: damp\nlogical, save :: first = .True.\n')
    actual = actual.replace('damping%first', 'first').replace('damping%damp', 'damp')
    assert actual == oracle, 'Damping statements differ from frozen oracle'
    # Freeze the oracle's SAVE lifecycle independently in each fresh process.
    oracle = oracle.replace('ImDamp', 'oop_frozen_damping')
    oracle = oracle.replace('end subroutine oop_frozen_damping', 'write(77) damp\nend subroutine oop_frozen_damping')
    module = replace_once(module, 'public :: ace_t, ace_response_t',
                          'public :: ace_t, ace_response_t, oop_direct_damping, oop_check_native_pair')
    helper = '''
subroutine oop_direct_damping(mode)
character(*), intent(in) :: mode
type(ace_damping_t) :: a,b
integer :: step,nc,nz,nv,i,k,n,which,state,cache
real :: dt
real, allocatable :: X(:,:,:),Y(:,:,:),Ref(:,:),Ref_b(:,:)
! Different shapes and references make accidental sharing observable.
nc=2;nz=17;nv=3;dt=3.
allocate(X(nc+1,nz,nv),Ref(nz,8))
do k=1,nz
  Ref(k,:)=1.;Ref(k,1)=1.+real(k)/100.;Ref(k,2)=1.1+real(k)/100.
  Ref(k,3)=real(k-1)*125.
  do n=1,nv
    do i=1,nc+1
      X(i,k,n)=real(i+2*k+3*n)/7.
    enddo
  enddo
enddo
allocate(Y(4,29,3),Ref_b(29,8))
do k=1,29
  Ref_b(k,:)=1.;Ref_b(k,1)=0.8+real(k)/120.;Ref_b(k,2)=0.9+real(k)/120.
  Ref_b(k,3)=real(k-1)*175.
  do n=1,3
    do i=1,4
      Y(i,k,n)=real(2*i+k+4*n)/9.
    enddo
  enddo
enddo
if (mode=='oracle_a' .or. mode=='oracle_b') then
  open(77,file='cache.bin',access='stream',form='unformatted',status='new')
  open(newunit=state,file='state.bin',access='stream',form='unformatted',status='new')
  do step=1,5
    if (mode=='oracle_a') then
      call oop_frozen_damping(2,17,3,X,Ref,3.)
      write(state) X
    else
      call oop_frozen_damping(3,29,3,Y,Ref_b,5.)
      write(state) Y
    endif
  enddo
  close(77);close(state)
else
  open(71,file='a_cache.bin',access='stream',form='unformatted',status='new')
  open(72,file='a_state.bin',access='stream',form='unformatted',status='new')
  open(73,file='b_cache.bin',access='stream',form='unformatted',status='new')
  open(74,file='b_state.bin',access='stream',form='unformatted',status='new')
  if (.not.a%first .or. allocated(a%damp) .or. .not.b%first .or. allocated(b%damp)) error stop 'Premature damping cache'
  do step=1,5
    call ImDamp(a,2,17,3,X,Ref,3.)
    if (a%first .or. size(a%damp)/=17) error stop 'A first use'
    if (step==1 .and. (.not.b%first .or. allocated(b%damp))) error stop 'B cache polluted by A'
    write(71) a%damp;write(72) X
    call ImDamp(b,3,29,3,Y,Ref_b,5.)
    if (b%first .or. size(b%damp)/=29) error stop 'B first use'
    write(73) b%damp;write(74) Y
  enddo
  close(71);close(72);close(73);close(74)
endif
end subroutine

subroutine oop_check_native_pair(input_a,input_b,lookup,dt_a,dt_b)
character(*), intent(in) :: input_a,input_b,lookup
real, intent(in) :: dt_a,dt_b
type(ace_t) :: a,b
integer :: nc,nz,nb,nv,intervals,state_a,state_b,step
real :: dt
logical :: khn,precip
character(16) :: physics
real, allocatable :: saved_damp(:),saved_b(:,:,:)
dt=dt_a;intervals=1;physics='native'
call a%initialize(.true.,input_a,lookup,2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
open(newunit=state_a,file='a_states.bin',access='stream',form='unformatted',status='new')
write(state_a) nc,nz,nv
write(state_a) real(a%X,real64),real(a%Tv0,real64)
call a%integrate(0.)
call a%diagnose()
if (.not.a%damping%first .or. allocated(a%damping%damp)) error stop 'A allocated before first damping'
! Integrate A before initializing B; B must not disturb A's first-use cache.
call a%integrate(dt_a)
write(state_a) real(a%X,real64)
if (a%damping%first .or. size(a%damping%damp)/=a%nz) error stop 'A damping first-use timing'
saved_damp=a%damping%damp

dt=dt_b;intervals=1;physics='native'
call b%initialize(.true.,input_b,lookup,2,physics,dt,intervals,.true.,nc,nz,nb,nv,khn,precip)
if (any(saved_damp/=a%damping%damp)) error stop 'B initialization changed A cache'
open(newunit=state_b,file='b_states.bin',access='stream',form='unformatted',status='new')
write(state_b) nc,nz,nv
write(state_b) real(b%X,real64),real(b%Tv0,real64)
call b%integrate(0.)
call b%open_output('b_fields.bin')
call b%output()
if (.not.b%damping%first .or. allocated(b%damping%damp)) error stop 'B allocated before first damping'
call b%integrate(dt_b)
write(state_b) real(b%X,real64)
if (b%damping%first .or. size(b%damping%damp)/=b%nz) error stop 'B damping first-use timing'
saved_b=b%X
! Continue A through five steps, while B is idle with its own live cache.
do step=2,5
  call a%integrate(real(step)*dt_a)
  write(state_a) real(a%X,real64)
  if (any(saved_damp/=a%damping%damp)) error stop 'A cache rebuilt'
  if (any(saved_b/=b%X)) error stop 'A integration changed B state'
enddo
! Continue B after A; preserve A, and compare both trajectories to fresh processes.
do step=2,5
  call b%integrate(real(step)*dt_b)
  write(state_b) real(b%X,real64)
  if (any(saved_damp/=a%damping%damp)) error stop 'B integration changed A cache'
enddo
call b%output();call b%close_output()
close(state_a);close(state_b)
if (.not.legacy_damping%first .or. allocated(legacy_damping%damp)) error stop 'Objects used legacy damping'
if (allocated(legacy_response%PMB) .or. allocated(legacy_thermal%Ta)) error stop 'Objects used legacy context'
end subroutine
'''
    if "type :: ace_p3_t" in module:
        helper = helper.replace("if (.not.legacy_damping%first .or. allocated(legacy_damping%damp))", "if (p3_context_claimed .or. .not.a%p3%first .or. a%p3%itt/=1 .or. .not.b%p3%first .or. b%p3%itt/=1) error stop 'Native path used P3'\nif (.not.legacy_damping%first .or. allocated(legacy_damping%damp))", 1)
    module = replace_once(module, 'end module ace_module', oracle + '\n' + helper + '\nend module ace_module')
    (dest / 'ace_module_contract.F').write_text(module)
    driver = '''program contract
use ace_module, only: oop_direct_damping,oop_check_native_pair
implicit none
character(1024) :: mode,input_a,input_b,lookup,arg
real :: dt_a,dt_b
call get_command_argument(1,mode)
if (trim(mode)=='native_pair') then
  call get_command_argument(2,input_a);call get_command_argument(3,input_b)
  call get_command_argument(4,lookup)
  call get_command_argument(5,arg);read(arg,*) dt_a
  call get_command_argument(6,arg);read(arg,*) dt_b
  call oop_check_native_pair(input_a,input_b,lookup,dt_a,dt_b)
else
  call oop_direct_damping(trim(mode))
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
              'frozen_damping_sha256': sha(dest / 'frozen_damping.txt'), 'qualification_only_numerical_audit': True,
              'scope': 'Checked real64/OpenMP32; five first/subsequent calls against frozen damping, distinct shape/grid/dt contexts, two native objects vs fresh-process frozen trajectories; no P3 multi-object claim.'}
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS='32', OMP_THREAD_LIMIT='32', OMP_DYNAMIC='FALSE', OMP_STACKSIZE='64M')

    def execute(cmd, cwd, log):
        report['commands'].append({'argv': list(map(str, cmd)), 'cwd': str(cwd), 'log': str(log)})
        write(dest / 'results.json', report)
        with log.open('w') as stream:
            subprocess.run(list(map(str, cmd)), cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
        report['commands'][-1]['exit_code'] = 0

    build = work / 'builds/checked_plain'
    execute(['gfortran', *flags, *includes, '-I' + str(build), '-c', dest / 'ace_module_contract.F', '-o', 'module.o'], dest, dest / 'compile.log')
    execute(['gfortran', *flags, '-I' + str(dest), dest / 'contract.f90', 'module.o',
             *[build / (n + '.o') for n in ('ace_input', 'ace_interpolation', 'microphy_p3')],
             *libs, '-o', 'contract.exe'], dest, dest / 'link.log')
    for mode in ('oracle_a', 'oracle_b', 'pair'):
        directory = dest / mode; directory.mkdir()
        execute([dest / 'contract.exe', mode], directory, directory / 'run.log')
    for label in ('a', 'b'):
        checks = {field: compare_file(dest / ('oracle_' + label) / (field + '.bin'),
                                     dest / 'pair' / (label + '_' + field + '.bin')) for field in ('state', 'cache')}
        assert all(c['bitwise_identical'] for c in checks.values()), label
        report['checks']['direct_' + label] = checks
    print('PASS independent first/subsequent damping oracles', flush=True)
    crop = dest / 'cropped_input.nc'
    report['fixture'] = cropped_fixture(input_file, crop)
    configs = {'full_dt4': (input_file, 4), 'full_dt3': (input_file, 3), 'crop_dt3': (crop, 3)}
    for name, (fixture, dt) in configs.items():
        directory = dest / ('fresh_' + name); directory.mkdir()
        execute([executable, '--input', fixture, '--physics', 'native', '--dt', dt,
                 '--steps', '5', '--state-output', directory / 'states.bin'], directory, directory / 'run.log')
    for name, b_config in (('same_config', 'full_dt4'), ('different_dt', 'full_dt3'), ('different_grid_dt', 'crop_dt3')):
        print('Native sequential damping contract', name, flush=True)
        directory = dest / name; directory.mkdir()
        fixture, dt = configs[b_config]
        execute([dest / 'contract.exe', 'native_pair', input_file, fixture, lookup, 4, dt], directory, directory / 'run.log')
        checks = {'a': compare_file(dest / 'fresh_full_dt4/states.bin', directory / 'a_states.bin'),
                  'b': compare_file(dest / ('fresh_' + b_config) / 'states.bin', directory / 'b_states.bin')}
        assert all(c['bitwise_identical'] for c in checks.values()), name
        report['checks'][name] = checks
        write(dest / 'results.json', report)
    report.update(passed=True, candidate_executable_sha256=sha(dest / 'contract.exe'),
                  helper_sha256=sha(dest / 'ace_module_contract.F'), driver_sha256=sha(dest / 'contract.f90'))
    write(dest / 'results.json', report)
    print('PASS model-owned damping lifecycle contract', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'migration_work/fortran_v020_oop_stage0')
    parser.add_argument('--lookup-directory', type=Path, default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
    parser.add_argument('--contract-directory', default='damping_contract', help='Fresh artifact subdirectory; use a distinct name when preserving an earlier attempt')
    args = parser.parse_args()
    run(args.work.resolve(), args.baseline.resolve(), args.lookup_directory.resolve(), args.contract_directory)
