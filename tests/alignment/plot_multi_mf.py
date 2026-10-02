#!/usr/bin/env python3
"""Plot eight-ACE MF evolution and MATLAB/Fortran differences."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
import numpy as np


def plot_comparison(work, report, hours, height, m, f, height_km):
    """Use fixed physical axes dimensions: panel height is one fifth of width."""
    panel_width = 6.0
    panel_height = panel_width/5
    column_gap = 1.0
    row_gap = 0.42
    left = 0.85
    bottom = 1.05
    figure_width = left+3*panel_width+2*column_gap+1.05
    figure_height = bottom+8*panel_height+7*row_gap+0.85
    fig = plt.figure(figsize=(figure_width, figure_height))
    selected = height <= height_km
    axes = []
    for i in range(8):
        y = bottom+(7-i)*(panel_height+row_gap)
        limit = max(float(abs(m[:, selected, i]).max()), float(abs(f[:, selected, i]).max()))
        difference = f[:, :, i]-m[:, :, i]
        difference_limit = float(abs(difference[:, selected]).max())
        norm = Normalize(-limit if limit else -1, limit if limit else 1)
        diff_norm = Normalize(-difference_limit if difference_limit else -1,
                              difference_limit if difference_limit else 1)
        for j, values in enumerate([m[:, :, i], f[:, :, i], difference]):
            x = left+j*(panel_width+column_gap)
            ax = fig.add_axes([x/figure_width, y/figure_height,
                               panel_width/figure_width, panel_height/figure_height])
            axes.append(ax)
            mesh = ax.pcolormesh(hours, height[selected], values[:, selected].T,
                                 shading='nearest', cmap='RdBu_r',
                                 norm=diff_norm if j == 2 else norm, rasterized=True)
            ax.set_xlim(hours[0], hours[-1])
            ax.set_ylim(0, height_km)
            ax.set_yticks([0, height_km/2, height_km])
            ax.tick_params(labelsize=9)
            if j == 0:
                ax.set_ylabel(f'ACE {i+1}\nHeight (km)', fontsize=10)
            if i == 7:
                ax.set_xlabel('Time (hours)', fontsize=10)
            if i == 0:
                ax.set_title(['MATLAB', 'Fortran', 'Fortran − MATLAB'][j], fontsize=14, pad=10)
            if j in [1, 2]:
                cax = fig.add_axes([(x+panel_width+0.08)/figure_width, y/figure_height,
                                    0.12/figure_width, panel_height/figure_height])
                bar = fig.colorbar(mesh, cax=cax)
                bar.ax.tick_params(labelsize=8)
                bar.formatter.set_powerlimits((-2, 2))
                bar.update_ticks()
    fig.suptitle(f"{report['case'].upper()} {report['profile_index']} · {hours[-1]:g} hours · "
                 f"ACE 8 initial MF pulse · precipitation {report['precipitation']}\n"
                 'MF (kg m$^{-2}$ s$^{-1}$) · Each row: MATLAB/Fortran share a scale; difference has its own scale',
                 fontsize=13, y=1-0.08/figure_height)
    fig.canvas.draw()
    ratios = [ax.get_window_extent().height/ax.get_window_extent().width for ax in axes]
    assert np.allclose(ratios, 0.2, rtol=0, atol=1e-12)
    print(f'All 24 panel height/width ratios verified: {ratios[0]:.6f}')
    for extension in ['png', 'pdf']:
        path = work/f'mf_multi_comparison.{extension}'
        fig.savefig(path, dpi=180, bbox_inches='tight')
        print(path)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--height-km', type=float, default=20)
    parser.add_argument('--layout', choices=['separate', 'comparison'], default='separate',
                        help='Separate overviews, or eight rows by three columns with 1:5 panels')
    args = parser.parse_args()
    work = args.work.resolve()
    report = json.loads((work/'results.json').read_text())
    assert report['ace_mode'] == 'multi'
    with np.load(work/'mf_all_aces.npz') as data:
        hours = data['time_seconds']/3600
        height = data['height_m']/1000
        m = data['matlab']; f = data['fortran']
    assert m.shape == f.shape == (hours.size, height.size, 8)
    assert np.isfinite(m).all() and np.isfinite(f).all()
    if not 0 < args.height_km <= height.max():
        parser.error('height-km must lie inside the model height range')
    if args.layout == 'comparison':
        plot_comparison(work, report, hours, height, m, f, args.height_km)
        return
    selected = height <= args.height_km
    difference = f-m
    limit = max(float(abs(m[:, selected]).max()), float(abs(f[:, selected]).max()))
    difference_limit = float(abs(difference[:, selected]).max())
    norm = Normalize(-limit if limit else -1, limit if limit else 1)
    diff_norm = Normalize(-difference_limit if difference_limit else -1,
                          difference_limit if difference_limit else 1)
    for label, values in [('matlab', m), ('fortran', f), ('difference', difference)]:
        fig, axes = plt.subplots(2, 4, figsize=(16, 8), sharex=True, sharey=True,
                                 layout='constrained')
        for i, ax in enumerate(axes.flat):
            mesh = ax.pcolormesh(hours, height[selected], values[:, selected, i].T,
                                 shading='nearest', cmap='RdBu_r',
                                 norm=diff_norm if label == 'difference' else norm,
                                 rasterized=True)
            ax.set_title(f'ACE {i+1}'+(' (outer pulse)' if i == 7 else ''))
            ax.set_ylim(0, args.height_km)
            ax.set_xlim(hours[0], hours[-1])
            if i >= 4:
                ax.set_xlabel('Time (hours)')
            if i % 4 == 0:
                ax.set_ylabel('Height (km)')
        bar = fig.colorbar(mesh, ax=axes.ravel().tolist(), pad=0.02)
        bar.set_label(('ΔMF' if label == 'difference' else 'MF')+' (kg m$^{-2}$ s$^{-1}$)')
        title = {'matlab': 'MATLAB', 'fortran': 'Fortran', 'difference': 'Fortran − MATLAB'}[label]
        fig.suptitle(f"{report['case'].upper()} {report['profile_index']} · "
                     f"{hours[-1]:g} hours · {title}\n"
                     f"ACE 8 initial MF pulse · precipitation {report['precipitation']}")
        for extension in ['png', 'pdf']:
            path = work/f'mf_multi_{label}.{extension}'
            fig.savefig(path, dpi=160, bbox_inches='tight')
            print(path)
        plt.close(fig)
    fig, axes = plt.subplots(2, 1, figsize=(11, 8), sharex=True, sharey=True,
                             layout='constrained')
    for ax, values, label in zip(axes, [m, f], ['MATLAB', 'Fortran']):
        for i in range(8):
            ax.plot(hours, abs(values[:, :, i]).max(axis=1), label=f'ACE {i+1}')
        ax.set_title(label, loc='left')
        ax.set_ylabel('Max |MF| over 0–40 km\n(kg m$^{-2}$ s$^{-1}$)')
        ax.grid(alpha=0.25)
    axes[0].legend(ncol=4)
    axes[-1].set_xlabel('Time (hours)')
    fig.suptitle('MultiACE response to the outer ACE 8 initial MF pulse')
    for extension in ['png', 'pdf']:
        path = work/f'mf_multi_response.{extension}'
        fig.savefig(path, dpi=160, bbox_inches='tight')
        print(path)
    plt.close(fig)


if __name__ == '__main__':
    main()
