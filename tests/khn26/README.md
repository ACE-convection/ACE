# KHN26 actual-basis checks

The v0.21.87 candidate uses a different 88-ACE GOAmazon case; its current
workflow is [the slab suite](../slab/README.md). The commands below target
the preserved 101-ACE Manaus baseline. Use the `v0.20.87` checkout for its
original runners/defaults; many runners pin that case's dimensions and source
anchors and are not generic launchers for the new case.

These checks cover the author-selected 101-ACE 4UNEVEN basis and processed
Manaus profile 1342. Requirements: licensed MATLAB (tested R2023b), GNU
Fortran/netCDF-Fortran (`nf-config`), Python NumPy/netCDF4, generated
`data/input/manaus1342_khn26.nc` and original source data matching its hashes.
Current native three-hour results and commands are in
[the comparison workflow](#native-precipitation-and-three-hour-wave-comparison);
[the script index](scripts.md) distinguishes current tools from historical
queues and performance utilities.

See [shared input conversion](../../docs/shared_input.md). Runtime files
are ignored; use a fresh workspace. Test preparation verifies original data
hashes and compiles real64/real32 separately with bounds/FPE checks.

```bash
python3 tests/khn26/run.py migration_work/khn26_check --prepare
```

Preparation creates `probe.m` with the production driver's local numerical
functions and `original_main.m` from the pinned source archive. The latter
changes only data/source paths, duration (6 s) and output instrumentation.
Run both with the absolute workspace and shared file paths:

```matlab
work='/absolute/path/to/ACE/migration_work/khn26_check';
addpath(work);
probe(work,'/absolute/path/to/ACE/data/input/manaus1342_khn26.nc');
run(fullfile(work,'original_main.m'));
```

```bash
python3 tests/khn26/run.py migration_work/khn26_check --fortran --compare --guards
```

Comparison checks exact original/shared MATLAB initial/one-step/reference-Tv
identity, real64 Fortran native/physics-off initial/one-step states, a
nonzero-MF transport tendency and step, 406 inversions and eight native
precipitation cases. The high-condensate historical MATLAB overflow is
recorded and compared to a stable logaddexp water oracle with independently
computed MATLAB forward theta_e finite differences. Dry, liquid, ice and
mixed states are covered. Production routines are exposed in a test-only
module; production access permissions are unchanged. Guards test rejection
of both marked momentum operators through the production initializer.

For a production ten-step smoke run, clear initialization mode and use a
fresh NetCDF output, then export prognostic states:

```matlab
setenv('ACE_VALIDATE_INPUT','');
setenv('ACE_INPUT_MODE','shared'); setenv('ACE_PHYSICS','native');
setenv('ACE_INPUT_FILE','/absolute/path/to/ACE/data/input/manaus1342_khn26.nc');
setenv('ACE_STEPS','10'); setenv('ACE_OUTPUT_FILE',fullfile(work,'smoke60.nc'));
run('/absolute/path/to/ACE/matlab/ace.m');
fid=fopen(fullfile(work,'matlab_smoke60.bin'),'w');
for step=1:11
    v=permute(X(:,[3,1,2],:,step),[3,1,2]); fwrite(fid,v(:),'double');
end
fclose(fid);
```

```bash
migration_work/khn26_check/build64/ace_model.exe \
  --input data/input/manaus1342_khn26.nc --physics native --steps 10 \
  --state-output migration_work/khn26_check/fortran_smoke60.bin
python3 tests/khn26/run.py migration_work/khn26_check --compare-smoke
```

Errors use field-specific absolute thresholds, with finite-state and
nonnegative-water checks. The smoke comparison also checks output provenance.
Preserve `configuration.json`, results, logs and binary dumps with a run.
Reported evidence is in [the integration record](../../docs/migration/v020_khn26_integration.md)
and [validation manifest](../../docs/migration/v020_khn26_alignment_validation.json).
Real32 is compile-only; full six-hour dynamics/budgets and P3 are separate
acceptance work. These tests do not replace the frozen v0.18 Manus suite.

## Six-hour trajectories and native-removal accounting

`trajectory.py` adds observations to isolated copies of the production
drivers; numerical statements and release sources remain unchanged. Use a
fresh workspace, first run `run.py WORK --prepare`, then:

```bash
python3 tests/khn26/trajectory.py WORK --prepare
```

Run production MATLAB with the same shared/native environment as the smoke
example above, but clear `ACE_STEPS`, write `WORK/matlab.nc` and export all
361 saved states to `WORK/matlab_states.bin`. Use the smoke export loop with
`step=1:size(X,4)`. Save the launcher and logs. Run the diagnostic MATLAB
copy with `run('/absolute/WORK/diagnostic_launch.m')` in a separate MATLAB
process; it exports matching saved states and a per-step budget stream.

From the repository root, run production Fortran with `--intervals 360`,
`--output WORK/fortran.dat`, `--state-output WORK/fortran_states.bin` and
`--physics native`. From **WORK**, run `build_budget/ace_model.exe` with the
absolute shared input path, `--intervals 360 --physics native`,
`--output fortran_diagnostic.dat` and
`--state-output fortran_diagnostic_states.bin`. Keep the four driver logs
as `matlab.log`, `matlab_diagnostic.log`, `fortran.log` and
`fortran_diagnostic.log`. The diagnostic Fortran process writes
`fortran_budget.bin` in its working directory.

```bash
python3 tests/khn26/trajectory.py WORK --watch
```

The watcher updates `trajectory_status.json` once per minute. It waits for
complete state/output/budget files, checks input/source hashes and exact
production/diagnostic saved-state identity, then writes
`six_hour_report.json` with trajectory, budget and production-output metrics
and artifact hashes. Known model error messages produce a failed status;
an incomplete or unexpectedly terminated run must also be checked against
the driver process exit status. No timeout certifies a model result.

Inventories sum reference density times layer thickness times normalized
ACE area over physical scalar levels 1–400. Reports split dynamics plus
clipping, native precipitation and damping increments. Step accounting
closure is not an independent conservation test: inspect the dynamics
increment and physical boundary/source terms separately. Theta_e inventory
is a diagnostic tracer inventory, not total energy.

Native removal is integrated directly from the per-step water sink and
reported per column/domain in kg/m² (numerically mm water equivalent).
It does not represent transported surface rain or validate unused historic
accumulation slots. Six-hour differences are reported as metrics; scientific
interpretation and release thresholds require developer review. P3 and
real32 numerical acceptance remain outside this run.

## SingleACE with the full KHN26 basis

`single.py` prepares isolated MATLAB/Fortran copies with the existing
dynamics tendency mask enabled for ACEs 2–101. The full shared geometry and
PMB are retained; this is not a one-column basis extraction. PMDv/PMD stay
disabled. Select duration, dt, bubble, precipitation, initial MF and mean-MF
policy explicitly through the command-line options (`--help`). MATLAB uses
its existing `one_ace_only`; Fortran enables its existing commented mask.
The preparer writes generated-source diffs, hashes, compiler commands and
`single_case.json` into a fresh workspace.

`--mean-mf zero` retains the domain-mean MF correction after SSPRK; other
columns then acquire compensation MF even though their dynamics tendencies
are masked. `--mean-mf free` disables that correction; zero initial MF in
the other columns remains zero. Physics and damping retain the original
all-column driver behavior in either mode: this is a dynamics mask, not a
mask of every physical process. Nonzero initial MF is confined to ACE 1,
with the declared sine pulse between 0 and 1000 m.

The workspace contains `smoke_launch.m` (one step) and `full_launch.m`.
Run the smoke MATLAB launcher and `build_single/ace_model.exe` with
`--steps 1 --state-output /fresh/smoke_fortran_states.bin`, the same declared
`--dt`, `--physics`, and absolute KHN26 input. Compare initial and evolved
states and check the inactive-column policy before starting the full
launcher/Fortran interval run. Use fresh output paths for each run.
Production Fortran's shared-case initialization is adapted only in the
test copy for the declared bubble, pulse and mean-MF policy.

These cases still use the Manaus 1342 profile and KHN26 100 m grid. Reusing
some older Manus singleACE parameters does not reproduce the frozen Manus
case, which has a different basis, sounding and grid. The six-hour watcher
above is specific to the full default KHN26 case and must not be applied to
a shorter singleACE run.

After preparation, `single.py WORK --launch` starts a detached supervisor.
It runs both one-step drivers, verifies initialization/pulse, numerical
agreement and inactive-column behavior, then starts both full drivers only
if the smoke comparison passes. MATLAB must have a writable preferences
directory and a valid license. The supervisor records driver PIDs, heartbeat
timestamps and actual exit codes in `single_status.json`; a failed driver
stops its paired process and preserves output/logs. `--run` performs the same
workflow in the foreground. Fresh paths are required; `--compare smoke` or
`--compare full` rechecks completed artifacts without rerunning the model.

The completed run writes `full_results.json` and `full_mf.npz`, containing
saved-state errors, field ranges, inactive scalar deviations, area-mean MF,
ACE 1 MF trajectories and source/input/output provenance. Status
`completed_pending_scientific_review` means numerical evidence is ready;
it is not a release or physical-acceptance decision.

`plot_single.py WORK` adapts validated full-run MF arrays to the existing
v0.18 plotter (`tests/alignment/plot_mf.py`). It produces PNG/PDF panels for
MATLAB, Fortran real64 and Fortran-minus-MATLAB over 0–20 km. MATLAB and
Fortran share a symmetric color scale; the difference has its own scale.
`--tag smoke` plots only the validated one-step check and labels it as such.
`--partial` plots only complete common one-minute states and labels the
figure as partial. The configured three-hour duration is not substituted
for the actual available time range.

`--launch` starts a detached plot watcher; it makes matched previews after
the MATLAB state stream becomes available, then creates `full_comparison/`
once the supervisor's full validation report exists. Plot directories use
the actual covered time; existing figures are preserved. `plot_status.json`
records whether the final plot is ready or the model failed. The normal
v0.18 matplotlib dependencies and a writable `MPLCONFIGDIR` are required.

## Packed singleACE timing

`serial_timing.py` uses the frozen three-hour case/completed MATLAB outputs
in `migration_work/khn26_single_3h`. Following developer instruction, it
rebuilds all modules and the driver in separate debug/production directories.
Both are packed real64 `-O2`; debug adds `-g`, `-fcheck`, FPE traps and
backtrace flags, while production adds none of these. By default, compilation
is serial and OpenMP runtime linkage is rejected. `--threads 6` enables
`-fopenmp` with six requested threads, dynamic teams disabled, a six-thread
limit and close/core affinity. The only model parallel region is the PMB
contraction; reductions within each output retain their original order.
Runtime linkage is checked against the requested mode. An isolated driver
has observational wall timers around `ace_driver` calls.

```bash
python3 tests/khn26/serial_timing.py migration_work/khn26_single_production_3h --launch
# Six-thread OpenMP replacement (stop the previous run first):
python3 tests/khn26/serial_timing.py migration_work/khn26_single_openmp6_3h --threads 6 --launch
```

Use a fresh directory. The detached supervisor records progress and actual
driver exit status in `timing_status.json`. It first integrates ten individual
steps with debug checks and then with the production build. All eleven saved
states must be finite with nonnegative qt and both complete streams must be
byte-identical; initial/single-step output must also match frozen legacy.
OpenMP runs additionally require ten-step byte identity against the completed
serial production gate in `migration_work/khn26_single_production_3h`.
`debug_gate_results.json` records gate exits, hashes and timings. Only a passed
gate starts the fresh three-hour production run from the original initial
state, without debug flags. The supervisor then runs the existing full-state
comparison and writes `full_results.json`, `full_mf.npz` and
`efficiency_results.json`. Input, source, object, executable and MATLAB
artifact hashes are recorded and rechecked. Failed runs preserve logs/outputs.
Stop any previous run before launching its replacement. The earlier checked
serial run in `migration_work/khn26_single_serial_3h` was stopped by developer
instruction, with partial outputs preserved; it is not three-hour acceptance.
The [recorded gate report](serial_gate_results.json) confirms the first ten-step
debug/production comparison passed; it does not certify the three-hour run.
The serial production run was subsequently stopped for the developer-requested
six-thread OpenMP replacement; its partial streams are preserved.
The [OpenMP gate report](openmp_gate_results.json) records successful six-thread
debug/production and serial-reference ten-step identity checks.

Efficiency is integration wall seconds divided by three simulated hours.
Fortran times `ace_driver` calls, excluding initialization and output diagnostics;
MATLAB uses its preserved `timeint` tic/toc (including loop/reporting overhead).
Fortran process wall time is reported separately; comparable MATLAB process
wall time was not recorded. These are historical/shared-host measurements,
not simultaneous runs or isolated hardware benchmarks. The MATLAB reference
integration took 5,798.9891 s, or 32.2166 wall minutes per simulated hour.

## Completed-run diagnostics and 15-minute serial timing

```bash
python3 tests/khn26/plot_single.py migration_work/khn26_single_openmp6_3h
python3 tests/khn26/diagnose_single.py migration_work/khn26_single_openmp6_3h
python3 tests/khn26/benchmark_single.py migration_work/khn26_single_serial_15min
```

The diagnostic script rechecks complete-state agreement, finite/nonnegative
states, inactive scalars and compensation MF before plotting theta_e/qt
anomalies and diagnostic curves. PNG/PDF files and `diagnostic_summary.json`
are written alongside the MF panels in `full_comparison/`. Matplotlib is
required; set a writable `MPLCONFIGDIR` when needed.

The benchmark requires a fresh directory, the preserved serial ten-step gate,
and the completed three-hour MATLAB/OpenMP state streams. It rebuilds current
sources using the serial production real64 `-O2` flags and checks ten-step
binary identity before timing. Fortran and MATLAB run sequentially for 900
simulated seconds with `dt=4 s` (225 steps), saving every 60 s. MATLAB copies
the original three-hour source and launcher with only duration/artifact-path
changes and a natural thread-cap query; no computational-thread setter or
affinity pinning is added. Use a writable `MATLAB_PREFDIR` if required.
Both short state streams must match their completed three-hour prefixes.

`benchmark_results.json` reports integration wall seconds per step and
separate full-process wall times. Fortran times `ace_driver`; MATLAB retains
the original `timeint` tic/toc including loop/reporting overhead. Inputs,
source/object/executable hashes, build/run commands and timing scope are
recorded in `benchmark_configuration.json`. This is one evolving run per
language on shared hardware, not an isolated or repeated-run benchmark.

If MATLAB fails before creating state output because the sandbox cannot
reach its license server, preserve the completed Fortran run and failure log.
After obtaining the required execution permission, use
`benchmark_single.py WORK --resume-matlab` to rerun only MATLAB with the same
launcher. The recovery verifies model/input/build hashes and records its
script hash. If the failed supervisor did not persist Fortran process wall
time, that optional value is reported as null; its completed integration
timing remains valid. Existing MATLAB state files are never overwritten.

The [saved 15-minute report](serial_benchmark_results.json) records 225 steps:
Fortran serial averaged 4.094963 s/step and MATLAB default averaged
1.835955 s/step. Both 16-state streams reproduced their three-hour prefixes
byte-for-byte. The [three-hour diagnostic summary](openmp_diagnostic_results.json)
records the earlier plotted numerical checks.

## MATLAB one-minute section comparison

```bash
python3 tests/khn26/profile_matlab.py migration_work/khn26_matlab_profile_1min
python3 tests/khn26/profile_matlab.py migration_work/khn26_matlab_profile_1min --run
python3 tests/khn26/profile_matlab.py migration_work/khn26_matlab_control_1min --control
python3 tests/khn26/profile_matlab.py migration_work/khn26_matlab_control_1min --run
```

Use fresh workspaces and the original MATLAB batch/default thread settings.
The section copy retains floating-point expressions and reduction grouping,
names the coarse nonlocal result before interpolation, and adds observational
timers. Explicit outer/nested `tic` handles preserve the integration clock.
Only integration sections are timed; postprocessing inversion is excluded.
Both 0/60 s states must match the completed three-hour MATLAB prefix exactly.
There are 15 steps, 135 tendencies/nonlocal evaluations and 30 `microrad`
calls. The control adds no section timers.

[Comparison and scope](../../docs/performance/khn26_section_profile.md),
[MATLAB section report](matlab_profile_results.json) and
[control report](matlab_control_results.json) preserve measurements and hashes.
MATLAB section timing measured 3.257407 s/step versus 1.893833 s/step in the
uninstrumented one-minute control. Instrumentation/JIT and shared-host load
effects are not separated; use the section measurements to locate work,
not as precise original-driver section costs. Cross-language aggregates are
additive but their internal boundaries and thermodynamic call counts differ.

## Revised MATLAB profiling and interleaved controls

`profile_matlab.py --timer-mode unsplit` times the whole original nonlocal
function without splitting its PMB/interpolation expression. `split_only`
is an expression-naming sensitivity control without section timers; the
default `helper` preserves the initial split/timer experiment.

`profile_sensitivity.py WORK` runs fresh-process control/split-only/unsplit/
helper/control samples sequentially. `profile_paired.py WORK` prepares one
initialized MATLAB model with a single shared PMB allocation and five
same-initial-state minute samples (control/profile/control/profile/control).
`profile_paired.py WORK --run` executes them, recording wall/CPU times and
exact state identity. No natural thread setting or affinity is changed.
Use fresh paths, licensed MATLAB, writable preferences and the same
license-network execution permission as earlier MATLAB tests.

The paired unsplit profile measured 1.875705–1.929413 s/step, within the
control range of 1.789522–2.271917. This does not establish zero overhead;
the earlier 72% difference cannot be treated as a fixed overhead correction.
`--compare-fortran PATH_TO_PROFILE_JSON` combines completed paired samples
with a new validated serial Fortran minute report, without rerunning either
model, and verifies additive section sums.

[Updated comparison](low_perturbation_comparison.json),
[paired samples](profile_paired_results.json) and
[sensitivity samples](profile_sensitivity_results.json) preserve raw evidence.
See [methodology and updated table](../../docs/performance/khn26_section_profile.md).
The default MATLAB run has substantial measured parallel CPU use; this
comparison retains serial Fortran and does not equalize CPU resources.

## Fifteen-minute MATLAB single-thread benchmark

```sh
python3 tests/khn26/benchmark_matlab_single.py migration_work/khn26_matlab_single_15min
MATLAB_PREFDIR=/tmp/ace-khn26-matlab-single-prefs python3 tests/khn26/benchmark_matlab_single.py migration_work/khn26_matlab_single_15min --run
```

Use a fresh workspace, writable preferences and licensed MATLAB. The run
starts MATLAB with `-singleCompThread`, queries/asserts computational cap
one before and after the original frozen model, and retains the original
15-minute configuration, expression and integration `tic`/`toc`. CPU time
is sampled outside that timer; no section instrumentation, thread setter
or CPU pinning is introduced. The source diff records duration/output
path changes and outer CPU measurements. The full run comprises 225
SSPRK93 steps and exports 16 complete minute-spaced states.

The runner checks source/input/reference hashes, finiteness/nonnegative
saved qt and state agreement against the frozen default MATLAB trajectory.
Exact identity and per-field errors are reported separately; thread-dependent
rounding differences are not silently accepted as scientific equivalence.
Results include CPU/wall ratio, computational cap, process/integration
timings and comparisons to the earlier default MATLAB and serial Fortran
15-minute measurements. A single computational thread does not imply the
MATLAB process has no background threads. This experiment does not rerun
the reference measurements or change production sources.

The 2026-10-06 single-thread attempt was interrupted at the user's request.
The last step started at simulated second 552 (at least 548 seconds
completed). MATLAB exited on SIGTERM; no final timing or complete state
stream exists. The runtime workspace preserves `cancellation.json`, the
configuration/source diff and log. This is not a completed 15-minute result.
The [tracked cancellation record](matlab_single_cancellation.json) preserves
configuration and artifact hashes; only startup cap one was observed.

## Saved-state physical review

`review_single.py` reads the completed three-hour singleACE outputs without
integrating either model. It verifies preserved artifact hashes, computes
area/density-weighted water and theta_e inventories, reconstructs sampled
ACE 1 lateral exchange/mixing and sponge rates, and compares vertical kinetic
energy. An independent MATLAB NetCDF/longdouble calculation checks net
inventory changes. Source constants, dynamics masks, cutoff-interface MF,
finite/nonnegative states and cross-language agreement are checked.

```sh
python3 tests/khn26/review_single.py migration_work/khn26_single_openmp6_3h --output tests/khn26/single_physical_review.json --plot docs/figures/khn26_single_physical_review
```

NumPy/netCDF4 are required and matplotlib is optional for plotting.
Existing model outputs are read only; selected analysis outputs are
regenerated. The [physical review](../../docs/maintenance/history_summary.md#record-v020-khn26-single-physical-review)
explains the masked-case reservoir behavior and sparse-sampling limits.
Theta_e inventory and vertical KE do not establish total-energy closure.
The [saved report](single_physical_review.json) contains all 181 samples and
provenance. No new performance measurement or model run is part of this review.

## Native precipitation and three-hour wave comparison

For source-version scope, fresh aligned ten-minute gates, error-source
controls and stale runtime labels, see the
[current development status](../../docs/maintenance/history_summary.md#record-v020-khn26-status).
The three-hour trajectories below predate the thermodynamic alignment
in `b1010ea`; they do not validate a three-hour run of that aligned source.

The subsequent [k=2 WENO alignment](../../docs/maintenance/history_summary.md#record-v020-khn26-weno-matlab-alignment)
also passed fresh dry/native ten-minute multiACE gates. Its
[result record](weno_matlab_alignment_gate_results.json) includes unchanged
limits, component checks and comparison with the pre-WENO aligned gate.

The corrected native singleACE and dry/native multiACE ten-minute tests
passed their original limits. Native three-hour singleACE and multiACE
saved-state comparisons are complete. The latest multiACE target was reduced
from twelve hours to three hours; neither long-run queue is active.

| Evidence | Record |
| --- | --- |
| Ci correction, common-state and short tests | [Constants audit](../../docs/maintenance/history_summary.md#record-v020-khn26-constants-audit), [validation summary](ci_correction_validation.json) |
| Native singleACE three hours | [Physical review](../../docs/maintenance/history_summary.md#record-v020-khn26-single-native-physical-review) |
| Native multiACE three hours | [Comparison](../../docs/maintenance/history_summary.md#record-v020-khn26-multiace-three-hour-comparison) |
| Earlier experiment history | [MultiACE case](../../docs/maintenance/history_summary.md#record-v020-khn26-multiace-gravity-wave), [singleACE precipitation investigation](../../docs/maintenance/history_summary.md#record-v020-khn26-single-precip-comparison) |
| Script roles and dependencies | [Script index](scripts.md) |

### Inspect existing outputs

Run from the repository root with NumPy, netCDF4 and matplotlib installed.
These commands read saved outputs and regenerate postprocessing artifacts;
they do not start model processes. `WORK` denotes the preserved local
workspace, not a fresh simulation destination.

```sh
python3 tests/khn26/compare_multi_prefix.py migration_work/khn26_multi_matlab_default_fortran32_12h
python3 tests/khn26/plot_multi_snapshots.py migration_work/khn26_multi_matlab_default_fortran32_12h
python3 tests/khn26/plot_single_native.py migration_work/khn26_single_matlab_default_fortran32_3h --output docs/figures/khn26_single_native_3h
```

The multiACE comparison uses exactly minutes 0–180 at 60-second intervals,
including Fortran's first three hours from its longer preserved stream.
Snapshot panels show MATLAB left, Fortran right, eight rows at 20–160 minutes,
0–20 km, panel height:width 1:5, and MF colors from −1 to +1. Missing live
records are labeled; `--watch` refreshes until all requested panels exist.
The singleACE plotter verifies hashes against its completed run report.

Completed trajectories have close cross-implementation agreement; the
three-hour runs are not certified by the ten-minute numerical thresholds.
qt agreement and integrated native water removal are not surface rainfall
or a closed water-budget test. Mean-MF projection and nonlocal pressure
also require care when interpreting remote wave arrival.

### Reproduce short tests

Use fresh paths. Preparers generate isolated driver copies and compile the
Fortran binaries. Each language receives 32 distinct physical cores on the
recorded 160-logical-CPU host. Licensed MATLAB and its license-server access
are required. The following commands run only the ten-minute gates:

```sh
python3 tests/khn26/multi.py migration_work/khn26_multi_short --prepare --initial-mf 0
python3 tests/khn26/multi.py migration_work/khn26_multi_short --run --gate-only
python3 tests/khn26/single_precip.py migration_work/khn26_single_short --prepare
python3 tests/khn26/single_precip.py migration_work/khn26_single_short --run --gate-only
```

`--run --gate-only` is a foreground supervisor. To keep it in the background,
launch it with persistent logs, for example after preparation:

```sh
nohup python3 tests/khn26/multi.py migration_work/khn26_multi_short --run --gate-only > migration_work/khn26_multi_short/background.log 2>&1 < /dev/null &
```

Preserve configuration, logs, raw streams and comparison reports. State,
all nine SSPRK-stage tendencies and actual native precipitation sinks are
checked separately, with checked/production Fortran prefix identity.
The native singleACE case masks dynamics tendencies outside ACE 1 and has
an initial 0.03 kg m−2 s−1 MF pulse below 1 km. MultiACE enables all columns
and has zero initial MF. Both use the +1 K bubble at ACE 1 levels 11–51,
dt=4 s and the full 101-column geometry; these are distinct experiments.

### Long-run launchers

`unrestricted_single.py` reproduces the three-hour native singleACE launch
with MATLAB defaults and Fortran 32. `unrestricted_multi.py` now launches
three-hour native multiACE directly. Both long runs save 181 minute-spaced
states, including the initial state. The common `multi.py` default is also
three hours; gate-only runs still stop after their ten-minute tests and
print only the gate completion message.

Both unrestricted launchers accept `--gate-work` during preparation to select
a fresh completed gate. Their legacy default gate paths are retained for
traceability; gate names containing `12h` do not select a twelve-hour run.
Changed source/runner hashes require fresh gates; do not edit old configuration
hashes to bypass verification. Old long-run configurations with other durations
are rejected before model processes launch. Prepare and launch into fresh
destinations; do not restart old queues or reuse preserved workspaces.
MATLAB has no imposed thread cap
or CPU binding, Fortran remains 32, and CPU overlap is allowed. Status,
commands and first-ten-minute reproduction checks remain with each run.

After a fresh matching gate completes, prepare a three-hour destination:

```sh
python3 tests/khn26/unrestricted_single.py migration_work/khn26_single_3h_run --prepare --gate-work SINGLE_GATE
python3 tests/khn26/unrestricted_multi.py migration_work/khn26_multi_3h_run --prepare --gate-work MULTI_GATE
```

Preparation creates drivers/configuration without launching a simulation.
The original stopped twelve-hour launch and its three-hour comparison remain
historical evidence; their raw logs, workspace names and results are unchanged.

## Staged Fortran OOP preservation

The [OOP plan](../../docs/migration/fortran_v020_oop_refactor.md) records the
ownership boundaries and stage-specific gates. `oop_regression.py` freezes
OOP-0 or compares a candidate with that hash-verified workspace; it preserves
initialization, raw RK/physics/cache observations, state streams and nine-field
output exactly. `oop_initialization_contract.py` adds shared/legacy/default
and error-contract checks plus fresh-process 600 s dry/native comparisons
using the frozen baseline executable without modifying its workspace.

[OOP-2 results](oop_stage2_results.json) record the completed initialization
ownership gates. OOP-3a moves response tables, coarse grids/work arrays and
flags into a private model context, with explicit context propagation and
compatibility dispatch for old procedural tests. Its isolated observer checks
that model initialization leaves legacy PMB unallocated. The legacy basis
capture adapter separately checks its coarse forcing against the frozen
first RK frame. [OOP-3a results](oop_stage3a_results.json) record those gates.
Numerical runtime scope remains GNU real64/OpenMP32; the
real32/serial compatibility matrix certifies compilation and linking only.
Keep one model initialized once per fresh process until response/cache and
P3 lifecycle migration is validated. Commands and external data requirements
are listed in the OOP plan.

OOP-3b adds `ace_t%integrate(te)`, persistent object time/options and an explicit
private thermal context. The isolated observer checks that both legacy
response and thermal storage stay unallocated throughout the model path.
`oop_integration_contract.py WORKSPACE` checks persistent time, existing
full-dt overshoot, repeated/past/aligned no-op targets and exact cache/state
preservation; five none/native/P3 steps match the frozen executable, including
an explicit interval clock reset. A fractional-dt three-minute CLI replay
also preserves state and normal-output bytes. Helpers
are inserted only into a separate test build, with no production getters.
Validation and serialization callbacks return before integration starts.

[OOP-3b results](oop_stage3b_results.json) record complete integration/cache
ownership acceptance: 195 bitwise-identical frozen artifacts, 165 observation
layouts, 18 valid state streams, nine supplemental gates, clock/cache and
fractional-dt contracts, four compilation/link variants and adapter checks.
Checked legacy procedural clients also reproduce none/native/P3 ten-step
streams from frozen initial arrays. Damping/P3 lifecycle remains a later
stage; retain the single-model/fresh-process restriction.

OOP-4a adds observational `ace_t%diagnose()` with separate full-precision
thermal/phase and real32 output buffers. Optional Xout/rh4/b4 copies feed the
existing serializer at its original cadence. `oop_diagnose_contract.py
WORKSPACE` extracts its oracle from the hash-pinned frozen writer, verifies
all diagnostic fields exactly, checks repeated/poisoned-buffer refresh and
state/cache/clock/response preservation, and compares five steps with
interspersed diagnoses against the frozen executable. It uses six checkpoints
and three diagnoses per checkpoint in fresh none/native/P3 processes. Public
state remains private; helpers exist only in the isolated checked build.
Output unit/record ownership remains in `test.F` until OOP-4b.


[OOP-4a results](oop_stage4a_results.json) record 195 bitwise-identical frozen
artifacts, 165 observation layouts, 18 valid state streams, all three
observational diagnosis contracts, integration clock/cache/fractional-dt
contracts, nine supplemental gates and four compilation/link variants.
The numerical diagnostic body differs from the frozen writer only by
component qualification; removing diagnostic additions recovers the OOP-3b
module exactly. Existing serialization and cadence remain unchanged.


OOP-4b transfers normal-output units, record sizing, counter and the nine-field
real32 write into `ace_t%open_output(filename)`, `%output()` and
`%close_output()`. The driver retains cadence and comparison state streams.
`oop_output_contract.py WORKSPACE` compares 12 repeated/poisoned-buffer records
at four three-minute checkpoints against the hash-pinned frozen writer, checks
model/cache/clock preservation, frozen executable state and normal-field
identity, reopen record reset and six lifecycle/fresh-file failure cases.
The existing diagnostic, integration, initialization and compilation gates
continue to apply. Damping/P3 still require one initialized model per process.

[OOP-4b results](oop_stage4b_results.json) record 195 bitwise-identical frozen
artifacts, 165 observation layouts, 18 valid state streams, three output and
three diagnostic contracts, integration clock/cache/fractional-dt contracts,
nine supplemental gates and four compilation/link variants. Each output
contract verifies 12 records, four frozen checkpoint fields, model/cache
neutrality and reopen reset; six error cases preserve the fresh-file policy.
Exact inverse extraction recovers the OOP-4a module and driver. No tolerance,
numerical method or scientific parameterization changed.


OOP-5a adds private model-owned damping first-use flag/values and separate
legacy procedural storage. `oop_damping_contract.py WORKSPACE` compares five
first/subsequent calls on two synthetic shapes/grids/dt against fresh-process
frozen ImDamp oracles. Three two-native-object tests (same configuration,
different dt, and different grid/dt) compare both five-step trajectories with
fresh frozen executable references. The cropped 201-level fixture is solely
for lifecycle testing; its parent/derivation/hash are recorded and no physical
acceptance is claimed. Existing diagnostic/output neutrality and integration
no-op cache gates include damping flag/allocation/value snapshots. Native
sequential-object support does not certify concurrent, reinitialized or mixed
P3/native objects; P3 still requires one instance per fresh process.

[OOP-5a results](oop_stage5a_results.json) record 195 bitwise-identical frozen
artifacts, 165 observation layouts, 18 valid state streams, two independent
five-call damping oracles and three two-native-object/fresh-reference cases.
All existing diagnosis/integration/output contracts, nine supplemental gates,
four compilation/link variants and current/previous profiler adapter compile
checks pass. Snapshot contracts include damping first/allocation/cache state.
The cropped fixture uses response/forcing ACE aligned chunks; its initial
slow default-chunk attempt is preserved separately, and every decoded variable
bit/attribute is audited identical after the layout repair. Numerical source
statements and tolerances are unchanged; no performance or long scientific
acceptance is claimed. See the OOP plan for validated native lifecycle limits
and the remaining single-P3-instance restriction.


OOP-5b moves wrapper directory/first/itt into a private model context and keeps
separate procedural storage. The unchanged P3 library retains SAVE is_init,
shared tables/options and mutable global_status; one ACE P3 wrapper context
per fresh process is explicitly enforced before a second library init/main.
`oop_p3_contract.py WORKSPACE` checks model, sequential native interference and
public procedural ten-step prefixes against frozen states, every P3 field and
surface flux; verifies the directory used, exactly one init and itt=1..10;
and checks four second-context rejections plus four directory validation errors.
Current snapshot contracts include P3 options/counter/claim neutrality; native
multi-object tests require the library to remain unused. No independent second
P3 instance, copied P3 model or concurrent lifecycle is certified. Final OOP
three-hour acceptance and history integration remain separate steps.

[OOP-5b results](oop_stage5b_results.json) record 195 bitwise-identical frozen
artifacts, 165 observation layouts, 18 valid state streams, three P3 wrapper
contracts with all-field/surface-flux identity, and eight explicit restriction/
directory validation errors. Actual init path/count and itt=1..10 are traced
only in isolated copies; third-party source/tables stay unchanged. Existing
damping, diagnosis, integration/no-op, output, nine supplemental and four
compilation/link gates all pass. Exact inverse extraction recovers the OOP-5a
module and its directory validation. One P3 wrapper context per fresh process
is enforced; final three-hour OOP acceptance/history integration remain later
work. No tolerance or numerical algorithm was changed.

`oop_long_regression.py WORKSPACE --prepare` builds isolated OOP-5b plain and
minute-precipitation-observed copies, preserving production sources. Use
`--run` to execute native/P3 plain/observed one-minute identity gates followed
by separate fresh-process three-hour multiACE runs. The experiment matches
the accepted +1 K bubble, zero initial MF, dt=4 s and GNU real64/OpenMP32.
All saved states, nine-field normal output and minute/cumulative precipitation
must match the hash-pinned archived Fortran references byte-for-byte. Input,
lookup, source, executable and helper hashes are recorded. Live `status.json`
and final `results.json` are workspace artifacts; a background launch does
not itself certify final acceptance. See the OOP plan's final three-hour
launch record for workspace, logs and reproduction details.

[Final OOP three-hour results](oop_long_results.json) record successful native
and P3 multiACE runs: all 181 states, all nine-field normal output records and
all minute/cumulative precipitation records match the archived references
bit-for-bit. An independent post-run audit reverified hashes, layouts, complete
record counts, finite states/outputs, nonnegative water/number fields and
precipitation bookkeeping. P3 riming validity and one actual initialization
also pass. Current production source matches the executed OOP-5b snapshot.
This completes the documented multiACE OOP preservation gates; reference
history integration remains separate, and existing lifecycle/precision scope
limits still apply.
