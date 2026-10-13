#!/usr/bin/env python3
"""Profile serial packed KHN26 singleACE sections in isolated builds."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/khn26'))
from oop_regression import response_code
BASE = ROOT / 'migration_work/khn26_single_3h'
PACKED = ROOT / 'migration_work/khn26_packed_model'
LABELS = ['initialization', 'tendency_total', 'transport_and_thermodynamics',
          'thermodynamics_nested', 'mean_buoyancy_and_coarsening', 'forcing_pack',
          'PMB_contraction', 'momentum_interpolation_mask', 'damping', 'driver_total',
          'initial_PMB_pack']


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def replace(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Expected unique instrumentation anchor: ' + old)
    return text.replace(old, new, 1)


def instrument(source):
    source = replace(source, 'module ace_module\n',
                     'module ace_module\nuse iso_fortran_env, only: int64, real64\n')
    source = replace(source, '! defien operator',
                     'public :: profile_dump\ninteger(int64) :: profile_ticks(11), profile_rate\n'
                     'integer :: profile_calls(11)=0\nreal(real64) :: profile_seconds(11)=0.0_real64\n\n! defien operator')
    helpers = '''contains
subroutine profile_start(slot)
integer, intent(in) :: slot
call system_clock(profile_ticks(slot),profile_rate)
end subroutine
subroutine profile_end(slot)
integer, intent(in) :: slot
integer(int64) :: tick
call system_clock(tick)
profile_seconds(slot)=profile_seconds(slot)+real(tick-profile_ticks(slot),real64)/real(profile_rate,real64)
profile_calls(slot)=profile_calls(slot)+1
end subroutine
subroutine profile_dump()
integer :: slot
do slot=1,11
  write(*,*) 'ACE_PROFILE',slot,profile_seconds(slot),profile_calls(slot)
enddo
end subroutine
'''
    source = source.replace('\ncontains\n\nsubroutine ace_driver', '\n'+helpers+'\nsubroutine ace_driver', 1)
    contextual = "type :: ace_response_t" in source
    for slot, start, end in [
        (1, 'if (.not.all(ieee_is_finite(environment_tv))', 'end subroutine ace_initialization'),
        (2, '! initialization\ndo k=1,nz', 'end subroutine ace_tendency'),
        (3, '! initialization\ndo k=1,nz', '! MATLAB S20 removes the area-weighted mean buoyancy'),
        (5, '! MATLAB S20 removes the area-weighted mean buoyancy', 'packed_F=transpose(coarse_F)'),
        (8, '!$omp end parallel do\n\ndo i=1,ncols', 'end subroutine ace_tendency'),
        (9, 'if (first) then\n  allocate(damp(nz))', 'end subroutine ImDamp'),
        (10, 'yi = X\n\ndo while', '\n\ncontains\nsubroutine apply_native_precipitation()'),
        (11, 'allocate(packed_pmb(', 'call move_alloc(packed_pmb,PMB)')]:
        if contextual:
            start, end = response_code(start), response_code(end)
            end = end.replace("end subroutine ace_initialization", "end subroutine ace_initialization_context").replace("end subroutine ace_tendency", "end subroutine ace_tendency_context")
        source = replace(source, start, f'call profile_start({slot})\n'+start)
        if slot == 11:
            source = replace(source, end, end+f'\ncall profile_end({slot})')
        elif slot == 8:
            # The start includes the completed OpenMP loop; move the timer below it.
            source = source.replace('call profile_start(8)\n!$omp end parallel do',
                                    '!$omp end parallel do\ncall profile_start(8)', 1)
            source = replace(source, end, f'call profile_end({slot})\n'+end)
        else:
            source = replace(source, end, f'call profile_end({slot})\n'+end)
    source = replace(source, '  if (rkstage==1) then\n',
                     '  if (rkstage==1) then\n    call profile_start(4)\n')
    source = replace(source, '    enddo \n  endif\n\n  Tv(',
                     '    enddo \n    call profile_end(4)\n  endif\n\n  Tv(')
    source = replace(source, response_code('packed_F=transpose(coarse_F)') if contextual else 'packed_F=transpose(coarse_F)',
                     response_code('call profile_start(6)\npacked_F=transpose(coarse_F)\ncall profile_end(6)\ncall profile_start(7)') if contextual else 'call profile_start(6)\npacked_F=transpose(coarse_F)\ncall profile_end(6)\ncall profile_start(7)')
    source = replace(source, '!$omp end parallel do',
                     '!$omp end parallel do\ncall profile_end(7)')
    return replace(source, '!dXdt(2:ncols,:,:)=0.', 'dXdt(2:ncols,:,:)=0.')


def run(work, repeats, duration_seconds=4, production=False, output_block=1):
    work.mkdir(parents=True, exist_ok=False)
    case = json.loads((BASE/'single_case.json').read_text())
    source = ROOT/'fortran/src/ace_module.F'
    expected = json.loads((PACKED/'validation_results.json').read_text())['source_sha256']
    if sha(source) != expected or sha(case['input']) != case['input_sha256']:
        raise ValueError('Source/input differs from validated packed case')
    candidate = source.read_text()
    if output_block != 1:
        from analyze_serial_simd import kernel
        contextual = 'type :: ace_response_t' in candidate
        anchor = 'do i=1,ncols\n  do k=1,coarse_nz+1\n    value=0.'
        begin = candidate.index(response_code(anchor) if contextual else anchor)
        end = candidate.index('!$omp end parallel do', begin)
        original_loop = candidate[begin:end]
        blocked_loop, declaration = kernel(original_loop.replace("response%", ""), output_block)
        if contextual: blocked_loop = response_code(blocked_loop)
        candidate = replace(candidate, 'real*8 :: partial,value', declaration)
        candidate = replace(candidate, original_loop, blocked_loop)
    module = work/'profile_module.F'; module.write_text(instrument(candidate))
    (work/'profile_runner.py').write_bytes(Path(__file__).read_bytes())
    driver = work/'profile_driver.F'
    driver.write_text(replace((BASE/'single_driver.F').read_text(),
                             '  stop\nendif\ncall cpu_time(start)',
                             '  call profile_dump()\n  stop\nendif\ncall cpu_time(start)'))
    driver.write_text(replace(driver.read_text(), "write(*,*) 'time cost =',finish-start",
                             "write(*,*) 'time cost =',finish-start\ncall profile_dump()"))
    build = work/'build'; build.mkdir()
    flags = ['-cpp','-ffree-form','-ffree-line-length-none','-O2','-g',
             '-fcheck=all,no-array-temps','-ffpe-trap=invalid,zero,overflow',
             '-fbacktrace','-fdefault-real-8','-fdefault-double-8']
    reference = BASE/'smoke_fortran_states.bin'
    if production:
        benchmark = ROOT/'migration_work/khn26_single_serial_15min'
        cfg = json.loads((benchmark/'benchmark_configuration.json').read_text())
        flags = cfg['fortran_flags']
        reference = BASE/'smoke_fortran_states.bin' if duration_seconds == 4 else benchmark/'full_fortran_states.bin'
        for path in [Path(case['input']), *[ROOT/'fortran/src'/(n+'.F') for n in
                     ('ace_input','ace_interpolation','microphy_p3')],
                     *[benchmark/'build'/(n+'.o') for n in ('ace_input','ace_interpolation','microphy_p3')]]:
            if sha(path) != cfg['sha256'][str(path)]:
                raise ValueError('Production benchmark provenance changed: '+str(path))
    inc = subprocess.check_output(['nf-config','--fflags'],text=True).split()
    libs = subprocess.check_output(['nf-config','--flibs'],text=True).split()
    objects = [BASE/'build64'/(name+'.o') for name in ('ace_input','ace_interpolation','microphy_p3')]
    if production:
        objects = [benchmark/'build'/(name+'.o') for name in ('ace_input','ace_interpolation','microphy_p3')]
    for name in ('ace_input','ace_interpolation','microphy_p3'):
        mod_base = benchmark/'build' if production else PACKED/'serial'
        (build/(name+'.mod')).write_bytes((mod_base/(name+'.mod')).read_bytes())
    commands = [['gfortran',*flags,*inc,'-c',str(module),'-o','ace_module.o'],
                ['gfortran',*flags,*inc,'-c',str(driver),'-o','test.o'],
                ['gfortran',*flags,'test.o','ace_module.o',*map(str,objects),*libs,'-o','ace_model.exe']]
    for command in commands:
        subprocess.run(command,cwd=build,check=True)
    provenance = {str(p):sha(p) for p in [source,Path(case['input']),module,driver,*objects,
                                          reference,Path(__file__).resolve()]}
    if output_block != 1:
        generator = ROOT/'tests/basis_layout/analyze_serial_simd.py'
        provenance[str(generator)] = sha(generator)
        (work/generator.name).write_bytes(generator.read_bytes())
    steps = round(duration_seconds/case['dt_seconds'])
    report = {'case':case,'compiled_commands':commands,'sha256':provenance,'runs':[],
              'duration_seconds':duration_seconds,'steps':steps,'production':production,'flags':flags,
              'independent_output_block':output_block,'production_source_modified':False,
              'limits':'Section wall timings in an evolving serial run on a shared host. '
                       'Instrumentation can affect performance. Nested timings are not additive; '
                       'initialization is separate and paid once; no long-run speed guarantee.'}
    for repeat in range(repeats):
        state = work/f'state_{repeat}.bin'; log = work/f'profile_{repeat}.log'
        command = [str(build/'ace_model.exe'),'--input',case['input'],'--physics',case['physics'],
                   '--dt',str(case['dt_seconds']),'--state-output',str(state)]
        if duration_seconds == 4:
            command += ['--steps','1']
        else:
            command += ['--intervals',str(duration_seconds//60),'--output',str(work/f'profile_{repeat}.dat')]
        print(f'Profiling repeat {repeat+1}/{repeats}',flush=True)
        started = time.monotonic()
        with log.open('w') as stream:
            subprocess.run(command,cwd=work,stdout=stream,stderr=subprocess.STDOUT,check=True)
        wall = time.monotonic()-started
        with reference.open('rb') as stream:
            expected_state = stream.read(state.stat().st_size)
        expected_count = 2 if duration_seconds == 4 else duration_seconds//60+1
        expected_bytes = 12 + (expected_count*102*401*3+401)*8
        if state.stat().st_size != expected_bytes or state.read_bytes() != expected_state:
            raise ValueError('Instrumented output differs from validated reference prefix')
        sections = {}
        for line in log.read_text().splitlines():
            if line.strip().startswith('ACE_PROFILE'):
                _, slot, seconds, calls = line.split()
                sections[LABELS[int(slot)-1]] = {'wall_seconds':float(seconds),'calls':int(calls)}
        if len(sections) != len(LABELS):
            raise ValueError('Incomplete section timing output')
        total = sections['driver_total']['wall_seconds']
        sections['transport_excluding_thermodynamics'] = {
            'wall_seconds':sections['transport_and_thermodynamics']['wall_seconds']-
                           sections['thermodynamics_nested']['wall_seconds']}
        exclusive_names = ['transport_excluding_thermodynamics','thermodynamics_nested',
                           'mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction',
                           'momentum_interpolation_mask','damping']
        sections['other_driver_and_timer_overhead'] = {
            'wall_seconds':total-sum(sections[name]['wall_seconds'] for name in exclusive_names)}
        for name, values in sections.items():
            if name not in ('initialization','initial_PMB_pack'):
                values['wall_seconds_per_step'] = values['wall_seconds']/steps
                values['percent_of_driver'] = 100*values['wall_seconds']/total
            if values.get('calls',0):
                values['wall_seconds_per_call'] = values['wall_seconds']/values['calls']
        report['runs'].append({'command':command,'process_wall_seconds':wall,
                              'sections':sections,'binary_identical':True,
                              'PMB_percent_of_driver':100*sections['PMB_contraction']['wall_seconds']/total,
                              'state_sha256':sha(state)})
        (work/'profile_results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report['runs'][-1],indent=2),flush=True)
    for name, expected in provenance.items():
        if sha(name) != expected:
            raise ValueError('Provenance changed during profiling: '+name)
    report['provenance_rechecked']=True
    (work/'profile_results.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--repeats',type=int,default=2)
    parser.add_argument('--duration',type=int,default=4,help='4 for one step, or a positive multiple of 60 seconds')
    parser.add_argument('--production',action='store_true',help='Use verified unchecked serial -O2 objects/flags from the 15-minute benchmark')
    parser.add_argument('--output-block',type=int,choices=(1,4,8),default=1,
                        help='Isolated serial candidate retaining reduction order; requires --production')
    args = parser.parse_args()
    if args.repeats < 1: parser.error('--repeats must be positive')
    if args.duration != 4 and (args.duration <= 0 or args.duration%60 or not args.production):
        parser.error('Longer profiles require --production and duration a positive multiple of 60 s')
    if args.output_block != 1 and not args.production:
        parser.error('Blocked candidates require --production serial builds')
    run(args.work.resolve(),args.repeats,args.duration,args.production,args.output_block)
