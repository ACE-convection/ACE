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

## OOP-1 passive declaration (2026-10-12)

The developer authorized OOP-1 after committing OOP-0 as `1289498`.
`ace_module.F` now exports a concrete `ace_t` with private dimensions
ncols/nz/n_prog/n_weno, dt/t and allocatable X/Ref/A/B/forcing components.
There are no method bindings, scalar default changes, allocations, pointer
aliases or live model instances. The current model state still belongs to
the original procedural driver/module. These passive components have no
assigned scalar values yet and must not be read before a future approved
initialization stage. No P3/state/cache ownership has moved.

The production diff is ten added declaration/comment lines in ace_module.F.
Removing that declaration block exactly recovers the release source; test.F,
ace_input.F, ace_interpolation.F and microphy_p3.F are unchanged.

The regression tool has an explicit `--candidate-baseline` mode. It snapshots
current source, verifies the OOP-0 artifact hashes and matching compiler/input/
lookup/grid/dt/thread settings, then runs only the candidate in fresh builds
and processes. It checks candidate observational neutrality and compares
all numerical artifacts against the frozen stage-0 workspace. The frozen
baseline is neither rerun nor rewritten. Preserve test/build snapshots and
separate executed-tool hashes when postprocessing helpers are updated.

A separate compilation matrix uses the uninstrumented candidate snapshot,
building/linking the full executable with default real32 and real64 in both
serial and OpenMP modes. A minimal external client declares an unused ace_t
with private components, verifying that the new public type can be imported
and linked; running that empty client does not integrate the model. All four
compatibility cases passed. This adds no real32 scientific/runtime acceptance.

Reproduction (fresh nonexistent candidate workspace; pinned stage-0 artifacts
must exist):

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline FROZEN_OOP0_WORKSPACE
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
```

Numerical evidence is recorded after the candidate matrix finishes. No
OOP-2 initialization extraction, automatic commit, push or tag is part of
this stage.

### Completed OOP-1 gates

All 24 candidate model commands completed successfully. Candidate original/
observed initialization, production/checked ten-step state streams and
one-minute state/normal outputs are bitwise identical. All 195 candidate
binary artifacts also exactly match the hash-verified frozen OOP-0 artifacts,
including operator tables and raw RK response/tendency/thermal/sink/flux/
damping observations. No tolerance was changed and no divergence was found.

Postprocessing passed 165 observation-layout/frame-count checks and validated
18 saved-state streams and all normal output values. Native qt and P3 water/
number/riming fields remain nonnegative; P3 qrim<=qi. The four serial/OpenMP,
real32/real64 compilation/link cases and empty public-type clients passed.
Numerical runtime evidence remains GNU real64/OpenMP32; compilation success
is not real32 or serial scientific acceptance. The 150-step gates apply when
integration/cache behavior is migrated in the later approved stages; this
passive declaration is checked against the fixed OOP-0 short matrix.

[Stage-1 results](../../tests/khn26/oop_stage1_results.json) preserve all gates,
source/input/build provenance, compatibility commands, state diagnostics,
artifact/executable hashes and tool provenance. The full candidate workspace
is `migration_work/fortran_v020_oop_stage1`; the stage-0 workspace is unchanged.
The developer clarified that OOP-1 should be committed after completion;
OOP-2 still awaits a separate instruction.

## OOP-2 initialization ownership (2026-10-12)

The developer authorized OOP-2 after OOP-1 commit `88151b0`.
`ace_t%initialize` now contains the original metadata/default resolution,
shared/legacy profile and geometry reads, allocation/conversion, environment
reconstruction, KHN26 bubble or legacy MF initialization, P3 directory setter
and response initialization in their original statement order. CLI parsing
and existing error strings/options remain in their original layers.

The object owns X/Ref/A/B/forcing, Tv0, initial fine/coarse grids, input
binary64 arrays, retained profile conversion arrays and initialization-only
Tr/q/ql/qi scratch. No input adapter, interpolation formula, PMB packing,
RK expression, physics call or third-party P3 source is changed. Removing
`self%` qualification and the separate output-buffer allocations reproduces
the original initialization statements exactly. This textual audit is a
supplement to numerical comparisons, not scientific equivalence evidence.

`test.F` calls `model%initialize` then `model%with_legacy_state(run_model)`.
The temporary synchronous callback exposes assumed-shape arguments to the
existing procedural integration and serialization code without pointer
aliases or an explicit copy of the live state. Ref/A/B/Tv0 and input coarse
grids are read-only callback arguments; X/forcing retain their original
mutable use. `write_state` takes X/Ref/Tv0 as explicit read-only arguments.
The callback is a transitional public bridge, not `integrate` or `output`.
GNU linking reports an executable-stack requirement for the internal
procedure callback in `test.F`; compatibility on hosts forbidding that
mechanism is not established. Later integration/output methods should
remove the bridge rather than retain this compiler-dependent mechanism.

Driver dimensions/options and integration time still drive the procedural
path. The object's dt/t fields record initialization only; they are not a
claim of model-owned integration time. Response context, reference_tv,
Ta/q/ql/qi integration caches, damping SAVE variables, wrapper clocks and
P3 library globals remain module/process state. Initialization scratch and
driver diagnostic arrays are separate from those integration caches. Keep
one model initialized once in a fresh process; reinitialization and multiple
independent objects are not supported or validated at this stage. Retained
input/profile arrays are not prematurely deallocated.

KHN26 single/multi and P3 smoke experiment adapters now alter the bubble/MF
at its owning initialization site in `ace_module.F`, preserving the original
experiment expressions and source patches. Probe/profiler helper insertion
uses the module `contains` boundary rather than the newly added type-bound
procedure boundary. These adapter changes introduce no production experiment
configuration options.

Reproduce with pinned stage-0 artifacts, input, compiler and lookup data:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline migration_work/fortran_v020_oop_stage0
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
python3 tests/khn26/oop_initialization_contract.py NEW_WORKSPACE
```

