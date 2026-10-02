# MATLAB v0.18 implementation

Current sources live directly in this directory. `ace.m` retains its local
dynamics/time-integration routines and uses `util_weno/`, `util_plume/` and
`util_thermodynamics/`. Do not add historical/later-version utilities to the
MATLAB path. Those sources remain recoverable from Git; see the
[normalization map](../docs/migration/v018_normalization.md).

From this directory, `ace` reads `../data/input/manus208.nc` by default.
Set `ACE_INPUT_FILE` to an absolute path to select another shared case;
`ACE_INPUT_MODE=legacy` and `ACE_LEGACY_DATA` retain the legacy comparison
route. Full interactive diagnostics retain their original toolbox/data
requirements. The tested comparison drivers skip unused diagnostics.

Run the developer-accepted Manus cases using the repository-root commands
in [tests/README.md](../tests/README.md). MATLAB R2023b Update 9 was used.
See the [shared input schema](../docs/shared_input.md) and
[v0.18.0 accepted scope](../docs/releases/v0.18.0.md).
