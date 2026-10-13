# MATLAB KHN26 v0.20.0 source

`ace.m` now follows the author-selected November 2025 KHN26 driver and its
paired utilities. The default shared input is
`../data/input/manaus1342_khn26.nc`: actual 101-ACE 4UNEVEN basis, processed
Manaus profile 1342, dt=6 s and six-hour duration. No sounding preprocessing
is repeated. The reference Tv is reconstructed from theta_e/qt as in KHN26.

```matlab
addpath('/absolute/path/to/ACE/matlab');
setenv('ACE_INPUT_FILE','/absolute/path/to/manaus1342_khn26.nc');
setenv('ACE_OUTPUT_FILE','/absolute/path/to/fresh-output.nc');
ace
```

The output path must be fresh. `ACE_STEPS=10` selects a ten-step smoke run
with output each step; clear it for the six-hour default. `ACE_PHYSICS` is
`native` by default, or `none` for dynamics comparisons. `ACE_VALIDATE_INPUT`
selects an initialization-only MAT dump containing `X0` and `model`.
Dimensions and slab geometry come from schema 2. PMDv/PMD placeholders are
marked disabled and cannot be enabled. `case_profile_index` retains the
original index while `pidx=1` selects the shared file's sole profile.

`ACE_INPUT_MODE=legacy` reads the original KHN26 MAT basis and processed
`acelevels_*.nc`; `ACE_LEGACY_DATA` sets the root containing `basis/` and
`soundings/`. It does not select the earlier raw-sounding S20 driver.

The [integration record](../docs/migration/v020_khn26_integration.md) explains
source preservation, adapter changes and scientific alignment. See
[shared input](../docs/shared_input.md) for conversion and
[KHN26 tests](../tests/khn26/README.md) for validated scope. The original
MATLAB native precipitation formula is preserved, including its known
high-condensate overflow. The developer accepted the documented three-hour GNU real64 comparisons
for v0.20.0; [release notes](../docs/releases/v0.20.0-notes.md) retain known
differences. The six-hour defaults remain outside this tested scope, and
P3 is a Fortran-only feature. Use `v0.18.0` for the accepted v0.18 source/tests.
