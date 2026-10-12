#!/usr/bin/env python3
"""Independently review completed three-hour multiACE saved states and plot them."""
import argparse
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

from plot_multi import plot


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def review(work, out, baseline=None):
    cfg = json.loads((work / 'configuration.json').read_text())
    case = cfg['case']
    saved = json.loads((work / 'full_state_results.json').read_text())
    n, z, nt = 101, 401, 181
    if (case['duration_seconds'], case['output_interval_seconds'],
            case['dt_seconds'], saved['saved_states']) != (10800, 60, 4, nt):
        raise ValueError('Expected three hours at dt=4 s with minute records')
    for lang in ('matlab', 'fortran'):
        path = work / 'full' / (lang + '_states.bin')
        expected_size = nt * (n if lang == 'matlab' else n+1) * z * 3 * 8
        expected_size += 0 if lang == 'matlab' else 12 + z * 8
        if path.stat().st_size != expected_size:
            raise ValueError(f'Unexpected stream size: {lang}')
        if digest(path) != saved['artifacts_sha256'][path.name]:
            raise ValueError(f'Stream hash differs from completed report: {lang}')
    fp = work / 'full' / 'fortran_states.bin'
    if not np.array_equal(np.fromfile(fp, '<i4', count=3), [n, z, 3]):
        raise ValueError('Fortran header mismatch')
    mstream = np.memmap(work/'full/matlab_states.bin', '<f8', mode='r', shape=(nt,n*z*3))
    height = np.asarray(case['height_m'])
    fractions = np.asarray(case['ace_area_m2']); fractions /= fractions.sum()
    mf = np.empty((2, nt, n, z))
    errors, means, extrema, locations = [], [], [], [None]*3
    sums, norms = np.zeros(3), np.zeros(3)
    maxima = np.full(3, -1.0)
    for minute in range(nt):
        offset = 12 + minute*(n+1)*z*3*8 + (z*8 if minute else 0)
        f = np.memmap(fp, '<f8', mode='r', offset=offset, shape=((n+1)*z*3,))
        f = f.reshape((n+1,z,3), order='F')[:n]
        m = mstream[minute].reshape((n,z,3), order='F')
        if not all(np.isfinite(v).all() and v[:,:,2].min() >= 0 for v in (m,f)):
            raise ValueError(f'Invalid saved state at minute {minute}')
        delta = f-m
        error = np.max(np.abs(delta), axis=(0,1)); errors.append(error)
        sums += np.sum(delta**2, axis=(0,1)); norms += np.sum(m**2, axis=(0,1))
        means.append([np.max(np.abs(np.sum(v[:,:,0]*fractions[:,None],axis=0))) for v in (m,f)])
        extrema.append([[v.min(axis=(0,1)).tolist(),v.max(axis=(0,1)).tolist()] for v in (m,f)])
        for field in range(3):
            if error[field] > maxima[field]:
                ace,k = np.unravel_index(np.argmax(np.abs(delta[:,:,field])), (n,z))
                locations[field] = dict(time_minutes=minute, ACE_column=int(ace+1),
                    height_m=float(height[k]), matlab=float(m[ace,k,field]), fortran=float(f[ace,k,field]))
                maxima[field] = error[field]
        mf[:,minute] = np.stack((m[:,:,0],f[:,:,0]))
    errors = np.asarray(errors)
    if not np.array_equal(errors, np.asarray(saved['max_abs_error_each_state'])):
        raise ValueError('Independent state errors differ from original report')
    if np.any(mf[:,0] != 0):
        raise ValueError('Expected zero initial MF')
    with np.load(work/'full/mf_all_aces.npz') as ds:
        if not (np.array_equal(mf[0],ds['matlab']) and np.array_equal(mf[1],ds['fortran'])):
            raise ValueError('Plot cache differs from raw streams')
    out.mkdir(parents=True, exist_ok=True)
    visible = height <= 20000
    snapshots = []
    for minute in range(20,181,20):
        a,b = mf[:,minute][:,:,visible].reshape(2,-1)
        snapshots.append(dict(time_minutes=minute, correlation=float(np.corrcoef(a,b)[0,1]),
            relative_L2_error=float(np.linalg.norm(a-b)/np.linalg.norm(a))))
    peak = []
    for lang in range(2):
        minute,ace,k = np.unravel_index(np.argmax(np.abs(mf[lang])),mf[lang].shape)
        peak.append(dict(language=('matlab','fortran')[lang], time_minutes=int(minute),
            ACE_column=int(ace+1),height_m=float(height[k]),MF=float(mf[lang,minute,ace,k])))
    old = json.loads(baseline.read_text()) if baseline else None
    result = dict(saved_states=nt, duration_seconds=10800, field_order=['MF','theta_e','qt'],
        finite_saved_states=True, nonnegative_saved_qt=True, raw_hashes_verified=True,
        raw_errors_match_original_report=True, MF_cache_matches_raw=True,
        max_abs_error=maxima.tolist(), max_error_locations=locations,
        time_minutes=list(range(nt)), max_abs_error_each_state=errors.tolist(),
        relative_L2_error=np.sqrt(sums/norms).tolist(),
        area_mean_MF_max_matlab_fortran=np.max(means,axis=0).tolist(),
        MF_peak=peak, snapshot_diagnostics=snapshots,
        state_sha256={name:saved['artifacts_sha256'][name] for name in ('matlab_states.bin','fortran_states.bin')},
        scope='Minute-saved states only; no predefined three-hour acceptance tolerance, wave-speed validation, or closed water budget.')
    if old:
        for key in ('input_sha256','dt_seconds','physics','bubble_delta_K','initial_mf_amplitude','ace_width_m'):
            if old['case'][key] != case[key]:
                raise ValueError(f'Baseline case differs: {key}')
        result['baseline'] = str(baseline)
        result['baseline_sha256'] = digest(baseline)
        result['baseline_max_abs_error'] = old['max_abs_error']
        result['baseline_max_abs_error_each_state'] = old['max_abs_error_each_state']
        result['max_error_reduction_percent'] = (100*(1-maxima/np.asarray(old['max_abs_error']))).tolist()
    # Regenerate the established spatial and selected-column figures after cache verification.
    plot(work,'full')
    for name in ('spatial_mf','selected_aces'):
        for ext in ('png','pdf'):
            (out/(name+'.'+ext)).write_bytes((work/'full/comparison'/(name+'.'+ext)).read_bytes())
    edges = np.r_[0,np.cumsum(case['ace_width_m'])]/1000
    h = height[visible]/1000
    height_edges = np.r_[h[0]-(h[1]-h[0])/2, (h[:-1]+h[1:])/2, h[-1]+(h[-1]-h[-2])/2]
    fig,axes = plt.subplots(6,3,figsize=(17,12),layout='constrained',sharex=True,sharey=True)
    diff_limit = max(np.max(np.abs(mf[1,30::30,:,visible]-mf[0,30::30,:,visible])),1e-15)
    for row,minute in enumerate(range(30,181,30)):
        fields = [mf[0,minute][:,visible],mf[1,minute][:,visible]]
        fields.append(fields[1]-fields[0])
        for col,field in enumerate(fields):
            limit = 1 if col < 2 else diff_limit
            mesh = axes[row,col].pcolormesh(edges,height_edges,field.T,
                shading='flat',cmap='RdBu_r',vmin=-limit,vmax=limit,rasterized=True)
            axes[row,col].set(title=f'{minute} min / '+('MATLAB','Fortran','Fortran - MATLAB')[col],
                xlim=(0,500),ylim=(0,20),ylabel='Height (km)',xlabel='Distance (km)')
            axes[row,col].set_box_aspect(0.2)
            if row == 5:
                fig.colorbar(mesh,ax=axes[:,col],orientation='horizontal',shrink=0.8,
                    extend='both' if col<2 else 'neither',label='MF (kg m$^{-2}$ s$^{-1}$)')
    fig.suptitle('KHN26 aligned native multiACE / MF snapshots through three hours\nPhysical columns span 500 km; MF panels clipped at +/-1; difference scale is separate')
    for ext in ('png','pdf'): fig.savefig(out/('mf_snapshots.'+ext),dpi=160)
    plt.close(fig)
    fig,axes = plt.subplots(3,1,figsize=(10,8),sharex=True,layout='constrained')
    for field,ax in enumerate(axes):
        ax.semilogy(np.arange(nt),np.where(errors[:,field]>0,errors[:,field],np.nan),label='Aligned run')
        if old:
            oe = np.asarray(old['max_abs_error_each_state'])[:,field]
            ax.semilogy(np.arange(nt),np.where(oe>0,oe,np.nan),label='Pre-alignment run',alpha=0.7)
        ax.set(ylabel=('MF (kg m$^{-2}$ s$^{-1}$)','theta_e (K)','qt (kg kg$^{-1}$)')[field],xlim=(0,180))
        ax.grid(alpha=0.25); ax.legend()
    axes[-1].set_xlabel('Simulation time (minutes)')
    fig.suptitle('Maximum absolute Fortran - MATLAB difference / all columns and heights')
    for ext in ('png','pdf'): fig.savefig(out/('state_errors.'+ext),dpi=160)
    plt.close(fig)
    (out/'review_results.json').write_text(json.dumps(result,indent=2)+'\n')
    (out/'source_configuration.json').write_bytes((work/'configuration.json').read_bytes())
    manifest = {p.name:digest(p) for p in out.iterdir() if p.is_file() and p.name!='manifest.json'}
    manifest['review_script_sha256'] = digest(Path(__file__))
    manifest['source_configuration_sha256'] = digest(work/'configuration.json')
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in
        ('time_minutes','max_abs_error_each_state','baseline_max_abs_error_each_state')},indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--baseline',type=Path)
    args = parser.parse_args()
    review(args.work.resolve(),args.output.resolve(),args.baseline.resolve() if args.baseline else None)
