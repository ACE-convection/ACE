# Unified ACE v0.18 alignment audit

Status: static repository archaeology, 2026-09-28. No source modification or
MATLAB–Fortran numerical run was performed. A matching label, commit message,
or source-level formula is not proof of equivalent results. Paths below are
relative to the historical Git trees; inspect a state with
`git show <commit>:<path>`.

## Candidate source states and boundary

| Role | Commit and evidence | Decision / uncertainty |
| --- | --- | --- |
| MATLAB original v0.18 | `a328496` (2024-10-14), `ace_v018_dev_8aces.m` plus that commit's utility tree. Message identifies a staggered grid and vector WENO. | **Primary MATLAB candidate.** It predates the Fortran reproduction claim and keeps the optional original MF diffusion routine. This is a source candidate, not a validated release. |
| MATLAB January v0.18 | `5cc173a` (2025-01-15), same driver plus 61 added and 4 removed lines; utilities unchanged. | Retain as a distinct historical state. It adds joint implicit tracer/MF diffusion, replaces the optional call with `ImDiff`, and leaves two local functions named `ImDiffMF`; the default diffusion switch is off. Its science and parse behavior need separate review. It cannot silently replace the October baseline. |
| Fortran alignment anchor | `bb72a55` (2024-12-16), message says it can reproduce MATLAB v0.18. | Important evidence of intent, with no archived matched output or input hashes found. The code suppresses all but the first ACE tendency, has no active precipitation sink, and its makefile lacks `-r8`. It is not sufficient as a unified release state. |
| Fortran v0.18 source candidate | `ffdd734` (2025-01-06 PST / 2025-01-07 UTC), target of the existing Fortran `v0.18` tag. Its history contains `daab45c` and `e586558` for precipitation, multiple ACEs and buoyancy changes. | **Primary Fortran candidate for validation**, with `bb72a55` retained as the original alignment anchor. The tag is a historical Fortran marker. Source changes after `bb72a55` include scientific changes, so alignment must be retested. |
| Beyond the boundary | After `ffdd734`, the later branch changes state ordering at `ad7d1b6` (2025-01-08), moves toward `th_q` at `ba6e11f`, changes to `th,qv,ql,qi` at `0d8dc4c`, and adds P3 at `381402d`; these enter main through `88e4af5`. | These identify the v0.18 boundary only. They are outside this audit. Do not substitute a later Fortran claim of MATLAB consistency for v0.18 evidence. |

The MATLAB original and January commits have the same v0.18 filename but
different model behavior when diffusion is enabled. The preserved
`matlab/history/original_git/ace_v018_dev_8aces.m` matches the January state;
use `a328496` directly to inspect the original driver. The Fortran tag and the
December reproduction message also identify different source states. A joint
v0.18 release cannot be inferred from any of those labels.

## Component comparison

The table compares MATLAB `a328496` with Fortran `ffdd734` unless noted.
“Confirmed aligned” means the cited source structure or constants match at
the stated level only; no row implies end-to-end numerical equivalence.

