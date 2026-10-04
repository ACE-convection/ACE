#!/usr/bin/env python3
"""Compare production interp1 (PCHIP/MAKIMA) with MATLAB in double precision."""
import argparse
import hashlib
import json
import pathlib
import shlex
import shutil
import struct
import subprocess
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / 'fortran/src/ace_interpolation.F'


def fixtures():
    rng = np.random.default_rng(20261004)
    cases = []
    def add(name, x, y):
        x = np.asarray(x, dtype=np.float64)
        y = np.asarray(y, dtype=np.float64)
        q = np.concatenate([x, (x[:-1]+x[1:])/2,
            rng.uniform(x[0], x[-1], 57),
            [x[0]-.4*(x[1]-x[0]), x[-1]+.4*(x[-1]-x[-2])]])
        rng.shuffle(q)  # Unsorted queries and repeated knot queries are valid.
        cases.append((name, x, y, q))
    add('two_points', [0, 3], [2, -4])
    add('constant', np.arange(12)*200., np.full(12, 3.25))
    add('zero', np.arange(12)*200., np.zeros(12))
    add('linear_nonuniform', [0, .5, 2, 5, 9, 13], np.array([0, .5, 2, 5, 9, 13])*1.5-2)
    add('plateaus', np.arange(12), [-1,-1,-1,0,1,1,1,1,1,1.5,1.5,1])
    add('sign_changes', np.arange(9), [0,1,-1,0,2,-2,1,-1,0])
    add('three_points', [0,2,7], [1,0,3])
    add('large_coordinate_offset', 1e6+np.arange(15)*.25, np.sin(np.arange(15)))
    x = np.arange(201)*200.
    add('ace_200m_edges', x, 1e-3*np.sin(x/3000.)+2e-4*np.cos(x/700.))
    for n in [4,5,12,201]:
        for scale in [1e-6,1.,1e6]:
            x = np.concatenate([[0.],np.cumsum(rng.uniform(.2,3.,n-1))])
            add(f'random_{n}_{scale:g}', x, rng.normal(size=n)*scale)
    return cases


METHODS = ('pchip','makima')
POLICIES = ('extrap','endpoint','default')


