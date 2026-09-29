# MATLAB historical import and preservation record

This is a record of the **pre-LFS import**. The MATLAB data migration later
rewrote the Git commits named below; their original IDs remain documented in
the [LFS commit map](matlab_data_lfs_commit_map.csv), and the original Git
graph is saved in the local pre-migration bundle. The original-ID preservation
claims below describe the import at that time, not the current Git refs.

Import status recorded 2026-09-24: source import complete; runtime validation remains open. Documentation consolidated 2026-09-30. The original Git history was joined at `141455d`. All 98 S19 files were committed through `b7b448b`, verified against the source archive, and marked with the annotated `matlab/snapshot/v0.19.3-k24` tag. The three standalone drivers were committed at `8ed7284` (D-1), `b3637f9` (D-2), and `d1bcc00` (D-3), with source bytes verified. All 52 S20 files were committed through `bb040f8`, verified against the source archive and committed Git blobs, and marked with the annotated `matlab/snapshot/v0.20-package` tag. All 50 S24 files were committed through `6af974b`, verified against the source archive and committed Git blobs, and marked with the annotated `matlab/snapshot/v0.24.87-p87-gf87` tag. The former command recipe has been condensed into the verification record below; completed migration commands must not be rerun blindly. The primary evidence is the [inventory](matlab_inventory.md), [version matrix](matlab_version_matrix.md), and [lineage report](matlab_lineage.md). Archive paths are relative to `migration_work/ACE_MATLAB/`, a read-only symlink to the historical working repository.

## Role and permanent architecture

This is the canonical record of how historical material was imported,
reconstructed, verified and preserved. The import stage is largely complete;
scientific validation is a separate, unfinished task. The
[alignment and release roadmap](matlab_fortran_alignment_plan.md) is the
primary forward plan, and the [index](README.md) identifies supporting records.

The `history/`, snapshot and `active/` trees were migration mechanisms.
Reconstructed snapshot commits preserve evidence and importer staging order;
they do not prescribe the permanent source layout. After v0.18 alignment and
validation, a separately reviewed normalization will place the current sources
directly under `matlab/` and `fortran/`, removing migration-only copies from the
current tree while preserving commits, ancestry, historical tags and provenance.
Imported material remains recoverable through Git after normalization. Retain
the current staging trees until that review and its validation gates pass.

This permanent architecture is a developer-defined decision on 2026-09-30.
The actual import facts, inferred lineage and earlier developer conventions
below retain their original meanings. From unified `v0.18.0` onward, one ACE
release commit contains both language implementations; archaeology must not
create separate post-v0.18 version histories.

## Import method and scope (completed)

The original `ace-matlab/main` history was joined with `git subtree add` **without `--squash`** under `matlab/history/original_git/`. At import time this made all ten original commits reachable, with their original object IDs, parents, authors, dates, messages, and unmodified trees. The subtree merge commit is a new ACE migration commit; the prefix exists in its tree, not in the original commit trees. The import rejected `git filter-repo`, prefix rewriting, cherry-picking and squashing because they would replace identities or omit individual historical commits. The later, separately documented LFS migration changed IDs as described above; it must not be repeated as part of normalization. A plain `git merge --allow-unrelated-histories` would preserve the commits but merge root-level `LICENSE`, `README.md`, and source paths into ACE, causing conflicts or an unsuitable layout. A manual `merge -s ours` followed by a copy could also preserve reachability, but obscures the mapping between the imported parent and the prefixed tree. The non-squashed subtree provides that mapping in one auditable merge.

The import record distinguishes three provenance layers:

| Layer | ACE location / ref | What it proves |
| --- | --- | --- |
| Authentic Git history | Original commits reachable through the subtree merge's second parent; `matlab/history/original_git/` is their tip tree | Actual ACE_MATLAB commit identities and historical content through v0.18; the prefix is an ACE layout decision |
| Reconstructed archive states | `matlab/history/snapshots/` and `matlab/history/standalone/`, several dependency-aware migration commits per collected package where supported | Exact archived bytes at each final anchor; intermediate commits are migration staging, **not** recovered historical states or ancestry |
| Interpretation and decisions | These migration documents and annotated tag messages | Inferred family relationships and the developer-defined root-utility baseline, explicitly distinguished from Git facts |

