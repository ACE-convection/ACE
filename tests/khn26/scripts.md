# KHN26 script index

Run scripts from the repository root. NumPy/netCDF4 are required for model
validation; plots additionally require matplotlib. Preparing or launching
model runs requires licensed MATLAB, GNU Fortran/netCDF-Fortran, shared input
data and appropriate CPU availability. Postprocessing requires preserved
raw outputs. These roles describe the existing tools; no numerical algorithm
or original experiment configuration is changed by this documentation.

## Current comparison tools

| Script | Purpose | Inputs / local dependencies |
| --- | --- | --- |
| `compare_multi_prefix.py` | Compare all states in the first three hours; generate spatial MF and error figures | Run configuration and both state streams; `plot_multi.py` |
| `plot_multi_snapshots.py` | Eight paired MF snapshots at 20–160 minutes, 0–20 km, colors −1…1; optionally watch live records | Configuration and state streams; standalone raw-record reader |
| `plot_multi.py` | Spatial and selected-column plots from completed comparisons | State report and MF NPZ; imported by prefix comparison |
| `plot_single_native.py` | Hash-checked native singleACE physical plots | Completed report, state streams, NetCDF; `multi.py`, `run.py` |

For existing outputs and short-test commands, see [README](README.md#native-precipitation-and-three-hour-wave-comparison).

## Model tests and shared launch helpers

| Script | Purpose | Local dependencies |
| --- | --- | --- |
| `multi.py` | Isolated multiACE preparation, dry/native short gates, provenance and stream comparison | `run.py`, `trajectory.py` |
| `single_precip.py` | Native singleACE short gates and optional three-hour continuation | `multi.py`, `run.py` |
| `common_precip.py` | Native thermodynamics and sinks on byte-identical samples from a saved short run | `multi.py`, `run.py`, `trajectory.py` |
| `attribute_ci.py` | Attribute the former Ci formula discrepancy using preserved common-state outputs | `run.py`; postprocessing, not a production correction |
| `full_multi.py` | Validated long-run preparation, frame access and short-prefix checks; its CLI retains 96/32 policy | `multi.py`, `run.py`, `trajectory.py` |
| `unrestricted_single.py` | Native three-hour singleACE, MATLAB defaults / Fortran 32; exports shared MATLAB launch helper | `full_multi.py`, `multi.py`, `run.py` |
| `unrestricted_multi.py` | Original native twelve-hour multiACE launcher, MATLAB defaults / Fortran 32 | `full_multi.py`, `multi.py`, `unrestricted_single.py`, `run.py` |
| `stop_multi_at_three_hours.py` | Preserve raw streams and intentionally stop the original multiACE run at 180 saved minutes | Live status/PIDs; standalone controller |

Some filenames reflect the experiment for which a helper was introduced;
they are not independent versions. In particular, `full_multi.py` and
`unrestricted_single.py` are still imported by the current multiACE launcher.
Their numerical/threading policies must be reviewed before consolidating them.

`unrestricted_single.py` expects the completed gate workspace
`migration_work/khn26_single32_native_ci_3h`.
`unrestricted_multi.py` expects
`migration_work/khn26_multi32_bubble_ci_12h`.
They validate the frozen gate/source hashes. Recreating a short test in another
directory does not automatically substitute it into these launchers.
The stop controller requires a running original supervisor and Fortran output
already beyond minute 180. It intentionally terminates driver processes;
it is not a normal solver completion or a new three-hour launch interface.

## Historical or inactive tools

| Script / group | Status and purpose |
| --- | --- |
| `ci_validation.py` | Former fixed-workspace 32/32 gate/long-run queue; superseded and stopped |
| `full_sequence.py` | Former 96/32 single-three-hour then multi-twelve-hour queue; stopped |
| `stage_budget.py` | Earlier diagnostic instrumentation; not part of the completed native three-hour comparisons and not required by current launchers |
| `benchmark_*`, `profile_*`, `serial_timing.py` | Earlier efficiency work; outside the current scientific comparison workflow |
| `run.py`, `trajectory.py`, `single.py`, `diagnose_single.py`, `plot_single.py`, `review_single.py` | Earlier integration, six-hour and dry singleACE checks; some supply shared helpers |

Keep these files and their original outputs for traceability. Historical queues
use fixed paths and policies; do not launch them as a substitute for the current
workflow. Existing raw workspaces and executed runner copies are preserved.

## Saved evidence

- [Ci source correction and audited constants](../../docs/migration/v020_khn26_constants_audit.md),
  with [versioned validation summary](ci_correction_validation.json).
- [Native singleACE three-hour review](../../docs/migration/v020_khn26_single_native_physical_review.md).
- [Native multiACE three-hour comparison](../../docs/migration/v020_khn26_multiace_three_hour_comparison.md).
- Earlier [multiACE setup/history](../../docs/migration/v020_khn26_multiace_gravity_wave.md)
  and [singleACE precipitation attribution](../../docs/migration/v020_khn26_single_precip_comparison.md).

One-minute saved-state agreement does not establish agreement at every SSPRK
stage, a closed water budget, surface rainfall, or an independent wave-speed
validation. Ten-minute regression limits are unchanged and do not automatically
certify a longer trajectory.
