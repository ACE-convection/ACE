# Fortran v0.20 behavior-preserving OOP refactor

## Decision and baseline

Planning inspection: 2026-10-12. Read and follow repository `AGENTS.md`.
Scientific/numerical baseline: unified ACE v0.20.0,
`115cc50db158f2a0f0ba55fca66027958a895060` (release merge and tag target).
Architecture reference only: separate ACE_FORTRAN repository,
`b3f922e48e238581a85d31469bafcb800569a748`.

This is a v0.20 architecture task. No v0.24 implementation, eta/cref,
K1/K2 terrain kernel, vorticity/Lamb state or immersed-boundary metadata is
introduced. No source is modified in this planning interaction. Every code
stage, including the subdivisions below, requires separate developer approval.
No automatic commit, push, tag or main merge is authorized by this plan.

The earlier v02487 source review is retained as separate work. Its suggested
OOP preparation now refers to this v0.20 preservation plan; its scientific
feature-port sequence is deferred until this baseline has passed regression.

## Inspected source and evidence

Active source: `fortran/src/test.F`, `ace_module.F`, `ace_input.F`,
`ace_interpolation.F`, `microphy_p3.F`, and `fortran/makefile`.
Inspected the reference's `ace_t`, methods, namelist, response/tendency,
native sink, initialization/output and saved caches directly from Git.

Authoritative acceptance is [v0.20.0 notes](../releases/v0.20.0-notes.md),
with current driver contracts in [Fortran README](../../fortran/README.md).
Existing evidence/tools inspected:

| Evidence | Use for refactor |
| --- | --- |
| [KHN26 tests](../../tests/khn26/README.md), `run.py`, `multi.py`, `gate_matlab_default.py` | Initialization/component checks; all nine tendency frames; native sinks; dry/native ten-minute gates; checked/production prefixes |
| [WENO gate results](../../tests/khn26/weno_matlab_alignment_gate_results.json) | Preserve current written k=2 expressions; existing MATLAB tolerances are contextual, not OOP tolerance allowances |
| [Aligned three-hour review](v020_khn26_weno_three_hour_review.md) | Accepted native multiACE trajectory, raw hashes and source-version scope |
| [P3 smoke](v020_khn26_p3_smoke.md), `p3_smoke.py`, [three-hour record](v020_khn26_p3_three_hour.md) | P3 variable ordering, debug/production identity and validity/riming checks |
| [Minute-output checks](../../tests/khn26/precip_output_results.json), `check_precip_output.py` | Actual accumulator fixtures, output cadence/units and reader checks |
| [Final replay results](../figures/khn26_multi_precipitation_3h/results.json) | Three complete replays, 181 records each and exact within-implementation state reproduction |

Older singleACE and pre-WENO reports do not silently replace current
production behavior. Test-generated drivers add +1 K/dt=4/masking settings;
those changes must be applied identically to frozen baseline and candidate.
The production +0.25 K/dt=6 defaults remain unchanged. Raw references reside
in ignored workspaces and must be hash-verified, not assumed available on a
fresh clone. The native replay reference hash is
`be233ddf6596c96f150be015898a33d69e901969b06cc85124d30d5a5f7559fc`;
P3 multiACE is
`c91e1171f9d840ad1254a4f72e0b3b695caf1785254ae205ab1f0e5db3503044`.
These long references are final preservation evidence, not permission to
start long integrations during planning.

## Proposed ownership and interface

Keep `ace_module` as the model module, `ace_input` as the unchanged input
adapter and `ace_interpolation` as the existing pure numerical service layer
(no claim that every procedure has a Fortran PURE attribute). Retain the
third-party P3 source. Use a concrete, privately owned allocatable model
object; avoid pointer aliases to shared module storage, class inheritance,
state-array transposes and copied PMB allocations.

Conceptual final structure (not code to implement all at once):

```fortran
type :: ace_t
  private
  ! configuration: ncols, nz, n_prog, n_weno, dt, t, existing physics/options
  ! prognostics/reference/geometry: X, Ref, A, B, forcing, Tv0
  ! response context: coarse grids, packed PMB, PMDv/PMD, coarse_F, dwdt
  ! thermal cache: Ta, q, ql, qi, reference_tv
  ! late-stage caches: damping initialization flag/values, P3 wrapper clock
  ! output buffers/record state: retain existing kinds and layout
contains
  procedure :: initialize
  procedure :: integrate
  procedure :: diagnose
  procedure :: output
end type
```

