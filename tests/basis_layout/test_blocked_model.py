#!/usr/bin/env python3
"""Sequential one-minute production-flag controls and isolated blocked models."""
import argparse
import json
import statistics
from pathlib import Path

from profile_model import ROOT, run, sha

ORDER = [('control_before',1),('outputs4',4),('outputs8',8),('control_after',1)]
GROUPS = {
    'nonlocal_response_interpolation_assembly': [
        'mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction',
        'momentum_interpolation_mask'],
    'transport_and_other_buoyancy_setup':['transport_excluding_thermodynamics'],
    'thermodynamic_inversions':['thermodynamics_nested'],
    'damping':['damping'],
    'other_driver_timer_overhead':['other_driver_and_timer_overhead'],
}


def experiment(work):
    work.mkdir(parents=True,exist_ok=False)
    (work/'test_blocked_model.py').write_bytes(Path(__file__).read_bytes())
    results=[]
    for name,width in ORDER:
        print('Starting '+name,flush=True)
        run(work/name,1,60,True,width)
        path=work/name/'profile_results.json'
        report=json.loads(path.read_text())
        sample=report['runs'][0]
        if not report['provenance_rechecked'] or not sample['binary_identical']:
            raise ValueError('Incomplete acceptance')
        sections=sample['sections']
        if sections['PMB_contraction']['calls']!=135:
            raise ValueError('Unexpected PMB work count')
        results.append(dict(name=name,output_block=width,report_path=str(path),
            report_sha256=sha(path),state_sha256=sample['state_sha256'],
            integration_seconds=sections['driver_total']['wall_seconds'],
            seconds_per_step=sections['driver_total']['wall_seconds_per_step'],
            PMB_ms_per_call=1000*sections['PMB_contraction']['wall_seconds_per_call'],
            PMB_percent_of_driver=sample['PMB_percent_of_driver'],
            initialization_seconds=sections['initialization']['wall_seconds'],
            process_wall_seconds=sample['process_wall_seconds'],
            sections=sections,flags=report['flags']))
    if len({r['state_sha256'] for r in results})!=1:
        raise ValueError('Complete state identity between builds failed')
    if len({tuple(r['flags']) for r in results})!=1:
        raise ValueError('Compiler flags differ')
    baseline=statistics.mean(r['seconds_per_step'] for r in results if r['output_block']==1)
    matlab_path=ROOT/'tests/khn26/low_perturbation_comparison.json'
    matlab=json.loads(matlab_path.read_text())
    rows=[]
    for section,keys in GROUPS.items():
        row=dict(section=section,matlab_ms_per_step=next(
            r['matlab_ms_per_step'] for r in matlab['comparison'] if r['section']==section))
        for result in results:
            row[result['name']+'_ms_per_step']=1000*sum(
                result['sections'][key]['wall_seconds_per_step'] for key in keys)
        rows.append(row)
    for result in results:
        if abs(sum(r[result['name']+'_ms_per_step'] for r in rows)-
               1000*result['seconds_per_step'])>1e-8:
            raise ValueError('Sections are not additive')
        result['speedup_vs_mean_controls']=baseline/result['seconds_per_step']
    report=dict(order=ORDER,runs=results,comparison=rows,
        baseline_mean_seconds_per_step=baseline,
        matlab_seconds_per_step=matlab['matlab_ms_per_step']/1000,
        matlab_control=matlab['matlab_control'],matlab_source_report=str(matlab_path),
        matlab_source_report_sha256=sha(matlab_path),duration_seconds_each=60,
        steps_each=15,dt_seconds=4,binary_identity_all_runs=True,
        source_sha256={str(p):sha(p) for p in [Path(__file__).resolve(),
            ROOT/'tests/basis_layout/profile_model.py',
            ROOT/'tests/basis_layout/analyze_serial_simd.py']},
        limits='Sequential fresh-process one-minute Fortran samples on a shared host, '
               'with controls before/after; one candidate sample per width. No affinity '
               'pinning; identical original O2 serial flags/dependencies for every build. '
               'MATLAB section averages are the previously measured two unsplit samples '
               'at default settings, not newly rerun or equal CPU budgets. Exact state '
               'identity covers all exported prognostic fields at 0 and 60 seconds; '
               'intermediate steps are not exported. No long-run or hardware portability acceptance.')
    (work/'blocked_model_results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps([{k:r[k] for k in ('name','seconds_per_step','PMB_ms_per_call',
          'speedup_vs_mean_controls')} for r in results],indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    args=parser.parse_args()
    experiment(args.work.resolve())
