# Production interp1 comparison

This test compiles `fortran/src/ace_interpolation.F` and compares its unified
`interp1` against MATLAB R2023b in double precision. Supported methods are
`pchip` and `makima`; endpoint behavior is selectable between cubic
extrapolation and holding the nearest endpoint value. It does not open
scientific basis files or integrate ACE/P3.

## Fortran interface

```fortran
use ace_interpolation, only: interp1
call interp1(n,x,y,nq,xq,yq,'pchip',extrap=.true.)
call interp1(n,x,y,nq,xq,yq,'makima',extrap=.false.)
```

`extrap` is optional and defaults true, matching MATLAB's default for these
methods. False returns exactly y(1) or y(n) for queries below or above the
sample interval. Coordinates must be increasing, finite real vectors, with
at least two nodes. Two nodes use a line. Inputs and outputs follow the
build's default real kind; real64 is the numerical consistency requirement.
MATLAB's complex/ND/PP-object interfaces and NaN-input handling are outside
this ACE vector interface. Other methods are rejected.

The original PCHIP routine now lives in the same module. The public PCHIP
entry remains available from both `ace_interpolation` and `ace_module` for
compatibility; the model itself calls unified `interp1`. The public makima
entry also remains, with optional `extrap`.

## Run

From the repository root, use a fresh directory:

```bash
python tests/interpolation/run.py migration_work/interp1_check --prepare
MATLAB_PREFDIR=/tmp/ace-interp1-prefs matlab -batch "addpath('tests/interpolation'); reference(fullfile(pwd,'migration_work/interp1_check'))"
python tests/interpolation/run.py migration_work/interp1_check --compare
```

Requirements: Python NumPy, GNU Fortran and licensed MATLAB. The license
server may require execution outside the network sandbox. Preparation refuses
to overwrite a directory. Tests never update the tracked report automatically.

The real64 probe runs with array/runtime checks and invalid/zero/overflow
floating-point traps. Real32 is compiled, with no numerical acceptance
requirement. There are 21 deterministic cases (seed 20261004), 3,094 queries
per method/policy and 18,564 results across two methods and three policies
(explicit extrapolation, endpoint hold and omitted/default extrapolation).
Cases cover two/three nodes, constant/zero/linear oracles, plateaus, sign
changes, nonuniform grids, mixed scales, coordinate offsets, 201 synthetic
200 m basis edges, unsorted queries, knots, midpoints and extrapolation.

MATLAB uses `interp1(...,method,'extrap')`. Its held-endpoint reference
replaces only interval-exterior outputs with the corresponding endpoint
value. Those outputs must match Fortran exactly. Default and explicit
Fortran extrapolation outputs must also match exactly. Each method must
reject one node, repeated/decreasing nodes; an unsupported `linear` method
must be rejected by the unified interface.

## Recorded result

The [summary](results.json) records source/test hashes and tool versions.
MATLAB R2023b/GNU 11.2.0: all double-precision checks passed.

| Method/policy | Maximum amplitude-scaled error |
| --- | --- |
| PCHIP extrapolate | 9.57623e-16 |
| PCHIP hold endpoint | 6.66134e-16 |
| MAKIMA extrapolate | 6.65328e-16 |
| MAKIMA hold endpoint | 7.16906e-16 |

Scale is `max(max(abs(MATLAB reference)),max(abs(input y)),float64 tiny)`.
The fixed tolerance is 128 times float64 epsilon (2.84217e-14).
These are amplitude-scaled errors, not pointwise relative errors near zero.
Numerical agreement is within tolerance; bitwise identity is not claimed.

Full values, compiler/rejection logs, fixtures and metrics are retained in
ignored `migration_work/interp1_validation_20261004/`. The preceding makima
comparison remains preserved under
`migration_work/makima_validation_20261004_repeat/`. Actual basis and model
trajectories remain pending.
