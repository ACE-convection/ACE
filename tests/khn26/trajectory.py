#!/usr/bin/env python3
"""Instrument copied KHN26 drivers and compare six-hour production trajectories.

Diagnostic copies preserve numerical statements; stage inventories use reference
density, 400 physical scalar levels and normalized ACE areas. Native removal is
a column-integrated sink, not a prognostic surface rain flux.
"""
import argparse
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from netCDF4 import Dataset

from run import ROOT, digest


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Expected one instrumentation anchor: {old!r}')
    return source.replace(old, new, 1)


def prepare(work):
    source = (ROOT / 'matlab/ace.m').read_text()
    source = replace_once(source, "dir_ace = fileparts(mfilename('fullpath'));",
                          f"dir_ace = '{ROOT / 'matlab'}';")
    source = replace_once(source, '  yn = X0;', f'''  yn = X0;
  budget_fid=fopen('{work / 'matlab_budget.bin'}','w');
  weights=model.rho_zc(1:end-1)*model.dz.*reshape(model.Ai/sum(model.Ai),1,1,[]);
''')
    source = replace_once(source, '      t = t+dt;', '''      t = t+dt;
      inventory_before=sum(yn(1:end-1,1:2,:).*weights,[1,3]);''')
    source = replace_once(source, '      if model.precip_enabled', '''      inventory_dynamic=sum(yn(1:end-1,1:2,:).*weights,[1,3]);
      column_sink=-reshape(sum(dQt(1:end-1,:).*model.rho_zc(1:end-1)*model.dz,1),1,[])*dt;
      if model.precip_enabled''')
    source = replace_once(source, '      % Implicit Newtonian damping', '''      inventory_precip=sum(yn(1:end-1,1:2,:).*weights,[1,3]);
      % Implicit Newtonian damping''')
    source = replace_once(source, '      % Implicitly solving massflux diffusion', '''      inventory_damp=sum(yn(1:end-1,1:2,:).*weights,[1,3]);
      fwrite(budget_fid,[t,inventory_before,inventory_dynamic,inventory_precip,inventory_damp,column_sink],'double');
      % Implicitly solving massflux diffusion''')
    source = replace_once(source, 'end%idt\nend', 'end%idt\n  fclose(budget_fid);\nend')
    # Export before the script's first local function (after production output).
    source = replace_once(source, 'function X = timeint(', f'''fid=fopen('{work / 'matlab_diagnostic_states.bin'}','w');
for step=1:size(X,4)
  v=permute(X(:,[3,1,2],:,step),[3,1,2]); fwrite(fid,v(:),'double');
end
fclose(fid);

function X = timeint(''')
    (work / 'diagnostic_main.m').write_text(source)
    (work / 'diagnostic_launch.m').write_text(f"""setenv('ACE_VALIDATE_INPUT',''); setenv('ACE_STEPS','');
setenv('ACE_PHYSICS','native'); setenv('ACE_INPUT_MODE','shared');
setenv('ACE_INPUT_FILE','{ROOT / 'data/input/manaus1342_khn26.nc'}');
setenv('ACE_OUTPUT_FILE','{work / 'matlab_diagnostic.nc'}');
run('{work / 'diagnostic_main.m'}');
""")
    module = (ROOT / 'fortran/src/ace_module.F').read_text()
    module = replace_once(module, 'real :: mean_mf(nz)', '''real :: mean_mf(nz)
integer, save :: budget_unit=0
real :: inventory(2,4), column_sink(ncols), weights(ncols,nz-1)
if (budget_unit==0) then
  open(newunit=budget_unit,file='fortran_budget.bin',access='stream',form='unformatted',status='new')
endif'''.replace("\nif (budget_unit", "\n!INIT!if (budget_unit"))
    # Executable initialization belongs after all declarations.
    init = module[module.index('!INIT!'):module.index('endif', module.index('!INIT!')) + 5]
    module = module.replace(init, '')
    module = replace_once(module, 'yi = X\n\ndo while', init.replace('!INIT!', '') + '''
do k=1,nz-1
  weights(:,k)=Ref(k,1)*Ref(k,5)*A/sum(A)
enddo
yi = X

do while''')
    module = replace_once(module, '  ! update ace tendency', '''  call record_inventory(1)
  ! update ace tendency''')
    module = replace_once(module, '    X(1:ncols,:,3)=max(X(1:ncols,:,3),0.)', '''    X(1:ncols,:,3)=max(X(1:ncols,:,3),0.)
    call record_inventory(2)''')
    module = replace_once(module, '  ! NaN check', '  call record_inventory(3)\n  ! NaN check')
    module = replace_once(module, '  t = t + dt', '''  call record_inventory(4)
  write(budget_unit) t+dt,inventory,column_sink
  flush(budget_unit)
  t = t + dt''')
    module = replace_once(module, 'subroutine apply_native_precipitation()', '''subroutine record_inventory(stage)
integer, intent(in) :: stage
inventory(1,stage)=sum(X(1:ncols,1:nz-1,2)*weights)
inventory(2,stage)=sum(X(1:ncols,1:nz-1,3)*weights)
end subroutine
subroutine apply_native_precipitation()''')
    module = replace_once(module, 'X(1:ncols,:,2:3)=X(1:ncols,:,2:3)+K1(:,:,1:2)*dt', '''do ii=1,ncols
  column_sink(ii)=-sum(K1(ii,1:nz-1,2)*Ref(1:nz-1,1)*Ref(1:nz-1,5))*dt
enddo
X(1:ncols,:,2:3)=X(1:ncols,:,2:3)+K1(:,:,1:2)*dt''')
    (work / 'ace_module_budget.F').write_text(module)
    build = work / 'build_budget'
    build.mkdir(exist_ok=True)
    flags = ['-cpp', '-ffree-form', '-ffree-line-length-none', '-O2', '-g',
             '-fcheck=all,no-array-temps', '-ffpe-trap=invalid,zero,overflow',
             '-fbacktrace', '-fdefault-real-8', '-fdefault-double-8']
    include = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    for file in ('ace_input.mod', 'ace_interpolation.mod', 'microphy_p3.mod'):
        (build / file).write_bytes((work / 'build64' / file).read_bytes())
    commands = [ ['gfortran', *flags, *include, '-c', str(work / 'ace_module_budget.F'), '-o', 'ace_module.o'],
                ['gfortran', *flags, *include, '-c', str(ROOT / 'fortran/src/test.F'), '-o', 'test.o'],
                ['gfortran', *flags, 'test.o', 'ace_module.o',
                 *[str(work / 'build64' / (name + '.o')) for name in ('ace_input','ace_interpolation','microphy_p3')],
                 *libs, '-o', 'ace_model.exe'] ]
    for cmd in commands:
        subprocess.run(cmd, cwd=build, check=True)
    (work / 'diagnostic_manifest.json').write_text(json.dumps({
        'commands': commands, 'copies': {p.name:digest(p) for p in
        [work/'diagnostic_main.m', work/'ace_module_budget.F']},
        'scope': 'Observations of copied numerical statements; compare against production states.'
    }, indent=2)+'\n')


