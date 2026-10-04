# v0.20 reference buoyancy and momentum response alignment

Implemented 2026-10-04 on `migration/v020-preparation` after developer
approval to proceed with the reference-buoyancy/momentum alignment direction.
The input adapter is recorded separately. This is a scientific
change, not evidence of model agreement or a validated release.

## Reference state

The driver takes fixed environmental density temperature from the shared
twelve-field profile contract's `Tv_zc` column (column 9 in `input_profile`).
`ace_initialization` again accepts `environment_tv` before `netcdf_input`,
following the v0.18 interface, and stores it as module `reference_tv`.
The reference is checked for finite positive values before allocation.
Both shared and legacy drivers supply the input reference.

`ace_tendency` uses

```text
rho0B(i,z) = g * rho_zc(z) * (Tv(i,z) - reference_tv(z)) / reference_tv(z)
```

It no longer passes the environmental P3 theta/qv state to `inv_theta_e`.
As clarified by the developer, P3 prognostics are not theta_e/qt. Their
actual array order is `MF, th, qv, qc, nc, qr, nr, qi, ni, qrim, brim`.
Here th is potential temperature, qc/qr/qi are water mass variables, nc/nr/ni
are number variables, and qrim/brim carry riming information. The input
schema may contain theta_e/qt; the driver converts them once before
integration. The P3 wrapper reads and returns the native P3 fields.

Actual ACE thermodynamics keep their existing state-aware branches:
`n_prog=3` uses theta_e/qt inversion; `n_prog=11` uses theta times Exner,
vapor, cloud/rain and ice to obtain Tv. Thermodynamics are cached on the
first SSPRK stage as before. P3 source is unchanged.

For schema 2 slab geometry, `zero_ref_buoyancy` defaults true, matching
MATLAB S20's `timeint`: each level subtracts `sum(rho0B * A/sum(A))`.
Schema 1/legacy annular geometry defaults false. The diagnostic output remains
raw buoyancy against the fixed reference; mean removal acts on dynamics only.

This changes tendencies and diagnostics relative to the imported historical
P3 code. It restores the v0.18 reference-temperature convention, without
claiming that P3 prognostics equal MATLAB's theta_e/qt prognostics.

## Momentum operators

The existing PMB contribution keeps its original summation path. Two
optional `ace_initialization` keyword arguments, `turn_off_DHv_input` and
`turn_off_DHh_input`, default true, matching MATLAB. Setting either false
requires schema 2 slab operators. The production driver leaves defaults in
place; no command-line option activates them. Basis coefficients remain in
native source units, which require review before activation.

| Quantity | Fortran implementation corresponding to MATLAB |
| --- | --- |
| FH | Horizontal turbulent entrainment plus upwind lateral momentum exchange; vertical flux convergence excluded |
| dz2FH | Centered second difference; lower ghost `-FH(1)`, upper ghost zero |
| DHh | `(ioflow(i)^2 - ioflow(i-1)^2)/(rho_zc*A(i))`, inner boundary ioflow zero |
| Coarse DHv forcing | Negative block mean of dz2FH, matching `(turn_off_DHv-1)*dz2FH` |
| Coarse DHh forcing | Positive block mean of DHh |
| Operator contraction | Sum over forcing ACE and coarse layer, producing response ACE and edge |

Schema 2 copies the outermost ACE's reconstructed momentum into the outer
momentum boundary slot, matching MATLAB S20's self boundary. This affects
PMB's horizontal forcing as well as the new FH branch even when DHv/DHh
remain disabled. Annular input retains its zero-MF environmental boundary.
This boundary adaptation is a scientific change explicitly included here.

`zero_ref_buoyancy_input` is an optional initialization override. The full
signature is:

```fortran
call ace_initialization(ncols,nz,ncoarse,coarse_z,coarse_ze,file,environment_tv, &
    netcdf_input=.true., turn_off_DHv_input=.true., turn_off_DHh_input=.true.)
```

There is no change to NetCDF schemas or stored basis values in this step.

## Slab mass-flux, tracer boundary and interpolation alignment

The developer subsequently requested the remaining three items be aligned.
These changes apply to schema 2 slab geometry:

