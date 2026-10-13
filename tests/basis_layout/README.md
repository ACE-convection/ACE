# PMB contraction layout experiment

This standalone experiment uses the actual KHN26 101×101×200×201 PMB and
the initial forcing from the singleACE run. It never edits active MATLAB or
Fortran model code. A second
fixed forcing array exercises signed cancellation. Both languages read the
same binary64 forcing bytes.

The operator under test is
`Y(response,edge) = sum_forcingACE(sum_vertical(PMB * F))`.
Fortran retains the full source/forcing domain even when only response ACE 1
is requested. Single-response timing is a contraction microbenchmark, not
an implementation of the full singleACE dynamics, mean-MF projection or
interpolation.

| Method | Layout / reduction |
| --- | --- |
| `legacy` | Pre-change/input `P(response,forcing,vertical,edge)` and nested `sum` |
| `streamed` | Same layout; contiguous response index innermost; preserve vertical-then-forcing grouping |
| `packed_grouped` | `Q(vertical,forcing,edge,response)`; contiguous vertical reduction; preserve grouping |
| `packed_dot` | Alias Q as `C(source,output)`; dot product per output column |
| `packed_blas` | Same C; BLAS DGEMV transpose operation, without a materialized transpose |
| `packed_openmp` | Grouped packed reduction; independent output columns on 1/4/8 threads |

`source = vertical + (forcingACE-1)*nvertical` and
`output = edge + (responseACE-1)*nedge` (one-based indexing). A single
response occupies a contiguous group of `nedge` columns in C; all forcing
columns remain included. The packed matrix requires one basis-sized extra
allocation while the original basis remains present. Read/packing times
are separate from repeated contraction times.

Requirements: NumPy/netCDF4, GNU Fortran/netCDF-Fortran/OpenMP, LP64 BLAS,
licensed MATLAB, shared KHN26 input and completed singleACE smoke states.
Preparation currently reuses compatible real64 objects from
`migration_work/khn26_single_3h/build64`; their hashes are recorded.

```bash
python3 tests/basis_layout/run.py migration_work/khn26_basis_layout_full --prepare
python3 tests/basis_layout/run.py migration_work/khn26_basis_layout_full --fortran
```

Then run MATLAB with the absolute workspace/input paths and the repository
`tests/basis_layout` directory on its path:

```matlab
maxNumCompThreads(1);
reference('/absolute/WORK','/absolute/ACE/data/input/manaus1342_khn26.nc',3);
```

```bash
python3 tests/basis_layout/run.py migration_work/khn26_basis_layout_full --compare
```

Each method has an untimed warmup and three measured wall times; results
are saved to prevent elimination of unused work. Baseline checked `-O2` and
unchecked `-O3` builds are reported separately; neither uses fast-math.
BLAS is fixed to one thread; only the explicitly labelled OpenMP variant
uses 4/8 threads. MATLAB's maximum computational thread setting is recorded.
Thread setting is not a measurement of actual CPU utilization.

Every Fortran result is checked against its build's legacy nested sum with
an absolute bound `128*eps*sum(abs(P*F))`; all outputs are compared with
MATLAB, and selected boundary/interior outputs have an independent NumPy
longdouble check. Exact equality and nonzero roundoff are reported separately.
Dot/BLAS can change reduction order; agreement within these kernel bounds
does not establish scientific equivalence of full trajectories.

Timing occurs on a shared host while another model job is running, without
hardware isolation. Compare medians, account for one-time packing and
memory footprint, and avoid treating these measurements as portable speed
guarantees. `results.json` records source/input/object/forcing hashes,
compiler commands and timing/error evidence.

## Production model regression

`validate_model.py` builds the current production module with serial and
optional OpenMP execution. It enables the existing singleACE mask only in a
test copy, reuses the frozen singleACE driver, and compares against preserved
pre-change binaries and outputs in `migration_work/khn26_single_3h`.
The model still calculates all 101 responses and retains all forcing columns.
It checks binary identity for serial/OpenMP single steps, an unmasked
all-response single step, and all complete saved legacy trajectory records.
Incomplete trailing bytes of the stopped legacy stream are excluded.
Saved MATLAB states are compared at matching times with field tolerances
`[1e-9,1e-7,1e-11]` for MF/theta_e/qt. Finite states, nonnegative qt,
mean-MF correction and inactive-column behavior are also checked.

