#!/usr/bin/env python3
"""Compare MATLAB timer modes repeatedly with one unchanged basis allocation."""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import time

import numpy as np
from profile_matlab import BASE, ROOT, FORTRAN, LABELS, digest, instrument, split_expression
from trajectory import replace_once

ORDER = ['control','unsplit','control','unsplit','control']


def prepare(work):
    original = (BASE/'single_main.m').read_text()
    case = json.loads((BASE/'single_case.json').read_text())
    if digest(BASE/'single_main.m') != case['generated_sha256']['single_main.m'] or digest(case['input']) != case['input_sha256']:
        raise ValueError('Frozen source/input changed')
    work.mkdir(parents=True,exist_ok=False)
    source = replace_once(original,'tspan = 0:60:10800;','tspan = 0:60:60;').replace(str(BASE),str(work))
    local_start = source.index('function X = timeint(')
    initialization = source[:source.index('%% Time-integration\n')]+source[local_start:]
    (work/'initialization.m').write_text(initialization)
    for mode in ('control','split_only','unsplit','helper'):
        transformed = source
        if mode == 'split_only':transformed=split_expression(source)
        elif mode != 'control':transformed=instrument(source,mode)
        local = transformed[transformed.index('function X = timeint('):]
        entry = f'''function [X,seconds,timing,cpu_seconds] = measure_{mode}(tspan,X0,dt,model)
global ACE_PROFILE_SECONDS ACE_PROFILE_CALLS
ACE_PROFILE_SECONDS=zeros(1,9); ACE_PROFILE_CALLS=zeros(1,9);
ace_cpu_started=cputime;
ace_outer_clock=tic;
X=timeint(@ssprk93,tspan,X0,dt,model);
seconds=toc(ace_outer_clock);
cpu_seconds=cputime-ace_cpu_started;
ACE_PROFILE_SECONDS(9)=seconds; ACE_PROFILE_CALLS(9)=1;
timing=[ACE_PROFILE_SECONDS;ACE_PROFILE_CALLS];
end

'''
        (work/f'measure_{mode}.m').write_text(entry+local)
    launcher = (BASE/'full_launch.m').read_text().replace(str(BASE),str(work))
    launcher = launcher[:launcher.index("run('")]
    launcher += f'''addpath('{work}');
fprintf('Natural MATLAB computational thread cap = %d\\n',maxNumCompThreads);
ace_initialization_clock=tic;
run('{work}/initialization.m');
fprintf('Paired initialization wall seconds = %.17g\\n',toc(ace_initialization_clock));
ace_order={{{','.join("'"+mode+"'" for mode in ORDER)}}};
ace_samples=fopen('{work}/samples.tsv','w');
ace_sections=fopen('{work}/sections.tsv','w');
for ace_repeat=1:numel(ace_order)
  ace_mode=ace_order{{ace_repeat}};
  ace_measure=str2func(['measure_' ace_mode]);
  [ace_X,ace_seconds,ace_timing,ace_cpu_seconds]=ace_measure(tspan,X0,dt,model);
  fprintf(ace_samples,'%d %s %.17g %.17g\\n',ace_repeat,ace_mode,ace_seconds,ace_cpu_seconds);
  for ace_slot=1:9
    fprintf(ace_sections,'%d %d %.17g %d\\n',ace_repeat,ace_slot,ace_timing(1,ace_slot),ace_timing(2,ace_slot));
  end
  ace_fid=fopen(sprintf('{work}/state_%02d.bin',ace_repeat),'w');
  for ace_step=1:size(ace_X,4)
    ace_v=permute(ace_X(:,[3,1,2],:,ace_step),[3,1,2]);fwrite(ace_fid,ace_v(:),'double');
  end
  fclose(ace_fid);
  fprintf('PAIRED_SAMPLE %d %s %.17g CPU %.17g\\n',ace_repeat,ace_mode,ace_seconds,ace_cpu_seconds);
end
fclose(ace_samples);fclose(ace_sections);
'''
    (work/'launch.m').write_text(launcher)
    paths = [Path(case['input']),BASE/'single_main.m',BASE/'full_matlab_states.bin',
             ROOT/'matlab/util_timeint/ssprk93.m',FORTRAN/'profile_results.json',
             Path(__file__).resolve(),Path(__file__).with_name('profile_matlab.py'),*work.glob('*.m')]
    cfg = {'order':ORDER,'duration_seconds':60,'steps':15,'dt_seconds':4,'case':case,
           'command':['matlab','-batch',f"run('{work}/launch.m')"],
           'sha256':{str(p):digest(p) for p in paths},
           'scope':'One MATLAB process and one unchanged PMB/model allocation, repeated initial state for each evolving 60 s sample; original default thread settings, no affinity pinning. Function entry/JIT context differs from the original script; control samples bracket and interleave variants.',
           'environment':{k:os.environ.get(k) for k in ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS','MATLAB_PREFDIR')}}
    (work/'configuration.json').write_text(json.dumps(cfg,indent=2)+'\n')


def run(work):
    cfg=json.loads((work/'configuration.json').read_text())
    def verify():
        for p,h in cfg['sha256'].items():
            if digest(p)!=h:raise ValueError('Provenance changed: '+p)
    verify();started=time.monotonic()
    with (work/'matlab.log').open('x') as log:
        subprocess.run(cfg['command'],cwd=work,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,check=True)
    wall=time.monotonic()-started
    with (BASE/'full_matlab_states.bin').open('rb') as stream:reference=stream.read(2*101*401*3*8)
    samples=[]
    for line in (work/'samples.tsv').read_text().splitlines():
        index,mode,seconds,cpu=line.split();index=int(index)
        state=work/f'state_{index:02d}.bin'
        if state.read_bytes()!=reference:raise ValueError('Paired output differs: '+str(index))
        if not np.isfinite(np.fromfile(state,'<f8')).all():raise ValueError('Nonfinite state')
        samples.append({'index':index,'mode':mode,'integration_wall_seconds':float(seconds),
                        'wall_seconds_per_step':float(seconds)/15,'matlab_cputime_seconds':float(cpu),'binary_identical':True,
                        'state_sha256':digest(state),'sections':{}})
    if [s['mode'] for s in samples]!=ORDER:raise ValueError('Incomplete sample order')
    for line in (work/'sections.tsv').read_text().splitlines():
        index,slot,seconds,calls=line.split();s=samples[int(index)-1]
        label=LABELS[int(slot)-1]
        if s['mode']=='unsplit' and label=='basis_contraction':label='nonlocal_response_total'
        s['sections'][label]={'wall_seconds':float(seconds),'calls':int(calls),'ms_per_step':1000*float(seconds)/15}
    for s in samples:
        if s['mode'] in ('unsplit','helper'):
            basis='nonlocal_response_total' if s['mode']=='unsplit' else 'basis_contraction'
            if s['sections'][basis]['calls']!=135 or s['sections']['microrad_total']['calls']!=30:
                raise ValueError('Unexpected step/stage counts')
    aggregate={mode:{'median_seconds_per_step':statistics.median(s['wall_seconds_per_step'] for s in samples if s['mode']==mode),
                     'range_seconds_per_step':[min(s['wall_seconds_per_step'] for s in samples if s['mode']==mode),max(s['wall_seconds_per_step'] for s in samples if s['mode']==mode)]}
               for mode in dict.fromkeys(ORDER)}
    f=json.loads((FORTRAN/'profile_results.json').read_text())['runs'][0]['sections']
    low=[s['sections'] for s in samples if s['mode']=='unsplit']
    m={k:statistics.median(s[k]['ms_per_step'] for s in low) for k in low[0]}
    nonlocal_total=m['tendency_total']-m['transport_setup']
    # Both unsplit samples contribute to an additive mean/median (two samples).
    comparison=[
        {'section':'nonlocal_response_interpolation_assembly','fortran_ms_per_step':1000*sum(f[k]['wall_seconds_per_step'] for k in ('mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction','momentum_interpolation_mask')),'matlab_ms_per_step':nonlocal_total},
        {'section':'transport_and_other_buoyancy_setup','fortran_ms_per_step':1000*f['transport_excluding_thermodynamics']['wall_seconds_per_step'],'matlab_ms_per_step':m['transport_setup']+m['microrad_total']-m['thermodynamics_nested']},
        {'section':'thermodynamic_inversions','fortran_ms_per_step':1000*f['thermodynamics_nested']['wall_seconds_per_step'],'matlab_ms_per_step':m['thermodynamics_nested']},
        {'section':'damping','fortran_ms_per_step':1000*f['damping']['wall_seconds_per_step'],'matlab_ms_per_step':m['damping']},
        {'section':'other_driver_timer_overhead','fortran_ms_per_step':1000*f['other_driver_and_timer_overhead']['wall_seconds_per_step'],'matlab_ms_per_step':m['driver_total']-m['tendency_total']-m['microrad_total']-m['damping']}]
    verify()
    report={'configuration':cfg,'samples':samples,'aggregate':aggregate,'comparison':comparison,
            'matlab_ms_per_step':m['driver_total'],'fortran_ms_per_step':1000*f['driver_total']['wall_seconds_per_step'],
            'process_wall_seconds':wall,'provenance_rechecked':True,
            'limits':'Repeated one-minute samples in one initialized MATLAB process; same allocation/initial states, default threading, shared host. Controls estimate measurement sensitivity; no unmeasured overhead correction is applied. MATLAB nonlocal function includes interpolation, so compare combined nonlocal/interpolation/assembly groups.'}
    (work/'paired_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'aggregate':aggregate,'comparison':comparison},indent=2),flush=True)


def compare_with_fortran(work, fortran_path):
    """Combine saved MATLAB samples with an additional verified Fortran run."""
    matlab_path=work/'paired_results.json'
    m=json.loads(matlab_path.read_text());fr=json.loads(fortran_path.read_text())
    if not m['provenance_rechecked'] or not fr['provenance_rechecked'] or not fr['runs'][0]['binary_identical']:
        raise ValueError('Reports lack validated provenance/output identity')
    if not all(s['binary_identical'] for s in m['samples']):raise ValueError('MATLAB output identity failed')
    if m['configuration']['case']['input_sha256']!=fr['case']['input_sha256'] or fr['steps']!=15 or fr['duration_seconds']!=60:
        raise ValueError('Reports describe different inputs/durations')
    f=fr['runs'][0]['sections']
    groups={
        'nonlocal_response_interpolation_assembly':['mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction','momentum_interpolation_mask'],
        'transport_and_other_buoyancy_setup':['transport_excluding_thermodynamics'],
        'thermodynamic_inversions':['thermodynamics_nested'],
        'damping':['damping'],
        'other_driver_timer_overhead':['other_driver_and_timer_overhead']}
    rows=[{**row,'fortran_ms_per_step':1000*sum(f[k]['wall_seconds_per_step'] for k in groups[row['section']])} for row in m['comparison']]
    report={'duration_seconds_each':60,'steps_each':15,'dt_seconds':4,'comparison':rows,
            'fortran_ms_per_step':1000*f['driver_total']['wall_seconds_per_step'],'matlab_ms_per_step':m['matlab_ms_per_step'],
            'matlab_control':m['aggregate']['control'],'matlab_unsplit':m['aggregate']['unsplit'],
            'matlab_cpu_to_wall_ratios':[s['matlab_cputime_seconds']/s['integration_wall_seconds'] for s in m['samples']],
            'source_reports':{str(p):digest(p) for p in (matlab_path,fortran_path)},
            'binary_identity_all_samples':True,
            'method':'Fortran: fresh serial production one-minute profile average. MATLAB: component medians over two unsplit profiles (equivalent to their mean), interleaved with three original-expression controls in one process and one PMB allocation. Nonlocal/interpolation/assembly are combined; no scalar overhead correction is applied.',
            'limits':'Shared hardware, one Fortran run and two MATLAB profiled samples. Control range documents observed variability; it does not prove zero instrumentation overhead. Default parallel MATLAB resources and serial Fortran differ; CPU/wall ratios are not thread-count measurements.'}
    for language in ('fortran','matlab'):
        if abs(sum(r[language+'_ms_per_step'] for r in rows)-report[language+'_ms_per_step'])>1e-8:
            raise ValueError('Section breakdown does not sum to integration total')
    (work/'combined_profile_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('work',type=Path)
    mode=p.add_mutually_exclusive_group();mode.add_argument('--run',action='store_true');mode.add_argument('--compare-fortran',type=Path)
    a=p.parse_args()
    if a.run:run(a.work.resolve())
    elif a.compare_fortran:compare_with_fortran(a.work.resolve(),a.compare_fortran.resolve())
    else:prepare(a.work.resolve())
