# Shared ACE case input

## v0.21.87 shared case (accepted 2026-10-15)

Both drivers now default to `data/input/goamazon314_88aces.nc`: the supplied
88-ACE basis, raw GOAmazon filtered profile 314, all three supplied operators.
Use `tools/input/create_s20_shared_input.m` with profile 314, arm 3, dz 100
and actual basis/sounding hashes. It extracts the unchanged raw-sounding
preprocessing functions from the current MATLAB driver. Input generation
is separate from the current inversion-derived runtime reference Tv/bubble.
The converter uses full vertical chunks for each forcing/response pair.
See [release scope](releases/v0.21.87-notes.md) and [tests](../tests/slab/README.md).

From v0.21 onward, basis and shared inputs embedding full operators are
local-only, including their parts: do not commit or upload them. Obtain them
separately. The manifest and `tools/input/materialize_v02187_inputs.py` verify
every local part/full SHA-256 and reconstruct the original runtime paths
without numerical conversion. The developer authorized rebuilding the release
history after v0.20.87 without the new basis/operator payload pointers, while
preserving all earlier historical inputs.
The following dated v0.20 records describe the preserved Manaus baseline.

## Current v0.20 development interface (2026-10-04)

Both drivers now default to `data/input/manaus1342_khn26.nc`, the
November 2025 KHN26 reference selected by the author and developer.
The [integration record](migration/v020_khn26_integration.md) owns current
source changes and numerical scope; [the KHN26 tests](../tests/khn26/README.md)
reproduce initialization/component/short-run checks. The older S20 adapter
record is historical evidence.

### Schema: ACE-case-input-2

Schema 2 extends the twelve v0.18 profile fields and ancillary sounding data
with slab geometry and three operators. All numeric variables use binary64.
Required global attributes are `ace_input_schema='ACE-case-input-2'`,
`geometry='slab'`, `case_name`, `arm` and `profile_index`. Grids and ACE counts
are dynamic. Dimension names and variable units are checked explicitly.

| Variables | MATLAB/Fortran NetCDF API dimensions | Units |
| --- | --- | --- |
| Twelve theta_e/qt/Tv/p/rho/height profiles | `mf_level` or `zc_level`, same length | Same as schema 1 below |
| PMB, PMDv, PMD | `basis_edge, coarse_level, forcing_ace, response_ace` | PMB: `1`; PMDv/PMD: `native` |
| basis_z, coarse_ze | `basis_edge=coarse_level+1` | m |
| coarse_z | `coarse_level` | m |
| ace_width, ace_perimeter | `ace=response_ace=forcing_ace` | m |
| ace_area | `ace` | m2 |
| dz | scalar | m |
| p/T_p/q_p/rho_p/z_p and sounding/postprocessing fields | Same named dimensions as schema 1, with variable grid lengths | Same as schema 1 |

Python/ncdump see all operators in reversed order:
`response_ace, forcing_ace, coarse_level, basis_edge`. Fortran stores
`operator(response,forcing,coarse,edge)`; MATLAB keeps API order.
Readers reject swapped dimension names even when lengths are equal. Schema
2 requires all three full operators; missing momentum operators must be explicitly marked
`source_status=disabled_zero_placeholder`. Both drivers reject their
activation. Older supplied operators without this attribute remain readable. Fortran now includes PMDv/PMD calculation
branches with the same disabled defaults as MATLAB; see the
[dynamics alignment record](migration/v020_dynamics_alignment.md).

`native` records unconverted momentum-operator source values; their physical
units and application need scientific review before those momentum terms
are enabled. It is not a claim that all three operators are dimensionless.
The converter does not rescale their coefficients.

The schema requires positive geometry and
`ace_area/ace_perimeter=ace_width`. The converter preserves the original
S20 convention `Ai=D` km2 and `Bi=1` km by representing a 1 km span:
`ace_width=D*1000`, `ace_area=ace_width*1000`, and `ace_perimeter=1000`.
MATLAB converts area/perimeter back to its original units; Fortran uses SI.
This is a geometry representation, not a new boundary-condition model.

`mf_level-1` must partition evenly into `coarse_level` blocks. Profiles use
`z=zm+dz/2`; `basis_z` and `coarse_ze` retain identical supplied basis
coordinates, matching the fine-grid partition within floating-point
roundoff. `coarse_z=coarse_ze(1:end-1)`. The S20 converter retains 40 km depth
with configurable dz (default 100 m), without resampling basis operators.
Schema 2 does not require the annular schema's diameter, Lx or Ly fields.

