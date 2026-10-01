#!/usr/bin/env python3
"""Preview a proposed phase roundoff rule in temporary copies only."""
import argparse
import csv
import difflib
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import subprocess
from sweep_inversion import ROOT, instrument


def proposal(source,language,comments=True):
    if language=='matlab':
        anchor='  % 3 cases: liquid-only, ice-only, co-existing'
        inserted='''  phase_roundoff = 0;
  if isreal([G0,GT0,HT0]) && all(isfinite([G0,GT0,HT0]))
    phase_roundoff = 8*eps(1)*max(abs([G0,GT0,HT0]));
  end
'''
        old_liquid='  if G0>GT0 && G0>HT0 % Liquid-only'
        new_liquid='  if G0-GT0>phase_roundoff && G0-HT0>phase_roundoff % Liquid-only'
        old_ice='  elseif G0<GT0 && G0<HT0 % Ice-only'
        new_ice='  elseif G0-GT0<-phase_roundoff && G0-HT0<-phase_roundoff % Ice-only'
        comment='%'
    else:
        source=source.replace('real :: sat_roundoff,sat_slope','real :: sat_roundoff,sat_slope,phase_roundoff',1)
        anchor='  ! 3 cases: liquid-only, ice-only, co-existing'
        inserted='''  phase_roundoff = 0.
  if (all(ieee_is_finite([G0,GT0,HT0]))) then
    phase_roundoff = 8*epsilon(G0)*max(abs(G0),abs(GT0),abs(HT0))
  endif
'''
        old_liquid='  if (G0>GT0 .and. G0>HT0) then ! liquid-only'
        new_liquid='  if (G0-GT0>phase_roundoff .and. G0-HT0>phase_roundoff) then ! liquid-only'
        old_ice='  elseif (G0<GT0 .and. G0<HT0) then ! ice-only'
        new_ice='  elseif (G0-GT0<-phase_roundoff .and. G0-HT0<-phase_roundoff) then ! ice-only'
        comment='!'
    assert source.count(anchor)==1
    source=source.replace(anchor,inserted+anchor,1)
    for old,new in [(old_liquid,new_liquid),(old_ice,new_ice)]:
        assert source.count(old)==1
        source=source.replace(old,('  '+comment+old.strip()+'\n' if comments else '')+new,1)
    return source


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    args=parser.parse_args();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
    commands=instrument(work,1000)
    patches=[]
    for relative,language,temporary in [
        ('matlab/active/util_thermodynamics/inv_T_from_theta_e.m','matlab','reference_inversion.m'),
        ('fortran/active/src/ace_module.F','fortran','ace_module.F')]:
        source=(ROOT/relative).read_text()
        proposed=proposal(source,language)
        patches.extend(difflib.unified_diff(source.splitlines(True),proposed.splitlines(True),fromfile='a/'+relative,tofile='b/'+relative))
        path=work/temporary;before=path.read_text();after=proposal(before,language,comments=False);path.write_text(after)
        (work/(language+'_preview_instrumentation.diff')).write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True))))
    (work/'proposed_model.patch').write_text(''.join(patches))
    for command in commands[1:]:subprocess.run(command,cwd=work,check=True)
    shutil.copy2(Path(__file__).with_suffix('.m'),work/'preview_phase_endpoints.m')
    rows=list(csv.DictReader((ROOT/'tests/thermodynamics/results/atmospheric_validation.csv').open()))
    inputs=[[float(row[x]) for x in ['theta_e_K','qt_kgkg','p_Pa']] for row in rows]
    assert len(inputs)==1200
    metadata=[]
    for base in [1106,1101]:
        te,qt,p=inputs[base-1]
        for ulps in [-64,-16,-8,-4,0,4,8,16,64]:
            inputs.append([te+ulps*math.ulp(te),qt,p])
            metadata.append({'base_case':base,'theta_e_ulp_offset':ulps})
    data=struct.pack('<i',len(inputs))
    data+=struct.pack('<'+'d'*(3*len(inputs)),*(x[j] for j in range(3) for x in inputs))
    (work/'input.bin').write_bytes(data)
    with (work/'fortran.log').open('w') as log:
        subprocess.run([str(work/'inversion_probe'),'input.bin','fortran.bin'],cwd=work,stdout=log,check=True)
    manifest={'root':str(ROOT),'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
        ['fortran/active/src/ace_module.F','matlab/active/util_thermodynamics/inv_T_from_theta_e.m']},
        'replay_cases':1200,'neighbor_cases':18,'neighbors':metadata,'production_modified':False,
        'formula':'8*epsilon*max(abs(G0),abs(GT0),abs(HT0))',
        'proposal_status':'Unapproved scientific decision; applied only in temporary copies.'}
    (work/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Prepared preview-only rule for 1200 replay cases + 18 endpoint checks in {work}.')


if __name__=='__main__':
    main()
