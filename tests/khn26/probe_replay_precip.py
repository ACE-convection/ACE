#!/usr/bin/env python3
"""Isolate precipitation roundoff on saved post-SSPRK multiACE replay states."""
import argparse
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset

import common_precip
import multi
from run import ROOT, digest


def prepare(work, replay):
    cfg = json.loads((replay / 'configuration.json').read_text())
    source = Path(cfg['source'])
    production = json.loads((source / 'configuration.json').read_text())
    with Dataset(production['case']['input']) as ds:
        pressure = np.asarray(ds['p_zc'][:])
    samples, labels = [], []
    provenance = [Path(__file__).resolve(), replay / 'configuration.json',
                  Path(production['case']['input'])]
    for language in ('matlab', 'fortran'):
        path = replay / (language + '_outputs.bin')
        provenance.append(path)
        raw = np.fromfile(path, '<f8').reshape((len(cfg['labels']), 21, 401, 101))
        for case, label in enumerate(cfg['labels']):
            # Include the whole ACE 1 profile and the late-error boundary band.
            for ace in (1, 98, 99, 100, 101):
                levels = range(401) if ace == 1 else range(49, 101)
                for k in levels:
                    samples.append([raw[case, 13, k, ace-1], raw[case, 14, k, ace-1], pressure[k]])
                    labels.append({**label, 'SSPRK_source': language, 'ace': ace,
                                   'level': k+1, 'height_m': 50+100*k})
    common_precip.prepare(work, Path(production['gate_work']),
                          sample_data=(samples, labels), provenance=provenance)
    multi.write(work / 'selection.json', {'replay': str(replay),
        'scope': 'Common theta_e/qt/p and fixed MATLAB T/q/ql/qi; no integration or formula changes.',
        'dt_seconds': 4, 'provenance_sha256': {str(p): digest(p) for p in provenance}})


def attribute(work):
    cfg = json.loads((work / 'configuration.json').read_text())
    n = cfg['samples']
    labels = json.loads((work / 'sample_labels.json').read_text())
    arrays = {name: np.fromfile(work / (name + '.bin'), '<f8').reshape((n, 9), order='F')
              for name in ('matlab_outputs', 'fortran_outputs', 'fortran_fixed_thermo')}
    m, f, fixed = (arrays[name] for name in arrays)
    target = next(i for i, label in enumerate(labels) if label['minute'] == 180
                  and label['seed'] == 'matlab' and label['SSPRK_source'] == 'matlab'
                  and label['ace'] == 1 and label['level'] == 82)
    # Algebraic attribution of independent-inversion sink difference:
    # F(F thermo)-M(M thermo) = [F(F thermo)-F(M thermo)] + [F(M thermo)-M(M thermo)].
    indices = sorted(set([target, int(np.argmax(abs(f[:, 7]-m[:, 7]))),
                          int(np.argmax(abs(fixed[:, 7]-m[:, 7])))]))
    points = []
    for i in indices:
        delta_base = fixed[i, 4]-m[i, 4]
        delta_pert = fixed[i, 5]-m[i, 5]
        derivative = fixed[i, 6]-m[i, 6]
        points.append({'sample': labels[i], 'is_replay_target': i == target,
            'matlab': dict(zip(common_precip.FIELDS, m[i].tolist())),
            'fortran_independent': dict(zip(common_precip.FIELDS, f[i].tolist())),
            'fortran_fixed_thermo': dict(zip(common_precip.FIELDS, fixed[i].tolist())),
            'fixed_thermo_base_delta_K': float(delta_base),
            'fixed_thermo_perturbed_delta_K': float(delta_pert),
            'fixed_thermo_derivative_delta': float(derivative),
            'derivative_delta_from_forward_roundoff': float((delta_pert-delta_base)/1e-8),
            'independent_sink_delta_K_per_s': float(f[i, 7]-m[i, 7]),
            'inversion_contribution_K_per_s': float(f[i, 7]-fixed[i, 7]),
            'fixed_thermo_contribution_K_per_s': float(fixed[i, 7]-m[i, 7]),
            'derivative_sink_contribution_K_per_s': float(m[i, 8]*derivative),
            'qt_sink_contribution_K_per_s': float((fixed[i, 8]-m[i, 8])*fixed[i, 6]),
            'four_second_independent_theta_delta_K': float(4*(f[i, 7]-m[i, 7]))})
    multi.write(work / 'attribution.json', {'samples': n, 'points': points,
        'scope': 'Local thermodynamics/sink attribution; not a causal proof for the full three-hour divergence.',
        'source_sha256': digest(Path(__file__).resolve()),
        'results_sha256': digest(work / 'results.json')})
    print(json.dumps({'samples': n, 'points': points}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--replay', type=Path,
                        default=ROOT / 'migration_work/khn26_multi_boundary_common_state')
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--prepare', action='store_true')
    action.add_argument('--run', action='store_true')
    action.add_argument('--attribute', action='store_true')
    args = parser.parse_args()
    work = args.work.resolve()
    if args.prepare:
        prepare(work, args.replay.resolve())
    if args.run:
        common_precip.run(work)
        attribute(work)
    if args.attribute:
        attribute(work)