The supplemental initialization-contract runner uses the existing frozen
baseline executable read-only, with all new outputs in the candidate
workspace. It compares default shared and legacy initialization, an unused
lookup-directory option, user-visible failure messages, and 150-step dry/native
state streams. The unused-directory initialization must succeed: the existing
setter stores the path; P3 table loading occurs later. It does not promise
that missing tables are checked during initialization. `--resume` verifies
completed binary-artifact and executable hashes before skipping saved gates.
OOP-3 and any commit require separate developer instructions.

### Completed OOP-2 gates (2026-10-13)

All 24 candidate model commands passed. Candidate observational neutrality,
checked/production prefix identity and the frozen OOP-0 comparison all pass;
all 195 binary artifacts are bitwise identical, including initialization,
operator tables, raw RK response/tendency/thermal/sink/flux/damping data,
state streams and normal real32 output. Postprocessing passed 165 observation
layout/frame checks and validated 18 saved-state streams plus normal output.
No tolerance was changed and no numerical divergence was found.

Supplemental gates passed default shared and original legacy initialization,
initialization with an unused lookup directory, four user-visible error
contracts, and 150-step (600 s, dt=4 s, +0.25 K) dry/native trajectories.
Both 151-state candidate streams match the frozen executable exactly and
remain finite with nonnegative qt. An initial supplemental test incorrectly
expected a missing lookup path to fail before P3 table loading; it was
interrupted, its source/log retained, and the corrected initialization test
passed. Completed gates were hash-verified on resume. Initial/resumed
execution sources and later tooling are recorded separately.

All four uninstrumented real32/real64 serial/OpenMP compilation/link cases
and empty public-type clients passed. SingleACE probe/single-driver builds,
production/checked multiACE experiment builds and profiler adapter compilation
also passed. These adapter checks do not certify rerun experiment trajectories.
Runtime numerical evidence remains GNU real64/OpenMP32; no real32/serial
runtime, Intel runtime, three-hour rerun or multi-instance acceptance is added.

[Stage-2 results](../../tests/khn26/oop_stage2_results.json) preserve source,
input, compiler, commands, baseline comparisons, raw-artifact/executable/tool
hashes, observation layouts, state diagnostics, supplemental gates, adapter
build checks and limitations. The raw workspace is
`migration_work/fortran_v020_oop_stage2`; the frozen OOP-0 workspace remains
unchanged. Current production source matches the executed candidate snapshot.
OOP-2 is complete; OOP-3a awaits a separate instruction.

## Final reference-history integration decision (2026-10-13)

The developer selected preservation of the OOP reference branch's Git history
after the staged OOP work and its validation. Historical Fortran v0.20
`88e4af5892ec2b93f6bde65fbc11c506276e420f` is already an ancestor of this
branch, joined as the second parent of `d9e8401`. The later reference tip
`b3f922e48e238581a85d31469bafcb800569a748` exists in the local object store
but is not yet an ancestor; it adds 13 reachable commits beyond `88e4af5`.

Keep this history integration separate from OOP implementation stages and
scientific feature ports. At final integration, preserve the reference tip
and its ancestors as a merge parent while retaining the validated ACE tree,
following the earlier history-only `ours` merge approach. Record the pinned
reference, omitted source changes and tree identity explicitly; ancestry
preservation does not claim that every reference algorithm was ported or is
scientifically equivalent. Verify the reference tip is then an ancestor and
that the integration commit's tree matches its ACE first parent's tree.
No source replacement, history rewrite, push or main merge is implied.

The separate `ACE_FORTRAN` checkout currently has local modifications to
`makefile` and `src/test.F`; they are outside the committed reference history
and must remain untouched. They are not included by this decision. The final
history merge has not been executed during this inspection.

