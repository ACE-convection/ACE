#!/usr/bin/env python3
"""Controlled serial PMB compiler/independent-output SIMD and read tests."""
import argparse
import json
import os
import statistics
import subprocess
from pathlib import Path

from run import ROOT, HERE, digest

VARIANTS = {
    'O2': (['-O2'], 1),
    'O3_generic': (['-O3', '-ffp-contract=off'], 1),
    'O3_native': (['-O3', '-march=native', '-ffp-contract=off'], 1),
    'O3_native_scalar': (['-O3', '-march=native', '-ffp-contract=off',
                          '-fno-tree-vectorize'], 1),
    'outputs4': (['-O3', '-march=native', '-ffp-contract=off'], 4),
    'outputs8': (['-O3', '-march=native', '-ffp-contract=off'], 8),
    'outputs4_scalar': (['-O3', '-march=native', '-ffp-contract=off',
                         '-fno-tree-vectorize'], 4),
    'outputs8_scalar': (['-O3', '-march=native', '-ffp-contract=off',
                         '-fno-tree-vectorize'], 8),
    'read8': (['-O3', '-march=native', '-ffp-contract=off'], 0),
}


def kernel(original, width):
    if width == 1:
        return original, 'real*8 :: partial,value'
    if width == 0:
        # Diagnostic read only, independent checksum chains; not a PMB response.
        updates = '\n'.join(f's{a}=s{a}+PMB(l+{a-1},j,k,i)' for a in range(1,9))
        code = '\n'.join(f's{a}=0.' for a in range(1,9))
        code += f'''\ndo i=1,ncols
do k=1,coarse_nz+1
do j=1,ncols
do l=1,coarse_nz-7,8
{updates}
enddo
do l=coarse_nz-mod(coarse_nz,8)+1,coarse_nz
s1=s1+PMB(l,j,k,i)
enddo
enddo
enddo
enddo
dwdt=0.
dwdt(1,1)={'+'.join(f's{a}' for a in range(1,9))}
'''
        return code, 'real*8 :: '+','.join(f's{a}' for a in range(1,9))
    zero_v = '\n'.join(f'v{a}=0.' for a in range(1,width+1))
    zero_p = '\n'.join(f'p{a}=0.' for a in range(1,width+1))
    updates = '\n'.join(f'p{a}=p{a}+PMB(l,j,k+{a-1},i)*packed_F(l,j)'
                        for a in range(1,width+1))
    additions = '\n'.join(f'v{a}=v{a}+p{a}' for a in range(1,width+1))
    stores = '\n'.join(f'dwdt(i,k+{a-1})=v{a}' for a in range(1,width+1))
    # Each independent output retains l-then-j reduction order and rounding.
    remainder = original[original.index('    value=0.'):original.rindex('enddo')]
    remainder = remainder[:remainder.rindex('enddo')]
    code = f'''do i=1,ncols
do k=1,coarse_nz+2-{width},{width}
{zero_v}
do j=1,ncols
{zero_p}
do l=1,coarse_nz
{updates}
enddo
{additions}
enddo
{stores}
enddo
do k=((coarse_nz+1)/{width})*{width}+1,coarse_nz+1
{remainder}
enddo
enddo
'''
    decl = 'real*8 :: partial,value,'+','.join(f'{t}{a}' for t in ('p','v')
                                              for a in range(1,width+1))
    return code, decl


