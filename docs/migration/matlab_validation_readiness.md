# MATLAB standalone validation readiness

Status: static review on 2026-09-24. This records checks for the standalone
v0.19/v0.20 mains after source import; they are deferred while
[unified v0.18 alignment](matlab_fortran_alignment_plan.md) is the current
milestone. This does not certify execution or numerical equivalence. The three
standalone mains are paired with `matlab/history/original_git/` utilities by
developer convention, not by recovered runtime provenance. Historical files
were not edited.

## Input provenance and immediate blockers

| Main | Required input or action in source | Evidence in the imported tree | Status |
| --- | --- | --- | --- |
| `ace_v019_K24_8aces.m` | `data/basis/COMPOSITE_ACE_BASIS_Heaviside_7ACEs.mat` and `data/soundings/acelevels_*.nc`; then NetCDF export | The named basis exists only in the S19 snapshot, not in R. No `acelevels_*.nc` is present. An unconditional `error("test")` follows NetCDF creation and precedes model initialization. | The assigned R layout cannot run this main as supplied. Copying the S19 basis would be a separate, unverified provenance decision; the explicit stop remains. |
| `ace_v019_dev_2d88aces.m` | Hard-coded `C:\Users\r9822\Dropbox\JULIACE\data\`, `COMPOSITE_ACE_BASIS_2D.mat`, and ARM/GoAmazon soundings | The basis and soundings are absent. S19 has a builder for the named basis, but its prerequisite `PRECOMPUTED_VERTICAL_MODES_MCStepBASIS_2D.mat` is absent. | Input provenance and layout must be recovered before execution. |
| `ace_v020_dev_2d88aces.m` | Hard-coded `C:\Users\yhkuo\Dropbox\JULIACE\data\`, the same named 2D basis and soundings; `V019_DEBUG` after saving output | The basis and soundings are absent; no `V019_DEBUG.m` is present. S20 has a builder, but its prerequisite `PRECOMPUTED_VERTICAL_MODES_2D.mat` is absent. | Inputs block startup; `V019_DEBUG` is an additional post-run failure with the default `save_output = 1`. |

The two 2D builders produce the **same output filename** but use different source modes and basis constructions. A filename match does not establish that either output is the historical file used by either standalone driver. The S19 collection script saves `A` and `ADX` into its 2D vertical-modes file, while the S19 composite builder also uses `ADV`; that input is not supplied by the named saved file. S20's collection script does save `ADV`. Do not generate or substitute a 2D basis until the intended builder version, input files, dimensions, and PMB/PMDv/PMD orientation are reviewed.

## R utility interface check

The R tree contains the directly referenced WENO, plume, and thermodynamics functions. Its `eval_Tv(T,q,qc)` accepts two arguments by setting `qc=0`; `eval_qsat(T,p,qt,T0)` has two- and three-argument branches; `eval_q(e,p,qt)` has a two-argument branch; and `inv_T_from_theta_e(theta_e,qt,p,ABS_TOL)` defaults its fourth argument. Thus the selected R versions support the argument counts seen in the standalone mains. This is only a signature check. Array shapes, branch behavior, convergence, and scientific agreement remain untested. The drivers derive utility paths from `pwd`, so running a file from `matlab/history/standalone/` alone does not activate the assigned R utilities.

## Evidence and next validation gate

- Standalone inputs and stops: `matlab/history/standalone/ace_v019_K24_8aces.m` lines 2–39 and 80–82; `ace_v019_dev_2d88aces.m` lines 2–34; `ace_v020_dev_2d88aces.m` lines 2–42 and 270–278.
- Builder chain: `matlab/history/snapshots/ACE_V019.3/util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES.m` lines 34–63 and `PRECOMPUTE_COMPOSITE_ACE_BASIS_2D.m` lines 1–23, 91; S20 `util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES_2D.m` lines 1–54 and `PRECOMPUTE_COMPOSITE_ACE_BASIS_2D.m` lines 1–5, 136.
- R interfaces: `matlab/history/original_git/util_thermodynamics/{eval_Tv,eval_qsat,eval_q,inv_T_from_theta_e}.m` and `util_weno/{reconstruction_weno_vec,reconstruction_up3}.m`.

Ask the original developers for the exact basis and sounding files, their hashes or source archives, the working directories and MATLAB versions used, and which 2D builder generated each driver's basis. For K24, clarify whether the S19 basis was intentionally reused and whether the NetCDF export stop marks the intended endpoint. Once inputs are identified, perform runtime checks in isolated copies with explicit paths and matched data. MATLAB and Octave were not available in this review environment, so no simulation was run.
