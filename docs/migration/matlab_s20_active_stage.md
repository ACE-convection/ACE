# Historical S20 MATLAB staging note

Classification: superseded MATLAB-only planning; redundant status detail has
been consolidated. The [unified roadmap](matlab_fortran_alignment_plan.md)
governs joint development. S20 is a scientific reference for the later joint
v0.20 publication/reproducibility milestone, not an independent permanent
MATLAB active baseline. The old `matlab/active/` destination was temporary.

The earlier staging retained 27 byte-identical S20/S24 WENO and thermodynamics
copies and added S20 `inv_T_from_theta_e.m` and `ssprk93.m` at `9a5b7c7`.
No S20 driver adaptation, run or numerical comparison was recorded.

Detailed evidence now has these owners:

- [Utility inventory](matlab_shared_utility_inventory.md): copy counts,
  cross-version identities, staging commit and unused/variant dispositions.
- [Driver dependency map](matlab_driver_dependencies.md#s20-package-input-and-validation-evidence):
  static dependency coverage, missing basis/builder input, `arm=3`/profile 314,
  shared-sounding convention, environment limits and reference-run requirement.

This short record is retained for existing links. It can be removed after
approval and link updates; its unique evidence has been consolidated above.
