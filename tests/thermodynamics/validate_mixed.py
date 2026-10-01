#!/usr/bin/env python3
"""Prepare 25 fixed mixed-phase and nearby endpoint inputs; no sweep."""
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
# Log the actual values used by strict phase comparisons in temporary copies.
p=work/'ace_module.F';s=p.read_text()
anchor='  GT0 =  T0 * (RE+RV*qs)**chi * exp(qs*LvoT/CPL)'
assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\n  write(*,'(A,5ES26.17)') 'PHASE ',G0,GT0,HT0,G0-GT0,G0-HT0",1);p.write_text(s)
subprocess.run(commands[1],cwd=work,check=True)
s=(ROOT/'tests/thermodynamics/inversion_probe.f90').read_text()
s=s.replace('do i=1,n','do i=1,n\n write(*,\'(A,I3)\') \'CASE \',i',1)
(work/'mixed_probe.f90').write_text(s)
cmd=commands[2].copy();cmd[cmd.index(str(ROOT/'tests/thermodynamics/inversion_probe.f90'))]='mixed_probe.f90'
subprocess.run(cmd,cwd=work,check=True)
p=work/'reference_inversion.m';s=p.read_text()
anchor='  GT0 = T0 .* (RE+461.5*qs).^chi .* exp(qs.*9155.566660243245./CPL);'
assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\nfprintf('PHASE %.17g %.17g %.17g %.17g %.17g\\n',G0,GT0,HT0,G0-GT0,G0-HT0);",1);p.write_text(s)
shutil.copy2(Path(__file__).with_suffix('.m'),work/'validate_mixed.m')
manifest={'root':str(ROOT),'build_commands':commands,
 'phase_logging_build_commands':[commands[1],cmd],'case_count':25,
 'scope':'25 explicit mixed-phase/interior/endpoint/near-T0 states. No sweep.',
 'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
 ['fortran/active/src/ace_module.F','matlab/active/util_thermodynamics/inv_T_from_theta_e.m']}}
(work/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Prepared 25 cases. In {work}, run MATLAB -batch validate_mixed.')
