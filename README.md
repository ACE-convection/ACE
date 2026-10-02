# ACE

ACE (Anelastic Convective Entity) is a cloud-resolving numerical model developed for studying atmospheric convection and related dynamical and physical processes.

This repository is the main development repository for ACE. It is intended to consolidate and maintain the MATLAB and Fortran implementations of the model within a common development framework.

## Implementations

ACE currently has two implementations with different roles:

- **MATLAB** — the primary implementation used for development and testing of the model dynamics.
- **Fortran** — a high-performance implementation intended for larger numerical experiments and for supporting additional physical parameterizations.

The two implementations share the same core model formulation, but they are not necessarily identical in all physical parameterizations. A major goal of this repository is to maintain consistency between the shared components of the MATLAB and Fortran implementations and to provide systematic tests for their numerical agreement.

The current development milestone is [unified v0.18 alignment](docs/migration/matlab_fortran_alignment_plan.md). MATLAB and Fortran v0.18 source candidates are staged for validation; their scientific differences, required inputs, and numerical agreement remain under review. Earlier MATLAB S20/S24 utility staging is preserved for later milestones and is not the v0.18 validation source.

Developers continuing v0.18 testing on another machine should start with the
[v0.18 developer handoff](docs/v018_developer_handoff.md) for the current
progress, input blockers, environment checks, and validation order.

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

This repository is therefore currently being reorganized to:

- reconstruct and document the historical development of ACE;
- establish a consistent source-code structure;
- maintain MATLAB and Fortran implementations together;
- distinguish shared model dynamics from implementation-specific physics;
- establish regression and cross-implementation tests; and
- provide a reproducible basis for future ACE development.

The [migration documentation index](docs/migration/README.md) distinguishes
current guidance from historical evidence. The current `matlab/active/`,
`matlab/history/`, `fortran/active/` and `fortran/history/` directories are
temporary scaffolding. After v0.18 validation, a separately reviewed and
validated normalization will place current sources directly in `matlab/` and
`fortran/`, alongside shared `data/`, `tests/`, `docs/` and `tools/`. Only then
can one repository commit containing both implementations become unified
`v0.18.0`. Future `v0.20.0` likewise identifies both implementations; MATLAB
and Fortran advance together in one ACE history.

Git commits, branches and tags preserve historical versions after migration-only
source copies leave the current tree. Existing historical tags keep their
provenance meanings. Shared `ACE/data/` and common netCDF runtime inputs are
the long-term direction; large inputs should not be ordinary Git blobs.
Historical input contracts remain in effect pending separate interface review.
Refactoring and repository restructuring remain separate from scientific changes.

## P3 microphysics

The Fortran implementation of ACE can use the **Predicted Particle Properties (P3) microphysics scheme** developed by Morrison, Milbrandt, and collaborators.

The current upstream P3 source code is maintained separately at the
[P3-microphysics repository](https://github.com/P3-microphysics/P3-microphysics).

P3 is a third-party component and is not considered part of the ACE code covered by the ACE license unless explicitly stated. The exact P3 version used by ACE and any ACE-specific interface or modifications will be documented separately.

## License

The ACE source code is distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See `LICENSE` for details.

Third-party components may be subject to separate licensing and attribution requirements.
