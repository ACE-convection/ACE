# Fortran v0.20 / P3 development source

The driver defaults to shared NetCDF input using the v0.18 reader pattern,
extended to dynamic grids/geometry and three S20 basis operators. The default
file is `../data/input/goamazon314_s20.nc`; it is pending provision of the
correct S20 basis and conversion. From `fortran/`:

```bash
make
./ace_model.exe --input /absolute/path/to/case.nc \
  --p3-lookup-directory /absolute/path/to/p3-tables \
  --intervals 2 --output /existing/output/directory/state.dat
```

The Intel makefile defaults remain. `ace_input.F` now builds before the ACE
module and driver. A GNU configuration uses:

```bash
make FC=gfortran \
  FCFLAGS='-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none' \
  FINCLUDE="$(nf-config --fflags)" LDLIBS="$(nf-config --flibs)"
```

GNU real32/real64 compile and link checks have passed; model testing is
deferred. Both schema 1 (v0.18 annular) and
schema 2 (S20 slab) can be read; model arrays use the file dimensions. Schema
2 loads PMB, PMDv and PMD in explicit API order and stores them in the
Fortran model layout. PMDv/PMD branches are implemented with disabled
defaults matching MATLAB; activation requires coefficient-unit review.
The fixed environmental Tv_zc reference, slab area-mean buoyancy removal,
momentum/tracer outer boundaries and area-mean MF removal follow the documented
[dynamics alignment](../docs/migration/v020_dynamics_alignment.md).
Complete MATLAB equivalence has not been established.

`--legacy-input` reads the original eight-ACE binary files under
`./input_data/`. `--intervals` selects 60-second output intervals; historical
P3 defaults remain dt=2 s, inner MF pulse=0.3 and 100-day integration length
unless intervals are explicitly set. `--output` overrides the output path.
`--p3-lookup-directory` overrides `./input_data/` for P3 tables. The active
wrapper uses P3 5.3.1 and `p3_lookupTable_1.dat-v6.4-2momI`.

`--validate-input dump.bin` performs initialization and basis loading only,
then writes a stream dump. It has four default-integer header values
(ncols,nz,n_prog,ncoarse), followed by binary64 X, Ref, A, B, Tv0, coarse_z,
coarse_ze in Fortran order. Its P3/dynamic-grid layout differs from the v0.18
dump; older validation tools need adapters before use.

Input/output binary record lengths use `INQUIRE(IOLENGTH=...)`. NetCDF input
and basis storage remain binary64; model arrays follow the compiler default
real kind. The legacy nine-field real32 output layout is retained. Both
normal and final output now refresh vapor before calculating RH/buoyancy.

See [shared input](../docs/shared_input.md),
[the adapter record](../docs/migration/v020_shared_input_adapter.md) and
[known code findings](../docs/migration/v020_code_review.md). P3 exceptions
and further cross-language dynamics alignment remain deferred work.
Use a separate `v0.18.0` checkout for accepted release tests.
