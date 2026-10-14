#!/usr/bin/env python3
"""Compare serial production/global and assumed-shape PMB kernels and checks."""
import argparse
import json
import statistics
import subprocess
from pathlib import Path

from run import ROOT, HERE, digest

VARIANTS = {
    'O2_all': ['-O2', '-fcheck=all,no-array-temps'],
    'O2_bounds': ['-O2', '-fcheck=bounds'],
    'O2_none': ['-O2'],
    'O3_all': ['-O3', '-fcheck=all,no-array-temps'],
    'O3_none': ['-O3'],
}


def run(work, repeats):
    work.mkdir(parents=True, exist_ok=False)
    # Strip ownership qualifiers only for the isolated standalone kernel.
    original = (ROOT/'fortran/src/ace_module.F').read_text().replace("response%", "")
    begin = original.index('do i=1,ncols\n  do k=1,coarse_nz+1\n    value=0.')
    end = original.index('!$omp end parallel do', begin)
    production_loop = original[begin:end]
    kernels = (HERE/'kernels.f90').read_text()
    begin = kernels.index('subroutine grouped_omp(')
    end = kernels.index('end subroutine', begin) + len('end subroutine')
    dummy = '\n'.join(line for line in kernels[begin:end].splitlines()
                      if not line.startswith('!$omp'))
    # Both methods consume the production packed forcing (level,forcing ACE).
    dummy = dummy.replace('do j=1,size(f,1)', 'do j=1,size(f,2)')
    dummy = dummy.replace('do l=1,size(f,2)', 'do l=1,size(f,1)')
    dummy = dummy.replace('*f(j,l)', '*f(l,j)')
    common = ['-ffree-form','-ffree-line-length-none','-fdefault-real-8',
              '-fdefault-double-8','-g','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
    commands, paths = [], []
    for name, flags in VARIANTS.items():
        text = f'''module kernel_{name}
use iso_fortran_env, only: real64
implicit none
integer :: coarse_nz
real*8, allocatable :: PMB(:,:,:,:), dwdt(:,:)
real, allocatable :: coarse_F(:,:)
contains
subroutine take_basis(q)
real*8, allocatable, intent(inout) :: q(:,:,:,:)
call move_alloc(q,PMB)
end subroutine
subroutine give_basis(q)
real*8, allocatable, intent(inout) :: q(:,:,:,:)
call move_alloc(PMB,q)
end subroutine
subroutine production(ncols)
integer, intent(in) :: ncols
integer :: i,j,l,k
real*8 :: partial,value
real :: packed_F(coarse_nz,ncols)
packed_F=transpose(coarse_F)
{production_loop}
end subroutine
subroutine assumed_shape(ncols)
integer, intent(in) :: ncols
real :: packed_F(coarse_nz,ncols)
packed_F=transpose(coarse_F)
call grouped_omp(PMB,packed_F,dwdt)
end subroutine
{dummy}
end module
'''
        path = work/f'{name}.f90'; path.write_text(text); paths.append(path)
        command = ['gfortran',*common,*flags,f'-fopt-info-vec-all={work/name}.vectorization.txt',
                   '-c',str(path),'-o',str(work/f'{name}.o')]
        commands.append(command)
        subprocess.run(command,cwd=work,check=True)
    uses = '\n'.join(f'use kernel_{name}, only: p{idx}=>PMB, f{idx}=>coarse_F, '
                     f'y{idx}=>dwdt, nb{idx}=>coarse_nz, '
                     f'prod{idx}=>production, dummy{idx}=>assumed_shape, '
                     f'take{idx}=>take_basis, give{idx}=>give_basis'
                     for idx,name in enumerate(VARIANTS,1))
    blocks = []
    names = list(VARIANTS)
    for idx,name in enumerate(names,1):
        blocks.append(f'''call take{idx}(packed)
nb{idx}=nb
allocate(f{idx}(nc,nb),y{idx}(nc,nb+1))
do forcing=1,2
  f{idx}=forces(:,:,forcing)
  do method=1,2
    do repeat=0,repeats
      call system_clock(tick,rate)
      if (method==1) then
        call prod{idx}(nc)
      else
        call dummy{idx}(nc)
      endif
      call system_clock(finish)
      elapsed=real(finish-tick,real64)/real(rate,real64)
      if ({idx}==1.and.method==1.and.repeat==0) reference(:,:,forcing)=y{idx}
      if (any(y{idx}/=reference(:,:,forcing))) error stop 'Reduction output changed'
      if (.not.all(ieee_is_finite(y{idx}))) error stop 'Nonfinite output'
      if (repeat>0) write(*,*) 'RESULT','{name}',method,forcing,repeat,elapsed
      write(filename,'(a,a,i0,a,i0,a,i0,a)') '{name}', '_method',method, '_forcing',forcing,'_rep',repeat,'.bin'
      open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='new')
      write(u) y{idx}
      close(u)
    enddo
  enddo
enddo
deallocate(f{idx},y{idx})
call give{idx}(packed)
''')
    # List-directed character outputs need a delimiter between RESULT and variant.
    blocks = [block.replace("'RESULT','", "'RESULT ','") for block in blocks]
    harness = f'''program benchmark
{uses}
use ace_input, only: read_case_metadata, read_case_basis
use iso_fortran_env, only: real64,int64
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
integer :: nc,nz,nb,u,i,k,forcing,method,repeat,header(2),repeats
integer(int64) :: tick,finish,rate
real(real64) :: elapsed
real(real64), allocatable :: input_p(:,:,:,:),packed(:,:,:,:),forces(:,:,:),reference(:,:,:)
character(1024) :: input_file,forcing_file,filename,arg
character(64) :: geometry
call get_command_argument(1,input_file)
call get_command_argument(2,forcing_file)
call get_command_argument(3,arg); read(arg,*) repeats
call read_case_metadata(trim(input_file),nz,nc,nb,geometry)
allocate(input_p(nc,nc,nb,nb+1),packed(nb,nc,nb+1,nc))
call read_case_basis(trim(input_file),'PMB',input_p)
do i=1,nc
  do k=1,nb+1
    packed(:,:,k,i)=transpose(input_p(i,:,:,k))
  enddo
enddo
deallocate(input_p)
allocate(forces(nc,nb,2),reference(nc,nb+1,2))
do forcing=1,2
  filename=forcing_file
  if (forcing==2) filename=trim(forcing_file)//'/../forcing_stress.bin'
  open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='old')
  read(u) header
  if (any(header/=[nc,nb])) error stop 'Forcing shape mismatch'
  read(u) forces(:,:,forcing)
  close(u)
enddo
{''.join(blocks)}
end program
'''
    # A file path cannot serve as a directory when resolving the stress file.
    force_root = ROOT/'migration_work/khn26_basis_layout_full'
    harness = harness.replace("trim(forcing_file)//'/../forcing_stress.bin'",
                              f"'{force_root/'forcing_stress.bin'}'")
    path = work/'benchmark.f90'; path.write_text(harness); paths.append(path)
    inc = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    base = ROOT/'migration_work/khn26_single_3h/build64'
    (work/'ace_input.mod').write_bytes((base/'ace_input.mod').read_bytes())
    command = ['gfortran',*common,'-O2','-fcheck=all,no-array-temps',*inc,str(path),
               *[str(work/f'{name}.o') for name in VARIANTS],str(base/'ace_input.o'),
               *libs,'-o',str(work/'benchmark.exe')]
    commands.append(command); subprocess.run(command,cwd=work,check=True)
    input_file = ROOT/'data/input/manaus1342_khn26.nc'
    forcing_files = [force_root/name for name in ('forcing.bin','forcing_stress.bin')]
    provenance = {str(p):digest(p) for p in [ROOT/'fortran/src/ace_module.F',HERE/'kernels.f90',
                    Path(__file__).resolve(),input_file,*forcing_files,*paths,base/'ace_input.o']}
    command = [str(work/'benchmark.exe'),str(input_file),str(forcing_files[0]),str(repeats)]
    commands.append(command)
    print('Running serial same-memory compiler comparisons',flush=True)
    with (work/'benchmark.log').open('w') as stream:
        subprocess.run(command,cwd=work,stdout=stream,stderr=subprocess.STDOUT,check=True)
    rows = []
    for line in (work/'benchmark.log').read_text().splitlines():
        if not line.strip().startswith('RESULT'): continue
        _,name,method,forcing,repeat,seconds = line.split()
        rows.append({'variant':name,'method':int(method),'forcing':int(forcing),
                     'repeat':int(repeat),'wall_seconds':float(seconds)})
    summary = []
    for name in VARIANTS:
        for method in (1,2):
            for forcing in (1,2):
                times = [r['wall_seconds'] for r in rows if
                         (r['variant'],r['method'],r['forcing'])==(name,method,forcing)]
                if len(times)!=repeats: raise ValueError('Incomplete timing records')
                files = list(work.glob(f'{name}_method{method}_forcing{forcing}_rep*.bin'))
                hashes = {digest(p) for p in files}
                ref = work/f'O2_all_method1_forcing{forcing}_rep0.bin'
                if hashes != {digest(ref)}: raise ValueError('Binary identity failed')
                legacy = force_root/f'checked_threads1/case{forcing}_responses101_legacy.bin'
                if digest(ref)!=digest(legacy): raise ValueError('Frozen legacy agreement failed')
                summary.append({'variant':name,'method':'production_globals' if method==1 else 'assumed_shape',
                                'forcing':forcing,'median_seconds':statistics.median(times),
                                'min_seconds':min(times),'max_seconds':max(times),
                                'binary_identical_to_frozen_legacy':True})
    for name,expected in provenance.items():
        if digest(name)!=expected: raise ValueError('Provenance changed: '+name)
    report = {'summary':summary,'raw_times':rows,'commands':commands,'sha256':provenance,
              'compiler':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
              'repeats':repeats,'warmups_per_configuration':1,'openmp':False,'fast_math':False,
              'basis_allocation_policy':'Pack once, move the same allocation between modules; no copying between variants.',
              'limits':'Isolated contraction only; production loop extracted verbatim, global arrays retained. '
                       'Shared host and concurrent serial trajectory; timings exclude basis I/O/packing. '
                       'No full-model or alternative-build trajectory acceptance.'}
    (work/'compiler_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path);parser.add_argument('--repeats',type=int,default=3)
    args=parser.parse_args()
    if args.repeats<1: parser.error('--repeats must be positive')
    run(args.work.resolve(),args.repeats)
