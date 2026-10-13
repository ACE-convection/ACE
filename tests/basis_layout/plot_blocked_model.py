#!/usr/bin/env python3
"""Plot additive one-minute blocked-model section averages and MATLAB reference."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def plot(report_path, output):
    report=json.loads(report_path.read_text())
    names=[r['name'] for r in report['runs']]+['matlab']
    labels=['Fortran original\nbefore','Fortran outputs4','Fortran outputs8',
            'Fortran original\nafter','MATLAB default\nprevious samples']
    titles=['Nonlocal + interpolation + assembly','Transport / buoyancy setup',
            'Thermodynamic inversions','Damping','Other']
    colors=['#2563eb','#fb923c','#22c55e','#a855f7','#94a3b8']
    fig,ax=plt.subplots(figsize=(11,6),layout='constrained')
    bottom=[0.]*len(names)
    for row,title,color in zip(report['comparison'],titles,colors):
        values=[row[name+'_ms_per_step']/1000 for name in names]
        ax.bar(range(len(names)),values,bottom=bottom,label=title,color=color)
        bottom=[x+y for x,y in zip(bottom,values)]
    for i,total in enumerate(bottom):
        ax.text(i,total+.045,f'{total:.3f}',ha='center')
    ax.set_xticks(range(len(names)),labels)
    ax.set_ylim(0,max(bottom)*1.23)
    ax.set_ylabel('Seconds per full SSPRK93 step (15-step averages)')
    ax.set_title('KHN26: 60 simulated seconds per Fortran build\nSame serial O2 '
                 'flags; complete exported states identical')
    ax.grid(axis='y',alpha=.2)
    ax.set_axisbelow(True)
    ax.legend(loc='upper center',ncol=2,fontsize=9)
    fig.supxlabel('Sequential shared-host samples; MATLAB uses default parallel '
                  'resources. Initialization excluded.',fontsize=9)
    output.parent.mkdir(parents=True,exist_ok=True)
    for suffix in ('.png','.pdf'):
        fig.savefig(output.with_suffix(suffix),dpi=170)
    plt.close(fig)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    plot(args.report,args.output)
