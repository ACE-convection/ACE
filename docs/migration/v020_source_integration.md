# v0.20 source integration

The source-only state below describes `d9e8401`. Subsequent developer-authorized
[shared-input adapters](v020_shared_input_adapter.md) reconnect both drivers
to NetCDF and extend the contract to three operators. Input-only verification
is recorded there; model testing remains deferred.

Authorized 2026-10-04 after source review. The developer selected integration
on `migration/v020-preparation`, with basis confirmation and testing deferred.
Published `main` and `v0.18.0` remain at `d7d25b1`.

## Imported code and history

The [55-file manifest](v020_source_merge_manifest.json) identifies the
promoted source blobs: 51 MATLAB `.m` files from packaged S20 at `c9ae729`
and four Fortran source/build files from `88e4af5`. There are 23 replacements
and 32 additions; no numerical source file is deleted. Source byte identities
were checked against the prepared manifest before promotion.

MATLAB's driver is now `matlab/ace.m`; original snapshot names remain in
its provenance. Paired library versions are imported together. The MAT
sample file is excluded from this code-only operation. Existing shared-input
helpers and the older scalar WENO helper are retained for follow-up work.

The historical Fortran commits after `ffdd734` through `88e4af5` are fetched
from the separate local repository and joined as the second merge parent.
The merge uses `ours` to establish ancestry, followed by explicit promotion
of the four manifest-listed files into `fortran/`. This avoids importing
the historical repository's root layout into the unified source tree;
it does not assert scientific equivalence between source versions. Local
modifications in the separate repository remain untouched and excluded.

## Current development state

This is a historical source-version migration, not a behavior-preserving
cleanup. State ordering, geometry, physics splitting and default cases change
as described in the [code review](v020_code_review.md). The numerical source
has no new corrections applied. In particular, known P3 exceptions and
historical diagnostic issues remain to be addressed through reviewed changes.

Historical MATLAB and Fortran drivers use their MAT/binary input contracts.
The shared NetCDF helpers are retained but not yet wired into these drivers.
Source READMEs and the test README describe this limitation. The frozen v0.18
reference data and the released implementation in Git remain available.

No basis candidate contents were inspected, no runtime input was replaced,
and no build, test or model integration was executed. Code confirmation is
static review and source identity checking. No v0.20 acceptance or release
tag is created by this merge.

## Next code work

Review input adapters and known code findings in small changes, before the
deferred basis confirmation and tests. The required MATLAB final basis is
`COMPOSITE_ACE_BASIS_2D_V020.mat` containing `D`, `Z`, `PMB`, `PMDv` and
`PMD`; the developer will provide it. Shared dynamics and Fortran-only P3
need separate validation when testing begins.
