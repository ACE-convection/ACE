# v0.21.87 88-ACE GOAmazon integration

The developer authorized the 88-ACE author basis and GOAmazon sounding,
both momentum switches enabled, current initialization/precipitation policies
and an eight-hour target. Work is on `feature/v02187-basis-goamazon` from
`a0658ec`. No release tag has been created or moved, and no commit is implied.

## Scope and provenance

- Author main: `docs/migration/v02187_author_sources.tar.gz` retains the
  original `ACE_V020_2D88ACEs_NoGlobal.m`; SHA-256 of the uncompressed main is
  `19d0e3da36d8656015aeb724b57225ae54a7bcc498f9ea82febee6be9ba3e2c6`.
- Basis: `data/basis/COMPOSITE_ACE_BASIS_2D.mat`; binary64 PMB/PMDv/PMD,
  MATLAB axes `(201,200,88,88)`, all widths 5 km and 201 edges at 0–40 km.
- Raw sounding: `data/soundings/maoarmbeatmM1.c1.20140101.003000.nc`, copied
  from the preserved ACE_MATLAB inputs. The selection is one-based profile
  314 after the unchanged LOAD_SOUNDINGS filtering, not raw record 314.
- The existing `create_s20_shared_input.m` preprocessing functions match the
  author main; it uses current paired thermo helpers. Runtime initialization
  still inverts theta_e/qt, reconstructs reference Tv and uses the inverted
  temperature for its saturated +0.25 K bubble at levels 11–51.
- Current numerical MATLAB local functions and the reference/bubble block
  remain text-identical to the baseline after line-ending normalization.
  Both languages retain post-dynamics native precipitation and damping.

The shared file `data/input/goamazon314_88aces.nc` and its provenance identify
the exact source hashes. All coefficients were read back against the raw MAT
without rescaling. The first conversion's NetCDF default chunks were replaced
by full vertical chunks for each ACE pair, with exact readback of every
variable. The converter now directly writes that storage layout. The original
conversion is preserved locally as `migration_work/v02187_validation/unpacked_input.nc`.
NC files remain ignored; deliberate LFS distribution or documented regeneration
is needed before publishing. Review the author basis generator and physical
validation separately; array identity is not physical acceptance.

## Enabled DHh exposed a latent unit defect

MATLAB Ai is in km2, Fortran A is in m2. Linear horizontal terms divide by
area and cancel that scale; `DHh=ioflow^2/rho/A` instead scales with area.
The supplied PMD expects the MATLAB native-area convention. A byte-matched
nonzero MF fixture gave matching cross-language tendencies with DHh off,
but substantial differences with DHh on. At coincident basis edges, dividing
the Fortran contribution by 1e6 reduced the discrepancy to about 5.6e-18.
The fine-grid difference cannot simply be scaled afterwards because makima
interpolates the combined response nonlinearly.

The initial validation supervisor was stopped with outputs preserved. The
Fortran DHh forcing is now converted by 1e6 before native PMD contraction.
This is explicitly a scientific bug fix, not a storage/default-only change.
Fresh corrected-unit tests use `migration_work/v02187_validation/native_units`.
The independent oracle derives the native forcing from km2 geometry rather
than copying the Fortran implementation expression.

## Evidence and acceptance

The [validation manifest](v02187_validation.json) contains completed input
readback, old-case preservation, unavailable-operator guards and unit-diagnosis
evidence. The [test architecture](../../tests/slab/README.md) defines component,
short, timestep and gated long-run checks. Initial old-case Fortran ten-step
states are bitwise equal with both switches disabled. The corrected-source ten-step regression also remains bitwise equal.
Corrected DHh/DHv four-mode cross-language tendency checks passed, with
maximum MF tendency error about 3.3e-17. GNU real32 serial compilation/link
also passed; this is not real32 runtime acceptance. Integration gates and
long-run validation remain in progress.

GNU real64 debug and production builds are isolated. All model source
snapshots, executables and inputs are hash-checked before a supervisor runs.
Reports distinguish numerical completion from pending scientific acceptance.
No new P3 eight-hour, real32 runtime, compiler portability or closed physical
budget acceptance is claimed. See [candidate release notes](../releases/v0.21.87-notes.md).