## OOP-3a response ownership (2026-10-13)

The developer authorized OOP-3a after commits `dcfbd47` (OOP-2) and `b6f45a3`
(history integration plan). This stage transfers the response context only;
it does not implement OOP-3b integration ownership or the final history merge.

`ace_t` now privately owns an `ace_response_t`. The opaque public context
has private coarse_nz/coarse_ratio, coarse_z/coarse_ze, coarse_F/dwdt,
binary64 packed PMB/PMDv/PMD, slab_geometry, zero_ref_buoyancy, Wbar_eq_zero
and momentum switches. Initial Boolean values match the original module
SAVE defaults; initialization still assigns flags at the original points.
Retained input/coarse-grid conversion arrays from OOP-2 are distinct from
the runtime response grids, preserving their prior lifetime and copy order.

`ace_initialization`, `ace_driver` and the test-exposed `ace_tendency` retain
their original positional arguments and add a trailing optional opaque
response argument. Thin dispatch wrappers select either the supplied context
or a separate `legacy_response` for old procedural test callers. Private
`*_context` implementations require the context explicitly. The model's
initialization passes `self%response`; its transitional callback passes that
same context to the driver and all nine SSPRK tendency stages. The model path
does not allocate or read the legacy response tables. No pointers, aliases to
module tables or passive full-table copies are introduced.

The original PMB input allocation, packing transpose, move_alloc lifetime,
vertical-then-forcing reduction, momentum additions, interpolation branches,
expression grouping and RK/physics/damping sequence remain intact. OpenMP
still uses collapse(2), default(none), static scheduling and the same private
loop/reduction scalars. Its shared list now names the response object instead
of separate global response fields. Automatic tendency workspace dimensions
read the same coarse size through the context. No array order or kind changes.

A source audit removes only context qualification, helper/argument plumbing
and the corresponding OpenMP shared-list spelling, then recovers the three
pre-stage procedure bodies exactly (apart from trailing whitespace). Numerical
regression is still required; this audit alone is not equivalence evidence.

Thermal reference_tv/Ta/q/ql/qi, damping first/damp, P3 directory/wrapper/library
state and the integration clock remain in their OOP-2 owners. The context
is therefore not a multi-model lifecycle guarantee. Continue using one model,
initialized once, per fresh process. The callback's previously documented GNU
executable-stack requirement remains until later driver extraction.

The isolated OOP observer maps original labels/shapes to actual context arrays
and hooks the private implementations, not the dispatch wrappers. A test-only
assertion rejects a model path that allocated legacy PMB. Full raw tables are
still observed once, and all baseline comparison artifacts retain their names.
The observer remains backward-compatible with frozen pre-context sources.

Single/multiACE adapters target the new tendency implementation and forward
initialization options with the explicit model context. Legacy basis capture
writes coarse_F through an isolated module helper, with no production getter.
Profiler anchors follow the context implementation. Standalone performance
kernel generators remove ownership qualification from their extracted test
loop; this does not alter the production kernel or relax their pinned-input
contracts. No new benchmark or optimized production algorithm is introduced.

Use the same candidate, compatibility, analysis and supplemental commands as
OOP-2, with a fresh workspace such as `migration_work/fortran_v020_oop_stage3a`.
The frozen OOP-0 sources/artifacts/executable remain read-only. Record adapter
checks separately from model acceptance. Stop for review after OOP-3a; do not
commit or start OOP-3b automatically.

### Completed OOP-3a gates (2026-10-13)

All 24 candidate model commands passed. Plain/observed neutrality,
production/checked prefix identity and frozen OOP-0 preservation all pass.
All 195 binary artifacts match exactly, including packed/momentum operator
arrays, initialization, all nine raw RK tendencies and response/thermal
observations, native sinks/P3 fluxes, damping, state streams and nine-field
normal output. The isolated ownership assertion passed for every observed
model command: legacy PMB remained unallocated. No tolerance was changed.

Postprocessing passed 165 observation-layout/frame-count checks and validated
18 state streams and normal real32 output. All nine supplemental gates passed:
default shared/legacy/unused-lookup initialization, four error contracts and
150-step (600 s) dry/native state streams. Both 151-state trajectories are
bitwise identical to the versioned-hash-verified frozen executable and contain
finite values with nonnegative qt. The supplemental runner's exact executed
source is snapshotted before launch; no interrupted/resumed run was needed.

All four uninstrumented real32/real64 serial/OpenMP compilation/link cases and
empty public-type clients passed. SingleACE probe/driver and production/checked
multiACE adapter builds passed. The legacy procedural initialization/tendency
capture produces coarse_F identical to the frozen first RK frame; profiler
instrumentation compiled successfully. Legacy initialization also continues
to reject unavailable PMDv/PMD when the corresponding optional switch enables
them. These checks add no benchmark, long-experiment, real32/serial runtime
or multi-instance acceptance.

