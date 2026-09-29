# MATLAB history import plan

This is a record of the **pre-LFS import**. The MATLAB data migration later
rewrote the Git commits named below; their original IDs remain documented in
the [LFS commit map](matlab_data_lfs_commit_map.csv), and the original Git
graph is saved in the local pre-migration bundle. The original-ID preservation
claims below describe the import at that time, not the current Git refs.

Status: source import complete, updated 2026-09-24; runtime validation remains open. The original Git history was joined at `141455d`. All 98 S19 files were committed through `b7b448b`, verified against the source archive, and marked with the annotated `matlab/snapshot/v0.19.3-k24` tag. The three standalone drivers were committed at `8ed7284` (D-1), `b3637f9` (D-2), and `d1bcc00` (D-3), with source bytes verified. All 52 S20 files were committed through `bb040f8`, verified against the source archive and committed Git blobs, and marked with the annotated `matlab/snapshot/v0.20-package` tag. All 50 S24 files were committed through `6af974b`, verified against the source archive and committed Git blobs, and marked with the annotated `matlab/snapshot/v0.24.87-p87-gf87` tag. The command blocks below are a migration record; do not rerun completed steps. The primary evidence is the [inventory](matlab_inventory.md), [version matrix](matlab_version_matrix.md), and [lineage report](matlab_lineage.md). Archive paths are relative to `migration_work/ACE_MATLAB/`, a read-only symlink to the historical working repository.

## Recommendation and scope

The original `ace-matlab/main` history was joined with `git subtree add` **without `--squash`** under `matlab/history/original_git/`. This makes all ten original commits reachable, with their original object IDs, parents, authors, dates, messages, and unmodified trees. The subtree merge commit is a new ACE migration commit; the prefix exists in its tree, not in the original commit trees. Do not use `git filter-repo`, a prefix-rewriting import, cherry-pick, or a squashed subtree: each would replace the original commit identities or omit the individual historical commits. A plain `git merge --allow-unrelated-histories` would preserve the commits but merge root-level `LICENSE`, `README.md`, and source paths into ACE, causing conflicts or an unsuitable layout. A manual `merge -s ours` followed by a copy could also preserve reachability, but obscures the mapping between the imported parent and the prefixed tree. The non-squashed subtree provides that mapping in one auditable merge.

The import should have three provenance layers:

| Layer | ACE location / ref | What it proves |
| --- | --- | --- |
| Authentic Git history | Original commits reachable through the subtree merge's second parent; `matlab/history/original_git/` is their tip tree | Actual ACE_MATLAB commit identities and historical content through v0.18; the prefix is an ACE layout decision |
| Reconstructed archive states | `matlab/history/snapshots/` and `matlab/history/standalone/`, several dependency-aware migration commits per collected package where supported | Exact archived bytes at each final anchor; intermediate commits are migration staging, **not** recovered historical states or ancestry |
| Interpretation and decisions | These migration documents and annotated tag messages | Inferred family relationships and the developer-defined root-utility baseline, explicitly distinguished from Git facts |

Keep the historical paths and case exactly as found. Do not rename or normalize mains, utilities, `.asv` files, binaries, line endings, or old backup/test files. Do not put these copies in the active `matlab/` program root; `matlab/history/` is an inert archive area. No historical source will be edited. Keep each source package in its own directory so a comparison never silently mixes libraries. The three standalone mains have no copied utility tree: their assigned baseline is the **100 v0.18-era root utilities** in the original Git import, by developer-defined migration convention. That pairing does not prove the historical MATLAB working directory or runtime compatibility.

The original commits retain their **original root paths** internally. Consequently, `git log -- matlab/history/original_git/ace_v018_dev_8aces.m` alone does not enumerate the original edits. Follow the subtree join's second parent with `git log HEAD^2 -- ace_v018_dev_8aces.m` immediately after the join, or use the recorded original SHA and `git show <sha>:<original-path>` later. The prefix and annotated tags are navigation aids; neither rewrites the original trees.

