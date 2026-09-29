# Fortran v0.18 source candidate

This directory is temporary migration/alignment scaffolding. The
[unified roadmap](../../docs/migration/matlab_fortran_alignment_plan.md)
requires v0.18 validation, a separately reviewed promotion into `fortran/`,
and validation of that normalized checkout before unified `v0.18.0`.
Historical source remains recoverable through Git.

This directory stages the Fortran source at original Git commit `ffdd734`,
the target of the historical Fortran `v0.18` tag. `makefile`,
`src/ace_module.F`, and `src/test.F` are byte-identical copies from that
commit. The original history is preserved under
`fortran/history/original_git/` through a non-squashed subtree merge. The
December 2024 alignment claim at `bb72a55` remains a separate historical
anchor; later scientific changes are present in `ffdd734`.

No source, compiler flag, array order, or numerical method has been adapted
here. The makefile expects Intel Fortran and its configured netCDF library
paths. The source expects `input_data/ini_manus_208.dat` and `PMB.dat`, which
have not been located in this repository. This staging has not been built or
compared with the MATLAB candidate.

Recover or reproducibly derive the inputs and document their binary record
conventions before runtime validation. Review source differences separately;
byte-identical staging does not establish MATLAB-Fortran equivalence.

The original Fortran files contain trailing whitespace and a blank line at
the end of `makefile`. `git diff --check` reports these inherited formatting
issues; they are retained to preserve byte identity in the source-import
commit.
