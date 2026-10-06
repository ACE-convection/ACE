#!/usr/bin/env python3
"""Plot validated singleACE scalar anomalies and saved-state diagnostics."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from netCDF4 import Dataset

from single import compare, digest


def main(work):
    report = compare(work, 'full')
    case = report['case']
    n, z, count = 101, 401, report['saved_states']
    with Dataset(case['input']) as ds:
        height = np.asarray(ds['zm'][:]) / 1000
        reference = np.stack([ds['theta_e_zc'][:], ds['qt_zc'][:]], axis=1)
    m = np.memmap(work/'full_matlab_states.bin', '<f8', mode='r', shape=(count,n*z*3))
    scalars = []
    for i in range(count):
        offset = 12 + 8*(i*(n+1)*z*3 + (z if i else 0))
        f = np.memmap(work/'full_fortran_states.bin', '<f8', mode='r', offset=offset,
                      shape=((n+1)*z*3,)).reshape((n+1,z,3), order='F')
        scalars.append(np.stack([m[i].reshape((n,z,3), order='F')[0,:,1:3], f[0,:,1:3]]))
    scalars = np.asarray(scalars)
    hours = np.asarray(report['time_seconds'])/3600
    selected = height <= 20
    out = work/'full_comparison'
    out.mkdir(exist_ok=True)
    fig, axes = plt.subplots(3,2,figsize=(13,10),sharex=True,sharey=True,layout='constrained')
    for j, (field, units, factor) in enumerate([('theta_e anomaly','K',1),('qt anomaly','g/kg',1000)]):
        values = (scalars[:,:,:,j]-reference[None,None,:,j])*factor
        difference = (scalars[:,1,:,j]-scalars[:,0,:,j])*factor
        limit = np.max(np.abs(values[:,:,selected])) or 1
        dlimit = np.max(np.abs(difference[:,selected])) or 1
        for row, data in enumerate([values[:,0], values[:,1], difference]):
            bound = dlimit if row == 2 else limit
            mesh = axes[row,j].pcolormesh(hours,height[selected],data[:,selected].T,
                                         shading='nearest',cmap='RdBu_r',vmin=-bound,vmax=bound,rasterized=True)
            axes[row,j].set_title(['MATLAB','Fortran OpenMP 6','Fortran minus MATLAB'][row]+' / '+field)
            axes[row,j].set_ylabel('Height (km)')
            fig.colorbar(mesh,ax=axes[row,j],label=units)
        axes[2,j].set_xlabel('Time (hours)')
    fig.suptitle('KHN26 singleACE / 3 hours / scalars relative to reference sounding')
    for ext in ('png','pdf'): fig.savefig(out/('scalar_anomalies.'+ext),dpi=160)
    plt.close(fig)
    errors = np.asarray(report['max_abs_error_each_state'])
    means = np.asarray(report['area_mean_MF_max_matlab_fortran'])
    inactive = np.asarray(report['inactive_scalar_deviation_matlab_fortran'])
    fig, axes = plt.subplots(2,2,figsize=(12,8),layout='constrained')
    for j, field in enumerate(('MF','theta_e','qt')):
        axes[0,0].semilogy(hours,np.maximum(errors[:,j],1e-18),label=field)
    axes[0,0].set_title('Maximum absolute Fortran minus MATLAB error\n(native units)', fontsize=10)
    for j, name in enumerate(('MATLAB','Fortran')):
        axes[0,1].semilogy(hours[1:],np.maximum(means[1:,j],1e-18),label=name)
        axes[1,0].plot(hours,np.asarray(report['active_MF_abs_max_matlab_fortran'])[:,j],label=name)
        for k, field in enumerate(('theta_e','qt')):
            axes[1,1].semilogy(hours,np.maximum(inactive[:,j,k],1e-18),label=name+' '+field)
    axes[0,1].set_title('Maximum area-mean MF after mean correction\n(exclude initial pulse)', fontsize=10)
    axes[1,0].set_title('ACE 1 maximum absolute MF', fontsize=10)
    axes[1,1].set_title('Inactive scalar deviation from reference\n(native units)', fontsize=10)
    for ax in axes.flat:
        ax.set_xlabel('Time (hours)');ax.legend();ax.grid(alpha=.25)
    for ext in ('png','pdf'): fig.savefig(out/('diagnostics.'+ext),dpi=160)
    plt.close(fig)
    summary = {
        'saved_states':count, 'finite_saved_states':report['finite_saved_states'],
        'nonnegative_saved_qt':report['nonnegative_saved_qt'],
        'max_abs_error_MF_theta_e_qt':report['max_abs_error'],
        'max_poststep_area_mean_MF_matlab_fortran':means[1:].max(axis=0).tolist(),
        'max_inactive_theta_e_qt_deviation_matlab_fortran':inactive.max(axis=0).tolist(),
        'compensation_MF_equal_in_inactive_columns':True,
        'scope':'Saved states only; initial pulse precedes mean correction. No independent energy/water budget acceptance.',
        'artifacts_sha256':{p.name:digest(p) for p in out.iterdir() if p.suffix in ('.png','.pdf')}
    }
    (out/'diagnostic_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    main(parser.parse_args().work.resolve())