def compare(work):
    n, z, nt = 101, 401, 361
    count = n*z*3
    matlab = np.memmap(work/'matlab_states.bin', '<f8', mode='r', shape=(nt,count))
    header=np.fromfile(work/'fortran_states.bin','<i4',count=3)
    if not np.array_equal(header,[n,z,3]):
        raise ValueError('Unexpected state header')
    fcount=(n+1)*z*3
    errors=[]; extrema=[]; mean_mf=[]
    with Dataset(ROOT/'data/input/manaus1342_khn26.nc') as ds:
        area=np.asarray(ds['ace_area'][:]); area/=area.sum()
    for t in range(nt):
        offset=12+(0 if t==0 else fcount+z+(t-1)*fcount)*8
        f=np.memmap(work/'fortran_states.bin','<f8',mode='r',offset=offset,shape=(fcount,)).reshape((n+1,z,3),order='F')[:n]
        m=matlab[t].reshape((n,z,3),order='F')
        if not np.all(np.isfinite(f)) or not np.all(np.isfinite(m)):
            raise ValueError(f'Nonfinite state at {t*60} s')
        if min(f[:,:,2].min(),m[:,:,2].min())<0:
            raise ValueError(f'Negative water at {t*60} s')
        errors.append(np.max(np.abs(f-m),axis=(0,1)).tolist())
        extrema.append([[v.min(axis=(0,1)).tolist(),v.max(axis=(0,1)).tolist()] for v in (m,f)])
        mean_mf.append([float(np.max(np.abs(np.sum(v[:,:,0]*area[:,None],axis=0)))) for v in (m,f)])
    result={'duration_seconds':21600,'dt_seconds':6,'saved_interval_seconds':60,
            'field_order':['MF','theta_e','qt'],'max_abs_errors':np.max(errors,axis=0).tolist(),
            'errors_each_minute':errors,'extrema_each_minute_matlab_fortran':extrema,
            'max_area_mean_MF_each_minute':mean_mf,'finite_saved_states':True,'nonnegative_saved_water':True,
            'acceptance':'Metrics only; six-hour scientific acceptance requires developer review.'}
    (work/'trajectory_results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if 'each_minute' not in k},indent=2))


def budgets(work):
    """Account for recorded increments; do not equate water loss to surface rain."""
    result = {'weighting': 'rho_ref * dz * area/sum(area), levels 1..400',
              'units': {'theta_e_inventory': 'K kg m-2', 'water_inventory': 'kg m-2',
                        'column_native_removal': 'kg m-2 (numerically mm water equivalent)'},
              'limits': 'Dynamics includes clipping. Stage closure is accounting, not an independent physical conservation test. Native removal is not transported surface rain.'}
    with Dataset(ROOT/'data/input/manaus1342_khn26.nc') as ds:
        area=np.asarray(ds['ace_area'][:]); area/=area.sum()
    series={}
    for name in ('matlab','fortran'):
        raw=np.fromfile(work/f'{name}_budget.bin','<f8')
        if raw.size!=3600*110:
            raise ValueError(f'{name}: expected 3600 complete budget rows, got {raw.size/110}')
        rows=raw.reshape((3600,110))
        if not np.all(np.isfinite(rows)) or not np.array_equal(rows[:,0],np.arange(1,3601)*6):
            raise ValueError(f'{name}: nonfinite or incorrect budget timestamps')
        inv=rows[:,1:9].reshape((3600,4,2))
        changes=np.diff(inv,axis=1)
        rain=rows[:,9:]
        continuity=np.max(np.abs(inv[1:,0]-inv[:-1,3]),axis=0)
        observed=inv[-1,3]-inv[0,0]
        terms=changes.sum(axis=0)
        accumulated=rain.sum(axis=0)
        result[name]={'initial_inventory':inv[0,0].tolist(),'final_inventory':inv[-1,3].tolist(),
                      'net_change':observed.tolist(),
                      'dynamics_and_clipping_change':terms[0].tolist(),
                      'precipitation_change':terms[1].tolist(),'damping_change':terms[2].tolist(),
                      'accounting_residual':(observed-terms.sum(axis=0)).tolist(),
                      'max_step_continuity_error':continuity.tolist(),
                      'column_native_removal_mm':accumulated.tolist(),
                      'domain_native_removal_mm':float(accumulated@area),
                      'min_native_step_removal':float(rain.min()),
                      'water_sink_accounting_residual':float(terms[1,1]+accumulated@area)}
        series[name]=rows
    result['max_abs_budget_stage_difference']=np.max(np.abs(series['matlab'][:,1:9]-series['fortran'][:,1:9]),axis=0).tolist()
    result['max_abs_column_accumulation_difference_mm']=float(np.max(np.abs(np.sum(series['matlab'][:,9:],axis=0)-np.sum(series['fortran'][:,9:],axis=0))))
    (work/'budget_results.json').write_text(json.dumps(result,indent=2)+'\n')


def diagnostic_identity(work):
    production=np.memmap(work/'matlab_states.bin','<f8',mode='r')
    diagnostic=np.memmap(work/'matlab_diagnostic_states.bin','<f8',mode='r')
    if production.size!=361*101*401*3 or diagnostic.size!=production.size:
        raise ValueError('Incomplete MATLAB trajectory')
    matlab_identical=np.array_equal(production,diagnostic)
    fortran_identical=digest(work/'fortran_states.bin')==digest(work/'fortran_diagnostic_states.bin')
    if not matlab_identical or not fortran_identical:
        raise ValueError('Diagnostic copies changed production saved states')
    (work/'diagnostic_identity.json').write_text(json.dumps({'matlab_exact_saved_state_identity':True,
                                                          'fortran_exact_state_stream_identity':True},indent=2)+'\n')


def compare_output(work):
    fields=['mf','the','qt','ql',None,'qi',None,'rh','B']
    path=work/'fortran.dat'
    expected=361*9*401*101*4
    if path.stat().st_size!=expected:
        raise ValueError('Incomplete nine-field production output')
    data=np.memmap(path,'<f4',mode='r',shape=(361,9,401,101))
    result={}
    with Dataset(work/'matlab.nc') as ds:
        if ds.reference_version!='KHN26 2025-11' or ds.profile_index!=1342 or ds.physics!='native':
            raise ValueError('Unexpected MATLAB production provenance')
        if not np.array_equal(ds['time'][:],np.arange(361)*60):
            raise ValueError('Unexpected production timestamps')
        for index,name in enumerate(fields):
            if name is None:
                if np.any(data[:,index]!=0):
                    raise ValueError('Native rain/riming slot is not zero')
                continue
            variable=ds[name]
            dims=variable.dimensions
            errors=[]
            for t in range(361):
                selection=[slice(None)]*3;selection[dims.index('time')]=t
                m=np.asarray(variable[tuple(selection)])
                remaining=[d for d in dims if d!='time']
                m=np.transpose(m,[remaining.index('zc'),remaining.index('ncols')])
                if name=='rh':m=m/100
                f=data[t,index].astype(float)
                if not np.all(np.isfinite(m)) or not np.all(np.isfinite(f)):
                    raise ValueError(f'Nonfinite derived output {name}, minute {t}')
                errors.append(float(np.max(np.abs(m-f))))
            result[name]={'max_absolute_difference':max(errors),'errors_each_minute':errors}
    result['scope']='Production diagnostic output; Fortran real32 storage, real64 model state. Metrics are not release acceptance thresholds.'
    (work/'output_results.json').write_text(json.dumps(result,indent=2)+'\n')


def watch(work):
    """Wait for complete artifacts; preserve failures and publish a status file."""
    sizes={'matlab_states.bin':361*101*401*3*8,
           'matlab_diagnostic_states.bin':361*101*401*3*8,
           'fortran_states.bin':12+(361*102*401*3+401)*8,
           'fortran_diagnostic_states.bin':12+(361*102*401*3+401)*8,
           'fortran.dat':361*9*401*101*4,
           'fortran_diagnostic.dat':361*9*401*101*4,
           'matlab_budget.bin':3600*110*8,'fortran_budget.bin':3600*110*8}
    config=json.loads((work/'configuration.json').read_text())
    config['trajectory_tool_sha256']=digest(Path(__file__))
    config['executables_sha256']={str(p.relative_to(work)):digest(p) for p in
                                (work/'build64/ace_model.exe',work/'build_budget/ace_model.exe')}
    (work/'trajectory_configuration.json').write_text(json.dumps(config,indent=2)+'\n')
    while True:
        actual={name:(work/name).stat().st_size if (work/name).exists() else 0 for name in sizes}
        status={'updated_utc':datetime.now(timezone.utc).isoformat(),'state':'running',
                'expected_bytes':sizes,'actual_bytes':actual}
        try:
            for log in ('matlab.log','matlab_diagnostic.log','fortran.log','fortran_diagnostic.log'):
                path=work/log
                if path.exists():
                    tail=path.read_text(errors='replace')[-16000:]
                    if any(marker in tail for marker in ('SIGFPE','ERROR STOP','Error using','Error in ','check 2')):
                        raise RuntimeError(f'Model failure in {log}; preserve logs and partial states for review')
            if any(actual[name]>size for name,size in sizes.items()):
                raise ValueError('Unexpected excess artifact length')
            if all(actual[name]==size for name,size in sizes.items()):
                if digest(config['input'])!=config['input_sha256']:
                    raise ValueError('Input changed during run')
                for name,sha in config['sources'].items():
                    if digest(ROOT/name)!=sha:
                        raise ValueError(f'Production source changed during run: {name}')
                diagnostic_identity(work);compare(work);budgets(work);compare_output(work)
                reports={name:json.loads((work/name).read_text()) for name in
                         ('diagnostic_identity.json','trajectory_results.json','budget_results.json','output_results.json')}
                reports['configuration']=config
                reports['artifacts']={name:{'bytes':size,'sha256':digest(work/name)} for name,size in sizes.items()}
                reports['acceptance']='Completed numerical evidence; physical interpretation and release acceptance require developer review.'
                (work/'six_hour_report.json').write_text(json.dumps(reports,indent=2)+'\n')
                status['state']='completed_pending_scientific_review'
        except Exception as exc:
            status['state']='failed';status['error']=str(exc)
        temp=work/'trajectory_status.tmp'
        temp.write_text(json.dumps(status,indent=2)+'\n');temp.replace(work/'trajectory_status.json')
        if status['state']!='running':
            print(json.dumps(status,indent=2));return
        time.sleep(60)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--compare',action='store_true')
    parser.add_argument('--budgets',action='store_true')
    parser.add_argument('--identity',action='store_true')
    parser.add_argument('--output',action='store_true')
    parser.add_argument('--watch',action='store_true')
    args=parser.parse_args(); work=args.work.resolve()
    if args.prepare: prepare(work)
    if args.compare: compare(work)
    if args.budgets: budgets(work)
    if args.identity: diagnostic_identity(work)
    if args.output: compare_output(work)
    if args.watch: watch(work)
