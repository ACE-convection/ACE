# KHN26 PMB layout and contraction experiment

Measured 2026-10-05 on `migration/v020-preparation` at `a91ac4e`, in
`migration_work/khn26_basis_layout_full/`. The developer requested separate
MATLAB and Fortran code to investigate efficient Fortran matrix layout.
At the time of the kernel experiment, active model sources and the ongoing
three-hour singleACE run were unchanged. The subsequent production integration
is recorded below.

## Inputs and numerical scope

The basis is the actual KHN26 PMB, 101×101×200×201 in the current Fortran
ordering, 410,080,200 binary64 values (3.2806 GB decimal). Initial forcing
comes from the production `ace_tendency` evaluated on the validated
singleACE initial state: a test-only public-access change exports its
`coarse_F`; equations are unchanged. A fixed signed synthetic forcing is
the second test. Both languages read identical forcing bytes.

[Source and reproduction instructions](../../tests/basis_layout/README.md)
and [the recorded report](../../tests/basis_layout/results.json) preserve
inputs, seed, compiled source/object hashes, compiler commands, MATLAB
version, forcing hashes, timing ranges and numerical checks.

## Recommended layout

Pre-change/input: `P(response_ace, forcing_ace, source_level, response_edge)`.
Experiment: `Q(source_level, forcing_ace, response_edge, response_ace)`.
Conversion is `Q(l,j,k,i)=P(i,j,l,k)`. The source-level index is contiguous
and belongs in the innermost reduction loop. Accumulate source levels
within each forcing ACE, then sum the forcing-ACE partial sums. This keeps
the original nested reduction grouping.

Q also aliases a matrix `C(source,output)` with
`source=l+(j-1)*nsource_level` and `output=k+(i-1)*nresponse_edge`.
Its columns are contiguous source vectors. DGEMV transpose can evaluate
all output dot products without materializing a transposed matrix, but
BLAS/dot reduction order differs from the preserved grouped method.

Only response ACE 1 uses the first 201 columns of C and **all 101 forcing
ACEs**. This does not discard inactive-column forcing, buoyancy mean
removal, compensating MF, or any full-model initialization/interpolation.
The experiment times contraction alone; these other operations are not
implemented by the benchmark.

## Actual-forcing wall-time medians

Three measured repeats after a warmup; seconds per contraction.

| Method | All 101 responses | Only response ACE 1 |
| --- | ---: | ---: |
| Current expression, checked `-O2` | 4.14493 | 0.0413662 |
| Same layout, streaming loop order, checked `-O2` | 1.01574 | 0.0830805 |
| Packed grouped, checked `-O2` | 0.591671 | 0.00586533 |
| Current expression, `-O3` | 4.12835 | 0.0407375 |
| Same layout, streaming loop order, `-O3` | 0.512215 | 0.0510632 |
| Packed grouped, `-O3` | 0.444891 | 0.00437351 |
| Packed BLAS, one thread, `-O3` | 0.267255 | 0.00166784 |
| Packed OpenMP, four requested threads, `-O3` | 0.131268 | 0.00129751 |
| Packed OpenMP, eight requested threads, `-O3` | 0.0678681 | 0.000672972 |
| MATLAB original, max thread setting 1 | 1.94860 | 0.0148270 |
| MATLAB packed matrix, max thread setting 1 | 1.24174 | 0.00863700 |

The checked `-O2` layout change alone yields about 7× in the full kernel;
removing checks and using `-O3` without changing layout barely changes the
legacy result. The combined packed/eight-thread `-O3` case is about 61×
faster than the current checked full kernel. These are not full-model
speedups. Merely moving the response index innermost performs worse for
the one-response case because its source traversal remains strided.

Basis reading took about 13.5 s; full packing about 4.6 s in Fortran.
Keeping both original and packed bases uses about 6.56 GB before other
state/scratch memory. A future single-response implementation could pack
only the 201 required output columns (about 32.5 MB), but that allocation
strategy and its packing time were not measured here.

## Agreement and limits

Across both forcing cases and both response counts, streaming, packed
grouped and packed OpenMP output files are byte-identical to the legacy
Fortran outputs and MATLAB original outputs. BLAS/dot change reduction
order; the largest cross-MATLAB absolute difference across all tested
outputs is 8.674e-17. Every Fortran output satisfies
`128*eps*sum(abs(P*F))` against its legacy build; cross-MATLAB checks use
twice that bound. Selected boundary/interior outputs are also checked
against independent NumPy longdouble sums (64 mantissa bits on this host).
There are 56 Fortran output configurations and 60 cross-MATLAB comparisons.

GNU Fortran is 11.2.0, BLAS is the installed LP64 OpenBLAS 0.3.30 library,
and MATLAB is R2023b Update 9. BLAS uses one thread. OpenMP thread requests
use close/core affinity. Timings are on a shared four-socket Xeon Gold 6248
host while another model job runs; requested/max thread settings do not
measure CPU utilization. Input reading, packing, kernel timing and compiler
flags must be considered separately.

