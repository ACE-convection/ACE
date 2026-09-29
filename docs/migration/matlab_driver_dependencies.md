# MATLAB driver dependency map

Static source review, updated 2026-09-28. The current milestone is
[unified v0.18 alignment](matlab_fortran_alignment_plan.md); the S20 utility
staging described here is deferred to the v0.20 milestone. This map records
utility calls written in the preserved drivers and their input paths. Direct calls include
local-function bodies, conditional branches, function handles such as
`@ssprk93`, and constant-import scripts. Utility-to-utility calls were followed
by matching names in the paired library. This is a source-level dependency
map, not proof that every branch runs or that name scanning catches dynamic
dispatch. No driver has been validated through this map alone.

## Direct external calls by driver

| Driver / paired library | Direct thermodynamics and constants | Other direct external calls / integration |
| --- | --- | --- |
| R v0.16 / original Git utilities | `IMPORT_CONSTANTS`, `eval_Tv`, `eval_es`, `eval_q`, `eval_qsat`, `eval_theta`, `eval_theta_e`, `eval_theta_es`, `inv_T_from_theta_e` | `reconstruction_weno`; `entrain_plume_calc` in a local plume helper; local time integration. |
| R v0.18 / original Git utilities | Same direct thermodynamics as v0.16 | `reconstruction_weno`, `reconstruction_up3`, `reconstruction_weno_vec`; `entrain_plume_calc` in a local plume helper; local time integration. |
| S19 K24 / S19 utilities | Same direct thermodynamics as R | `reconstruction_up3`, `reconstruction_weno_vec`; `entrain_plume_calc` in a local plume helper; local time integration. |
| S20 packaged / S20 utilities | `IMPORT_CONSTANTS_NOGLOBAL`, `eval_B`, `eval_Tv`, `eval_es`, `eval_q2`, `eval_qsat`, `eval_qsat2`, `eval_theta`, `eval_theta_e`, `eval_theta_es`, `inv_T_from_theta_e` | `reconstruction_up3`, `reconstruction_weno_vec`; external `ssprk93` passed by function handle. No direct external plume call found. |
| S24 p87 / S24 utilities | Same S20 direct set except `inv_T_batch_warm` is added; `inv_T_from_theta_e` remains in the diagnostic path | `reconstruction_up3`, `reconstruction_weno_vec`; local `ssprk93_topo`. No direct external plume or `ssprk93` call found. |
| S24 GF87 / S24 utilities | Same as p87, plus `inv_T_from_theta_e_gpu` in the optional GPU path | Same external WENO calls and local terrain integrator family as p87. |

The three standalone v0.19/v0.20 mains have the same observed direct utility
names as S19 K24. By the developer's documented migration convention they are
paired with the original Git utility tree, not with the S19 package. Their
input/path blockers are recorded separately in
[`matlab_validation_readiness.md`](matlab_validation_readiness.md).

Following direct calls through the paired utility files adds `ci`, `lv`,
`eval_dTqs`, `eval_dTqsi`, `eval_esi`, `eval_qs`, and `eval_qsi` to the older
R/S19 call chains. For S20/S24, the scan also reaches `eval_q`, `eval_qs2`,
and `eval_qsi2` through saturation helpers. S24's `inv_T_batch_warm` reaches
`inv_T_batch`; GF87 also needs the GPU inversion when that branch is chosen.
These are static call-chain observations, not an execution trace.

The reviewed S20 staging has the observed external call chain, including its
`inv_T_from_theta_e` and external `ssprk93`; both are committed copies. The
S20 package is not runnable because its driver, path setup, and runtime inputs
are absent. The separate v0.18 candidate is staged under `matlab/active/ace.m`
and `matlab/active/util_*` from original Git `a0f30cd`; its own runtime inputs
remain unresolved. The S24 p87 chain still needs
its paired
`inv_T_batch`, `inv_T_batch_warm`, and `inv_T_from_theta_e` (GF87 additionally
needs the GPU inversion). Older R/S19 drivers require their own versions of changed APIs,
including the global constants script and scalar inversion. Do not fill these
gaps by matching filenames across versions.

## Working-directory and input contracts

| Driver family | Paths constructed by source | Basis contract |
| --- | --- | --- |
| Original Git v0.16/v0.18 | Utility folders beneath `pwd`; basis and soundings beneath `pwd/../data/`. This differs from the preserved `matlab/history/original_git/data/` location. | `COMPOSITE_ACE_BASIS_8ACEs.mat`; loads variables into the script workspace. |
| S19 K24 | Utility folders and `data/` beneath `pwd`. | Default `COMPOSITE_ACE_BASIS_Heaviside_4ACEs.mat` despite the main filename containing `8aces`. |
| S20 packaged | Utility folders and `data/` beneath `pwd`. | `COMPOSITE_ACE_BASIS_2D_V020.mat`; the default initial path loads its variables into the script workspace. |
| S24 p87/GF87 | Utility folders and `data/` beneath `pwd`; `KFILE` can override the basis path. | Default `COMPOSITE_ACE_BASIS_2D_V024_dx=500m_NT=30.mat`; loads `PMB_trunc`, `K2_trunc`, and checked `params`. |

All listed families construct an ARM sounding path. The developer confirmed
that sounding files are shared across versions; this does not make the basis
files interchangeable. The standalone mains use additional paths and input
contracts described in the validation-readiness document. Keep driver-local
functions inside their preserved scripts until a version is selected; moving
them would change call or workspace boundaries and requires separate review.
