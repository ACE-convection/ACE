#!/usr/bin/env python3
"""Run an isolated real-basis PMB layout experiment; no model sources edited."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

import numpy as np
from netCDF4 import Dataset

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent


def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(8*1024*1024),b''):h.update(block)
    return h.hexdigest()


def execute(command,work,log,env=None):
    with (work/log).open('w') as stream:
        subprocess.run([str(x) for x in command],cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT,check=True)


def prepare(work,seed):
    work.mkdir(parents=True,exist_ok=False)
    input_file=ROOT/'data/input/manaus1342_khn26.nc'
    base=ROOT/'migration_work/khn26_single_3h/build64'
    module=(ROOT/'fortran/src/ace_module.F').read_text()
    module=module.replace('! defien operator','public :: ace_tendency, capture_coarse_forcing\n\n! defien operator',1)
    module=module.replace('\ncontains\n\nsubroutine ace_driver', '''
contains
subroutine capture_coarse_forcing(unit)
integer, intent(in) :: unit
write(unit) legacy_response%coarse_F
end subroutine capture_coarse_forcing

subroutine ace_driver''',1)
    (work/'ace_module_capture.F').write_text(module)
    include=subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs=subprocess.check_output(['nf-config','--flibs'],text=True).split()
    libdir=Path(subprocess.check_output(['nf-config','--prefix'],text=True).strip())/'lib'
    checked=['-O2','-g','-fcheck=all,no-array-temps','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
    common=['-ffree-form','-ffree-line-length-none','-fdefault-real-8','-fdefault-double-8']
    commands=[]
    build=work/'capture_build';build.mkdir()
    for name in ('ace_input','ace_interpolation','microphy_p3'):
        for suffix in ('.mod','.o'):(build/(name+suffix)).write_bytes((base/(name+suffix)).read_bytes())
    command=['gfortran',*common,*checked,*include,'-c',work/'ace_module_capture.F','-o','ace_module.o']
    commands.append(command);execute(command,build,'module.log')
    command=['gfortran',*common,*checked,*include,HERE/'capture.f90','ace_module.o',
             'ace_input.o','ace_interpolation.o','microphy_p3.o',*libs,'-o','capture.exe']
    commands.append(command);execute(command,build,'link.log')
    command=[build/'capture.exe',input_file,seed,work/'forcing.bin']
    commands.append(command);execute(command,work,'capture.log')
    with (work/'forcing.bin').open('rb') as stream:
        nc,nb=np.fromfile(stream,'<i4',2)
    j,l=np.meshgrid(np.arange(1,nc+1),np.arange(1,nb+1),indexing='ij')
    stress=1e-3*(np.sin(j/7)*np.cos(l/11)+0.2*(-1.)**(j+l))
    with (work/'forcing_stress.bin').open('wb') as stream:
        np.asarray([nc,nb],dtype='<i4').tofile(stream)
        stress.flatten(order='F').astype('<f8').tofile(stream)
    for label,flags in [('checked',checked),('optimized',['-O3'])]:
        build=work/label;build.mkdir()
        (build/'ace_input.mod').write_bytes((base/'ace_input.mod').read_bytes())
        command=['gfortran',*common,*flags,'-fopenmp',*include,HERE/'kernels.f90',HERE/'benchmark.f90',
                 base/'ace_input.o',*libs,f'-L{libdir}',f'-Wl,-rpath,{libdir}','-lblas','-o','benchmark.exe']
        commands.append(command);execute(command,build,'compile.log')
    (work/'configuration.json').write_text(json.dumps({
        'baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'input':str(input_file),'input_sha256':digest(input_file),
        'seed':str(seed),'seed_sha256':digest(seed),
        'source_sha256':{str(p.relative_to(ROOT)):digest(p) for p in
                         [ROOT/'fortran/src/ace_module.F',ROOT/'fortran/src/ace_input.F',
                          *sorted(p for p in HERE.glob('*.*') if p.suffix in ('.py','.m','.f90'))]},
        'reused_object_sha256':{str(p):digest(p) for p in base.glob('*.o')},
        'compiler':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],
        'commands':[[str(x) for x in c] for c in commands],
        'blas_library':str((libdir/'libblas.so').resolve()),
        'scope':'Kernel experiment only; forcing snapshot includes all columns and comes from production initial-state tendency.'
    },indent=2)+'\n')


def fortran(work,repeats):
    config=json.loads((work/'configuration.json').read_text())
    env=os.environ.copy();env.update(OPENBLAS_NUM_THREADS='1',OMP_PROC_BIND='close',OMP_PLACES='cores')
    for label,threads,only in [('checked',1,False),('optimized',1,False),('optimized',4,True),('optimized',8,True)]:
        out=work/f'{label}_threads{threads}';out.mkdir()
        cmd=[work/label/'benchmark.exe',config['input'],work/'forcing.bin',out,str(repeats),str(threads)]
        if only:cmd.append('omp-only')
        execute(cmd,work,f'{out.name}.log',env)


def compare(work):
    config=json.loads((work/'configuration.json').read_text())
    with Dataset(config['input']) as ds:
        nc=len(ds.dimensions['response_ace']);nb=len(ds.dimensions['coarse_level']);ne=nb+1
    results=[];overheads={}
    for logfile in sorted(work.glob('*_threads*.log')):
        for line in logfile.read_text().splitlines():
            if line.startswith(('basis_read_seconds,','packing_seconds,')):
                key,value=line.split(',');overheads.setdefault(logfile.stem,{})[key]=float(value)
            if ',seconds=' not in line:continue
            method,*parts=line.split(',');row={'build':logfile.stem,'method':method}
            for part in parts:
                key,value=part.split('=')
                if key=='method':key='method_id'
                row[key]=value.strip()
            for key in ('kind','responses','threads','rep'):row[key]=int(row[key])
            for key in ('seconds','max_abs_error','scaled_error'):row[key]=float(row[key])
            row['exact']=row['exact']=='T';results.append(row)
    summary=[]
    for group in sorted(set((r['build'],r['method'],r['kind'],r['responses']) for r in results)):
        entries=[r for r in results if (r['build'],r['method'],r['kind'],r['responses'])==group]
        artifact=work/group[0]/f'case{group[2]}_responses{group[3]}_{group[1]}.bin'
        baseline_build='optimized_threads1' if group[0].startswith('optimized') else 'checked_threads1'
        baseline=work/baseline_build/f'case{group[2]}_responses{group[3]}_legacy.bin'
        summary.append({'build':group[0],'method':group[1],'kind':group[2],'responses':group[3],
                        'median_seconds':float(np.median([r['seconds'] for r in entries])),
                        'min_seconds':min(r['seconds'] for r in entries),
                        'max_seconds':max(r['seconds'] for r in entries),
                        'max_absolute_error':max(r['max_abs_error'] for r in entries),
                        'max_scaled_error':max(r['scaled_error'] for r in entries),
                        'all_exact_to_legacy':all(r['exact'] for r in entries),
                        'binary_identical_to_legacy':digest(artifact)==digest(baseline)})
    checks=[]
    with Dataset(config['input']) as ds:
        for kind in (1,2):
            if kind==1:
                with (work/'forcing.bin').open('rb') as stream:
                    header=np.fromfile(stream,'<i4',2);assert np.array_equal(header,[nc,nb])
                    forcing=np.fromfile(stream,'<f8').reshape((nc,nb),order='F')
            else:
                with (work/'forcing_stress.bin').open('rb') as stream:
                    header=np.fromfile(stream,'<i4',2);assert np.array_equal(header,[nc,nb])
                    forcing=np.fromfile(stream,'<f8').reshape((nc,nb),order='F')
            for responses in (nc,1):
                oracle=np.fromfile(work/f'matlab_case{kind}_responses{responses}_original.bin','<f8').reshape((responses,ne),order='F')
                matrix_result=np.fromfile(work/f'matlab_case{kind}_responses{responses}_matrix.bin','<f8').reshape((responses,ne),order='F')
                primary_bound=np.fromfile(work/'checked_threads1'/f'case{kind}_responses{responses}_bound.bin','<f8').reshape((responses,ne),order='F')
                if np.any(abs(matrix_result-oracle)>2*primary_bound):
                    raise ValueError('MATLAB matrix reduction exceeds cross-reference bound')
                checks.append({'path':f'matlab_case{kind}_responses{responses}_matrix.bin',
                               'max_abs_vs_matlab':float(np.max(abs(matrix_result-oracle)))})
                for path in sorted(work.glob(f'*_threads*/case{kind}_responses{responses}_*.bin')):
                    if path.stem.endswith('_bound'):continue
                    y=np.fromfile(path,'<f8').reshape((responses,ne),order='F')
                    if not np.isfinite(y).all():raise ValueError(f'Nonfinite result: {path}')
                    bound=np.fromfile(path.parent/f'case{kind}_responses{responses}_bound.bin','<f8').reshape((responses,ne),order='F')
                    if np.any(abs(y-oracle)>2*bound):raise ValueError(f'Cross-MATLAB roundoff bound exceeded: {path}')
                    checks.append({'path':str(path.relative_to(work)),'max_abs_vs_matlab':float(np.max(abs(y-oracle))),
                                   'binary_identical_to_matlab':digest(path)==digest(work/f'matlab_case{kind}_responses{responses}_original.bin')})
                # Independent extended-precision spot checks using explicit NetCDF index order.
                for i,k in sorted(set([(0,0),(0,ne//2),(0,ne-1),(responses-1,ne//2)])):
                    coeff=np.asarray(ds['PMB'][i,:,:,k]);terms=coeff.astype(np.longdouble)*forcing.astype(np.longdouble)
                    extended=float(np.sum(terms,dtype=np.longdouble));abs_sum=float(np.sum(abs(terms),dtype=np.longdouble))
                    bound=max(np.finfo(float).tiny,128*np.finfo(float).eps*abs_sum)
                    if abs(oracle[i,k]-extended)>bound:raise ValueError('MATLAB outside independent roundoff bound')
                    for path in work.glob(f'*_threads*/case{kind}_responses{responses}_*.bin'):
                        if path.stem.endswith('_bound'):continue
                        y=np.fromfile(path,'<f8').reshape((responses,ne),order='F')
                        if abs(y[i,k]-extended)>bound:raise ValueError(f'Independent spot check failed: {path}')
    report={'configuration':config,'basis_shape_fortran':[nc,nc,nb,ne],
            'timing_summary':summary,'cross_matlab_checks':checks,
            'one_time_costs':overheads,'basis_bytes':nc*nc*nb*ne*8,
            'packed_peak_basis_bytes':2*nc*nc*nb*ne*8,
            'analysis_source_sha256':digest(Path(__file__)),
            'thread_configuration':{'OPENBLAS_NUM_THREADS':'1','OMP_PROC_BIND':'close','OMP_PLACES':'cores',
                                    'openmp_threads_requested':[1,4,8]},
            'longdouble_precision_bits':int(np.finfo(np.longdouble).nmant),
            'matlab':json.loads((work/'matlab_results.json').read_text()),
            'forcing_sha256':{name:digest(work/name) for name in ('forcing.bin','forcing_stress.bin')},
            'roundoff_test':'128*eps*sum(abs(P*F)), each Fortran output; independent longdouble corner/interior spots.',
            'limits':'Shared-host wall times, not isolated hardware. Kernel agreement does not certify a full model trajectory. BLAS/dot may reorder reductions.'}
    (work/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--prepare',action='store_true');parser.add_argument('--fortran',action='store_true')
    parser.add_argument('--compare',action='store_true');parser.add_argument('--repeats',type=int,default=3)
    parser.add_argument('--seed',type=Path,default=ROOT/'migration_work/khn26_single_3h/smoke_fortran_states.bin')
    args=parser.parse_args();work=args.work.resolve()
    if args.repeats<1:parser.error('repeats must be positive')
    if args.prepare:prepare(work,args.seed.resolve())
    if args.fortran:fortran(work,args.repeats)
    if args.compare:compare(work)
