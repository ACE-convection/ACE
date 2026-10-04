# MATLAB S20 development source

`ace.m` uses the v0.18 shared NetCDF input pattern, extended for S20's three
basis operators and slab geometry. The default is
`../data/input/goamazon314_s20.nc`, which must be generated after the correct
S20 basis is provided. From `matlab/`:

```matlab
setenv('ACE_INPUT_FILE', '/absolute/path/to/case.nc');
ace
```

Both readers understand `ACE-case-input-1` and `ACE-case-input-2`. This S20
driver requires schema 2 slab geometry; the v0.18 annular basis is not a
substitute. Profiles are already prepared by the converter and are used
without repeating sounding interpolation. `arm` and original profile index
come from the file; `case_profile_index` preserves the index and `pidx=1`
selects the file's single profile. Dimensions, spacing and geometry come
from the file. Bubble, timestep and physics switches retain S20 defaults.

`ACE_INPUT_MODE=legacy` selects the original MAT/sounding preprocessing.
`ACE_LEGACY_DATA` selects its `basis/` and `soundings/` root. The required
final MAT basis contains `D`, `Z`, `PMB`, `PMDv`, `PMD`. The portable shared
schema and conversion entry are in [shared input](../docs/shared_input.md).
Historical output/toolbox requirements remain.

The [source integration record](../docs/migration/v020_source_integration.md)
identifies the import baseline; later input-adapter edits are described in
[the adapter record](../docs/migration/v020_shared_input_adapter.md).
Reader readback is verified against v0.18 and Fortran using synthetic schema 2
fixtures. Full driver initialization, model integration and actual basis
inspection remain deferred; see the adapter record for evidence.
Use `v0.18.0` for the accepted v0.18 source and tests.
