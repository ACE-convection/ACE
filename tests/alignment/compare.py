#!/usr/bin/env python3
"""Compare binary64 prognostic values without imposing an acceptance tolerance."""
import argparse
import json
from pathlib import Path
import netCDF4
import numpy as np


def metrics(a, b):
    a = np.asarray(a); b = np.asarray(b)
    finite = np.isfinite(a) & np.isfinite(b)
    if not finite.all():
        return {'nonfinite_matlab': int((~np.isfinite(a)).sum()),
                'nonfinite_fortran': int((~np.isfinite(b)).sum())}
    diff = a - b
    index = np.unravel_index(np.argmax(abs(diff)), diff.shape)
    norm = float(np.linalg.norm(a.ravel()))
    nonzero = a != 0
    return {'exact_equal': bool(np.array_equal(a, b)),
            'max_abs': float(abs(diff).max()),
            'rms': float(np.sqrt(np.mean(diff**2))),
            'relative_l2': float(np.linalg.norm(diff.ravel()) / norm) if norm else None,
            'max_rel_nonzero_reference': float(np.max(abs(diff[nonzero] / a[nonzero]))) if nonzero.any() else None,
            'zero_reference_max_abs': float(np.max(abs(diff[~nonzero]))) if (~nonzero).any() else 0,
            'worst_index_one_based': [int(i + 1) for i in index],
            'matlab_at_worst': float(a[index]), 'fortran_at_worst': float(b[index])}


def compare(work, mode, input_file):
    with netCDF4.Dataset(work / ('matlab_' + mode + '.nc')) as ds:
        def get(name, order=None):
            a = np.asarray(ds[name][:])
            return a.transpose(order) if order is not None else a
        mh = get('state', (3,2,1,0))
        mi = get('initial_state',(2,1,0))
        mr = get('raw_tendency',(2,1,0))
        fields = {n: get(n,(1,0)) for n in ['initial_temperature','initial_vapor','initial_liquid','initial_ice','initial_buoyancy','upwind']}
        fields['weno'] = get('weno',(2,1,0))
        fields['reference_tv'] = get('reference_tv')
        fields['areas_m2'] = get('areas_m2')
        fields['perimeters_m'] = get('perimeters_m')
        times = get('time')
    binary = np.fromfile(work / ('fortran_' + mode + '.bin'),dtype='<f8')
    offset = 0
    def take(shape):
        nonlocal offset
        size = int(np.prod(shape))
        value = binary[offset:offset+size].reshape(shape,order='F')
        offset += size
        return value
    fi = take((8,801,3)).transpose(1,2,0)
    fr = take((8,801,3)).transpose(1,2,0)
    ffields = {n: take((8,801)).T for n in ['initial_temperature','initial_vapor','initial_liquid','initial_ice','initial_buoyancy']}
    ffields['weno'] = take((8,801,2)).transpose(1,2,0)
    ffields['upwind'] = take((8,801)).T
    ffields['reference_tv'] = take((801,))
    ffields['areas_m2'] = take((8,))
    ffields['perimeters_m'] = take((8,))
    fh = np.stack([fi, *[take((8,801,3)).transpose(1,2,0) for _ in range(30)]],axis=3)
    assert offset == binary.size and mh.shape == fh.shape
    assert np.isfinite(mh).all() and np.isfinite(fh).all(), 'Nonfinite trajectory'
    assert np.isfinite(mr).all() and np.isfinite(fr).all(), 'Nonfinite tendency'
    report = {'mode': mode, 'pulse_ace': 1 if mode.startswith('single') else 8,
              'dt_seconds': 4, 'duration_seconds': 120, 'precision': 'binary64 in both comparison outputs',
              'tolerance_status': 'No cross-implementation tolerance approved; metrics only',
              'initial_state': metrics(mi,fi), 'raw_tendency': {},
              'diagnostics': {}, 'snapshots': {}, 'budgets': {}}
    variables = ['theta_e','qt','MF']
    for j, name in enumerate(variables):
        report['raw_tendency'][name] = metrics(mr[:,j,:],fr[:,j,:])
    for name in fields:
        if name == 'weno':
            # Fortran's unassigned WENO boundaries are not a defined operator result.
            report['diagnostics']['weno_defined_interior'] = metrics(fields[name][1:800],ffields[name][1:800])
            report['diagnostics']['weno_boundary_note'] = 'Exclude levels 1 and 801 unassigned by Fortran; tendency top mask is levels 791:801.'
        elif name == 'upwind':
            report['diagnostics'][name] = metrics(fields[name],ffields[name])
            report['diagnostics']['upwind_below_top_mask'] = metrics(fields[name][:790],ffields[name][:790])
            report['diagnostics']['upwind_top_11'] = metrics(fields[name][790:],ffields[name][790:])
        else:
            report['diagnostics'][name] = metrics(fields[name],ffields[name])
    for time in [0,4,60,120]:
        n = int(np.flatnonzero(times == time)[0])
        report['snapshots'][str(time)] = {
            name: {'all_aces': metrics(mh[:,j,:,n],fh[:,j,:,n]),
                   'by_ace': [metrics(mh[:,j,i,n],fh[:,j,i,n]) for i in range(8)]}
            for j,name in enumerate(variables)}
    with netCDF4.Dataset(input_file) as ds:
        rho = np.asarray(ds['rho_zc'][:])
    for label, history, area in [('matlab',mh,fields['areas_m2']),('fortran',fh,ffields['areas_m2'])]:
        water = (history[:,1,:,:] * rho[:,None,None] * area[None,:,None] * 50).sum(axis=(0,1))
        report['budgets'][label] = {'column_water_kg_initial': float(water[0]),
                                   'column_water_kg_final': float(water[-1]),
                                   'change_kg': float(water[-1]-water[0]),
                                   'interpretation': 'Diagnostic over all 801 stored levels, including extra top level; sinks/sponge/open boundaries and frozen single columns prevent a conservation pass claim.'}
    if mode.startswith('single'):
        report['inactive_aces'] = {
            'matlab_max_state_change': float(np.max(abs(mh[:,:,1:,:]-mh[:,:,1:,0,None]))),
            'fortran_max_state_change': float(np.max(abs(fh[:,:,1:,:]-fh[:,:,1:,0,None]))),
            'initial_mask_matlab_exact_zero': bool(np.all(mr[:,:,1:]==0)),
            'initial_mask_fortran_exact_zero': bool(np.all(fr[:,:,1:]==0))}
    diagnostic_file=work / ('matlab_' + mode + '_diagnostics.nc')
    if diagnostic_file.is_file():
        with netCDF4.Dataset(diagnostic_file) as ds:
            md=np.asarray(ds['diagnostic'][:]).transpose(3,2,1,0)
        fd=np.fromfile(work / ('fortran_' + mode + '_diagnostics.bin'),dtype='<f8').reshape((8,801,5,4),order='F').transpose(1,2,0,3)
        report['snapshot_diagnostics']={
            str(time): {name: metrics(md[:,j,:,i],fd[:,j,:,i])
                       for j,name in enumerate(['T','q','ql','qi','buoyancy'])}
            for i,time in enumerate([0,4,60,120])}
        report['sampled_condensate']={
            'matlab_max_ql_plus_qi':float(np.max(md[:,2,:,:]+md[:,3,:,:])),
            'fortran_max_ql_plus_qi':float(np.max(fd[:,2,:,:]+fd[:,3,:,:])),
            'note':'Four diagnostic snapshots only; no precipitation equivalence claim.'}
    (work / (mode + '_comparison.json')).write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print(mode)
    print('initial state',report['initial_state'])
    for time,snapshot in report['snapshots'].items():
        print(time,{n:row['all_aces'].get('max_abs',row['all_aces']) for n,row in snapshot.items()})
    print('initial buoyancy',report['diagnostics']['initial_buoyancy'])
    return report


