# Fortran KHN26 alignment and P3 v0.20.0 source

The developer accepted the documented native/P3 three-hour GNU real64 cases
for v0.20.0. [Release notes](../docs/releases/v0.20.0-notes.md) list known
differences, P3 edge-case failures and external-data requirements. Minute
precipitation accumulation is supplied by the diagnostic runner.

On the OOP refactor branch, `ace_t%initialize` owns the initial model state,
reference/profile arrays, geometry and an `ace_response_t` context containing
the coarse grids, packed response tables, work arrays and response flags.
`ace_t%integrate(te)` uses the object's dt, persistent clock, precipitation
option and private thermal cache (reference_tv/Ta/q/ql/qi). RK workspace stays
automatic; cache allocation, stage-one refresh, later-stage reuse and post-RK
native refresh retain the v0.20 sequence. Full-dt target overshoot is preserved.
The interval driver explicitly passes `reset_clock_to_target=.true.` to
preserve its historical `ts=te` assignment, including fractional-dt rounding;
standalone calls retain the accumulated clock.

`ace_t%open_output(filename)` opens a fresh direct-access file with a model-owned
unit and resets its record counter to 1. `ace_t%output()` refreshes diagnostics
and writes one nine-field real32 record; `ace_t%close_output()` closes the file.
Call close explicitly before reopening a fresh file; copying a model while
its output is open is outside the supported lifecycle. Diagnoses alone do not
advance the output counter. Opening an already open object, writing/closing
a closed output, and overwriting existing files are rejected. Diagnostic
buffers allocate on first diagnosis or output opening, without changing
integrator caches.

CLI parsing and output scheduling stay in `test.F`. Validation and saved-state output
borrow the private arrays through the synchronous `with_legacy_state` callback;
integration occurs after callbacks return. Procedural integration/tendency
must not be invoked inside a model callback: old procedural interfaces use a
separate legacy thermal cache, with an optional response argument for existing
test callers. The model uses its own contexts without shared aliases or full
state/table copies. Damping first-use flag/values now belong to the model; its cache is built
at the first end-of-step damping call and reused without changing expressions.
Sequential native objects are checked against fresh-process references,
including different dt/grid. Initialize each object once and keep its dt/grid
fixed. Concurrent integration and general mixed P3/native lifecycle support
are outside the validated scope; one P3 object with sequential native operations
is specifically tested. P3 wrapper directory, first-use flag and iteration counter
now belong to each model. The third-party library retains process-wide tables,
initialization flag and mutable status; it cannot reload options after first
initialization. Only one ACE P3 wrapper context may be used per fresh process,
across both model and procedural API. A second context is rejected before its
library init/main call; the claim lasts until process exit. Copying initialized
P3 models, concurrent P3 use and direct external library initialization are
outside the supported lifecycle. Public procedural calls
retain singleton damping and P3 wrapper contexts with their prior first-use
semantics. `set_p3_lookup_directory` configures only the procedural wrapper;
model options come from `initialize` and are not changed by that setter or
another object's initialization. Each P3 context starts with itt=1, initializes
the library on its first actual P3 step and increments once after field copy.
No-op integration, diagnose and output do not initialize or advance P3.
Initialization scratch, integration caches and model
diagnostic buffers remain distinct. Validation/saved-state callbacks still require
an executable stack under the validated GNU toolchain. See the
[staged OOP plan](../docs/migration/fortran_v020_oop_refactor.md).

`src/test.F` defaults to `../data/input/manaus1342_khn26.nc`. Shared slab
cases use dt=6 s, 360 one-minute output intervals and native precipitation.
The default prognostics are MF/theta_e/qt; the KHN26 saturated +0.25 K bubble
is initialized in ACE 1, levels 11–51, with zero initial MF. Environmental
Tv is reconstructed from theta_e/qt for slab cases.

From `fortran/`, build using the Intel makefile defaults or GNU real64:

```bash
make FC=gfortran \
  FCFLAGS='-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none' \
  FINCLUDE="$(nf-config --fflags)" LDLIBS="$(nf-config --flibs)"
./ace_model.exe --input /absolute/path/to/manaus1342_khn26.nc \
  --physics native --intervals 1 --output /existing/directory/fresh-state.dat
```

`--physics none` disables native precipitation. `--physics p3` selects the
retained eleven-prognostic P3 path and requires external lookup tables via
`--p3-lookup-directory` (default `./input_data/`). P3 remains an additional
Fortran-only scheme, not a KHN26 MATLAB equivalence claim. The source uses
P3 5.3.1 with `p3_lookupTable_1.dat-v6.4-2momI`; known historical P3 failures
remain recorded in [the code review](../docs/migration/v020_code_review.md).

`--dt` overrides the timestep and must divide 60 s for interval output.
`--steps 10 --state-output /fresh/state.bin` runs ten individual steps and
writes binary64 initial/evolved states without the nine-field output.
The stream header is three default integers (ncols,nz,n_prog), followed by
initial X, reference Tv, and saved X arrays in Fortran order. X includes the
extra environmental column (ncols+1,nz,n_prog). Interval runs optionally
write this stream at each saved minute.

