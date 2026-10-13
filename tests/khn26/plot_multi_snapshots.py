#!/usr/bin/env python3
"""Read completed minute records from live streams and plot paired MF snapshots."""
import argparse
import hashlib
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def frame(path, language, minute):
    n, z = 101, 401
    width = n if language == 'matlab' else n + 1
    size = width * z * 3
    offset = minute * size * 8
    if language == 'fortran':
        if not np.array_equal(np.fromfile(path, '<i4', count=3), [n, z, 3]):
            raise ValueError('Unexpected Fortran state header')
        offset += 12 + (z * 8 if minute else 0)
    if path.stat().st_size < offset + size * 8:
        return None
    with path.open('rb') as stream:
        stream.seek(offset)
        raw = stream.read(size * 8)
    if len(raw) != size * 8:
        return None
    values = np.frombuffer(raw, '<f8').reshape((width, z, 3), order='F')[:n, :, 0].copy()
    if not np.isfinite(values).all():
        raise ValueError(f'Nonfinite MF: {language}, {minute} min')
    return values


def plot(work):
    case = json.loads((work / 'configuration.json').read_text())['case']
    if not case['multiACE'] or case['dt_seconds'] != 4:
        raise ValueError('Expected multiACE case with dt=4 s')
    height = np.asarray(case['height_m']) / 1000
    out = work / 'full' / 'comparison'
    out.mkdir(exist_ok=True)
    # Explicit axes sizes give every physical plotting box height:width = 1:5.
    fig = plt.figure(figsize=(16, 16))
    panel_w, panel_h = 6.5, 1.3
    gap, top = 0.48, 14.6
    records = []
    mesh = None
    for row, minute in enumerate(range(20, 161, 20)):
        for col, language in enumerate(('matlab', 'fortran')):
            ax = fig.add_axes([(0.8 + col * 7.6) / 16,
                               (top - row * (panel_h + gap) - panel_h) / 16,
                               panel_w / 16, panel_h / 16])
            values = frame(work / 'full' / (language + '_states.bin'), language, minute)
            record = {'language': language, 'time_minutes': minute, 'available': values is not None}
            if values is None:
                ax.set_facecolor('#f2f2f2')
                ax.text(0.5, 0.5, 'Awaiting saved output', ha='center', va='center', transform=ax.transAxes)
            else:
                mesh = ax.pcolormesh(np.arange(1, 102), height, values.T,
                                     shading='nearest', cmap='RdBu_r', vmin=-1, vmax=1,
                                     rasterized=True)
                record.update(mf_sha256=hashlib.sha256(values.tobytes()).hexdigest(),
                              mf_min=float(values.min()), mf_max=float(values.max()))
            records.append(record)
            ax.set(xlim=(0.5, 101.5), ylim=(0, 20),
                   ylabel='Height (km)', title=f'{minute} min')
            ax.set_xticks([1, 20, 40, 60, 80, 101])
            if row == 7:
                ax.set_xlabel('ACE column')
            else:
                ax.tick_params(labelbottom=False)
    fig.text(4.05 / 16, 15.35 / 16, 'MATLAB', ha='center', fontsize=17)
    fig.text(11.65 / 16, 15.35 / 16, 'Fortran', ha='center', fontsize=17)
    if mesh is not None:
        cax = fig.add_axes([0.33, 0.027, 0.34, 0.012])
        fig.colorbar(mesh, cax=cax, orientation='horizontal', extend='both',
                     ticks=[-1, -0.5, 0, 0.5, 1], label='MF (kg m$^{-2}$ s$^{-1}$)')
    for ext in ('png', 'pdf'):
        target = out / ('mf_20min_snapshots.' + ext)
        temporary = target.with_name(target.stem + '.tmp.' + ext)
        fig.savefig(temporary, dpi=180)
        temporary.replace(target)
    plt.close(fig)
    complete = all(record['available'] for record in records)
    report = {'updated_utc': datetime.now(timezone.utc).isoformat(),
              'complete': complete, 'color_limits': [-1, 1],
              'panel_height_to_width': [1, 5], 'height_km': [0, 20],
              'x_axis': 'ACE column index 1–101 (not physical distance)',
              'record_interval_seconds': 60, 'records': records}
    target = out / 'mf_20min_snapshots.json'
    temporary = target.with_suffix('.tmp')
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(target)
    print(json.dumps({'complete': complete, 'figure': str(out / 'mf_20min_snapshots.png')}), flush=True)
    return complete


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--watch', action='store_true')
    args = parser.parse_args()
    while True:
        complete = plot(args.work.resolve())
        if complete or not args.watch:
            break
        status = json.loads((args.work / 'status.json').read_text())
        if status.get('state') == 'failed':
            raise RuntimeError('Simulation failed before all requested snapshots were saved')
        time.sleep(60)
