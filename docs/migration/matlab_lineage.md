# MATLAB development lineage reconstruction

Inspected 2026-09-23. This report separates Git ancestry, source-code inference, developer-defined migration decisions, and unresolved historical relationships. All archive source paths are relative to `migration_work/ACE_MATLAB/`. File identities, complete presence/absence lists, and Git trees are in [inventory](matlab_inventory.md); each distinguishable driver state is in [version matrix](matlab_version_matrix.md).

## Confirmed lineage

### The Git sequence ends at v0.18 source

The ten commits reachable from `ace-matlab/main` form one linear Git chain:

```text
a29286e license
  → 8e5cb2d v0.16 main + 96 utilities
  → b924022 twelve basis files
  → 7f3ea6e README
  → fda0904 four additional WENO/reconstruction utilities
  → a328496 v0.18 main added alongside v0.16
  → 5cc173a v0.18 main modified (joint implicit diffusion)
  → 8c2f604 → 0422a2b → d9d50a8 README-only changes
```

This confirms commit ancestry and order of introduction, not a claim that v0.18 was edited directly from the committed v0.16 blob without intermediate work. All 116 tip files match the archive root byte for byte. No v0.19 or later main occurs in any inspected MATLAB commit tree. The later snapshots therefore have no confirmed Git parent here.

The root utilities are precisely the Git collection after `fda0904`: basis, plume, thermodynamics and time-integration files retain their initial-upload bytes; WENO adds `reconstruction_cd2.m`, `reconstruction_cd4.m`, `reconstruction_up3.m`, and `reconstruction_weno_vec.m`. Later standalone mains coexisting with those utilities do not make this a v0.19/v0.20 utility snapshot.

### Confirmed collection relationships

S19 contains the K24 main, four utility directories, two Heaviside bases and three soundings. Its local functions implement time integration, so no external time directory is required by the main. “019.3” comes from the directory name, not a distinct main filename. Source/package presence is confirmed; successful execution is not.

S20 and S24 contain their respective mains and five utility directories. Between S20 and S24, plume, time-integration and WENO directories are byte-identical. All common thermodynamics files except `inv_T_from_theta_e.m` are byte-identical; S24 adds three inversion functions. The basis directories are entirely replaced at the path level. These identities demonstrate library continuity, without proving direct ancestry of the mains.

S24's README explicitly identifies GF87 as p87 with GPU and FFT acceleration. Both are retained; they are not byte-identical. CPU/device arithmetic equivalence is an author claim to be tested separately, not an outcome of this investigation.

## Strongly inferred lineage

```text
v0.16 source family
    → v0.18 original → v0.18 January update [the latter edge is Git-confirmed]
          |
          +... K24 family / S19 collected state
                  |... root K24 export experiment [direction not confirmed]
                  |
                  +... v0.19 standalone 2D
                            → v0.20 standalone 2D
                                  → S20 packaged main
                                        ... missing intermediate development ...
                                              S24 p87 → S24 GF87
```

Arrows outside the explicit Git edge denote the most plausible development direction, not a recovered commit graph. Dotted connections denote a family relationship with unresolved ancestry. In particular, K24 may branch from the original v0.18 family rather than the January diffusion update: it uses MF-only diffusion and lacks the added tracer-diffusion routine.

