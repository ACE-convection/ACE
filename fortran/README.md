# Fortran v0.18 implementation

Current sources are in `src/`, with `makefile` at this root. The original
Intel defaults remain in the makefile. The accepted comparisons used
GNU Fortran 11.2.0, binary64 and netCDF-Fortran:

```bash
make FC=gfortran \
  FCFLAGS='-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none' \
  FINCLUDE="$(nf-config --fflags)" \
  LDLIBS="$(nf-config --flibs) -Wl,-rpath,$(nf-config --prefix)/lib"
./ace_model.exe --validate-input /tmp/manus_init.bin
```

Run these commands from `fortran/`. The default shared input is
`../data/input/manus208.nc`; `--input` accepts an explicit path.
Use `--output` with a writable output path when running the production
driver. Existing `--legacy-input`, `--intervals` and validation interfaces
remain available. Compiler flags and numerical routines are unchanged
by normalization.

Use the repository-root commands in [tests/README.md](../tests/README.md)
for the developer-accepted singleACE and multiACE cases. See the
[shared input schema](../docs/shared_input.md),
[historical recovery map](../docs/migration/v018_normalization.md), and
[v0.18.0 accepted scope](../docs/releases/v0.18.0.md).