```sh
python3 tests/basis_layout/validate_model.py migration_work/khn26_packed_model --threads 8
```

Use a fresh output directory; real64 model checks and real32 compile
compatibility are included. This is a trajectory-prefix regression, not a
completed three-hour run. Results and compilation commands are recorded in
`validation_results.json`. `--analyze` repeats saved-state numerical diagnostics
without rebuilding or rerunning the model.

## Serial production section profiling

```sh
python3 tests/basis_layout/profile_model.py migration_work/khn26_serial_profile_sections --repeats 2
```

Use a fresh directory. This builds an isolated singleACE module/driver with
wall timers, using the same checked GNU `-O2` real64 flags as the serial
production regression and no OpenMP flags. Each repeat integrates one 4 s
step with nine SSPRK stages, then checks exact output identity against the
frozen legacy single-step stream. Initialization, initial PMB packing,
tendency sections and damping are recorded. Nested timings (thermodynamics
inside transport, packing inside initialization, tendency inside driver)
must not be added to their enclosing totals.

The [recorded report](profile_results.json) includes commands, source/input/
object hashes, timing counts and binary identity. Two repeats on the shared
host while the three-hour serial run continued place 99.2% of integration
wall time in PMB contraction. These initial-state timings locate the dominant
section; they do not measure long-run efficiency or establish why the
production kernel differs from the earlier standalone benchmark.

## Compiler/check overhead comparison

```sh
python3 tests/basis_layout/compare_compilers.py migration_work/khn26_compiler_profile_packed_forcing --repeats 3
```

Use a fresh directory and retain the earlier kernel workspace containing
`forcing.bin`, `forcing_stress.bin` and frozen legacy contraction outputs.
The experiment extracts the current production PMB loop verbatim into small
modules retaining global allocatable arrays. A second method passes arrays
as assumed-shape arguments and uses the same packed forcing axes, output
grouping and scalar reduction order. Both methods include forcing packing.
Five compiler configurations isolate `-O2`/`-O3`, complete `-fcheck` checks,
bounds-only checks and no `-fcheck`. All retain FPE traps; none enables
OpenMP or fast-math.

PMB is read/packed once and its same allocation is moved between modules.
Each method/build/forcing combination has one warmup and three timed
contractions. All 80 output artifacts must be byte-identical to frozen
legacy results for actual and signed stress forcing. The
[report](compiler_results.json) preserves commands, hashes and timing ranges;
the runtime workspace also retains compiler vectorization reports.
Timings exclude basis initialization, share the host with the serial model
run, and are not full-model acceptance of different compiler flags.

## One-minute serial production profiling

```sh
python3 tests/basis_layout/profile_model.py migration_work/khn26_serial_profile_1min --production --duration 60 --repeats 1
```

Use a fresh directory. This mode verifies and reuses the current serial
production dependency objects/flags from `khn26_single_serial_15min`, then
builds isolated module/driver copies with the existing section timers.
The model advances 60 seconds with `dt=4 s`: 15 full SSPRK93 steps and 135
tendency/PMB calls. There is no OpenMP, fast-math or debug/check overhead.
Output is saved at 0/60 s and must match the validated serial trajectory
prefix byte-for-byte. Initialization and initial PMB packing are separate
from step averages; nested thermodynamics is subtracted from transport
before constructing an additive timing breakdown.

The [production report](production_profile_results.json) records 59.814016 s
of integration, 3.987601 s/step. PMB contributes 3.898243 s/step (97.7591%).
Module initialization took 37.875398 s, including 4.542772 s of PMB packing;
process wall time including initialization/output was 97.785329 s.
The exact execution script is retained as `profile_runner.py` in the runtime
workspace (matching the script hash recorded in the report). Measurements
are one evolving run on shared hardware; timer instrumentation can change
performance. The earlier checked one-step report remains separate.

## Controlled serial memory/SIMD diagnosis