## Developer-authorized momentum storage improvement

After the short four-mode checks passed, the initial Fortran dry run took
about 436 wall seconds for six completed 6 s steps, including startup. The
stored input-layout PMD/PMDv required highly strided accesses. The developer
explicitly selected the proposed storage improvement before implementation.
The slow supervisor was stopped with its raw outputs and twelve complete
per-step water-budget observations retained as a fixed comparison prefix.

The candidate now packs both momentum operators into the PMB source-contiguous
layout. Source-level and forcing-ACE reduction order, separate PMB + PMDv +
PMD additions, precision, units and initialization/physics are preserved.
Only independent output points are distributed across OpenMP threads.
The pre-layout Fortran source/configuration is archived in
`v02187_momentum_layout_reference.tar.gz`. Fresh tests use
`migration_work/v02187_validation/packed_momentum` and require bitwise equality
against the pinned pre-layout artifacts before proceeding to long runs.
The full four-mode component stream, native single-step stream, observational
single-step stream and all four nonzero-MF single-step streams are bitwise
identical. The older Manaus ten-step stream and a separate P3 single-step
stream also match their pre-layout references. GNU real32 serial compilation
and linking pass; real32 runtime remains outside acceptance.

A controlled single native step with eight requested OpenMP threads measured
70.1454 s before packing and 2.04395 s after packing (34.32x observed speedup),
with identical full saved-state SHA-256. Initialization and compilation are
excluded; saved-state I/O is included. This one-step observation is not an
independent repeated timing distribution or a certified long-run speedup.
The pinned twelve-step dry budget prefix and full short/refinement/long-run
checks remain in progress. An independent auditor follows completed jobs.

The packed ten-minute physics-off case passed all eleven cross-language
minute-state comparisons: max absolute MF/theta_e/qt errors are approximately
7.78e-14, 2.96e-12 and 1.68e-16. The independent audit passed normal-output
record counts, finite fields, exact real32 prognostic casts, corrected mean
MF and per-step water bookkeeping. Both the twelve-step budget prefix and
the available binary state prefix match the pre-layout run bit-for-bit.
The associated MF PNG/PDF are in the runtime case's `figures/` directory.
The native ten-minute gate also passed: maximum MF/theta_e/qt discrepancies
are approximately 4.89e-12, 1.89e-10 and 6.45e-15. Its eleven minute states,
normal-output casts and water-bookkeeping checks passed the independent audit.
The dt=3/1.5 s refinement gates and one-hour/eight-hour validation remain pending.

## Thread settings after the current validation suite

The developer subsequently requested stopping the current eight-hour run and
applying MATLAB's default computation-thread setting (without an explicit
`maxNumCompThreads` override) and 32 Fortran OpenMP threads immediately.
The `packed_momentum` supervisor was stopped with reason
`stopped_for_matlab_default_fortran32`; all completed gates and partial
eight-hour outputs are retained. Its frozen eight-thread configuration remains
unchanged. The updated harness uses a fresh `matlab_default_fortran32` workspace
and records MATLAB's reported computation-thread limit in each job log.
Subsequent runs must record
their separate MATLAB and Fortran settings; existing eight-thread timings do
not establish performance under the requested settings.

### Thread slowdown investigation (runs stopped)

The developer requested stopping the new suite during `dry_10min` to investigate
slowdown. Stop reason: `investigate_matlab_thread_slowdown`. Fortran completed
600 s; MATLAB reached 120 s in its log. Full validation remains stopped.
Both workspaces have identical MATLAB source hashes and shared-input hash.
Observed MATLAB ODE timer seconds (startup/input loading excluded):

| Case | 8-thread suite | Default 80-thread suite |
| --- | ---: | ---: |
| Native single step | 4.1865 | 30.6523 |
| Physics-off, h0v0 | 3.4125 | 2.5431 |
| Physics-off, h1v0 | 3.6875 | 15.9023 |
| Physics-off, h0v1 | 3.6728 | 18.6713 |
| Physics-off, h1v1 | 3.8638 | 26.1768 |

