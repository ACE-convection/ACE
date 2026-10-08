#!/usr/bin/env python3
"""Locate existing ten-minute state, SSPRK tendency and native sink maxima."""
import argparse
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset

import multi
from run import digest


def locate(m, f, field, height):
    delta = f-m
    ace, level = np.unravel_index(np.argmax(abs(delta)), delta.shape)
    return {'field': field, 'ACE': int(ace+1), 'level': int(level+1),
            'height_m': float(height[level]), 'matlab': float(m[ace, level]),
            'fortran': float(f[ace, level]), 'fortran_minus_matlab': float(delta[ace, level]),
            'max_abs_error': float(abs(delta[ace, level]))}


def analyze(work):
    cfg = multi.verify(work)
    gate = json.loads((work / 'gate_passed.json').read_text())
    if not gate['passed'] or gate['configuration_sha256'] != digest(work / 'configuration.json'):
        raise ValueError('Completed gate provenance differs')
    with Dataset(cfg['case']['input']) as ds:
        scalar = np.asarray(ds['z'][:])
        interface = np.asarray(ds['zm'][:])
    output = {'scope': 'Location of maxima on independently evolving trajectories; not a common-state causal attribution.',
              'source_sha256': digest(Path(__file__).resolve()), 'gates': {}}
    for tag in ('gate_none', 'gate_native'):
        states = json.loads((work / (tag+'_state_results.json')).read_text())
        tendencies = json.loads((work / (tag+'_tendency_results.json')).read_text())
        for report in (states, tendencies):
            for path, expected in report['artifacts_sha256'].items():
                p = Path(path) if Path(path).is_absolute() else work / tag / path
                if digest(p) != expected:
                    raise ValueError('Changed gate artifact: '+str(p))
        state_points = [None]*3
        per_ace = np.zeros((101, 3))
        for record, (m, f) in enumerate(zip(multi.state_frames(work, tag, 'matlab', 151),
                                         multi.state_frames(work, tag, 'fortran', 151))):
            d = abs(f-m)
            per_ace = np.maximum(per_ace, d.max(axis=1))
            for field, name in enumerate(states['field_order']):
                point = locate(m[:, :, field], f[:, :, field], name,
                               interface if field == 0 else scalar)
                if state_points[field] is None or point['max_abs_error'] > state_points[field]['max_abs_error']:
                    state_points[field] = {**point, 'time_seconds': record*4}
        if [p['max_abs_error'] for p in state_points] != states['max_abs_error']:
            raise ValueError('State maxima do not reproduce original gate')
        tendency_points = []
        # Original verified reports identify candidate steps; read every stage
        # of those steps to recover exact spatial maxima without rescanning 1,350 frames.
        per_step = np.asarray(tendencies['max_abs_error_each_step'])
        for field, name in enumerate(tendencies['field_order']):
            step = int(np.argmax(per_step[:, field]))
            best = None
            for stage in range(9):
                frame = step*9+stage
                pair = [np.memmap(work / tag / (language+'_tendencies.bin'), '<f8', mode='r',
                        offset=frame*101*401*3*8, shape=(101*401*3,)).reshape((101,401,3), order='F')
                        for language in ('matlab', 'fortran')]
                point = locate(pair[0][:,:,field], pair[1][:,:,field], name,
                               interface if field == 0 else scalar)
                if best is None or point['max_abs_error'] > best['max_abs_error']:
                    best = {**point, 'step_one_based': step+1, 'stage_one_based': stage+1,
                            'step_start_seconds': step*4, 'step_end_seconds': (step+1)*4}
            if best['max_abs_error'] != tendencies['max_abs_error'][field]:
                raise ValueError('Tendency maximum does not reproduce original gate')
            tendency_points.append(best)
        result = {'states': state_points, 'tendencies': tendency_points,
                  'state_max_abs_error_per_ACE': per_ace.tolist(),
                  'ACE_101_state_max_abs_error': per_ace[-1].tolist(),
                  'ACE_98_to_101_state_max_abs_error': per_ace[97:].max(axis=0).tolist()}
        if tag == 'gate_native':
            precip = json.loads((work / (tag+'_precipitation_results.json')).read_text())
            for path, expected in precip['artifacts_sha256'].items():
                if digest(path) != expected:
                    raise ValueError('Changed precipitation artifact')
            sinks = [None]*2
            arrays = [np.memmap(work / tag / (language+'_precip_sinks.bin'), '<f8', mode='r',
                      shape=(150, 101*401*2)) for language in ('matlab', 'fortran')]
            for step in range(150):
                m,f = [a[step].reshape((101,401,2), order='F') for a in arrays]
                for field, name in enumerate(precip['field_order']):
                    point = locate(m[:,:,field], f[:,:,field], name, scalar)
                    if sinks[field] is None or point['max_abs_error'] > sinks[field]['max_abs_error']:
                        sinks[field] = {**point, 'step_one_based': step+1,
                            'step_start_seconds': step*4, 'step_end_seconds': (step+1)*4,
                            'evaluation': 'After SSPRK, before precipitation and damping'}
            if [p['max_abs_error'] for p in sinks] != precip['max_abs_error']:
                raise ValueError('Sink maxima do not reproduce original gate')
            result['precipitation_sinks'] = sinks
        output['gates'][tag] = result
    output['configuration_sha256'] = digest(work / 'configuration.json')
    multi.write(work / 'maximum_difference_locations.json', output)
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    args = parser.parse_args()
    report = analyze(args.work.resolve())
    print(json.dumps({tag: {key: value for key, value in result.items()
                      if key != 'state_max_abs_error_per_ACE'}
                      for tag, result in report['gates'].items()}, indent=2))
