#!/usr/bin/env python3
"""Run an isolated KHN26 P3 checked prefix, then a ten-minute smoke experiment."""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import resource
import shlex
import subprocess
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
FIELDS = ['MF','theta','qv','qc','nc','qr','nr','qi','ni','qrim','brim']


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def write(path, value):
    path.write_text(json.dumps(value,indent=2)+'\n')


def state_summary(path, interval):
    if not path.exists() or path.stat().st_size < 12:
        return {'complete_saved_states':0}
    n,z,nv = np.fromfile(path,'<i4',count=3)
    if (n,z,nv) != (101,401,11):
        raise ValueError('Unexpected P3 stream dimensions')
    record = (n+1)*z*nv*8
    initial_bytes = 12+record+z*8
    if path.stat().st_size < initial_bytes:
        return {'complete_saved_states':0,'incomplete_initial_record':True}
    nt = 1+(path.stat().st_size-initial_bytes)//record
    mins,maxs,finite,rime_excess,rime_density,total_water = [],[],[],[],[],[]
    for i in range(nt):
        offset = 12+i*record+(z*8 if i else 0)
        v = np.memmap(path,'<f8',mode='r',offset=int(offset),shape=(int((n+1)*z*nv),))
        v = v.reshape((n+1,z,nv),order='F')[:n]
        mins.append(v.min(axis=(0,1)).tolist()); maxs.append(v.max(axis=(0,1)).tolist())
        finite.append(bool(np.isfinite(v).all()))
        rime_excess.append(float(np.max(v[:,:,9]-v[:,:,7])))
        active = v[:,:,10]>0
        density = v[:,:,9][active]/v[:,:,10][active]
        rime_density.append([float(density.min()),float(density.max())] if density.size else None)
        qt = v[:,:,2]+v[:,:,3]+v[:,:,5]+v[:,:,7]
        total_water.append([float(qt.min()),float(qt.max())])
    minimum = np.min(mins,axis=0)
    return dict(complete_saved_states=int(nt),last_saved_time_seconds=int((nt-1)*interval),
        all_saved_values_finite=all(finite),field_order=FIELDS,
        field_minimum=minimum.tolist(),field_maximum=np.max(maxs,axis=0).tolist(),
        water_and_number_fields_nonnegative=bool(np.all(minimum[2:]>=0)),
        rime_mass_not_above_total_ice=max(rime_excess)<=0,
        rime_mass_exceeds_total_ice_max_each_state=rime_excess,
        rime_density_kg_m3_each_state=rime_density,
        total_water_min_max_each_state=total_water,
        total_water_definition='qv+qc+qr+qi; qrim is already contained in qi',
        minimum_each_state=mins,maximum_each_state=maxs,state_sha256=sha(path))


