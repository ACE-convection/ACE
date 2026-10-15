#!/usr/bin/env python3
"""Time identical native steps before/after packing; require bitwise states."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(8*1024*1024),b''):h.update(block)
    return h.hexdigest()


def replace(source,old,new):
    if source.count(old)!=1:raise ValueError('Expected unique anchor: '+old)
    return source.replace(old,new,1)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline',type=Path);parser.add_argument('candidate',type=Path)
    parser.add_argument('work',type=Path);parser.add_argument('--steps',type=int,default=1)
    args=parser.parse_args();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
    if args.steps<1:raise ValueError('Positive steps required')
    include=shlex.split(subprocess.check_output(['nf-config','--fflags'],text=True))
    libs=shlex.split(subprocess.check_output(['nf-config','--flibs'],text=True))
    report=dict(steps=args.steps,scope='One fresh-process integration per layout; initialization/compilation excluded, saved-state I/O included. Not a general long-run speed claim.',jobs={})
    input_hash=None
    for name,source in [('baseline',args.baseline.resolve()),('candidate',args.candidate.resolve())]:
        cfg=json.loads((source/'configuration.json').read_text())
        if input_hash and input_hash!=cfg['input_sha256']:raise ValueError('Different input')
        input_hash=cfg['input_sha256'];build=work/name;build.mkdir()
        for obj in ('ace_input','ace_interpolation','microphy_p3','ace_module'):
            for suffix in ('.o','.mod'):shutil.copyfile(source/'production'/(obj+suffix),build/(obj+suffix))
        driver=(source/'source/fortran/test.F').read_text()
        driver=replace(driver,'integer :: intervals','integer(kind=8) :: wall_begin,wall_end,wall_rate\ninteger :: intervals')
        driver=replace(driver,'if (steps>0) then\n  do i=1,steps',
                       'if (steps>0) then\n  call system_clock(wall_begin,wall_rate)\n  do i=1,steps')
        driver=replace(driver,'  if (len_trim(state_output)>0) close(state_unit)\n  stop\nendif',
                       "  if (len_trim(state_output)>0) close(state_unit)\n  call system_clock(wall_end)\n  write(*,*) 'SLAB_STEP_WALL_SECONDS',real(wall_end-wall_begin,kind(dt))/real(wall_rate,kind(dt))\n  stop\nendif")
        (build/'timed_driver.F').write_text(driver)
        commands=[['gfortran',*cfg['flags'],*include,'-c',str(build/'timed_driver.F')],
                  ['gfortran',*cfg['flags'],'timed_driver.o','ace_module.o','ace_input.o',
                   'ace_interpolation.o','microphy_p3.o',*libs,'-o','timed_model.exe']]
        with (build/'build.log').open('x') as log:
            for command in commands:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
        env=dict(os.environ,OMP_NUM_THREADS=str(cfg['threads']),OMP_THREAD_LIMIT=str(cfg['threads']),
                 OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M')
        env.pop('ACE_SLAB_BUDGET',None)
        command=[str(build/'timed_model.exe'),'--input',cfg['input'],'--physics','native',
                 '--steps',str(args.steps),'--dt','6','--dhh','on','--dhv','on',
                 '--state-output',str(build/'states.bin')]
        with (build/'run.log').open('x') as log:
            subprocess.run(command,cwd=build,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
        lines=[line for line in (build/'run.log').read_text().splitlines() if 'SLAB_STEP_WALL_SECONDS' in line]
        if len(lines)!=1:raise ValueError('Timing marker missing')
        elapsed=float(lines[0].split()[-1].replace('D','E'))
        report['jobs'][name]=dict(elapsed_seconds=elapsed,seconds_per_step=elapsed/args.steps,
            state_sha256=sha(build/'states.bin'),module_sha256=sha(build/'ace_module.o'),
            timed_driver_sha256=sha(build/'timed_driver.F'),threads=cfg['threads'],
            flags=cfg['flags'],commands=commands+[command],input_sha256=input_hash)
        print(name,elapsed,flush=True)
    jobs=report['jobs'];report['bitwise_equal']=jobs['baseline']['state_sha256']==jobs['candidate']['state_sha256']
    report['observed_speedup']=jobs['baseline']['elapsed_seconds']/jobs['candidate']['elapsed_seconds']
    (work/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    if not report['bitwise_equal']:raise ValueError('Packing changed numerical states')


if __name__=='__main__':main()
