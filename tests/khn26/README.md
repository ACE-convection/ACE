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
