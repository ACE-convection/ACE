#!/usr/bin/env python3
"""Plot serial PMB medians and observed ranges from analyze_serial_simd.py."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def plot(report_path, output):
    report = json.loads(report_path.read_text())
    names = list(dict.fromkeys(row['variant'] for row in report['summary']))
    fig, ax = plt.subplots(figsize=(11, 6.5), layout='constrained')
    for forcing, offset, color, label in [(1,-.16,'#2563eb','Actual forcing'),
                                          (2,.16,'#ea580c','Signed stress forcing')]:
        rows = [next(r for r in report['summary'] if r['variant']==name and
                     r['forcing']==forcing) for name in names]
        values = [r['median_seconds']*1000 for r in rows]
        errors = [[(r['median_seconds']-r['min_seconds'])*1000 for r in rows],
                  [(r['max_seconds']-r['median_seconds'])*1000 for r in rows]]
        ax.barh([i+offset for i in range(len(names))],values,height=.3,
                xerr=errors,color=color,label=label,capsize=3)
    ax.set_yticks(range(len(names)),[n if n!='read8' else 'read8 (checksum only)'
                                    for n in names])
    ax.invert_yaxis()
    ax.set_xlabel('Milliseconds per contraction / read pass (median; min–max bars)')
    ax.set_title(f'KHN26 serial PMB: {report["repeats"]} interleaved rounds, CPU '
                 f'{report["affinity_cpu"]}\nSame 3.281 GB allocation; exact response '
                 'agreement for all contraction variants')
    ax.grid(axis='x',alpha=.2)
    ax.set_axisbelow(True)
    ax.legend(loc='lower right')
    fig.supxlabel('Kernel-only measurements. read8 omits forcing multiplication; '
                  'bytes/time is not measured DRAM bandwidth.',fontsize=9)
    output.parent.mkdir(parents=True,exist_ok=True)
    for suffix in ('.png','.pdf'):
        fig.savefig(output.with_suffix(suffix),dpi=170)
    plt.close(fig)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('output',type=Path,help='Output stem for PNG/PDF')
    args=parser.parse_args()
    plot(args.report,args.output)
