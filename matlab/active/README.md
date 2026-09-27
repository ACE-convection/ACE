# Active MATLAB source staging

This directory contains reviewed utility copies from earlier MATLAB layout
work. The current milestone is
[unified v0.18 alignment](../../docs/migration/matlab_fortran_alignment_plan.md)
using historical source states. These S20/S24 utility copies are preserved for
later work; they are not the v0.18 validation source. No driver has been copied,
this is not a runnable package, and sounding and basis dependent tests remain
deferred.

The `numerics/` files and 25 thermodynamics functions are byte-identical to
their counterparts in both preserved S20 and S24 snapshots. Two additional
S20 copies, `inv_T_from_theta_e.m` and `time_integration/ssprk93.m`, remain
uncommitted as of this note; the inversion differs from S24. Some shared files
are also identical in the original Git utility tree and S19. See the
[cross-version inventory](../../docs/migration/matlab_shared_utility_inventory.md)
for exact groups and the files intentionally left in history.
The [driver dependency map](../../docs/migration/matlab_driver_dependencies.md)
records the missing utility and path contracts for each candidate main.
The [S20 staging note](../../docs/migration/matlab_s20_active_stage.md) records
the preserved utility copies and the later validation gate.

Do not combine these utilities with a historical driver solely by adding this
directory to the MATLAB path. Utility signatures and scientific behavior vary
between versions; a driver and its complete dependency set must be chosen
together.
