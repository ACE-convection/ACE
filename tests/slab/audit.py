#!/usr/bin/env python3
"""Audit completed slab jobs without rerunning or modifying model outputs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
import traceback

import numpy as np
from netCDF4 import Dataset


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def write(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def audit(work, job):
    cfg = json.loads((work/'configuration.json').read_text())
    case = json.loads((job/'configuration.json').read_text())
    result = json.loads((job/'results.json').read_text())
    with Dataset(cfg['input']) as f:
        nc = len(f.dimensions['ace']); nz = len(f.dimensions['mf_level'])
        area = np.asarray(f['ace_area'][:]); area /= area.sum()
    seconds = case['duration_seconds']; dt = case['dt']
    count = round(seconds/(dt if seconds < 60 else 60))+1
    if result['saved_states'] != count or result['duration_seconds'] != seconds:
        raise ValueError('Report duration/count mismatch')
    for name, digest in result['sha256'].items():
        if sha(job/name) != digest:
            raise ValueError('Completed artifact changed: '+name)
    checks = dict(saved_states=count, duration_seconds=seconds, hashes_match=True,
                  field_order=['MF', 'theta_e', 'qt'])
    final = {}
    for lang in ('matlab', 'fortran'):
        n = nc if lang == 'matlab' else nc+1
        width = n*nz*3
        path = job/(lang+'_states.bin')
        first_offset = 0 if lang == 'matlab' else 12
        next_offset = first_offset+(width+(0 if lang == 'matlab' else nz))*8
        expected_bytes = first_offset+(count*width+(0 if lang == 'matlab' else nz))*8
        if path.stat().st_size != expected_bytes:
            raise ValueError('State stream length: '+lang)
        first = np.memmap(path, '<f8', mode='r', offset=first_offset, shape=(width,))
        later = np.memmap(path, '<f8', mode='r', offset=next_offset, shape=(count-1, width))
        max_mean = 0.; minimum_water = np.inf
        for k, flat in enumerate([first, *later]):
            a = flat.reshape((n,nz,3), order='F')[:nc]
            if not np.isfinite(a).all() or np.min(a[:,:,2]) < 0:
                raise ValueError('Invalid state: '+lang)
            if k:
                mean = float(np.max(np.abs(area@a[:,:,0])))
                bound = 64*np.finfo(float).eps*nc*max(1., float(np.max(np.abs(a[:,:,0]))))
                if mean > bound:
                    raise ValueError('Area-mean MF correction failed: '+lang)
                max_mean = max(max_mean, mean)
            minimum_water = min(minimum_water, float(a[:,:,2].min()))
            if k == count-1: final[lang] = a.copy()
        b = np.fromfile(job/(lang+'_budget.bin'), '<f8')
        if b.size != round(seconds/dt)*4*nc:
            raise ValueError('Budget record count: '+lang)
        b = b.reshape((-1,4,nc))
        if not np.isfinite(b).all() or not np.array_equal(b[1:,0], b[:-1,3]):
            raise ValueError('Budget continuity: '+lang)
        changes = np.diff(b, axis=1)
        if case['physics'] == 'none' and np.any(changes[:,1] != 0):
            raise ValueError('Precipitation changed water with physics off: '+lang)
        if np.max(changes[:,1]) > 1e-12:
            raise ValueError('Native precipitation added column water: '+lang)
        closure = np.sum(changes, axis=(0,1))-(b[-1,3]-b[0,0])
        tolerance = 128*np.finfo(float).eps*b.shape[0]*max(1., float(np.max(np.abs(b))))
        if np.max(np.abs(closure)) > tolerance:
            raise ValueError('Inventory bookkeeping closure: '+lang)
        checks[lang] = dict(finite=True, minimum_qt=minimum_water,
                            max_postinitial_area_mean_MF=max_mean,
                            budget_continuous=True,
                            bookkeeping_closure_error_kg_m2=float(np.max(np.abs(closure))),
                            physical_conservation_claim=False)
    if seconds >= 60:
        path = job/'fields.dat'
        if path.stat().st_size != count*nc*nz*9*4:
            raise ValueError('Normal Fortran output record count')
        fields = np.memmap(path, '<f4', mode='r', shape=(count,9,nz,nc))
        state_path = job/'fortran_states.bin'
        width = (nc+1)*nz*3
        for k, record in enumerate(fields):
            if not np.isfinite(record).all():
                raise ValueError('Nonfinite normal output')
            offset = 12 if k == 0 else 12+(k*width+nz)*8
            flat = np.memmap(state_path, '<f8', mode='r', offset=offset, shape=(width,))
            state = flat.reshape((nc+1,nz,3), order='F')[:nc]
            expected = state.transpose(2,1,0).astype('<f4')
            if not np.array_equal(record[:3], expected):
                raise ValueError('Normal output/state mismatch')
        checks['fortran_normal_output'] = dict(records=count, fields=9, finite=True,
                                               prognostics_exact_real32_cast=True)
    checks['final_max_abs_error'] = np.max(np.abs(final['matlab']-final['fortran']), axis=(0,1)).tolist()
    checks['passed'] = True
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path)
    parser.add_argument('--follow', action='store_true', help='Audit each newly completed job until the supervisor finishes')
    args = parser.parse_args(); work = args.work.resolve()
    report = dict(jobs={}, status='running')
    destination = work/'audit_results.json'
    try:
        while True:
            for result in sorted(work.glob('*/results.json')):
                name = result.parent.name
                if name not in report['jobs']:
                    report['jobs'][name] = audit(work, result.parent)
                    print('Audited '+name, flush=True)
            supervisor = json.loads((work/'status.json').read_text())
            report.update(utc=datetime.now(timezone.utc).isoformat(), supervisor=supervisor)
            phase = supervisor['phase']
            terminal = phase in ('failed', 'completed_pending_scientific_review') or phase.startswith('stopped_')
            report['status'] = 'completed' if phase == 'completed_pending_scientific_review' else ('supervisor_stopped' if terminal else 'running')
            write(destination, report)
            if terminal or not args.follow: break
            time.sleep(10)
    except BaseException:
        report.update(status='audit_failed', error=traceback.format_exc())
        write(destination, report)
        raise


if __name__ == '__main__': main()