During import, the preservation rule was to retain historical paths, case and bytes, including mains, utilities, `.asv` files, binaries, line endings and old backup/test files. Packages were isolated under the temporary `matlab/history/` archive area so comparisons did not silently mix libraries. This describes migration staging; the permanent archive is Git history. Future source promotion must preserve historical objects and provenance while changing only the reviewed current tree. The three standalone mains have no copied utility tree: their assigned baseline is the **100 v0.18-era root utilities** in the original Git import, by developer-defined migration convention. That pairing does not prove the historical MATLAB working directory or runtime compatibility.

The original commits retain their **original root paths** internally. Consequently, `git log -- matlab/history/original_git/ace_v018_dev_8aces.m` alone does not enumerate the original edits. Follow the subtree join's second parent with `git log HEAD^2 -- ace_v018_dev_8aces.m` immediately after the join, or use the recorded original SHA and `git show <sha>:<original-path>` later. The prefix and annotated tags are navigation aids; neither rewrites the original trees.

## Reconstructed commit sequence and tags

The subtree join preserved the **ten original ACE_MATLAB commits** through `d9d50a8` unchanged at that time. The join is a new ACE migration commit. The original plan proposed `matlab/git/v0.16-source` (`b924022`), `matlab/git/v0.18-original` (`a328496`), and `matlab/git/v0.18-updated` (`5cc173a`) as source markers. These three proposed tags are absent from the local tag list inspected on 2026-09-30; do not describe their creation as completed. If introduced later, they would mark source milestones, not certified releases. Preserve all existing historical tags, including Fortran `v0.18`, with their existing meanings.

Each row below describes a **migration-reconstructed** commit containing exact files from an observed archive collection. All S19, standalone, S20 and S24 import rows are complete. The tables retain the original staging rationale and evidence limits; they are not a queue of commands to execute. Commit order expresses staging and dependency, **not** recovered historical chronology, a proven parent edge, or a previously runnable model. A transition heading names the collections compared in the lineage report. Do not create an intermediate version by editing or splicing main programs: their local time integration, dynamics, physics, and diagnostics are coupled and must enter as whole, unchanged files. The `No` in the runnable column means no execution claim is possible at that staging point. Even complete anchors have known data, path, or static-source limits and are not claimed runnable.

### v0.18 Git tip → collected S19 (`ACE_V019.3`)

The import placed all 98 supplied S19 files at `matlab/history/snapshots/ACE_V019.3/`. S19 is a separate archived collection; replacing v0.18 utilities in place would falsely imply verified ancestry and lose the original tip tree. Preserve experimental files, backups, binaries, and nested directories with their original bytes.

| Stage / original plan label | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S19-1 `matlab: archive S19 WENO collection` | All 17 `util_weno/` files; corrected vector k=4–6 weights and preserved variants. The scalar file has formatting-only changes. | Subtree join; no S19 driver yet. | No: library-only staging. |
| S19-2 `matlab: archive S19 thermodynamics collection` | All 31 `util_thermodynamics/` files; T0, qsat threshold, inversion and diagnostic changes remain together. | S19-1 for ordered staging only; no scientific dependency on WENO. | No: library-only staging. |
| S19-3 `matlab: archive S19 plume collection` | All 7 `util_plume/` files, including altered entrainment and alternate/backup routines. | S19-2 for ordered staging only; driver still absent. | No: library-only staging. |
| S19-4 `matlab: archive S19 basis and input collection` | All 37 `util_basis/` files and 5 `data/` files, including Heaviside bases, soundings, and experiments. Keep builders with their supplied data because binary provenance and call contracts are unverified. | S19-1–3 staged; S19 driver expects this collection. | No: driver absent; binary internals unvalidated. |
| S19-5 `matlab: archive S19 K24 driver` | Entire `ace_v019_K24_8aces.m`; local SSPRK, MF diffusion, dynamic-pressure choices, interpolation, configuration and diagnostics form one coupled file. Do not split by hunk. | S19-1–4; only then is the supplied collection complete. | Not demonstrated: source package has static call concerns. |

After S19-5, **the committed S19 tree** was verified against all 98 preserved files and marked with the annotated `matlab/snapshot/v0.19.3-k24` tag at `b7b448b`. “019.3” is a folder label, not an official release.

