# MATLAB v0.18 source candidate

This directory stages the October 2024 MATLAB v0.18 source at original Git
commit `a328496`. `ace.m` is a byte-identical copy of
`a328496:ace_v018_dev_8aces.m`; only its filename changed. The 20 utility files
under `util_weno/`, `util_plume/`, and `util_thermodynamics/` are byte-identical
copies from the corresponding paths at that same commit. They cover the named
external calls found by static inspection of the driver and their utility
call chain. The original historical source remains unchanged.

The driver derives utility paths from `pwd` and expects its `util_*` folders
there. It expects the eight-ACE basis and ARM soundings under `../data/`
relative to `pwd`. Those inputs have not been installed for this active tree,
and no path, constant, equation, or numerical method has been changed. This
source staging has not been run or compared with the Fortran candidate.

Use the preserved `a328496` source as the reference for any later path or
runtime adaptation. Keep those adaptations and scientific corrections in
separate reviewed changes.

The original source contains trailing whitespace. `git diff --check` reports
those lines in this copy; they are retained to preserve byte identity and
should not be reformatted in the source-import commit.
