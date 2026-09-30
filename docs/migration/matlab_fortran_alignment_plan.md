# Unified ACE alignment and release roadmap

Status: canonical forward roadmap, architecture clarified 2026-09-30.
v0.18 source candidates are staged; numerical validation and repository
normalization remain open. Historical import is largely complete; its facts
and verification record belong in the [import record](matlab_import_plan.md).
Start at the [documentation index](README.md) for document roles.

## Repository philosophy and development sequence

`matlab/active/`, `matlab/history/`, `fortran/active/`, and `fortran/history/`
are temporary migration/alignment scaffolding for archaeology, reconstruction,
comparison and validation. Keep them while v0.18 validation is unfinished.
The developer-defined post-migration architecture is:

```text
ACE/
  matlab/    # current MATLAB source
  fortran/   # current Fortran source
  data/      # shared runtime inputs; large data outside ordinary Git blobs
  tests/
  docs/
  tools/
```

From the first unified release onward, Git commits, branches and tags are the
historical archive. A checkout of the future `v0.18.0` tag must directly expose
the validated v0.18 implementations under `matlab/` and `fortran/`; a checkout
of the future `v0.20.0` tag must expose its corresponding pair in those same
roots. Neither checkout should require choosing between `active/` and
`history/`. These tags are release targets, not existing validated releases.

```text
historical archaeology / migration
    ↓
v0.18 MATLAB–Fortran alignment and validation
    ↓
separately reviewed repository normalization
    ↓
unified ACE v0.18.0 release
    ↓
normal joint MATLAB + Fortran development
    ↓
v0.19 alignment/development as needed
    ↓
v0.20.0 publication/reproducibility release
    ↓
joint development toward v0.24
    ↓
v0.24 unified active development
    ↓
main
```

**MATLAB and Fortran advance as one ACE repository history after v0.18.**
Each unified release tag identifies one commit containing the corresponding
reviewed implementations of both languages. Do not create separate post-v0.18
MATLAB-only and Fortran-only version histories. Shared dynamics require
comparison; Fortran-only physics can remain implementation-specific and must
be documented. File-by-file identity is not a release requirement.

The sequence describes milestone order. `main` can already hold a migration
or validation baseline; that alone establishes neither a unified release nor
scientific equivalence. The later v0.24 target becomes the joint active line
on `main` after review.

## Current milestone: v0.18 — first unified validated release

| Component | Pinned state | Current staging evidence |
| --- | --- | --- |
| MATLAB | Original October 2024 Git state `a0f30cd` (current LFS-era ID) | `matlab/active/ace.m` and 20 named utility dependencies are byte-identical copies, staged at `0d30268`. The driver retains `pwd` and `../data/` assumptions; runtime inputs have not been installed for this layout. |
| Fortran history | Original Git `ffdd734` | Non-squashed subtree merge `a870a67` preserves the history under `fortran/history/original_git/`, with `ffdd734` as a parent. Historical `v0.18` remains unchanged. |
| Fortran source | Original Git `ffdd734` | `fortran/active/makefile` and both `src/*.F` files are byte-identical copies, staged at `90c7a5e`. Original Intel compiler and binary input assumptions remain. |

The [v0.18 audit](v018_alignment.md) owns candidate selection, known source
and scientific differences, review dispositions, numerical gates and release
criteria. The January MATLAB `25d49e7` state and December Fortran `bb72a55`
alignment claim remain separate historical anchors. Neither replaces this
candidate pair. S20/S24 utility copies in other MATLAB staging subdirectories
are evidence for later milestones and must not enter the v0.18 runtime path.

Known differences include precipitation timing/onset and the `qt` clamp,
ice-inversion derivative and stopping behavior, WENO/upwind boundaries,
sponge behavior, state mapping and output precision. They require the focused
checks and explicit scientific decisions in the audit. Byte identity of a
staged copy establishes preservation only.

The [input contract](v018_input_contract.md) owns input hashes, provenance,
profile indexing and Fortran binary reads. The MATLAB eight-ACE basis and
Manus sounding are preserved through LFS. Original Fortran initialization and
PMB binaries have not been located; the extracted PMB is unverified. No matched
initial state, operator/one-step comparison, short run or active-layout run
has been completed. Tolerances remain unapproved. The
[developer handoff](../v018_developer_handoff.md) owns practical environment,
run and evidence-collection instructions.

### Validation, normalization and release gates

1. Review candidate identities and source differences using the audit.
   Recover original Fortran inputs or establish a reviewed, reproducible
   derivation; record hashes, units, profile indexing, array ordering, real
   kind, byte order and compiler record conventions. Validate compiler readback
   and compare the loaded MATLAB/Fortran initial states.
