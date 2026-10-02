# Shared ACE case input

The active MATLAB and Fortran candidates now default to one shared case file
at `data/input/manus208.nc`. `data/input/goamazon314.nc` is an additional
converted case. Historical snapshots remain unchanged. This reader migration
does not establish cross-implementation dynamics equivalence or promote the
candidate sources to a release.

## Manus sounding time verified against the paper

The existing `data/input/manus208.nc` is the **0700 local time, 10 August
1998 Manus sounding**. Its `date=729976.875` (MATLAB datenum) and `hh=21`
encode **1998-08-09 21:00 UTC**, which is **1998-08-10 07:00 UTC+10**
in `Pacific/Port_Moresby`. `hh` is the UTC hour, not the Manus local hour;
the converter preserves the source time without a timezone shift.

Verification on 2026-10-02 read the original sounding NetCDF's
`time_bnds=902696400` seconds since 1970-01-01 00:00:00 +00:00
(Gregorian calendar). Raw record 7616 is record 208 after the active
`LOAD_SOUNDINGS` filter requiring all 37 temperature/humidity values and
surface precipitation to be non-NaN. The source SHA-256 matches the
shared-file provenance, and the selected `ta`, `hus`, pressure and
precipitation values match exactly. The repository snapshot currently holds
a Git LFS pointer; the verification used the matching real source file at
`/scratch/peter50504/ACE_MATLAB_old/soundings/manus_3hr_ARMBEsonde_profiles.nc`.
See [machine-readable evidence](manus208_sounding_time_verification.json).

