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
