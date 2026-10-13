#!/usr/bin/env python3
"""Prepare and supervise independent three-hour single/multiACE P3 runs."""
import argparse
from datetime import datetime, timezone
import difflib
import json
import os
from pathlib import Path
import resource
import shlex
import shutil
import subprocess
import sys
import time

from p3_smoke import ROOT, sha, state_summary


def write(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value,indent=2)+'\n')
    temporary.replace(path)


def prepare(work, smoke):
    gate = json.loads((smoke/'status.json').read_text())
    cfg = json.loads((smoke/'configuration.json').read_text())
    if gate['state']!='completed' or not gate['production_prefix_identical']:
        raise ValueError('Require a completed P3 smoke experiment')
    for name, expected in cfg['source_sha256'].items():
        if sha(ROOT/'fortran/src'/name)!=expected:
            raise ValueError('Production source changed since smoke experiment: '+name)
    if sha(Path(cfg['input']))!=cfg['input_sha256']:
        raise ValueError('Input changed')
    if sha(Path(cfg['lookup_directory'])/'p3_lookupTable_1.dat-v6.4-2momI')!=cfg['lookup_table_sha256']:
        raise ValueError('P3 lookup changed')
    if sha(smoke/'ten_minute/states.bin')!=gate['results']['state_sha256']:
        raise ValueError('Smoke stream changed')
    work.mkdir(parents=True,exist_ok=False)
    shutil.copyfile(Path(__file__),work/'executed_runner.py')
    shutil.copyfile(Path(__file__).with_name('p3_smoke.py'),work/'executed_state_reader.py')
    names = list(cfg['source_sha256'])
    include = shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs = shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    commands=[]
    single=work/'singleACE'; multi=work/'multiACE'
    for case in (single,multi):
        case.mkdir(); (case/'full').mkdir()
    source=single/'source'; source.mkdir()
    for name in names:
        shutil.copyfile(smoke/'source'/name,source/name)
    module=(source/'ace_module.F').read_text()
    marker='!dXdt(2:ncols,:,:)=0.'
    if module.count(marker)!=1:
        raise ValueError('Expected existing singleACE dynamics mask')
    changed=module.replace(marker,'dXdt(2:ncols,:,:)=0.')
    (source/'ace_module.F').write_text(changed)
    (single/'dynamics_mask.patch').write_text(''.join(difflib.unified_diff(
        module.splitlines(True),changed.splitlines(True),fromfile='multiACE/ace_module.F',tofile='singleACE/ace_module.F')))
    for build_name,checked in (('debug',True),('build',False)):
        build=single/build_name; build.mkdir()
        flags=['-O2','-ffree-form','-fdefault-real-8','-fdefault-double-8','-ffree-line-length-none','-fopenmp']
        if checked: flags+=['-g','-fcheck=all,no-array-temps','-ffpe-trap=invalid,zero,overflow','-fbacktrace']
        for name in names:
            command=['gfortran',*flags,*include,'-c',str(source/name)]
            with (build/(name+'.compile.log')).open('w') as log:
                subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
            commands.append(command)
        command=['gfortran',*flags,*[str(build/Path(name).with_suffix('.o')) for name in names],
                 '-o',str(build/'ace_model.exe'),*libs]
        with (build/'link.log').open('w') as log:
            subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
        commands.append(command)
    (multi/'build').mkdir()
    shutil.copy2(smoke/'production_build/ace_model.exe',multi/'build/ace_model.exe')
    write(work/'build_commands.json',commands)
    config=dict(case={k:cfg[k] for k in ('input','input_sha256','lookup_directory','lookup_table_sha256',
        'field_order','dt_seconds','bubble_delta_K','initial_MF','ncols','nz','threads')},
        duration_seconds=10800,output_interval_seconds=60,expected_saved_states=181,
        smoke_workspace=str(smoke),smoke_configuration_sha256=sha(smoke/'configuration.json'),
        multi_executable_source=str(smoke/'production_build/ace_model.exe'),
        single_definition='Only ACE 1 dynamics tendency active; full 101-column basis, mean-MF projection, physics and damping retained.',
        source_sha256=cfg['source_sha256'],
        single_source_sha256={name:sha(source/name) for name in names},
        executable_sha256={str(p):sha(p) for p in (single/'debug/ace_model.exe',single/'build/ace_model.exe',multi/'build/ace_model.exe')},
        runner_sha256=sha(Path(__file__)),state_reader_sha256=sha(Path(__file__).with_name('p3_smoke.py')))
    write(work/'configuration.json',config)
    write(work/'status.json',dict(state='prepared',full_started=False))
    print(str(work),flush=True)


def verify(work):
    cfg=json.loads((work/'configuration.json').read_text())
    for file,expected in cfg['executable_sha256'].items():
        if sha(Path(file))!=expected: raise ValueError('Executable changed: '+file)
    if sha(work/'executed_runner.py')!=cfg['runner_sha256']:
        raise ValueError('Supervisor changed')
    if sha(Path(__file__).with_name('p3_smoke.py'))!=cfg['state_reader_sha256']:
        raise ValueError('State reader changed')
    if sha(Path(cfg['case']['input']))!=cfg['case']['input_sha256']:
        raise ValueError('Input changed')
    if sha(Path(cfg['case']['lookup_directory'])/'p3_lookupTable_1.dat-v6.4-2momI')!=cfg['case']['lookup_table_sha256']:
        raise ValueError('Lookup changed')
    return cfg


