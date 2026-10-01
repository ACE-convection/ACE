#!/usr/bin/env python3
"""Prepare 1200 reproducible atmospheric states, not a Cartesian sweep."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from sweep_inversion import ROOT, instrument

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('work',type=Path)
args=parser.parse_args();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
commands=instrument(work,1000)
shutil.copy2(Path(__file__).with_suffix('.m'),work/'validate_atmosphere.m')
# Independent uninstrumented Fortran comparison for converged cases only.
production=work/'production';production.mkdir()
shutil.copy2(ROOT/'fortran/active/src/ace_module.F',production/'ace_module.F')
for command in commands[:2]:subprocess.run(command,cwd=production,check=True)
source=(ROOT/'tests/thermodynamics/inversion_probe.f90').read_text()
source=source.replace('output(n,13)','output(n,4)').replace('T,q,ql,qi,branch,n1,n2,status,initial_failure)','T,q,ql,qi)')
source=source.replace(' output(i,5:8)=0.\n','').replace(' output(i,9:13)=real([branch,n1,n2,status,initial_failure])\n','')
(production/'production_probe.f90').write_text(source)
link=commands[2].copy();link[link.index(str(ROOT/'tests/thermodynamics/inversion_probe.f90'))]='production_probe.f90';link[-1]='production_probe'
subprocess.run(link,cwd=production,check=True)
manifest={'root':str(ROOT),'build_commands':commands,'production_build_commands':[*commands[:2],link],
 'case_count':1200,'seed':180103,'generation':'Five stratified categories; no Cartesian grid.',
 'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
 ['fortran/active/src/ace_module.F','matlab/active/util_thermodynamics/inv_T_from_theta_e.m']}}
(work/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Prepared 1200-case runner. In {work}, run MATLAB -batch validate_atmosphere.')