2. Validate preserved candidates and their staging copies with the reviewed
   inputs. Complete the audit's operator/one-step, short-run and budget gates;
   record quantitative tolerances, results, limitations and developer decisions
   for all known differences. Keep scientific corrections separately reviewed.
3. **After those gates pass, propose and obtain review of normalization.**
   Inventory the exact source promotion/removal map, runtime path effects and
   recovery refs. Promote the validated MATLAB source into `matlab/` and
   Fortran source into `fortran/`. Remove migration-only historical source
   copies and obsolete staging copies from the current tree; later S20/S24
   material remains recoverable from Git. Preserve all previous commits,
   imported histories, ancestry, historical tags and provenance. Keep useful
   migration documentation under `docs/migration/`. This is a separately
   authorized structural change, with no history rewrite.
4. Validate the normalized checkout: review any working-directory, build,
   dependency or I/O path adaptation, reproduce the agreed validation evidence
   with the same inputs/settings, and update run instructions to the new roots.
   Record old-to-new path mappings and verify historical source recovery by
   pinned commits/tags (plus LFS objects for historical data). Removal from the
   current tree must leave history accessible. Directory movement alone does
   not prove preserved behavior.
5. Only after the normalized state and its evidence are reviewed and meet the
   [release criteria](v018_alignment.md#unified-release-criteria), create the
   unified annotated `v0.18.0` tag on that single repository commit. Tagging
   requires developer authorization; no release tag is created by this plan.

## Later milestones — evidence-limited scope

**v0.19:** alignment/development as needed in the joint history after v0.18.0.
The preserved S19 and standalone artifacts are comparison evidence; their
order of import does not establish a missing historical parent or require a
separate release.

**v0.20:** publication/reproducibility release `v0.20.0`, containing matching,
reviewed MATLAB and Fortran states. The preserved packaged MATLAB S20 is the
scientific reference for that joint milestone. It is not a permanent independent
MATLAB baseline. Its basis and builder-input provenance remain unresolved;
the [dependency map](matlab_driver_dependencies.md) records the known contracts.
No detailed Fortran implementation plan is justified yet.

**v0.24:** later unified active-development target, reached through joint
MATLAB/Fortran development after v0.20. S24 p87/GF87 preserve formulation and
variant evidence. Missing intermediate history, inputs and reference logs
remain unresolved. The old S24 active-layout proposal is superseded; do not
adopt its directory map as the final structure or invent v0.21–v0.23 states.

## Historical markers versus unified release tags

| Marker | Meaning |
| --- | --- |
| `matlab/git/...` | Historical MATLAB source-marker namespace described in the import record; the proposed markers are not present in the locally inspected tag list on 2026-09-30. |
| `matlab/snapshot/v0.19.3-k24`, `matlab/snapshot/v0.20-package`, `matlab/snapshot/v0.24.87-p87-gf87` | Preserved, reconstructed archive states; S20's tag means the historical MATLAB S20 package. |
| Existing Fortran `v0.18` → `ffdd734` | Historical Fortran source marker, with its existing target and meaning. |
| Future `v0.18.0`, `v0.20.0` | Jointly reviewed and validated ACE repository states containing the corresponding MATLAB AND Fortran implementations under normalized source roots. |

Preserve historical tag targets and meanings; do not move or reinterpret them
as unified releases. The already completed [LFS migration](matlab_data_lfs_migration.md)
changed earlier MATLAB commit IDs; its [map](matlab_data_lfs_commit_map.csv)
connects pre-LFS evidence to current IDs. That completed operation does not
authorize another rewrite during normalization.

## Shared runtime data direction

The long-term architecture is `ACE/data/`, shared by both implementations,
with common netCDF inputs for basis/kernel data, soundings and initialization
where appropriate. Large runtime data should normally stay outside ordinary
Git blobs. Track schemas, manifests, checksums, documentation, conversion tools
and validation tools as appropriate. Existing historical LFS storage is a
preservation mechanism; it does not establish the future runtime interface.

The current v0.18 MAT/NetCDF and Fortran direct-access binary contracts remain
as documented evidence. Common netCDF conversion, schema design and runtime
interface changes need their own review and validation; they are not part of
this documentation update or automatically required by source normalization.
The exact normalized runtime path setup must be decided and validated during
that separately reviewed step.

### Shared case-input implementation update (2026-09-30)

The developer authorized shared NetCDF conversion and active-reader changes
on `feature/shared-netcdf-input`. The [case schema](../shared_input.md) and
[validation evidence](../shared_input_validation.json) now implement the
runtime direction above: recovered inputs agree exactly, converters demand
full equality, and each active implementation retains a legacy input route
for regression checks. This reviewed task scope supersedes the missing-input
and byte-identical-active-source descriptions for this branch only. It does
not authorize normalization, alter historical snapshots, or satisfy the
cross-implementation dynamics and unified release gates.
