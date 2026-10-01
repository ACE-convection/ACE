#!/usr/bin/env python3
"""Test a temporary Ci reference-temperature change on ten saved common inputs."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work', type=Path, help='Completed alignment runner directory')
    parser.add_argument('diagnostic', type=Path, help='Fresh diagnostic output directory')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    work = args.work.resolve()
    diagnostic = args.diagnostic.resolve()
    manifest = json.loads((work / 'configuration.json').read_text())
    for name, digest in manifest['sources_sha256'].items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest
    original = (work / 'ace_module.F').read_text()
    start = original.index('function Ci(T)')
    end = original.index('end function', start)
    block = original[start:end]
    old = 'real, parameter :: T0=273.1636783445389'
    assert block.count(old) == 1
    replacement = block.replace(old, '!' + old + '\nreal, parameter :: T0=273.15')
    modified = original[:start] + replacement + original[end:]
    diagnostic.mkdir(parents=True, exist_ok=False)
    (diagnostic / 'ace_module.F').write_text(modified)
    (diagnostic / 'ci_reference.diff').write_text(''.join(difflib.unified_diff(
        original.splitlines(True), modified.splitlines(True),
        fromfile='alignment/ace_module.F', tofile='diagnostic/ace_module.F')))
    flags = ['-O2', '-ffree-form', '-fdefault-real-8', '-fdefault-double-8',
             '-ffree-line-length-none']
    includes = subprocess.check_output(['nf-config', '--fflags'], text=True).split()
    libs = subprocess.check_output(['nf-config', '--flibs'], text=True).split()
    prefix = subprocess.check_output(['nf-config', '--prefix'], text=True).strip()
    commands = [
        ['gfortran', *flags, *includes, '-I' + str(work), '-c', 'ace_module.F'],
        ['gfortran', *flags, *includes, '-I' + str(diagnostic),
         str(root / 'tests/alignment/fortran_thermo.f90'), 'ace_module.o',
         str(work / 'ace_input.o'), *libs, '-Wl,-rpath,' + prefix + '/lib',
         '-o', 'probe.exe'],
        [str(diagnostic / 'probe.exe'), str(work / 'thermo_input.bin'),
         str(diagnostic / 'thermo_fortran.bin')],
    ]
    for command in commands:
        subprocess.run(command, cwd=diagnostic, check=True)
    arrays = [np.fromfile(p, dtype='<f8').reshape((10, 7), order='F') for p in [
        work / 'thermo_matlab.bin', work / 'thermo_fortran.bin',
        diagnostic / 'thermo_fortran.bin']]
    matlab, fortran, candidate = arrays
    assert all(np.isfinite(a).all() for a in arrays)
    assert np.array_equal(fortran[:, :4], candidate[:, :4]), 'Inverse changed'
    assert np.array_equal(fortran[:, 6], candidate[:, 6]), 'dqt changed'
    labels = json.loads((work / 'thermo_labels.json').read_text())
    names = ['T', 'qv', 'ql', 'qi', 'theta_e_formula', 'precip_dtheta_e', 'precip_dqt']
    report = {
        'scope': 'Diagnostic temporary Ci reference change only; not applied to active sources',
        'original_Ci_reference_K': 273.1636783445389,
        'diagnostic_Ci_reference_K': 273.15,
        'commands': commands,
        'inverse_unchanged': True,
        'dqt_unchanged': True,
        'all_finite': True,
        'cases': {
            label: {
                'original_absolute_diff': dict(zip(names, map(float, abs(matlab[i] - fortran[i])))),
                'diagnostic_absolute_diff': dict(zip(names, map(float, abs(matlab[i] - candidate[i])))),
            } for i, label in enumerate(labels)
        },
    }
    (diagnostic / 'comparison.json').write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print(json.dumps(report['cases']['saturated_ice'], indent=2))


if __name__ == '__main__':
    main()
