# v0.18 inverse-theta_e comparison

## Current workflow: targeted cases only

Sweep runs are suspended by developer instruction. The theta_e > 400 K case is deferred. To diagnose only the
known ice-saturation mismatch, prepare a fresh temporary workspace:

```bash
python3 tests/thermodynamics/trace_mismatches.py /tmp/ace_targeted_cases
cd /tmp/ace_targeted_cases
MATLAB_PREFDIR=/tmp/ace_targeted_cases/matlab-prefs matlab -batch run_targeted > matlab_trace.log 2>&1
```

The preparation compiles and runs Fortran for the original input and four nearby qt perturbations;
MATLAB then runs the same five decimal binary64 inputs. The five fixed inputs use relative qt changes [-1e-4,-1e-8,0,+1e-8,+1e-4];
this is a targeted boundary test, not a grid scan. Temporary logging
records Newton T/dT, consistency/phase comparisons and final branch, iteration
counts and status. Instrumentation changes no production files. Results
are in `fortran_trace.log`, `matlab_trace.log`, and `targeted_results.json`
(the latter contains MATLAB outputs; both implementations are in the logs).
The runner imports only the source-instrumentation helper from the legacy
scan module; it does not call a sweep driver or generate a grid.

## Historical scan runner (do not run for current investigation)

Compare instrumented copies of the actual scalar MATLAB
`inv_T_from_theta_e` and Fortran `inv_theta_e`. Both read identical binary64
`theta_e, qt, p` inputs. No independent reconstruction of these inputs is used.
The MATLAB reference keeps its original complex arithmetic. Fortran uses its
existing real-valued algorithm with GNU double-precision build flags.

Dependencies: Python 3, MATLAB, GNU Fortran and netCDF-Fortran (`nf-config`).
MATLAB must be able to reach its license server. The runner sets a temporary
`MATLAB_PREFDIR` under the work directory unless it is already configured.
Run from the repository root; use a fresh work directory.

```bash
# 696 manufactured physical/near-saturation/mixed-phase/dry states.
# Some manufactured theta_e values exceed 400 K at low pressure.
python3 tests/thermodynamics/sweep_inversion.py migration_work/thermo_focused

# 2,002 selected points within the requested Cartesian grid.
python3 tests/thermodynamics/sweep_inversion.py migration_work/thermo_pilot --mode pilot

# All 401,401 theta_e/qt combinations at 1100 hPa.
python3 tests/thermodynamics/sweep_inversion.py migration_work/thermo_1100 \
  --mode full --first-pressure-index 0 --stop-pressure-index 1

# Full 843,343,501-point Cartesian grid (not completed in the Step 3 review).
python3 tests/thermodynamics/sweep_inversion.py migration_work/thermo_full --mode full
```

Full-grid axes are generated from integer indices, with endpoints included:

| Axis | Values | Count |
| --- | --- | ---: |
| Pressure | `1100 - 0.5*i` hPa, `i=0..2100` (converted to Pa) | 2101 |
| theta_e | `200 + 0.5*j` K, `j=0..400` | 401 |
| qt | `k/10000` kg/kg, `k=0..1000` (0..100 g/kg) | 1001 |

Pressure ranges use zero-based indices and a half-open interval. Independent
pressure shards must have separate work directories. Chunk size defaults to
10,000 inputs; full inputs/results are not retained for every grid point.
The runner keeps aggregate maxima, counts, representative disagreements,
focused-case matrices, and the most recent shared-input/Fortran-output batch.

Create `STOP` inside the work directory to stop at the next checkpoint. To
resume, remove that marker and rerun the identical command with `--resume`.
The runner rejects a changed production-source hash or scan configuration.
A crash before a checkpoint can replay that chunk; it is not counted twice.
Use `--prepare-only` to compile and inspect the generated-source diffs without
starting MATLAB.

## Observation limits and reports

Both production inversions have no iteration limit. The **temporary test
copies only** stop each Newton branch after `--max-iterations` iterations
(default 1,000). This observes the original numerical path until that limit.
A capped call is unfinished, not a converged solution or agreement. It does
not prove the original unbounded call could never converge.

The 13 output columns are:

