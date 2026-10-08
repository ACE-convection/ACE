#!/usr/bin/env python3
"""Compare a preserved three-hour prefix without requiring natural solver exits."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

from plot_multi import plot


def compare(work):
    cfg = json.loads((work / 'configuration.json').read_text())
    case = dict(cfg['case'])
    case['duration_seconds'] = 10800
    n, z, count = 101, 401, 181
    errors = []
    sums = np.zeros(3)
    reference = np.zeros(3)
    means = []
    hashes = {}
    mf = np.empty((2, count, n, z))
    fractions = np.asarray(case['ace_area_m2'])
    fractions = fractions / fractions.sum()
    streams = []
    try:
        for name in ('matlab', 'fortran'):
            path = work / 'full' / (name + '_states.bin')
            stream = path.open('rb')
            streams.append(stream)
            width = n if name == 'matlab' else n + 1
            needed = count * width * z * 3 * 8 + (0 if name == 'matlab' else 12 + z * 8)
            if path.stat().st_size < needed:
                raise ValueError(f'Incomplete three-hour {name} prefix')
            if name == 'fortran' and not np.array_equal(np.fromfile(stream, '<i4', count=3), [n, z, 3]):
                raise ValueError('Fortran header mismatch')
            hashes[name] = hashlib.sha256()
        for i in range(count):
            values = []
            for lang, stream in enumerate(streams):
                width = n if lang == 0 else n + 1
                offset = i * width * z * 3 * 8 + (0 if lang == 0 else 12 + (z * 8 if i else 0))
                stream.seek(offset)
                raw = stream.read(width * z * 3 * 8)
                hashes[('matlab', 'fortran')[lang]].update(raw)
                value = np.frombuffer(raw, '<f8').reshape((width, z, 3), order='F')[:n]
                if not np.isfinite(value).all() or value[:, :, 2].min() < 0:
                    raise ValueError(f'Invalid state at minute {i}')
                values.append(value)
                mf[lang, i] = value[:, :, 0]
            m, f = values
            errors.append(np.max(np.abs(f - m), axis=(0, 1)).tolist())
            sums += np.sum((f - m)**2, axis=(0, 1))
            reference += np.sum(m**2, axis=(0, 1))
            means.append([float(np.max(np.abs(np.sum(v[:, :, 0] * fractions[:, None], axis=0)))) for v in values])
        if np.any(mf[:, 0] != 0):
            raise ValueError('Expected zero initial MF')
    finally:
        for stream in streams:
            stream.close()
    errors = np.asarray(errors)
    visible = np.asarray(case['height_m']) <= 20000
    diagnostics = []
    for minute in range(20, 181, 20):
        a, b = mf[:, minute][:, :, visible]
        # Use a flattened field so diagnostics are independent of array layout.
        a, b = a.ravel(), b.ravel()
        diagnostics.append({'time_minutes': minute,
            'MF_max_abs_error_0_20km': float(np.max(np.abs(a-b))),
            'MF_relative_L2_error_0_20km': float(np.linalg.norm(a-b)/np.linalg.norm(a)),
            'MF_pattern_correlation_0_20km': float(np.corrcoef(a,b)[0,1])})
    peak = []
    for lang in range(2):
        i, ace, k = np.unravel_index(np.argmax(np.abs(mf[lang])), mf[lang].shape)
        peak.append({'language': ('matlab','fortran')[lang], 'time_minutes': int(i),
                     'ACE_column': int(ace+1), 'height_m': case['height_m'][k],
                     'MF': float(mf[lang,i,ace,k])})
    report = {'tag':'three_hour', 'case':case, 'saved_states':count,
        'actual_duration_seconds':10800, 'field_order':['MF','theta_e','qt'],
        'time_seconds':(np.arange(count)*60).tolist(),
        'max_abs_error':errors.max(axis=0).tolist(), 'max_abs_error_each_state':errors.tolist(),
        'rms_error':np.sqrt(sums/(count*n*z)).tolist(),
        'relative_L2_error':np.sqrt(sums/reference).tolist(),
        'area_mean_MF_max_matlab_fortran':np.max(means,axis=0).tolist(),
        'finite_saved_states':True, 'nonnegative_saved_qt':True,
        'MF_peak':peak, 'snapshot_diagnostics':diagnostics,
        'compared_raw_state_record_sha256':{name:h.hexdigest() for name,h in hashes.items()},
        'scope':'Only saved states at 60-second intervals, minutes 0–180. Intentional stops; no full-step tendencies, closed water budget, or predefined three-hour scientific tolerance.'}
    out = work / 'three_hour'
    out.mkdir(exist_ok=True)
    np.savez_compressed(out/'mf_all_aces.npz', time_seconds=np.arange(count)*60,
        height_m=case['height_m'], x_center_m=case['ace_center_from_left_boundary_m'],
        matlab=mf[0],fortran=mf[1])
    (work/'three_hour_state_results.json').write_text(json.dumps(report,indent=2)+'\n')
    plot(work,'three_hour')
    fig, axes = plt.subplots(3,1,figsize=(9,8),sharex=True,layout='constrained')
    for k,ax in enumerate(axes):
        ax.semilogy(np.arange(count)[errors[:,k]>0],errors[errors[:,k]>0,k])
        ax.set(ylabel=['MF error (kg m-2 s-1)','theta_e error (K)','qt error (kg kg-1)'][k],xlim=(0,180))
        ax.grid(alpha=0.25)
    axes[-1].set_xlabel('Simulation time (minutes)')
    fig.suptitle('multiACE: maximum absolute Fortran–MATLAB difference across all columns/heights')
    for ext in ('png','pdf'):
        fig.savefig(out/'comparison'/('state_errors.'+ext),dpi=160)
    plt.close(fig)
    print(json.dumps({k:report[k] for k in ('max_abs_error','relative_L2_error','MF_peak','snapshot_diagnostics')},indent=2))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    compare(parser.parse_args().work.resolve())
