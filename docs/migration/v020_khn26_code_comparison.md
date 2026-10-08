# KHN26 MATLAB–Fortran implementation comparison

Reviewed 2026-10-08 against the active source at `b1010ea` on
`test/khn26-multiace-gravity-wave`. This is a fresh source inspection,
plus an isolated GNU real64 WENO-coefficient probe. No model trajectory,
production source edit or new scientific-equivalence claim is included.
Previously completed [ten-minute controls](v020_khn26_ten_minute_error_sources.md)
provide numerical context; their measurements were not rerun here.

The developer subsequently requested production k=2 WENO alignment with
MATLAB. The [WENO change and fresh ten-minute gates](v020_khn26_weno_matlab_alignment.md)
supersede the WENO-difference row below for the current working source.
Other rows retain their reviewed scope.

## Scope and common calculation sequence

The comparison covers the shared-input, uniform-grid, slab, k=2,
three-prognostic native/none configuration. Momentum-response operators and
MF diffusion are disabled in the active MATLAB defaults. Fortran real64
is the comparison precision, rather than an arbitrary default-real build.

Both drivers default to zero MF, a saturated +0.25 K bubble in ACE 1 at
levels 11–51, dt=6 s and six hours. The earlier multiACE test changes bubble
amplitude to +1 K and dt to 4 s in diagnostic drivers; those are not the
unmodified production defaults.

Both implementations compute thermodynamics/buoyancy from the start-of-step
state, hold that buoyancy across all nine SSPRK93 tendency evaluations,
complete the dynamics update, clip qt and remove area-mean MF, recompute
post-SSPRK thermodynamics for native precipitation, and apply implicit
Newtonian damping. MATLAB clips qt before projecting MF; Fortran projects
MF before clipping qt. These operations act on separate fields, with no
intervening physics evaluation, so this order does not change their finite
state result. Neither implementation recomputes buoyancy at every RK stage.

See [MATLAB time integration](../../matlab/ace.m),
[MATLAB SSPRK93](../../matlab/util_timeint/ssprk93.m) and
[Fortran driver/tendencies](../../fortran/src/ace_module.F).

## Confirmed remaining differences

| Component | MATLAB | Fortran | Interpretation in the active case |
| --- | --- | --- | --- |
| Bubble saturation | `eval_q2`: EPS*e/(p-e*0.378028169014084). | `eval_qs(T,p,0,phase)` followed by r/(1+r). | Same ideal saturation definition when the complement is treated exactly; written constants and algebra/order are not bit-identical. Initial thermodynamic inversion can also seed differences. |
| Thermal inversion | Explicit complex arithmetic. Unsaturated Newton loop checks imaginary dT and NaN T; either can trigger the condensate fallback. Wrapper diagnoses imaginary outputs then takes their real parts. | Real arithmetic; loop tests abs(dT)>tol, and condensate branch tests q>qsat. | Main phase equations, coefficients and 1e-3 K step threshold align; exceptional-input recovery differs. No claim of equivalent invalid-input behavior. |
| Virtual temperature/buoyancy | Combines ql+qi, then evaluates rho*(g*(Tv-Tv_ref)/Tv_ref). | Subtracts ql then qi; evaluates g*rho*(Tv-Tv_ref)/Tv_ref. | Floating-point grouping differs; reference Tv is also independently reconstructed. |
| k=2 WENO weights | Written decimals 0.666666666666667 and 0.333333333333333. Middle candidate is 0.5*(v_left+v). | Evaluates 2/3 and 1/3; middle candidate is 0.5*v_left+0.5*v. | Confirmed tiny coefficient and expression differences, rather than a changed stencil/order. No trajectory contribution was isolated. |
| Horizontal flow/transport | `cumsum`, logical sign masks, combined tendency expressions; area/perimeter converted to km units. | Prefix `sum`, half-sum sign splitting, successive tendency additions; SI area/perimeter. | Matching ideal active-case definitions after unit conversion, but different accumulation/grouping. Sign splitting can behave differently on extreme magnitudes. |
| Nonlocal PMB response | Broadcast products and nested vector reductions. | Packed contiguous source array; explicit vertical-then-forcing additions with binary64 accumulators. OpenMP distributes independent outputs. | Same active response/reduction axes; runtime/library reduction details can round differently. OpenMP does not parallelize each output's inner sum. |
| SSPRK93 | Early stages use `(dt/6)*K`; later stages use `dt*(K1/6+K2)`. | Early stages use `K*dt/6`; later stages multiply the accumulated expression by dt. | Same nine-stage coefficients and frozen-buoyancy policy; arithmetic order differs. |
| Precipitation dry/overflow handling | Computes sinks and condensate fractions before masking qc<=0; always uses log(1+exp(ramp)). | Skips qc<=0 before division; uses MATLAB expression in representable range and stable softplus fallback above it. | Active condensate method and 1e-8 derivative perturbation align. Intermediate dry division-by-zero and extreme-condensate behavior differ. |
| Physics disabled | Still calls `microrad` before/after SSPRK, which computes precipitation sinks; only their update is disabled. | Stage-one inversion supplies buoyancy; post-SSPRK native inversion/sinks are skipped. | Extra MATLAB calculations do not update the state, but can encounter overflow/invalid intermediates. No extreme-input reproduction was performed here. |
| Sponge | Precomputes density-scaled model.damp; uses broadcast relaxation toward scalar environment and zero MF. | Caches dt*exp(...)/SLTau on first call, then divides by the appropriate density during each update. | Same fixed-dt relaxation equation with different rounding. Fortran's saved cache assumes one fixed grid/dt per process; rebuilding a MATLAB model can refresh its coefficient. In-process reconfiguration was not tested. |

