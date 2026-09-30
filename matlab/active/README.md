# MATLAB source staging

## Shared-input development state

The active driver now reads `../../data/input/manus208.nc` by default;
`ACE_INPUT_MODE=legacy` preserves the previous MAT/sounding input route.
See [shared input schema, conversion and validation](../../docs/shared_input.md).
Input conversion and reader initialization have been validated; full MATLAB
integration still requires the driver's existing Statistics Toolbox and
plotting dependencies. Historical snapshots remain unchanged. The staging
identity description below records the pre-reader-migration source state.


This directory is temporary migration/alignment scaffolding. After the
v0.18 gates pass, a separately reviewed normalization will promote the
validated source directly into `matlab/` before unified `v0.18.0` is tagged.
Historical and later-version copies remain recoverable through Git; the
permanent layout is defined by the roadmap below.

The current milestone is [unified v0.18 alignment](../../docs/migration/matlab_fortran_alignment_plan.md).
`ace.m` is a byte-identical copy of the October 2024 MATLAB v0.18 driver at
original Git commit `a0f30cd`; only its filename changed. Its 20 named
external utility dependencies under `util_weno/`, `util_plume/`, and
`util_thermodynamics/` are byte-identical copies from the same commit. These
directories form the v0.18 source candidate. The historical source is unchanged.
The original pre-LFS driver commit ID is recorded in the
[LFS commit map](../../docs/migration/matlab_data_lfs_commit_map.csv).

The separate `numerics/`, `thermodynamics/`, and `time_integration/` directories
contain utility copies staged from the later S20/S24 packages. They are
preserved for later milestones and are not dependencies of the v0.18 candidate.
See the [cross-version inventory](../../docs/migration/matlab_shared_utility_inventory.md)
and [S20 staging note](../../docs/migration/matlab_s20_active_stage.md) for
their identities and disposition. Do not add the entire `matlab/active/` tree
recursively to the MATLAB path: names and signatures overlap across versions.

The v0.18 driver derives `util_*` paths from `pwd` and expects the eight-ACE
basis and ARM soundings under `../data/` relative to `pwd`. Those inputs have
not been installed for this active tree. No path, constant, equation, or
numerical method has been changed in the source copies. The candidate has not
been run or compared with Fortran. Use the preserved `a0f30cd` source as the
reference for any later runtime adaptation, and review adaptations separately.

The original source contains trailing whitespace. It is retained in the
source copies to preserve byte identity.