- `Wbar_eq_zero` defaults true. At the end of the nine SSPRK stages, before
  P3 and damping, each level subtracts the area-weighted mean physical-ACE
  MF from every physical ACE. The environmental slot is excluded. This
  corresponds to MATLAB `util_timeint/ssprk93.m`; shared rho at each level
  makes it equivalent to removing area-mean vertical velocity. It is
  distinct from the reference-buoyancy removal above. The optional
  `Wbar_eq_zero_input` initialization argument overrides the default.
- Outer tracer exchange chooses `min(i+1,ncols)` for slab geometry. Thus
  the last ACE uses itself for turbulent entrainment and upwind outer
  inflow, matching MATLAB `expFun`. This applies to every P3 tracer,
  including number and riming fields. Internal ACE exchange is unchanged.
- When `coarse_ratio==1`, the basis edge response is assigned directly to
  MF levels, matching MATLAB's direct `NONLOCAL_RESPONSE` branch. For
  larger ratios, the independent `ace_interpolation` module's real-valued `makima` routine uses
  modified Akima secant weights, quadratic boundary secant extension and
  cubic Hermite evaluation. Two basis edges use linear slopes, and a
  zero weight denominator uses zero derivative. Endpoint intervals also
  provide cubic extrapolation as in MATLAB's default `interp1(...,'makima')`.

The algorithm and extrapolation policy were checked against the installed
MATLAB R2023b `toolbox/matlab/polyfun/makima.m` and `interp1.m`. This is an
independent Fortran implementation of the formula. At the initial port,
no numerical comparison was run. The subsequent developer-authorized
standalone comparison below establishes agreement within recorded
tolerances; evaluation order and precision produce rounding differences.

Schema 1/legacy annular paths keep the prior environmental tracer boundary,
PCHIP interpolation and disabled mass-flux mean adjustment by default.
The fixed-Tv reference correction from the preceding step still applies.
No time step, initial perturbation, P3 prognostic field or NetCDF schema was
changed in this step. Source before this step is retained in
`/tmp/ace-v020-slab-alignment/before_ace_module.F`.

### Standalone Fortran makima interface

`fortran/src/ace_interpolation.F` provides the vector/query subset required
by ACE, without MATLAB or other runtime dependencies:

```fortran
use ace_interpolation, only: makima
! x(n), y(n), xq(nq), yq(nq): real arrays in the build's default real kind.
call makima(n,x,y,nq,xq,yq)
```

`ace_module` calls this same routine. The makefile builds its module before
ACE and links its object. It supports increasing finite real sample grids,
nonuniform spacing, constant/linear data, two sample points and endpoint
extrapolation through the formula described above. MATLAB's ND-array,
complex-value, automatic input reordering and piecewise-polynomial-object
interfaces are outside this ACE vector interface. Numerical agreement within
tested tolerances is recorded below; bitwise identity is not claimed.

## Checks and remaining differences

GNU real32 and real64 compile/link completed in separate build directories.
Flags: `-cpp -ffree-form -ffree-line-length-none -O0`, adding
`-fdefault-real-8 -fdefault-double-8` for real64, with local NetCDF includes
and libraries. Static review checked signs, boundary values, coarse grouping,
operator axes, production call sites, modified Akima weights and the three
slab branches. Both precisions were compiled again after the slab changes.
The initial alignment stage did not add or run new tests. The subsequent
standalone makima check below was authorized and run. No full model
executable, P3 probe, converter or actual basis was run or inspected.
Scientific behavior remains unvalidated.

Remaining alignment work includes:

- Mean-MF adjustment, tracer boundaries and their interaction with the model
  still require numerical checks. Standalone makima checks pass; this does
  not establish agreement of the full dynamics.
- Initial perturbations and dt differ; precipitation/P3 splitting and
  scientific parameterizations also differ.
- Historical P3 initialization stores reconstructed theta/qv while leaving
  initial condensate and number fields zero. Its consistency with the
  supplied total-water/reference profile requires later review.
- The known dry/warm P3 invalid-operation observation remains unresolved.

The final S20 basis (D, Z, PMB, PMDv, PMD) and its generating configuration
remain required. Coefficient units, actual grids and numerical agreement are
not inferred from compile success.

Local pre-change source snapshots are retained under
`/tmp/ace-v020-dynamics-review/` to separate this scientific diff from the
preceding input adapter when preparing commits. Suggested separate messages:
`io: extend v0.18 shared input for S20 basis operators` and
`fortran: align S20 reference buoyancy and momentum response`.