Section 4 and the Fig. 3 caption of the
[paper preprint](https://d197for5662m48.cloudfront.net/documents/publicationstatus/210779/preprint_pdf/c66ffdcb39f91173a1ab140bf38eb2e4.pdf)
specify the same Manus date/local time for the single- and multi-ACE
examples. The archived profile's precipitation is 0.056483585 mm h-1,
consistent with the paper's rounded 0.06 mm h-1. No new case file or
change to the existing NetCDF is needed. This identifies the environmental
sounding; it does not assert that every simulation parameter matches the paper.

## Schema: ACE-case-input-1

NetCDF-4 stores all numeric variables as double, without quantization or
scale/offset packing. The global `ace_input_schema` identifies the schema.
Required global attributes include `case_name`, `arm`, `profile_index`,
`PMB_order_on_disk` and `coordinate_policy`. Converter provenance attributes
record input SHA-256 values and source commit. `profile_index` is the original
one-based index after sounding filtering; the file contains only that profile.

| Variables | Dimension(s) in MATLAB/Fortran NetCDF API order | Units |
| --- | --- | --- |
| theta_e_mf, qt_mf, Tv_mf, p_mf, rho_mf, zm | mf_level=801 | K, kg kg-1, K, Pa, kg m-3, m |
| theta_e_zc, qt_zc, Tv_zc, p_zc, rho_zc, z | zc_level=801 | K, kg kg-1, K, Pa, kg m-3, m |
| PMB | basis_edge=201, coarse_level=200, forcing_ace=8, response_ace=8 | 1 |
| basis_z | basis_edge=201 | m |
| coarse_z | coarse_level=200 | m |
| coarse_ze | basis_edge=201 | m |
| diameter | radial_boundary=7 | m |
| Lx, Ly, dz | scalar | m |
| p, T_p, q_p, rho_p, z_p | pressure_level=181 | Pa, K, kg kg-1, kg m-3, m |
| plev, ta, hus | sounding_level=37 | Pa, K, kg kg-1 |
| T_env | zc_level=801 | K |
| T_zm, theta_zm, theta_es_zm, rh_zm | mf_level=801 | K, K, K, 1 |
| pr, prw, date, hh | scalar | mm h-1, mm, MATLAB datenum days, hour |

`ncdump` and Python see reversed PMB dimensions:
`PMB(response_ace, forcing_ace, coarse_level, basis_edge)`.
The Fortran reader explicitly maps them to the model's
`PMB(response, forcing, coarse, edge)`. Both readers reject a swapped
forcing/response dimension order even though both lengths are eight.

`z` retains the historical 25:50:40025 m grid, including its final extra
level; `zm` is 0:50:40000 m. No grid trimming is performed.
`basis_z` preserves the MATLAB basis coordinates exactly. `coarse_z` and
`coarse_ze` preserve the regular coordinates constructed by legacy Fortran.
Their maximum edge-coordinate discrepancy is 3.637978807091713e-12 m.
Each implementation continues to use its historical coordinate values;
unifying those values would be a separate reviewed numerical change.

## Reproduce conversion

Use MATLAB with the active thermodynamic utilities and real source data,
not Git LFS pointers. Add `tools/input/` to the MATLAB path and call:

```matlab
provenance = struct('source_commit', '<baseline commit>', ...
    'initial_sha256', '<initial binary SHA-256>', ...
    'pmb_sha256', '<PMB SHA-256>', ...
    'basis_sha256', '<basis SHA-256>', ...
    'sounding_sha256', '<sounding SHA-256>');
create_shared_input(binary_dir, basis_file, sounding_file, ...
    output_file, 208, 1, provenance);
% GOAmazon: use the corresponding sounding, profile 314 and arm=3.
```

The converter extracts the active driver's unchanged `LOAD_SOUNDINGS`,
`INTERP_P_GRID` and `INTERP_Z_GRID` functions into a temporary helper. It
computes only the selected profile, demands exact equality with all twelve
legacy initialization records and the complete PMB, and verifies readback.
It refuses to overwrite an existing output. Provenance hashes should be
computed from the actual files used; the runtime manifest records this host's
conversion results. The converter preserves both original inputs.

Generated `.nc` files are ignored by Git. `data/**` already has LFS
attributes, but this change does not stage or upload runtime data. Preserve
the files locally or regenerate them using the documented inputs; distributing
them through LFS requires a separate deliberate staging step and Git LFS.

## MATLAB run

From `matlab/active/`, run `ace`. It reads the shared file by default and uses
its single-profile ancillary data for the existing plume diagnostics. `arm`
and original profile index come from the file; internally `pidx=1` because
there is one profile. `case_profile_index` retains the original index.

```matlab
setenv('ACE_INPUT_FILE', '/absolute/path/to/case.nc'); % optional override
ace
```

For legacy regression, set `ACE_INPUT_MODE=legacy`. `ACE_LEGACY_DATA` may
point to a directory containing `basis/` and `soundings/`; otherwise the
historical `matlab/data/` layout is used. The normal driver still needs its
existing Statistics Toolbox (`normpdf`) and graphical plotting facilities.

`ACE_VALIDATE_INPUT=/absolute/path/to/dump.mat` runs initialization only,
skipping unused plume/radiation diagnostics and all integration/plotting.
In legacy validation, only the selected sounding profile is interpolated.
This mode verifies actual driver initialization without requiring the
Statistics Toolbox. It does not test the normal diagnostics or time integrator.

## Fortran build and run

The historical default compiler and flags remain Intel-specific. The new
`ace_input.F` module uses netCDF-Fortran; make dependencies build it first.
From `fortran/active/`:

```bash
make
mkdir -p data
./ace_model.exe
./ace_model.exe --input ../../data/input/manus208.nc \
  --intervals 2 --output ../../migration_work/shared_input/reports/short.dat
```

`--intervals` controls the number of existing 60-second output intervals;
the default remains 2880 (48 hours). It does not change dt or integration.
`--output` overrides the legacy output filename; use it for non-Manus cases.
`--validate-input dump.bin` writes initialized X, A, B, Tv0 and coarse
coordinates as a double-precision stream and exits before output/integration.
`--legacy-input` reads the existing `input_data/` binaries instead.

Legacy binary record lengths and output record length now use
`INQUIRE(IOLENGTH=...)` on the actual transfer list. This preserves the
Intel four-byte-record-unit layout and permits GNU byte-unit readback;
compiler flags that alter record conventions still require validation.
Output remains the historical nine-variable real*4 direct-access layout.

For this host's GNU Fortran environment the build command is:

```bash
make FC=gfortran \
  FCFLAGS='-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none' \
  FINCLUDE="$(nf-config --fflags)" \
  LDLIBS="$(nf-config --flibs)"
```

Ensure the netCDF shared libraries are on the runtime library search path.
This is a separate compiler environment, not evidence of Intel/GNU scientific
equivalence. Do not mix objects from different compiler/flag configurations.

## Validation tools

- `tests/input/validate_matlab.m`: exact comparison of actual MATLAB driver
  initialization from shared versus legacy inputs, plus malformed PMB rejection.
- `tests/input/read_case.f90`: complete Fortran profile/PMB readback.
- `tests/input/validate_fortran.py`: exact binary/NetCDF readback for both
  cases, actual model initialization and 120-second same-compiler regression,
  finite-value checks, and malformed PMB-order rejection.

Compile the small reader with the same netCDF-Fortran environment and the
model's `ace_input.o`, then supply its path and the model executable to the
Python validation tool. Run `validate_matlab(legacy_data,reports)` with
`tests/input` on the MATLAB path and a fresh report directory. Results on
this host are recorded in `docs/shared_input_validation.json`; full dumps
and logs are under the ignored temporary workspace. Both implementations
reading the same input does not eliminate the known dynamics differences
in the v0.18 alignment audit.

## Cross-implementation runtime evidence

The [single/multi runtime report](v018_runtime_comparison.md) now records
actual dynamics integration in MATLAB and GNU Fortran, including matched
one-step and 120-second dry/precipitating cases. It uses the input-validation
path to initialize, then calls the actual numerical routines without the
normal driver's unused Statistics/plotting diagnostics. Dry agreement does
not extend to the controlled precipitating cases; review the scientific
sink and inversion differences before claiming shared model behavior.
