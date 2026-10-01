#!/usr/bin/env python3
"""Prepare one specified saturation boundary and four nearby targeted inputs; never invoke a grid scan.

Run this script with a fresh work directory, then run its printed MATLAB command.
Instrumentation adds logs and test-only iteration caps to temporary source copies.
"""
import argparse
import difflib
import json
import math
from pathlib import Path
import subprocess
from sweep_inversion import ROOT, instrument

CASES = [[282.02296733261414, 3.3710674483252453e-6*(1+delta), 30000.0]
         for delta in [-1e-4, -1e-8, 0.0, 1e-8, 1e-4]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--base-input-json', type=Path,
                        help='JSON [theta_e K, qt kg/kg, p Pa] for one targeted boundary')
    args = parser.parse_args()
    cases = CASES
    if args.base_input_json:
        base = json.loads(args.base_input_json.read_text())
        if (not isinstance(base, list) or len(base)!=3 or
                not all(isinstance(x,(int,float)) and math.isfinite(x) for x in base) or
                not 200<=base[0]<=400 or not 0<=base[1]<=0.1 or base[2]<=0):
            parser.error('Expected a finite [theta_e in 200..400, qt in 0..0.1, positive p].')
        cases = [[base[0],base[1]*(1+delta),base[2]]
                 for delta in [-1e-4,-1e-8,0,1e-8,1e-4]]
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    commands = instrument(work, 1000)
    path = work / 'ace_module.F'
    before = path.read_text()
    start = before.index('subroutine inv_theta_e(')
    stop = before.index('endsubroutine inv_theta_e', start)
    routine = before[start:stop]
    anchor = 'F0 = theta_e * (p*Re/R/P0)**chi * e**gamma'
    routine = routine.replace(anchor, anchor + "\nwrite(*,'(A,6ES26.17)') 'F0 FACTORS e gamma base power epower F0 ',e,gamma,p*Re/R/P0,(p*Re/R/P0)**chi,e**gamma,F0", 1)
    routine = routine.replace('  dT = -(F-F0)/dFdT', """  write(*,'(A,7ES26.17)') 'F FACTORS es power exp_arg exp Lv F residual ',eval_es(T,ice),eval_es(T,ice)**gamma,qt/Cpl*Lv(T)/T,exp(qt/Cpl*Lv(T)/T),Lv(T),F,F-F0
  dT = -(F-F0)/dFdT""", 1)
    routine = routine.replace('  T = T + dT', '''  write(*,'(A,2I5,4ES26.17)') 'NEWTON ',bdiag,ndiag1+ndiag2,T,dT,T+dT,dFdT
  T = T + dT''', 1)
    # Saturated derivatives differ by branch; record T/dT without reading dFdT.
    routine = routine.replace('    T = T + dT', '''    write(*,'(A,2I5,3ES26.17)') 'NEWTON ',bdiag,ndiag1+ndiag2,T,dT,T+dT
    T = T + dT''')
    routine = routine.replace('\nif (ieee_is_nan(T) .or. q-qsat>sat_roundoff) then', '''
write(*,'(A,ES26.17)') 'SAT_ROUNDOFF ',sat_roundoff
write(*,'(A,4ES26.17)') 'CONSISTENCY T qsat qt qt-qsat ',T,qsat,qt,qt-qsat
write(*,'(A,5ES26.17)') 'CONSTANTS Cpl Re chi F0 FT0 ',Cpl,Re,chi,F0,FT0
if (ieee_is_nan(T) .or. q-qsat>sat_roundoff) then''', 1)
    anchor = '  GT0 =  T0 * (RE+RV*qs)**chi * exp(qs*LvoT/CPL)'
    routine = routine.replace(anchor, anchor + '''
  write(*,'(A,5ES26.17)') 'PHASE G0 GT0 HT0 G0-GT0 G0-HT0 ',G0,GT0,HT0,G0-GT0,G0-HT0
  write(*,'(A,3ES26.17)') 'G0 FACTORS ',p*Re/P0,(p*Re/P0)**chi,theta_e
  write(*,'(A,4ES26.17)') 'GT0 FACTORS ',RE+RV*qs,(RE+RV*qs)**chi,qs*LvoT/CPL,exp(qs*LvoT/CPL)
''', 1)
    after = before[:start] + routine + before[stop:]
    path.write_text(after)
    (work / 'fortran_trace.diff').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True))))
    subprocess.run(commands[1], cwd=work, check=True)
    driver = '''program targeted\nuse ace_module, only: inv_theta_e\nimplicit none\nreal :: cases(3,5),t,q,ql,qi\ninteger :: i,b,n1,n2,s,f\n'''
    for i, case in enumerate(cases, 1):
        driver += f'cases(:,{i})=[{case[0]:.17e},{case[1]:.17e},{case[2]:.17e}]\n'
    driver += '''do i=1,5
write(*,'(A,I2)') 'CASE ',i
call inv_theta_e(cases(1,i),cases(2,i),cases(3,i),t,q,ql,qi,b,n1,n2,s,f)
write(*,'(A,4ES26.17,5I5)') 'RESULT ',t,q,ql,qi,b,n1,n2,s,f
enddo
end program
'''
    # Decimal integer-looking pressure must be real in array constructor.
    driver = driver.replace(',30000]', ',30000.0]')
    (work / 'targeted.f90').write_text(driver)
    link = commands[2].copy()
    link[link.index(str(ROOT / 'tests/thermodynamics/inversion_probe.f90'))] = 'targeted.f90'
    link[-1] = 'targeted'
    subprocess.run(link, cwd=work, check=True)
    with (work / 'fortran_trace.log').open('w') as log:
        subprocess.run([str(work / 'targeted')], cwd=work, stdout=log, check=True)
    path = work / 'reference_inversion.m'
    before = path.read_text()
    original_matlab = before
    anchor = 'F0 = theta_e .* (p.*RE./R/1e5).^chi .* e.^gamma;'
    before = before.replace(anchor, anchor + "\nfprintf('F0 FACTORS e gamma base power epower F0 %.17g %.17g %.17g %.17g %.17g %.17g\\n',e,gamma,p*RE/R/1e5,(p*RE/R/1e5)^chi,e^gamma,F0);", 1)
    before = before.replace('  dT = -(F-F0)./dFdT;', "  if F0>=FT0, diagnostic_es=eval_es(T); else, diagnostic_es=eval_esi(T); end\n  fprintf('F FACTORS es power exp_arg exp Lv F residual %.17g %.17g %.17g %.17g %.17g %.17g %.17g\\n',diagnostic_es,diagnostic_es^gamma,qt/CPL*lv(T)/T,exp(qt/CPL*lv(T)/T),lv(T),F,F-F0);\n  fprintf('DERIVATIVE %.17g\\n',dFdT);\n  dT = -(F-F0)./dFdT;", 1)
    after = before.replace('  T = T + dT;', "  fprintf('NEWTON %d %d %.17g %.17g %.17g\\n',branch,n1+n2,T,dT,T+dT);\n  T = T + dT;")
    after = after.replace('\nbsmeter = ', "\nfprintf('SAT_ROUNDOFF %.17g\\n',sat_roundoff);\nfprintf('CONSISTENCY T qsat qt qt-qsat %.17g %.17g %.17g %.17g\\n',T,qsat,qt,qt-qsat);\nfprintf('CONSTANTS Cpl Re chi F0 FT0 %.17g %.17g %.17g %.17g %.17g\\n',CPL,RE,chi,F0,FT0);\nbsmeter = ", 1)
    anchor = '  GT0 = T0 .* (RE+461.5*qs).^chi .* exp(qs.*9155.566660243245./CPL);'
    after = after.replace(anchor, anchor + "\nfprintf('PHASE G0 GT0 HT0 G0-GT0 G0-HT0 %.17g %.17g %.17g %.17g %.17g\\n',G0,GT0,HT0,G0-GT0,G0-HT0);\nfprintf('G0 FACTORS %.17g %.17g %.17g\\n',p*RE/1e5,(p*RE/1e5)^chi,theta_e);\nfprintf('GT0 FACTORS %.17g %.17g %.17g %.17g\\n',RE+461.5*qs,(RE+461.5*qs)^chi,qs*9155.566660243245/CPL,exp(qs*9155.566660243245/CPL));", 1)
    path.write_text(after)
    (work / 'matlab_trace.diff').write_text(''.join(difflib.unified_diff(original_matlab.splitlines(True), after.splitlines(True))))
    rows = ';\n'.join(' '.join(f'{x:.17g}' for x in row) for row in cases)
    script = f"addpath('{ROOT}/matlab/active/util_thermodynamics');\naddpath('{work}');\ncases=[{rows}];\nresults=zeros(5,9);\n"
    script += r'''for i=1:5
fprintf('CASE %d\n',i);
[T,q,ql,qi,b,n1,n2,s,f]=reference_inversion(cases(i,1),cases(i,2),cases(i,3));
results(i,:)=[T,q,ql,qi,b,n1,n2,s,f];
fprintf('RESULT %.17g %.17g %.17g %.17g %d %d %d %d %d\n',results(i,:));
end
'''
    script += "fid=fopen('targeted_results.json','w'); fprintf(fid,'%s',jsonencode(struct('inputs',cases,'matlab',results))); fclose(fid);\n"
    (work / 'run_targeted.m').write_text(script)
    (work / 'cases.json').write_text(json.dumps(cases, indent=2))
    print(f"Prepared exactly {len(cases)} cases in {work}. Run MATLAB -batch run_targeted there.")


if __name__ == '__main__':
    main()