These are historical single observations, not controlled repeated benchmarks:
Fortran concurrency and thread environment also changed. Slowdown correlates
with enabling the large momentum operators. `NONLOCAL_RESPONSE` multiplies
and sums three 201x200x88x88 double operators (about 2.49 GB each), with large
intermediates. Memory bandwidth, thread synchronization and cross-socket NUMA
traffic are candidate causes, not measured root causes. The host exposes four
20-core sockets (80 physical cores, 160 logical CPUs). Isolated repeated MATLAB
thread-count benchmarks and profiling should precede choosing settings or
changing numerical code.

The developer clarified that MATLAB must inherit its environment unchanged,
without setting or clearing thread variables or calling `maxNumCompThreads`.
A MATLAB-only native single-step test using this policy completed in
`matlab_inherited_environment_smoke`: ODE wall time 30.403 s for 6 simulated
seconds, versus historical 4.1865 s with eight threads and 30.6523 s with the
previous default-thread harness. Saved states are bitwise identical to both
earlier MATLAB smoke streams and all fields are finite, with nonnegative qt.
This isolated observation shows the slowdown persists without a concurrent
Fortran run; it does not measure the individual bandwidth/NUMA/thread overhead
contributions. Full validation remains stopped.

A subsequent MATLAB-only integration profiler run in
`matlab_inherited_environment_profile` completed the same 6 simulated seconds
in 28.6351 wall seconds. `NONLOCAL_RESPONSE` was called nine times and accounted
for 27.2327 of 28.6312 profiled integration seconds (95.1%); `microrad` accounted
for 1.0843 seconds. Saved states are bitwise identical to the unprofiled run.
The hotspot is the compound three-operator multiply/add/reduction expression;
line timings on that expression do not isolate individual operator costs.
The profiler identifies the hotspot but cannot distinguish bandwidth, NUMA,
and synchronization costs. No numerical expression or thread setting was
changed; no long integration was restarted.

The isolated `tests/slab/benchmark_basis.m` fixture subsequently ran three
trials with nonzero synthetic coarse forcings and unchanged inherited MATLAB
thread environment, without Fortran. It loads the actual three operators and
compares the original compound contraction with separately timed products,
left-associated additions and vertical-then-forcing sums. All three outputs
match exactly. Reports are under `matlab_basis_kernel_default`.
The compound contraction took 3.2906, 4.3597 and 3.9205 s. Median separate
operation times were: PMB product 0.0369 s (first trial 0.7160 s), PMDv product
1.6348 s, PMD product 1.6413 s, additions 0.0482 and 0.0378 s, vertical sum
0.0145 s and forcing sum 0.0009 s. These timings include allocation and are
sensitive to JIT, repeated invariant operands, cache and memory placement;
separate medians must not be interpreted as a decomposition of the compound
median. The diagnostic points toward the large momentum products rather than
the final reductions, but does not prove a bandwidth/NUMA/synchronization root
cause or validate a model optimization. No model numerical code was changed.

The follow-up thread comparison varied synthetic forcings between trials to
avoid invariant-product timing. One MATLAB session ran the inherited default
first (reported 80), then explicit benchmark-only 8, 16 and 32 thread limits,
three trials per group, with no concurrent Fortran. Median original compound
contraction seconds were 3.739241, 0.290183, 0.199725 and 0.170903 respectively.
Every output is bitwise identical across thread groups for all three forcings.
`basis_thread_comparison.json` records samples, comparisons and benchmark hash.
The order is not randomized and each group reloads the operators; allocation,
memory placement and system load remain confounders. This supports thread-count
sensitivity of the hotspot but is not a full-step or eight-hour speedup result.
32 was fastest among these tested settings; it is not an established global
optimum. The production/default MATLAB policy has not been changed.

The extended comparison (`basis_threads_extended`) uses fresh MATLAB processes
in order default, 64, 32, 80, 80, 32, 64, default, three trials per process.
Each default process inherits its environment without a thread setter and
reports 80; explicit settings apply only to benchmark processes. Median
compound kernel seconds over six samples per setting:

