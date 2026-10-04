# Historical Fortran v0.20 / P3 development source

`src/ace_module.F`, `src/test.F`, `src/microphy_p3.F` and `makefile` are
imported from historical Fortran commit `88e4af5`. Its ancestry is joined to
the development branch; numerical source bytes are preserved. The
[source manifest](../docs/migration/v020_source_merge_manifest.json) and
[integration record](../docs/migration/v020_source_integration.md) describe
the import. The separate source repository's local driver/makefile changes
are excluded.

The historical makefile uses Intel `ifort`, real64 defaults and site-specific
netCDF paths. It builds the P3 module before ACE. No build or runtime test
has been performed for this integrated branch.

The imported driver enables P3 (`n_prog=11`) and still uses the eight-ACE
geometry. It expects `./input_data/ini_manus_208.dat`, `./input_data/PMB.dat`
and P3 lookup data relative to its run directory. P3 5.3.1 selects the
`p3_lookupTable_1.dat-v6.4-2momI` table under the current wrapper settings.
Data provision, compiler-specific binary record lengths, output directory
and a portable input interface require subsequent work. Lookup files are
present in the separate local source repository; this import does not copy
them into Git.

`src/ace_input.F` is retained from v0.18 but is not used by the historical
makefile/driver. The previous `--input`, `--output`, `--validate-input` and
other shared-input command interfaces are not implemented by this driver.
Known P3 zero-ice exceptions and diagnostic issues remain recorded in the
[code review](../docs/migration/v020_code_review.md).

For the accepted real32/real64 v0.18 implementation and its checks, use a
separate checkout of `v0.18.0`. Historical v0.20 numerical routines do not
automatically inherit the accepted v0.18 corrections.
