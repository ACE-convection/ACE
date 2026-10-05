#!/usr/bin/env python3
"""Plot measured kernel medians; full versus one response are separate panels."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('work',type=Path)
    args=parser.parse_args();work=args.work.resolve()
    report=json.loads((work/'results.json').read_text())
    choices=[('checked_threads1','legacy','Current expression (checked O2)'),
             ('checked_threads1','packed_grouped','Packed, same sums (checked O2)'),
             ('optimized_threads1','streamed','Loop order only (O3)'),
             ('optimized_threads1','packed_grouped','Packed, same sums (O3)'),
             ('optimized_threads1','packed_blas','Packed BLAS, 1 thread (O3)'),
             ('optimized_threads4','packed_openmp','Packed OpenMP, 4 threads (O3)'),
             ('optimized_threads8','packed_openmp','Packed OpenMP, 8 threads (O3)'),
             ('matlab','original','MATLAB original, 1 thread setting'),
             ('matlab','matrix','MATLAB matrix, 1 thread setting')]
    fig,axes=plt.subplots(1,2,figsize=(15,7),sharey=True,layout='constrained')
    for ax,responses,title in zip(axes,[101,1],['All 101 responses','Only ACE 1 response; all forcing ACEs retained']):
        values=[]
        for build,method,_ in choices:
            if build=='matlab':
                entry=next(r for r in report['matlab']['cases'] if r['kind']==1 and r['responses']==responses and r['method']==method)
                values.append(float(np.median(entry['seconds'])))
            else:
                entry=next(r for r in report['timing_summary'] if r['build']==build and r['method']==method and r['kind']==1 and r['responses']==responses)
                values.append(entry['median_seconds'])
        positions=np.arange(len(values))
        ax.barh(positions,values,color=['#888888','#2877a8','#2877a8','#2877a8','#68a870','#8855ab','#8855ab','#d38d33','#d38d33'])
        ax.set_xscale('log');ax.set_xlim(min(values)/2,max(values)*2)
        ax.set_title(title);ax.set_xlabel('Seconds per contraction (log scale; lower is faster)')
        ax.set_yticks(positions,[r[2] for r in choices])
        ax.grid(axis='x',alpha=.25)
        for position,value in zip(positions,values):ax.text(value*1.07,position,f'{value:.4g}',va='center',fontsize=9)
    axes[0].invert_yaxis()
    fig.suptitle('KHN26 PMB layout experiment: actual singleACE initial forcing\n'
                 'Median of 3 runs after warmup; shared host; read/packing excluded',fontsize=13)
    for extension in ('png','pdf'):
        path=work/f'basis_layout_timings.{extension}';fig.savefig(path,dpi=180);print(path)
    plt.close(fig)


if __name__=='__main__':main()