| Proposed relationship | Evidence | Confidence and limit |
| --- | --- | --- |
| v0.16 family → v0.18 | Git introduction order; large shared main structure; systematic staggered-grid/vector transport changes | Strong family succession; unrecorded intermediate edits possible |
| v0.18 family → S19 K24 | Shared SSPRK, thermodynamic and transport structure; additions for dynamic-pressure tests, humidity adjustment and Heaviside bases | Medium; which v0.18 state was the immediate parent is unknown |
| S19 K24 ↔ root K24 | Same basename, extensive shared local functions; root adds processed-sounding/NetCDF export and debugging edits | Strong common family; exact chronological direction unknown |
| K24 family → standalone v0.19 2D | Shared staggered driver and source terms; systematic change from annuli to equal-width columns, PMD forcing and 2D diagnostics | Medium; root export experiment need not be on this path |
| standalone v0.19 2D → standalone v0.20 2D | Very close source structure; concentrated addition of PMDv/dz2FH, timestep and continuation edits | Strong inference; not Git-confirmed |
| standalone v0.20 2D → packaged S20 | Shared nonlocal PMB/PMDv/PMD channels and transport equations; ace-struct rewrite and explicit matching library APIs | Strong family continuity, medium immediate-parent inference; significant intervening work possible |
| S20 family → S24 | Preserved utility bytes, ace struct, five original state slots, microrad pattern and SSPRK family; new terrain/kernel machinery | Medium family continuity; low confidence in a direct edge |
| p87 → GF87 | README's explicit description plus source diff: GPU/FFT helpers and device-aware paths added to the same model structure | Strong inference for derivation; no commit/date evidence establishing order |

The original Git history supports v0.16 preceding the v0.18 introduction but neither confirms nor contradicts later numeric ordering: it simply stops tracking model changes at v0.18. It does contradict treating all archive files as committed releases, treating the archive root as the latest utility library, or treating each version number as a complete replacement snapshot.

## Developer-defined migration convention

For historical standalone MATLAB mains without their own utility directories, the assigned baseline is **v0.18-era root utilities by developer-defined migration convention.** This applies to `ace_v019_K24_8aces.m`, `ace_v019_dev_2d88aces.m`, and `ace_v020_dev_2d88aces.m`. The baseline is collection R: the 100 root utility files whose Git identity is recorded in the inventory. Snapshots with their own utilities retain their documented accompanying collections.

The evidence categories are distinct:

- **Git-confirmed historical facts:** the root utility bytes and their introduction in the MATLAB Git history.
- **Source-code inference:** driver-family relationships and compatibility findings derived from source comparisons.
- **Developer-defined migration decision:** assigning R to standalone mains for migration. This resolves the baseline selection; it does not establish which utilities, working directory or MATLAB path were used historically, prove numerical compatibility, or change the inferred source lineage.

## Main-program evolution and scientific changes

Labels below use the requested categories. A listed change describes source behavior; its scientific validity has not been established by simulation. Line references identify anchors in the archived files, not suggested edits.

### v0.16 → original v0.18

**Scientific formulation; numerical method; WENO/numerics.** In v0.16 `expFun` (line 429), tracer and MF reconstruction is performed through per-level scalar WENO stencils. v0.18 moves tracers to cell centers and MF to interfaces, reconstructs interface tracers with `reconstruction_weno_vec`, obtains center MF through `reconstruction_up3`, and computes vertical tracer flux divergence. `NONLOCAL_RESPONSE` changes from the older MB/buoyancy averaging expression to PMB acting on `rho0B + F`. Density location, array shape, forcing units and surface/top treatment all deserve scientific review; this is not just vectorization.

**Constants or configuration; time integration.** Defaults change dz 100 → 50 m, dt 20 → 4 s, duration 1 → 12 h, continuation enabled → disabled, and sponge depth 3 → 6 km. Nine-stage SSPRK coefficients already occur inline in v0.16; v0.18 factors the stages into local `SSPRK93`. The old external `util_timeint` alternatives are not the active march merely because they are present.

**Thermodynamics; diagnostics or I/O.** Inversion, precipitation thermodynamic derivatives and diagnostics use cell-center pressure/reference state in v0.18. Plot heights change with the staggered tracer grid. These outputs cannot be compared safely using filename identity alone.

### original v0.18 → January v0.18

**Time integration; numerical method.** `git show 5cc173a` changes the conditional diffusion call from per-ACE `ImDiffMF` to full-state `ImDiff`. The new function constructs a density-weighted tridiagonal tracer solve and a separate MF solve, with zero MF enforced at surface and upper levels. `turn_off_mf_diff=1` remains the default, so the new behavior is conditional.

