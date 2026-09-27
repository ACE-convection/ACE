# Active MATLAB layout proposal

Status: proposed layout with partial source copies, updated 2026-09-26. Source
baseline: the 50 preserved files in `matlab/history/snapshots/ACE_V024.87/`
(S24). The preserved Git history and
snapshot remain untouched. S24 has two drivers, five utility directories, and
no `data/` directory. Its README describes runtime files that are absent from
the archive. No run or numerical equivalence has been demonstrated.

Current copy progress: `matlab/active/numerics/` has two WENO functions;
`matlab/active/thermodynamics/` has 25 functions, including the p87 sounding
initialization call chain and two saturation derivatives used by its inversion
utilities. All 27 files are byte-identical in S20 and S24;
12 are also byte-identical in the original Git utility tree and S19. The latter
group is `reconstruction_up3`, `ci`, `eval_B`, `eval_dTes`, `eval_es`,
`eval_esi`, `eval_rho`, `eval_theta`, `eval_theta_e`, `eval_theta_l`,
`eval_theta_v`, and `lv`. The only remaining S24 thermodynamics files with
that same four-source byte identity are the unused `IMPORT_CONSTANTS.m` global
script and comment-only `NOTE.m`; keep both historical-only. File identity does
not imply equivalent behavior of different drivers. The active driver and
basis builder have not been selected or copied. The developer will select a
version for runtime testing after code organization. The conditional p87
runtime input and reference-output gate is recorded in
[`matlab_p87_validation_gate.md`](matlab_p87_validation_gate.md).
The cross-version utility dispositions are recorded in
[`matlab_shared_utility_inventory.md`](matlab_shared_utility_inventory.md).

## Proposed layout

```text
matlab/
  active/
    ace.m                         # p87 CPU driver; one script with local model functions
    ace_accelerated.m             # GF87 GPU/FFT variant, only after review
    basis/
      construct_kernels.m         # offline builder, only after path review
      util_layergreen.m
    plume/                        # populate only if a required caller is established
    thermodynamics/               # production thermodynamic functions and constants
    time_integration/             # reference SSPRK routine, only if needed
    numerics/                     # WENO and upwind reconstruction
    README.md                     # staging status now; run instructions after driver selection
```

`matlab/history/` stays an inert archive. Keep local functions inside each
driver initially: extracting dynamics, pressure/terrain closure, diagnostics,
or `ssprk93_topo` would change call and workspace boundaries and needs its own
scientific review. The accelerated driver is a separate candidate, not a
replacement for p87. Do not deduplicate the two large scripts by textual
similarity. The planned directories give later MATLAB–Fortran comparisons
stable component boundaries without asserting equivalent physics.

## S24 file map and disposition

Source paths below are relative to `matlab/history/snapshots/ACE_V024.87/`.
"Candidate" means eligible for a later, reviewed copy; no file is moved now.

