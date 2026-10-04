# ACE reference tests

On the v0.20 development branch, active sources have been replaced by the
historical S20/P3 imports. The runners below were written for v0.18 and have
not been adapted or run against these new sources. Use a separate checkout
of `v0.18.0` to reproduce the accepted cases. The
[integration record](../docs/migration/v020_source_integration.md) tracks
deferred input adapters, basis confirmation and testing.

For the independently runnable v0.20 interp1 comparison (PCHIP/MAKIMA,
MATLAB versus production Fortran real64, without basis/model integration), see
[interpolation tests](interpolation/README.md). The recorded checks pass.

For default-real32 Fortran precipitation checks and their real64 comparison,
see [precision tests](precision/README.md). These retain the frozen v0.18
reference cases and document the subsequent precipitation evaluation change.

The canonical initial runtime comparison for v0.18, v0.20 and v0.24 is
**`manus_saturated_bubble`**, designated by the developer on 2026-10-02.
Its fixed definition is [`cases/manus_saturated_bubble.json`](cases/manus_saturated_bubble.json);
the completed v0.18 reference is documented in
[the Manus report](../docs/manus208_single_saturated_bubble_3h.md).

## Fixed case contract

Use Manus profile 208; ACE 1; levels 11–51 with +1 K saturation and zero
explicit initial condensate; precipitation disabled; dt=4 s; SSPRK93;
3 hours; output every minute. Preserve the eight-ACE geometry/full PMB,
the existing single-ACE tendency mask, initial 0.03 kg m-2 s-1 MF pulse,
50 m vertical grid, MF diffusion off and damping. Initialization follows
the original MATLAB `T_zm`/`p_mf` convention and supplies the same
theta_e/qt/MF input to both implementations.

Initial v0.20/v0.24 comparisons must use this same sounding, bubble,
physics switches, timing, geometry and output coordinates. Record the tested
revision, tool versions and any version-specific adapter. The current runner
operates on `matlab/` and `fortran/`; adapters for later
snapshots remain future work. Do not silently change the case to match
different defaults or treat this initial test as full scientific validation.

## Run and plot

Requirements: MATLAB with a license/writable preferences, GNU Fortran,
netCDF-Fortran (`nf-config`), Python numpy/netCDF4 and matplotlib for plots.
Obtain the pinned input through Git LFS:

```bash
git lfs pull --include=data/input/manus208.nc
python3 tests/alignment/run_reference_case.py --check-only
python3 tests/alignment/run_reference_case.py migration_work/manus_reference
python3 tests/alignment/plot_mf.py migration_work/manus_reference
```

Use a fresh output directory. The canonical entry checks input/reference
hashes and runs explicit fixed settings, independent of the exploratory
runner's defaults. It writes reference comparison metrics and never updates
the archived baseline automatically.
To validate a preserved completed run without repeating integration, use
`python3 tests/alignment/run_reference_case.py <run-directory> --verify-run`.

## Reference evidence and evaluation

[`reference/manus_saturated_bubble/`](reference/manus_saturated_bubble/)
contains complete ACE 1 time/height MF arrays (`mf.npz`), original
metadata/metrics/source and artifact hashes (`results.json`), and the bubble
initialization check. Reference revision is recorded in the case definition.
`initial_state.bin` preserves the common initial theta_e/qt/MF seed as
little-endian binary64 with Fortran-order shape (8 ACEs, 801 levels, 3 variables).
Original absolute paths identify the execution host; archived arrays are
portable. Full eight-ACE histories, generated sources and logs remain in
the original ignored workspace.

The input uses the existing `data/**` Git LFS policy. The small compressed
MF reference is stored with the test suite; reference
[PNG](../docs/figures/manus_saturated_bubble_mf.png) and
[PDF](../docs/figures/manus_saturated_bubble_mf.pdf) are also archived.

Require completion to 10800 s with finite states, consistent settings,
nonnegative saved total water and verified bubble initialization. Report
MF errors/norms and compare evolution/physical interpretation. **Do not
require byte equality.** No numerical acceptance tolerance is prescribed;
the measured v0.18 differences are observations, not thresholds to impose
on v0.20/v0.24. Additional scientific, budget and physics tests are needed.

## Additional precipitation-enabled Manus case

