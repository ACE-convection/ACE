#!/usr/bin/env python3
"""Copy the author-selected KHN26 processed case into the existing schema 2.

Requires NumPy/netCDF4. netCDF4 reads MATLAB v7.3's HDF5 datasets in their
on-disk (response, forcing, coarse, edge) order. No model preprocessing runs.
Missing momentum operators are explicitly marked disabled zero placeholders.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from netCDF4 import Dataset


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def vector(dataset, name):
    value = np.asarray(dataset[name][:], dtype=np.float64).reshape(-1)
    if not np.all(np.isfinite(value)):
        raise ValueError(f"Nonfinite {name}")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("basis", type=Path)
    parser.add_argument("sounding", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--profile", type=int, default=1342,
                        help="One-based index, as in the KHN26 MATLAB driver")
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    report_path = args.output.with_suffix(".provenance.json")
    if report_path.exists():
        raise FileExistsError(report_path)
    basis_hash, sounding_hash = sha256(args.basis), sha256(args.sounding)
    with Dataset(args.basis) as basis, Dataset(args.sounding) as sounding:
        widths = vector(basis, "D") * 1000
        edges = vector(basis, "Z")
        z, zm = vector(sounding, "zc"), vector(sounding, "ze")
        nc, nz, nb = len(widths), len(zm), len(edges) - 1
        dz = zm[1] - zm[0]
        if nc < 2 or nz < 12 or nb < 1 or (nz - 1) % nb:
            raise ValueError("Invalid basis/grid dimensions")
        if not np.all(widths > 0) or not np.all(np.diff(edges) > 0):
            raise ValueError("Invalid basis geometry")
        if not np.allclose(np.diff(zm), dz, rtol=0, atol=1e-9):
            raise ValueError("Nonuniform MF grid")
        if not np.allclose(z, zm + dz / 2, rtol=0, atol=1e-9):
            raise ValueError("Cell-center grid mismatch")
        if not np.allclose(edges, zm[::(nz - 1) // nb], rtol=0, atol=1e-9):
            raise ValueError("Basis/fine grid mismatch")
        if basis["PMB"].shape != (nc, nc, nb, nb + 1):
            raise ValueError("Unexpected MATLAB v7.3 PMB disk order")
        index = args.profile - 1
        if not 0 <= index < len(sounding.dimensions["time"]):
            raise ValueError("Profile outside processed sounding collection")
        mapping = {
            "theta_e_mf": ("theta_e_ze", "K"), "qt_mf": ("Q_ze", "kg kg-1"),
            "Tv_mf": ("Tv_ze", "K"), "p_mf": ("P_ze", "Pa"),
            "rho_mf": ("rho_ze", "kg m-3"),
            "theta_e_zc": ("theta_e_zc", "K"), "qt_zc": ("Q_zc", "kg kg-1"),
            "Tv_zc": ("Tv_zc", "K"), "p_zc": ("P_zc", "Pa"),
            "rho_zc": ("rho_zc", "kg m-3"),
            "T_env": ("T_zc", "K"), "T_zm": ("T_ze", "K"),
        }
        profiles = {}
        for name, (source, _) in mapping.items():
            if sounding[source].dimensions != ("time", "zc" if source.endswith("zc") else "ze"):
                raise ValueError(f"Unexpected processed profile axes: {source}")
            value = np.ma.asarray(sounding[source][index, :])
            if np.any(np.ma.getmaskarray(value)) or not np.all(np.isfinite(value)):
                raise ValueError(f"Missing/nonfinite selected profile: {source}")
            profiles[name] = np.asarray(value, dtype=np.float64)
        for name in ("p_mf", "p_zc", "rho_mf", "rho_zc", "Tv_mf", "Tv_zc"):
            if np.any(profiles[name] <= 0):
                raise ValueError(f"Nonpositive {name}")
        for name in ("qt_mf", "qt_zc"):
            if np.any(profiles[name] < 0):
                raise ValueError(f"Negative {name}")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with Dataset(args.output, "w", format="NETCDF4") as output:
            for name, size in {"mf_level": nz, "zc_level": nz, "basis_edge": nb + 1,
                               "coarse_level": nb, "forcing_ace": nc, "response_ace": nc,
                               "ace": nc, "pressure_level": 181}.items():
                output.createDimension(name, size)

            def write(name, values, dimensions, unit, **attributes):
                value = np.asarray(values, dtype=np.float64)
                if not np.all(np.isfinite(value)):
                    raise ValueError(f"Nonfinite output {name}")
                variable = output.createVariable(name, "f8", dimensions)
                variable[:] = value
                variable.units = unit
                variable.setncatts(attributes)

            for name, (source, unit) in mapping.items():
                dim = "mf_level" if source.endswith("ze") else "zc_level"
                write(name, profiles[name], (dim,), unit, source_variable=source)
            for name, value, dim in (("zm", zm, "mf_level"), ("z", z, "zc_level"),
                                     ("basis_z", edges, "basis_edge"),
                                     ("coarse_ze", edges, "basis_edge"),
                                     ("coarse_z", edges[:-1], "coarse_level")):
                write(name, value, (dim,), "m")
            write("ace_width", widths, ("ace",), "m")
            write("ace_area", widths * 1000, ("ace",), "m2")
            write("ace_perimeter", np.full(nc, 1000.), ("ace",), "m")
            write("dz", dz, (), "m")
            # p is the nominal, unused pressure grid declared by the original driver.
            write("p", np.arange(1000., 99., -5.) * 100, ("pressure_level",), "Pa",
                  role="Nominal KHN26 driver grid; not used to preprocess profiles")
            # Existing MATLAB schema-2 reader requires plev units even for processed input.
            write("plev", profiles["p_zc"], ("zc_level",), "Pa",
                  role="Compatibility alias of processed P_zc; not raw sounding levels")
            for name in ("time", "pr", "prw", "yyyy", "mm", "dd"):
                write("source_" + name, sounding[name][index], (),
                      getattr(sounding[name], "Units", "1"))
            axes = ("response_ace", "forcing_ace", "coarse_level", "basis_edge")
            for name in ("PMB", "PMDv", "PMD"):
                variable = output.createVariable(name, "f8", axes, zlib=True,
                                                 complevel=1, chunksizes=(1, 1, nb, nb + 1))
                variable.units = "1" if name == "PMB" else "native"
                supplied = name in basis.variables
                variable.source_status = "supplied" if supplied else "disabled_zero_placeholder"
                if supplied and basis[name].shape != (nc, nc, nb, nb + 1):
                    raise ValueError(f"Unexpected operator shape: {name}")
                # MATLAB chunks can span every response ACE. Reading the whole
                # operator once avoids repeated decompression for each response.
                full_operator = np.asarray(basis[name][:], dtype=np.float64) if supplied else None
                for response in range(nc):
                    block = full_operator[response] if supplied else np.zeros((nc, nb, nb + 1))
                    if not np.all(np.isfinite(block)):
                        raise ValueError(f"Nonfinite {name} response {response}")
                    variable[response] = block
                print(f"Copied {name}: {variable.source_status}", flush=True)
                del full_operator
            output.setncatts({
                "ace_input_schema": "ACE-case-input-2", "geometry": "slab",
                "case_name": "manaus_khn26", "arm": np.int32(1),
                "profile_index": np.int32(args.profile), "reference_version": "KHN26 2025-11",
                "basis_sha256": basis_hash, "sounding_sha256": sounding_hash,
                "basis_source": str(args.basis.resolve()), "sounding_source": str(args.sounding.resolve()),
                "profile_policy": "Direct processed profile copy; no filtering/interpolation/humidity adjustment",
                "reference_tv_policy": "Supplied Tv preserved; KHN26 inversion-derived reference remains driver work",
                "momentum_basis_units_policy": "Absent momentum operators are disabled zero placeholders; never enable them",
                "basis_order_on_disk": ",".join(axes), "PMB_order_on_disk": ",".join(axes),
                "coordinate_policy": "Preserve original processed coordinates and supplied MAT Z",
                "selected_duration_seconds": np.float64(21600), "selected_dt_seconds": np.float64(6),
            })
    report = {"output": str(args.output), "output_sha256": sha256(args.output),
              "basis_sha256": basis_hash, "sounding_sha256": sounding_hash,
              "converter_sha256": sha256(__file__), "profile_index": args.profile,
              "dimensions": {"nz": nz, "ncols": nc, "ncoarse": nb},
              "model_validation": "not performed"}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
