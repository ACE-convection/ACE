#!/usr/bin/env python3
"""Verify that a source-path-only change preserves saved model results exactly."""
import argparse
import hashlib
import json
from pathlib import Path

import netCDF4
import numpy as np


def compare(previous, current):
    assert previous.shape == current.shape, 'Output shape changed'
    assert np.isfinite(previous).all() and np.isfinite(current).all()
    result = {'shape': list(previous.shape),
              'exact_equal': bool(np.array_equal(previous, current)),
              'max_abs_difference': float(np.max(np.abs(previous-current)))}
    assert result['exact_equal'], 'Source normalization changed numerical outputs'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('previous', type=Path)
    parser.add_argument('current', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    records = [json.loads((p/'results.json').read_text())
               for p in [args.previous, args.current]]
    for key in ['case', 'profile_index', 'duration_seconds', 'dt_seconds',
                'output_step_seconds', 'precipitation', 'bubble', 'input_sha256']:
        assert records[0][key] == records[1][key], 'Configuration changed: '+key
    assert records[0].get('ace_mode', 'single') == records[1].get('ace_mode', 'single')
    result = {'scope': 'Same implementation before/after source normalization; '
                        'exact equality is not a MATLAB/Fortran acceptance criterion',
              'previous': str(args.previous), 'current': str(args.current),
              'baseline_commits': [r['baseline_commit'] for r in records],
              'production_sources_sha256': [r['production_sources_sha256'] for r in records],
              'commands': [r['commands'] for r in records],
              'input_sha256': records[0]['input_sha256'], 'matlab': {}}
    result['current_run_validation'] = {
        key: records[1][key] for key in
        ['finite_outputs', 'prognostic', 'initial_state', 'ranges',
         'precipitation_validation', 'matlab_version', 'gfortran_version']
        if key in records[1]}
    result['initial_seed'] = compare(
        np.fromfile(args.previous/'initial_override.bin', dtype='<f8'),
        np.fromfile(args.current/'initial_override.bin', dtype='<f8'))
    with netCDF4.Dataset(args.previous/'matlab.nc') as old, \
            netCDF4.Dataset(args.current/'matlab.nc') as new:
        assert set(old.variables) == set(new.variables)
        for name in old.variables:
            assert old[name].dimensions == new[name].dimensions
            if name == 'state':
                result['matlab']['prognostic'] = {
                    field: compare(np.asarray(old[name][:, :, i, :]),
                                   np.asarray(new[name][:, :, i, :]))
                    for i, field in enumerate(['theta_e', 'qt', 'MF'])}
            else:
                result['matlab'][name] = compare(np.asarray(old[name][:]),
                                                np.asarray(new[name][:]))
    duration = records[0]['duration_seconds']
    step = records[0]['output_step_seconds']
    shape = (8, 801, 3, duration//step+1)
    states = [np.fromfile(p/'fortran.bin', dtype='<f8').reshape(shape, order='F')
              for p in [args.previous, args.current]]
    result['fortran'] = {field: compare(states[0][:, :, i, :], states[1][:, :, i, :])
                         for i, field in enumerate(['theta_e', 'qt', 'MF'])}
    if records[0]['precipitation'] == 'enabled':
        result['fortran']['precipitation'] = compare(
            np.loadtxt(args.previous/'fort.97'), np.loadtxt(args.current/'fort.97'))
    result['artifact_sha256'] = [
        {name: hashlib.sha256((p/name).read_bytes()).hexdigest()
         for name in ['matlab.nc', 'fortran.bin', 'initial_override.bin']}
        for p in [args.previous, args.current]]
    result['status'] = 'passed: all saved numerical values exactly reproduced'
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False)+'\n')
    print(result['status'])


if __name__ == '__main__':
    main()