`manus_saturated_bubble_precip` adds the native precipitation scheme to the
same fixed Manus sounding, saturated bubble, common initial state and timing.
The original precipitation-disabled case remains the default. The fixed
definition is [`cases/manus_saturated_bubble_precip.json`](cases/manus_saturated_bubble_precip.json);
see [the completed three-hour report](../docs/manus208_single_saturated_bubble_precip_3h.md).

```bash
python3 tests/alignment/run_reference_case.py --case manus_saturated_bubble_precip --check-only
python3 tests/alignment/run_reference_case.py migration_work/manus_precip_reference --case manus_saturated_bubble_precip
python3 tests/alignment/plot_mf.py migration_work/manus_precip_reference
```

For an existing completed run, append `--verify-run` to the second command.
The precipitation reference archives MF arrays, metadata, initialization
evidence, and `precipitation.npz`: MATLAB's saved cumulative qt sink and
Fortran's per-step sink diagnostics (time, sum, maximum and minimum qt removal).
Require finite, nonnegative Fortran sinks with positive total removal, and a
finite MATLAB accumulation starting at zero, increasing monotonically and
ending positive, in addition to the existing execution checks.

Both codes retain their native post-dynamics precipitation masks: MATLAB
masks prognostic sinks in the top eleven levels and masks all precipitation
slots in ACEs 2–8; Fortran applies precipitation across all levels and ACEs.
The single-ACE mask applies to dynamics in Fortran. No precipitation formula,
mask, constant or phase selection is changed for this test. Passing the
execution checks does not settle these differences or establish a closed
water budget or scientific equivalence. Later-version adapters remain future work.

## MultiACE outer-pulse experiment (12 hours)

The developer-selected multiACE test perturbs the outermost ACE 8 using
the existing initial MF pulse, `0.03*sin(pi*z/1000)` kg m-2 s-1 at 0–1000 m.
All eight ACEs evolve with the full geometry/PMB. Use Manus 208, no thermal
bubble, native precipitation, no sustained external forcing, original
damping, MF diffusion disabled, dt=4 s and output every 60 s. The exploratory
duration is 43200 s to capture the later inner-ACE response.

```bash
python3 tests/alignment/run_sounding_case.py migration_work/manus_multi_repeat \
  --input data/input/manus208.nc --mode multi --precipitation --duration 43200
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_repeat
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_repeat --layout comparison
```

Use a fresh directory. The runner exports one common initial state from
MATLAB for both implementations. It checks finite outputs, nonnegative
saved total water, matching initial states, an outer-only initial MF pulse,
and active precipitation. Default mode remains `single`; adding `--mode multi`
enables all ACE tendencies and moves the pulse to ACE 8.

`mf_all_aces.npz` preserves both full 0–40 km MF histories with shape
(time, level, ACE). `results.json` reports all-field errors, per-ACE MF errors,
and hourly max |MF|. The plotter writes MATLAB, Fortran, difference, and
per-ACE response figures; time-height plots default to 0–20 km and share
the same MF scale. Native physics/masks remain unchanged. The existing
`mf.npz` output still contains ACE 1, for compatibility with single-ACE tools.
For preserved outputs, append `--analyze-existing` to the integration command.

`--layout comparison` writes a combined eight-row, three-column time-height
figure: ACEs 1–8 from top to bottom, MATLAB/Fortran/Fortran-minus-MATLAB
from left to right. Each panel's height is one fifth of its width. Each row
uses a shared MATLAB/Fortran color scale and an independent difference scale;
color scales vary between ACE rows.

See the [completed 12-hour report](../docs/manus208_multi_outer_pulse_12h.md).
This trial does not set a numerical acceptance tolerance or automatically
replace the frozen single-ACE reference cases.

## Source normalization verification

For source-path-only changes, compare a completed run with its preserved
pre-change run using:

```bash
python3 tests/alignment/verify_source_normalization.py <previous-run> <current-run> \
  --output <comparison.json>
```

This checks identical case settings and exact equality of every saved MATLAB
variable, all three Fortran prognostic fields across all ACEs, and native
Fortran precipitation diagnostics when enabled. Exact equality here verifies
that directory changes preserve each implementation's results; it does not
set a cross-implementation or later-version scientific tolerance. Source,
input, command and artifact provenance are saved in the comparison record.
