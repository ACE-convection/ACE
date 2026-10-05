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