| Component | Classification | Source evidence and review point |
| --- | --- | --- |
| Governing dynamics and transport | **Likely aligned** | MATLAB `expFun` and Fortran `ace_tendency` both use vertical tracer-flux divergence, area/perimeter coupling, density-weighted buoyancy and a PMB-driven MF tendency. The Fortran loop and MATLAB vectorization have not been compared term by term or run on the same state. |
| Prognostic variables | **Known different** | Both evolve `theta_e`, `qt`, MF in that order. MATLAB carries two additional precipitation-accumulation slots in its five-slot `X`; Fortran advances three variables and stores reference fields in slots 4–10 of a separate `X` layout. Comparison requires an explicit mapping. |
| Grid and staggering | **Likely aligned** | Both use 50 m vertical spacing, 801 interface levels, centered tracers, interface MF and a 200-level PMB forcing grid. MATLAB derives ACE areas from `DCASES`, `Lx`, `Ly` in the MAT basis; Fortran hard-codes 8 columns, annulus radii and a 64 km outer square in `test.F`. Equality of horizontal geometry and vertical edge arrays is unproved. |
| Numerical operators | **Unknown / needs runtime validation** | Both use PCHIP-style profile/PMB interpolation and four-level coarse averaging. MATLAB calls `interp1(...,'pchip')`; Fortran has its own `pchip`. Endpoint and extrapolation behavior, accumulation order and array orientation need direct checks. |
| WENO and MF reconstruction | **Likely aligned** in the interior; **known different** at boundaries | Both select `k=2`, use matching interior WENO candidate weights and an upwind third-order MF reconstruction. MATLAB `reconstruction_weno_vec` uses `circshift` and applies a reduced surface rule; Fortran `weno_vec` assigns only its interior and second level, leaving edge outputs dependent on later masking. `weno_up3` explicitly zeros unassigned top entries, unlike MATLAB's circular stencil. At zero MF, both WENO implementations choose the nonnegative branch; in the upwind MF reconstruction, Fortran `sign(1.,up3)` and MATLAB `sign(up3)` differ when the centered estimate is exactly zero. Test edges and that zero case separately. |
| Time integration | **Confirmed aligned** at SSPRK stage-coefficient level; **known different** for physics splitting | MATLAB local `SSPRK93` and Fortran `ace_driver` use the same nine-stage, 1/6 and 1/15 low-storage recurrence. MATLAB includes precipitation tendencies in each stage; Fortran `ffdd734` applies its sink once after the RK step. MATLAB uses a smooth `log(1+exp(...))` condensate ramp; Fortran uses a hard `max(...,0)` ramp, so the sink formulas also differ near onset. MATLAB clamps nonnegative `qt` after the step; no matching clamp was found in this Fortran driver. |
| Pressure / nonlocal response | **Likely aligned** formulation; **unknown** kernel equivalence | Both add `rho0B + F`, average into coarse levels and apply PMB before interpolating MF tendency. MATLAB `PMB(:,:,forcing,response)` and Fortran `PMB(response,forcing,coarse,edge)` have different in-memory order. The Fortran direct-access `PMB.dat` is absent, so content and transposition cannot be checked. |
| Thermodynamics | **Known different** | Both use related `theta_e`, vapor-pressure, saturation and inversion formulas with shared constants such as `Rd=287.04`, `Rv=461.5`, `Cpd=1005.7` and `T0=273.1636783445389`. In the unsaturated ice branch, MATLAB `inv_T_from_theta_e` uses `1-300708*qt/CPL/T` for `dFdT`; Fortran `inv_theta_e` uses `1+300708*qt/CPL/T`. Newton convergence/failure handling also differs. Compare liquid, ice and mixed-phase cases before accepting equivalence. |
| Diffusion and damping | **Known different** | MATLAB October source has optional `ImDiffMF` but `turn_off_mf_diff=1` by default; January source adds optional joint tracer/MF diffusion. Fortran `ffdd734` has no matching implicit diffusion step. Both apply upper sponge damping with 6 km depth and 180 s scale, but indexing and reference states need testing. |
| Initialization | **Known different** | MATLAB reads a Manus netCDF profile (`arm=1`, `pidx=208`), derives profiles, loads `COMPOSITE_ACE_BASIS_8ACEs.mat`, and initializes an outer-column 0.03 MF pulse. Fortran `test.F` skips its netCDF section with `goto 838`, reads `ini_manus_208.dat` and `PMB.dat`, and initializes the outer-column pulse. The binaries, preprocessing recipe and initial-state equality are missing. |
| Boundary conditions | **Known different / needs validation** | Both zero the top 11 dynamical levels and use zero surface tracer flux. MATLAB's outer tracer boundary explicitly uses environmental `theta_e_zc`/`qt_zc`; Fortran reads a dedicated extra reference column from its binary setup. At `bb72a55` Fortran also zeros tendencies for columns 2–8; this is removed by `ffdd734`. Edge WENO behavior above remains unresolved. |
| Diagnostics and I/O | **Known different** | MATLAB can save a workspace MAT file and computes temperature, humidity, buoyancy and precipitation diagnostics. Fortran writes direct-access binary records, including selected state and diagnostics; its `real*4` output arrays reduce stored precision even with `-r8` computation. Record lengths and interpretation depend on the Intel Fortran build convention. No paired reference logs were found. |

