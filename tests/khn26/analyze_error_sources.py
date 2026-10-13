#!/usr/bin/env python3
"""Attribute selected gate/replay discrepancies without changing the model."""
import argparse
import json
from pathlib import Path

import numpy as np

import common_precip
import multi
from run import digest


def analyze(replay, thermo):
    cfg = multi.verify(thermo)
    if json.loads((thermo/'status.json').read_text())['state'] != 'completed':
        raise ValueError('Common thermodynamic probes are incomplete')
    rcfg = json.loads((replay/'configuration.json').read_text())
    for path, expected in rcfg['sha256'].items():
        if digest(path) != expected:
            raise ValueError('Changed replay source or input')
    n = cfg['samples']
    labels = json.loads((thermo/'sample_labels.json').read_text())
    s = np.fromfile(thermo/'inputs.bin', '<f8').reshape((n,3), order='F')
    outputs = {name: np.fromfile(thermo/(name+'.bin'), '<f8').reshape((n,9), order='F')
               for name in ('matlab_outputs','fortran_outputs','fortran_fixed_thermo')}
    m,f,fixed = outputs.values()
    points = []
    for level in (57,61):
        def index(seed, solver):
            return next(i for i,l in enumerate(labels) if l['record']==145 and l['seed']==seed
                        and l['SSPRK_source']==solver and l['ace']==1 and l['level']==level)
        mm,mf,ff = index('matlab','matlab'),index('matlab','fortran'),index('fortran','fortran')
        direct = f[mm,7]-m[mm,7]
        dynamics = f[mf,7]-f[mm,7]
        inherited = f[ff,7]-f[mf,7]
        cases = {label: {'sample': labels[i], 'theta_e_qt_pressure': s[i].tolist(),
                         'matlab': dict(zip(common_precip.FIELDS,m[i].tolist())),
                         'fortran': dict(zip(common_precip.FIELDS,f[i].tolist())),
                         'fortran_fixed_thermo': dict(zip(common_precip.FIELDS,fixed[i].tolist()))}
                 for label,i in [('M_seed_M_SSPRK',mm),('M_seed_F_SSPRK',mf),('F_seed_F_SSPRK',ff)]}
        points.append({'ACE':1,'level':level,'height_m':50+100*(level-1),
            'step_one_based':146,'step_start_seconds':580,'step_end_seconds':584,
            'same_input_thermal_sink_delta_K_per_s':float(direct),
            'same_seed_SSPRK_input_effect_on_sink_K_per_s':float(dynamics),
            'inherited_seed_effect_on_sink_K_per_s':float(inherited),
            'total_independent_seed_sink_delta_K_per_s':float(f[ff,7]-m[mm,7]),
            'same_seed_SSPRK_input_delta_theta_e_qt':(s[mf,:2]-s[mm,:2]).tolist(),
            'same_seed_derivative_delta':float(f[mf,6]-f[mm,6]),
            'same_seed_four_second_theta_update_delta_K':float(
                (s[mf,0]+4*f[mf,7])-(s[mm,0]+4*m[mm,7])),
            'states':cases})
    count = len(rcfg['labels'])
    replay_arrays = {name:np.fromfile(replay/(name+'_outputs.bin'),'<f8').reshape((count,21,401,101))
                     for name in ('matlab','fortran')}
    case = next(i for i,l in enumerate(rcfg['labels']) if l['record']==145 and l['seed']=='matlab')
    for point in points:
        k=point['level']-1
        actual = replay_arrays['fortran'][case,16,k,0]-replay_arrays['matlab'][case,16,k,0]
        point['actual_same_seed_post_precipitation_theta_delta_K'] = float(actual)
        point['exact_rounded_update_reproduction'] = bool(actual==point['same_seed_four_second_theta_update_delta_K'])
    gate_work = Path(rcfg['source'])
    sink_arrays = {name:np.memmap(gate_work/'gate_native'/(name+'_precip_sinks.bin'),'<f8',mode='r',
                  shape=(150,101*401*2)) for name in ('matlab','fortran')}
    target = points[0]
    original = {name:float(a[145].reshape((101,401,2),order='F')[0,56,0]) for name,a in sink_arrays.items()}
    target['original_gate_sink_values_K_per_s'] = original
    target['exact_original_gate_sink_reproduction'] = bool(
        original['matlab']==target['states']['M_seed_M_SSPRK']['matlab']['theta_e_sink'] and
        original['fortran']==target['states']['F_seed_F_SSPRK']['fortran']['theta_e_sink'])
    reference_f = np.fromfile(replay/'fortran_environment_thermo.bin','<f8').reshape((401,5),order='F')[:,4]
    reference_m = np.fromfile(replay/'reference_tv.bin','<f8')
    k = int(np.argmax(abs(reference_f-reference_m)))
    phases = lambda a:np.select([(a[:,2]+a[:,3])==0,(a[:,2]>0)&(a[:,3]==0),
        (a[:,2]==0)&(a[:,3]>0),(a[:,2]>0)&(a[:,3]>0)],[0,1,2,3],default=-1)
    result = {'scope':'Local error-source controls on selected gate steps; no unique causal proof for full history.',
        'replay':json.loads((replay/'results.json').read_text()),
        'common_thermodynamics':json.loads((thermo/'results.json').read_text()),
        'phase_selection_mismatches':int(np.count_nonzero(phases(m)!=phases(f))),
        'selected_point_attribution':points,
        'independent_reference_Tv':{'max_abs_difference_K':float(abs(reference_f[k]-reference_m[k])),
            'fortran_minus_matlab_K':float(reference_f[k]-reference_m[k]),'level':k+1,'height_m':50+100*k},
        'analysis_source_sha256':digest(Path(__file__).resolve()),
        'configuration_sha256':{'replay':digest(replay/'configuration.json'),'thermo':digest(thermo/'configuration.json')},
        'evidence_sha256':{str(p):digest(p) for p in [replay/'fortran_environment_thermo.bin',
            replay/'reference_probe.F',replay/'reference_probe_commands.json',thermo/'results.json',
            thermo/'matlab_outputs.bin',thermo/'fortran_outputs.bin',thermo/'fortran_fixed_thermo.bin']}}
    multi.write(replay/'error_source_analysis.json',result)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('replay',type=Path)
    parser.add_argument('thermo',type=Path)
    args=parser.parse_args()
    result=analyze(args.replay.resolve(),args.thermo.resolve())
    print(json.dumps({'phase_mismatches':result['phase_selection_mismatches'],
        'reference':result['independent_reference_Tv'],
        'points':[{k:v for k,v in p.items() if k!='states'} for p in result['selected_point_attribution']]},indent=2))
