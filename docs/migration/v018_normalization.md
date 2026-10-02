# v0.18 source-root normalization

Authorized by the developer on 2026-10-02 before publishing `v0.18.0`.
This structural operation follows the accepted Manus validation milestone;
it introduces no scientific correction. The
[per-file manifest](v018_normalization_manifest.json) records source hashes,
retirement dispositions and test/tool path adaptations.

## Promotion and retirement map

| Before | Normalized path/disposition |
| --- | --- |
| `matlab/active/ace.m`, `read_shared_input.m`, `util_*` | Same names directly under `matlab/` (22 files) |
| `fortran/active/src/`, `makefile` | `fortran/src/`, `fortran/makefile` (4 files) |
| MATLAB/Fortran staging READMEs and root placeholders | Replaced by current source-root run instructions |
| `matlab/active/numerics/`, `thermodynamics/`, `time_integration/` | 29 later S20/S24 staged utilities retired from the current tree |
| `matlab/history/`, `fortran/history/` | 325 historical files retired from the current tree; recoverable in Git |

The 29 retired utility bytes all have exact counterparts in the historical
collections. Their roles and cross-version differences were reviewed in
[lineage](matlab_lineage.md), [version matrix](matlab_version_matrix.md),
[utility inventory](matlab_shared_utility_inventory.md) and the
[superseded layout proposal](matlab_active_layout_plan.md).
Uncertain historical ancestry remains uncertain; removal from the current
tree does not consolidate or reinterpret any snapshot.

## Preservation and path effects

Recovery commit: **`c9ae729`**, retained on `feature/shared-netcdf-input`
and in the ancestry of the normalized release. All historical files were
backed up and verified before removal. A complete local copy, including
ignored compiler artifacts, is under
`migration_work/v018_pre_normalization/`. Git history is the portable archive;
the local backup is an additional safeguard.

Example recovery without changing the current checkout:

```bash
git show c9ae729:matlab/history/original_git/ace_v018_dev_8aces.m
git worktree add --detach /tmp/ace-pre-normalization c9ae729
```

Historical large data may be LFS pointers; obtain the corresponding LFS
objects when recovering actual MAT/NC data. The input manifests and LFS
commit/object maps remain under `docs/migration/`. No commit ancestry,
existing tag target or remote history is rewritten.

Of 26 promoted files, **24 are byte-identical**. Only the MATLAB and Fortran
driver default shared-input paths change from `../../data/input/manus208.nc`
to `../data/input/manus208.nc`. Numerical routines, arrays, compiler defaults,
constants and physics switches are unchanged. MATLAB still runs from its
source directory and uses its named `util_*` directories. Legacy fallback
data directories now resolve under repository-root `data/`; explicit
`ACE_LEGACY_DATA` continues to select the original data collection.

Twenty-nine test/tool files receive only source-path substitutions. Archived
reference metadata and scientific reports retain their original paths/hashes
as evidence. Diagnostics requiring an exact historical source hash should
be replayed in the pinned pre-normalization checkout rather than relaxing
their provenance checks.

## Validation

The normalized GNU build passed, and default shared-input initialization
agrees exactly with explicit input selection within both implementations.
The three-hour singleACE cases with and without precipitation and the
twelve-hour multiACE case exactly reproduce their pre-normalization saved
numerical values, including all ACEs and native precipitation diagnostics.
All 384 manifest entries were checked against the recovery commit and the
current tree. Commands, hashes and full comparison results are recorded in
the [release record](../releases/v0.18.0.md) and its linked normalization
validation evidence. No new cross-implementation physical tolerance is
introduced.
