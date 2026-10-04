#!/usr/bin/env python3
"""Plot MATLAB, Fortran, and Fortran-minus-MATLAB time-height MF panels."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--height-km', type=float, default=20)
    args = parser.parse_args()
    work = args.work.resolve()
    report = json.loads((work/'results.json').read_text())
    with np.load(work/'mf.npz') as data:
        hours = data['time_seconds']/3600
        height = data['height_m']/1000
        m = data['matlab']; f = data['fortran']
    assert m.shape == f.shape == (hours.size, height.size)
    assert np.isfinite(m).all() and np.isfinite(f).all()
    if args.height_km <= 0 or args.height_km > height.max():
        parser.error('height-km must lie inside the model height range')
    selected = height <= args.height_km
    difference = f-m
    limit = max(float(abs(m[:, selected]).max()), float(abs(f[:, selected]).max()))
    difference_limit = float(abs(difference[:, selected]).max())
    # A neutral zero field still needs nonzero color limits.
    norm = Normalize(-limit if limit else -1, limit if limit else 1)
    diff_norm = Normalize(-difference_limit if difference_limit else -1,
                          difference_limit if difference_limit else 1)
    fig, axes = plt.subplots(3, 1, figsize=(10, 10), sharex=True, sharey=True,
                             layout='constrained')
    fortran_label = report.get('fortran_label', 'Fortran')
    labels = ['MATLAB', fortran_label, fortran_label+' − MATLAB']
    for i, (ax, values, label) in enumerate(zip(axes, [m, f, difference], labels)):
        mesh = ax.pcolormesh(hours, height[selected], values[:, selected].T,
                             shading='nearest', cmap='RdBu_r',
                             norm=norm if i < 2 else diff_norm, rasterized=True)
        ax.set_title(label, loc='left', fontsize=13)
        ax.set_ylabel('Height (km)')
        ax.set_ylim(0, args.height_km)
        ax.set_xlim(hours[0], hours[-1])
        bar = fig.colorbar(mesh, ax=ax, pad=0.02)
        bar.set_label('MF (kg m$^{-2}$ s$^{-1}$)' if i < 2 else
                      'ΔMF (kg m$^{-2}$ s$^{-1}$)')
        bar.formatter.set_powerlimits((-3, 3))
        bar.update_ticks()
    axes[-1].set_xlabel('Time (hours)')
    bubble = report.get('bubble', {}).get('enabled', False)
    fig.suptitle(f"{report['case'].upper()} profile {report['profile_index']} · ACE 1 · "
                 f"{report['duration_seconds']/3600:g} hours · precipitation {report['precipitation']}\n"
                 f"{'Bubble: +1 K, saturated, levels 11–51' if bubble else 'No initial thermal bubble'}\n"
                 'MATLAB / Fortran share one color scale; difference uses its own scale', fontsize=12)
    for extension in ['png', 'pdf']:
        file = work/('mf_three_panels.'+extension)
        fig.savefig(file, dpi=180)
        print(file)
    plt.close(fig)


if __name__ == '__main__':
    main()
