"""Sequential actual-state full-step comparison; benchmark copies only."""
from pathlib import Path
import json
import re
import subprocess
import numpy as np

HERE = Path(__file__).resolve().parent
WORK = HERE / 'fullsteps'
jobs = ['original_1', 'precomputed_1', 'precomputed_2', 'original_2']
report = {'simulated_seconds': 6, 'start_state_seconds': 600, 'threads': 32,
          'limits_MF_thetae_qt': [1e-9, 1e-7, 1e-11], 'runs': {}}
for name in jobs:
    job = WORK / name
    (WORK / 'status.json').write_text(json.dumps({'phase': name}))
    with (job / 'matlab.log').open('x') as log:
        subprocess.run(['matlab', '-batch', f"maxNumCompThreads(32);run('{job}/replay.m');"],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    text = (job / 'matlab.log').read_text()
    assert 'SLAB_INTEGRATION_COMPLETED' in text
    elapsed = float(re.search(r'ODE solver time = ([\d.]+) sec', text)[1])
    packing = float(re.search(r'Precompute seconds: ([\d.]+)', text)[1])
    state = np.fromfile(job / 'matlab_states.bin', '<f8').reshape(2, 3, 401, 88)
    assert np.isfinite(state).all() and state[:, 2].min() >= 0
    reference = np.fromfile(WORK / 'original_1/matlab_states.bin', '<f8').reshape(state.shape)
    delta = state - reference
    absolute = np.max(np.abs(delta), axis=(0, 2, 3))
    relative = [float(np.linalg.norm(delta[:, k]) / max(np.linalg.norm(reference[:, k]), np.finfo(float).tiny))
                for k in range(3)]
    assert np.all(absolute <= report['limits_MF_thetae_qt'])
    report['runs'][name] = {'ode_seconds': elapsed, 'packing_seconds': packing,
                            'max_abs_error_MF_thetae_qt': absolute.tolist(),
                            'relative_l2_MF_thetae_qt': relative, 'finite': True,
                            'minimum_qt': float(state[:, 2].min()), 'screen_passed': True}
    (WORK / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(name, elapsed, absolute.tolist(), flush=True)
original = np.median([r['ode_seconds'] for k, r in report['runs'].items() if k.startswith('original')])
candidate = np.median([r['ode_seconds'] for k, r in report['runs'].items() if k.startswith('precomputed')])
report.update(original_median_seconds=float(original), precomputed_median_seconds=float(candidate),
              observed_step_speedup=float(original/candidate), scientific_acceptance='pending long trajectory review')
(WORK / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
(WORK / 'status.json').write_text(json.dumps({'phase': 'completed'}))