## Reconstructed commit sequence and tags

The subtree join first preserves the **ten original ACE_MATLAB commits** through `d9d50a8` unchanged. The join is a new ACE migration commit. Tag the original objects `matlab/git/v0.16-source` (`b924022`), `matlab/git/v0.18-original` (`a328496`), and `matlab/git/v0.18-updated` (`5cc173a`). These are source milestones, not certified releases; the existing ACE tag `v0.18` must not be reused or moved.

Each row below describes a **migration-reconstructed** commit containing exact files from an observed archive collection. The S19 and standalone rows are complete; subsequent rows remain planned. Commit order expresses staging and dependency, **not** recovered historical chronology, a proven parent edge, or a previously runnable model. A transition heading names the collections compared in the lineage report. Do not create an intermediate version by editing or splicing main programs: their local time integration, dynamics, physics, and diagnostics are coupled and must enter as whole, unchanged files. The `No` in the runnable column means no execution claim is possible at that staging point. Even complete anchors have known data, path, or static-source limits and are not claimed runnable.

### v0.18 Git tip → collected S19 (`ACE_V019.3`)

Place all 98 supplied S19 files at `matlab/history/snapshots/ACE_V019.3/`. S19 is a separate archived collection; replacing v0.18 utilities in place would falsely imply verified ancestry and lose the original tip tree. Preserve experimental files, backups, binaries, and nested directories with their original bytes.

| ID / proposed message | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S19-1 `matlab: archive S19 WENO collection` | All 17 `util_weno/` files; corrected vector k=4–6 weights and preserved variants. The scalar file has formatting-only changes. | Subtree join; no S19 driver yet. | No: library-only staging. |
| S19-2 `matlab: archive S19 thermodynamics collection` | All 31 `util_thermodynamics/` files; T0, qsat threshold, inversion and diagnostic changes remain together. | S19-1 for ordered staging only; no scientific dependency on WENO. | No: library-only staging. |
| S19-3 `matlab: archive S19 plume collection` | All 7 `util_plume/` files, including altered entrainment and alternate/backup routines. | S19-2 for ordered staging only; driver still absent. | No: library-only staging. |
| S19-4 `matlab: archive S19 basis and input collection` | All 37 `util_basis/` files and 5 `data/` files, including Heaviside bases, soundings, and experiments. Keep builders with their supplied data because binary provenance and call contracts are unverified. | S19-1–3 staged; S19 driver expects this collection. | No: driver absent; binary internals unvalidated. |
| S19-5 `matlab: archive S19 K24 driver` | Entire `ace_v019_K24_8aces.m`; local SSPRK, MF diffusion, dynamic-pressure choices, interpolation, configuration and diagnostics form one coupled file. Do not split by hunk. | S19-1–4; only then is the supplied collection complete. | Not demonstrated: source package has static call concerns. |

After S19-5, verify **the committed S19 tree** against all 98 preserved files, then create the annotated `matlab/snapshot/v0.19.3-k24` tag. “019.3” is a folder label, not an official release.

### Standalone development artifacts between S19 and S20

These are three separate, one-file commits under `matlab/history/standalone/`. Their placement here is a migration order, not a claim that the root K24 export experiment parents the 2D line. All three use the original v0.18-era root utilities **by developer-defined convention**, not a historically proven pairing. Do not duplicate or edit those utilities.

| ID / proposed message | Purpose and files | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| D-1 `matlab: archive standalone K24 export experiment` | Root `ace_v019_K24_8aces.m` only; preserve the NetCDF export, unconditional stop, and latent science edits. | Original Git utility collection by convention; S19 only for comparison, not a proven parent. | No: unconditional stop and missing inputs. |
| D-2 `matlab: archive standalone v0.19 2D development` | Root `ace_v019_dev_2d88aces.m` only; 2D geometry, PMD/DHh forcing, local integrator and diagnostics remain coupled. | Original Git utilities by convention; K24 family relationship is inferred. | No: external data path and absent basis binary. |
| D-3 `matlab: archive standalone v0.20 2D development` | Root `ace_v020_dev_2d88aces.m` only; PMDv/dz2FH and configuration edits are preserved as one observed driver. | Original Git utilities by convention; D-2 is a strong source inference, not Git ancestry. | No: absent basis/debug dependency. |

