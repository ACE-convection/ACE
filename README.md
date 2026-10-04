# ACE

ACE (Anelastic Convective Entity) is a cloud-resolving numerical model developed for studying atmospheric convection and related dynamical and physical processes.

This repository is the main development repository for ACE. It is intended to consolidate and maintain the MATLAB and Fortran implementations of the model within a common development framework.

## Implementations

ACE currently has two implementations with different roles:

- **MATLAB** — the primary implementation used for development and testing of the model dynamics.
- **Fortran** — a high-performance implementation intended for larger numerical experiments and for supporting additional physical parameterizations.

The two implementations share the same core model formulation, but they are not necessarily identical in all physical parameterizations. A major goal of this repository is to maintain consistency between the shared components of the MATLAB and Fortran implementations and to provide systematic tests for their numerical agreement.

The developer accepted the current MATLAB/Fortran v0.18 alignment on
2026-10-02 using the Manus singleACE and twelve-hour multiACE comparisons.
The [v0.18.0 release record](docs/releases/v0.18.0.md) defines the accepted
scope and retained limitations. Current sources are directly under
[`matlab/`](matlab/README.md) and [`fortran/`](fortran/README.md).

Developers running the accepted cases should start with the
[test instructions](tests/README.md) and [shared-input instructions](docs/shared_input.md).
The [migration index](docs/migration/README.md) identifies current guidance
and the historical evidence needed for later versions.

The [canonical initial runtime test](tests/README.md) for v0.18 and later
v0.20/v0.24 comparisons is Manus 208: a single ACE, a saturated +1 K bubble
at levels 11–51, precipitation disabled, and three hours of integration.
Its pinned input, MF reference and reproducible test entry are preserved;
comparison uses error metrics and scientific review rather than byte equality.

Historical MATLAB `data/` files use Git LFS. Install Git LFS and run
`git lfs pull` after cloning to obtain the MAT and NetCDF contents; see the
[migration and provenance record](docs/migration/matlab_data_lfs_migration.md).

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
state. Future `v0.20.0` likewise identifies both implementations; MATLAB and
Fortran advance together in one ACE history.

Git commits, branches and tags preserve historical versions after migration-only
source copies leave the current tree. Existing historical tags keep their
provenance meanings. Shared `ACE/data/` and common netCDF runtime inputs are
the long-term direction; large inputs should not be ordinary Git blobs.
The [shared NetCDF interface](docs/shared_input.md) is implemented and tested;
historical binary contracts remain provenance and legacy-read references.
Refactoring and repository restructuring remain separate from scientific changes.

## P3 microphysics

Integration of the **Predicted Particle Properties (P3) microphysics scheme**
developed by Morrison, Milbrandt, and collaborators is planned for ACE v0.20.
The current v0.18 Fortran implementation uses native simplified precipitation
and does not include an integrated P3 scheme.

The current upstream P3 source code is maintained separately at the
[P3-microphysics repository](https://github.com/P3-microphysics/P3-microphysics).

P3 is a third-party component and is not considered part of the ACE code covered by the ACE license unless explicitly stated. The exact P3 version used by ACE and any ACE-specific interface or modifications will be documented separately.

## License

The ACE source code is distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See `LICENSE` for details.

Third-party components may be subject to separate licensing and attribution requirements.
