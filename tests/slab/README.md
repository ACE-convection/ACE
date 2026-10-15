# v0.21.87 slab validation

The developer accepted the original native 88-ACE eight-hour results and
reviewed MF plots on 2026-10-15. This acceptance covers the documented 32-thread
MATLAB/Fortran case and does not enable any benchmark-only optimization.
See the [release notes](../../docs/releases/v0.21.87-notes.md) for evidence,
long-run difference metrics and retained limitations.

`benchmark_basis(input_file, fresh_report_dir)` measures the original basis
contraction and separately timed products/additions/reductions using synthetic
nonzero forcings. It inherits MATLAB thread settings unchanged; an optional
third argument sets a thread limit for this isolated benchmark only. Three
trials vary the operands and require exact split/compound equality. These
kernel timings are not full model integration performance measurements.

`python3 tests/slab/benchmark_threads.py FRESH_WORKSPACE` runs fresh MATLAB
processes in reversed blocks for default/32/64/80 thread comparisons, checks
cross-setting binary equality, then measures full single steps with inherited
defaults and the fastest measured setting. It requires the retained
`migration_work/v02187_validation/matlab_inherited_environment_smoke` fixture;
it does not launch long integrations or change production thread policy.

For the developer-requested parallel native 600 s and 3600 s cases, use
`python3 tests/slab/run_parallel_cases.py PREPARED_32_THREAD_WORKSPACE FRESH_WORKSPACE`.
It launches a background supervisor, reuses hash-verified frozen inputs/builds,
keeps per-case status/results, and independently audits completed cases.
It stops after these two cases and has no eight-hour execution path; eight-hour
integration requires a separate developer decision. Four model processes can
overlap, so timings include resource competition.

Additional MATLAB optimization prototypes are `benchmark_basis_blocks`,
`benchmark_basis_packed` and `benchmark_basis_matrix` (input file and fresh
report directory arguments). All explicitly use 32 threads. The first two
preserve contraction grouping and require exact equality; the matrix variant
changes floating-point grouping and records errors without claiming scientific
acceptance. None is selected by the model or validation driver. Initial
measurements did not establish a stable speedup for production adoption.

After explicit developer authorization of the eight-hour run,
`python3 tests/slab/run_eight_hour.py PREPARED_32_THREAD_WORKSPACE FRESH_WORKSPACE`
checks the completed parallel ten-minute/one-hour audits and launches native
28,800 s integration with the frozen production sources, followed by comparison
and audit. It does not enable any benchmark-only MATLAB optimization.

The new candidate uses the author-supplied 88-ACE equal-width basis and raw
GOAmazon filtered profile 314. MATLAB's current preprocessing constructs the
shared profiles; both production initializers retain inversion-derived Tv,
the saturated +0.25 K bubble and zero initial MF. Production precipitation
ordering is unchanged. Default dt is 6 s, dz 100 m, duration eight hours,
and both supplied momentum operators are enabled in the command-line drivers.
This is a scientific change from the accepted 101-ACE Manaus baseline.

Requirements: licensed MATLAB, GNU Fortran, netCDF-Fortran (`nf-config`),
Python NumPy/netCDF4, materialized basis/sounding and the generated input.
Use `tools/input/create_s20_shared_input.m` with raw GOAmazon sounding,
profile 314, arm 3, dz 100 and actual source hashes; see the case provenance
in `data/input/goamazon314_88aces.provenance.json`. The historical name of
the converter reflects its raw-sounding preprocessing contract.

```bash
python3 tests/slab/run.py migration_work/slab_check --prepare
python3 tests/slab/run.py migration_work/slab_check --launch --long
```

Always use a fresh workspace. Preparation freezes all MATLAB sources and
uses an explicit MATLAB computation-thread limit of 32 and 32 Fortran OpenMP
threads, per the developer's updated execution policy. MATLAB inherits the
thread environment without Fortran-specific overrides and sets
`maxNumCompThreads(32)`; its reported limit is captured in each job log. Historical
workspaces retain their frozen settings, including the eight-thread suite
stopped at the developer's request during its eight-hour integration.
Preparation freezes
Fortran production sources, records hashes/compiler commands and builds
separate real64 debug/production executables. Test-only module access permits
a deterministic nonzero-MF fixture. Independent NumPy horizontal momentum
flux, vertical curvature and direct basis contractions check all source
cells at five response ACEs and five edge heights; all four switch modes
also verify additivity at the same state. Debug FPE/bounds checks and
production builds must produce identical one-step saved-state streams.