Verify each committed file's Git blob against its inventory SHA-256. Do not tag these experiments as releases.

### S19 / standalone 2D → packaged S20 (`ACE_V020`)

Place all 52 supplied S20 files at `matlab/history/snapshots/ACE_V020/`. The S20 driver and libraries change APIs together; do not manufacture a runnable hybrid of S19 or standalone files with S20 utilities. In particular, S20's `*2` thermodynamic calls, external SSPRK interface, basis layout, and weighted MF projection must be reviewed as dependencies.

| ID / proposed message | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S20-1 `matlab: archive S20 basis construction collection` | All 9 `util_basis/` files, including 2D builders, changed response-axis ordering, and uneven-grid experiments. Case-sensitive reconstruction helper name remains unchanged. | D-3 for comparison only; no proven immediate parent. | No: builders alone and requested basis binary absent. |
| S20-2 `matlab: archive S20 thermodynamics API collection` | All 37 `util_thermodynamics/` files; keep explicit-argument/`*2` APIs, theta_il/ice constants, inversion variants and GPU sample together. | S20-1 for staging only; S20 driver requires this API. | No: library-only staging. |
| S20-3 `matlab: archive S20 plume collection` | Both `util_plume/` files; fixed qc cap is scientifically material. | S20-2 for staging only; S20 driver remains absent. | No: library-only staging. |
| S20-4 `matlab: archive S20 WENO collection` | Both `util_weno/` files; vector algorithm already corrected in S19, with only comments changed here. | S20-3 for staging only; no new WENO correction inferred. | No: library-only staging. |
| S20-5 `matlab: archive S20 external time integrator` | `util_timeint/ssprk93.m` as a whole; weighted MF projection and fixed thermodynamic tendencies are coupled to its interface. | S20-1–4 staged; S20 driver calls this integrator. | No: driver absent. |
| S20-6 `matlab: archive packaged S20 driver` | Entire `ACE_V020_2D88ACEs.m`; ace-struct layout, PMDv input, reference buoyancy, integration call, physics and I/O cannot be safely split by hunk. | S20-1–5; only then is the supplied source package complete. | No: `data/` and requested basis are absent. |

After S20-6, verify **the committed S20 tree** against all 52 preserved files, then tag `matlab/snapshot/v0.20-package`. This is a reconstructed package state, not a release or a claim that standalone D-3 was its direct parent.

Completed: S20-5 was committed at `9177f4d` and S20-6 at `bb040f8`. All 52 source, destination, and committed blob hashes matched. `git diff --cached --check` reported CRLF line endings and inherited trailing spaces in the two files; these were retained byte-for-byte. The annotated snapshot tag points to `bb040f8`.

### S20 family → S24 (`ACE_V024.87`)

Place all 50 supplied S24 files at `matlab/history/snapshots/ACE_V024.87/`. S24 replaces the basis formulation and embeds terrain-aware integration in the p87/GF87 mains. There is no evidence to reconstruct v0.21–v0.23 or an intermediate v0.24 main. The p87 and GF87 files coexist in one observed package; staging one before the other is a review order, not a recovered date.