Kernel identity alone does not certify full-model scientific equivalence.
Recommended next step: integrate the packed grouped method into an isolated
singleACE driver, compute only the required response while retaining all
forcing and mean-MF rules, and compare initialization, steps and matched
trajectories against the existing production driver. Add OpenMP as a
separate reviewable step after the serial trajectory is established.

## Production integration

The developer subsequently requested stopping the old run and applying the
validated layout to Fortran. The old singleACE supervisor, Fortran driver and
plot watcher were terminated; outputs were preserved. Its stream contains
24 complete saved states through 1,380 s and an incomplete trailing record.
The incomplete record is excluded from regression comparisons.

`fortran/src/ace_module.F` packs PMB once at initialization, then releases the
input-layout allocation with `move_alloc`. The tendency packs the small forcing
array and evaluates the contiguous grouped kernel with binary64 accumulators.
PMDv/PMD retain their layout and activation policy. All forcing and response
columns remain present, including in the masked singleACE test; this integration
does not implement the one-response shortcut measured above.

Optional OpenMP distributes independent response/edge points with static
scheduling. Without OpenMP compiler flags the same kernel runs serially.
`fortran/makefile` accepts `OPENMP_FLAGS` at compilation and linking, including
when `FCFLAGS` is overridden. Scientific initialization, interpolation, SSPRK,
damping, physics, mean-MF correction and the existing tendency mask are unchanged.
Packing temporarily adds one PMB allocation (3.28 GB for KHN26); PMDv/PMD
allocations remain as before.

`tests/basis_layout/validate_model.py` compares the current module against the
preserved pre-change binaries/output using GNU Fortran 11.2.0, checked `-O2`,
binary64 and no fast-math. Separate serial/OpenMP masked single steps and an
unmasked all-response single step are included. Default-real32 compatibility
is checked by compilation only. This evidence is specific to the KHN26 shared
input and does not certify other compiler/configuration combinations or a full
three-hour trajectory.

The integration regression passed in `migration_work/khn26_packed_model/`.
Serial and eight-thread singleACE single steps, and the all-101-response single
step, are byte-identical to the frozen legacy outputs. All 24 saved trajectory
states (0–1,380 s) are byte-identical across the complete state, including
inactive columns and the environment row. Against matching MATLAB states,
maximum MF/theta_e/qt absolute differences are
`[1.76748e-13, 1.36424e-12, 2.71658e-15]`, below the regression bounds
`[1e-9, 1e-7, 1e-11]`. States are finite, qt is nonnegative, inactive scalar
fields retain their initial values within roundoff, and compensating MF is
equal among inactive columns. The maximum poststep area-mean MF magnitude
is recorded in [the model report](../../tests/basis_layout/model_results.json).
The checked eight-thread 23-minute trajectory took 665.2 s wall time including
initialization and I/O on the shared host; this is not a kernel-only timing.

## Serial production profiling (2026-10-05 local time)

The developer requested profiling after the serial three-hour run progressed
slowly. `perf` and `gdb` were unavailable, so
[`profile_model.py`](../../tests/basis_layout/profile_model.py) instrumented
isolated copies with section wall timers. Active sources and the background
run were unchanged. Two initial-state 4 s steps used checked GNU `-O2`,
real64, no fast-math and no OpenMP, with the same frozen singleACE settings.
Both complete state streams are byte-identical to the validated legacy
single-step output. Source/input/reused-object hashes were rechecked.
The [report](../../tests/basis_layout/profile_results.json) preserves evidence.

Mean integration wall time across the two repeats:

| Section | Seconds per 4 s model step | Share of driver time |
| --- | ---: | ---: |
| PMB contraction (nine stages) | 12.7453 | 99.20% |
| Transport/setup excluding nested thermodynamics | 0.0658 | 0.51% |
| Thermodynamic inversions | 0.0135 | 0.11% |
| Momentum/interpolation/mask | 0.0165 | 0.13% |
| Mean buoyancy and coarsening | 0.00327 | 0.03% |
| Forcing packing | 0.000128 | <0.01% |
| Damping | 0.000299 | <0.01% |
| Complete driver | 12.8481 | 100% |

Other SSPRK/state-update/check/timer overhead accounts for the small remainder.
Initialization separately took 36.5–36.7 s, including about 4.46 s to pack PMB;
it is outside the integration totals and is paid once per run. Native
precipitation is disabled in this case, and P3 is not executed.

The dominant measured cost is therefore the packed PMB contraction, which
still computes all 101 response columns before the singleACE tendency mask.
Average contraction time is about 1.416 s per stage, versus 0.592 s in the
earlier standalone checked packed-grouped benchmark. Different production
code context and shared-host conditions prevent attributing that discrepancy
to bounds checks, vectorization or memory placement without a controlled
comparison. The profiling run temporarily competed with the existing serial
run; initial-state section timings are not a completed trajectory benchmark.

