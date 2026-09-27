# Active MATLAB source staging

This directory contains reviewed utility copies while the active model layout
is being organized. No driver or complete runnable package is selected here.
The developer will select a version for runtime testing after source
organization; sounding and basis dependent tests are deferred until then.

The current `numerics/` and `thermodynamics/` files are byte-identical to their
counterparts in both preserved S20 and S24 snapshots. Some are also identical
in the original Git utility tree and S19. See the
[cross-version inventory](../../docs/migration/matlab_shared_utility_inventory.md)
for exact groups and the files intentionally left in history.
The [driver dependency map](../../docs/migration/matlab_driver_dependencies.md)
records the missing utility and path contracts for each candidate main.

Do not combine these utilities with a historical driver solely by adding this
directory to the MATLAB path. Utility signatures and scientific behavior vary
between versions; a driver and its complete dependency set must be chosen
together.
