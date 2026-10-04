# v0.20 shared NetCDF adapter

Implemented 2026-10-04 on `migration/v020-preparation`, following the
developer's instruction to use v0.18 inputs as the base, extend to three
basis operators and unify MATLAB/Fortran input. Basis inspection and model testing
remain deferred; input-only verification is recorded below. This follows the source-only import at `d9e8401`; its
manifest records imported bytes, not the later adapter source hashes.

## Changes

- Both readers retain schema 1 compatibility and accept
  `ACE-case-input-2` with dynamic grid/ACE dimensions and slab geometry.
  Profile names and binary64 I/O follow the v0.18 convention.
- Schema 2 requires PMB, PMDv and PMD in explicitly named axis order, plus
  width, area, perimeter and coordinates. MATLAB uses
  `(edge,coarse,forcing,response)`; Fortran maps to
  `(response,forcing,coarse,edge)` without assuming eight ACEs.
- MATLAB defaults to shared input through `ACE_INPUT_FILE` and imports
  prepared profiles directly. Its S20 legacy path remains selectable.
  The slab driver rejects schema 1 annular geometry explicitly.
- Fortran defaults to shared input, restores `--input`, `--output`,
  `--intervals`, `--legacy-input` and initialization-dump selection. The
  makefile builds `ace_input.F`; arrays and geometry follow file metadata.
  Legacy record lengths use `INQUIRE(IOLENGTH=...)` as in v0.18.
- Fortran initialization stores all three schema 2 operators. Fine-to-coarse
  grouping uses file dimensions instead of fixed factor four. At the old
  factor-four dimensions, it uses the same first `nz-1` values and the same
  block-average expression.
- `--p3-lookup-directory` selects the table path. Versions, categories and
  P3 physics remain unchanged.
- `create_s20_shared_input.m` prepares one S20 profile and three operators
  from the supplied MAT/sounding files. No basis file was opened or
  conversion run as part of implementation.

## Scientific scope and retained differences

The schema shares environmental profiles and operators. Initial perturbations,
physics splitting, dt and boundary treatments are not made equivalent by
this adapter. Historical Fortran P3 initialization still derives theta/qv
through its existing theta_e inversion, while MATLAB uses S20 preprocessing
and bubble settings.

Fortran applies PMB only; the other operators are stored. Native coefficient
units require review before activation. Known P3 dry/warm invalid operations
and reference-state interpretation in ace_tendency remain pending. One diagnostic change accompanies driver
consolidation: the shared output routine refreshes vapor for normal and final
output, avoiding stale-vapor final RH/buoyancy. It does not alter prognostics.
The nine-field real32 output remains; the initialization dump now carries
dynamic dimensions and eleven P3 variables, requiring validation-tool adapters.

## Data and validation state

Both drivers default to `../data/input/goamazon314_s20.nc` from their source
directories. It has not been generated. The developer is to supply the final
`COMPOSITE_ACE_BASIS_2D_V020.mat` with D, Z, PMB, PMDv and PMD; the annular
v0.18 basis must not be substituted.

Implementation review covers code paths, field/axis mapping and documentation.
The initial adapter implementation did not run compilation or tests. The
subsequent developer-requested code confirmation ran the input-only checks
below. Conversion, model integration and basis-candidate inspection remain
deferred. Published main/v0.18.0 is unchanged; this is not a validated v0.20
release.

The [schema and commands](../shared_input.md) describe the contract. After
basis provision and authorization, verify readback and initialization before
model trajectories or P3 tests.


## Input-only code confirmation (2026-10-04)

The readers extend the published `v0.18.0` implementations. The numerical
model sources instead descend from the imported MATLAB S20 and Fortran P3
snapshots identified in the integration manifest; reader compatibility does
not establish preservation of v0.18 numerical behavior.

Two small interface changes were made during confirmation:

- MATLAB handles empty `ncinfo(...).Dimensions` explicitly for scalar
  variables. The previous adapter failed on the valid v0.18 scalar lengths.
- Fortran now checks the schema 1 pressure/sounding dimensions (181/37),
  matching MATLAB's existing v0.18 schema checks.

No annular geometry correction was needed: `atan(1.d0)` is pi/4, so its area
expression and the v0.18 expression agree.

| Check | Result |
| --- | --- |
| Fortran v0.18 reader versus current reader, accepted `manus208.nc` | Exact binary equality of twelve profiles and every PMB element (20,659,296 bytes) |
| MATLAB v0.18 reader versus current reader, same accepted file | All 40 original struct fields exactly equal |
| Synthetic schema 2: 13 levels, three ACEs, coarse ratios four and two | Profile, coordinates, slab area/perimeter and all three operators exactly equal between MATLAB and Fortran (493 and 1,309 doubles) |
| Independent Python expected values, uniquely indexed basis axes | Exact equality with Fortran output; MATLAB comparison includes the explicit axis permutation |
| Swapped forcing/response dimension names, equal axis lengths | Rejected by both readers |
| Complete Fortran build, GNU real32 and real64 | Compile and link successful in separate directories, no model integration |

MATLAB R2023b was used. GNU builds used `-cpp -ffree-form
-ffree-line-length-none -O0`, adding `-fdefault-real-8
-fdefault-double-8` for real64, and the local `nf-config` NetCDF paths.
The Fortran reader probe additionally used `-fcheck=all`.
The temporary synthetic inputs are reader fixtures, not scientific bases.
Local scripts, fixtures and binary readbacks are retained in ignored
`migration_work/input_adapter_review_20261004/`.

### Code differences identified at input-only confirmation

The following differences require later scientific alignment.

1. Fortran stores PMDv/PMD but does not include their contributions in
   `ace_tendency`; MATLAB `NONLOCAL_RESPONSE` contains those terms, subject
   to its existing switches. Native momentum basis units still need review.
2. Fortran stores theta/qv in its P3 state but the reference path in
   `ace_tendency` passes them to `inv_theta_e` as theta_e/qt. Its driver's
   diagnostic Tv0 is reconstructed, whereas MATLAB uses the file's Tv_zc.
   The accepted v0.18 reference-state fix has not been ported to this P3
   state layout. This requires a scientific correction and review.
3. S20 and historical P3 initial perturbations, dt, reference-buoyancy
   adjustment and physics are different. The imported code is not a matched
   MATLAB/Fortran dynamics case. Known dry/warm P3 invalid operations also
   remain unresolved.

These results establish compatibility of the reader paths exercised above.
They do not verify the converter, full MATLAB driver initialization, actual
S20 basis, time integration, P3 operation, or cross-language scientific
agreement. MATLAB reads ancillary sounding metadata that Fortran does not
consume, so their validation coverage beyond shared consumed fields also
remains different. Complete code alignment is still pending before model
usability can be asserted.