## Review disposition for the candidate pair

These are proposed validation dispositions, not decisions that either behavior
is scientifically acceptable. The source states remain MATLAB `a328496` and
Fortran `ffdd734`; `bb72a55` and `5cc173a` remain separate historical states.
No source correction or equivalence claim follows from this review.

| Difference | Provisional disposition | Evidence needed before a unified v0.18 decision |
| --- | --- | --- |
| Five-slot MATLAB state versus three prognostic Fortran slots; different diagnostic output formats | Map explicitly for comparison. The extra MATLAB slots accumulate precipitation diagnostics, while Fortran stores reference fields separately. | Compare the three prognostic fields and reference arrays by named quantity, grid position and units; compare derived diagnostics after accounting for output precision. |
| Optional MATLAB MF diffusion versus absent Fortran implicit diffusion | Match the default October MATLAB setting, `turn_off_mf_diff=1`, for the first paired run. Treat diffusion-enabled behavior and January `5cc173a` as separate experiments. | Record switches and show the disabled diffusion branch is not entered; review any diffusion-enabled comparison separately. |
| Initialization paths, hard-coded Fortran geometry and PMB record orientation | Input reconstruction prerequisite. File names and nominal grid spacing do not establish identical initial states. | Recover or derive Fortran binaries, then compare loaded geometry, profiles, reference fields and PMB values with hashes and index mapping. |
| WENO/upwind boundary behavior and zero centered MF estimate | Operator-level numerical question. Do not accept from an interior stencil match. | Compare surface, top and zero-estimate outputs and their contribution to one-step tendencies, including masked levels. |
| MATLAB stagewise smooth precipitation sink and `qt` clamp versus Fortran post-step hard-ramp sink without the clamp | Scientific behavior difference requiring developer review. The two sinks differ in both timing and onset formula. | Compare dry, near-ramp and precipitating columns over one step and a short run; decide whether both behaviors belong in a unified release or require a separately reviewed correction. |
| Opposite sign in the unsaturated ice-branch Newton derivative and different inversion stopping behavior | Scientific/numerical difference requiring developer review. The source alone does not establish which behavior is intended. | Check analytic or finite-difference derivatives, then compare warm, ice and mixed-phase inversion outputs and failure cases before considering a correction. |
| Sponge indexing/reference states and precision of stored output | Quantify before setting tolerances. | Compare damping applied to the same state; separate in-memory differences from `real*4` output rounding. |

The first paired run can therefore use the preserved default switch settings,
but it cannot certify the candidate pair. The precipitation and ice-inversion
rows need explicit scientific decisions after focused evidence is available.

## Required inputs and missing evidence

- MATLAB's `COMPOSITE_ACE_BASIS_8ACEs.mat` is preserved in the original Git
  history and at `matlab/history/original_git/data/basis/` (MATLAB v7.3,
  19,809,507 bytes; SHA-256
  `6053e923f12da0eb87cc0d65ea776e5fa9ba9bf6fe4dc4399fd1b4b9b645cf45`).
  Inspect `DCASES`, `Lx`, `Ly`, PMB shape and numerical values before a Fortran
  conversion. MATLAB's historical driver expects `../data/` relative to `pwd`;
  the preserved archive location alone does not satisfy that path.
