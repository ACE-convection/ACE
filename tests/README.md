# ACE reference tests

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
operates on `matlab/active/` and `fortran/active/`; adapters for later
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