**Unknown or uncertain.** The same commit adds `function X = ImDiffMF(X,dt)` while retaining `function MF = ImDiffMF(MF,dt,ida)` in the same script (archive lines 533 and 555). This is a concrete duplicate-local-name concern, regardless of the diffusion switch. No parser/run test was performed and nothing was repaired. It is especially unsafe to describe this commit as a validated baseline solely from its message.

### v0.18 family → S19 K24

**Scientific formulation; numerical method.** The main adds `turn_off_DHv`, `turn_off_DHh` and `no_dyn_pres` controls; its active MF tendency combines `(1-turn_off_DHv)*FHi`, the `no_dyn_pres*Fi` option and the PMB response (main lines 490–521). A declared switch does not prove every named channel is implemented: this K24 `NONLOCAL_RESPONSE` consumes PMB, whereas the later 2D main explicitly consumes PMD. Edge momentum values change from padded zeros to repeated edge values. Optional mean-MF handling becomes end-of-step unweighted removal instead of the v0.18 outer-column area-balancing tendency.

**Constants or configuration; time integration.** S19 defaults to a four-ACE Heaviside basis, dz=100 m, dt=6 s, k=6, a 1-K moist bubble and two hours. External buoyancy is enabled for one hour. Initial MF is balanced using ACE areas. Eddy coefficient scaling drops division by dz. The march selects MF-only implicit diffusion, disabled by default. Thus later numbering does not mean the January tracer-diffusion feature was retained.

**Thermodynamics; numerical method.** A new `TWEAK_THETA_E` adjusts supersaturated-equivalent-potential-temperature soundings. Profile and nonlocal interpolation change from pchip to makima. Active utility changes are detailed below.

**Unknown or uncertain.** The “constant mixing” diagnostic call at lines 201–203 passes `(T_p,q_p,rho_p,z_p,mixing)` to local `ENTRAIN_PLUME`, whose signature expects pressure as the fifth argument and mixing as the sixth. The utility's five-argument path interprets this as an unprescribed-mixing plume. The same call pattern persists in the standalone 2D mains. Preserve this evidence; developer review is required before deciding whether/how to correct it.

### S19 K24 versus root K24 experiment

**Diagnostics or I/O.** Root main lines 46–85 export a Heaviside basis to NetCDF and execute unconditional `error("test")`. Later code expects processed `acelevels_manaus/manus/nauru/sgp.nc` files, absent in the archive, and includes simulation NetCDF output instead of MAT output. The source explicitly credits JD Huang for processed-data loading; this supports an interoperability experiment interpretation, but does not establish a Git parent or author/date for the file.

**Physical parameterization; thermodynamics; numerical method.** Relative to S19, root code sets both precipitation tendencies to zero immediately after calculation; reconstructs reference Tv via thermodynamic inversion; changes bubble initialization; uses pchip for nonlocal response; and overwrites the potential-temperature diagnostic with actual temperature. These changes lie after the unconditional stop and therefore describe latent code, not a completed simulation as stored.

**Constants or configuration.** Root selects seven rather than four ACEs, k=2 rather than 6, a 0.1-K rather than 1-K bubble, three rather than two hours, and different sounding selection. `gf=0` also leaves the radiative-profile normalization with a zero denominator; radiation use is commented in the tendency. Both files must be preserved as distinct artifacts.

### K24 family → standalone v0.19 2D → standalone v0.20 2D

**Scientific formulation; numerical method.** v0.19 2D uses 88 equal-width columns with `Ai=D`, `Bi=1`, replacing cylindrical areas/perimeters. `DHh` derives from horizontal momentum flux differences and enters `NONLOCAL_RESPONSE` through PMD. The direct FHi term has coefficient `(turn_off_DHv-1)`, opposite to the K24 expression. Outer tracer transport uses edge-column values. Do not infer a fully periodic main from a periodic basis: the driver still has special first/last-column expressions.