| Setting | Median seconds |
| --- | ---: |
| Inherited default (reported 80) | 3.9462985 |
| Explicit 32 | 0.1871405 |
| Explicit 64 | 2.0865875 |
| Explicit 80 | 3.9436245 |

All kernel outputs match bitwise across settings. The reversed process blocks
support the same trend as the initial comparison; default and explicit 80 have
similar observed medians. Follow-up native complete single steps (6 simulated
seconds, no Fortran) took 28.5230 ODE wall seconds with inherited defaults and
2.6231 seconds with explicit 32, an observed 10.87x ratio. Both complete state
streams match the earlier default single step bit-for-bit. These complete-step
timings exclude initialization and are single observations, not a production
long-run guarantee. 32 is fastest among tested settings; this does not isolate
the bandwidth/NUMA/synchronization root cause. The new sequential harness is
`tests/slab/benchmark_threads.py`. Full validation remains stopped, and no
production MATLAB thread policy or numerical algorithm was changed.

After reviewing these measurements, the developer explicitly selected 32
threads for both MATLAB and Fortran for subsequent runs. The validation harness
now sets MATLAB `maxNumCompThreads(32)` and Fortran OpenMP thread count/limit 32.
MATLAB inherits the parent's thread environment, with case-specific ACE controls
set separately; it does not inherit the harness's Fortran-only OpenMP/BLAS
overrides. New validation uses the fresh `threads32` workspace, repeating
short/refinement gates before one-hour and eight-hour integration. Earlier
workspaces and their stopped partial outputs remain unchanged.

The developer then requested background native ten-minute and one-hour cases
in parallel, with an explicit report/decision point before any eight-hour run.
The sequential `threads32 --long` supervisor was stopped with reason
`parallel_10min_1h_no_8h`, preserving its partial gates. The separate
`parallel32_10min_1h` supervisor uses the frozen 32/32 sources and executables,
independent case directories/status files, and audits each completed case.
`tests/slab/run_parallel_cases.py` has no eight-hour execution path. Its final
status is `completed_awaiting_8h_decision` if both cases and audits succeed.
Each native case runs one MATLAB and one Fortran process (four model processes
while cases overlap); elapsed timings include resource competition. The current
32-thread timestep-refinement suite has not completed; older eight-thread
refinement evidence remains available but is not relabeled as a 32-thread run.

The parallel 32/32 native ten-minute case completed and passed the independent
audit. All eleven states are finite, qt is nonnegative, the per-step inventory
bookkeeping is continuous, and all eleven Fortran normal-output records are
finite with exact real32 prognostic casts. Maximum cross-language MF/theta_e/qt
errors are 4.8901e-12, 1.8929e-10 and 6.4514e-15, below the predeclared short
limits 1e-9, 1e-7 and 1e-11. MATLAB/Fortran state streams, reference Tv, both
budget streams and Fortran `fields.dat` each match the prior eight-thread
native ten-minute case bit-for-bit. This is a record-consistency audit, not
independent proof of physical conservation or full scientific acceptance.
The one-hour case continues; eight-hour execution still awaits the developer.

## MATLAB optimization prototypes during background validation

The developer authorized code optimization while the frozen one-hour case
continued. Test-only kernels partitioned independent response ACEs, retaining
the vertical-then-forcing sums and PMB + PMDv + PMD grouping. Block sizes
1/4/8/16 all matched exactly, but slicing the large operators each call was
substantially slower. Prepacked block 16 appeared promising in a first fixed
order sweep; an eight-trial alternating-order comparison did not confirm it
(candidate slower in seven trials). It is not adopted in the active model.

A separate test-only matrix-vector prototype packs response/edge rows into
BLAS matrices. It changes floating-point reduction grouping and was explicitly
treated as requiring scientific review before adoption. The eight paired
synthetic-kernel trials showed no stable speedup and maximum absolute rounding
difference about 3.1e-10 (synthetic forcing units, not a trajectory error).
It is also not adopted. Timing includes competition from background validation.
Results and source hashes are retained in
`migration_work/v02187_validation/matlab_optimization_review.json`, with raw
reports under `basis_blocks32`, `basis_packed16_paired32`, and `basis_matrix32`.
The three `tests/slab/benchmark_basis_*.m` prototypes do not change production
algorithms, frozen inputs or running executables. This investigation has not
established an additional production speedup beyond the selected 32 threads.

