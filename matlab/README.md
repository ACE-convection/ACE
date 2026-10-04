# MATLAB S20 development source

`ace.m` is the packaged S20 driver, renamed from `ACE_V020_2D88ACEs.m`.
Its local numerical routines and paired `util_*` code are imported without
scientific corrections. The [source manifest](../docs/migration/v020_source_merge_manifest.json)
records the exact source blobs; the
[integration record](../docs/migration/v020_source_integration.md) owns scope
and deferred work. No runtime validation has been performed on this branch.

The historical driver constructs paths relative to `pwd`. It expects
`matlab/data/basis/COMPOSITE_ACE_BASIS_2D_V020.mat` with `D`, `Z`, `PMB`,
`PMDv` and `PMD`; see the [requested input contract](../docs/migration/v020_code_review.md#basis-file-requested-from-the-developer).
Its default sounding is
`matlab/data/soundings/maoarmbeatmM1.c1.20140101.003000.nc`, profile 314.
The historical output path and toolbox dependencies also need review.
Do not run the basis builders without first reviewing their hard-coded paths
and intermediate-file deletion settings.

`read_shared_input.m` is retained from v0.18, but this imported driver does
not yet use it. `ACE_INPUT_FILE`, `ACE_INPUT_MODE` and `ACE_LEGACY_DATA` are
not implemented by the imported S20 driver. Shared-input adaptation is a
subsequent code change, followed by basis confirmation and tests.

To reproduce the accepted v0.18 implementation, use a separate checkout of
`v0.18.0` and its source README/test instructions. The frozen evidence remains
preserved; this development source is not a new validated release.