**Thermodynamics; configuration.** v0.19 2D clips the target theta_e to saturation minus 0.1 K in `TWEAK_THETA_E`; k=2, dt=3 s, default domain-mean MF removal enabled. Plotting becomes 2D contours/movie output. These files use external Windows data paths rather than snapshot-relative data.

**Scientific formulation; numerical method.** The closely related v0.20 standalone replaces direct FHi adjustment with a PMDv response to `dz2FH`; defaults to dt=6 s; loads basis conditionally on continuation; and adds another turbulent-entrainment contribution to F beyond FH. In `NONLOCAL_RESPONSE` (lines 447–462), the fine-grid branch multiplies PMDv by F, while the coarse branch uses dz2FH. This potential inconsistency is recorded without guessing the intended equation. The default coarse_z=2 follows the latter path.

**Diagnostics or I/O; unknown or uncertain.** Its enabled save block calls `V019_DEBUG`, absent throughout the archive. Neither its exact `COMPOSITE_ACE_BASIS_2D.mat` nor that debug dependency is available. S19 has builders for that family, but matching a generator filename does not establish which historical binary was used.

### standalone v0.20 → packaged S20

**Refactoring/renaming.** Globals and flattened vectors give way to an `ace` struct and `(z,var,ACE,time)` arrays; main becomes `ACE_V020_2D88ACEs.m`; local SSPRK93 becomes external `util_timeint/ssprk93.m`. This is a candidate driver successor/rename with scientific edits, not a confirmed rename. No files are known to have been deleted from the developer's original workspace.

**Scientific formulation; numerical method.** `zero_ref_buoyancy=1` subtracts the area-weighted mean rho0B (lines 346–353); SSPRK subtracts area-weighted MF rather than a simple mean. The driver obtains D from its basis, permitting nonuniform widths. F no longer contains the standalone's extra repeated turbulent term, and the fine-grid PMDv input becomes dz2FH. Defaults disable both DH channels. The output filename's “101ACEs” and the main filename's “88ACEs” are not reliable actual grid counts without the missing D data.

**Time integration.** Thermodynamics/buoyancy/precipitation are computed before the RK call and held across its stages. Earlier standalone inversion already ran only at stage 1; the extraction makes that contract explicit, rather than newly making every thermodynamic calculation infrequent. Damping now precedes optional MF diffusion. `activate_mf_diff` offers none/explicit/implicit modes; the explicit path uses a velocity-difference diffusivity. The new library's weighted projection matters for unequal areas.

**Thermodynamics; constants or configuration; diagnostics or I/O.** Bubble initialization uses center T and pressure; the library contract changes to explicit arguments and `eval_qsat2`. Main no longer performs the traditional plume comparison block. Default bubble strength is 0.25 K and duration eight hours. Output targets `OUTPUT\...`, which requires platform/path review. The supplied source is not a runnable standalone distribution: `data/` is absent, and builders have different output names/contracts from the requested `COMPOSITE_ACE_BASIS_2D_V020.mat`.

### S20 family → S24 p87 and GF87

**Scientific formulation; numerical method.** S24 has a substantially different response formulation: K1 = inverse-Laplacian horizontal second derivative, K2 = inverse-Laplacian horizontal first derivative, applied by finite-width convolution. `util_basis/V024p87_CONSTRUCT_KERNELS.m` constructs smoothed forcing boxes using a slab Green function, with three-tier vertical layers and a rock buffer row. K1 side-tap compensation enforces a zero window sum; K2 uses closed odd tap pairs. The model has kernel metadata/geometry checks. This cannot be treated as a cosmetic replacement of S20 PMB/PMDv/PMD arrays.