### Standalone development artifacts between S19 and S20

These are three separate, one-file commits under `matlab/history/standalone/`. Their placement here is a migration order, not a claim that the root K24 export experiment parents the 2D line. All three use the original v0.18-era root utilities **by developer-defined convention**, not a historically proven pairing. Do not duplicate or edit those utilities.

| Stage / original plan label | Purpose and files | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| D-1 `matlab: archive standalone K24 export experiment` | Root `ace_v019_K24_8aces.m` only; preserve the NetCDF export, unconditional stop, and latent science edits. | Original Git utility collection by convention; S19 only for comparison, not a proven parent. | No: unconditional stop and missing inputs. |
| D-2 `matlab: archive standalone v0.19 2D development` | Root `ace_v019_dev_2d88aces.m` only; 2D geometry, PMD/DHh forcing, local integrator and diagnostics remain coupled. | Original Git utilities by convention; K24 family relationship is inferred. | No: external data path and absent basis binary. |
| D-3 `matlab: archive standalone v0.20 2D development` | Root `ace_v020_dev_2d88aces.m` only; PMDv/dz2FH and configuration edits are preserved as one observed driver. | Original Git utilities by convention; D-2 is a strong source inference, not Git ancestry. | No: absent basis/debug dependency. |

The three committed files were verified against their inventory SHA-256 values, as recorded above. These experiments were not tagged as releases.

### S19 / standalone 2D → packaged S20 (`ACE_V020`)

The import placed all 52 supplied S20 files at `matlab/history/snapshots/ACE_V020/`. The S20 driver and libraries change APIs together; do not manufacture a runnable hybrid of S19 or standalone files with S20 utilities. In particular, S20's `*2` thermodynamic calls, external SSPRK interface, basis layout, and weighted MF projection must be reviewed as dependencies.

| Stage / original plan label | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S20-1 `matlab: archive S20 basis construction collection` | All 9 `util_basis/` files, including 2D builders, changed response-axis ordering, and uneven-grid experiments. Case-sensitive reconstruction helper name remains unchanged. | D-3 for comparison only; no proven immediate parent. | No: builders alone and requested basis binary absent. |
| S20-2 `matlab: archive S20 thermodynamics API collection` | All 37 `util_thermodynamics/` files; keep explicit-argument/`*2` APIs, theta_il/ice constants, inversion variants and GPU sample together. | S20-1 for staging only; S20 driver requires this API. | No: library-only staging. |
| S20-3 `matlab: archive S20 plume collection` | Both `util_plume/` files; fixed qc cap is scientifically material. | S20-2 for staging only; S20 driver remains absent. | No: library-only staging. |
| S20-4 `matlab: archive S20 WENO collection` | Both `util_weno/` files; vector algorithm already corrected in S19, with only comments changed here. | S20-3 for staging only; no new WENO correction inferred. | No: library-only staging. |
| S20-5 `matlab: archive S20 external time integrator` | `util_timeint/ssprk93.m` as a whole; weighted MF projection and fixed thermodynamic tendencies are coupled to its interface. | S20-1–4 staged; S20 driver calls this integrator. | No: driver absent. |
| S20-6 `matlab: archive packaged S20 driver` | Entire `ACE_V020_2D88ACEs.m`; ace-struct layout, PMDv input, reference buoyancy, integration call, physics and I/O cannot be safely split by hunk. | S20-1–5; only then is the supplied source package complete. | No: `data/` and requested basis are absent. |

After S20-6, **the committed S20 tree** was verified against all 52 preserved files and marked with `matlab/snapshot/v0.20-package`. This is a reconstructed package state, not a release or a claim that standalone D-3 was its direct parent.

Completed: S20-5 was committed at `9177f4d` and S20-6 at `bb040f8`. All 52 source, destination, and committed blob hashes matched. `git diff --cached --check` reported CRLF line endings and inherited trailing spaces in the two files; these were retained byte-for-byte. The annotated snapshot tag points to `bb040f8`.

### S20 family → S24 (`ACE_V024.87`)

The import placed all 50 supplied S24 files at `matlab/history/snapshots/ACE_V024.87/`. S24 replaces the basis formulation and embeds terrain-aware integration in the p87/GF87 mains. There is no evidence to reconstruct v0.21–v0.23 or an intermediate v0.24 main. The p87 and GF87 files coexist in one observed package; staging one before the other is a review order, not a recovered date.

