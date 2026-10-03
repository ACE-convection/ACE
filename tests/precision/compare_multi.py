#!/usr/bin/env python3
"""Plot MATLAB, corrected real64 and corrected real32 multiACE MF responses."""
import argparse
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('single', type=Path)
    parser.add_argument('double', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    single = args.single.resolve(); double = args.double.resolve(); output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('Use a fresh comparison directory to preserve evidence')
    reports = [json.loads((p/'results.json').read_text()) for p in [single, double]]
    assert [r['precision_bits'] for r in reports] == [32, 64]
    for key in ['duration_seconds', 'dt_seconds', 'output_step_seconds', 'ace_mode', 'precipitation',
                'input_sha256', 'seed_sha256', 'reference_mf_sha256', 'compiler']:
        assert reports[0][key] == reports[1][key], 'Unmatched configuration: '+key
    for key in ['fortran/src/ace_module.F', 'fortran/src/ace_input.F', 'fortran/src/test.F',
                'tests/precision/fortran_case.f90']:
        assert reports[0]['sources_sha256'][key] == reports[1]['sources_sha256'][key], 'Unmatched source: '+key
    with np.load(single/'mf_all_aces.npz') as data:
        times = data['time_seconds']; height = data['height_m']; m = data['matlab']; s = data['fortran']
    with np.load(double/'mf_all_aces.npz') as data:
        assert np.array_equal(times, data['time_seconds']) and np.array_equal(height, data['height_m'])
        assert np.array_equal(m, data['matlab'])
        d = data['fortran']
    assert m.shape == s.shape == d.shape == (721, 801, 8)
    assert np.isfinite(m).all() and np.isfinite(s).all() and np.isfinite(d).all()
    output.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(4, 2, figsize=(15, 12), sharex=True, layout='constrained')
    hours = times/3600
    for i, ax in enumerate(axes.flat):
        # Separate scales for each ACE; one common scale for its three runs.
        ax.plot(hours, np.abs(m[:, :, i]).max(axis=1), color='black', linewidth=2.2, label='MATLAB')
        ax.plot(hours, np.abs(d[:, :, i]).max(axis=1), color='tab:blue', linestyle='--',
                linewidth=1.6, label='Fortran double precision')
        ax.plot(hours, np.abs(s[:, :, i]).max(axis=1), color='tab:orange', linewidth=1.3,
                label='Fortran single precision')
        ax.set_title(f'ACE {i+1}', loc='left')
        ax.set_xlim(0, 12)
        ax.set_ylabel('Max |MF| (kg m$^{-2}$ s$^{-1}$)')
        ax.grid(alpha=0.25)
        if i >= 6:
            ax.set_xlabel('Time (hours)')
    axes[0, 0].legend(fontsize=9)
    fig.suptitle('Manus 208 · multiACE · 12 hours · native precipitation\n'
                 'ACE 8 initial pulse · max |MF| over 0–40 km · each ACE uses its own vertical scale')
    for extension in ['png', 'pdf']:
        path = output/('mf_precision_response.'+extension)
        fig.savefig(path, dpi=180)
        print(path)
    plt.close(fig)
    report = {'scope': 'Matched numerical sources and case settings; default-real32 versus default-real64. '
                       'MATLAB reference is identical in both comparisons; no acceptance threshold.',
              'sources': {str(p): digest(p) for p in [single/'results.json', double/'results.json',
                                                     single/'mf_all_aces.npz', double/'mf_all_aces.npz']},
              'per_ace': []}
    for i in range(8):
        entry = {'ace': i+1}
        for name, values in [('matlab', m), ('double', d), ('single', s)]:
            peak = np.unravel_index(np.abs(values[:, :, i]).argmax(), (721, 801))
            entry[name] = {'peak_abs_mf': float(np.abs(values[peak[0], peak[1], i])),
                           'peak_seconds': int(times[peak[0]]), 'peak_height_m': float(height[peak[1]]),
                           'terminal_max_abs_mf': float(np.abs(values[-1, :, i]).max())}
        for name, error in [('double_minus_matlab', d[:, :, i]-m[:, :, i]),
                            ('single_minus_double', s[:, :, i].astype(np.float64)-d[:, :, i])]:
            entry[name] = {'max_abs': float(np.abs(error).max()),
                           'rms': float(np.sqrt(np.mean(error**2)))}
        report['per_ace'].append(entry)
    report['figures_sha256'] = {p.name: digest(p) for p in
                               [output/'mf_precision_response.png', output/'mf_precision_response.pdf']}
    (output/'results.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n')


if __name__ == '__main__':
    main()
