# MATLAB v0.21.87

The default shared input is `../data/input/goamazon314_88aces.nc`: 88 equal
5 km ACEs, raw GOAmazon filtered profile 314, dz=100 m, dt=6 s and eight
hours. Current inversion-derived reference Tv, saturated +0.25 K bubble,
zero initial MF and post-dynamics precipitation ordering are retained.
`ACE_DHH` and `ACE_DHV` default to `on`; each accepts `on` or `off`.
`ACE_DT` overrides dt and must divide 60 s. The old Manaus case requires
both switches `off`. See [release notes](../docs/releases/v0.21.87-notes.md)
and [new tests](../tests/slab/README.md). The developer accepted the tested
native eight-hour case and response plots; retained limitations are in the notes.
Obtain the large 101-ACE KHN26 and 88-ACE basis/shared operator inputs
separately: both are local-only and must not be uploaded through Git or LFS. The materializer verifies existing files or reconstructs them
from separately supplied local parts; do not commit or upload those payloads.

```matlab
addpath('/absolute/path/to/ACE/matlab');
maxNumCompThreads(32);
setenv('ACE_INPUT_FILE','/absolute/path/to/goamazon314_88aces.nc');
setenv('ACE_OUTPUT_FILE','/absolute/path/to/fresh-output.nc');
ace
```

The output path must be fresh. `ACE_STEPS=10` selects a ten-step smoke run
with output each step; clear it for the eight-hour default. `ACE_PHYSICS` is
`native` by default, or `none` for dynamics comparisons. `ACE_VALIDATE_INPUT`
selects an initialization-only MAT dump containing `X0` and `model`.
Dimensions and slab geometry come from schema 2. Unavailable PMDv/PMD placeholders are still rejected when enabled. `case_profile_index` retains the
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
differences. The new eight-hour case remains outside that earlier tested scope, and
P3 is a Fortran-only feature. Use `v0.18.0` for the accepted v0.18 source/tests.