| Stage / original plan label | Purpose and exact file area | Depends on | Runnable after this commit? |
| --- | --- | --- | --- |
| S24-1 `matlab: carry forward S24 shared utilities` | The 2 `util_plume/`, 2 `util_weno/`, and 1 `util_timeint/` files; byte-identical to S20, recorded explicitly for the S24 package. | S20 anchor for identity comparison; not a new algorithm. | No: support files only. |
| S24-2 `matlab: archive S24 slab Green kernels` | Both `util_basis/` files; K1/K2 construction and slab Green evaluation are one scientific dependency. Do not treat them as renames of S20 basis builders. | S24-1 for staging; p87/GF87 depend on these kernels and missing generated data. | No: generator/support only. |
| S24-3 `matlab: archive S24 CPU thermodynamic solvers` | 39 `util_thermodynamics/` files: scalar cap, warm/batch inversion and unchanged support files. Hold the separate GPU scalar helper for GF87. | S24-1–2 staged; p87 uses warm batch. | No: no driver or input data. |
| S24-4 `matlab: archive p87 terrain driver` | Entire `ACE_V024p87.m`; local periodic WENO, `ssprk93_topo`, terrain closure, Lamb momentum, viscosity/SGS options, checkpoints and diagnostics are interleaved. | S24-1–3; do not split local functions into imagined intermediate drivers. | No: S24 data absent; execution unverified. |
| S24-5 `matlab: archive GF87 GPU and FFT path` | `util_thermodynamics/inv_T_from_theta_e_gpu.m` and entire `ACE_V024GF87.m`; GPU scalar inversion, FFT/GPU tables, kernel application, device setup and closures form one dependency unit. | S24-1–4; p87-to-GF87 derivation is inferred, not a Git-confirmed parent. | No: S24 data absent; equivalence unverified. |
| S24-6 `matlab: archive S24 package description` | `README.md`, including the supplied p87/GF87 claims and references to absent data. | S24-4–5 so documentation describes both preserved mains. | No: documentation does not supply missing data. |

After S24-6, **the committed S24 tree** was verified against all 50 preserved files and marked with `matlab/snapshot/v0.24.87-p87-gf87`. One tag identifies the supplied two-main package. Do not add separate p87/GF87 release tags or claim CPU/GPU numerical equivalence.

Completed: S24-1 through S24-6 were committed at `f292580`, `1ed2aca`, `8287f78`, `6c39d84`, `cdb8067`, and `6af974b`. All 50 source, destination, and committed blob hashes matched. `git diff --cached --check` reported inherited CRLF line endings, trailing spaces, and blank lines at EOF in some source files; these were retained byte-for-byte. The annotated snapshot tag points to `6af974b`. No execution or numerical equivalence was tested.

All three `matlab/snapshot/*` tags are annotated **archive-state** tags pointing to cumulative ACE commits after complete-tree verification. They are not official release tags. Their messages must name the package path, provenance, and missing-data limits. Backups, tests, autosaves, alternate algorithms and intermediate migration commits remain development evidence without release tags.

## Completed procedure and verification record

The old executable copy/commit/tag recipe has been condensed here. Its full
pre-consolidation text is recoverable at
`af4d500:docs/migration/matlab_import_plan.md`. It described the pre-LFS refs
and archive paths; do not rerun it against the current repository. In
particular, Git blobs for migrated MAT/NC files are now LFS pointers and cannot
be compared directly with materialized data bytes using that old recipe.

- The plan used clean `migration/matlab-history` and `migration/matlab-import`
  branches, the existing `ace-matlab/main` ref (ten commits through
  `d9d50a8b45824c919ba8932b4cf8e7d9606d4bbc`), and the read-only
  `migration_work/ACE_MATLAB/` archive. The completed join is `141455d`.
- Its import identity checks compared the subtree merge's second parent with
  the imported tip and the prefixed tree ID with that parent's complete tree;
  the prefix did not alter paths inside the original commits.
- Archive paths and bytes were copied unchanged, with explicit staging for
  ignored `*.asv`, `*.nc` and `migration_work/` material. The dependency-aware
  stages above kept complete drivers intact and recorded inherited CRLF,
  trailing whitespace and EOF formatting rather than repairing source.