## Authorized eight-hour validation

After both parallel 32/32 native cases completed and passed independent audits,
the developer explicitly authorized background eight-hour integration. The new
`native8h_threads32` workspace reuses the frozen `threads32` source/builds,
without any Precomputed MATLAB prototype. `tests/slab/run_eight_hour.py` checks
the completed ten-minute/one-hour audit prerequisites, launches the isolated
supervisor, compares 481 minute states and audits complete outputs at the end.
Both MATLAB and Fortran use 32 threads, dt 6 s and 28,800 simulated seconds.
Completion remains distinct from scientific release acceptance. Earlier
records stating that eight-hour authorization was pending describe the prior
decision point; this explicit authorization supersedes them for this run.

The authorized 32/32 eight-hour case has completed: both models reached
4,800 steps / 28,800 simulated seconds and saved 481 minute states.
Approximate process elapsed times, from job launch metadata to final log
writes, were MATLAB 24,348 s (6 h 45 min 48 s) and Fortran 12,507 s
(3 h 28 min 27 s); initialization is included. The Fortran `cpu_time` log
is aggregate CPU time and must not be interpreted as wall elapsed time.
Independent output auditing passed finite fields, nonnegative qt, inventory
record continuity and the Fortran normal-output checks. Full-period maximum
MATLAB/Fortran MF/theta_e/qt differences are 3.1392e-8 / 3.1643e-7 / 7.5393e-11;
final-state differences are 8.1825e-9 / 3.7785e-8 / 1.5890e-11. Long-run errors
are reported metrics without an invented acceptance tolerance. Scientific
acceptance and physical budget review remain pending; no release tag is made.

## Developer release acceptance (2026-10-15)

After reviewing the eight-hour results and the MF/gravity-wave PNGs, the
developer judged this milestone ready for release, then explicitly authorized
commit, merge into `main`, and tag `v0.21.87`. This dated decision supersedes
the earlier pending-scientific-review statements for the tested native case;
raw numerical reports retain their original machine-generated status fields.
The accepted scope is the original 32-thread MATLAB/Fortran 88-ACE GOAmazon314
native eight-hour configuration, including the documented DHh unit correction
and Fortran layout improvement. P3 long-run behavior, real32 runtime, other
compilers, closed physical budgets and complete eight-hour MATLAB normal
postprocessing are not newly accepted. Precomputed remains unintegrated.
Release notes are in `docs/releases/v0.21.87-notes.md`; copies of the reviewed
PNGs are in `docs/figures/v02187`. The unrelated v0.24.87 reviews/specification
are not part of this release commit.

Before committing, release preparation found the shared NC was
5,667,681,931 bytes, above GitHub's per-file LFS maximum. The supplied basis,
raw sounding and exact validated NC are therefore distributed as 12 <=1 GiB
LFS parts under `data/distribution/v02187`, with ordered part/full SHA-256
manifest and `tools/input/materialize_v02187_inputs.py`. The existing runtime
files are preserved and ignored; reconstruction restores the same paths and
must reproduce the validated hashes. This is byte packaging, without numerical
conversion or changed source algorithms. Release notes describe materialization.

## Basis policy and authorized history cleanup

After the initial release refs were pushed, the developer required v0.21 and
later basis/operator payloads to remain local-only and explicitly authorized
cleaning existing history back to the v0.20.87 boundary. The replacement release
commits exclude the five supplied-basis parts and six shared-NetCDF parts.
Local payloads remain intact and ignored. Source, validated trajectories,
figures, provenance hashes and benchmark-only work remain preserved; all
v0.20.87-and-earlier history is unchanged. The v0.21.87 refs must point to the
replacement commits, using lease-protected remote updates. A private ignored
bundle preserves the superseded local commits for recovery. Ref rewriting
does not itself delete objects already stored in a server LFS store or cache.
No further basis/LFS upload is authorized or required for this cleanup.
