#!/usr/bin/env python3
"""Run the fixed Manus case used for initial v0.18/v0.20/v0.24 comparisons."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import netCDF4
import numpy as np
from compare import metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', nargs='?', type=Path, help='Fresh output directory')
    parser.add_argument('--check-only', action='store_true', help='Verify case/input/reference without integration')
    parser.add_argument('--verify-run', action='store_true', help='Verify and compare an existing completed run without integration')
    parser.add_argument('--matlab', default='matlab')
    parser.add_argument('--case', choices=['manus_saturated_bubble', 'manus_saturated_bubble_precip'],
                        default='manus_saturated_bubble', help='Select the archived Manus reference configuration')
    args = parser.parse_args()
    if args.check_only and args.verify_run:
        parser.error('Use either --check-only or --verify-run')
    root = Path(__file__).resolve().parents[2]
    case_path = root/'tests/cases'/ (args.case+'.json')
    case = json.loads(case_path.read_text())
    input_file = root/case['input']['path']
    if not input_file.exists():
        raise SystemExit('Missing Manus input: run git lfs pull; see tests/README.md')
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    if sha(input_file) != case['input']['sha256']:
        raise SystemExit('Manus input hash mismatch; obtain the pinned Git LFS object')
    with netCDF4.Dataset(input_file) as ds:
        assert ds.case_name == case['input']['case_name']
        assert int(ds.profile_index) == case['input']['profile_index']
        assert int(ds.arm) == case['input']['arm']
    reference = root/case['reference']['path']
    for name, expected in case['reference']['files_sha256'].items():
        assert sha(reference/name) == expected, 'Reference hash mismatch: '+name
    integration = case['integration']
    precipitation = args.case == 'manus_saturated_bubble_precip'
    assert case['case_id'] == args.case
    assert integration['dt_seconds'] == 4 and integration['precipitation'] == precipitation
    assert integration['duration_seconds'] == 10800 and integration['output_step_seconds'] == 60
    assert integration['method'] == 'SSPRK93' and not integration['mf_diffusion']
    assert case['bubble']['levels_one_based'] == [11, 51]
    assert case['bubble']['delta_temperature_K'] == 1 and case['bubble']['saturated']
    assert case['bubble']['initial_condensate_kg_per_kg'] == 0
    assert case['single_ace']['active_ace_one_based'] == 1
    with np.load(reference/'mf.npz') as data:
        assert np.array_equal(data['time_seconds'], np.arange(0, 10801, 60))
        assert np.array_equal(data['height_m'], np.arange(0, 40001, 50))
        for name in ['matlab', 'fortran']:
            assert data[name].shape == (181, 801) and np.isfinite(data[name]).all()
    if precipitation:
        with np.load(reference/'precipitation.npz') as data:
            water = data['matlab_qt_accumulation']
            sinks = data['fortran_step_diagnostics']
            assert water.shape == (181, 8, 801) and np.isfinite(water).all()
            assert np.all(water[0] == 0) and np.all(np.diff(water, axis=0) >= 0) and water[-1].max() > 0
            assert sinks.shape == (2700, 4) and np.isfinite(sinks).all()
            assert np.array_equal(sinks[:, 0], np.arange(4, 10801, 4))
            assert np.all(sinks[:, 3] >= 0) and sinks[:, 1].sum() > 0
    print(args.case+': pinned input and archived reference verified.', flush=True)
    if args.check_only:
        return
    if args.work is None:
        parser.error('Provide a fresh output directory')
    work = args.work.resolve()
    if not args.verify_run:
        command = [sys.executable, str(root/'tests/alignment/run_sounding_case.py'),
                        str(work), '--input', str(input_file), '--saturated-bubble',
                        '--duration', str(integration['duration_seconds']),
                        '--output-step', str(integration['output_step_seconds']),
                        '--matlab', args.matlab]
        if precipitation:
            command.append('--precipitation')
        subprocess.run(command, check=True)
    report = json.loads((work/'results.json').read_text())
    assert report['case'] == 'manus' and report['profile_index'] == 208
    assert report['input_sha256'] == case['input']['sha256']
    assert report['duration_seconds'] == 10800 and report['dt_seconds'] == 4
    assert report['output_step_seconds'] == 60
    assert report['precipitation'] == ('enabled' if precipitation else 'disabled')
    if precipitation:
        validation = report['precipitation_validation']
        assert validation['matlab_accumulation_finite_monotonic']
        assert validation['matlab_final_qt_removal_max_kg_per_kg'] > 0
        assert validation['fortran_sink_finite_nonnegative']
        assert validation['fortran_updates_with_positive_loss'] > 0
        for name in ['precipitation.npz', 'matlab.nc', 'fortran.bin']:
            assert sha(work/name) == report['artifacts_sha256'][name], 'Run artifact hash mismatch: '+name
    assert report['bubble']['enabled'] and report['bubble']['levels_one_based'] == [11, 51]
    assert report['bubble']['delta_T_K'] == 1 and report['finite_outputs']
    assert all(value['qt_min'] >= 0 for value in report['ranges'].values())
    seed = np.fromfile(work/'initial_override.bin', dtype='<f8').reshape((8, 801, 3), order='F')
    evidence = np.fromfile(work/'bubble_initial.bin', dtype='<f8').reshape((801, 4), order='F')
    mask = np.zeros(801, dtype=bool); mask[10:51] = True
    with netCDF4.Dataset(input_file) as ds:
        theta = np.asarray(ds['theta_e_zc'][:]); q = np.asarray(ds['qt_zc'][:])
        assert np.array_equal(evidence[:, 0], ds['T_zm'][:])
        assert np.array_equal(evidence[:, 1], ds['p_mf'][:])
        assert np.array_equal(evidence[:, 3], ds['zm'][:])
    assert np.array_equal(seed[0, mask, 1], evidence[mask, 2])
    assert np.array_equal(seed[0, ~mask, 0], theta[~mask])
    assert np.array_equal(seed[0, ~mask, 1], q[~mask])
    assert np.array_equal(seed[1:, :, 0], np.tile(theta, (7, 1)))
    assert np.array_equal(seed[1:, :, 1], np.tile(q, (7, 1)))
    assert np.isfinite(seed).all()
    (work/'reference_case.json').write_text(case_path.read_text())
    with np.load(reference/'mf.npz') as previous, np.load(work/'mf.npz') as current:
        for coordinate in ['time_seconds', 'height_m']:
            assert np.array_equal(previous[coordinate], current[coordinate])
        for name in ['matlab', 'fortran']:
            assert current[name].shape == previous[name].shape and np.isfinite(current[name]).all()
        comparison = {name: metrics(previous[name], current[name]) for name in ['matlab', 'fortran']}
    (work/'reference_comparison.json').write_text(json.dumps({
        'reference_source_commit': case['reference']['source_commit'],
        'status': 'Descriptive metrics; no byte equality or acceptance tolerance required',
        'mf': comparison}, indent=2)+'\n')
    print('Completed run settings, bubble initialization and MF reference comparison verified.')


if __name__ == '__main__':
    main()