def compare_thermo(work):
    labels=json.loads((work/'thermo_labels.json').read_text())
    data=np.fromfile(work/'thermo_input.bin',dtype='<f8').reshape(10,7,order='F')
    m=np.fromfile(work/'thermo_matlab.bin',dtype='<f8').reshape(10,7,order='F')
    f=np.fromfile(work/'thermo_fortran.bin',dtype='<f8').reshape(10,7,order='F')
    names=['T','q','ql','qi','theta_e_formula','precip_dtheta_e','precip_dqt']
    report={'scope':'Common manufactured states; actual inversion/formula/sink routines; sink timing across RK stages is not changed or unified.',
            'all_finite':bool(np.isfinite(m).all() and np.isfinite(f).all()),'cases':{}}
    for i,label in enumerate(labels):
        report['cases'][label]={
            'input':{'T':float(data[i,3]),'p':float(data[i,2]),'q':float(data[i,4]),'ql':float(data[i,5]),'qi':float(data[i,6]),'theta_e':float(data[i,0]),'qt':float(data[i,1])},
            'matlab':dict(zip(names,map(float,m[i]))),'fortran':dict(zip(names,map(float,f[i]))),
            'difference_matlab_minus_fortran':dict(zip(names,map(float,m[i]-f[i]))),
            'temperature_error_from_constructed_state':{'matlab':float(m[i,0]-data[i,3]),'fortran':float(f[i,0]-data[i,3])}}
    (work/'thermo_comparison.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print('Near-threshold dqt:',report['cases']['liquid_at_onset']['matlab']['precip_dqt'],report['cases']['liquid_at_onset']['fortran']['precip_dqt'])
    return report


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('mode',choices=['single','multi','single_precip','multi_precip',
                                     'single_ice_precip','multi_ice_precip','thermo'])
    parser.add_argument('--input',type=Path,default=Path('data/input/manus208.nc'))
    args=parser.parse_args()
    if args.mode=='thermo': compare_thermo(args.work)
    else: compare(args.work,args.mode,args.input)
