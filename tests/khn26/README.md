# KHN26 actual-basis checks

These checks cover the author-selected 101-ACE 4UNEVEN basis and processed
Manaus profile 1342. Requirements: licensed MATLAB (tested R2023b), GNU
Fortran/netCDF-Fortran (`nf-config`), Python NumPy/netCDF4, generated
`data/input/manaus1342_khn26.nc` and original source data matching its hashes.
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
regenerated. The [physical review](../../docs/migration/v020_khn26_single_physical_review.md)
explains the masked-case reservoir behavior and sparse-sampling limits.
Theta_e inventory and vertical KE do not establish total-energy closure.
The [saved report](single_physical_review.json) contains all 181 samples and
provenance. No new performance measurement or model run is part of this review.
