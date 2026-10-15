# Actual-input NONLOCAL_RESPONSE benchmark

All new code and artifacts for this experiment live in this directory.
Production MATLAB/Fortran files and frozen background simulations are not
modified. No commit, merge, branch switch, or eight-hour run is performed.

The candidate's matrix layout, setup/runtime code, numerical differences,
costs and integration requirements are documented in [PRECOMPUTED.md](PRECOMPUTED.md).

The repository's function is local to `matlab/ace.m`; there is no standalone
production `NONLOCAL_RESPONSE.m`. `Original.m` is an exact extracted body with
only its function name changed. `manifest.json` records production hashes,
the source revision, benchmark hashes, and captured-input hashes.

## Actual case and data

- GOAmazon filtered profile 314, 88 equal-width ACEs, dz 100 m, dt 6 s.
- Current `coarse_z=2` only; both momentum terms and zero-reference buoyancy on.
- Basis MATLAB layout: `[basis_edge,coarse_level,forcing_ACE,response_ACE]`,
  size `[201,200,88,88]`, double, 2,490,470,400 bytes per operator.
- rho0B/F/DHh are 401x88; dz2FH is 400x88. Averaged coefficients are 1x200x88.
- The completed native ten-minute MATLAB trajectory supplies the actual
  t=600 s state. `capture/replay.m` replays one unchanged production timestep,
  observing all nine SSPRK calls before the original local function runs.
  Three prognostics are restored; accumulated precipitation diagnostics are
  zeroed, and do not feed the dynamical/thermodynamic prognostic calculations.
  Every comparison uses these actual inputs, not synthetic forcing.
- All runs explicitly request 32 MATLAB computation threads. No Fortran is
  launched by these benchmarks. Previously authorized background validation
  may compete for resources and is identified as a timing limitation.

## Implementations

`Original.m`: exact baseline arithmetic and `makima`.

`Vectorized.m`: computes small averaged coefficients once and forms the three
products in explicit left-associated temporary assignments. Original vertical
then forcing reduction order is retained, followed by `makima`.

`LoopBased.m`: loops over forcing ACEs, performs each per-level three-term
expression, reduces vertical levels, and accumulates forcing ACE contributions.
This exposes JIT loops but creates slices; rounding could in principle differ
from the built-in forcing reduction and is measured.

`Precomputed.m`: prepares a single fixed matrix with rows `(edge,response)`
and columns `(operator,coarse,forcing)`. Runtime interleaves the three averaged
coefficient arrays, evaluates one matrix-vector product, and retains `makima`.
Area weights are computed once. BLAS changes floating-point reduction grouping,
which is explicitly quantified; mathematical coefficients are unchanged.
`makima` slopes depend on current values and are not precomputed or replaced.

## Measurement

From MATLAB, add this directory to the path and call `run_benchmark` once
after input capture. It requires a fresh `results/` directory. It:

1. Checks all four methods on all nine actual captured stages, after `makima`.
2. Calls `timeit` for each method on captured stage 5, in three forward/reverse
   rounds. Final time is the median of three independent `timeit` estimates.
3. Collects Original Profiler data for all nine captured stages.
4. Separately uses `timeit` for reshape, mean, each product, both sums, and
   `interp1(...,'makima')`. Component timings include materialization and must
   not be summed to predict a compound-expression time.

The predeclared kernel screening limits are max absolute error <=1e-9 and
relative L2 <=1e-10, both over the interpolated outputs. Relative L2 is
`norm(candidate-original)/max(norm(original),realmin)`. Errors in the summary
are maxima over nine captured stages. Passing this screen is not long-run
scientific acceptance.

`run_fullsteps.py` sequentially executes fresh MATLAB processes in order
Original, Precomputed, Precomputed, Original, replaying the same t=600 s native
state for 6 simulated seconds. Both variants perform identical matrix packing
before the integration timer to match setup/memory footprint; packing cost
is reported separately. The candidate replaces only the benchmark copy's
local nonlocal-response function. Three prognostic state fields are checked
against Original with prior short-state limits MF/theta_e/qt <=1e-9/1e-7/1e-11.
The final report distinguishes measured full-step speedup from kernel speedup.

All timeit, profiler, timestep and JSON outputs are retained here. These are
candidate results for developer review; integration into production is pending.