```sh
python3 tests/basis_layout/analyze_serial_simd.py migration_work/khn26_serial_simd_reproduce --repeats 5 --cpu 0
python3 tests/basis_layout/plot_serial_simd.py tests/basis_layout/serial_simd_results.json docs/performance/khn26_serial_simd
```

Use a fresh directory, an allowed CPU, existing full-layout forcing/reference
artifacts and production `ace_input` objects. The process pins CPU placement
before first-touch and shares one packed PMB allocation across all variants.
It compares original O2/O3/native/vectorization-disabled loops, independent
four/eight-output blocking with and without vectorization, and a read-only
checksum diagnostic. Every contraction retains the ordered reductions and
must match frozen legacy output bytes. Rounds are interleaved with reversed
order; the first round is warmup. Kernel timings include forcing packing but
exclude allocation, basis input/packing and binary output.

The [results](serial_simd_results.json) record five measured rounds per
forcing, raw CPU/wall times, exact commands and source/input/reference hashes.
All 96 contraction outputs passed exact identity. O2 actual-forcing median
was 442.033 ms; four/eight-output medians were 268.387/264.314 ms. Disabling
vectorization in the blocked kernels retained the improvement. No production
source or scientific reduction was changed. Kernel-only measurements do not
establish full-model speed or measured hardware bandwidth. See the
[diagnostic discussion and figure](../../docs/performance/khn26_section_profile.md#serial-pmb-memory-and-simd-diagnostic).
Plotting requires matplotlib; PNG/PDF artifacts are generated together.

## Blocked-kernel one-minute model acceptance

```sh
python3 tests/basis_layout/test_blocked_model.py migration_work/khn26_blocked_model_reproduce
```

This sequential experiment profiles unchanged production controls before
and after isolated four/eight-output candidates. All builds use the same
verified production serial O2 flags and dependency objects, without CPU
pinning. Each advances 60 simulated seconds using the original KHN26
configuration: 15 full SSPRK93 steps and 135 PMB calls. Every complete
exported state at 0/60 seconds must match the original 15-minute reference
prefix and all four builds must have the same state hash. Intermediate
steps are not exported. Production sources remain unchanged.

`profile_model.py --production --duration 60 --repeats 1 --output-block 4`
(or `8`) provides an individual candidate run in a fresh workspace.
Default block `1` retains the original loop. Candidate loops are generated
by `analyze_serial_simd.py`; runner/generator snapshots, generated sources,
commands and hashes are retained in each workspace. Section averages are
additive after subtracting nested thermodynamic timings. Initialization is
reported separately. The combined report compares to the previously saved
default MATLAB unsplit profiles; it does not launch MATLAB again.

With matplotlib installed, export the comparison using:

```sh
python3 tests/basis_layout/plot_blocked_model.py tests/basis_layout/blocked_model_results.json docs/performance/khn26_blocked_model
```

## Fifteen-minute blocked-candidate validation

```sh
python3 tests/basis_layout/profile_model.py migration_work/khn26_blocked_model_15min --production --duration 900 --repeats 1 --output-block 4
python3 tests/basis_layout/report_blocked_15min.py migration_work/khn26_blocked_model_15min tests/basis_layout/blocked_15min_results.json --plot docs/performance/khn26_blocked_15min
```

Use a fresh workspace for integration. The four-output serial O2 candidate
advances 225 full steps and performs 2025 PMB evaluations. All 16 complete
minute-spaced output states must match the original serial 15-minute stream
byte-for-byte. The reporting tool verifies original Fortran/MATLAB artifact
hashes, checks finiteness/nonnegative qt, computes per-state cross-language
errors, checks section additivity and reports average time per step/call.
Initialization and initial PMB packing are separate from integration.

Original Fortran and MATLAB total timings come from the earlier
`serial_benchmark_results.json`; neither reference is rerun by this command.
No 15-minute MATLAB section timings are inferred from its one-minute profile.
The new candidate is section-instrumented; reference timings are not.
Numerical acceptance covers saved states, with no three-hour candidate or
independent energy/water-budget validation. Production sources are unchanged.
The optional plot requires matplotlib and produces PNG/PDF artifacts.
