#!/usr/bin/env python3
"""Preserve evidence from the existing aligned timestep runner; set no tolerance."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

import netCDF4
import numpy as np

from compare import metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--ice-diagnostic', type=Path,
                        help='Optional comparison.json from compare_ice_forward.py')
    parser.add_argument('--cases', nargs='+',
                        choices=['single','single_precip','multi','multi_precip',
                                 'single_ice_precip','multi_ice_precip'],
                        default=['single','single_precip','multi','multi_precip'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve()
    configuration = json.loads((work / 'configuration.json').read_text())
    unchanged = {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest() == digest
        for name, digest in configuration['sources_sha256'].items()
    }
    assert all(unchanged.values()), 'Source changed since test preparation'
    report = {
        'validated_at_utc': datetime.now(timezone.utc).isoformat(),
        'configuration': configuration,
        'sources_unchanged_since_preparation': unchanged,
        'branch': subprocess.check_output(
            ['git', 'branch', '--show-current'], cwd=root, text=True).strip(),
        'build_commands': json.loads((args.build / 'build_commands.json').read_text()),
        'compiler_version': subprocess.check_output(
            ['gfortran', '--version'], text=True).splitlines()[0],
        'scope': 'Matched 4-second/120-second trajectories; no acceptance tolerance or production source change',
        'runs': {},
    }
    report['validation_tools_sha256'] = {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted((root / 'tests/alignment').glob('*')) if p.is_file()
    }
    for mode in args.cases:
        run = json.loads((work / f'{mode}_comparison.json').read_text())
        with netCDF4.Dataset(work / f'matlab_{mode}.nc') as ds:
            matlab = np.asarray(ds['state'][:]).transpose(3, 2, 1, 0)
            times = np.asarray(ds['time'][:])
            version = ds.getncattr('matlab_version')
        binary = np.fromfile(work / f'fortran_{mode}.bin', dtype='<f8')
        # Runner layout: initial state, raw tendency, diagnostics/operators,
        # reference fields, then thirty complete post-step states.
        header = 14 * 8 * 801 + 801 + 16
        assert binary.size == header + 30 * 8 * 801 * 3
        first = binary[:8*801*3].reshape((8, 801, 3), order='F').transpose(1, 2, 0)
        tail = binary[header:].reshape((8, 801, 3, 30), order='F').transpose(1, 2, 0, 3)
        fortran = np.concatenate([first[..., None], tail], axis=3)
        assert matlab.shape == fortran.shape == (801, 3, 8, 31)
        assert np.array_equal(times, np.arange(0, 121, 4))
        assert np.isfinite(matlab).all() and np.isfinite(fortran).all()
        assert run['initial_state']['exact_equal']
        run['matlab_version'] = version
        run['all_31_samples'] = {
            name: metrics(matlab[:, j, :, :], fortran[:, j, :, :])
            for j, name in enumerate(['theta_e', 'qt', 'MF'])
        }
        run['minimum_qt'] = {
            'matlab': float(matlab[:, 1].min()),
            'fortran': float(fortran[:, 1].min()),
        }
        if 'ice_precip' in mode:
            evidence = work / f'{mode}_ice_evidence.json'
            run['ice_precipitation_accumulation'] = json.loads(evidence.read_text())
            with netCDF4.Dataset(work / f'matlab_{mode}_diagnostics.nc') as ds:
                md = np.asarray(ds['diagnostic'][:]).transpose(3, 2, 1, 0)
            fd = np.fromfile(work / f'fortran_{mode}_diagnostics.bin', dtype='<f8')
            fd = fd.reshape((8, 801, 5, 4), order='F').transpose(1, 2, 0, 3)
            pulse = run['pulse_ace'] - 1
            run['ice_snapshot_ranges'] = {}
            for language, diagnostic in [('matlab', md), ('fortran', fd)]:
                selected = diagnostic[150:170, :, pulse, :]
                assert np.isfinite(selected).all()
                assert (selected[:, 0] < 273.1636783445389).all()
                assert (selected[:, 3] > 0).all() and (selected[:, 2] == 0).all()
                run['ice_snapshot_ranges'][language] = {
                    'temperature_min_K': float(selected[:, 0].min()),
                    'temperature_max_K': float(selected[:, 0].max()),
                    'qi_min_kgkg': float(selected[:, 3].min()),
                    'qi_max_kgkg': float(selected[:, 3].max()),
                    'ql_exact_zero': True,
                    'sample_times_seconds': [0, 4, 60, 120],
                }
        report['runs'][mode] = run
    report['thermo'] = json.loads((work / 'thermo_comparison.json').read_text())
    report['thermo']['scope'] = (
        'Ten identical manufactured inputs; active inverse, forward theta_e and '
        'isolated precipitation sinks. Operator order is exercised by the trajectories.')
    trace = args.ice_diagnostic or work / 'ice_forward_trace/comparison.json'
    if trace.exists():
        report['ice_forward_diagnostic'] = json.loads(trace.read_text())
    report['limitations'] = [
        'No long production simulation, release equivalence or approved tolerance',
        ('Mixed-phase sink is a standalone probe, not a mixed-phase trajectory'
         if any('ice_precip' in mode for mode in args.cases) else
         'Ice/mixed-phase sinks are standalone probes, not ice-precipitating trajectories'),
        'Existing MATLAB/Fortran reference-Tv, boundary and geometry differences retained',
        'The 1200-case pure-ice endpoint counterexample remains unresolved',
        'GNU binary64 build only; Intel compiler behavior not tested',
        'Water budgets are diagnostics, not a closed conservation test',
        'WENO levels 1 and 801 are unassigned by Fortran and excluded from operator metrics',
        'Plotting/plume/radiation diagnostics skipped through existing test access',
    ]
    report['artifacts'] = {
        str(p.relative_to(work)): {
            'bytes': p.stat().st_size,
            'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
        }
        for p in sorted(work.rglob('*')) if p.is_file()
    }
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print(args.output)


if __name__ == '__main__':
    main()