[Stage-3a results](../../tests/khn26/oop_stage3a_results.json) preserve source,
input, compiler and command provenance, all comparisons, artifact/executable/
runner hashes, ownership assertion scope, source-body audit, supplemental
state validity and adapter/guard evidence. The raw workspace is
`migration_work/fortran_v020_oop_stage3a`. Current production source matches
its executed snapshot; input/interpolation/third-party P3 source is unchanged.
Frozen OOP-0 and completed OOP-2 evidence remains intact.

OOP-3a is complete. OOP-3b integration/cache ownership and the separately
approved final reference-history integration remain later stages. No commit,
push, tag, main merge or reference-history merge was performed in OOP-3a.

## OOP-3b integration ownership (2026-10-13)

The developer authorized this stage by accepting the proposed OOP-3b next
step after OOP-3a commit `1250f98`. This approval covers integration/cache
ownership and its gates; later diagnose/output/cache stages and the final
reference-history integration remain separate review boundaries.

`ace_t` owns a private `ace_thermal_t` (reference_tv/Ta/q/ql/qi), the resolved
precipitation option, dt and persistent t. `model%integrate(te)` calls the
private driver implementation with its own state, response and thermal
contexts. All nine tendency calls and the internal post-RK native helper use
that explicit thermal context. The RK arrays remain automatic with unchanged
shapes and kinds. Cache allocation occurs at the original basis-init points;
initialization-only model Tr/q/ql/qi scratch remains distinct. Stage one still
refreshes thermal fields, stages two through nine reuse them, and native
physics still recomputes them after SSPRK/clipping. No numerical expression,
reduction, interpolation, boundary policy or physics/damping order is changed.

Old procedural driver/initialization/tendency signatures remain available,
including their optional response argument. They always use a separate
legacy thermal context. The old private precip_sinks entry is retained for
actual isolated component probes and dispatches to the same numerical body
with that legacy cache. The model initialization directly selects its own
contexts; no model path allocates or uses legacy response/thermal storage.
A model callback must not call the procedural integrator/tendency: its cache
is now distinct. Existing procedural test callers initialize their own
compatibility path as before.

`test.F` invokes integrate outside validation/serialization callbacks, so
callback array arguments do not overlap a live whole-object integration call.
Its ts/te variables schedule output targets; the model clock advances by the
original full-dt loop. Interval calls explicitly select the optional
`reset_clock_to_target=.true.` to preserve the old caller's `ts=te` assignment.
Standalone calls omit that option and retain accumulated time/overshoot. This
matters even for accepted minute-dividing fractional dt: accumulated rounding
can alter subsequent step counts if the interval reset is omitted. Initial/final writes, steps/interval cadence, state and
nine-field output layouts, freshness checks and CLI errors are preserved.
The callback bridge remains only for validation/serialization until OOP-4.
Its GNU executable-stack requirement remains. Damping SAVE first/damp and
P3 wrapper options/clock/library state are unchanged, so one initialized model
per fresh process remains the supported scope.

Observers qualify thermal fields only in isolated snapshots, retain every
frozen artifact label and assert that both legacy contexts stay unallocated
on the model path. Single/multiACE and common-thermodynamic/component probes
follow the new ownership sites without changing their experiment formulas.
The old frozen-input timing harness remains pinned to its historical source;
its source-hash rejection is retained rather than claiming new performance
acceptance.

