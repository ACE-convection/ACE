# KHN26 v0.20 source integration and Fortran alignment

This page records the initial 2026-10-04 integration. Subsequent PMB,
constant and thermodynamic changes and their validation scope are indexed
in [current development status](../maintenance/history_summary.md#record-v020-khn26-status). In particular,
`b1010ea` updates native softplus evaluation to follow MATLAB when the
exponential is representable; the description below is the initial method.

Implemented 2026-10-04 on `migration/v020-preparation`, after the developer
confirmed promotion of the author-selected November 2025 KHN26 reference.
The [pre-promotion review](v020_khn26_review.md) preserves the earlier
findings at `c7d9183`; its statements about active S20 code are historical.
No release, tag, commit or historical deletion is part of this integration.

## Source preservation and import

The original 51 MATLAB files are preserved byte-for-byte in
[`khn26_sources.tar.gz`](khn26_sources.tar.gz), pinned by
[the integration manifest](v020_khn26_integration.json) and
[original inventory](v020_khn26_source_inventory.json). Four `util_basis/bak/`
files remain archive evidence rather than active utilities. Two builders
retain their existing `util_basis/uneven_tests/` paths and identical contents.
All remaining helpers use the supplied KHN26 bytes; active `matlab/ace.m`
is adapted from `ACE_V020_2D88ACEs_NoGlobal.m`. Previous active sources remain
in Git at `c7d9183` and in the ignored pre-alignment workspace.

Imported utility differences include mode-builder defaults, the plume
routine's globals, and theta_il heat capacity/inverse expressions. The
reported `2834.e6` ice term and removed fourth inverse argument are preserved,
not silently corrected or ported. These theta_il/plume paths are not called
by the default theta_e driver and have not received scientific acceptance.

## Shared input and MATLAB adapter

Both drivers select `data/input/manaus1342_khn26.nc`: supplied 4UNEVEN basis
(actual 101 ACEs), processed Manaus profile 1342, 401 fine levels and 200
coarse layers. The original source label mentioning UNEVEN41 does not
identify its actual dimensions. [Input validation](v020_khn26_input_validation.json)
records exact full-PMB and processed-profile readback; no sounding
interpolation/humidity adjustment is repeated. [Shared input](../shared_input.md)
owns conversion, schema, input hashes and compatibility aliases.

The MATLAB adapter converts slab geometry from SI to original km conventions,
retains supplied profiles and reconstructs reference Tv through theta_e/qt
inversion, exactly as KHN26 does. The default bubble is saturated +0.25 K
in ACE 1, levels 11–51, with zero initial MF. Defaults remain dt=6 s and
six hours, native post-dynamics precipitation, disabled momentum responses
and disabled MF diffusion. The struct is named `model` to avoid MATLAB's
script/function name collision with `ace.m`; local arguments are renamed
consistently. The diagnostic inverse helper's undefined `p_mf` reference is
changed to its actual `p_zc` argument. This diagnostic branch is not the
validated default initialization path.

`ACE_STEPS`, `ACE_PHYSICS`, `ACE_VALIDATE_INPUT`, input/output paths and
legacy processed-input mode are documented in [MATLAB instructions](../../matlab/README.md).
Output is NetCDF, with width in metres, corrected MF units/ice label and
reference/profile/physics/input provenance. Existing output is preserved
by rejecting an occupied output path. Historical unused diagnostic slots
are not promoted to precipitation accumulation evidence.

The shared file has no supplied momentum operators. Full-shape compressed
zero PMDv/PMD have `source_status=disabled_zero_placeholder`; readers retain
that marker and both initialization paths reject activation. A missing
attribute remains compatible with older supplied schema-2 operators.
This does not validate their units or enabled momentum physics.

## Fortran numerical changes

The retained P3 implementation gains a native three-prognostic driver option
(default for slab inputs); `--physics none` isolates dynamics. P3 remains
an explicit eleven-prognostic option. Slab initialization uses the KHN26
bubble, zero initial MF and inversion-derived environmental Tv. P3 mapping
now preserves reconstructed environmental liquid/ice water instead of
silently dropping it; P3 evolution is not validated by these comparisons.

The native sequence is SSPRK93, total-water clipping, post-dynamics
thermodynamic inversion/precipitation, then damping. The optional final
`ace_driver` argument disables native precipitation; existing callers retain
its enabled default. Precipitation uses KHN26's softplus ramp, thresholds,
timescale and 1e-8 finite-difference theta_e derivative. Fortran evaluates
softplus as `max(x,0)+log(1+exp(-abs(x)))`, with a dry-state early exit.
This avoids overflow and division by zero. The original MATLAB formula
is preserved: one of eight focused cases (20 g/kg condensate) overflows
there. Its stable mathematical water sink is checked independently with
NumPy logaddexp and the original MATLAB forward-thermodynamic derivative.
This exception is not byte agreement with the overflowing historical result.

Fortran theta_e inversion now follows the KHN26 cold-branch derivative
sign, liquid/ice starting constants and exact empirical saturation
pressure derivatives. Newton iteration is otherwise retained. MATLAB's
broader fallback/complex recovery behavior is not newly ported.

Default k=2 WENO endpoint stencils and UP3 circular top stencils/sign(0)
now match MATLAB. Explicit output initialization removes undefined WENO
endpoint values. k=3 is not accepted by these tests; MATLAB k=4–6 are not
ported. Earlier shared slab geometry, pressure-basis contraction, MAKIMA,
buoyancy and area-mean MF alignment remain in place. NaN diagnostics use
`n_prog` bounds so native states do not access P3-only slots.

Fortran run/state/output choices are in [Fortran instructions](../../fortran/README.md).
Nine-field binary output retains real32 storage with documented native/P3
field meanings; state comparison streams use binary64. Native and P3
prognostic fields must not be interpreted interchangeably.

## Validation and limits

[Reproduction instructions](../../tests/khn26/README.md) use the actual
101-ACE basis and both production implementations. The
[validation report](v020_khn26_alignment_validation.json) records metrics,
source/input/artifact hashes, compilation commands and evidence scope.
GNU Fortran 11.2.0 builds both default-real64 and default-real32. Numerical
comparisons use real64 with bounds checks and invalid/zero/overflow traps.
MATLAB uses R2023b on this host.

Archived original KHN26 versus shared MATLAB has exact equality for the
initial state, reference Tv and native 6 s step. Fortran versus MATLAB:

| Check | Maximum absolute error |
| --- | --- |
| Initial theta_e / qt | 3.98e-13 K / 1.02e-16 kg/kg |
| Reference Tv | 1.14e-13 K |
| Native and physics-off 6 s MF / theta_e / qt | 6.66e-16 / 4.55e-13 K / 1.02e-16 kg/kg |
| Nonzero-MF transport tendency, MF / theta_e / qt | 1.19e-16 / 5.63e-14 / 4.77e-22 |
| Nonzero-MF transport step, MF / theta_e / qt | 7.15e-16 / 4.55e-13 K / 2.17e-19 kg/kg |
| 406 thermodynamic inversions, T | 5.68e-14 K |
| Native 60 s run, MF / theta_e / qt | 9.99e-15 / 1.14e-12 K / 1.03e-16 kg/kg |
| Eight precipitation cases, theta_e / qt sink | 1.16e-8 K/s / 8.76e-24 kg/kg/s |

PMDv and PMD activation are separately tested and rejected through the
production Fortran initializer using a small marked fixture. The production
MATLAB NetCDF output is checked in a ten-step native smoke run; its detailed
trajectory comparison is in the validation report.

These are narrow regression tolerances, not six-hour release criteria.
Normal Fortran nine-field interval output runtime and the P3 initialization
mapping are also not covered by the state-stream tests.
Full six-hour trajectory, budgets, precipitation accumulation, physical
interpretation, nondefault momentum/order/diffusion branches, Intel/GNU
comparison, P3 runtime and real32 numerical acceptance remain unestablished.
In particular, real32 retains the 1e-8 finite-difference derivative, which
can lose significance. The v0.18 analytic-derivative precision fix is not
silently substituted for the selected KHN26 formula.
