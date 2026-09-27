# MATLAB utility identity and activation

Static inventory, 2026-09-26. Compare the preserved utility trees in
`matlab/history/original_git/` (R), `ACE_V019.3/` (S19), `ACE_V020/` (S20), and
`ACE_V024.87/` (S24). "Same" below means byte-identical files at the same
relative path; it does not establish equivalent drivers or model results.
The developer will select a version for runtime testing after code organization.
Driver-level calls and input paths are mapped in
[`matlab_driver_dependencies.md`](matlab_driver_dependencies.md).

| Utility group | R / S19 / S20 / S24 identity | Current disposition |
| --- | --- | --- |
| 12 active files: `reconstruction_up3`, `ci`, `eval_B`, `eval_dTes`, `eval_es`, `eval_esi`, `eval_rho`, `eval_theta`, `eval_theta_e`, `eval_theta_l`, `eval_theta_v`, `lv` | Same in all four trees | Byte-identical copies in `matlab/active/`. This is the complete callable S24 thermodynamics subset with four-tree identity. |
| 13 other active files: `reconstruction_weno_vec`, `IMPORT_CONSTANTS_NOGLOBAL`, `eval_Tv`, `eval_esscl`, `eval_q`, `eval_q2`, `eval_qs`, `eval_qs2`, `eval_qsat`, `eval_qsat2`, `eval_qsi`, `eval_qsi2`, `eval_theta_es` | Same in S20 and S24; different or absent in R/S19 | Existing byte-identical copies in `matlab/active/`. Treat these as S20/S24-family utilities until a driver is chosen. |
| 8 remaining S20/S24 thermodynamics functions: `eval_dTqs`, `eval_dTqsi`, `eval_dTqsscl`, `eval_h`, `eval_qsscl`, `eval_theta_il`, `inv_T_from_h`, `inv_T_from_theta_il` | Same in S20 and S24; different or absent in R/S19 | Keep in history until the selected driver and its inversion dependencies are known. |
| 3 S24 thermodynamics functions: `inv_T_batch`, `inv_T_batch_warm`, `inv_T_from_theta_e` | S24 differs from or adds to S20 | Keep in history. The p87 driver directly uses `inv_T_batch_warm`; its diagnostic path calls `inv_T_from_theta_e`. |
| `cin_cape_calc` | Same in all four trees | Keep in history: no direct call was found in the S20 or S24 drivers. This does not establish that the utility is obsolete. |
| `entrain_plume_calc` | Same in S20 and S24; different or absent in R/S19 | Keep in history pending a supported caller. An S19 local plume routine calls its version; neither S20 nor S24 driver directly calls this external function. |
| `ssprk93` | Same in S20 and S24; different or absent in R/S19 | S20 calls the external function. S24 drivers use their local `ssprk93_topo` and refer to `ssprk93` as a reference. Keep the external file historical until an active caller is selected. |
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