Keep native X(ACE,z,var) order MF/theta_e/qt, P3's existing 11 variables,
the extra environment column and Ref columns. Keep compiler-dependent
model real kind, binary64 PMB/input/comparison storage and real32 normal
output. Do not standardize all reals as part of this refactor.
Input methods consume existing CLI-derived options and current adapters;
no historical namelist replacement, schema redesign or new user-visible
configuration convention. Existing procedural numerical helpers remain
where useful; type-bound entry points need not turn every scalar helper
into a method. Retain old interfaces temporarily for actual test callers,
with one explicit ownership path rather than duplicated state. Transitional
single-instance restrictions must be documented until all caches are audited.

## Global/SAVE audit and lifetime policy

| Current owner/state | Classification and planned handling |
| --- | --- |
| `test.F`: X/Ref/A/B, forcing, initial/profile/environment arrays, ts/te/dt and options | Model state/configuration; progressively owned by object. Parsing stays in thin program initially. Preserve ordering of profile conversion, bubble creation, lookup setter and basis initialization. Release temporary profile arrays only if baseline lifetime is intentionally preserved/reviewed. |
| `ace_module`: coarse_nz/ratio, coarse grids, coarse_F/dwdt, packed PMB and PMDv/PMD | Instance response context. Move together with explicit instance argument in a separately approved stage; preserve allocation, packing and inner reduction order. No full PMB copy into a passive object. |
| `ace_module`: slab_geometry, zero_ref_buoyancy, Wbar_eq_zero, momentum switches, reference_tv | Instance flags/reference data with initialization-dependent defaults; preserve when and how defaults are assigned. |
| `ace_module`: Ta/q/ql/qi | Instance thermal scratch, but not disposable: stage one populates them, later RK stages reuse them, native post-RK sinks refresh them. Do not recompute at every stage or reset them at method boundaries. |
| `ace_module`: p3_lookup_directory | Instance option eventually, but preserve setter validation and lookup selection before first P3 initialization. |
| `ImDamp`: SAVE first/damp | First-use cache built from dt/Ref/grid on first damping call. Preserve that timing for baseline object. Move only in cache stage; do not refresh every step. Current `Ref(nz,7)` dummy versus driver's eight-column Ref is a pre-existing interface risk to document/check separately, not silently repair. |
| `p3_wrapper_ace`: SAVE first/itt | First-use wrapper init and timestep count. Preserve first itt=1, increment position, X_old timing and library-init call sequence. Migration does not by itself isolate library state. |
| `microphy_p3`: lookup tables, runtime-initialized constants, iparam, n_iceCat, global_status; p3_init SAVE is_init | Third-party process-wide state. Leave intact in this refactor unless separately approved. Tables are effectively shared read-only after setup, but initialization flags/status are mutable. No concurrent or independent mixed-configuration P3-object support is claimed. |
| Constants/WENO/thermodynamic parameters; ace_input/interpolation | Keep shared immutable constants and existing helper formulas. No persistent model arrays found in input/interpolation modules. |
| `test.F`: Xout(real32), rh4/b4, diagnostic Tr/q/ql/qi, output units/record n | Output/diagnostic context. Separate from integrator's cached thermal arrays; method calls must not mutate the integration cache. Preserve initial/final writes, record order, conversion order, binary headers and fresh-file rules. |

Audit implicit SAVE too: module variables have persistent lifetime; local
variables with declaration initialization can be saved even without SAVE.
P3 uses extensive module storage beyond the wrapper's explicit flags.
Retain initialized flags at their original first-use point; define explicit
reset/reinitialize semantics only after separate review. Until the final
cache gates pass, use fresh processes and one live model per process.

## Architectural elements reused and behaviors rejected

Reuse only: owning derived type; type-bound entry methods; configuration,
state, reference and workspace grouping; thin executable driver.

Do NOT copy the reference's:

