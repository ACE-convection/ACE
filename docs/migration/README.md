# ACE migration records

Updated 2026-10-02. The migration and v0.18 source-root normalization are
complete. Local `main` contains the accepted release, and annotated tag
`v0.18.0` identifies `2b62c291b3ab4e3da7a822559d341e3183bc302b`.
The release has not been pushed to GitHub. Later documentation changes do
not move that tag.

## Start here

| Purpose | Authoritative document |
| --- | --- |
| Accepted v0.18 scope, results and retained limitations | [Release record](../releases/v0.18.0.md) |
| Current development sequence and joint MATLAB/Fortran milestones | [Roadmap](matlab_fortran_alignment_plan.md) |
| Run the fixed Manus reference cases | [Test instructions](../../tests/README.md) |
| Shared NetCDF schema and current input usage | [Shared input](../shared_input.md) |
| Source promotion, retired paths and recovery | [Normalization record](v018_normalization.md) and [per-file manifest](v018_normalization_manifest.json) |
| Historical import method and evidence boundaries | [Import record](matlab_import_plan.md) |
| Alignment changes and scientific evidence | [v0.18 alignment](v018_alignment.md) |
| Original data identities and binary record ordering | [Input provenance](v018_input_contract.md) |
| Historical LFS conversion and commit-ID translation | [LFS record](matlab_data_lfs_migration.md), [data manifest](matlab_data_lfs_manifest.tsv), [commit map](matlab_data_lfs_commit_map.csv) |

Current source/build instructions belong in [MATLAB](../../matlab/README.md)
and [Fortran](../../fortran/README.md). Migration documents should link to
those instructions instead of maintaining another set of commands.

## Evidence needed for later versions

These records preserve distinct findings. Their dates, tool availability,
pre-LFS commit IDs, `active/` and `history/` paths describe the investigation
at that time, rather than today's checkout or unresolved v0.18 release gates.

| Record | Reason to retain |
| --- | --- |
| [Historical inventory](matlab_inventory.md) | File identities, hashes, collection counts and presence/absence ledger |
| [Development lineage](matlab_lineage.md) | Confirmed ancestry, inferred relationships and scientific changes |
| [Version matrix](matlab_version_matrix.md) | Distinct drivers, configurations and incompatible utility APIs |
| [Driver dependencies](matlab_driver_dependencies.md) | Caller/library pairings, S20 input requirements and builder dependencies |
| [Utility inventory](matlab_shared_utility_inventory.md) | Cross-version byte identity and the former S20/S24 staging record |
| [Standalone readiness](matlab_validation_readiness.md) | Missing 2D basis inputs, explicit stops and debug dependencies |
| [p87 validation evidence](matlab_p87_validation_gate.md) | S24 kernel contracts, sounding identity and missing fingerprint logs |
| [Superseded S24 layout](matlab_active_layout_plan.md) | Historical file dispositions and variant-specific path contracts; not a layout to implement |

No historical source parent, runtime compatibility or numerical equivalence
is inferred from an import order, matching filename or snapshot label.

## Recover earlier records and source trees

The complete documentation before this consolidation is preserved at
`v0.18.0`. Historical source trees before normalization are preserved at
`c9ae729`; follow the normalization manifest for exact paths.

```bash
git show v0.18.0:docs/migration/matlab_fortran_alignment_plan.md
git show c9ae729:matlab/history/snapshots/ACE_V020/ACE_V020_2D88ACEs.m
```

For older pre-LFS IDs, first consult the commit map. Materializing historical
MAT/NC files also requires the corresponding LFS objects. No history rewrite,
source change or release-tag replacement is part of documentation cleanup.

## Documentation consolidation (2026-10-02)

The roadmap now states completed v0.18 work and later joint milestones.
Import, alignment and input records retain summaries, verified anchors and
links to their primary evidence; obsolete staging recipes and duplicated
pre-release gates remain recoverable from `v0.18.0`. The
[handoff](../v018_developer_handoff.md) uses current source roots and test
entry points.

The redundant `matlab_s20_active_stage.md` page was removed: its copy counts
and staging commit are retained in the utility inventory, and its dependency,
input and no-runtime-proof findings in the driver dependency map. Recover
its original text with
`git show v0.18.0:docs/migration/matlab_s20_active_stage.md`.
File identities, lineage/variant evidence, scientific reports, data manifests,
commit maps and the normalization manifest remain preserved.