- Final-anchor verification compared archive and copied paths/bytes, expected
  file counts (98 S19, 52 S20, 50 S24), and each committed blob with its source.
  Standalone checks used the full SHA-256 values in the
  [inventory](matlab_inventory.md#main-program-identities). The completed
  verification results and anchor IDs are recorded above. Byte identity
  establishes preservation, not numerical equivalence.
- The original recipe also called for per-stage diff review, commit
  reachability, tag-target, `git fsck --no-reflogs` and final status checks.
  A prescribed check is not a numerical-validation result. Snapshot tag
  meanings retain package paths, provenance and missing-data limits.
- The earlier note about S19's 103,316,408-byte NetCDF and hosting limits
  predates the completed [LFS migration](matlab_data_lfs_migration.md).
  Its manifest and commit map now supply data-identity and ID-translation
  evidence. No further import, push or history rewrite is instructed here.

## Evidence boundaries and review gates

- **Git-confirmed:** Original parent chain, commit metadata, v0.16 and v0.18 tracked blobs, and root utility contents. Use `git show <original-sha>` for the original tree; the subtree merge introduces only a new ACE path and join commit. Do not present the subtree commit's author/date as those of the original work.
- **Inferred:** K24/2D/S20/S24 family direction and p87-to-GF87 derivation, as described in the lineage report. Their consecutive ACE migration commits only record the importer's ordering. Do not infer that K24 root export precedes or parents the 2D family.
- **Developer-defined:** Assign R, the original v0.18-era root utilities, to the three standalone mains. S19/S20/S24 retain their own utility collections. Archive directory names and tags identify observed states; none establishes release status.
- **Unresolved:** Historical dates and immediate parents of snapshots; missing basis/sounding data in S20/S24 and standalone states; binary MAT internals; hard-coded paths, static source issues, and scientific behavior. Reconstructing the source does not resolve these. Do not generate substitute data or normalize source during import.

The original import required review of its structural source/destination map under `AGENTS.md`. That completed import does not authorize the future normalization operation; its separate review and validation gates are specified in the alignment roadmap.

## Historical rollback policy

The import plan retained `migration/matlab-history` and its remote as the
starting reference, isolated work on `migration/matlab-import`, and preferred
an additive corrected branch over rewriting an incorrect import. Incorrect
committed states and tags were to remain available for diagnosis. Deleting a
branch could remove the only named pointer to unpushed evidence; deleting tags
would remove provenance labels; force pushing could replace shared history.
Those destructive actions required separate developer approval. This remains
a preservation rationale, not an instruction to replay the completed import.

## Documentation consolidation findings (2026-09-30)

The [index](README.md) classifies all migration records and related repository
documentation. The audit resolved stale planning language without changing
historical facts:

- S20/S24 imports were already complete despite a remaining "planned" sentence
  and copy/commit/tag recipe. Their counts, IDs, hash results and stage rationale
  remain above; obsolete operational repetition has been condensed.
- The S24 layout and S20-only active baseline are superseded planning
  assumptions. Their useful file map, utility identities, path contracts and
  missing-input evidence remain available in the linked historical records.
- The shared-utility inventory previously excluded `matlab/active/` from the
  v0.18 candidate even though `ace.m`/`util_*` had been staged. It now
  distinguishes those candidates from the later S20/S24 utility copies.
- Early inventory/lineage limitations on binary inspection are dated evidence.
  Later HDF5/NetCDF inspection in the v0.18 input contract adds evidence; it
  does not retrospectively turn the initial archaeology into a runtime test.
- Pre-LFS SHA references and current SHA references are different identity
  namespaces connected by the commit map. The already completed rewrite is a
  historical fact; future normalization must preserve current history and tags.
- The terminal `main` in the milestone sequence is the later joint development
  destination. Existing migration merges into `main` are validation baselines,
  not proof that the sequence or a unified release has been completed.

Open questions remain scientific or evidentiary: original Fortran binaries,
accepted differences/tolerances and numerical results for v0.18; the reviewed
path setup for normalization; S20/S24 basis provenance and missing reference
outputs; and unresolved snapshot dates/parents. The shared netCDF schema and
runtime interface are future design work. No missing historical states or
implementation steps have been invented to fill these gaps.