Reproduce using fresh candidate workspaces and the pinned OOP-0 artifacts:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline migration_work/fortran_v020_oop_stage0
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
python3 tests/khn26/oop_initialization_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_integration_contract.py NEW_WORKSPACE
```

The integration-contract runner uses only isolated test helpers to inspect
the private clock/cache. With dt=6, each none/native/P3 fresh process advances
to nonaligned targets 1 and 7 (preserving clocks 6 and 12), intersperses past,
repeated and aligned no-op targets, then reaches 18, explicitly resets a
full-dt step to target 19, and continues to 25. It verifies exact no-op
state/cache preservation and five-step identity against the hash-verified
frozen executable. A three-interval native replay with dt=60/13 additionally
checks state and normal-output byte identity, exercising the old interval
clock assignment under fractional rounding. No public clock getter is added.

The first `migration_work/fortran_v020_oop_stage3b` snapshot captured a cache
forwarding defect: all nine driver tendency calls selected legacy_thermal,
which the model intentionally leaves unallocated. Its dry-prefix SIGSEGV and
checked integration-contract failure are preserved with the executed source.
The calls were corrected to forward the driver's explicit thermal argument.
A second snapshot, `migration_work/fortran_v020_oop_stage3b_verified`, correctly
forwarded caches, but was superseded during review when the missing historical
interval clock reset was identified. Its partial runs were stopped and retained.
Final acceptance runs in `migration_work/fortran_v020_oop_stage3b_acceptance`;
source hashes must match the executed snapshot before collecting evidence.
The completed evidence below uses only the final acceptance snapshot. No
automatic commit, next stage, push, tag or history merge is authorized.

### Completed OOP-3b gates (2026-10-13)

All 24 candidate model commands passed: plain/observed neutrality,
checked/production prefix identity and frozen OOP-0 preservation. All 195
binary artifacts match exactly, including response/momentum tables,
initialization, all nine raw RK tendencies and thermal/response observations,
native sinks, P3 fluxes, damping, state streams and nine-field normal output.
The isolated ownership assertions passed for every observed model command:
legacy PMB and all legacy thermal arrays remained unallocated. No numerical
tolerance was changed.

Postprocessing passed 165 observation-layout/frame checks and validated 18
saved-state streams plus normal real32 output. All nine supplemental gates
passed, including default shared/legacy/unused-lookup initialization, four
error contracts and 600 s dry/native comparisons. Each 151-state trajectory
is bitwise identical to the versioned-hash-verified frozen executable, finite
and nonnegative in qt. The three none/native/P3 clock/cache tests passed:
full-dt overshoot, no-op cache/state identity, persistent time and explicit
interval reset all retain baseline behavior. The native dt=60/13 three-minute
CLI replay preserves both state-stream and normal-output bytes exactly.

All four uninstrumented real32/real64 serial/OpenMP compilation/link cases
and empty public-type clients passed. SingleACE component/driver and
production/checked multiACE adapters built successfully; disabled-operator
guards passed. The common-thermodynamic legacy-cache adapter and profiler
instrumentation compiled. Legacy initialization/tendency coarse forcing
matches the frozen first RK frame. Separate fresh-process checked procedural
driver clients for none/native/P3 reproduce all ten saved steps exactly
from hash-verified frozen initial arrays, without rerunning the baseline.
These adapter checks add no long-experiment or performance acceptance.

[Stage-3b results](../../tests/khn26/oop_stage3b_results.json) record source,
input, compiler and command provenance, artifact/executable/runner hashes,
all paired comparisons, ownership assertions, clock/cache/fractional-dt
contracts and compatibility/adapter evidence. Removing only thermal cache
qualification and argument plumbing recovers the prior driver,
initialization, tendency and sink implementation bodies exactly; damping and
P3 wrapper bodies are unchanged. This source audit supplements the numerical
gates. Current production source matches the executed acceptance snapshot;
input/interpolation/third-party P3 source is unchanged. Frozen OOP-0 and
completed OOP-2/OOP-3a evidence remain intact.

OOP-3b is complete. OOP-4a diagnose is the next separate approval boundary.
Damping/P3 state still requires one initialized model per fresh process;
real32/serial evidence remains compilation/linking only. The remaining
output callbacks still require an executable stack with this GNU toolchain.
No commit, push, tag, main merge or reference-history merge was performed.

## OOP-4a observational diagnose (2026-10-13)

The developer authorized OOP-4a after OOP-3b commit `14039c3`. This stage
extracts the existing `test.F` diagnostic calculation only. OOP-4b output
ownership, later lifecycle stages and history integration remain separate
review boundaries.

`ace_t%diagnose()` owns a private `ace_diagnostics_t` with model-kind
Tr/q/ql/qi and explicit real(kind=4) Xout/rh4/b4. Buffers are allocated on the
first diagnosis and completely refreshed on every call. They are distinct
from both initialization scratch and the integrator's thermal context. The
calculation retains the original zero fill, state conversion, vertical-then-
column loop order, native inversion/P3 phase combination, saturation branch,
RH and buoyancy expressions. Gravity retains the identical model-kind
constant already defined in `ace_module`. No physics, integrator, response,
damping or P3 statements are changed.

The optional `diagnose(Xout,rh4,b4)` arguments copy the diagnostic real32
buffers into the existing serializer. Required shapes are (ncols+1,nz,11),
(ncols,nz), and (ncols,nz); any argument may be omitted. No aliases escape.
`test.F` retains output allocation, unit 10, record sizing/bookkeeping,
fresh-file checks and the nine-field write. Its `write_state()` calls diagnose
at exactly the previous initial/interval/final cadence. Normal diagnostic
output no longer uses a whole-model callback; validation and saved-state
callbacks remain. OOP-4b will move serialization and record ownership.

`oop_diagnose_contract.py` inserts private-access helpers only in an isolated
checked build. Its independent oracle is extracted verbatim from the
hash-pinned OOP-0 `test.F`; removing only component qualifications from the
new numerical body must recover that oracle exactly. Runtime comparisons
cover complete Xout (including ghost/unused fields), RH, buoyancy and full-
precision thermal/phase diagnostics; no-argument, all-output and one-output
calls; poisoned diagnostic buffers and repeated refresh; and state, clock,
thermal cache and response work-array byte preservation. At initialization,
uninitialized thermal/response work arrays are seeded only in the test helper
so preservation checks read defined values. Five integrated steps with
interspersed diagnoses must match the frozen executable, independently
checking that those test seeds and diagnoses do not alter integration.

Reproduce in a fresh workspace without modifying frozen baseline artifacts:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline migration_work/fortran_v020_oop_stage0
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
python3 tests/khn26/oop_diagnose_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_integration_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_initialization_contract.py NEW_WORKSPACE
```