**Scientific formulation; physical parameterization.** `LAMB_CHANNEL` (p87 line 997) uses upwind vorticity-flux momentum with an anelastic remainder; `CAPB_STAGE` (1614) solves a capacitance system to impose terrain streamfunction constraints and update MF/gauge state. Local functions implement optional viscosity, no-slip/wall stress, mixing-length SGS and a level-mean wind equation with diagnosed pressure drag. The source also retains diagnostic Poisson/alternative closure paths. Defaults/presets determine which physics actually runs.

**Time integration; WENO/numerics.** Active `MARCH1` calls local `ssprk93_topo` (1221, 1362), closing terrain after stages, then damping, closing and resynchronizing vorticity. A terrain-aware weighted-MF removal preserves solid-interface constraints. The unchanged external SSPRK file therefore does **not** imply unchanged integration. `WENO_X_PERIODIC` supplies horizontal reconstruction; shared vector WENO is now also used for vertical vorticity transport. Extra state slots carry vorticity and gauge information.

**Thermodynamics; diagnostics or I/O.** The main calls new warm batched inversion, with fallback/cap reporting; a dry unsaturated path is also available. Checkpoints, resumable run modes, mountain-wave/terrain checks and progress records are added. Source comments claim prior validations; no logs or executable evidence were supplied to reproduce those claims here.

**Numerical method; refactoring/renaming.** GF87 adds `FFT_TABLES`, `K_APPLY_FFT`, `GPU_TABLES`, `GPU_LU_GATE`, `TAPIDX`, `K_APPLY_GPU`, `GPU_UPLOAD` and `GATHER_REC`, plus device-aware setup, allocations, closure solves and thermodynamics. GPU and FFT flags default to zero. GPU thermodynamics uses `arrayfun` with the scalar GPU inversion, while the CPU path uses warm batch inversion. FFT/GPU changes can affect rounding and reductions even when they intend the same equations. A p87/GF87 equivalence assertion requires numerical checks in a separate task.

## Utility-function evolution

### R → S19 (comparison, not a proven parent edge)

**Basis — scientific formulation; numerical method; configuration.** Common `PRECOMPUTE_VERTICAL_MODES.m` switches from WKB reconstruction to operator-specific `VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL(...,operator)`, producing `fnij`, `fnijh`, `fnijdz` instead of A; defaults change from a 150-km/1500² setup to 64-km/512². `COLLECT_PRECOMPUTE_VERTICAL_MODES.m` adds a 2D collection path with a Nyquist ADX adjustment. `PRECOMPUTE_COMPOSITE_ACE_BASIS.m` changes diameter cases, introduces forcing normalization and changes PMD naming to PMDv. These scripts are not necessarily one coherent build pipeline: collection files still expect particular intermediate variables and external paths.

Added basis files include 2D, DH, ADZ, high-resolution, alternative-resolution and backup experiments, plus `4jupyter/` copies and ten `hires-temp/*.mat` files. `VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` distinguishes `N_ij`, `N_ij^h`, and `N_ij(d/dz)` operators; the `-bak` variant has a different arity. Some callers/variants therefore cannot be substituted by basename resemblance. Their individual numerical histories and binary outputs remain uncertain; none is silently classified as obsolete.

**Plume calculations; physical parameterization.** `entrain_plume_calc.m` shifts z to its first level, uses a named 14-km updraft depth, and replaces the lowest-500-m averaged initial parcel with the first sounding level. `cin_cape_calc.m` and `trad_plume.m` are byte-identical across R/S19. Added `entrain_plume_calc_steady.m` includes turbulent entrainment in the default profile. `trad_plume_BnoVirtual.m` substitutes T for virtual T in buoyancy, changes its mixing setting and sounding selection; it is a separate scientific experiment. Backup plume files retain older interfaces (including global pressure), not confirmed renames.