1. real parts of `T, qv, ql, qi`;
2. imaginary parts of `T, qv, ql, qi` (zero for Fortran);
3. branch, first-branch iterations, condensate-branch iterations, status,
   first-branch failure flag.

Branch codes: 0 no condensate, 1 liquid, 2 ice, 3 mixed. Status codes:
0 finite real converged, 1 iteration cap/unfinished, 2 nonfinite or
nonconverged exit, 3 complex MATLAB output, 4 excluded by the optional test-only es>p filter. The first-branch failure flag
records MATLAB's complex/NaN trigger and Fortran's NaN trigger respectively.

`summary.json` reports each status/branch count and decision/iteration
mismatches. Absolute and relative errors are computed only for pairs with
status 0 in both implementations; invalid/capped/complex cases remain in the
counts and examples. Relative error is `abs(F-M)/abs(M)` for nonzero MATLAB
reference values, with differing zero-reference values counted separately.
Exact numerical equality and binary64 bitwise equality are counted separately.
There is **no acceptance tolerance**, and a successful process exit means the
comparison ran, not that scientific equivalence passed.

`completed` means the requested scan or pressure shard completed;
`full_cartesian_grid_complete` is true only for completion of all 843,343,501
points. Partial pressure scans and pilot/focused scans cannot set that flag.

`configuration.json` records source hashes, baseline commit, compiler and
commands. MATLAB version is in the summary. The generated instrumentation
diffs and source copies are retained for review. JSON encodes NaN/Inf as null;
status/imaginary-part fields identify failed results, and focused MAT files
retain the raw arrays. These metrics do not define a release gate.

The optional `--exclude-es-above-p` filter uses the MATLAB no-condensate trial
state to compute es, before calling either full inversion. Only finite real
es > p is excluded (not equality). This is a test selection rule, not a model
change. Excluded cases have status 4 and branch -1 in both outputs; they are
not counted as successful agreement. Configuration schema 2 prevents resume
from older checkpoints with incompatible status counts.

## Specify the targeted liquid boundary

The default remains the known ice boundary. For the separately tested
liquid boundary, generate one input with the active MATLAB forward functions:

```bash
matlab -batch "addpath('tests/thermodynamics'); make_liquid_boundary('/tmp/liquid_base_input.json')"
python3 tests/thermodynamics/trace_mismatches.py /tmp/ace_liquid_cases \
  --base-input-json /tmp/liquid_base_input.json
cd /tmp/ace_liquid_cases
MATLAB_PREFDIR=/tmp/ace_liquid_cases/matlab-prefs matlab -batch run_targeted > matlab_trace.log 2>&1
```

The JSON contains `[theta_e K, qt kg/kg, p Pa]`. The runner tests only this
triple and its four nearby qt perturbations, and rejects nonfinite inputs or
theta_e outside 200..400 K. The default ice case is unchanged. This is not
a full-domain validation. See `docs/v018_liquid_boundary_validation.json`
for historical pre-derivative-fix outputs and the observed common offset.
Current liquid-correction results are in
`docs/v018_liquid_derivative_validation.json`.

## Review the single liquid Newton path without model edits

```bash
matlab -batch "addpath('tests/thermodynamics'); review_liquid_newton('/tmp/liquid_newton_review.json')"
```

This diagnostic checks the corrected active final temperature against its
analytic-derivative trace and compares that derivative with centered
differences at four step sizes. The pre-fix coefficient trace and four
test-only continuation steps are retained for comparison; legacy JSON
fields named `current` describe the pre-fix trace, and `hypothetical`
describes the now-applied analytic coefficient. The existing 0.001 K stopping
threshold is retained. Running the diagnostic changes no production code.

## Validate the approved liquid derivative fix: exactly 25 inputs

```bash
python3 tests/thermodynamics/validate_liquid.py /tmp/ace_liquid_25_cases
cd /tmp/ace_liquid_25_cases
MATLAB_PREFDIR=/tmp/ace_liquid_25_cases/matlab-prefs matlab -batch validate_liquid > matlab.log 2>&1
```