def experiment(work, tables):
    work.mkdir(parents=True,exist_ok=False)
    (work/'executed_runner.py').write_bytes(Path(__file__).read_bytes())
    source = work/'source'; source.mkdir()
    paths = ['microphy_p3.F','ace_input.F','ace_interpolation.F','ace_module.F','test.F']
    for name in paths:
        (source/name).write_bytes((ROOT/'fortran/src'/name).read_bytes())
    driver = (source/'test.F').read_text()
    old = 'dum1=Tr(1,k)+0.25'
    if driver.count(old)!=1:
        raise ValueError('Expected unique production bubble statement')
    changed = driver.replace(old,'dum1=Tr(1,k)+1.0')
    (source/'test.F').write_text(changed)
    (work/'driver.patch').write_text(''.join(difflib.unified_diff(driver.splitlines(True),
        changed.splitlines(True),fromfile='fortran/src/test.F',tofile='experiment/source/test.F')))
    table = tables/'p3_lookupTable_1.dat-v6.4-2momI'
    input_path = ROOT/'data/input/manaus1342_khn26.nc'
    config = dict(input=str(input_path),input_sha256=sha(input_path),
        lookup_directory=str(tables),lookup_table_sha256=sha(table),
        field_order=FIELDS,ncols=101,nz=401,physics='p3',dt_seconds=4,
        bubble_delta_K=1,initial_MF=0,debug_steps=10,duration_seconds=600,
        threads=32,runner_sha256=sha(Path(__file__)),
        source_sha256={name:sha(ROOT/'fortran/src'/name) for name in paths},
        experiment_source_sha256={name:sha(source/name) for name in paths},
        scope='P3 runtime smoke experiment; no MATLAB comparison or scientific acceptance threshold.')
    write(work/'configuration.json',config)
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    resource.setrlimit(resource.RLIMIT_STACK,(resource.RLIM_INFINITY,resource.RLIM_INFINITY))
    include = shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs = shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    env = dict(os.environ,OMP_NUM_THREADS='32',OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M',
        OPENBLAS_NUM_THREADS='1',OMP_DISPLAY_ENV='TRUE')
    commands = []

    def call(command, cwd, log):
        entry = dict(command=command,cwd=str(cwd),log=str(log),started_unix=time.time())
        commands.append(entry); write(work/'commands.json',commands)
        with log.open('w') as stream:
            process = subprocess.Popen(command,cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT)
            write(work/'status.json',dict(state='running',phase=log.stem,pid=process.pid))
            entry['exit_code'] = process.wait()
        entry['wall_seconds']=time.time()-entry['started_unix']
        write(work/'commands.json',commands)
        return entry['exit_code']

    def build(name, checked):
        target = work/name; target.mkdir()
        flags = ['-O2','-ffree-form','-fdefault-real-8','-fdefault-double-8',
                 '-ffree-line-length-none','-fopenmp']
        if checked:
            flags += ['-g','-fcheck=all,no-array-temps','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
        for file in paths:
            code = call(['gfortran',*flags,*include,'-c',str(source/file)],target,target/(file+'.compile.log'))
            if code: raise RuntimeError(f'Compilation failed: {file}')
        executable = target/'ace_model.exe'
        code = call(['gfortran',*flags,*[str(target/Path(p).with_suffix('.o')) for p in paths],
                     '-o',str(executable),*libs],target,target/'link.log')
        if code: raise RuntimeError('Link failed')
        return executable

    def run(executable,name,steps=None):
        out = work/name; out.mkdir()
        command = [str(executable),'--input',str(input_path),'--physics','p3','--dt','4',
                   '--p3-lookup-directory',str(tables),'--state-output',str(out/'states.bin')]
        if steps: command += ['--steps',str(steps)]
        else: command += ['--intervals','10','--output',str(out/'fields.dat')]
        code = call(command,out,out/'run.log')
        report = dict(exit_code=code,**state_summary(out/'states.bin',4 if steps else 60))
        report['expected_saved_states']=steps+1 if steps else 11
        report['passed'] = (code==0 and report['complete_saved_states']==report['expected_saved_states']
            and report.get('all_saved_values_finite',False) and report.get('water_and_number_fields_nonnegative',False)
            and report.get('rime_mass_not_above_total_ice',False))
        write(out/'results.json',report)
        return report

    try:
        checked = build('debug_build',True)
        debug = run(checked,'debug_prefix',10)
        if not debug['passed']:
            write(work/'status.json',dict(state='debug_prefix_failed',full_started=False,
                results=debug,reason='Checked prefix must pass before production smoke run.'))
            print(json.dumps({'state':'debug_prefix_failed','results':debug},indent=2),flush=True)
            return
        production = build('production_build',False)
        prefix = run(production,'production_prefix',10)
        if not prefix['passed'] or sha(work/'debug_prefix/states.bin')!=sha(work/'production_prefix/states.bin'):
            raise RuntimeError('Production prefix failed or differs from checked prefix')
        full = run(production,'ten_minute')
        write(work/'status.json',dict(state='completed' if full['passed'] else 'ten_minute_failed',
            full_started=True,debug_prefix_passed=True,production_prefix_identical=True,results=full))
        print(json.dumps({'state':'completed' if full['passed'] else 'ten_minute_failed',
            'summary':{k:v for k,v in full.items() if not k.endswith('each_state')}},indent=2))
    except Exception as exc:
        write(work/'status.json',dict(state='failed',error=str(exc)))
        raise


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--lookup-directory',type=Path,required=True)
    args=parser.parse_args()
    experiment(args.work.resolve(),args.lookup_directory.resolve())