- Hard native precipitation ramp `max(ramp,0)`: keep current smooth expression,
  stable-overflow fallback, dry guard before division and 1e-8 finite difference.
- Post-RK sink based on stale stage-one thermodynamics: keep current post-RK
  clipping and inversion/precipitation sequence.
- Last-ACE compensating MF tendency: retain current slab end-SSPRK area-mean
  MF projection, area-mean buoyancy removal and current boundary/masking rules.
- Separate case_IC/basis input and namelist defaults: retain shared schema and
  legacy input semantics, command options, checks, environment conversion,
  grid/dt/bubble defaults and external P3 directory option.
- Universal PCHIP and un-packed nested PMB reductions: retain slab
  MAKIMA/direct versus annular PCHIP selection, general coarse ratio, packed
  binary64 PMB and exact vertical-then-forcing additions/OpenMP scheduling.
- Different WENO/thermodynamic literals or expression grouping: retain current
  MATLAB-aligned production expressions, convergence and exceptional behavior.
- Optional implicit diffusion enabled by reference: do not add a driver call
  absent in current v0.20. Keep current damping position and constants.
- NetCDF output redesign/overwrite behavior or shared output SAVE flag:
  preserve v0.20 numerical content, layouts, kinds and output contracts.
- Shared first/damp/itt as supposedly object-safe design: independently audit
  current lifetimes; do not adopt the reference's multi-instance defects.

The current integrate loop's full-dt target behavior also remains; correcting
nonaligned end-time overshoot is separate behavior-changing work.

## Staged implementation plan

Each row is a review/approval boundary; no approval covers multiple rows.
All expect zero numerical impact, which must be demonstrated rather than
inferred from textual changes. New test instrumentation stays outside
production science and observes arrays at the same points in both builds.

| Stage | Files and state/data | Interface changes | Expected impact / required gate |
| --- | --- | --- | --- |
| OOP-0, evidence preparation | New `tests/khn26/oop_regression.py` (proposed stable name), isolated baseline build/workspace; no source edits | Test-only access to private raw tendency/response arrays in isolated copies | Freeze baseline inputs/source/build/configuration; verify instrumentation does not alter uninstrumented prefix/output; matched debug and production builds |
| OOP-1, passive type | `fortran/src/ace_module.F`: add/export unused ace_t with dimensions, dt/time and allocatable X/Ref/A/B/forcing declarations | Only new public type; no bindings until implemented; old procedures/call sites unchanged | No executable behavior or ownership change; compile/link serial/OpenMP real64 and real32 compatibility; same initialized/raw tendency/one-step/short-output/diagnostic gates |
| OOP-2, initialization ownership | `ace_module.F`, `test.F`: move existing profile/grid/initial-state preparation into initialize method in unchanged statement order; transfer X/Ref/A/B/forcing/initial environment ownership; retain original input adapter | `model%initialize(existing options)`; existing parser remains; integration still uses object arrays via old procedural driver | Exact initialization X/Ref/A/B/Tv0/coarse grids and operator data; identical errors/options; one-step and short-output regression; singleton response context is explicitly transitional |
| OOP-3a, response context | `ace_module.F`, dependent test wrappers: move coarse grids/ratio, PMB/PMDv/PMD, coarse_F/dwdt and geometry/response flags | Pass context/self to response initialization and tendency helpers without changing array layout | Exact response tables, forcing, coarse response and all tendency frames; allocations/packing/order/OMP checks; thermal and damping remain singleton until later rows |
| OOP-3b, integration method | `ace_module.F`, `test.F`, test adapters: move Ta/q/ql/qi/reference_tv and integration clock/options into model; preserve automatic RK work arrays initially | `model%integrate(te)` plus explicit-self private tendency/native helpers; compatibility adapters only where genuinely needed | All nine SSPRK frames, pre/post-physics, pre/post-damping states, native sink and complete timestep byte identity; dry/native ten-minute and P3 prefix gates |
| OOP-4a, diagnose | `ace_module.F`, `test.F`: move existing write_state diagnostic calculations/buffers into observational method | `model%diagnose()`; diagnostic arrays distinct from integrator thermal cache | RH/buoyancy/phase fields and real32 conversion exact; X and integrator caches unchanged by diagnose; identical results with original call cadence |
| OOP-4b, output | `ace_module.F`, `test.F`: wrap existing serialization/record bookkeeping; reuse diagnose | `model%output()` with existing units/record policy; preserve comparison state writer | Initial/interval/final state streams and all nine output fields byte-identical; header, record count, precision, order, file freshness and diagnostic accumulation checks |
| OOP-5a, damping cache | `ace_module.F`: migrate first/damp to model | Explicit-self ImDamp, same expression and first-use timing | First and subsequent damping identity; two native instances sequentially vs isolated fresh-process references, including differing grid/dt where supported |
| OOP-5b, P3 wrapper lifecycle | `ace_module.F`: migrate wrapper directory/itt/first where library contract permits; leave third-party source/tables unchanged | Model-owned wrapper options/clock; explicitly documented process-wide library restriction | Same lookup hash/init timing/count and every P3 field; two sequential same-config objects vs fresh-process references only if library semantics permit; otherwise retain explicit single-P3-instance restriction |

