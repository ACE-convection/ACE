# p87 MATLAB validation gate

Status: conditional input and environment audit, 2026-09-26. This S24 gate was
deferred while [unified v0.18 alignment](matlab_fortran_alignment_plan.md) was
the current milestone at that review. v0.18.0 is now complete; the S24
kernel/reference questions below remain relevant to later work.
The developer confirmed that sounding files are the
same across all versions. If p87 is later selected, use the S19 GOAmazon file
as its input. This historical conditional checklist preserves input hashes,
source contracts and reference-log requirements for the S24 CPU driver. Its
former `matlab/active/` destination is superseded by the normalized source
roots in the roadmap; any later validation supports the joint v0.24 milestone.
It is not a current task list. No MATLAB run
or numerical comparison has been performed.

## Required baseline

Run the preserved `ACE_V024p87.m` from an isolated copy of its complete S24
package, with the working directory set to that copy. The script builds library
paths from `pwd`, and its input paths are also relative to `pwd`. Keep runtime
data and output outside the tracked historical snapshot.

| Requirement | Source contract | Current repository evidence |
| --- | --- | --- |
| MATLAB | S24 README specifies R2024b or later. The CPU driver calls `maxNumCompThreads`, `ncread`, and `save(...,'-v7.3')`. | Neither MATLAB nor Octave is installed in this environment. |
| Composite basis | Default `DX=500`, `NT=30`: `data/basis/COMPOSITE_ACE_BASIS_2D_V024_dx=500m_NT=30.mat`. The driver reads `PMB_trunc`, `K2_trunc`, and `params`; it checks `params.NT`, `dx`, `nbuf`, exact layer edges, and table shapes. | No file of this name was found under `matlab/`. S24 includes the offline builder and `util_layergreen.m`, but no produced basis. A regenerated basis requires its own provenance and numerical review. |
| GOAmazon sounding | `data/soundings/maoarmbeatmM1.c1.20140101.003000.nc`. `LOAD_SOUNDINGS` reads `pressure`, `precip_rate_sfc`, `temperature_p`, `relative_humidity_p`, and `time`. It keeps complete 37-level profiles at hour 05 and selects `pidx=314`. This read occurs even with the default `SND='ideal'`. | S24 does not include the file. The developer confirmed that soundings are the same across versions, so use the tracked S19 file as the p87 input. It is 103,316,408 bytes, SHA-256 `57016c62474bb4a2faf6011d285ee280d9581f9dc791327c506207ae06cc362a`. A static NetCDF check found the expected variables and 353 complete hour-05 profiles, so index 314 exists. |
| Reference output | The S24 driver says `RUN_MODE='mwgates'` must end in `ALL T2b GATES PASS` and that GATE / G14c lines must match reference fingerprint logs. | No p87 reference fingerprint log was found in the repository. Internal gate assertions alone do not establish reproduction of a previous run. |

## First run when inputs are confirmed

1. Record the MATLAB version, CPU platform, source commit, input paths, SHA-256
   hashes, and the builder provenance of the composite basis. Use the confirmed
   S19 sounding and verify its recorded hash before the run.
2. In an isolated S24 copy, put the confirmed inputs under `data/basis/` and
   `data/soundings/`, or set `KFILE` to the confirmed basis path. Set `OUTDIR`
   to a fresh output directory. Keep the working directory at the S24 copy so
   its `util_*` folders resolve as the driver expects.
3. Run the unchanged CPU driver with `RUN_MODE='mwgates'` and default grid,
   kernel, and physics presets. Save the complete console output and check both
   the final pass marker and every printed gate value. Compare GATE / G14c
   lines with a developer-supplied reference log from a matched input set.
4. Only after this baseline is reproducible, run a later reviewed normalized
   version with the same input hashes, presets, MATLAB version, and output
   location policy.
   Compare gate values and relevant output arrays; a successful textual copy or
   a pass marker by itself does not prove numerical equivalence.

Do not substitute an S19 basis or a freshly built p87 basis for the missing
runtime file solely because its filename or dimensions match. The kernels are
part of the numerical method, so their origin and values matter.