For new configurations, use a separate debug build for the first ten
integration steps. After successful checks, rebuild every object in a fresh
production directory without debug flags before starting a long run. For
GNU these debug-only flags are `-g`, `-fcheck=all,no-array-temps`,
`-ffpe-trap=invalid,zero,overflow` and `-fbacktrace`; do not reuse objects
compiled with them in the production build. Retain precision and numerical
optimization settings, and do not add fast-math. For the KHN26 singleACE
timing case, the [timing supervisor](../tests/khn26/README.md) automates the
ten-step debug/production gate and only then launches the serial long run.

`--validate-input /path/dump.bin` initializes then exits. Its four-integer
header is (ncols,nz,n_prog,ncoarse), followed by binary64 X, Ref, A, B, Tv0,
coarse_z and coarse_ze. This layout differs from the v0.18 validation dump.

`--legacy-input` retains original eight-ACE binaries under `./input_data/`,
P3 default, dt=2 s, initial MF pulse and historical 100-day duration.
Schema 1 is still readable; it retains these annular defaults. Schema 2
slab defaults apply even when P3 is explicitly selected. `--intervals`
always overrides duration. Output defaults to `./ace_state.dat`; model and
state output files must be fresh.

The nine-field direct-access output remains real32. Fields are MF, theta_e,
qt, ql, rain, qi, riming, RH and buoyancy for native/none; P3 uses theta and
qv in its second/third slots. Native rain/riming slots are zero. Record sizes
use `INQUIRE(IOLENGTH=...)`. Input/basis are binary64; model precision follows
compiler default real. Real64 numerical checks passed; real32 only compiled,
including the KHN26 finite-difference precipitation derivative.

Missing PMDv/PMD are explicitly disabled placeholders; initialization rejects
attempts to enable them. See the [integration record](../docs/migration/v020_khn26_integration.md),
[shared input](../docs/shared_input.md) and [KHN26 tests](../tests/khn26/README.md)
for evidence and remaining limits. Build different precisions in separate
directories. Use `v0.18.0` for accepted v0.18 tests.

### Reusable interp1

`src/ace_interpolation.F` provides unified vector interpolation supporting
PCHIP and MAKIMA. Both methods use double-precision formulas checked against
MATLAB R2023b. The old PCHIP routine was moved here and its two-point linear
case added. From another Fortran procedure:

```fortran
use ace_interpolation, only: interp1
call interp1(n,x,y,nq,xq,yq,'pchip',extrap=.true.)
call interp1(n,x,y,nq,xq,yq,'makima',extrap=.false.)
```

The optional `extrap` defaults true. False holds the nearest endpoint value
outside the sample interval. The slab model branch uses MAKIMA, annular uses
PCHIP, and both explicitly request extrapolation. Existing public PCHIP and
MAKIMA entries remain available. Arguments use the build's default real kind;
only real64 MATLAB numerical agreement is an acceptance requirement. Real32
compile compatibility is retained. See [interpolation tests](../tests/interpolation/README.md)
and [the dynamics record](../docs/migration/v020_dynamics_alignment.md).

PCHIP uses binary search to locate each query interval. This preserves its
floating-point expressions, endpoint policies and unsorted-query support;
21 before/after test cases are bitwise identical. The recorded
[v0.18 serial timestep timings](../docs/performance/serial_timestep.md) include
packed PMB, binary-search PCHIP and MATLAB default/single-thread comparisons.
Those eight-ACE timings do not predict KHN26 slab performance, whose existing
MAKIMA/direct path is unchanged.

### PMB memory layout and optional OpenMP

Initialization packs PMB from the input order `(response ACE, forcing ACE,
source level, response edge)` into `(source level, forcing ACE, response edge,
response ACE)`. The input layout is released after packing. The dynamics kernel
traverses contiguous source levels and keeps the original vertical-then-forcing
sum order with binary64 accumulators. All forcing and response columns remain
present. PMDv and PMD keep their existing layout and activation policy.

OpenMP distributes independent PMB output points; it does not parallelize the
sum within a point. It is optional: normal builds run the serial kernel. For
Intel, pass `make OPENMP_FLAGS=-qopenmp`; for GNU, add `OPENMP_FLAGS=-fopenmp`
alongside the existing GNU compiler, NetCDF and precision overrides. Set
`OMP_NUM_THREADS=8` at runtime to request eight threads. Rebuild in a separate
build directory when changing flags. Packing temporarily requires one extra
PMB allocation (3.28 GB for KHN26); the persistent basis size is unchanged.

The regression driver compares serial/OpenMP single steps, an all-response
single step, and the complete saved prefix of a frozen legacy singleACE run:

```sh
python3 tests/basis_layout/validate_model.py migration_work/khn26_packed_model --threads 8
```

This requires the preserved pre-change workspace `migration_work/khn26_single_3h`.
Use a fresh output directory. The prefix check also compares against the saved
MATLAB trajectory. See [the layout experiment](../docs/migration/v020_basis_layout.md)
for kernel measurements and their limits.