Acceptance evidence was collected in
`migration_work/fortran_v020_oop_stage4a`. Stop for review after these gates;
no automatic commit or next stage is authorized.


### Completed OOP-4a gates (2026-10-13)

All 24 candidate model commands passed. All 195 artifacts match frozen OOP-0
exactly, including initialization, response tables, nine RK frames, cache and
physics/damping observations, state streams and nine-field normal output.
Postprocessing passed 165 observation-layout/frame checks and validated 18
state streams and normal real32 output. Observed model paths kept all legacy
response/thermal contexts unallocated. No tolerance was changed.

All three none/native/P3 diagnostic contracts passed: six checkpoints with
three diagnoses each; complete full-precision phase/thermal fields and real32
output match the independent frozen writer; repeated/poisoned-buffer refresh
and optional copies are exact; X/reference/forcing/clock/integrator cache and
response work arrays remain byte-identical across diagnoses. Five steps with
interspersed diagnoses match the hash-verified frozen executable exactly.

All existing integration clock/cache contracts passed, including full-dt
overshoot, no-op targets, explicit interval reset and fractional-dt three-
minute native state/output replay. All nine supplemental initialization/error
contracts passed. Dry/native 600 s comparisons each retain 151 bitwise-
identical, finite saved states with nonnegative qt. All four real32/real64
serial/OpenMP uninstrumented compilation/link cases and empty type clients
passed; numerical runtime acceptance remains GNU real64/OpenMP32.

[Stage-4a results](../../tests/khn26/oop_stage4a_results.json) record executed
source/input/compiler/runner/executable hashes, commands, paired comparisons,
diagnostic oracle and isolated-helper provenance. Removing the diagnostic
type/component/binding/method additions recovers the OOP-3b module exactly.
Reversing the driver diagnostic extraction recovers the prior driver exactly,
including serialization and cadence. Input/interpolation/third-party P3
source is unchanged. Current source matches the executed acceptance snapshot;
frozen OOP-0 and prior stage evidence remain intact. No new adapter experiment,
performance or long scientific experiment acceptance is claimed.

OOP-4a is complete. OOP-4b output ownership is the next separate approval
boundary. Damping/P3 state still requires one initialized model per fresh
process; validation/saved-state callbacks still require the GNU executable
stack. No commit, push, tag, main merge or reference-history merge was performed.


## OOP-4b normal output ownership (2026-10-13)

The developer authorized OOP-4b after OOP-4a commit `a16b22d`.
`ace_t` now owns the output unit, open flag and next record counter.
`open_output(filename)` allocates diagnostic buffers without calculating them,
uses the original nine-field real32 `INQUIRE(IOLENGTH=...)` sizing and opens
an unformatted direct-access `status='new'` file. `NEWUNIT` replaces fixed
unit 10; record numbering still starts at 1. `output()` calls `diagnose()`
once, writes the original ordered field slices and increments the counter
once. `close_output()` closes the owned unit. Close is explicit; reopening a
fresh file resets the record counter and retains model/clock/cache state.
Copying a model with an open output is outside this stage's supported lifecycle.
Already-open and not-open operations are rejected. Existing-file and missing-
directory failures retain the driver's original error message.

The shared private buffer allocation helper contains the unchanged allocation
block from OOP-4a. Diagnosis formulas, kinds, loop order and optional copy
interface are unchanged. The driver retains CLI parsing, output scheduling,
initial/interval/final cadence and comparison state-stream writers (including
the three-integer header, initial reference Tv and binary64 X). It no longer
owns normal-output arrays, record sizing, file unit or serialization.
No initialization, integration, response, damping, native or P3 numerical
statements change. No output header or new field is added to the historical
nine-field format.

`oop_output_contract.py WORKSPACE` extracts the independent diagnostic/write
oracle from the hash-pinned frozen OOP-0 driver. An isolated checked helper
writes three repeated records at each of four checkpoints (0/60/120/180 s),
poisons diagnostic buffers before each write and intersperses diagnoses that
must not consume records. It checks full state/clock/thermal-cache/response-
work preservation around open/write/close, record length/counter, exact
12-record frozen-writer identity, four checkpoint records and saved state
streams against the frozen executable, and a single final record in a
reopened fresh file. Initially undefined scratch is seeded only in the
isolated helper, as in the previous diagnostic contract. Separate failures
check unopened output/close, double open, output after close, existing-file
preservation and missing output directory. Each initialized model runs in a
fresh none/native/P3 process.

