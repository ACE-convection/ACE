# Fortran precipitation precision checks

Run from the repository root with GNU Fortran, netCDF-Fortran (`nf-config`),
Python and numpy. The pinned Manus input must be materialized through Git LFS.
Use a fresh directory:

```bash
python3 tests/precision/run_precipitation.py migration_work/precision_precip
```

The runner builds the accepted `v0.18.0` and current sources with default
real32 and real64 separately. It checks eight fixed thermodynamic states:
zero condensate, small liquid condensate, the ramp threshold, 3 g/kg liquid,
the ice ramp threshold, 3 g/kg ice, mixed phase and 20 g/kg liquid.
The old real32 overflow and zero thermodynamic tendency are recorded as
baseline observations, not failures required of a future baseline.
The corrected builds trap invalid operations, division by zero and overflow,
and check array bounds. Default-real storage size is explicitly checked.

Water sinks are compared with numpy's stable `logaddexp`; thermodynamic
derivatives are compared with centered binary64 differences of the original
Fortran forward `theta_e`. Focused test tolerances check numerical evaluation
of these expressions; they are not atmospheric trajectory acceptance limits.

The runtime test uses the pinned three-hour Manus saturated-bubble seed from
`tests/reference/manus_saturated_bubble_precip/initial_state.bin`:
dt=4 s, output every 60 s, native precipitation, ACE 1 tendencies only,
full eight-ACE geometry/PMB, original damping and MF diffusion disabled.
It runs baseline real64 and corrected real32/real64 and reports all-field
errors, finite states, nonnegative qt and positive precipitation removal.
The seed is read as binary64 and explicitly converted to the model's default
real kind. Input and seed hashes are checked before integration.
`--duration 60` is available for a shorter smoke test; it is not the full
three-hour comparison. A separate 60 s production-driver smoke test uses
native multiACE outer-pulse defaults and checks all nine output fields.

Production numerical routines are used in temporary copies. Test access,
the existing single-ACE tendency mask and precipitation diagnostics are the
only instrumentation. MATLAB is not rerun; this comparison isolates Fortran
precision and the precipitation change. PMB and NetCDF reads remain binary64
as in the existing model; prognostics, thermodynamic work arrays and tendencies
use default real32 in the single-precision build. This is a mixed-precision
model, not a conversion of every stored value to binary32.

`results.json`, `commands.json`, generated source, build/integration logs and
full saved states stay in the ignored run directory. Unweighted precipitation
removal sums are diagnostics, not closed physical water budgets. No P3 scheme
is exercised. The test never updates frozen v0.18 references or release tags.

## Compare MF visually with the original MATLAB run

With matplotlib available, run after the complete three-hour test:

```bash
python3 tests/precision/plot_mf.py migration_work/precision_precip
```

This retains the existing three-panel layout: frozen MATLAB MF, corrected
single-precision Fortran MF, and Fortran-minus-MATLAB. Time is 0–3 h and
height is 0–20 km. The first two panels share a color scale and the difference
panel has its own scale. The script checks reference/input/seed identities
and extracts ACE 1 MF from binary32 output, then saves PNG/PDF and plotting
data/provenance under `<work>/matlab_comparison/`. Existing comparison outputs
are preserved. On the current host, plotting dependencies are available with
`PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib`.

## Twelve-hour multiACE test

Use the preserved, completed MATLAB multiACE reference described in
[`docs/manus208_multi_outer_pulse_12h.md`](../../docs/maintenance/history_summary.md#record-manus208-multi-outer-pulse-12h).
The runner checks its common seed and MF archive against hashes in the
committed report; those full reference artifacts are retained in the ignored
workspace rather than the small frozen single-ACE test reference.

```bash
python3 tests/precision/run_multi.py migration_work/manus_multi_real32
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real32 --layout comparison
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real32
```

The default reference directory is
`migration_work/manus208_multi_outer_pulse_12h`; `--reference` selects an
identical preserved reference elsewhere. The default duration is 43200 s,
dt=4 s and output every 60 s. There is no thermal bubble. Only ACE 8 has
the initial 0.03 kg m-2 s-1 MF pulse over 0–1000 m, and all eight ACEs
evolve with native precipitation and original damping. The same binary64
seed is explicitly converted to binary32. MF diffusion remains disabled.
Production numerical routines are unchanged by this test; temporary access
to the existing tendency mask and sink diagnostics are the only instrumentation.

Invalid/zero/overflow traps and array checks are enabled. The runner checks
finite states and nonnegative qt at every step and verifies the saved
initial state, 721 output times and per-step precipitation diagnostics after
completion. It saves full prognostics, MF comparison data, source snapshots,
hashes and commands. MATLAB is reused from the preserved reference, not rerun.
The combined plot retains eight ACE rows and three columns, 1:5 panel aspect,
per-row MATLAB/Fortran shared scales and independent difference scales.
Append `--analyze-existing` to recheck a completed run without integration.

For a corrected real64 control, use the same runner and a separate directory:

```bash
python3 tests/precision/run_multi.py migration_work/manus_multi_real64 --precision 64
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real64 --layout comparison
python3 tests/precision/compare_multi.py migration_work/manus_multi_real32 \
  migration_work/manus_multi_real64 migration_work/manus_multi_precision_comparison
```

The real64 build adds `-fdefault-real-8 -fdefault-double-8`; case settings,
production sources and diagnostics match real32. It retains the original
binary64 seed exactly. The three-way response plot checks matched source,
input, seed, compiler and output-coordinate identities before overlaying
MATLAB, corrected real64 and corrected real32 max |MF| for each ACE.