| ID / proposed message | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S24-1 `matlab: carry forward S24 shared utilities` | The 2 `util_plume/`, 2 `util_weno/`, and 1 `util_timeint/` files; byte-identical to S20, recorded explicitly for the S24 package. | S20 anchor for identity comparison; not a new algorithm. | No: support files only. |
| S24-2 `matlab: archive S24 slab Green kernels` | Both `util_basis/` files; K1/K2 construction and slab Green evaluation are one scientific dependency. Do not treat them as renames of S20 basis builders. | S24-1 for staging; p87/GF87 depend on these kernels and missing generated data. | No: generator/support only. |
| S24-3 `matlab: archive S24 CPU thermodynamic solvers` | 39 `util_thermodynamics/` files: scalar cap, warm/batch inversion and unchanged support files. Hold the separate GPU scalar helper for GF87. | S24-1–2 staged; p87 uses warm batch. | No: no driver or input data. |
| S24-4 `matlab: archive p87 terrain driver` | Entire `ACE_V024p87.m`; local periodic WENO, `ssprk93_topo`, terrain closure, Lamb momentum, viscosity/SGS options, checkpoints and diagnostics are interleaved. | S24-1–3; do not split local functions into imagined intermediate drivers. | No: S24 data absent; execution unverified. |
| S24-5 `matlab: archive GF87 GPU and FFT path` | `util_thermodynamics/inv_T_from_theta_e_gpu.m` and entire `ACE_V024GF87.m`; GPU scalar inversion, FFT/GPU tables, kernel application, device setup and closures form one dependency unit. | S24-1–4; p87-to-GF87 derivation is inferred, not a Git-confirmed parent. | No: S24 data absent; equivalence unverified. |
| S24-6 `matlab: archive S24 package description` | `README.md`, including the supplied p87/GF87 claims and references to absent data. | S24-4–5 so documentation describes both preserved mains. | No: documentation does not supply missing data. |

After S24-6, verify **the committed S24 tree** against all 50 preserved files, then tag `matlab/snapshot/v0.24.87-p87-gf87`. One tag identifies the supplied two-main package. Do not add separate p87/GF87 release tags or claim CPU/GPU numerical equivalence.

Completed: S24-1 through S24-6 were committed at `f292580`, `1ed2aca`, `8287f78`, `6c39d84`, `cdb8067`, and `6af974b`. All 50 source, destination, and committed blob hashes matched. `git diff --cached --check` reported inherited CRLF line endings, trailing spaces, and blank lines at EOF in some source files; these were retained byte-for-byte. The annotated snapshot tag points to `6af974b`. No execution or numerical equivalence was tested.

All three `matlab/snapshot/*` tags are annotated **archive-state** tags pointing to cumulative ACE commits after complete-tree verification. They are not official release tags. Their messages must name the package path, provenance, and missing-data limits. Backups, tests, autosaves, alternate algorithms and intermediate migration commits remain development evidence without release tags.

## Preconditions and proposed commands — **do not run yet**

These commands assume execution from the ACE repository root on a clean `migration/matlab-history` branch after this plan has been reviewed and committed by the developer. A separate `migration/matlab-import` branch keeps the import reviewable. They use the already-present `ace-matlab/main` remote-tracking ref and the same archive path inventoried in the reports. Before copying, resolve any later ref/archive change by repeating identity checks; do not silently switch inputs. The `*.asv`, `*.nc`, and `migration_work/` ignore rules mean archived contents must be staged explicitly with `git add -f`.

Run the blocks interactively and stop at the first failed check or unexpected diff. Do not paste the entire sequence into a shell without reviewing each staged state and obtaining the required approval for commits/tags.

```bash
# Read-only preflight; stop if anything differs from the documented baseline.
git status --short --branch
test -z "$(git status --porcelain)"
git rev-parse ace-matlab/main
git rev-list --count ace-matlab/main
git tag --list 'matlab/*'
git ls-tree -r --name-only HEAD matlab/history
test "$(git rev-parse ace-matlab/main)" = d9d50a8b45824c919ba8932b4cf8e7d9606d4bbc
test "$(git rev-list --count ace-matlab/main)" = 10
test -d migration_work/ACE_MATLAB/ACE_V019.3
test -d migration_work/ACE_MATLAB/ACE_V020
test -d migration_work/ACE_MATLAB/ACE_V024.87

# After explicit approval: create a review branch and join the unaltered Git DAG.
git switch -c migration/matlab-import
git subtree add --prefix=matlab/history/original_git ace-matlab/main -m 'matlab: join original ACE_MATLAB Git history'
git rev-list --count ace-matlab/main
git merge-base --is-ancestor d9d50a8b45824c919ba8932b4cf8e7d9606d4bbc HEAD
git rev-parse HEAD^2
test "$(git rev-parse HEAD:matlab/history/original_git)" = "$(git rev-parse ace-matlab/main^{tree})"
```

