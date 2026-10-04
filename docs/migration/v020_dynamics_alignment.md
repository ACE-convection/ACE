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

## Slab mass-flux and tracer boundary alignment

The developer subsequently requested slab dynamics alignment.
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

## Checks and remaining work

Development included GNU real32/real64 compile checks and static review of
reference state, operator signs and boundary/mean-flow formulas. Basis
inspection and model/P3 integration remain deferred. The original PCHIP
routine is retained at this checkpoint; standalone interpolation consolidation
and MATLAB numerical comparison belong to the following commit.

Initial perturbations, dt and physics differ from MATLAB. P3 initial
condensate/number consistency and the dry/warm invalid-operation observation
remain pending. This scientific change does not establish full model agreement.
