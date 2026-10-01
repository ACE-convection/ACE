#!/usr/bin/env python3
"""Prepare exactly 25 fixed liquid-inversion cases, never a sweep."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from sweep_inversion import ROOT, instrument

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('work',type=Path)
args=parser.parse_args()
work=args.work.resolve()
work.mkdir(parents=True,exist_ok=False)
commands=instrument(work,1000)
shutil.copy2(Path(__file__).with_suffix('.m'),work/'validate_liquid.m')
manifest={'root':str(ROOT),'build_commands':commands,'case_count':25,
          'scope':'Five original liquid cases plus 20 distinct fixed inputs. No sweep.',
          'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
           ['fortran/active/src/ace_module.F','matlab/active/util_thermodynamics/inv_T_from_theta_e.m']}}
(work/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Prepared 25 cases. In {work}, run MATLAB -batch validate_liquid.')
