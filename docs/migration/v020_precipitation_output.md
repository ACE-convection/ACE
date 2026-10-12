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
