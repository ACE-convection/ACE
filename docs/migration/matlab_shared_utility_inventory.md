# MATLAB utility identity and activation

Static inventory, updated 2026-09-28. Compare the preserved utility trees in
`matlab/history/original_git/` (R), `ACE_V019.3/` (S19), `ACE_V020/` (S20), and
`ACE_V024.87/` (S24). "Same" below means byte-identical files at the same
relative path; it does not establish equivalent drivers or model results.
The S20 copies are preserved staging for a later milestone. The current
milestone is [unified v0.18 alignment](matlab_fortran_alignment_plan.md), using
its historical candidate source states rather than `matlab/active/`.
Driver-level calls and input paths are mapped in
[`matlab_driver_dependencies.md`](matlab_driver_dependencies.md).

| Utility group | R / S19 / S20 / S24 identity | Current disposition |
| --- | --- | --- |
| 12 active files: `reconstruction_up3`, `ci`, `eval_B`, `eval_dTes`, `eval_es`, `eval_esi`, `eval_rho`, `eval_theta`, `eval_theta_e`, `eval_theta_l`, `eval_theta_v`, `lv` | Same in all four trees | Byte-identical copies in `matlab/active/`. This is the complete callable S24 thermodynamics subset with four-tree identity. |
| 15 other active files: `reconstruction_weno_vec`, `IMPORT_CONSTANTS_NOGLOBAL`, `eval_Tv`, `eval_dTqs`, `eval_dTqsi`, `eval_esscl`, `eval_q`, `eval_q2`, `eval_qs`, `eval_qs2`, `eval_qsat`, `eval_qsat2`, `eval_qsi`, `eval_qsi2`, `eval_theta_es` | Same in S20 and S24; different or absent in R/S19 | Byte-identical copies in `matlab/active/`. The two saturation derivatives are called by both S20 and S24 inversions. |
| S20 `inv_T_from_theta_e` | Differs from S24 | Byte-identical S20 copy committed under `matlab/active/thermodynamics/` at `b09e19a`. Required by the preserved S20 driver for the later v0.20 milestone. |
| 6 remaining S20/S24 thermodynamics functions: `eval_dTqsscl`, `eval_h`, `eval_qsscl`, `eval_theta_il`, `inv_T_from_h`, `inv_T_from_theta_il` | Same in S20 and S24; different or absent in R/S19 | Keep in history pending a supported caller. |
| S24 `inv_T_batch`, `inv_T_batch_warm`, `inv_T_from_theta_e` | S24 differs from or adds to S20 | Keep in history. The p87 driver directly uses `inv_T_batch_warm`; its diagnostic path calls its own `inv_T_from_theta_e`. |
| `cin_cape_calc` | Same in all four trees | Keep in history: no direct call was found in the S20 or S24 drivers. This does not establish that the utility is obsolete. |
| `entrain_plume_calc` | Same in S20 and S24; different or absent in R/S19 | Keep in history pending a supported caller. An S19 local plume routine calls its version; neither S20 nor S24 driver directly calls this external function. |
| `ssprk93` | Same in S20 and S24; different or absent in R/S19 | Byte-identical S20 copy committed under `matlab/active/time_integration/` at `b09e19a`. The preserved S20 driver passes it by function handle. S24 drivers use local `ssprk93_topo`. |
| `V024p87_CONSTRUCT_KERNELS`, `util_layergreen` | S24 only | Version-specific offline basis construction; keep in history pending a chosen driver and data contract. |

The S24 thermodynamics files `IMPORT_CONSTANTS.m`, `NOTE.m`,
`gputest_invTq.m`, `inv_T_from_theta_e_gpu.m`, and
`inv_T_from_theta_e_nogpu.m` have separate dispositions in
[`matlab_active_layout_plan.md`](matlab_active_layout_plan.md). The first two
are byte-identical across all four trees but are a global-constant script and
a comment-only note, respectively, not callable active utilities. The GPU
inversion belongs to the optional accelerated driver; the test artifacts and
comparison inversion remain in history.

No source file in history was modified or removed for this inventory.
