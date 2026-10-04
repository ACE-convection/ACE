# Fortran KHN26 alignment and P3 development source

`src/test.F` defaults to `../data/input/manaus1342_khn26.nc`. Shared slab
cases use dt=6 s, 360 one-minute output intervals and native precipitation.
The default prognostics are MF/theta_e/qt; the KHN26 saturated +0.25 K bubble
is initialized in ACE 1, levels 11–51, with zero initial MF. Environmental
Tv is reconstructed from theta_e/qt for slab cases.

From `fortran/`, build using the Intel makefile defaults or GNU real64:

```bash
make FC=gfortran \
  FCFLAGS='-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none' \
  FINCLUDE="$(nf-config --fflags)" LDLIBS="$(nf-config --flibs)"
./ace_model.exe --input /absolute/path/to/manaus1342_khn26.nc \
  --physics native --intervals 1 --output /existing/directory/fresh-state.dat
```

`--physics none` disables native precipitation. `--physics p3` selects the
retained eleven-prognostic P3 path and requires external lookup tables via
`--p3-lookup-directory` (default `./input_data/`). P3 remains an additional
Fortran-only scheme, not a KHN26 MATLAB equivalence claim. The source uses
P3 5.3.1 with `p3_lookupTable_1.dat-v6.4-2momI`; known historical P3 failures
remain recorded in [the code review](../docs/migration/v020_code_review.md).

`--dt` overrides the timestep and must divide 60 s for interval output.
`--steps 10 --state-output /fresh/state.bin` runs ten individual steps and
writes binary64 initial/evolved states without the nine-field output.
The stream header is three default integers (ncols,nz,n_prog), followed by
initial X, reference Tv, and saved X arrays in Fortran order. X includes the
extra environmental column (ncols+1,nz,n_prog). Interval runs optionally
write this stream at each saved minute.

`--validate-input /path/dump.bin` initializes then exits. Its four-integer
header is (ncols,nz,n_prog,ncoarse), followed by binary64 X, Ref, A, B, Tv0,
coarse_z and coarse_ze. This layout differs from the v0.18 validation dump.

`--legacy-input` retains original eight-ACE binaries under `./input_data/`,
P3 default, dt=2 s, initial MF pulse and historical 100-day duration.
Schema 1 is still readable; it retains these annular defaults. Schema 2
slab defaults apply even when P3 is explicitly selected. `--intervals`
always overrides duration. Output defaults to `./ace_state.dat`; model and
state output files must be fresh.

The nine-field direct-access output remains real32. Fields are MF, theta_e,
qt, ql, rain, qi, riming, RH and buoyancy for native/none; P3 uses theta and
qv in its second/third slots. Native rain/riming slots are zero. Record sizes
use `INQUIRE(IOLENGTH=...)`. Input/basis are binary64; model precision follows
compiler default real. Real64 numerical checks passed; real32 only compiled,
including the KHN26 finite-difference precipitation derivative.

Missing PMDv/PMD are explicitly disabled placeholders; initialization rejects
attempts to enable them. See the [integration record](../docs/migration/v020_khn26_integration.md),
[shared input](../docs/shared_input.md) and [KHN26 tests](../tests/khn26/README.md)
for evidence and remaining limits. Build different precisions in separate
directories. Use `v0.18.0` for accepted v0.18 tests.

### Reusable interp1

`src/ace_interpolation.F` provides unified vector interpolation supporting
PCHIP and MAKIMA. Both methods use double-precision formulas checked against
MATLAB R2023b. The old PCHIP routine was moved here and its two-point linear
case added. From another Fortran procedure:

```fortran
use ace_interpolation, only: interp1
call interp1(n,x,y,nq,xq,yq,'pchip',extrap=.true.)
call interp1(n,x,y,nq,xq,yq,'makima',extrap=.false.)
```

The optional `extrap` defaults true. False holds the nearest endpoint value
outside the sample interval. The slab model branch uses MAKIMA, annular uses
PCHIP, and both explicitly request extrapolation. Existing public PCHIP and
MAKIMA entries remain available. Arguments use the build's default real kind;
only real64 MATLAB numerical agreement is an acceptance requirement. Real32
compile compatibility is retained. See [interpolation tests](../tests/interpolation/README.md)
and [the dynamics record](../docs/migration/v020_dynamics_alignment.md).