The paired short suite covers one normal step, four nonzero-MF switch modes,
ten-minute physics-off/native cases and ten-minute dt=6/3/1.5 s refinements.
Short cross-language state limits retain the existing KHN26 limits of
1e-9 MF, 1e-7 K theta_e and 1e-11 kg/kg qt. They were selected before observing
the new results. Nonzero forcing prevents a zero-state false pass.

Timestep screening requires dt=3 errors relative to dt=1.5 not to exceed
dt=6 errors beyond the short absolute limits. dt=6 errors must be below
those limits plus 1% of the observed ten-minute field evolution. These
predeclared numerical screens are not physical or release acceptance.
Only passing gates permit `--long` to start one-hour and eight-hour native
runs. `--continue-long` starts those after an already completed short suite.
Long-run cross-language discrepancies are reported without an invented
trajectory-equality threshold. Full eight-hour runs expect 481 minute states.

Observational copies export saved states and per-step column water
inventories before dynamics, after dynamics/clipping, after precipitation
and after damping. MATLAB skips expensive final normal-output postprocessing
after state export; therefore these comparisons do not certify its normal
NetCDF postprocessing. Fortran also writes its normal nine-field output.
The source updates/order remain unchanged; observations do not establish
closed physical budgets or total-energy conservation. Native water removal
is not transported surface rain. P3 requires its own separate tests.

`configuration.json` records source/input hashes and compiler options;
`status.json` records phases, driver PIDs, exits and file sizes, updating
every ten seconds during paired runs. Failures preserve logs/artifacts and
terminate the paired process. A normal exit without complete files fails.
Per-job `results.json` contains ranges, errors, weighted MF, water increments
and hashes. Completed reports remain pending scientific review.

## Momentum layout preservation and output audit

The author-enabled PMD/PMDv are packed into the same contiguous source-level
layout as PMB. OpenMP distributes independent output points; each reduction
still sums source levels first, forcing ACEs second, then adds PMB, PMDv,
PMD separately. Binary64 coefficients and the SI-to-native DHh conversion
are unchanged. One temporary operator is used at a time.

For an existing completed pre-layout reference workspace, launch a fresh
prepared candidate with `--reference-work /absolute/reference --launch --long`.
The runner pins input identity, four-mode component bytes, native one-step
states, all four nonzero-MF one-step streams, and complete per-step budget
records from the interrupted slow trajectory. It stops at any bitwise
mismatch. `layout_preservation.json` records the exact hashes. The reference
source is retained in `docs/migration/v02187_momentum_layout_reference.tar.gz`;
raw runtime references remain in ignored workspaces.

A separate reproducible timing probe adds only system-clock observations to
isolated drivers. It excludes input initialization and compilation and requires
identical saved states:

```bash
python3 tests/slab/benchmark_layout.py OLD_WORK NEW_WORK FRESH_TIMING_WORK
python3 tests/slab/audit.py NEW_WORK --follow
```

The independent output auditor checks hashes, finite/nonnegative saved states,
area-mean MF correction, continuity of per-step inventories and precipitation
sign. For completed minute-output jobs, it checks all normal Fortran output
records are finite and their prognostics exactly equal real32 casts of the
saved states. Inventory bookkeeping closure does not certify physical water
conservation. It never modifies model output files.

Completed cases can be plotted without loading model operators or rerunning
integration. From MATLAB, add `tests/slab` and call
`plot_case('/absolute/WORK','dry_10min')` (or another completed job).
It exports MF time-height and final spatial comparisons in PNG/PDF with
separate difference scales, actual duration/input hashes and a pending-review
label. It requires a fresh `figures/` directory and uses the saved states.
