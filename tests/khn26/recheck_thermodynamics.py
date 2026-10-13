#!/usr/bin/env python3
"""Audit inversion closure, phase selection and sink algebra on common-state outputs."""
import argparse
import json
from pathlib import Path

import numpy as np

import common_precip
import multi
from run import digest


def audit(work, baseline):
    cfg = multi.verify(work)
    status = json.loads((work / 'status.json').read_text())
    if status['state'] != 'completed':
        raise ValueError('Diagnostic run has not completed')
    common = common_precip.compare(work, cfg)
    n = cfg['samples']
    samples = np.fromfile(work / 'inputs.bin', '<f8').reshape((n, 3), order='F')
    labels = json.loads((work / 'sample_labels.json').read_text())
    values = {name: np.fromfile(work / (name + '_outputs.bin'), '<f8').reshape((n, 9), order='F')
              for name in ('matlab', 'fortran')}
    report = {'samples': n, 'common_state_results': common, 'languages': {}}
    phases = {}
    for name, a in values.items():
        qc = a[:, 2]+a[:, 3]
        phase_masks = {'dry': qc == 0, 'liquid': (a[:, 2] > 0) & (a[:, 3] == 0),
                       'ice': (a[:, 3] > 0) & (a[:, 2] == 0),
                       'mixed': (a[:, 2] > 0) & (a[:, 3] > 0)}
        if not np.all(np.logical_or.reduce(list(phase_masks.values()))):
            raise ValueError('Unclassified/negative condensate')
        phases[name] = np.select(list(phase_masks.values()), range(4))
        residual = a[:, 4]-samples[:, 0]
        phase_report = {}
        for phase, mask in phase_masks.items():
            indices = np.flatnonzero(mask)
            phase_report[phase] = {'count': len(indices)}
            if len(indices):
                i = int(indices[np.argmax(abs(residual[indices]))])
                phase_report[phase].update(max_abs_forward_theta_residual_K=float(abs(residual[i])),
                                           worst_sample=labels[i])
        ramp = 20/0.0005*(qc-0.0005)
        # Independent stable softplus evaluation; no production formula changes.
        qt_reference = -(0.0005/20/300)*np.logaddexp(0, ramp)
        qt_reference[qc <= 0] = 0
        report['languages'][name] = {
            'phase_counts_and_forward_residuals': phase_report,
            'max_water_partition_closure_error': float(np.max(abs(a[:, 1:4].sum(axis=1)-samples[:, 1]))),
            'minimum_water_species': float(a[:, 1:4].min()),
            'qt_sink_nonpositive': bool(np.all(a[:, 8] <= 0)),
            'no_condensate_sinks_exactly_zero': bool(np.all(a[qc <= 0, 7:9] == 0)),
            'max_qt_sink_vs_independent_softplus_error': float(np.max(abs(a[:, 8]-qt_reference))),
            'max_theta_sink_vs_qt_times_exported_derivative_error': float(np.max(abs(a[:, 7]-a[:, 8]*a[:, 6]))),
            'ramp_min_max': [float(ramp.min()), float(ramp.max())]}
    report['phase_selection_mismatches'] = int(np.count_nonzero(phases['matlab'] != phases['fortran']))
    if digest(work / 'inputs.bin') != digest(baseline / 'inputs.bin'):
        raise ValueError('Repeat inputs differ from baseline')
    report['repeat_output_byte_identity'] = {name: digest(work / name) == digest(baseline / name)
        for name in ('matlab_outputs.bin', 'fortran_outputs.bin', 'fortran_fixed_thermo.bin')}
    report['constant_expression_comparison'] = {
        'EPS_Rd_div_Rv_minus_MATLAB_literal': 287.04/461.5-0.621971830985916,
        'ice_dC_forward_minus_inverse_constant':
            4190-(2106+7.3*(273.1636783445389-273.15))-2083.900148084866}
    report['scope'] = ('Current saved multiACE samples; Newton tolerance bounds iteration step, '
                       'not forward theta residual. This audit does not modify production sources '
                       'or validate invalid inputs.')
    report['source_sha256'] = digest(Path(__file__).resolve())
    report['configuration_sha256'] = digest(work / 'configuration.json')
    multi.write(work / 'recheck.json', report)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--baseline', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.work.resolve(), args.baseline.resolve()), indent=2))