Next, isolate the production contraction and compare compiler/runtime-check
costs with identical inputs and reduction grouping. A one-response shortcut
must retain every forcing column and separately pass model/compensation-MF
regression before use; it is not implemented by this profiling work.

## Controlled compiler/check comparison (2026-10-06 UTC)

The follow-up isolated the exact production PMB loop with its module-global
allocatable arrays and compared it with the same reduction using assumed-shape
array arguments. Both receive packed forcing, compute all 101 responses and
retain scalar vertical-then-forcing grouping. Five flag combinations share
the same packed basis allocation, actual forcing and signed stress forcing.
No OpenMP or fast-math is used; invalid/zero/overflow FPE traps remain enabled
even in the variants without `-fcheck`. Active model sources and the running
serial trajectory were unchanged.

Actual-forcing medians, three repeats after a warmup, seconds per contraction:

| Compiler/check flags | Production module globals | Assumed-shape arguments |
| --- | ---: | ---: |
| `-O2 -fcheck=all,no-array-temps` | 1.40414 | 0.684112 |
| `-O2 -fcheck=bounds` | 1.30940 | 0.466916 |
| `-O2`, without `-fcheck` | 0.416095 | 0.438168 |
| `-O3 -fcheck=all,no-array-temps` | 0.998391 | 0.489075 |
| `-O3`, without `-fcheck` | 0.432022 | 0.428861 |

The checked production kernel reproduces the preceding full-model section
measurement (~1.416 s per stage). Removing bounds checks accounts for most
of its measured overhead: bounds-only retains most of the complete-check
cost, while removing `-fcheck` gives about 3.37× relative to checked `-O2`.
Changing to assumed-shape arguments while retaining complete checks gives
about 2.05× in the isolated test. The comparable unchecked timings suggest
that array access/context interacts with check generation, rather than a
different PMB layout causing the performance gap. Exact attribution to
specific generated instructions still requires assembly analysis.

Compiler reports show the production inner reduction vectorized with 16-byte
vectors in unchecked `-O3`, while checked `-O3` reports control flow and runtime
check calls blocking vectorization. However, unchecked `-O3` is not faster
than unchecked `-O2` here, so SIMD alone does not explain the timing results.

All 60 timed and 20 warmup outputs (two forcing cases, two methods, five
builds) are byte-identical to frozen legacy contraction outputs. The
[comparison script](../../tests/basis_layout/compare_compilers.py) and
[report](../../tests/basis_layout/compiler_results.json) preserve reproduction
and provenance. Shared-host load, concurrent serial integration and the
isolated kernel scope still limit whole-model speed projections.

Recommended next small change: extract the PMB contraction into a private
array-argument routine while retaining checked builds, every response/forcing
column and the original reduction order. Validate serial single steps and
the existing trajectory prefix before measuring the model again. Disabling
model checks or changing response selection is a separate decision; neither
was applied by this investigation.

## One-minute serial production section profile (2026-10-06)

Following the developer's request, the same KHN26 singleACE case was run for
60 simulated seconds using serial production `-O2`, real64, no OpenMP,
no debug checks and no fast-math. Fifteen evolving 4 s SSPRK93 steps contain
135 tendency/PMB evaluations. Dependency objects and input hashes were
verified against the completed 15-minute serial benchmark. Observational
timers were inserted only into isolated module/driver copies; model output
at 0/60 s is byte-identical to the validated serial trajectory prefix.
Provenance was rechecked after completion.

| Exclusive section | Mean ms per full 4 s step | Integration wall share |
| --- | ---: | ---: |
| PMB contraction | 3898.243 | 97.7591% |
| Transport/setup excluding thermodynamics | 55.040 | 1.3803% |
| Momentum/interpolation/mask | 15.239 | 0.3822% |
| Thermodynamic inversions (nested in transport) | 12.932 | 0.3243% |
| Mean buoyancy/coarsening | 3.012 | 0.0755% |
| Other driver/state updates/timer overhead | 2.786 | 0.0699% |
| Damping | 0.256 | 0.0064% |
| Forcing packing | 0.093 | 0.0023% |
| Complete integration | 3987.601 | 100% |

Integration wall time was 59.814016 s, or 3.987601 s/step. One PMB evaluation
averaged 0.433138 s (nine per step). Module initialization separately took
37.875398 s, including 4.542772 s to pack PMB. These initialization timings
must not be added to each-step totals or added together as exclusive costs.
Complete process wall time including initialization/output was 97.785329 s.
Native precipitation is disabled and P3 is not executed in this case.

The [production profile report](../../tests/basis_layout/production_profile_results.json)
records counts, raw cumulative wall times, averages, commands and hashes.
Runtime artifacts and the exact execution-script snapshot are retained in
`migration_work/khn26_serial_profile_1min/`. The 3.9876 s/step average is
close to the preceding 15-minute serial measurement of 4.0950 s/step, but
different host load, evolving duration and instrumentation limit attribution
of their difference. The unchecked production profile still places nearly
all integration time in PMB; this finding is separate from the earlier
checked initial-state profile (12.8481 s/step, 99.2% PMB).
