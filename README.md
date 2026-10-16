# ACE

ACE (Anelastic Convective Entity) is a cloud-resolving numerical model developed for studying atmospheric convection and related dynamical and physical processes.

This repository is the main development repository for ACE. It is intended to consolidate and maintain the MATLAB and Fortran implementations of the model within a common development framework.

## Implementations

ACE currently has two implementations with different roles:

- **MATLAB** — the primary implementation used for development and testing of the model dynamics.
- **Fortran** — a high-performance implementation intended for larger numerical experiments and for supporting additional physical parameterizations.

The two implementations share the same core model formulation, but they are not necessarily identical in all physical parameterizations. A major goal of this repository is to maintain consistency between the shared components of the MATLAB and Fortran implementations and to provide systematic tests for their numerical agreement.

The `v0.20.87` milestone adds the behavior-preserving Fortran `ace_t` OOP
refactor and preserves the original Fortran repository's Git history.
Native/P3 multiACE three-hour states, normal output and precipitation records
match the accepted Fortran references bit-for-bit. See the
[v0.20.87 release notes](docs/releases/v0.20.87-notes.md) for evidence and
retained lifecycle limits.

The accepted `v0.20.0` scientific baseline contains the author-selected November 2025
KHN26 MATLAB implementation, aligned Fortran native dynamics and the
Fortran-only P3 5.3.1 integration. The developer accepted the observed
three-hour evolution and precipitation differences on 2026-10-12.
[Release notes](docs/releases/v0.20.0-notes.md) define the tested GNU real64
scope, known differences and unresolved issues. The dt=6 s, six-hour driver
defaults are distinct from the tested dt=4 s, +1 K, three-hour cases.

The `v0.21.87` milestone selects an 88-ACE GOAmazon
case, enables supplied DHh/DHv and uses an eight-hour default. Initialization
and precipitation ordering remain unchanged. The developer accepted the
eight-hour native results and response plots on 2026-10-15;
see [release notes](docs/releases/v0.21.87-notes.md) and
[the slab tests](tests/slab/README.md). The accepted older tags remain intact.

Current sources are directly under [`matlab/`](matlab/README.md) and
[`fortran/`](fortran/README.md). The default shared input is `data/input/goamazon314_88aces.nc` with all three
supplied operators; the older 101-ACE Manaus input remains available with
both momentum switches disabled. Minute precipitation
accumulation is available through the diagnostic runner, rather than as a
new production-driver default. P3 requires external lookup data.
The previous [v0.18.0 release](docs/releases/v0.18.0.md) remains available
for its accepted Manus and mixed-precision configuration.

Developers running the accepted cases should start with the
[test instructions](tests/README.md) and [shared-input instructions](docs/shared_input.md).
The [migration index](docs/migration/README.md) identifies current guidance
and the historical evidence needed for later versions.

For the consolidated record through v0.21.87, see the
[history and results summary](docs/maintenance/history_summary.md) and
[version-by-version test inventory](docs/maintenance/version_test_matrix.md).
The inventory includes recorded configurations, incomplete attempts and local
reference dependencies. Superseded narrative reports have been consolidated;
raw scientific references remain preserved. The 39 retired report paths were
removed from the reviewed local histories; local release tag IDs changed.
The [rewrite record](docs/maintenance/history_rewrite.json) and
[commit map](docs/maintenance/history_commit_map.tsv) preserve traceability.
The reviewed histories have been synchronized to the existing remote branches
and four release tags; see the [publication record](docs/maintenance/remote_sync.json).

The [canonical initial runtime test](tests/README.md) for v0.18 and later
v0.20/v0.24 comparisons is Manus 208: a single ACE, a saturated +1 K bubble
at levels 11–51, precipitation disabled, and three hours of integration.
Its pinned input, MF reference and reproducible test entry are preserved;
comparison uses error metrics and scientific review rather than byte equality.

Historical MATLAB `data/` files use Git LFS. Install Git LFS and run
`git lfs pull` after cloning to obtain the MAT and NetCDF contents; see the
[migration and provenance record](docs/migration/matlab_data_lfs_migration.md).

From v0.21 onward, basis payloads are local-only and are not distributed in
Git or Git LFS. Obtain the basis and the shared NetCDF containing its response
operators separately, placing them at the documented `data/` paths. Provenance,
hashes and conversion tools remain versioned. The materializer can reconstruct
inputs from separately supplied local parts; matching existing inputs are
verified and differing files are never overwritten. Earlier published history
introduced after v0.20.87 is removed from the rewritten release history;
pre-v0.21 historical inputs remain unchanged.

## Repository reorganization

ACE has historically been developed through a series of MATLAB and Fortran code snapshots. Earlier MATLAB versions were not maintained using a systematic Git-based versioning workflow.

The completed migration established a framework to:

- reconstruct and document the historical development of ACE;
- establish a consistent source-code structure;
- maintain MATLAB and Fortran implementations together;
- distinguish shared model dynamics from implementation-specific physics;
- establish regression and cross-implementation tests; and
- provide a reproducible basis for future ACE development.

The [normalization record](docs/migration/v018_normalization.md) maps the
former staging paths to the source roots and records historical recovery.
Migration-only `active/` and `history/` source copies leave the current tree;
Git preserves their commits, imported ancestry and provenance. The unified
`v0.18.0` tag identifies both implementations in one normalized repository
state. `v0.20.0` likewise identifies both implementations; MATLAB and
Fortran advance together in one ACE history.

Git commits, branches and tags preserve historical versions after migration-only
source copies leave the current tree. Existing historical tags keep their
provenance meanings. Shared `ACE/data/` and common netCDF runtime inputs are
the long-term direction; large inputs should not be ordinary Git blobs.
The [shared NetCDF interface](docs/shared_input.md) is implemented and tested;
historical binary contracts remain provenance and legacy-read references.
Refactoring and repository restructuring remain separate from scientific changes.

## P3 microphysics

The **Predicted Particle Properties (P3) microphysics scheme** developed by
Morrison, Milbrandt, and collaborators is included in ACE v0.20.0 for Fortran.
The historical P3 5.3.1 module and ACE wrapper completed the documented
three-hour cases. Known dry/warm edge-case failures remain unresolved;
see the release notes for the accepted scope and external lookup dependency.
The v0.18 Fortran implementation uses native simplified precipitation.

The current upstream P3 source code is maintained separately at the
[P3-microphysics repository](https://github.com/P3-microphysics/P3-microphysics).

P3 is a third-party component and is not considered part of the ACE code covered by the ACE license unless explicitly stated. The exact P3 version used by ACE and any ACE-specific interface or modifications will be documented separately.

## License

The ACE source code is distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See `LICENSE` for details.

Third-party components may be subject to separate licensing and attribution requirements.