The tree-ID check compares all imported bytes, including binaries, without rewriting original commits.

```bash
# Verify the subtree join before moving on.
test "$(git rev-parse HEAD^2)" = "$(git rev-parse ace-matlab/main)"
test "$(git rev-parse HEAD:matlab/history/original_git)" = "$(git rev-parse ace-matlab/main^{tree})"

# Tag authentic source milestones; names are deliberately outside release space.
git tag -a matlab/git/v0.16-source b924022aef4f48797c12b405c012737cd8a9aa2f -m 'Git-confirmed v0.16 source plus basis; original ACE_MATLAB commit, not certified release'
git tag -a matlab/git/v0.18-original a328496a5f2e43d44a60b90712e2becdc6313918 -m 'Git-confirmed first v0.18 main; original ACE_MATLAB commit, not certified release'
git tag -a matlab/git/v0.18-updated 5cc173a3d2c633cb3c5e10cc54890b19e6250beb -m 'Git-confirmed January v0.18 source update; not certified release'

# Define once for each anchor: compare source files, committed paths, and Git blobs.
verify_anchor () {
    local src="$1" dest="$2" expected="$3" file rel
    test -z "$(find "$src" -type l -print -quit)" || return 1
    diff -qr "$src" "$dest" || return 1
    test "$(find "$src" -type f | wc -l)" -eq "$expected" || return 1
    test "$(git ls-tree -r --name-only "HEAD:$dest" | wc -l)" -eq "$expected" || return 1
    while IFS= read -r -d '' file; do
        rel="${file#"$src"/}"
        test "$(git rev-parse "HEAD:$dest/$rel")" = "$(git hash-object -- "$file")" || return 1
    done < <(find "$src" -type f -print0)
}

# S19: copy exact source bytes once; stage one logical collection per commit.
s19=matlab/history/snapshots/ACE_V019.3
mkdir -p "$s19"
cp -a migration_work/ACE_MATLAB/ACE_V019.3/. "$s19/"
git add -f -A -- "$s19/util_weno"
git commit -m 'matlab: archive S19 WENO collection'
git add -f -A -- "$s19/util_thermodynamics"
git commit -m 'matlab: archive S19 thermodynamics collection'
git add -f -A -- "$s19/util_plume"
git commit -m 'matlab: archive S19 plume collection'
git add -f -A -- "$s19/util_basis" "$s19/data"
git commit -m 'matlab: archive S19 basis and input collection'
git add -f -- "$s19/ace_v019_K24_8aces.m"
git commit -m 'matlab: archive S19 K24 driver'
verify_anchor migration_work/ACE_MATLAB/ACE_V019.3 "$s19" 98
git tag -a matlab/snapshot/v0.19.3-k24 HEAD -m 'Reconstructed S19 archive state at matlab/history/snapshots/ACE_V019.3; 019.3 is folder label, not certified release'

# Three standalone development mains; utilities remain in original_git by convention.
mkdir -p matlab/history/standalone
cp -a migration_work/ACE_MATLAB/ace_v019_K24_8aces.m matlab/history/standalone/
test "$(sha256sum matlab/history/standalone/ace_v019_K24_8aces.m | cut -d ' ' -f 1)" = d338d4b1724720015853e6405d8bb863f3d1b86d906a5bad033190cdbfa98371
git add -f -- matlab/history/standalone/ace_v019_K24_8aces.m
git commit -m 'matlab: archive standalone K24 export experiment'
test "$(git show HEAD:matlab/history/standalone/ace_v019_K24_8aces.m | sha256sum | cut -d ' ' -f 1)" = d338d4b1724720015853e6405d8bb863f3d1b86d906a5bad033190cdbfa98371
cp -a migration_work/ACE_MATLAB/ace_v019_dev_2d88aces.m matlab/history/standalone/
test "$(sha256sum matlab/history/standalone/ace_v019_dev_2d88aces.m | cut -d ' ' -f 1)" = 06f67c523580373dc540a4f64952d6e98bd6224158889887e7e903ac3c45fde2
git add -f -- matlab/history/standalone/ace_v019_dev_2d88aces.m
git commit -m 'matlab: archive standalone v0.19 2D development'
test "$(git show HEAD:matlab/history/standalone/ace_v019_dev_2d88aces.m | sha256sum | cut -d ' ' -f 1)" = 06f67c523580373dc540a4f64952d6e98bd6224158889887e7e903ac3c45fde2
cp -a migration_work/ACE_MATLAB/ace_v020_dev_2d88aces.m matlab/history/standalone/
test "$(sha256sum matlab/history/standalone/ace_v020_dev_2d88aces.m | cut -d ' ' -f 1)" = 71b7e2a95c7597adc1f2697ed00537e02edfdcab0d1c80b7f314e93dc176299c
git add -f -- matlab/history/standalone/ace_v020_dev_2d88aces.m
git commit -m 'matlab: archive standalone v0.20 2D development'
test "$(git show HEAD:matlab/history/standalone/ace_v020_dev_2d88aces.m | sha256sum | cut -d ' ' -f 1)" = 71b7e2a95c7597adc1f2697ed00537e02edfdcab0d1c80b7f314e93dc176299c

# S20: its API and basis collection must be complete before the driver enters.
s20=matlab/history/snapshots/ACE_V020
mkdir -p "$s20"
cp -a migration_work/ACE_MATLAB/ACE_V020/. "$s20/"
git add -f -A -- "$s20/util_basis"
git commit -m 'matlab: archive S20 basis construction collection'
git add -f -A -- "$s20/util_thermodynamics"
git commit -m 'matlab: archive S20 thermodynamics API collection'
git add -f -A -- "$s20/util_plume"
git commit -m 'matlab: archive S20 plume collection'
git add -f -A -- "$s20/util_weno"
git commit -m 'matlab: archive S20 WENO collection'
git add -f -A -- "$s20/util_timeint"
git commit -m 'matlab: archive S20 external time integrator'
git add -f -- "$s20/ACE_V020_2D88ACEs.m"
git commit -m 'matlab: archive packaged S20 driver'
verify_anchor migration_work/ACE_MATLAB/ACE_V020 "$s20" 52
git tag -a matlab/snapshot/v0.20-package HEAD -m 'Reconstructed S20 package at matlab/history/snapshots/ACE_V020; archive lacks data directory; not certified release'

# S24: shared support, kernel/thermo dependencies, whole drivers, then README.
s24=matlab/history/snapshots/ACE_V024.87
mkdir -p "$s24"
cp -a migration_work/ACE_MATLAB/ACE_V024.87/. "$s24/"
git add -f -A -- "$s24/util_plume" "$s24/util_timeint" "$s24/util_weno"
git commit -m 'matlab: carry forward S24 shared utilities'
git add -f -A -- "$s24/util_basis"
git commit -m 'matlab: archive S24 slab Green kernels'
for file in "$s24"/util_thermodynamics/*; do
    test "$file" = "$s24/util_thermodynamics/inv_T_from_theta_e_gpu.m" || git add -f -- "$file"
done
git commit -m 'matlab: archive S24 CPU thermodynamic solvers'
git add -f -- "$s24/ACE_V024p87.m"
git commit -m 'matlab: archive p87 terrain driver'
git add -f -- "$s24/util_thermodynamics/inv_T_from_theta_e_gpu.m" "$s24/ACE_V024GF87.m"
git commit -m 'matlab: archive GF87 GPU and FFT path'
git add -f -- "$s24/README.md"
git commit -m 'matlab: archive S24 package description'
verify_anchor migration_work/ACE_MATLAB/ACE_V024.87 "$s24" 50
git tag -a matlab/snapshot/v0.24.87-p87-gf87 HEAD -m 'Reconstructed S24 package with p87 and GF87 at matlab/history/snapshots/ACE_V024.87; data absent; not certified release'
```