- The Manus sounding is preserved at
  `matlab/history/snapshots/ACE_V019.3/data/soundings/manus_3hr_ARMBEsonde_profiles.nc`
  (40,690,446 bytes; SHA-256
  `b909a2a61b040c5efe5b2f22375bd04c1a93ab4018e427be797a9adc05e23032`).
  Its netCDF header has 37 pressure levels, 43,832 times and the variables
  `pressure`, `pr`, `ta`, `hus`, `time_bnds`. Confirm the exact profile-index
  convention and file identity against the original MATLAB run.
- Fortran `ffdd734` expects `./input_data/ini_manus_208.dat` and `PMB.dat`,
  neither present in the inspected repository. Its README describes the
  initial-profile record sequence; `test.F` reads selected records 5–12 and
  `ace_initialization` reads PMB direct-access records in nested loops.
  Recover the original files or document a verified derivation from the same
  MATLAB input. Record record length units, endian order, real kind, dimensions
  and PMB index mapping. Do not treat a filename match as data equivalence.
- `ffdd734` uses `ifort -r8 -fp-model precise` and explicit `real*4` outputs;
  `bb72a55` lacked `-r8`. MATLAB normally computes in double precision.
  Neither MATLAB nor ifort is installed in this environment; `gfortran` is
  present, but using it would require a separately reviewed build comparison.
- No matched initial-state dump, one-step/tendency trace, short-run output,
  compiler/environment manifest or accepted tolerance set was found. The
  December 2024 commit message is a historical claim, not archived proof.

## Minimal v0.18 validation gate

1. **Pin configuration and provenance.** Record both candidate commit IDs,
   build/runtime versions, compiler flags, basis and sounding hashes, physical
   constants, `arm=1`/Manus profile 208, eight-ACE geometry, `dz=50 m`,
   `dt=4 s`, and all physics/diffusion switches. Compare actual loaded arrays,
   not just nominal settings.
2. **Match the initial state.** Map MATLAB five-slot `X` to Fortran's three
   prognostic slots and reference fields. Compare the vertical grids, ACE
   areas/perimeters, pressure, reference density, `theta_e`, `qt`, MF and PMB
   values/index orientation at initialization. Document any intentional
   single-ACE or multi-ACE test configuration.
3. **Test isolated operators and one step.** Compare thermodynamic inversion
   on warm, ice and mixed-phase states; WENO/upwind stencils including zero
   velocity and boundaries; PCHIP/coarse PMB response; raw tendencies for
   `theta_e`, `qt`, MF; then one `dt=4 s` step. Separate transport, buoyancy,
   precipitation and damping contributions where practical.
4. **Run a short matched case.** Compare after 15 steps (the Fortran output
   interval, 60 s) and several such intervals, not just a terminal value.
   Track `theta_e`, `qt`, MF, T, q/ql/qi, buoyancy and precipitation diagnostics
   where both codes supply them. Report max absolute/relative errors and norms
   by variable, level and ACE.
5. **Check numerical budgets.** Record area-weighted tracer-water and MF
   diagnostics, domain fluxes, precipitation loss and sponge effects wherever
   available. Explain expected nonconservation from sinks and boundary terms.
   Set quantitative tolerances only after a reviewed reference run and the
   known precision/splitting differences are understood.

## Proposed unified release criteria

- Both candidate histories and any reviewed corrections are pinned without
  rewriting the historical source or reusing source-history tags.
- Matched input data and build/runtime instructions reproduce initial-state,
  operator/one-step and short-run evidence on a documented platform.
- Every table entry marked **known different** is either deliberately accepted
  with a tested scope or resolved in a separate scientific change; unexplained
  discrepancies are not hidden by a broad tolerance.
- The validation report records checksums, configuration, numerical metrics,
  conservation results, compiler/precision effects and limitations. A clean
  build or one successful run alone does not establish equivalence.
- Only a reviewed unified source state meeting these criteria is eligible for
  the future annotated `v0.18.0` tag. Existing MATLAB history/snapshot tags and
  the Fortran `v0.18` tag remain distinct historical markers.