def run(work, repeats, cpu):
    work.mkdir(parents=True, exist_ok=False)
    (work/'analyze_serial_simd.py').write_bytes(Path(__file__).read_bytes())
    source = ROOT/'fortran/src/ace_module.F'
    original = source.read_text()
    start = original.index('do i=1,ncols\n  do k=1,coarse_nz+1\n    value=0.')
    loop = original[start:original.index('!$omp end parallel do', start)]
    common = ['-ffree-form','-ffree-line-length-none','-fdefault-real-8',
              '-fdefault-double-8']
    commands, files, uses, cases = [], [], [], []
    for idx,(name,(flags,width)) in enumerate(VARIANTS.items(),1):
        code, decl = kernel(loop,width)
        path = work/f'{name}.f90'
        path.write_text(f'''module kernel_{name}
implicit none
integer :: coarse_nz
real*8, allocatable :: PMB(:,:,:,:),dwdt(:,:),coarse_F(:,:)
contains
subroutine execute(ncols)
integer, intent(in) :: ncols
integer :: i,j,k,l
{decl}
real*8 :: packed_F(coarse_nz,ncols)
packed_F=transpose(coarse_F)
{code}
end subroutine
end module
''')
        cmd = ['gfortran',*common,*flags,
               f'-fopt-info-vec-all={work/name}.vectorization.txt',
               '-c',str(path),'-o',str(work/f'{name}.o')]
        commands.append(cmd); subprocess.run(cmd,cwd=work,check=True)
        cmd = ['objdump','-d',str(work/f'{name}.o')]
        commands.append(cmd)
        (work/f'{name}.assembly.txt').write_text(subprocess.check_output(cmd,text=True))
        files.append(path)
        uses.append(f'use kernel_{name}, only: p{idx}=>PMB,y{idx}=>dwdt,f{idx}=>coarse_F, '
                    f'nb{idx}=>coarse_nz,run{idx}=>execute')
        cases.append(f'''case({idx})
call move_alloc(packed,p{idx})
nb{idx}=nb
allocate(y{idx}(nc,nb+1),f{idx}(nc,nb))
f{idx}=forces(:,:,forcing)
call system_clock(tick,rate)
call cpu_time(cpu_start)
call run{idx}(nc)
call cpu_time(cpu_finish)
call system_clock(finish)
elapsed=real(finish-tick,real64)/real(rate,real64)
if (.not.all(ieee_is_finite(y{idx}))) error stop 'Nonfinite output'
write(*,*) 'RESULT ',variant,forcing,repeat,elapsed,cpu_finish-cpu_start,y{idx}(1,1)
write(filename,'(a,i0,a,i0,a,i0,a)') 'variant',variant,'_forcing',forcing,'_rep',repeat,'.bin'
open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='new')
write(u) y{idx}
close(u)
deallocate(y{idx},f{idx})
call move_alloc(p{idx},packed)
''')
    force_root = ROOT/'migration_work/khn26_basis_layout_full'
    harness = work/'benchmark.f90'
    harness.write_text(f'''program benchmark
{chr(10).join(uses)}
use ace_input, only: read_case_metadata,read_case_basis
use iso_fortran_env, only: real64,int64
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
integer :: nc,nz,nb,u,i,k,forcing,repeat,variant,position,header(2)
integer(int64) :: tick,finish,rate
real(real64) :: elapsed,cpu_start,cpu_finish
real(real64), allocatable :: input_p(:,:,:,:),packed(:,:,:,:),forces(:,:,:)
character(1024) :: filename
character(64) :: geometry
call read_case_metadata('{ROOT/'data/input/manaus1342_khn26.nc'}',nz,nc,nb,geometry)
allocate(input_p(nc,nc,nb,nb+1),packed(nb,nc,nb+1,nc))
call read_case_basis('{ROOT/'data/input/manaus1342_khn26.nc'}','PMB',input_p)
do i=1,nc
do k=1,nb+1
packed(:,:,k,i)=transpose(input_p(i,:,:,k))
enddo
enddo
deallocate(input_p)
allocate(forces(nc,nb,2))
do forcing=1,2
if(forcing==1) then
filename='{force_root/'forcing.bin'}'
else
filename='{force_root/'forcing_stress.bin'}'
endif
open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='old')
read(u) header
if(any(header/=[nc,nb])) error stop 'Forcing shape mismatch'
read(u) forces(:,:,forcing)
close(u)
enddo
do repeat=0,{repeats}
do forcing=1,2
do position=1,{len(VARIANTS)}
variant=position
if(mod(repeat,2)==1) variant={len(VARIANTS)+1}-position
select case(variant)
{chr(10).join(cases)}
end select
enddo
enddo
enddo
end program
''')
    files.append(harness)
    base = ROOT/'migration_work/khn26_single_3h/build64'
    (work/'ace_input.mod').write_bytes((base/'ace_input.mod').read_bytes())
    inc = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    cmd = ['gfortran',*common,'-O2',*inc,str(harness),
           *[str(work/f'{name}.o') for name in VARIANTS],str(base/'ace_input.o'),
           *libs,'-o',str(work/'benchmark.exe')]
    commands.append(cmd); subprocess.run(cmd,cwd=work,check=True)
    provenance = {str(p):digest(p) for p in [source,Path(__file__).resolve(),*files,
        ROOT/'data/input/manaus1342_khn26.nc',base/'ace_input.o',
        force_root/'forcing.bin',force_root/'forcing_stress.bin',
        *[force_root/f'checked_threads1/case{f}_responses101_legacy.bin' for f in (1,2)]]}
    cmd = ['taskset','-c',str(cpu),str(work/'benchmark.exe')]
    commands.append(cmd)
    print(f'Running {repeats} interleaved rounds, serial CPU {cpu}',flush=True)
    with (work/'benchmark.log').open('w') as out:
        subprocess.run(cmd,cwd=work,stdout=out,stderr=subprocess.STDOUT,check=True)
    rows=[]
    names=list(VARIANTS)
    for line in (work/'benchmark.log').read_text().splitlines():
        if not line.strip().startswith('RESULT'): continue
        _,idx,forcing,repeat,wall,cpu_seconds,checksum=line.split()
        name=names[int(idx)-1]; forcing=int(forcing); repeat=int(repeat)
        result=work/f'variant{idx}_forcing{forcing}_rep{repeat}.bin'
        if name!='read8' and digest(result)!=digest(force_root/
                f'checked_threads1/case{forcing}_responses101_legacy.bin'):
            raise ValueError(f'Binary identity failed: {result}')
        rows.append(dict(variant=name,forcing=forcing,repeat=repeat,
                         wall_seconds=float(wall),cpu_seconds=float(cpu_seconds),
                         checksum=float(checksum)))
    summary=[]
    basis_bytes=200*101*201*101*8
    for name in VARIANTS:
        for forcing in (1,2):
            times=[r['wall_seconds'] for r in rows if r['variant']==name and
                   r['forcing']==forcing and r['repeat']>0]
            if len(times)!=repeats: raise ValueError('Incomplete records')
            median=statistics.median(times)
            summary.append(dict(variant=name,forcing=forcing,median_seconds=median,
                mean_seconds=statistics.mean(times),min_seconds=min(times),
                max_seconds=max(times),effective_basis_GB_per_second=basis_bytes/median/1e9,
                binary_identical_to_frozen_legacy=True if name!='read8' else None))
    for path,expected in provenance.items():
        if digest(path)!=expected: raise ValueError('Provenance changed: '+path)
    report=dict(summary=summary,raw_times=rows,commands=commands,sha256=provenance,
        compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
        cpu_info=subprocess.check_output(['lscpu'],text=True),affinity_cpu=cpu,
        originally_allowed_cpus=sorted(os.sched_getaffinity(0)),repeats=repeats,
        warmup_rounds=1,basis_bytes=basis_bytes,openmp=False,fast_math=False,
        fma_contraction=False,production_source_modified=False,
        allocation_policy='One shared PMB allocation; pinned first-touch/read/packing and execution; move_alloc between kernels.',
        order='Forward on even rounds, reverse on odd rounds; both forcings every round.',
        limits='Kernel-only, shared host; pinned CPU differs from unpinned full-model runs. '
               'Effective bytes/time is not hardware-measured DRAM bandwidth. read8 has no forcing '
               'multiplication and uses independent checksum chains; it is not a scientific response '
               'or hardware memory-bandwidth ceiling. No full-model candidate acceptance.')
    (work/'serial_simd_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--repeats',type=int,default=5)
    parser.add_argument('--cpu',type=int,default=min(os.sched_getaffinity(0)))
    args=parser.parse_args()
    if args.repeats<1 or args.cpu not in os.sched_getaffinity(0):
        parser.error('Need positive repeats and an allowed CPU')
    run(args.work.resolve(),args.repeats,args.cpu)
