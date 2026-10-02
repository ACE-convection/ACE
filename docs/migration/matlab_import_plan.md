# Historical source import and preservation record

Updated 2026-10-02. Historical source import and v0.18 normalization are
complete. This record owns provenance and recovery; the
[roadmap](matlab_fortran_alignment_plan.md) owns future work and the
[release record](../releases/v0.18.0.md) owns accepted scientific scope.
The full import-stage tables and original decisions remain available at
`v0.18.0:docs/migration/matlab_import_plan.md`.

## Import method and scope

The ten original MATLAB Git commits were joined by a non-squashed subtree
under `matlab/history/original_git/`. At import time their object IDs,
parents, metadata and source trees were preserved. Original commits retain
root paths internally; the prefix belongs to the new subtree merge tree.
The later scoped LFS migration changed MATLAB commit IDs without changing
source bytes. Use the [commit map](matlab_data_lfs_commit_map.csv) to translate
pre-LFS evidence rather than assuming the old SHA resolves in a fresh clone.
Fortran history was likewise preserved through a non-squashed subtree.

S19, standalone, S20 and S24 archive states were imported in dependency-aware
commits. Complete drivers, local functions, library collections, inherited
line endings, backups and experimental files were preserved together.
Import ordering records migration work, not recovered historical chronology.
No hybrid or intermediate model was manufactured by combining driver hunks.

## Verified archive anchors

Current IDs below were resolved through the retained LFS commit map and
checked as local commit objects during this documentation update.

| Imported state | Files | Pre-LFS anchor | Current anchor |
| --- | ---: | --- | --- |
| Original MATLAB subtree join | 116 tip-tree files, ten original commits | `141455d` | `08f7599` |
| S19 `ACE_V019.3` | 98 | `b7b448b` | `6b88643` |
| Standalone K24 export experiment | 1 | `8ed7284` | `64c2455` |
| Standalone v0.19 2D driver | 1 | `b3637f9` | `2f91eb2` |
| Standalone v0.20 2D driver | 1 | `d1bcc00` | `81fe8e0` |
| Packaged S20 `ACE_V020` | 52 | `bb040f8` | `374f377` |
| S24 p87/GF87 `ACE_V024.87` | 50 | `6af974b` | `89f2e96` |

The recorded import checks compared archive, destination and committed blob
paths/hashes, verified complete-package counts, and preserved inherited CRLF
and whitespace. Byte identity establishes preservation, not numerical validity.
Detailed file identities and scientific differences remain in the
[inventory](matlab_inventory.md), [version matrix](matlab_version_matrix.md)
and [lineage](matlab_lineage.md).

Earlier records describe `matlab/snapshot/v0.19.3-k24`,
`matlab/snapshot/v0.20-package`, `matlab/snapshot/v0.24.87-p87-gf87` and
Fortran `v0.18` as historical markers. They are not present in the local tag
list inspected for this update; do not infer their current remote existence.
The proposed `matlab/git/...` tags were not recorded as created.
Use verified commit anchors when a historical ref is unavailable. Unified
`v0.18.0` is a separate release marker and does not reinterpret those names.

## Evidence boundaries

| Evidence | Meaning |
| --- | --- |
| Git-confirmed | Original source trees, metadata and parent chain; subtree ancestry and imported content |
| Source inference | K24/2D/S20/S24 family direction and p87-to-GF87 relationship; not a recovered parent edge |
| Developer convention | The three standalone mains use the original 100 v0.18-era root utilities for migration; historical runtime pairing remains unproved |
| Unresolved | Snapshot dates/immediate parents; S20/S24 basis/kernel provenance and reference outputs; standalone data, paths and static-source issues |

Packages with their own utilities retain those pairings. S20/S24 missing
basis files must not be substituted solely by matching names or dimensions.
Original v0.18 Fortran input recovery and shared-reader validation are now
complete as recorded in [input provenance](v018_input_contract.md); those
are no longer outstanding import blockers.

## Normalization and recovery

Current sources were promoted to `matlab/` and `fortran/` for `v0.18.0`.
The [normalization map](v018_normalization.md) and per-file manifest preserve
all retired paths and hashes. Recovery commit `c9ae729` contains the complete
pre-normalization source tree; local backups are supplementary safeguards.

```bash
git show c9ae729:matlab/history/snapshots/ACE_V020/ACE_V020_2D88ACEs.m
git show v0.18.0:docs/migration/matlab_import_plan.md
```

Historical large data may be LFS pointers: recover their objects using the
[LFS manifest](matlab_data_lfs_manifest.tsv), not a raw pointer/blob comparison.
The [LFS record](matlab_data_lfs_migration.md) preserves the completed rewrite
and local backup provenance. No import commands, history rewrites, tag moves
or remote updates are instructed by this record.