**Thermodynamics; constants or configuration.** Six common files differ: `eval_dTqsscl.m`, `eval_esscl.m`, `eval_h.m`, `eval_qsat.m`, `inv_T_from_h.m`, and `test_inv_T_from_h.m`. Mixed-phase/enthalpy routines replace hard-coded 273.15 K with global T0; the three-argument qsat threshold changes from 273.16 to 273.1636783445389 K. `IMPORT_CONSTANTS.m` itself is unchanged. `eval_theta_e_check.m` adds a liquid-water comparison formulation. Nested `bak/` and `tests-inv_T_from_theta/` are absent from S19, which does not prove they were historically deleted.

**WENO/numerics; numerical method.** `reconstruction_weno_vec.m` reverses the linear-weight ordering for k=4,5,6 (comments identify a typo), revises k=6 smoothness expressions and modifies reduced-order surface weights. These changes affect high-order transport, including the S19 main's k=6 default. Added `_dtypo456`, periodic and `_k56asym` variants preserve competing/older formulations; several declare an unsuffixed function name different from the filename. Do not select them based on the suffix alone.

**Formatting/comments only.** The common scalar `reconstruction_weno.m` changes indentation only; its high-order coefficients are not the vector correction. This distinction matters because the corrected vector function and the scalar/experimental routines coexist. All other common WENO files match R byte for byte.

**Time integration.** All seven R `util_timeint` files are absent from S19. The main has local integrators/damping/diffusion. This is library packaging divergence, not evidence that S19 abandoned time integration or inherited an unknown external solver.

### S19 → S20

**Basis — numerical method; refactoring/renaming.** Only two basis paths are shared (`PRECOMPUTE_COMPOSITE_ACE_BASIS_2D.m`, `PRECOMPUTE_VERTICAL_MODES_2D.m`), and both change. The composite builder changes even/odd symmetrization and writes shifted responses to `(:,:,id,:)` instead of `(:,:,:,id)` before later assembly: forcing/response axis ordering is scientifically consequential, especially for the odd PMD channel. The vertical builder now emits A, ADV and ADX with explicit operator selection. Added `COLLECT_PRECOMPUTE_VERTICAL_MODES_2D.m` and `uneven_tests/` explore uniform/uneven column aggregation and truncation.

`S19/util_basis/VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` → `S20/util_basis/vertical_solutions_reconstruct_util.m` is a strong rename/copy candidate: content differs only by removal of commented alternative lines, while the declaration still uses uppercase `VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL`. This is not a confirmed filesystem rename and case-sensitive lookup should be reviewed later. The inventory records it as absent/addition, preserving the actual evidence.

**Plume calculations; constants or configuration.** `cin_cape_calc.m` stays byte-identical. `entrain_plume_calc.m` replaces global qc_cap with a fixed `4e-3` kg/kg value; S19's driver sets its global value to `0.5e-3`. Thus using the newer utility can change parcel condensate removal by a factor of eight in the cap, even with the same calling code. Older traditional-plume scripts/variants are absent; packaged S20 does not actively run their comparison block.

**Thermodynamics; refactoring/renaming.** Optional branches in `eval_Tv`, `eval_q`, `eval_qs`, `eval_qsi`, `eval_qsat`, `eval_qsscl` and their saturation derivatives are disabled. New `eval_q2`, `eval_qs2`, `eval_qsi2`, `eval_qsat2` preserve condensate-free call forms under different names. `eval_theta_es` calls `eval_qsat2`. Several globals become local constants; `IMPORT_CONSTANTS_NOGLOBAL.m` is added. `inv_T_from_h` and `inv_T_from_theta_e` no longer accept caller-provided tolerance arguments. These are real API changes even where formulas remain the same.

**Thermodynamics; scientific formulation; constants or configuration.** `eval_theta_il.m` changes the qt coefficient in CPL from 3184.3 to 864.3. `inv_T_from_theta_il.m` changes `2834.e6` to `2.834e6` in ice formulas and replaces a ~2.8315e9 mixed-phase denominator with `2.834e6-lv(T0)`. These are large changes, consistent with correcting an ice latent-heat scale, but intent and consistency with the forward function require scientific review. The main evolves theta_e, so these utility differences are not evidence that the default trajectory exercises theta_il.