def environment():
    env=dict(os.environ)
    for key in ('GOMP_CPU_AFFINITY','OMP_PLACES','OMP_PROC_BIND','KMP_AFFINITY'):
        env.pop(key,None)
    env.update(OMP_NUM_THREADS='32',OMP_DYNAMIC='FALSE',OMP_THREAD_LIMIT='32',OMP_STACKSIZE='64M',
        OPENBLAS_NUM_THREADS='1',OMP_DISPLAY_ENV='TRUE')
    return env


def records(path):
    if not path.exists(): return 0
    record=102*401*11*8
    initial=12+record+401*8
    size=path.stat().st_size
    return 0 if size<initial else 1+(size-initial)//record


def supervise(work):
    cfg=verify(work); children=[]
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    resource.setrlimit(resource.RLIMIT_STACK,(resource.RLIM_INFINITY,resource.RLIM_INFINITY))
    env=environment()

    def start(case,build,tag,steps=None):
        out=work/case/tag
        if tag!='full': out.mkdir()
        command=[str(work/case/build/'ace_model.exe'),'--input',cfg['case']['input'],
            '--physics','p3','--dt','4','--p3-lookup-directory',cfg['case']['lookup_directory'],
            '--state-output',str(out/'states.bin')]
        command+=['--steps',str(steps)] if steps else ['--intervals','180','--output',str(out/'fields.dat')]
        log=(out/'run.log').open('x')
        process=subprocess.Popen(command,cwd=out,env=env,stdin=subprocess.DEVNULL,
            stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        child=dict(case=case,tag=tag,process=process,log=log,command=command,out=out)
        children.append(child)
        write(out/'launch.json',dict(pid=process.pid,command=command,started_utc=datetime.now(timezone.utc).isoformat()))
        return child

    try:
        for build,tag in (('debug','checked_prefix'),('build','production_prefix')):
            child=start('singleACE',build,tag,10)
            while child['process'].poll() is None:
                write(work/'status.json',dict(state='singleACE_'+tag,supervisor_pid=os.getpid(),
                    driver_pid=child['process'].pid,full_started=False,updated_utc=datetime.now(timezone.utc).isoformat()))
                time.sleep(10)
            child['log'].close()
            summary=state_summary(child['out']/'states.bin',4)
            passed=(child['process'].returncode==0 and summary['complete_saved_states']==11
                and summary.get('all_saved_values_finite') and summary.get('water_and_number_fields_nonnegative')
                and summary.get('rime_mass_not_above_total_ice'))
            write(child['out']/'results.json',dict(exit_code=child['process'].returncode,passed=bool(passed),**summary))
            if not passed: raise RuntimeError('singleACE '+tag+' failed')
        if sha(work/'singleACE/checked_prefix/states.bin')!=sha(work/'singleACE/production_prefix/states.bin'):
            raise RuntimeError('singleACE checked/production prefix mismatch')
        write(work/'singleACE/gate_results.json',dict(passed=True,duration_seconds=40,
            checked_production_byte_identical=True,state_sha256=sha(work/'singleACE/checked_prefix/states.bin')))
        verify(work)
        full=[start(case,'build','full') for case in ('singleACE','multiACE')]
        while True:
            states={}
            for child in full:
                code=child['process'].poll(); count=records(child['out']/'states.bin')
                states[child['case']]=dict(pid=child['process'].pid,exit_code=code,
                    state='running' if code is None else ('exited' if code==0 else 'failed'),
                    complete_saved_states=count,model_seconds=max(0,count-1)*60)
            write(work/'status.json',dict(state='full_running',supervisor_pid=os.getpid(),full_started=True,
                runs=states,updated_utc=datetime.now(timezone.utc).isoformat()))
            if all(child['process'].poll() is not None for child in full): break
            time.sleep(20)
        results={}
        for child in full:
            child['log'].close()
            summary=state_summary(child['out']/'states.bin',60)
            passed=(child['process'].returncode==0 and summary['complete_saved_states']==181
                and summary.get('all_saved_values_finite') and summary.get('water_and_number_fields_nonnegative')
                and summary.get('rime_mass_not_above_total_ice'))
            result=dict(exit_code=child['process'].returncode,passed=bool(passed),**summary)
            write(child['out']/'results.json',result); results[child['case']]=result
        write(work/'status.json',dict(state='completed_pending_scientific_review' if all(r['passed'] for r in results.values())
            else 'completed_with_failed_checks',full_started=True,results=results,
            updated_utc=datetime.now(timezone.utc).isoformat()))
    except Exception as exc:
        write(work/'status.json',dict(state='failed',error=str(exc),supervisor_pid=os.getpid(),
            driver_pids=[c['process'].pid for c in children if c['process'].poll() is None],
            updated_utc=datetime.now(timezone.utc).isoformat()))
        raise


def launch(work):
    verify(work)
    if json.loads((work/'status.json').read_text())['state']!='prepared':
        raise ValueError('Workspace already launched')
    with (work/'supervisor.log').open('x') as log:
        process=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),str(work),'--supervise'],
            cwd=ROOT,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    write(work/'supervisor.json',dict(pid=process.pid,started_utc=datetime.now(timezone.utc).isoformat()))
    print(json.dumps({'supervisor_pid':process.pid,'workspace':str(work)}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    actions=parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--prepare',action='store_true')
    actions.add_argument('--launch',action='store_true')
    actions.add_argument('--supervise',action='store_true')
    parser.add_argument('--smoke',type=Path,default=ROOT/'migration_work/khn26_p3_smoke')
    args=parser.parse_args(); work=args.work.resolve()
    if args.prepare: prepare(work,args.smoke.resolve())
    elif args.launch: launch(work)
    else: supervise(work)