This calls no sweep driver. It compiles source copies with branch/status
instrumentation and constructs the original five liquid inputs plus twenty
explicit distinct states in `validate_liquid.m`. Bounds, es<p and uniqueness
are checked before inversion. Active MATLAB outputs are checked against
the instrumented outputs, with no acceptance tolerance. `results.json`
reports every case, convergence/iteration status, raw absolute/relative
errors and forward-inverse errors. A successful process exit means the
validation ran; inspect the reported differences.

The liquid derivative review diagnostic now checks its analytic trace
against the corrected active routine. Its old-coefficient trace is retained
as a pre-fix comparison, not as the current production algorithm.

## Validate the approved ice derivative fix: exactly 25 inputs

```bash
python3 tests/thermodynamics/validate_ice.py /tmp/ace_ice_25_cases
cd /tmp/ace_ice_25_cases
MATLAB_PREFDIR=/tmp/ace_ice_25_cases/matlab-prefs matlab -batch validate_ice > matlab.log 2>&1
```

The five ice-boundary inputs and twenty explicit cold states are defined in
`validate_ice.m`. Bounds, es<p and uniqueness are checked before inversion.
No sweep driver is called. The output includes the same branch/status/error
fields as liquid validation plus a full analytic H-derivative comparison
against centered finite differences at four step sizes. Zero-reference
relative errors are undefined, not treated as zero relative errors. There
is no tolerance adjustment or implied full-domain release pass.

## Inspect exactly 25 fixed mixed-phase/endpoint states

```bash
python3 tests/thermodynamics/validate_mixed.py /tmp/ace_mixed_25_cases
cd /tmp/ace_mixed_25_cases
MATLAB_PREFDIR=/tmp/ace_mixed_25_cases/matlab-prefs matlab -batch validate_mixed > matlab.log 2>&1
```

The twenty-five explicit states in `validate_mixed.m` cover interior mixed
partitioning, pure-phase T0 endpoints, small condensate and T0 +/- 1e-6/
1e-3 K. Actual phase-comparison values are logged in `matlab.log` and
`fortran_phase.log`. `results.json` contains all inputs, outputs, branches,
iterations, statuses, numerical errors, forward errors and water closure.
No grid driver or production mutation is performed by this runner. Test-only
logging in source copies does not alter the phase comparison expressions.

## Validate 1200 stratified atmospheric conditions

```bash
python3 tests/thermodynamics/validate_atmosphere.py /tmp/ace_atmosphere_1200
cd /tmp/ace_atmosphere_1200
MATLAB_PREFDIR=/tmp/ace_atmosphere_1200/matlab-prefs matlab -batch validate_atmosphere > matlab.log 2>&1
```

This prepares exactly 1200 unique accepted inputs with seed 180103:
300 unsaturated, 250 liquid, 250 ice, 200 model mixed phase at T0 and
200 near-boundary cases. Paired vertical p/T envelopes and condensate bounds
are in `validate_atmosphere.m`; candidates outside theta_e 200..400 K or
with no-condensate es>p are excluded before inversion. It is not a Cartesian
sweep. Every case is compared with active MATLAB and, for converged calls,
with a separately compiled uninstrumented Fortran executable.

`results.json` retains raw per-case arrays and summary metrics. Committed
review artifacts are `docs/v018_atmospheric_validation.md`, its JSON summary
and `tests/thermodynamics/results/atmospheric_validation.csv`. The completed
run found one pure-ice endpoint branch difference; do not interpret its
successful process exit as a 1200-case equivalence pass. Production code
and tolerances remain unchanged by this validation.

## Preview an unapproved phase-endpoint rule (temporary copies only)

```bash
python3 tests/thermodynamics/preview_phase_endpoints.py /tmp/ace_phase_preview
cd /tmp/ace_phase_preview
MATLAB_PREFDIR=/tmp/ace_phase_preview/matlab-prefs matlab -batch preview_phase_endpoints > matlab.log 2>&1
```

This reads the committed 1200-case CSV without regenerating inputs, applies
a candidate rule in temporary inverse copies only, and appends eighteen ULP
neighbors of the ice/liquid endpoints. `proposed_model.patch` is a review
artifact, not an applied fix. The completed preview eliminated the original
1200 branch mismatches but found one new-edge neighbor mismatch. See
`docs/v018_phase_endpoint_proposal.md`; do not treat the candidate as a
complete alignment correction or tune its factor merely to make tests pass.
