#!/usr/bin/env python3
"""Validate and compare the isolated 15-minute blocked KHN26 profile."""
import argparse
import json
from pathlib import Path

import numpy as np

from profile_model import ROOT, sha


def report(work, output, plot_stem=None):
    profile_path=work/'profile_results.json'
    profile=json.loads(profile_path.read_text())
    baseline_path=ROOT/'tests/khn26/serial_benchmark_results.json'
    baseline=json.loads(baseline_path.read_text())
    short_path=ROOT/'tests/basis_layout/blocked_model_results.json'
    short=json.loads(short_path.read_text())
    short_run=next(r for r in short['runs'] if r['output_block']==4)
    short_module=Path(short_run['report_path']).parent/'profile_module.F'
    candidate_module=work/'profile_module.F'
    if candidate_module.read_bytes()!=short_module.read_bytes():
        raise ValueError('Candidate differs from validated one-minute module')
    benchmark=ROOT/'migration_work/khn26_single_serial_15min'
    state=work/'state_0.bin'
    original=benchmark/'full_fortran_states.bin'
    matlab=benchmark/'full_matlab_states.bin'
    if (profile['duration_seconds'],profile['steps'],profile['independent_output_block'])!=(900,225,4):
        raise ValueError('Expected four-output 15-minute candidate')
    if not profile['provenance_rechecked'] or len(profile['runs'])!=1:
        raise ValueError('Incomplete profile')
    run=profile['runs'][0]
    if not run['binary_identical'] or state.read_bytes()!=original.read_bytes():
        raise ValueError('Full 16-state byte identity failed')
    for path in (original,matlab):
        if sha(path)!=baseline['artifacts_sha256'][path.name]:
            raise ValueError('Frozen benchmark state hash differs: '+str(path))
    nc,nz,count=101,401,16
    if state.stat().st_size!=12+(count*(nc+1)*nz*3+nz)*8:
        raise ValueError('Fortran state stream size differs')
    if matlab.stat().st_size!=count*nc*nz*3*8:
        raise ValueError('MATLAB state stream size differs')
    m=np.memmap(matlab,'<f8',mode='r',shape=(count,nc*nz*3))
    errors=[]
    for index in range(count):
        offset=12+8*(index*(nc+1)*nz*3+(nz if index else 0))
        f=np.memmap(state,'<f8',mode='r',offset=offset,shape=((nc+1)*nz*3,)).reshape((nc+1,nz,3),order='F')
        reference=m[index].reshape((nc,nz,3),order='F')
        if not np.all(np.isfinite(f)) or not np.all(np.isfinite(reference)):
            raise ValueError('Nonfinite saved fields')
        if np.any(f[:,:,2]<0) or np.any(reference[:,:,2]<0):
            raise ValueError('Negative saved qt')
        errors.append(np.max(np.abs(f[:nc]-reference),axis=(0,1)).tolist())
    sections=run['sections']
    if sections['PMB_contraction']['calls']!=2025 or sections['damping']['calls']!=225:
        raise ValueError('Unexpected work count')
    exclusive=['transport_excluding_thermodynamics','thermodynamics_nested',
               'mean_buoyancy_and_coarsening','forcing_pack','PMB_contraction',
               'momentum_interpolation_mask','damping','other_driver_and_timer_overhead']
    if abs(sum(sections[name]['wall_seconds'] for name in exclusive)-
           sections['driver_total']['wall_seconds'])>1e-8:
        raise ValueError('Section totals are not additive')
    candidate=sections['driver_total']['wall_seconds_per_step']
    old=baseline['wall_seconds_per_step']
    result=dict(duration_seconds=900,steps=225,dt_seconds=4,saved_states=16,
        independent_output_block=4,flags=profile['flags'],
        integration_wall_seconds=dict(fortran_original=baseline['integration_wall_seconds']['fortran'],
            fortran_outputs4=sections['driver_total']['wall_seconds'],
            matlab_previous=baseline['integration_wall_seconds']['matlab']),
        wall_seconds_per_step=dict(fortran_original=old['fortran'],
            fortran_outputs4=candidate,matlab_previous=old['matlab']),
        speedup_vs_original=old['fortran']/candidate,
        step_time_reduction_percent=100*(1-candidate/old['fortran']),
        candidate_over_matlab_ratio=candidate/old['matlab'],
        candidate_module_identical_to_one_minute=True,
        one_minute_candidate_seconds_per_step=short_run['seconds_per_step'],
        candidate_process_wall_seconds=run['process_wall_seconds'],
        initialization_seconds=sections['initialization']['wall_seconds'],
        initial_PMB_pack_seconds=sections['initial_PMB_pack']['wall_seconds'],
        sections=sections,binary_identical_to_original_all_16_states=True,
        finite_saved_states=True,nonnegative_saved_qt=True,
        time_seconds=list(range(0,901,60)),max_abs_error_each_state_MF_theta_e_qt=errors,
        max_abs_error_MF_theta_e_qt=np.max(errors,axis=0).tolist(),
        source_reports_sha256={str(p):sha(p) for p in (profile_path,baseline_path,short_path)},
        candidate_module_sha256=sha(candidate_module),
        artifacts_sha256={str(p):sha(p) for p in (state,original,matlab)},
        reporting_script_sha256=sha(Path(__file__)),
        limits='One evolving 225-step serial candidate on a shared host. Original Fortran '
               'and default parallel MATLAB are previous uninstrumented 15-minute measurements, '
               'not fresh controls or equal CPU budgets. Candidate section timers may affect '
               'performance. Exact numerical agreement covers all 16 complete exported states; '
               'intermediate steps are not exported. No three-hour candidate validation or '
               'independent water/energy budget acceptance. Production sources unchanged.')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    (work/'report_blocked_15min.py').write_bytes(Path(__file__).read_bytes())
    if plot_stem:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig,axes=plt.subplots(1,2,figsize=(12,5),layout='constrained')
        values=list(result['wall_seconds_per_step'].values())
        axes[0].bar(['Fortran original\nprevious','Fortran outputs4\nnew profile',
                     'MATLAB default\nprevious'],values,color=['#94a3b8','#2563eb','#ea580c'])
        for i,value in enumerate(values):axes[0].text(i,value+.06,f'{value:.3f}',ha='center')
        axes[0].set_ylim(0,max(values)*1.16)
        axes[0].set_ylabel('Seconds per step (225-step average)')
        axes[0].set_title('Same 15 simulated minutes; initialization excluded')
        errors_array=np.asarray(errors)
        for j,name in enumerate(('MF','theta_e','qt')):
            axes[1].semilogy(np.arange(16),np.maximum(errors_array[:,j],1e-18),label=name)
        axes[1].set_xlabel('Simulated minutes')
        axes[1].set_ylabel('Maximum absolute difference, native units')
        axes[1].set_title('Candidate minus frozen MATLAB\nCandidate equals original Fortran byte-for-byte')
        axes[1].legend()
        for ax in axes:ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
        fig.supxlabel('Shared-host measurements; MATLAB default parallel resources differ from '
                      'serial Fortran. Saved-state diagnostics only.',fontsize=9)
        plot_stem.parent.mkdir(parents=True,exist_ok=True)
        for suffix in ('.png','.pdf'):fig.savefig(plot_stem.with_suffix(suffix),dpi=170)
        plt.close(fig)
    print(json.dumps({k:result[k] for k in ('wall_seconds_per_step','speedup_vs_original',
          'step_time_reduction_percent','candidate_over_matlab_ratio',
          'max_abs_error_MF_theta_e_qt')},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--plot',type=Path)
    args=parser.parse_args()
    report(args.work.resolve(),args.output.resolve(),args.plot)