Reproduce in a fresh workspace; frozen baseline files remain read-only:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline migration_work/fortran_v020_oop_stage0
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
python3 tests/khn26/oop_output_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_diagnose_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_integration_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_initialization_contract.py NEW_WORKSPACE
```

Acceptance workspace: `migration_work/fortran_v020_oop_stage4b`.
OOP-5a damping, OOP-5b P3 lifecycle and reference-history integration remain
separate review boundaries. Retain one initialized model per fresh process
and the GNU executable-stack restriction of validation/saved-state callbacks.
No automatic commit or next stage is authorized.

### Completed OOP-4b gates (2026-10-13)

All 24 candidate model commands passed. All 195 artifacts match frozen OOP-0
exactly, including initialization/response tables, nine RK frames, cache and
physics/damping observations, comparison state streams and normal output.
Postprocessing passed 165 observation-layout/frame checks and validated 18
state streams and finite nine-field real32 output. No tolerance was changed.

All three none/native/P3 output contracts passed: 12 records per case match
the independent frozen writer exactly; four initial/interior/final records
and three-minute comparison state streams match the hash-pinned frozen
executable. Poisoned diagnostic buffers refresh exactly, intervening diagnoses
do not consume records, and model/clock/integrator-cache/response work remains
byte-identical across open/write/close. Closing and opening a fresh file resets
the counter and produces exactly one final-state record. Six output lifecycle
and fresh-file failure cases passed, preserving existing file contents.

All existing diagnosis and integration clock/cache contracts passed, including
fractional-dt three-minute native state/output replay. All nine supplemental
initialization/error gates passed. Dry/native 600 s comparisons each retain
151 bitwise-identical finite saved states with nonnegative qt. Four real32/
real64 serial/OpenMP uninstrumented compilation/link cases and empty type
clients passed; numerical runtime acceptance remains GNU real64/OpenMP32.

[Stage-4b results](../../tests/khn26/oop_stage4b_results.json) record source,
input/compiler/executable hashes, commands, comparisons, frozen oracle and
isolated-helper provenance. Reversing the output additions and buffer-
allocation extraction recovers the OOP-4a module exactly. Reversing the driver
extraction recovers the prior driver exactly, including output cadence and
comparison state writers. Current source matches the executed acceptance
snapshot; input/interpolation/third-party P3 source and frozen evidence remain
unchanged. No long scientific experiment or performance acceptance is claimed.

OOP-4b is complete. OOP-5a damping cache ownership is the next separate review
boundary. Damping/P3 still requires one initialized model per fresh process;
validation/saved-state callbacks retain the GNU executable-stack restriction.
No commit, push, tag, main merge or reference-history merge was performed.


## OOP-5a model-owned damping cache (2026-10-13)

The developer authorized OOP-5a after OOP-4b commit `bf8de1a`. A private
`ace_damping_t` holds the original model-kind allocatable `damp(:)` and
`first=.true.` flag. Each `ace_t` owns one context; the private integration
and `ImDamp` interfaces receive it explicitly. The public procedural
`ace_driver` retains its signature and uses separate saved `legacy_damping`
storage, with its historical single-context first-use semantics.

`initialize`, `diagnose`, output opening/writing and no-op integration do not
build the damping cache. The first actual end-of-step damping call allocates
it and evaluates the unchanged dt/Ref/grid expression; subsequent calls reuse
it. Constants, expression grouping, k/i/n loop order, prognostic/environment
slices and placement after physics remain unchanged. The existing explicit
`Ref(nz,7)` dummy, versus eight-column integration Ref, is retained; this stage
does not repair that pre-existing interface risk. It currently reads columns
1..3, and checked builds and an independent frozen oracle exercise the same
actual/dummy layout. Reinitializing an existing object or changing dt/grid
in place remains outside the supported lifecycle.

`oop_damping_contract.py WORKSPACE` extracts its oracle verbatim from the
hash-pinned OOP-0 module. Removing context qualification and restoring the
local SAVE declarations must recover the frozen ImDamp exactly. Synthetic
17/29-level, 2/3-ACE contexts with different references and dt=3/5 each perform
five first/subsequent damping calls. Alternating instance states/cache values
must match separate fresh-process oracle runs exactly.

Three two-object native contracts use the full pinned shared input with equal
dt=4, full grids with dt=4/3, and full/cropped grids with dt=4/3. A integrates
once before B initializes; both caches remain live while A and then B continue
to five steps. Both streams must match their own fresh-process frozen
executable references. Assertions check first-use timing, cache preservation,
idle-object state, diagnoses/output/no-op neutrality and unused legacy caches.
The cropped fixture preserves the first 201 fine/100 coarse levels, all 101
ACEs, existing profiles, geometry and sliced response operators. Its derivation
and SHA-256 are recorded. It is a test-only lifecycle fixture, not an accepted
scientific case or a claim that cropping preserves response physics.

The observational regression runner keeps original labels/frame shapes and
now observes explicit damping context values and rejects any model use of
legacy damping. Existing diagnose/output snapshot contracts include damping
allocation flags/cache; integration no-op snapshots also include them. The
current-source profiler adapter adjusts only its damping anchor; historical
stage-budget code remains pinned to preserved sources and is unchanged.

Reproduce in a fresh workspace, preserving frozen baseline files:

```bash
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --candidate-baseline migration_work/fortran_v020_oop_stage0
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --compile-compatibility
python3 tests/khn26/oop_regression.py NEW_WORKSPACE --analyze-existing
python3 tests/khn26/oop_damping_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_diagnose_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_integration_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_output_contract.py NEW_WORKSPACE
python3 tests/khn26/oop_initialization_contract.py NEW_WORKSPACE
```

Acceptance workspace: `migration_work/fortran_v020_oop_stage5a`.
Native sequential-object support is limited to the exercised lifecycle; do
not claim concurrent integration, object reinitialization or mixed P3/native
independence. P3 wrapper/library state and lookup selection remain process-
wide pending OOP-5b; retain one P3 model per fresh process. Validation/saved-
state callbacks still require the GNU executable stack. No automatic commit,
next stage, main merge or reference-history merge is authorized.

### Completed OOP-5a gates (2026-10-13)

All 24 candidate model commands passed; all 195 artifacts match frozen OOP-0
exactly. Postprocessing passed 165 observation-layout/frame checks and validated
18 state streams and finite nine-field output. Raw damping arrays and pre/post-
damping states preserve the original first and subsequent timestep bytes. No
tolerance was changed. Observed model paths leave all legacy response, thermal
and damping storage unused, with legacy damping first-use flag still true.

Both independent synthetic frozen damping oracles passed five calls each,
including different array shapes, height/density references and dt. All three
two-native-instance cases passed (same configuration, different dt, different
grid/dt); both five-step trajectories, stream headers, initial reference Tv
and saved states match their own hash-verified fresh-process frozen references.
First-use timing, idle instance state and retained cache assertions passed.

All existing diagnosis, integration and output contracts passed with damping
flags/allocation/cache included in their observational/no-op snapshots. This
includes fractional-dt three-minute native state/output replay and none/native/
P3 output contracts with six lifecycle/fresh-file error cases. All nine
supplemental initialization/error gates passed; dry/native 600 s each retain
151 bitwise-identical finite saved states with nonnegative qt. Four real32/
real64 serial/OpenMP uninstrumented compilation/link cases and empty clients
passed. Current/previous profiler adapter anchors and compilation passed;
no performance/model profiling run is claimed. Numerical runtime acceptance
remains GNU real64/OpenMP32.

The initial cropped-fixture attempt used NetCDF default chunks [34,34,34,34],
which repeatedly decompressed multiple ACEs for the existing reader. Its fresh
cropped baseline was interrupted with SIGINT; artifacts and attempt status are
preserved in `damping_contract`. The completed damping contract uses separate
`damping_contract_aligned` artifacts and [1,1,100,101] chunks aligned to response/
forcing ACE reads. An independent audit confirms every decoded variable bit,
all attributes and dimensions are identical between the two fixture layouts.
Only the test fixture storage layout changed; the original input and model
reader remain unchanged. Fresh-workspace reproduction uses the repaired layout
by default; `--contract-directory damping_contract_aligned` preserves the
original attempt in this acceptance workspace.

[Stage-5a results](../../tests/khn26/oop_stage5a_results.json) record source,
input/compiler/executable/runner hashes, commands, comparisons, frozen oracle,
fixture derivation/layout audit and isolated helper provenance. Reversing the
damping context/type/qualification changes recovers the OOP-4b module exactly;
the driver, input, interpolation and third-party P3 sources remain identical.
Current source matches the executed snapshot; frozen baseline and prior-stage
evidence remain intact. No long scientific experiment or performance
acceptance is claimed.

OOP-5a is complete. Native sequential-object isolation is validated for the
exercised fixed-configuration lifecycle, with each object initialized once.
Concurrent, reinitialized, copied-live-output and mixed P3/native lifecycle
support is not claimed. Public procedural damping remains singleton. OOP-5b
P3 wrapper/library lifecycle is the next separate review boundary; retain one
P3 model per fresh process. Validation/saved-state callbacks still require
the GNU executable stack. No commit, push, tag, main merge or reference-history
merge was performed.
