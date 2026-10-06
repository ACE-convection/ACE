#!/usr/bin/env python3
"""Profile one minute of frozen-default MATLAB KHN26 and compare serial Fortran.

Only isolated test copies receive timers. Contraction expressions and their
reduction grouping are preserved; their result is named before interpolation.
"""
import argparse
import difflib
import json
import os
from pathlib import Path
import re
import subprocess
import time

import numpy as np
from single import ROOT, digest
from trajectory import replace_once

BASE = ROOT/'migration_work/khn26_single_3h'
FORTRAN = ROOT/'migration_work/khn26_serial_profile_1min'
LABELS = ['tendency_total','transport_setup','microrad_total','thermodynamics_nested',
          'mean_buoyancy','basis_contraction','interpolation','damping','driver_total']


def add(slot, timer):
    return f"ace_profile_add({slot},toc({timer}));\n"


def split_expression(text, timed=False):
    start = text.index('    dMFdt = interp1(Z,squeeze(sum(sum(PMB.')
    stop = text.index(",zm,'makima');", start)+len(",zm,'makima');")
    original = text[start:stop]
    kernel = original[len('    dMFdt = interp1(Z,'):-len(",zm,'makima');")]
    replacement = '    ace_coarse_response='+kernel+";\n    dMFdt=interp1(Z,ace_coarse_response,zm,'makima');"
    if timed:
        replacement = ('    ace_kernel_clock=tic;\n    ace_coarse_response='+kernel+';\n'+
            add(6,'ace_kernel_clock')+'ace_interpolation_clock=tic;\n'
            "    dMFdt=interp1(Z,ace_coarse_response,zm,'makima');\n"+add(7,'ace_interpolation_clock'))
    return text[:start]+replacement+text[stop:]


def instrument(text, mode='helper'):
    original_text = text
    text = replace_once(text, '%% Time-integration\n',
        'global ACE_PROFILE_SECONDS ACE_PROFILE_CALLS\n'
        'ACE_PROFILE_SECONDS=zeros(1,9); ACE_PROFILE_CALLS=zeros(1,9);\n\n%% Time-integration\n')
    text = replace_once(text, 'tic;\nX = timeint(', 'ace_integration_clock=tic;\nX = timeint(')
    text = replace_once(text, 'Tcost = toc;',
        'Tcost = toc(ace_integration_clock);\n'
        'ACE_PROFILE_SECONDS(9)=Tcost; ACE_PROFILE_CALLS(9)=1;\n'
        "fid=fopen(fullfile(fileparts(mfilename('fullpath')),'matlab_sections.txt'),'w');\n"
        "for ace_slot=1:9\n fprintf(fid,'%d %.17g %d\\n',ace_slot,ACE_PROFILE_SECONDS(ace_slot),ACE_PROFILE_CALLS(ace_slot));\nend\nfclose(fid);")
    text = replace_once(text, 'function dXdt = expFun(X,dTH,dQt,rho0B,model)\n',
        'function dXdt = expFun(X,dTH,dQt,rho0B,model)\nace_tendency_clock=tic; ace_transport_clock=tic;\n')
    text = replace_once(text, '  % Recall X(z,var,ACE-i)',
        '  '+add(2,'ace_transport_clock')+'  % Recall X(z,var,ACE-i)')
    text = replace_once(text, 'end\n\nfunction MF = ExDiffMF',
        add(1,'ace_tendency_clock')+'end\n\nfunction MF = ExDiffMF')
    signature = 'function dMFdt = NONLOCAL_RESPONSE(rho0B, F, dz2FH, DHh, Z, zm, coarse_z, Ni, PMB, PMDv, PMD, Ai, zero_ref_buoyancy)\n'
    text = replace_once(text, signature, signature+'ace_mean_clock=tic;\n')
    text = replace_once(text, '  if coarse_z==1\n', '  '+add(5,'ace_mean_clock')+'  if coarse_z==1\nace_kernel_clock=tic;\n')
    # Time the original reduction, without changing any floating-point expression.
    text = split_expression(text, timed=True)
    branch_end = '2),3)); % (zi,ACE-i)\n  else\n'
    text = replace_once(text, branch_end,
        '2),3)); % (zi,ACE-i)\n'+add(6,'ace_kernel_clock')+'  else\n')
    signature = 'function [dTH, dQt, rho0B] = microrad(y, p_zc, rho_zc, Tv_zc, theta_e_diag, model)\n'
    text = replace_once(text, signature, signature+'ace_microrad_clock=tic; ace_thermo_clock=tic;\n')
    text = replace_once(text, '  [dTH, dQt] = PRECIP_SINKS(T, Q, QL, QI, p_zc, model.qc_ramp, model.dqc, model.tau_pr);',
        add(4,'ace_thermo_clock')+'  [dTH, dQt] = PRECIP_SINKS(T, Q, QL, QI, p_zc, model.qc_ramp, model.dqc, model.tau_pr);')
    text = replace_once(text, '  rho0B = rho_zc.*eval_B(Tv, Tv_zc);\nend',
        '  rho0B = rho_zc.*eval_B(Tv, Tv_zc);\n'+add(3,'ace_microrad_clock')+'end')
    damping = '      yn = ImDamp(yn,model.theta_e_zc,model.qt_zc,model.Nzm,model.damp);'
    text = replace_once(text, damping,
        'ace_damping_clock=tic;\n'+damping+'\n'+add(8,'ace_damping_clock'))
    if mode == 'unsplit':
        # Keep the large original interp1(PMB-expression) statement intact.
        # Measure this complete function, rather than naming its intermediate.
        start = original_text.index('function dMFdt = NONLOCAL_RESPONSE(')
        stop = original_text.index('function [dTH, dQt, rho0B] = microrad(',start)
        block = original_text[start:stop]
        newline = block.index('\n')+1
        block = block[:newline]+'ace_kernel_clock=tic;\n'+block[newline:]
        last_end = block.rindex('end\n')
        block = block[:last_end]+add(6,'ace_kernel_clock')+block[last_end:]
        start = text.index('function dMFdt = NONLOCAL_RESPONSE(')
        stop = text.index('function [dTH, dQt, rho0B] = microrad(',start)
        text = text[:start]+block+text[stop:]
    return text+'''
function ace_profile_add(slot, seconds)
global ACE_PROFILE_SECONDS ACE_PROFILE_CALLS
ACE_PROFILE_SECONDS(slot)=ACE_PROFILE_SECONDS(slot)+seconds;
ACE_PROFILE_CALLS(slot)=ACE_PROFILE_CALLS(slot)+1;
end
'''