Before **every** `git commit` above, pause after `git add` and inspect `git diff --cached --name-status`, `git diff --cached --stat`, and `git diff --cached --check`. Confirm the staged paths match the corresponding table row, then run that commit command. The blocks are individual review steps, not a script to paste wholesale. Historical whitespace findings from `--check` must be recorded, not silently repaired. A failed check or unexpected staged path stops the sequence. Do not amend preserved source to make an intermediate commit runnable.

The `verify_anchor` function compares the copied directory with the archive, checks the file count in the committed tree, and compares **every committed Git blob** to the preserved file. Run it only after the final commit for each package and before tagging. The D-1/D-2/D-3 checks above compare both working copies and committed blobs with their inventory SHA-256 values. After all anchors, verify `git fsck --no-reflogs`, original commit reachability, tag targets, and `git status --short --branch`. Byte identity establishes preservation, not numerical equivalence or runnability. S19 contains a 103,316,408-byte NetCDF file, close to common hosting limits; check remote policy before any push. No push is part of this plan.

## Evidence boundaries and review gates

- **Git-confirmed:** Original parent chain, commit metadata, v0.16 and v0.18 tracked blobs, and root utility contents. Use `git show <original-sha>` for the original tree; the subtree merge introduces only a new ACE path and join commit. Do not present the subtree commit's author/date as those of the original work.
- **Inferred:** K24/2D/S20/S24 family direction and p87-to-GF87 derivation, as described in the lineage report. Their consecutive ACE migration commits only record the importer's ordering. Do not infer that K24 root export precedes or parents the 2D family.
- **Developer-defined:** Assign R, the original v0.18-era root utilities, to the three standalone mains. S19/S20/S24 retain their own utility collections. Archive directory names and tags identify observed states; none establishes release status.
- **Unresolved:** Historical dates and immediate parents of snapshots; missing basis/sounding data in S20/S24 and standalone states; binary MAT internals; hard-coded paths, static source issues, and scientific behavior. Reconstructing the source does not resolve these. Do not generate substitute data or normalize source during import.