### WENO coefficient check

An isolated program used the actual Fortran initializer
`d=(/0.,2./3.,1./3./)` and GNU `-O2 -fdefault-real-8 -fdefault-double-8`.
The binary64 bit patterns were `3FE5555555555555` and `3FD5555555555555`.
Compared with the MATLAB written decimal constants, Fortran-minus-MATLAB
differences are -3.3306690738754696e-16 and +3.3306690738754696e-16.
This verifies coefficient representation only; it does not measure a WENO
output difference or its accumulated contribution to the trajectory.

Sources: [MATLAB WENO](../../matlab/util_weno/reconstruction_weno_vec.m),
[bubble saturation](../../matlab/util_thermodynamics/eval_q2.m),
[thermal inversion](../../matlab/util_thermodynamics/inv_T_from_theta_e.m),
[forward thermodynamics](../../matlab/util_thermodynamics/eval_theta_e.m),
[Fortran initialization](../../fortran/src/test.F), and
[Fortran numerical routines](../../fortran/src/ace_module.F).

## Boundaries, interpolation and implementation scope

For the active slab case, both use the outermost ACE itself for outer
tracer and momentum exchange, zero surface tracer flux, the same UP3
odd surface extension/circular upper stencils, nonnegative-flow selection
for k=2 WENO, and zero top-eleven-level dynamics tendencies. MATLAB sets
the outer turbulent coefficient to zero; Fortran retains that coefficient
but multiplies it by a self-minus-self difference for finite states.
No different active boundary condition was found by this inspection.

Both average fine-grid forcing into coarse layers and use MAKIMA for the
slab pressure response when coarse_ratio>1, or direct values when it is 1.
Fortran's annular branch uses PCHIP; this is outside the active slab case.
The binary-search PCHIP change is not a KHN26 slab algorithm change.

MATLAB retains configurable MF diffusion, response truncation and higher
WENO orders. Fortran contains a k=3 branch but its boundary implementation
is not established equivalent; k=4–6 are absent. Fortran additionally
supports eleven-prognostic P3. These are separate configurations and are
not certified by the native k=2 comparison.

State storage differs: MATLAB `(z,var,ACE)` with theta_e/qt/MF plus two
diagnostic slots; Fortran `(ACE,z,var)` with MF/theta_e/qt and an extra
environment column. MATLAB interval output uses NetCDF double storage;
Fortran's normal nine-field interval output is real32, while comparison
state streams are binary64. MATLAB's extra precipitation slots are not
updated by the post-SSPRK native sink addition, and Fortran native
rain/riming slots are zero. Neither is accumulated surface rainfall evidence.

## Assessment and recommended next check

No new mismatch in the active governing discretization, SSPRK coefficients,
phase definitions or boundary rule was identified. This is source-level
evidence, not a proof of scientific equivalence across configurations.
Actual differences remain in WENO coefficient representation, operation
order, complex/real thermodynamics, exceptional-input handling and outputs.

The existing controls demonstrate that upstream roundoff can be amplified
by the 1e-8 precipitation finite difference. They do not isolate WENO as
the first seed or establish a unique cause of the full three-hour drift.
The next small diagnostic experiment should align only k=2 WENO constants
and grouping in an isolated copy, then replay identical states and compare
interface fluxes, SSPRK states and post-precipitation differences. Production
changes and a new long integration await a separate developer decision.
