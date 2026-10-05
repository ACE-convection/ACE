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