### Prepare the S20 shared file after basis provision

Use the final basis containing `D`, `Z`, `PMB`, `PMDv`, `PMD`, the raw sounding
and the current paired S20 thermodynamic utilities:

```matlab
addpath('tools/input');
provenance=struct('source_commit','<S20 source revision>', ...
    'basis_sha256','<actual basis SHA-256>', ...
    'sounding_sha256','<actual sounding SHA-256>');
create_s20_shared_input(basis_file,sounding_file, ...
    'data/input/goamazon314_s20.nc',314,3,provenance,100);
```

The tool extracts the driver's unchanged S20 preprocessing functions,
including humidity adjustment, for a single selected profile. It requires
operators to match the requested grid and writes their exact binary64
coefficients. The output path must be fresh. This entry has been implemented
but not executed or tested; no new case file is distributed. The original
`create_shared_input` is the historical v0.18 converter and should be used
from the `v0.18.0` checkout with that version's helpers.

### Select a shared case

From `matlab/`:

```matlab
setenv('ACE_INPUT_FILE','/absolute/path/to/case.nc');
ace
```

From `fortran/`:

```bash
./ace_model.exe --input /absolute/path/to/case.nc \
  --physics native --intervals 2 --output /existing/output/directory/state.dat
```

Fortran make dependencies include `ace_input.F`. P3 tables remain external
text data. Legacy input is explicit: MATLAB `ACE_INPUT_MODE=legacy` /
`ACE_LEGACY_DATA`, Fortran `--legacy-input`. Reader APIs still support schema
1 files; the current MATLAB KHN26 driver rejects annular geometry rather than reinterpreting it.
Reading the same case does not match initial perturbations, timesteps,
physics or boundaries; those remain documented model differences.

## Published v0.18 interface and evidence

The following records the tested v0.18 implementation and schema 1. Its
commands, compiler validation and conversion evidence apply to a
`v0.18.0` checkout, not the current KHN26/P3 sources.

The published MATLAB and Fortran implementations default to one shared case file
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

From `matlab/`, run `ace`. It reads the shared file by default and uses
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
From `fortran/`:

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

The [single/multi runtime report](maintenance/history_summary.md#record-v018-runtime-comparison) now records
actual dynamics integration in MATLAB and GNU Fortran, including matched
one-step and 120-second dry/precipitating cases. It uses the input-validation
path to initialize, then calls the actual numerical routines without the
normal driver's unused Statistics/plotting diagnostics. Dry agreement does
not extend to the controlled precipitating cases; review the scientific
sink and inversion differences before claiming shared model behavior.

## KHN26 processed reference case (2026-10-04)

The author-selected November 2025 KHN26 case uses the actual 101-ACE
`COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN.mat` and
`acelevels_manaus.nc`, one-based profile 1342. The converter
[`tools/input/create_khn26_shared_input.py`](../tools/input/create_khn26_shared_input.py)
produces `data/input/manaus1342_khn26.nc` with schema 2 and direct profile/PMB
copying. Missing momentum operators are full-shape compressed zero
placeholders with `source_status=disabled_zero_placeholder`; this is not
a scientific momentum basis, and momentum activation remains unsupported
for this case. The original supplied Tv is preserved separately from the
KHN26 driver's inversion-derived reference decision.

The [KHN26 review](migration/v020_khn26_review.md) preserves input/source
provenance and readback evidence. The [integration record](migration/v020_khn26_integration.md)
records current driver/Fortran changes.
The older raw-sounding S20 converter and default GoAmazon314 input are
not the selected KHN26 case. No raw-sounding intermediates are fabricated
to satisfy the older S20 driver; both active drivers now use this processed-input contract.

Reproduce the KHN26 conversion with original data and a fresh output path:

```bash
python3 tools/input/create_khn26_shared_input.py \
  /path/COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN.mat \
  /path/acelevels_manaus.nc data/input/manaus1342_khn26.nc --profile 1342
```

The generated NC is ignored, not committed or uploaded. The tracked
`data/input/manaus1342_khn26.provenance.json` pins its source and output hashes.
The legacy raw-sounding S20 recipe above is historical and is not the KHN26
conversion path.