def prepare(work, control=False, mode='helper'):
    case = json.loads((BASE/'single_case.json').read_text())
    original = (BASE/'single_main.m').read_text()
    if digest(BASE/'single_main.m') != case['generated_sha256']['single_main.m']:
        raise ValueError('Frozen MATLAB source changed')
    if digest(case['input']) != case['input_sha256']:
        raise ValueError('Shared input changed')
    work.mkdir(parents=True,exist_ok=False)
    source = replace_once(original,'tspan = 0:60:10800;','tspan = 0:60:60;').replace(str(BASE),str(work))
    if mode == 'split_only':source = split_expression(source)
    elif not control:source = instrument(source,mode)
    (work/'single_main.m').write_text(source)
    (work/'instrumentation.diff').write_text(''.join(difflib.unified_diff(
        original.splitlines(True),source.splitlines(True),fromfile=str(BASE/'single_main.m'),tofile=str(work/'single_main.m'))))
    launcher = (BASE/'full_launch.m').read_text().replace(str(BASE),str(work))
    launcher = "fprintf('Natural MATLAB computational thread cap = %d\\n',maxNumCompThreads);\n"+launcher
    (work/'full_launch.m').write_text(launcher)
    paths = [Path(case['input']),BASE/'single_main.m',work/'single_main.m',work/'full_launch.m',
             ROOT/'matlab/util_timeint/ssprk93.m',BASE/'full_matlab_states.bin',
             FORTRAN/'profile_results.json',Path(__file__).resolve()]
    cfg = {'case':case,'duration_seconds':60,'steps':15,'dt_seconds':4,'control':control or mode == 'split_only','timer_mode':mode,
           'command':['matlab','-batch',f"run('{work}/full_launch.m')"],
           'sha256':{str(p):digest(p) for p in paths},
           'environment':{k:os.environ.get(k) for k in ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS','MATLAB_PREFDIR')},
           'settings':'Frozen three-hour batch/default settings; no thread setter or CPU pinning.'}
    (work/'configuration.json').write_text(json.dumps(cfg,indent=2)+'\n')


def run(work):
    cfg = json.loads((work/'configuration.json').read_text())
    for name, expected in cfg['sha256'].items():
        if digest(name) != expected:raise ValueError('Provenance changed: '+name)
    started = time.monotonic()
    with (work/'matlab.log').open('x') as log:
        subprocess.run(cfg['command'],cwd=work,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,check=True)
    wall = time.monotonic()-started
    state = work/'full_matlab_states.bin'
    expected_bytes = 2*101*401*3*8
    with (BASE/'full_matlab_states.bin').open('rb') as stream:reference=stream.read(expected_bytes)
    if state.stat().st_size != expected_bytes or state.read_bytes() != reference:
        raise ValueError('Instrumented MATLAB states differ from the validated 0/60 s prefix')
    if not np.isfinite(np.fromfile(state,'<f8')).all():raise ValueError('Nonfinite state')
    if cfg.get('control'):
        total = float(re.search(r'ODE solver time = ([0-9.]+) sec',(work/'matlab.log').read_text())[1])
        for name, expected in cfg['sha256'].items():
            if digest(name) != expected:raise ValueError('Control provenance changed: '+name)
        report = {'duration_seconds':60,'steps':15,'integration_wall_seconds':total,
                  'wall_seconds_per_step':total/15,'process_wall_seconds':wall,
                  'binary_identical_to_three_hour_prefix':True,'provenance_rechecked':True,
                  'state_sha256':digest(state),'configuration':cfg,
                  'scope':'Original MATLAB timeint tic/toc; no section timers. One cold evolving minute on shared hardware.'}
        (work/'control_results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({k:report[k] for k in ('integration_wall_seconds','wall_seconds_per_step','binary_identical_to_three_hour_prefix')},indent=2),flush=True)
        return
    sections = {}
    basis_section = 'nonlocal_response_total' if cfg.get('timer_mode') == 'unsplit' else 'basis_contraction'
    for line in (work/'matlab_sections.txt').read_text().splitlines():
        slot, seconds, calls = line.split()
        sections[LABELS[int(slot)-1]]={'wall_seconds':float(seconds),'calls':int(calls)}
    if basis_section != 'basis_contraction':sections[basis_section]=sections.pop('basis_contraction')
    if len(sections) != 9 or sections[basis_section]['calls'] != 135 or sections['microrad_total']['calls'] != 30:
        raise ValueError('Incomplete profile or unexpected step/stage counts')
    total = sections['driver_total']['wall_seconds']
    def seconds(name):return sections[name]['wall_seconds']
    sections['microrad_excluding_inversion']={'wall_seconds':seconds('microrad_total')-seconds('thermodynamics_nested')}
    sections['tendency_assembly_mask_timer_overhead']={'wall_seconds':seconds('tendency_total')-sum(seconds(n) for n in ('transport_setup','mean_buoyancy',basis_section,'interpolation'))}
    sections['other_driver_timer_overhead']={'wall_seconds':total-sum(seconds(n) for n in ('tendency_total','microrad_total','damping'))}
    for data in sections.values():
        data['wall_seconds_per_step']=data['wall_seconds']/15
        data['percent_of_driver']=100*data['wall_seconds']/total
        if data.get('calls'):data['wall_seconds_per_call']=data['wall_seconds']/data['calls']
    f = json.loads((FORTRAN/'profile_results.json').read_text())['runs'][0]['sections']
    mapping = [
        ('nonlocal_basis_and_preparation',['mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction'],['mean_buoyancy',basis_section]),
        ('transport_and_other_buoyancy_setup',['transport_excluding_thermodynamics'],['transport_setup','microrad_excluding_inversion']),
        ('thermodynamic_inversions',['thermodynamics_nested'],['thermodynamics_nested']),
        ('interpolation_assembly_mask',['momentum_interpolation_mask'],['interpolation','tendency_assembly_mask_timer_overhead']),
        ('damping',['damping'],['damping']),
        ('other_driver_timer_overhead',['other_driver_and_timer_overhead'],['other_driver_timer_overhead'])]
    comparison = [{'section':label,'fortran_ms_per_step':1000*sum(f[n]['wall_seconds_per_step'] for n in fn),
                   'matlab_ms_per_step':1000*sum(sections[n]['wall_seconds_per_step'] for n in mn)} for label,fn,mn in mapping]
    if cfg.get('timer_mode') == 'unsplit':
        first, assembly = comparison[0], comparison[3]
        first['section']='nonlocal_response_interpolation_assembly'
        for language in ('fortran','matlab'):
            first[language+'_ms_per_step']+=assembly[language+'_ms_per_step']
        comparison.pop(3)
    for name, expected in cfg['sha256'].items():
        if digest(name) != expected:raise ValueError('Provenance changed during profiling: '+name)
    report = {'duration_seconds':60,'steps':15,'dt_seconds':4,'sections':sections,
              'comparison':comparison,'fortran_ms_per_step':1000*f['driver_total']['wall_seconds_per_step'],
              'matlab_ms_per_step':1000*total/15,'matlab_process_wall_seconds':wall,
              'matlab_initialization_postprocessing_output_and_startup_wall_seconds':wall-total,
              'binary_identical_to_three_hour_prefix':True,'provenance_rechecked':True,
              'state_sha256':digest(state),'configuration':cfg,
              'scope':'Exclusive comparison aggregates are additive. MATLAB basis timing includes original coarsening/temporary arrays and disabled PMDv/PMD expressions; Fortran packs forcing separately. MATLAB microrad includes two inversion/sink evaluations per step even with precipitation disabled; Fortran inversion is once per step. Interpolation/assembly boundaries are approximate across architectures.',
              'limits':'One instrumented evolving serial Fortran run and one default-thread MATLAB run, measured sequentially at different times on shared hardware; timers can affect JIT/code generation. MATLAB process-minus-integration includes initialization, startup, postprocessing and output, not initialization alone.'}
    if cfg.get('timer_mode') == 'unsplit':
        report['scope']='Original NONLOCAL_RESPONSE including mean buoyancy, coarsening, original basis expression and interpolation is timed as a whole, without splitting its expression. Cross-language nonlocal/interpolation/assembly aggregate is additive; transport/setup and inversion call-count differences remain as before.'
    (work/'profile_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('comparison','fortran_ms_per_step','matlab_ms_per_step','binary_identical_to_three_hour_prefix')},indent=2),flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--control',action='store_true',help='Prepare the same minute without section instrumentation')
    parser.add_argument('--timer-mode',choices=['helper','split_only','unsplit'],default='helper')
    args = parser.parse_args();work=args.work.resolve()
    if args.run:run(work)
    else:prepare(work,args.control,args.timer_mode)