## Standalone makima validation (2026-10-04)

After developer approval to proceed with the numerical comparison,
`tests/interpolation/run.py` compiled the production module at both default
real precisions with runtime bounds and invalid/zero/overflow FPE checks.
Independent MATLAB R2023b calls to `makima` and `interp1(...,'makima')`
provided reference outputs. The test is reproducible through the
[interpolation instructions](../../tests/interpolation/README.md); a compact
[report](../../tests/interpolation/results.json) records source/test hashes,
tool versions, limits and worst cases.

All 21 cases pass, with 3,094 queries per precision. The cases include
nonuniform grids, endpoint/extrapolation behavior, two/three nodes,
constant/linear oracles, plateaus, sign changes, mixed value scales and
201 synthetic 200 m basis edges. Unsorted query points are included.
Three invalid grid cases were rejected in each precision build.

| Fortran vs MATLAB same-precision reference | Maximum amplitude-scaled error |
| --- | --- |
| real64 vs interp1 makima | 6.653280933389858e-16 |
| real64 vs makima | 1.0037901670756657e-15 |
| real32 vs interp1 makima | 7.288024172918577e-7 |
| real32 vs makima | 4.620610881723451e-7 |

The fixed arithmetic tolerance is 128 times machine epsilon, with scale
`max(max(abs(reference)),max(abs(input y)),float64 tiny)`. These are amplitude
errors, not pointwise relative errors near zero crossings. The real32
arithmetic is also compared to double evaluation of float32-quantized inputs.

The intentional coordinate-offset stress case (offset 1e6, spacing 0.25)
has about 12.6% scaled difference between real32 and the original real64
reference, almost entirely due to coordinate/input quantization. For this
cross-precision comparison, the bound includes that independently measured
MATLAB quantization effect. The passing arithmetic checks do not imply that
arbitrary double grids are accurately representable in float32.

No production formula correction was required. No actual basis or model
integration was involved; the other dynamics/P3 checks remain pending.


## Unified interp1 and endpoint selection (2026-10-04)

The developer requested the original PCHIP be consolidated with MAKIMA,
with a single interp1 interface, selectable interval-exterior behavior and
only double-precision numerical agreement required. The module now exports:

```fortran
use ace_interpolation, only: interp1
call interp1(n,x,y,nq,xq,yq,'pchip',extrap=.true.)
call interp1(n,x,y,nq,xq,yq,'makima',extrap=.false.)
```

Only `pchip`/`makima` are supported; an unknown method is rejected. The
optional extrap flag defaults true (cubic extrapolation). False holds exactly
the corresponding endpoint value outside the interval. The original PCHIP
core was moved from `ace_module` and retains its n>=3 slope/evaluation
expressions; n=2 now uses linear slopes rather than accessing an absent
third node. Minimum node count and increasing-grid guards were added.
The old public PCHIP entry is re-exported by `ace_module` for compatibility.
Both algorithm entries remain available in `ace_interpolation`, while ACE
uses unified interp1 at both slab MAKIMA and annular PCHIP call sites.
No model endpoint policy was changed: both explicitly extrapolate.

The updated test suite checks double precision only for numerical acceptance;
single precision is compiled but not numerically compared. For 21 fixtures,
3,094 queries per combination, two methods and three policies (including the
omitted/default flag), all 18,564 query results pass MATLAB comparison.
Maximum amplitude-scaled error is 9.57623e-16 (PCHIP extrapolation).
Held values outside the interval are exactly the corresponding endpoint;
default and explicit extrapolation are exactly equal. Both methods reject
three invalid grids, and the dispatcher rejects unsupported linear.
The tolerance is 128*float64 epsilon, 2.84217e-14.

The current [test instructions](../../tests/interpolation/README.md) and
[report](../../tests/interpolation/results.json) supersede the preceding
MAKIMA-only numerical requirement. The previous local full report is preserved
in `migration_work/makima_validation_20261004_repeat/`; current full outputs
are in `migration_work/interp1_validation_20261004/`. No scientific basis,
ACE integration or P3 integration was run. Complete model alignment and
cross-compiler agreement remain unvalidated.
