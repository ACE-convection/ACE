#!/usr/bin/env python3
"""Use the existing MF panel layout with frozen MATLAB and real32 Fortran data."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path, help='Completed precipitation precision test directory')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve()
    output = work/'matlab_comparison'
    if output.exists() and any(output.iterdir()):
        parser.error('Comparison output exists; preserve it and use a fresh work directory')
    reference = root/'tests/reference/manus_saturated_bubble_precip'
    case = json.loads((root/'tests/cases/manus_saturated_bubble_precip.json').read_text())
    run = json.loads((work/'results.json').read_text())
    assert run['duration_seconds'] == case['integration']['duration_seconds'] == 10800
    assert run['input_sha256'] == case['input']['sha256']
    assert run['seed_sha256'] == case['reference']['files_sha256']['initial_state.bin']
    assert digest(reference/'mf.npz') == case['reference']['files_sha256']['mf.npz']
    with np.load(reference/'mf.npz') as data:
        times = data['time_seconds']; heights = data['height_m']; matlab = data['matlab']
    state_file = work/'corrected32/state.bin'
    # Fortran stream order: ACE varies fastest, then level, then variable.
    state = np.fromfile(state_file, dtype='<f4').reshape((len(times), 3, len(heights), 8))
    fortran = state[:, 2, :, 0]
    assert np.isfinite(fortran).all() and matlab.shape == fortran.shape
    output.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(output/'mf.npz', time_seconds=times, height_m=heights,
                        matlab=matlab, fortran=fortran)
    source_hash = run['source_sha256']
    if isinstance(source_hash, dict):
        source_hash = source_hash['fortran/src/ace_module.F']
    report = {
        'case': 'manus', 'profile_index': 208, 'duration_seconds': 10800,
        'precipitation': 'enabled', 'bubble': {'enabled': True},
        'fortran_label': 'Fortran (single precision)',
        'scope': 'Frozen MATLAB reference versus corrected default-real32 Fortran; ACE 1 MF. '
                 'Fortran PMB/input reads retain binary64. Original time/height coordinates and panel layout.',
        'sources': {'matlab_reference': str(reference/'mf.npz'),
                    'matlab_reference_sha256': digest(reference/'mf.npz'),
                    'fortran_state': str(state_file), 'fortran_state_sha256': digest(state_file),
                    'fortran_source_sha256': source_hash},
    }
    (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')
    subprocess.run([sys.executable, root/'tests/alignment/plot_mf.py', output], check=True)
    report['artifacts_sha256'] = {p.name: digest(p) for p in
                                 [output/'mf.npz', output/'mf_three_panels.png', output/'mf_three_panels.pdf']}
    (output/'results.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