After each stage stop for report/review. OOP-2/3 extraction can be subdivided
further if actual diff becomes too large; approval is then required per
smaller unit. Do not achieve smaller diffs by hiding a full model-state copy
or substituting reference algorithms. Do not claim OOP completion while
integrator state still silently comes from legacy singleton globals.

## Regression contract

Build baseline and candidate in separate fresh directories, with identical
compiler/version, optimization, default-real/double precision, NetCDF flags,
input/lookup hashes, dt/grid/case and thread policy. No fast-math, mixed object
reuse or expression reformulation. Start with GNU checked real64 prefix
(bounds, invalid/zero/overflow traps), separately rebuilt production real64,
serial and requested/actual 32-thread OpenMP. Keep real32 compile compatibility
as required; do not claim new KHN26 real32 scientific acceptance.

Minimum paired comparisons at matching observation points:

1. Initialization: full X including environment, Ref, A/B, Tv0/reference_tv,
   coarse grids/ratio, flags; packed PMB shape/values and any allocated PMDv/PMD.
2. Raw stage-one tendency on identical initialized/nonzero-transport states:
   all fields, rho0B/mean correction, F/coarse_F/packed_F/dwdt and interpolated
   MF tendency. Compare all nine frames for the complete step. Private access
   is test-only; no state restoration that changes stage-cache semantics.
3. Full timestep: intermediate SSPRK, projection, qt clipping, refreshed
   thermodynamics, native sinks/P3 call outputs, damping and final clock.
4. Short runs: ten-step checked/production prefixes and 150-step (600 s,
   dt=4 s) dry/native trajectories under the same documented experiment.
   P3 checked/production prefix and short-run counterpart when touched.
5. Diagnostics: theta_e/qt/MF; P3 theta/qv/all hydrometeors/numbers/riming;
   thermal phase/Tv/RH/buoyancy; mean MF and actual native removal/P3 flux.
   Confirm finite saved values, native qt>=0 and P3 validity invariants.
6. Serialization: initialization dump, raw state streams, all real32 normal
   output fields, record count and cadence. Reuse minute diagnostics with
   identical isolation/instrumentation; they are not production rainfall slots.

Prefer exact bitwise equality; compare kinds/layouts directly before casting.
Use hashes as evidence plus array comparison to locate differences. Exclude
wall-clock logs from numerical byte comparisons. Cross-language tolerances
cannot excuse Fortran-before/after drift. If identity fails, stop and report
first divergent stage/time/ACE/level/variable and baseline/candidate bits,
absolute/relative error (zero-reference handling explicit), max absolute,
relative L2 and reason. Do not loosen limits or accept unexplained drift.

A new OOP regression adapter is needed: current scripts use textual anchors
and generated isolated module/driver copies. Adapt them separately, validate
baseline vs baseline first and preserve their originally executed versions.
A passing old JSON report is not evidence for changed source.

At final OOP acceptance, reproduce the accepted native/P3 three-hour state
references where configurations/source scope match, and repeat precipitation
record/bookkeeping checks if their generator hooks changed. That final long
validation is deferred to the approved stage, not launched by this document.

## Risks and first smallest source change