Before executing the import, the developer should approve the **large structural import** and this exact source/destination map, as required by `AGENTS.md`. The first approved import operation should be creating `migration/matlab-import` and performing the non-squashed subtree join, then checking its second parent and tree identity before any snapshot copy. Treat each later reconstructed commit as a separate review point.

## Rollback if the import is wrong

Capture the starting ACE commit (`git rev-parse HEAD`) before import and keep `migration/matlab-history` and its remote unchanged. All proposed import work is on `migration/matlab-import`; no push, force push, source deletion, or rewrite is planned. If a copied state is wrong **before its commit**, correct the staging copy or stop for review; never alter the archive source. If a committed import is wrong, retain the branch for diagnosis, create a corrected import branch from the original starting commit, and replay only approved steps. This additive path preserves evidence and avoids changing shared history.

Deleting the import branch, hard-resetting it, removing newly created tags, or rewriting/pushing shared history would be destructive and needs separate explicit developer approval. A local branch deletion would discard its only named pointer and may make unpushed migration commits hard to find; deleting tags would remove provenance labels; a force push could replace shared remote history. The safer alternative is to leave the incorrect branch/tags in place with a documented superseded status until the corrected branch is verified. If anything was already pushed, use a new corrective branch and review/merge process rather than rewriting the shared remote.
