# MATLAB data Git LFS migration

Role: historical-only storage/provenance record. The completed rewrite below
must not be rerun for repository normalization. Preserve the commit map,
manifest and current historical refs. Future shared runtime data architecture
is defined by the [roadmap](matlab_fortran_alignment_plan.md); LFS storage
does not establish a common runtime input interface. Manifest paths refer to
the migration tree and remain historical evidence after source normalization.

Status: verified Git LFS migration, 2026-09-29. The 17 files in the
MATLAB historical `data/` directories retain their paths and contents in a
Git LFS checkout. Normal Git history stores LFS pointers for their content.
The [manifest](matlab_data_lfs_manifest.tsv) records every current file's path,
byte count, and SHA-256; the [commit map](matlab_data_lfs_commit_map.csv) maps
the 64 rewritten commit IDs from the repository state before this migration.

The affected paths are the original MATLAB Git history's `data/` directory,
`matlab/history/original_git/data/`, and
`matlab/history/snapshots/ACE_V019.3/data/`. The first is an ancestral Git
path, not a current working-tree directory. The migration included that path
so a checkout of the rewritten MATLAB history does not expose the old binary
blobs. It excluded the historical Fortran `v0.18` tag and its ancestors;
that tag still points to `ffdd734`.

The pre-migration local `main` was `378457f`. Immediately after the scoped LFS
rewrite it was `6ab39c7`. The only root-tree changes at that point were the
new `.gitattributes` and the 17 data files becoming LFS pointers. All 17 LFS
objects were checked against their pre-migration SHA-256 and size; the LFS
integrity check passed. An independent pre-migration Git bundle, data tar, and
their hashes are retained locally under the ignored
`migration_work/lfs_backup/` directory. They are not part of the repository.

Many earlier migration reports intentionally name the **pre-LFS historical
commit IDs**. Those IDs describe the original source-history evidence and are
not expected to resolve in a fresh clone of the rewritten repository. Use the
commit map to find the corresponding current ID. The original commit graph
and content remain available in the local pre-migration bundle; the rewritten
graph retains the same development lineage with data content represented by
LFS pointers. Source-code bytes outside the data paths were not changed by
this migration.

Git LFS is required to materialize the data after cloning. Run `git lfs pull`
in a checkout; a client without Git LFS may see pointer text instead of MAT or
NetCDF bytes. The `matlab/active/` driver still needs its historical input
paths configured separately, and no MATLAB–Fortran numerical agreement is
implied by this storage migration.

Rewriting branch and tag refs removes old data blobs from their current Git
histories. Previously pushed objects may remain accessible through old SHA
links, caches, forks, or other clones until GitHub prunes them; permanent
erasure from GitHub cannot be guaranteed for these non-sensitive data files.
