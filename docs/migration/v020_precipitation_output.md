# Minute precipitation output for diagnostic runs

The developer stopped the six precipitation-diagnostic replays on
2026-10-12, then requested minute accumulation output. The
[diagnostic runner](../../tests/khn26/precip_timeseries.py) now generates
MATLAB native, Fortran native and Fortran P3 diagnostic copies that
accumulate precipitation internally every model step and write only at
60-second boundaries. Production sources and preserved run artifacts are
unchanged. No model simulation was restarted for this output change.

## Amounts and cadence

For each ACE column, the diagnostic integrates rate times dt at every
4-second step. After 15 steps it writes:

- amount accumulated during that minute, in mm water equivalent;
- total amount accumulated from t=0 through the end of that minute, in mm.

Only the minute accumulator is reset after writing. The running total is
retained. An initial record at t=0 contains zero amounts. A complete
three-hour run therefore produces 181 records, at 0, 60, …, 10,800 s.
An interrupted partial minute is not labelled as a completed minute.
The current run contract requires dt to divide 60 s; a step crossing an
output boundary raises an error rather than assigning its amount to the
wrong interval.

Native schemes integrate the actual applied column-total-water sink,
`-sum(dqt_dt * reference_density * dz)`, over the physical scalar levels.
kg m−2 equals mm water equivalent. This is removal-equivalent precipitation,
not transported surface rainfall. P3 integrates its returned surface liquid
and solid fluxes in m s−1, multiplied by 1000 to convert to mm s−1. These
definitions remain distinct in the output metadata and plot captions.

## Binary record layout

`full/precip_accumulation.bin` contains little-endian real64 records for the
recorded GNU real64 builds. Each record is:

| Block | Values | Units |
| --- | --- | --- |
| Time | One end-of-interval time | seconds |
| Minute liquid or native total | One amount per ACE | mm |
| Minute solid | One amount per ACE; zero for native | mm |
| Cumulative liquid or native total | One amount per ACE | mm |
| Cumulative solid | One amount per ACE; zero for native | mm |

For 101 ACEs, each record has 405 doubles. Initial amounts are zero.
P3 total precipitation is the sum of its liquid and solid blocks. Native
uses the first component for total removal; it does not diagnose a liquid/
solid surface split. The binary file has no separate header; its layout,
version, column count and interval are recorded in `configuration.json`.

`read_minute_precip()` validates the record count, time axis, finite and
nonnegative amounts, initial zeros and consistency of each component's
minute amounts with its running accumulation. Plotting uses these stored
amounts directly; minute-average mm h−1 is derived as minute amount ×60.
The NPZ postprocessing artifact also retains the original minute amounts.
ACE 1 and the domain area-weighted mean remain separate plot scopes.

## Preserved stopped workspace

`migration_work/khn26_precipitation_three_hour` remains stopped and contains
the earlier per-step-rate format, its exact source/script copies and stop
record. It is not rewritten or automatically resumed. The current runner
rejects that legacy layout. Any later authorized experiment needs a fresh
workspace prepared with the new format; preparation and launch are separate
explicit commands.

## Authorized multiACE-only background launch

The developer subsequently authorized only multiACE MATLAB native,
Fortran native and Fortran P3, starting together for three hours.
The fresh workspace is `migration_work/khn26_multi_precipitation_three_hour`;
all three launched at 2026-10-12 10:49:22 UTC. Supervisor PID at launch:
3673749; model PIDs: MATLAB 3673775, Fortran native 3673776, P3 3673778.
These identify the launch, not completed results.

MATLAB has no imposed thread setting, thread-control environment variables
or CPU binding; its startup query reports the platform default of 80
computational threads. Both Fortran builds use real64 OpenMP, request and
cap 32 threads with dynamic teams disabled, and assert team size 32 at
startup. The P3 assertion only adds thread evidence to the isolated driver.
No singleACE job is prepared or launched by this configuration. The minute
accumulators and reader are unchanged from the validated output change.
Host process inspection after launch confirmed all three models and the
supervisor alive, with 32 threads in each Fortran process. MATLAB's queried
80 computational threads are distinct from its auxiliary/runtime threads.

```bash
python3 tests/khn26/precip_timeseries.py NEW_WORKSPACE --prepare --cases multiACE
python3 tests/khn26/precip_timeseries.py NEW_WORKSPACE --launch
```

The supervisor records progress in `status.json`. After all three complete,
it checks saved-state reproduction and precipitation records, then writes
ACE-1 and domain-area-mean three-line plots to
`docs/figures/khn26_multi_precipitation_3h`. All three subsequently completed by 2026-10-12 12:30:19 UTC. Each has
181 precipitation records, and its saved-state stream is byte-identical to
its own previous reference. [Results](../figures/khn26_multi_precipitation_3h/results.json)
and the ACE-1/domain-area-mean PNG/PDF curves are now preserved. The developer
reviewed these curves and accepted their differences for
[v0.20.0](../releases/v0.20.0-notes.md). Production sources remain unchanged;
minute precipitation output is still an isolated diagnostic-runner feature.

## Focused validation

[Output checks](../../tests/khn26/check_precip_output.py) exercise the actual
Fortran accumulator and generated MATLAB accumulator using known fluxes,
without an ACE integration. The fixtures check a partial minute, two full
minutes with changing rates, minute reset, running totals, water-equivalent
conversion and exclusion of the nonphysical top scalar slot in MATLAB.
The reader also rejects truncated records and an invalid clock. Four
instrumented Fortran module variants compile separately.

Both the MATLAB and checked GNU real64 Fortran fixtures passed. The
[versioned check results](../../tests/khn26/precip_output_results.json)
preserve the fixture expectations and code/output hashes. MATLAB used a
temporary preferences directory for the fixture; no ACE run was invoked.

These checks verify the output bookkeeping and compile compatibility;
they do not certify new model trajectories or physical precipitation budgets.
The diagnostic replay retains its saved-state reproduction check for any
future authorized full run.