**Numerical method; thermodynamics.** `inv_T_from_theta_e.m` uses explicit complex variables and imaginary-part tests for GPU-oriented scalar execution. Added `_nogpu` and GPU test/sample files preserve alternatives. Complex comparisons, convergence and tolerance behavior should be checked before asserting identical results.

**Time integration.** `ssprk93.m` becomes the supplied external integrator, passing fixed thermodynamic tendencies and buoyancy plus ace state. End-of-step nonnegative qt enforcement remains; MF projection is area-weighted. This utility is absent in R and S19 under that filename; those drivers' local SSPRK93 routines have different interfaces.

**WENO — formatting/comments only.** The common vector WENO differs from S19 only in comments removing old erroneous-weight examples and saying “corrected”; active statements are unchanged. `reconstruction_up3.m` is byte-identical. Other S19 WENO helpers/experiments are absent. Do not describe this as a new numerical correction at S20: the vector correction is already present in S19.

### S20 → S24

**Basis — scientific formulation; numerical method.** All nine S20 basis paths are absent in S24; the two new paths are `V024p87_CONSTRUCT_KERNELS.m` and `util_layergreen.m`. The latter evaluates a finite-height Dirichlet slab Green function using scaled exponentials to avoid large-hyperbolic-function overflow. New tiling, boundaries, units, truncation compensation and kernel metadata require matched driver/data combinations. No rename is inferred between the old builder suite and this new formulation.

**Thermodynamics; numerical method; diagnostics or I/O.** The only changed common utility is scalar `inv_T_from_theta_e.m`: counters add a nominal 200-iteration failure threshold, print inputs and return NaNs. Its actual test is `counter > 200`, after updating, permitting a 201st iteration before failure. New `inv_T_batch.m` uses per-cell masked iteration with an adjustable cap (default 200); `inv_T_batch_warm.m` attempts branch-specific warm seeds for up to three sweeps, then falls back per cell. These are changes in solver control and finite-tolerance trajectories; comments claiming exact agreement are not independently verified here.

New `inv_T_from_theta_e_gpu.m` follows the capped scalar formulas but omits fprintf diagnostics and returns scalar NaNs on failure for device `arrayfun`. Batch failure propagation and scalar/batch cap boundary behavior deserve later tests, especially because the batch code separately reports nonconvergence masks.

**Unchanged utility contents, changed callers.** Both plume files, external `ssprk93.m`, both WENO files and the remaining 36 common thermodynamic files are byte-identical. Main-level terrain integration, horizontal reconstruction and physics nevertheless change substantially. Library identity alone is insufficient evidence of model equivalence.

## Files added, absent, and candidate renames

The inventory's presence/hash ledger is the exhaustive path-level record. It includes all utility subdirectories and data, not just main files. Comparisons are between supplied collections; “absent” is deliberately not a historical deletion claim.

| Artifact or transition | Main-file additions / absences / renames |
| --- | --- |
| Initial Git source import | Add `ace_v016_dev_8aces.m` and 96 utility files; no source predecessor supplied |
| Git v0.18 upload | Add `ace_v018_dev_8aces.m`; retain v0.16 and utilities; no rename/removal |
| January Git v0.18 | Modify existing main only; no path additions/removals/renames |
| S19 K24 versus root collection | Separate K24 main at a nested path; root v0.16/v0.18 mains are not included in S19; no evidence of deletion or rename |
| Root K24, v0.19 2D, v0.20 2D | Three archive-only standalone additions relative to Git tip; R assigned by developer-defined migration convention; no historical utility-tree change established |
| Packaged S20 | New main path `ACE_V020_2D88ACEs.m`; candidate successor/rename of standalone v0.20 with substantial scientific edits; no confirmed rename |
| Packaged S24 | Add p87, GF87 and README compared with S20; S20 main absent from this collection; no confirmed driver rename |
| p87 versus GF87 | Two coexisting mains share one utility package; GF is an added variant, not a replacement |