Compiler aliasing/dispatch/inlining, implicit array temporaries, allocatable
ownership/move_alloc timing, PMB memory peak, initialization ordering,
OpenMP data-sharing, scratch-cache persistence, diagnostic side effects and
P3 singleton lifecycle are the main preservation risks. Inspect existing
interface issues without bundling behavior fixes into the architecture work.

Recommended first source change: **OOP-1 only**: add a passive, unused public
`ace_t` declaration in `ace_module.F`. Do not instantiate it in test.F, bind
methods, allocate/copy PMB, remove module arrays or change existing procedure
signatures. This makes the initial diff small and independently reviewable.
Prepare OOP-0 evidence before verifying this first source stage; it is test
preparation, not permission to implement any later stage. Await developer
approval for this single source change.

## OOP-0 execution record (2026-10-12)

The developer authorized stage 0 only. `tests/khn26/oop_regression.py` now
freezes the release source into a fresh ignored workspace
`migration_work/fortran_v020_oop_stage0`. Original and observational copies
are built independently in GNU real64/OpenMP production and checked modes.
All cases run sequentially in fresh processes; no MATLAB rerun is required
for an unchanged Fortran-only baseline.

The fixture retains the production +0.25 K bubble and zero initial MF,
with an explicit dt=4 s override to match the prefix/one-minute clock contract.
It covers physics none, native and P3 initialization, ten complete timesteps
and normal 0/60 s nine-field output. It is distinct from the accepted +1 K
three-hour experiment and does not replace that evidence.

Observational hooks write existing arrays without changing equations or
expression grouping: initialization reference/coarse grids, packed PMB and
momentum tables, all nine raw RK tendencies and nonlocal/thermal work arrays,
pre/post-physics states, post-damping state/cache, native sinks and P3 surface
liquid/solid rates. Full operator tables are saved once to avoid repeated
large dumps. A preserved patch records every observational source edit.
Production `fortran/` remains identical to the release.

The comparator checks exact bytes first and reports first element/bits,
absolute/relative error and L2 differences when unequal. It handles integer
stream headers, binary64 state streams and real32 normal output separately.
Synthetic checks exercised numeric drift, signed-zero differences, truncated
files and mixed-header state locations. Postprocessing records observation
shapes/counts for decoding step/stage/ACE/level/variable, and checks finite
saved state/output, water nonnegativity and P3 qrim<=qi.

Reproduce into a fresh directory on a host with the pinned data/compiler:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --lookup-directory /path/to/p3/tables
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
```

`--compare CANDIDATE_WORKSPACE` compares frozen binary artifacts without
launching a model. A later OOP implementation still needs an adapter mapping
its own arrays to these same observation points; stage 0 does not implement
an OOP model or relax regression limits. Integration and postprocessing runner
hashes are recorded separately when analysis tooling evolves after launch.

### Completed OOP-0 gates

All 24 fresh-process model commands exited successfully. For each of physics
none/native/P3, original versus observed initialization, ten-step production
and checked state streams, and one-minute state/nine-field outputs are
bitwise identical. Checked versus production prefixes also reproduce every
observed response/tendency/cache/sink/flux stream exactly.

Postprocessing passed 165 observation-layout/frame-count checks and validated
18 state streams plus normal real32 outputs. Saved values are finite; native
qt and P3 water/number/riming fields are nonnegative; P3 qrim<=qi. Native/P3
precipitation rates are finite/nonnegative and descriptive accumulated values
are preserved with their different definitions. Host process inspection
observed an actual 32-thread integration process.

[Versioned stage-0 results](../../tests/khn26/oop_stage0_results.json) record
source/input/table/compiler provenance, all comparison decisions, observation
layouts, state/precipitation diagnostics, raw-artifact hashes and executable
hashes. The exact executed integration runner and separately updated analysis
runner have distinct recorded hashes. The raw workspace preserves commands,
logs, baseline makefile, uninstrumented and observational sources, hook patch,
operator tables, all raw traces and state/output streams.

The release production tree is unchanged. There is no real32/serial runtime
acceptance, no three-hour rerun and no OOP source implementation in this stage.
Stage 0 is complete; await separate approval for OOP-1.
