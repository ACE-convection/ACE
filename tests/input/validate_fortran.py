#!/usr/bin/env python3
"""Full binary/NetCDF reader and same-compiler model regression checks.

Requires numpy, netCDF4, a compiled model and compiled read_case.f90 reader.
Does not establish MATLAB/Fortran dynamics equivalence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import netCDF4
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--reader', type=Path, required=True)
    parser.add_argument('--input-dir', type=Path, required=True)
    parser.add_argument('--binary-dir', type=Path, required=True)
    parser.add_argument('--reports', type=Path, required=True)
    args = parser.parse_args()
    for key in vars(args):
        setattr(args, key, getattr(args, key).resolve())
    args.reports.mkdir(parents=True, exist_ok=True)
    results = {}

    def run(command, cwd, log):
        proc = subprocess.run([str(x) for x in command], cwd=cwd,
                              capture_output=True, text=True, timeout=120)
        (args.reports / log).write_text(proc.stdout + proc.stderr)
        if proc.returncode:
            raise RuntimeError(f'{command[0]} failed: see {log}')

    with tempfile.TemporaryDirectory(prefix='ace-input-', dir=args.reports) as tmp:
        work = Path(tmp)
        (work / 'input_data').symlink_to(args.binary_dir, target_is_directory=True)
        for case in ('manus208', 'goamazon314'):
            file = args.input_dir / (case + '.nc')
            output = args.reports / (case + '_fortran_readback.bin')
            run([args.reader, file, output], work, case + '_readback.log')
            initial = 'ini_manus_208.dat' if case == 'manus208' else 'ini_goamazon_314.dat'
            expected = (args.binary_dir / initial).read_bytes() + (args.binary_dir / 'PMB.dat').read_bytes()
            assert output.read_bytes() == expected, f'{case} full readback differs'
            results[case + '_full_readback_exact'] = True
            results[case + '_sha256'] = hashlib.sha256(file.read_bytes()).hexdigest()

        for mode, flags in [('shared', ['--input', args.input_dir / 'manus208.nc']),
                            ('legacy', ['--legacy-input'])]:
            dump = args.reports / ('fortran_' + mode + '_init.bin')
            run([args.model, *flags, '--validate-input', dump], work, mode + '_init.log')
            output = args.reports / ('fortran_' + mode + '_120s.dat')
            run([args.model, *flags, '--intervals', '2', '--output', output], work, mode + '_120s.log')
        for stem, dtype in [('init.bin', '<f8'), ('120s.dat', '<f4')]:
            a = args.reports / ('fortran_shared_' + stem)
            b = args.reports / ('fortran_legacy_' + stem)
            assert a.read_bytes() == b.read_bytes(), f'Model {stem} differs'
            values = np.fromfile(a, dtype=dtype)
            assert np.isfinite(values).all(), f'Nonfinite model {stem}'
            results[stem] = {'byte_identical': True, 'finite': True, 'bytes': a.stat().st_size}

        # Deliberately reject a schema with reversed PMB dimension names,
        # retaining identical dimension lengths to catch order validation.
        bad = work / 'bad_order.nc'
        with netCDF4.Dataset(args.input_dir / 'manus208.nc') as src, netCDF4.Dataset(bad, 'w') as dst:
            dst.setncatts({n: src.getncattr(n) for n in src.ncattrs()})
            for name, dim in src.dimensions.items():
                dst.createDimension(name, len(dim))
            for name, var in src.variables.items():
                dims = var.dimensions
                if name == 'PMB':
                    dims = ('forcing_ace', 'response_ace', 'coarse_level', 'basis_edge')
                new = dst.createVariable(name, var.datatype, dims)
                new.setncatts({n: var.getncattr(n) for n in var.ncattrs() if n != '_FillValue'})
                new[:] = var[:]
        rejected = subprocess.run([str(args.reader), str(bad), str(work / 'bad.bin')],
                                  cwd=work, capture_output=True, text=True, timeout=20)
        assert rejected.returncode != 0 and 'PMB dimension order mismatch' in rejected.stderr + rejected.stdout
        results['wrong_PMB_order_rejected'] = True

    (args.reports / 'shared_input_fortran_validation.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
