# S20 active MATLAB staging

Status: preserved S20 utility staging from the earlier MATLAB-only layout work.
The current milestone is [unified v0.18 alignment](matlab_fortran_alignment_plan.md);
S20 becomes the scientific baseline only for the later v0.20 milestone.
The preserved package is `matlab/history/snapshots/ACE_V020/`; its driver is
`ACE_V020_2D88ACEs.m`. No S20 driver has been copied or adapted, and no S20
MATLAB run or numerical comparison has been performed.

The 27 previously committed WENO and thermodynamics functions match S20 byte
for byte. Two further byte-identical S20 copies,
`util_thermodynamics/inv_T_from_theta_e.m` and `util_timeint/ssprk93.m`, were
committed as byte-identical copies at `9a5b7c7` under
`matlab/active/thermodynamics/` and `matlab/active/time_integration/`.
Static call tracing finds these two as the remaining direct external functions
for the S20 driver; the existing utilities cover their named helper calls.
This is source-level evidence only, not a runtime dependency proof.

Keep the six other S20/S24 thermodynamics functions and the plume utilities in
history pending a supported caller. The S24 batch inversions and local terrain
integrator are not part of the selected S20 package. Do not mix the S24
`inv_T_from_theta_e.m` with the S20 driver; its bytes differ.

## Driver and validation gate

The S20 driver constructs `util_*` and `data/` paths from `pwd`, so copying it
into `matlab/active/` without adapting those paths would not create a runnable
package. Its default path loads `data/basis/COMPOSITE_ACE_BASIS_2D_V020.mat`
into the script workspace, including `D`, `PMB`, `PMD`, and `PMDv`. The basis
file is absent from this repository. The S20 builder depends on
`PRECOMPUTED_VERTICAL_MODES_2D.mat`, which is also absent. Its origin and
array ordering need review before generating or substituting a basis.

The default `arm=3` uses
`data/soundings/maoarmbeatmM1.c1.20140101.003000.nc` and `pidx=314`.
The developer confirmed that soundings are shared across versions; a copy is
preserved in the S19 package. No sounding has been copied into the active
tree. MATLAB and Octave are unavailable in this environment, and no matched
S20 reference output has been established.

When work reaches v0.20, review the S20 driver's path and output contracts as
a separate change. Before claiming behavior preservation, run the unchanged
S20 package with a
provenance-recorded basis and sounding, retain its output as a reference, then
compare an active-layout run with matching inputs and settings.