def prepare(directory):
    directory.mkdir(parents=True, exist_ok=False)
    paths = []
    for name, x, y, q in fixtures():
        file = directory / (name+'.input')
        file.write_bytes(struct.pack('<ii',len(x),len(q)) +
            x.astype('<f8').tobytes()+y.astype('<f8').tobytes()+q.astype('<f8').tobytes())
        paths.append(file)
    compiler = shutil.which('gfortran')
    if not compiler:
        raise RuntimeError('gfortran is required')
    for kind in [32,64]:
        build = directory / f'build{kind}'
        build.mkdir()
        flags = ['-cpp','-ffree-form','-O0','-g','-fcheck=all','-ffpe-trap=invalid,zero,overflow']
        if kind == 64:
            flags += ['-fdefault-real-8','-fdefault-double-8']
        command = [compiler,*flags,str(SOURCE),str(HERE/'probe.f90'),'-o',str(build/'probe')]
        completed = subprocess.run(command,cwd=build,capture_output=True,text=True,check=True)
        (build/'compile.log').write_text(shlex.join(command)+'\n'+completed.stdout+completed.stderr)
        if kind==32:
            continue  # Only compile compatibility is required for single precision.
        for file in paths:
            for method in METHODS:
                for policy in POLICIES:
                    output=file.with_suffix(f'.fortran_{method}_{policy}')
                    subprocess.run([str(build/'probe'),str(file),str(output),method,policy],
                        cwd=build,capture_output=True,text=True,check=True)
        for name,x in [('one_node',[0.]),('repeated',[0.,1.,1.]),('decreasing',[0.,2.,1.])]:
            file=build/(name+'.bad')
            file.write_bytes(struct.pack('<ii',len(x),1)+np.array(x,dtype='<f8').tobytes()+
                np.zeros(len(x),dtype='<f8').tobytes()+np.zeros(1,dtype='<f8').tobytes())
            for method in METHODS:
                result=subprocess.run([str(build/'probe'),str(file),str(build/'rejected.bin'),method,'extrap'],
                    capture_output=True,text=True)
                expected='at least two' if name=='one_node' else 'increasing coordinates'
                if result.returncode==0 or expected not in result.stdout+result.stderr:
                    raise AssertionError(f'Invalid grid was not rejected: {method}/{name}')
                (build/(method+'_'+name+'.log')).write_text(result.stdout+result.stderr)
        result=subprocess.run([str(build/'probe'),str(paths[0]),str(build/'rejected.bin'),'linear','extrap'],
            capture_output=True,text=True)
        if result.returncode==0 or 'only pchip and makima' not in result.stdout+result.stderr:
            raise AssertionError('Unsupported interpolation method was not rejected')
        (build/'unsupported_method.log').write_text(result.stdout+result.stderr)
    metadata={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'compiler':subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
        'cases':len(paths),'seed':20261004,'required_precision':'real64',
        'real32_check':'compile only','invalid_grid_checks':6,'unsupported_method_checks':1}
    (directory/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(f'Prepared {len(paths)} cases; real64 interp1 executed for two methods and three policies; real32 compiled')


def compare(directory):
    metadata=json.loads((directory/'metadata.json').read_text())
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest()!=metadata['source_sha256']:
        raise RuntimeError('Production source changed since preparation')
    files=sorted(directory.glob('*.input'))
    if len(files)!=metadata['cases']:
        raise AssertionError('Fixture count differs from preparation metadata')
    rows=[]
    tolerance=128*np.finfo(np.float64).eps
    for file in files:
        n,nq=struct.unpack('<ii',file.read_bytes()[:8])
        source=np.frombuffer(file.read_bytes()[8:],dtype='<f8')
        x=source[:n]; y=source[n:2*n]; q=source[2*n:]
        row={'case':file.stem,'nodes':n,'queries':nq,'comparisons':{}}
        for method in METHODS:
            for policy in POLICIES:
                reference_policy='extrap' if policy=='default' else policy
                actual=np.fromfile(file.with_suffix(f'.fortran_{method}_{policy}'),dtype='<f8')
                expected=np.fromfile(file.with_suffix(f'.matlab_{method}_{reference_policy}'),dtype='<f8')
                if actual.size!=nq or expected.size!=nq or not np.all(np.isfinite(actual)) or not np.all(np.isfinite(expected)):
                    raise AssertionError(f'Missing/nonfinite result: {file.stem}/{method}/{policy}')
                scale=max(float(np.max(np.abs(expected))),float(np.max(np.abs(y))),np.finfo(float).tiny)
                absolute=float(np.max(np.abs(actual-expected)))
                scaled=absolute/scale
                row['comparisons'][method+'_'+policy]={'max_absolute_error':absolute,
                    'max_amplitude_scaled_error':scaled,'tolerance':float(tolerance),'passed':bool(scaled<=tolerance)}
                if policy=='endpoint':
                    outside=(q<x[0])|(q>x[-1])
                    if not np.array_equal(actual[outside],expected[outside]):
                        raise AssertionError(f'Endpoint hold is not exact: {file.stem}/{method}')
                if policy=='default':
                    explicit=np.fromfile(file.with_suffix(f'.fortran_{method}_extrap'),dtype='<f8')
                    if not np.array_equal(actual,explicit):
                        raise AssertionError('Default policy differs from explicit extrapolation')
                if file.stem in ['two_points','constant','zero','linear_nonuniform']:
                    query=np.clip(q,x[0],x[-1]) if policy=='endpoint' else q
                    oracle={'two_points':lambda v:2-2*v,'constant':lambda v:v*0+3.25,
                        'zero':lambda v:v*0,'linear_nonuniform':lambda v:1.5*v-2}[file.stem](query)
                    if np.max(np.abs(actual-oracle))/max(float(np.max(np.abs(oracle))),1.)>tolerance:
                        raise AssertionError(f'Analytical oracle failed: {file.stem}/{method}/{policy}')
        rows.append(row)
    passed=all(c['passed'] for r in rows for c in r['comparisons'].values())
    report={**metadata,'matlab_version':(directory/'matlab_version.txt').read_text().strip(),
        'numpy_version':np.__version__,'all_passed':passed,
        'queries_per_method_policy':sum(r['queries'] for r in rows),
        'total_queries':sum(r['queries'] for r in rows)*len(METHODS)*len(POLICIES),
        'amplitude_scale_definition':'max(max(abs(MATLAB reference)), max(abs(input y)), float64 tiny)',
        'test_file_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE/'run.py',HERE/'probe.f90',HERE/'reference.m']},
        'fixture_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        'scope':'production interp1 only; no basis or model integration','results':rows}
    (directory/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    for key in rows[0]['comparisons']:
        worst=max(rows,key=lambda r:r['comparisons'][key]['max_amplitude_scaled_error'])
        print(key,worst['case'],worst['comparisons'][key])
    if not passed:
        raise AssertionError('Comparison tolerance exceeded; see results.json')
    print(f'PASS: {len(rows)} cases, {report["total_queries"]} queries; real64 only numerical requirement')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=pathlib.Path)
    action=parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--prepare',action='store_true')
    action.add_argument('--compare',action='store_true')
    args=parser.parse_args()
    directory=args.directory.resolve()
    (prepare if args.prepare else compare)(directory)


if __name__=='__main__':
    main()
