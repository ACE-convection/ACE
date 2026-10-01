#!/usr/bin/env python3
"""Run single ACE first, then multi ACE, then focused physics diagnostics.

Use a fresh work directory, an already built model, MATLAB and netCDF-Fortran.
MATLAB must be allowed to reach its license server. All numerical routines
come from active source; validation-only access changes are saved as a diff.
"""
import argparse
from pathlib import Path
import subprocess
import sys

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('work',type=Path)
parser.add_argument('--matlab',default='matlab')
parser.add_argument('--model',type=Path)
parser.add_argument('--precip',action='store_true',help='Also run controlled near-onset precipitation cases')
parser.add_argument('--experiments',nargs='+',choices=['dry','precip','ice_precip'],
                    help='Select experiments explicitly; cannot combine with --precip')
args=parser.parse_args()
if args.precip and args.experiments:
    parser.error('Use either --precip or --experiments')
experiments=args.experiments or (['dry','precip'] if args.precip else ['dry'])
root=Path(__file__).resolve().parents[2]
work=args.work.resolve()
if work.exists() and any(work.iterdir()):
    raise SystemExit('Use a fresh work directory; previous results are preserved')
work.mkdir(parents=True,exist_ok=True)
model=(args.model or root/'fortran/active/ace_model.exe').resolve()
input_file=root/'data/input/manus208.nc'


def run(command,label,cwd=work):
    with (work/(label+'.log')).open('w') as log:
        subprocess.run([str(x) for x in command],cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)


def matlab(function,label):
    # MATLAB string quoting doubles apostrophes; argv is passed without a shell.
    quote=lambda p: str(p).replace("'","''")
    statement=f"addpath('{quote(work)}'); {function}('{quote(root)}','{quote(work)}');"
    run([args.matlab,'-batch',statement],label)


run([sys.executable,root/'tests/alignment/prepare.py',work],'prepare')
run([model,'--input',input_file,'--validate-input',work/'fortran_base_init.bin'],'base_init')
cases=[]
for mode in ['single','multi']:
    for experiment in experiments:
        label=mode if experiment=='dry' else mode+'_'+experiment
        cases.append(label)
        quote=lambda p: str(p).replace("'","''")
        statement=f"addpath('{quote(work)}'); run_alignment_case('{quote(root)}','{mode}','{quote(work)}','{experiment}');"
        run([args.matlab,'-batch',statement],'matlab_'+label)
        command=[work/'fortran_case.exe',work/'fortran_base_init.bin',input_file,work/('fortran_'+label+'.bin'),mode]
        if experiment!='dry': command.append(work/('initial_'+label+'.bin'))
        run(command,'fortran_'+label)
        run([sys.executable,root/'tests/alignment/compare.py',work,label,'--input',input_file],label+'_initial_comparison')
matlab('run_thermo','matlab_probes')
run([work/'fortran_thermo.exe',work/'thermo_input.bin',work/'thermo_fortran.bin'],'fortran_probes')
run([sys.executable,root/'tests/alignment/compare.py',work,'thermo'],'thermo_comparison')
for mode in cases:
    run([work/'fortran_diagnostics.exe',work/('fortran_'+mode+'.bin'),work/'fortran_base_init.bin',work/('fortran_'+mode+'_diagnostics.bin')],'fortran_'+mode+'_diagnostics')
    run([sys.executable,root/'tests/alignment/compare.py',work,mode,'--input',input_file],mode+'_comparison')
print('Complete. Metrics (no acceptance tolerance):',work)