## Uncertain lineage and required developer review

1. **Standalone utility baseline resolved; historical provenance remains uncertain.** The three standalone mains are assigned v0.18-era root utilities by developer-defined migration convention. R-versus-S19 selection is no longer an open migration decision. No script pins the historically used library revision, and paths depend on `pwd`; actual historical pairings still require execution-environment evidence. S20/S24 API incompatibilities and the need to validate the assigned R combinations remain source-code findings.
2. **K24 branch direction.** The root export experiment could derive from the packaged K24 family, or both could share an unsaved predecessor. It must not automatically become the parent of the 2D family merely because its filename/version matches.
3. **Unrecorded intermediate versions.** No v0.17, v0.21–v0.23 or intermediate v0.24 main is present in these inputs. Experimental utility files are evidence of parallel work, not enough to assign new numbered releases or dates.
4. **Missing data and build contracts.** S20/S24 `data/` directories are absent; standalone 2D basis binaries are absent; processed `acelevels_*` soundings are absent. S19 supplies Heaviside data but not the requested 2D file. Binary dimensions/contents and generator provenance remain unchecked. Even S24's kernel builder falls back to saving in `.` when `data/basis/` is absent, while the driver expects the data path.
5. **Inherited artifacts.** Nested thermodynamic backups/tests, S19 WENO variants, autosave, high-resolution basis files and S20 uneven-grid experiments have no independent Git history here. Do not consolidate or discard them. Signature mismatches and alternate constants can preserve important scientific intent.
6. **Static execution concerns.** Duplicate v0.18 local function names, the K24 unconditional stop, the constant-mixing call, absent `V019_DEBUG`, hard-coded paths and missing data need review before any run. They were recorded, not fixed. User intent for scientific differences such as FHi sign, PMDv forcing and theta_il constants cannot be inferred safely.
7. **Fortran cross-reference.** `ace-fortran/main` history includes `bb72a55` (2024-12-16, “can reproduce matlab version of ACE model v0.18”), `dcc51e6` (2025-12-06, MATLAB comparison), and `0f481a6` (2026-05-26, consistent MATLAB result claim). Their changed-file lists were inspected; these messages provide context, not MATLAB blob identities, regression evidence, or dates for the uncommitted snapshots. The December 2024 claim predates the January 2025 MATLAB diffusion commit.

## Recommended next direction

Recover the missing basis/sounding provenance with the original developers and review compatibility of the standalone mains with their assigned R baseline. Preserve each artifact identity; the standalone utility baseline is now selected by convention, while selection of a model version for import remains a separate decision. A subsequent, separately authorized validation task should use isolated copies and matched inputs to check WENO weights/boundaries, thermodynamic round trips (including ice and failure cases), weighted conservation, PMD/PMDv orientation and terrain/GPU equivalence. No source import or scientific correction is implied by these reports.

## Verification of this archaeology task

Verification consists of Git tree/blob inspection, recursive file inventories, byte comparisons, source diffs and inspection of active call paths. No MATLAB/Fortran simulation, kernel generation, checkpoint creation or historical-source modification was performed. Only the three requested Markdown reports were created in the unified repository; no commit was made.

Original archaeology preservation check (before the reports were committed): all 319 archive files (excluding `.git`) have unchanged SHA-256 hashes and the same path set as at inspection start. Report links and table column counts were checked. At that check, unified HEAD was `1953c17` and the three reports were untracked. For this convention update, the initial working tree was clean on `migration/matlab-history` at `4cbb7b9` (`Document MATLAB historical code lineage`); only these three reports are being updated, with no new commit.
