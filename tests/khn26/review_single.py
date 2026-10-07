#!/usr/bin/env python3
"""Review completed KHN26 singleACE saved states, without integrating the model.

Water/Theta_e inventories and instantaneous exchange rates are diagnostics.
Minute samples cannot close an SSPRK stage budget or a total-energy budget.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def review(work, output, plot):
    case = json.loads((work / 'single_case.json').read_text())
    original = json.loads((work / 'full_results.json').read_text())
    if (case['duration_seconds'], case['dt_seconds'], case['physics'],
            case['mean_mf_zero'], case['full_basis_columns']) != (10800, 4.0, 'none', True, 101):
        raise ValueError('This review is specific to the completed three-hour KHN26 case')
    paths = [work / 'full_matlab_states.bin', work / 'full_fortran_states.bin',
             work / 'full_matlab.nc', Path(case['input'])]
    hashes = {str(p): digest(p) for p in paths}
    for p in paths[:3]:
        if hashes[str(p)] != original['artifacts_sha256'][p.name]:
            raise ValueError(f'Changed reference artifact: {p}')
    if hashes[str(paths[3])] != case['input_sha256']:
        raise ValueError('Changed shared input')
    with Dataset(case['input']) as ds:
        area = np.asarray(ds['ace_area'][:])
        perimeter = np.asarray(ds['ace_perimeter'][:])
        rho = np.asarray(ds['rho_zc'][:])
        rho_mf = np.asarray(ds['rho_mf'][:])
        height = np.asarray(ds['zm'][:])
        scalar_height = np.asarray(ds['z'][:])
        dz = float(ds['dz'][...])
        reference = np.stack([ds['theta_e_zc'][:], ds['qt_zc'][:]], axis=-1)
    if not np.allclose(np.diff(height), dz) or dz != 100:
        raise ValueError('Unexpected grid')
    times = np.asarray(original['time_seconds'])
    if not np.array_equal(times, np.arange(181) * 60):
        raise ValueError('Incomplete saved trajectory')
    n, z = 101, 401
    size, fsize = n*z*3, (n+1)*z*3
    if paths[0].stat().st_size != 181*size*8 or paths[1].stat().st_size != 12+(181*fsize+z)*8:
        raise ValueError('Incorrect state stream sizes')
    if not np.array_equal(np.fromfile(paths[1], '<i4', count=3), [n,z,3]):
        raise ValueError('Incorrect state header')
    matlab = np.memmap(paths[0], '<f8', mode='r', shape=(181,size))
    fractions = area / area.sum()
    weights = fractions[:,None] * rho[None,:400] * dz
    edge_weights = np.full(z, dz)
    edge_weights[[0,-1]] *= .5
    # Values pinned to the preserved drivers; compare the two source files.
    root = Path(__file__).resolve().parents[2]
    msource = root/'migration_work/khn26_single_3h/single_main.m'
    fsource = work/'ace_module_single.F'
    for source, anchors in [(msource, ['nju = 0.09;', 'SLD = 6e3;', 'SLTau = 180;',
                                      'dXdt(end-10:end,1:3,:) = 0;', 'dXdt(:,:,2:end) = 0;']),
                             (fsource, ['nju = 0.09', 'SLD = 6e3', 'SLTau = 180',
                                        'dXdt(2:ncols,:,:)=0.', 'dXdt(:,nz-10:nz,:)=0.'])]:
        text = source.read_text()
        if any(anchor not in text for anchor in anchors):
            raise ValueError(f'Unrecognized source constants/masks: {source}')
        hashes[str(source)] = digest(source)
    eps_tur = .09 * perimeter[0] / area[0]
    sponge = np.exp((scalar_height-scalar_height[-1])/6000) / 180 / rho
    series = {}
    max_error = np.zeros(3)
    for name in ('matlab', 'fortran'):
        rows = {key: [] for key in ('inventory', 'column_inventory', 'inventory_anomaly',
                'exchange_rate', 'mixing_rate', 'sponge_snapshot_rate',
                'vertical_kinetic_energy', 'active_mf_max', 'active_mf_min',
                'active_updraft_height_m', 'active_vertical_velocity_max')}
        boundary_max = 0.
        min_qt = np.inf
        for index in range(181):
            m = matlab[index].reshape((n,z,3), order='F')
            if name == 'matlab':
                state = m
            else:
                offset = 12+8*(index*fsize+(z if index else 0))
                state = np.memmap(paths[1], '<f8', mode='r', offset=offset,
                                  shape=(fsize,)).reshape((n+1,z,3),order='F')[:n]
                max_error = np.maximum(max_error, np.max(np.abs(state-m),axis=(0,1)))
            if not np.isfinite(state).all() or np.any(state[:,:,2] < 0):
                raise ValueError(f'Invalid {name} saved state {index}')
            min_qt = min(min_qt, float(state[:,:,2].min()))
            scalars = state[:,:400,1:3]
            anomaly = scalars-reference[None,:400]
            column = np.sum(scalars*rho[None,:400,None]*dz,axis=1)
            rows['column_inventory'].append(column[0].tolist())
            rows['inventory'].append(np.sum(scalars*weights[:,:,None],axis=(0,1)).tolist())
            rows['inventory_anomaly'].append(np.sum(anomaly*weights[:,:,None],axis=(0,1)).tolist())
            # Only levels 1..390 have scalar dynamics; vertical convergence
            # telescopes to the flux at interface 391, whose MF is verified zero.
            boundary_max = max(boundary_max, abs(float(state[0,390,0])))
            dm = np.diff(state[0,:,0])[:390] / dz
            upwind = np.where(dm[:,None] > 0, state[1,:390,1:3], state[0,:390,1:3])
            adv = fractions[0]*np.sum(dm[:,None]*upwind*dz,axis=0)
            # Use the actual neighboring state, including its roundoff deviation.
            mix = -fractions[0]*np.sum(eps_tur*(state[0,:390,1:3]-state[1,:390,1:3])*rho[:390,None]*dz,axis=0)
            rows['exchange_rate'].append(adv.tolist())
            rows['mixing_rate'].append(mix.tolist())
            rows['sponge_snapshot_rate'].append((-np.sum(anomaly*sponge[None,:400,None]*weights[:,:,None],axis=(0,1))).tolist())
            # Edge-grid quadrature of vertical KE only; excludes horizontal KE,
            # internal/potential energy and pressure/nonlocal work.
            ke = .5*np.sum(fractions[:,None]*state[:,:,0]**2/rho_mf[None,:]*edge_weights[None,:])
            rows['vertical_kinetic_energy'].append(float(ke))
            rows['active_mf_max'].append(float(state[0,:,0].max()))
            rows['active_mf_min'].append(float(state[0,:,0].min()))
            rows['active_updraft_height_m'].append(float(height[np.argmax(state[0,:,0])]))
            rows['active_vertical_velocity_max'].append(float((state[0,:,0]/rho_mf).max()))
        if boundary_max != 0:
            raise ValueError('Nonzero dynamics-cutoff MF requires explicit WENO boundary flux analysis')
        inv = np.asarray(rows['inventory'])
        col = np.asarray(rows['column_inventory'])
        anomaly = np.asarray(rows['inventory_anomaly'])
        # Changes computed from anomalies avoid subtracting large background totals.
        change = anomaly[-1]-anomaly[0]
        exchange = np.asarray(rows['exchange_rate'])+np.asarray(rows['mixing_rate'])
        rates = exchange+np.asarray(rows['sponge_snapshot_rate'])
        sampled_integral = np.sum((rates[:-1]+rates[1:])*.5*60,axis=0)
        sampled_terms = {key: np.sum((np.asarray(rows[key])[:-1]+np.asarray(rows[key])[1:])*.5*60,axis=0).tolist()
                         for key in ('exchange_rate','mixing_rate','sponge_snapshot_rate')}
        ke = np.asarray(rows['vertical_kinetic_energy'])
        peak = int(np.argmax(rows['active_mf_max']))
        rows.update(initial_inventory=inv[0].tolist(),final_inventory=inv[-1].tolist(),
                    net_inventory_change=change.tolist(),
                    relative_water_change_percent=float(100*change[1]/inv[0,1]),
                    active_column_net_change=(col[-1]-col[0]).tolist(),
                    sampled_rate_integral=sampled_integral.tolist(),
                    sampled_rate_integrals_by_term=sampled_terms,
                    sampled_budget_residual=(change-sampled_integral).tolist(),
                    cutoff_interface_MF_max=boundary_max,minimum_saved_qt=min_qt,
                    peak_updraft={'time_seconds':int(times[peak]),
                        'height_m':rows['active_updraft_height_m'][peak],
                        'MF':rows['active_mf_max'][peak]},
                    vertical_KE_initial_peak_final=[float(ke[0]),float(ke.max()),float(ke[-1])])
        series[name] = rows
    if np.any(max_error > [1e-9,1e-7,1e-11]):
        raise ValueError('Saved-state cross-language agreement failed')
    # Independent MATLAB output layout and longdouble summation check.
    with Dataset(paths[2]) as ds:
        if not np.array_equal(np.asarray(ds['time'][:]),times):
            raise ValueError('NetCDF timestamps differ')
        nc_change = []
        for field in ('the','qt'):
            initial = np.asarray(ds[field][0,:400,:],dtype=np.longdouble)
            final = np.asarray(ds[field][-1,:400,:],dtype=np.longdouble)
            nc_change.append(float(np.sum((final-initial)*np.asarray(weights.T,dtype=np.longdouble))))
    nc_error = np.abs(np.asarray(nc_change)-series['matlab']['net_inventory_change'])
    if np.any(nc_error > [1e-8,1e-12]):
        raise ValueError('Independent NetCDF inventory check failed')
    comparisons = {key: np.max(np.abs(np.asarray(series['matlab'][key])-np.asarray(series['fortran'][key])),axis=0).tolist()
                   for key in ('inventory','inventory_anomaly','exchange_rate','mixing_rate',
                               'sponge_snapshot_rate','vertical_kinetic_energy')}
    report = {'case':case,'time_seconds':times.tolist(),'field_order':['theta_e','qt'],
              'units':{'theta_e_inventory':'K kg m-2','water_inventory':'kg m-2',
                       'water_rate':'kg m-2 s-1','vertical_kinetic_energy':'J m-2'},
              'weighting':'rho_zc * dz * normalized ACE area, physical scalar levels 1..400',
              'max_abs_state_error_MF_theta_e_qt':max_error.tolist(),
              'independent_matlab_netcdf_longdouble_net_change':nc_change,
              'independent_netcdf_check_abs_error':nc_error.tolist(),
              'max_abs_matlab_fortran_diagnostic_difference':comparisons,
              'series':series,'artifacts_sha256':hashes,
              'analysis_script_sha256':digest(Path(__file__)),
              'limits':['Instantaneous exchange rates reconstructed at 60 s saved states, not SSPRK stage sums.',
                        'Sampled trapezoidal residual includes temporal sampling, operator splitting and unobserved qt clipping; it is not a conservation error bound.',
                        'SingleACE masks the receiving columns; active-column lateral exchange does not cancel in the domain inventory.',
                        'Sponge snapshot rate is the continuous relaxation rate, not the exact implicit per-step increment.',
                        'Theta_e inventory is a tracer diagnostic, not total energy.',
                        'Vertical KE excludes horizontal KE, thermodynamic energy, potential energy, pressure work and nonlocal work; no total-energy acceptance.',
                        'Exact physical acceptance criteria and complete stage accounting require developer review.']}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n')
    if plot:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig,axes=plt.subplots(2,2,figsize=(12,8),layout='constrained')
        for name,style in (('matlab','-'),('fortran','--')):
            data=series[name]
            axes[0,0].plot(times/3600,np.asarray(data['inventory_anomaly'])[:,1]-data['inventory_anomaly'][0][1],style,label=name)
            axes[0,1].plot(times/3600,np.asarray(data['exchange_rate'])[:,1],style,label=name+' lateral advection')
            axes[0,1].plot(times/3600,np.asarray(data['mixing_rate'])[:,1],style,label=name+' mixing')
            axes[1,0].plot(times/3600,data['vertical_kinetic_energy'],style,label=name)
            axes[1,1].plot(times/3600,data['active_mf_max'],style,label=name+' max MF')
            axes[1,1].plot(times/3600,data['active_mf_min'],style,label=name+' min MF')
        for ax,title,unit in zip(axes.flat,
                ['Domain water inventory change','Saved-state water exchange rates','Vertical kinetic energy only','ACE 1 MF extrema'],
                ['kg m-2','kg m-2 s-1','J m-2','kg m-2 s-1']):
            ax.set(title=title,xlabel='Time (hours)',ylabel=unit)
            ax.grid(alpha=.25);ax.legend(fontsize=8)
        fig.suptitle('KHN26 singleACE: saved-state review (not closed total-energy budget)')
        plot.parent.mkdir(parents=True,exist_ok=True)
        for ext in ('png','pdf'):fig.savefig(plot.with_suffix('.'+ext),dpi=160)
        plt.close(fig)
    print(json.dumps({name:{key:series[name][key] for key in
          ('net_inventory_change','relative_water_change_percent','peak_updraft','vertical_KE_initial_peak_final','sampled_budget_residual')}
          for name in series},indent=2))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--plot',type=Path)
    args=parser.parse_args()
    review(args.work.resolve(),args.output,args.plot)