| Source file(s) | Proposed active location / disposition | Evidence and review point |
| --- | --- | --- |
| `ACE_V024p87.m` | `active/ace.m` — primary active candidate | CPU model driver, including local time integration and terrain/kernel functions. Rename requires updating invocations, text references, output tags, and baseline checks. |
| `ACE_V024GF87.m` | `active/ace_accelerated.m` — conditional candidate | Adds GPU/FFT branches and calls the GPU thermodynamic inversion. Keep historical-only until developers decide whether acceleration belongs in the active track and validate the chosen mode. |
| `util_basis/V024p87_CONSTRUCT_KERNELS.m` | `active/basis/construct_kernels.m` — offline tool candidate | Script writes basis MAT files; its current path and filename contract needs review before renaming. |
| `util_basis/util_layergreen.m` | `active/basis/util_layergreen.m` — dependency of builder | Preserve bytes and function name. |
| `util_weno/{reconstruction_up3,reconstruction_weno_vec}.m` | `active/numerics/` — active candidates | Both are called by the drivers. |
| `util_thermodynamics/*.m`, except the five `.m` entries called out below | `active/thermodynamics/` — 34 library candidates | Includes `IMPORT_CONSTANTS_NOGLOBAL.m`, evaluation functions, `inv_T_batch*.m`, and CPU inversions. Retain exact names and bytes; static inclusion does not prove every function is exercised. |
| `util_thermodynamics/inv_T_from_theta_e_gpu.m` | `active/thermodynamics/` — conditional candidate | Called by GF87's GPU path; copy with that variant only. |
| `util_thermodynamics/IMPORT_CONSTANTS.m` | Historical-only pending review | Global-constant script; no S24 driver or utility call found. Do not substitute for `IMPORT_CONSTANTS_NOGLOBAL.m`. |
| `util_thermodynamics/inv_T_from_theta_e_nogpu.m` | Historical-only pending review | Referenced by `gputest_invTq.m`, not by the drivers; may be a comparison routine. |
| `util_thermodynamics/gputest_invTq.m`, `GPUTEST_SAMPLE.mat` | Historical-only test artifacts | The test script loads the sample MAT file by relative name. Retain together in history; do not put the sample on the active runtime path. |
| `util_thermodynamics/NOTE.m` | Historical-only note | Comment-only MATLAB file, not a callable utility. Its content can inform a future active README. |
| `util_plume/{cin_cape_calc,entrain_plume_calc}.m` | Historical-only pending caller review; `active/plume/` reserved | Neither driver directly calls these external functions. A plume-related local function `microrad` remains inside the drivers. Do not infer that the library is obsolete. |
| `util_timeint/ssprk93.m` | Historical-only pending review; possible `active/time_integration/` | Drivers use local `ssprk93_topo`, which documents this external function as a reference; no direct call found. |
| `README.md` | Historical-only package description | Describes the original package, paths, and filenames. Write a separate active README after behavior-preserving setup is agreed. |

This table covers all 50 S24 files: 2 drivers, 2 basis, 2 WENO, 40
thermodynamics, 2 plume, 1 time-integration, and 1 README. The S24 collection
contains no autosave or `_backup` file. Earlier snapshots and the original Git
tree do contain historical variants/backups; none is a source for this active
baseline. `gputest_invTq.m` and its sample are tests, while the GF87 driver and
`*_nogpu` inversion are experimental/variant candidates requiring review.

## Names and path contracts to address later

- Source names with version tokens: `ACE_V024p87.m` → `ace.m`,
  `ACE_V024GF87.m` → `ace_accelerated.m`, and
  `V024p87_CONSTRUCT_KERNELS.m` → `construct_kernels.m`. MATLAB script calls,
  README examples, and builder metadata would need consistent review. Internal
  names such as `BUILD_V024_CAP` are outside this file-layout step.
- Both drivers set `dir_ace = pwd`, add `util_*` folders from that directory,
  and look for `data/soundings/` and `data/basis/` beneath it. The builder
  writes to working-directory `data/basis/`, falling back to `.` if absent.
  Merely moving files would break these assumptions.
- The drivers select a versioned `COMPOSITE_ACE_BASIS_2D_V024_dx=..._NT=...mat`
  unless `KFILE` is given; the builder emits that same name. Keep this
  producer/consumer contract intact until a separately reviewed shared-data
  interface is ready. No basis MAT or sounding file is present in S24.
- `OUTDIR` defaults to working-directory `OUTPUT`; checkpoint, resume, progress
  log, and record tags include `V024p87`/`V024GF87`. Renaming output files may
  break continuation from existing records. Treat this as an I/O compatibility
  decision, not a cosmetic rename.
- Future shared top-level `data/` should have documented basis and sounding
  paths and netCDF schemas usable by both implementations. Large runtime files
  stay untracked. No conversion, data copy, or Fortran change is part of this
  proposal.

## Review gate and next step

The work is on `refactor/matlab-active-layout`. The two WENO and 25
thermodynamics files already staged in `matlab/active/` are byte-identical to
S20 and S24. No driver, path, API, constant, or numerical method has been
changed by these copies.

After code organization, developers will select a version for runtime testing
and decide whether the GF87 variant and historical-only utilities belong in a
supported workflow. Copy the chosen driver's remaining dependencies together
with that driver in small, reviewed steps. Establish its runnable input set and
reference gate output before any claim of behavior preservation; MATLAB was
unavailable for this review.
