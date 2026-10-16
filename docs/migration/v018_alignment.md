# Unified ACE v0.18 alignment record

Updated 2026-10-02 after local release `v0.18.0` at `2b62c29`.
The developer accepted the Manus singleACE and twelve-hour multiACE physical
evolution for this milestone. [The release record](../releases/v0.18.0.md)
owns that scope, measured errors, normalization verification and limitations.
This summary owns the source selection and links to scientific evidence;
build/run commands belong in the source READMEs and [tests](../../tests/README.md).

## Accepted state and completed changes

The starting pair was MATLAB `a0f30cd` and Fortran `ffdd734`. The release
contains reviewed corrections on top of those candidates, not byte-identical
copies of either historical source. The complete pre-consolidation audit,
static component table and original release gates are preserved at
`v0.18.0:docs/migration/v018_alignment.md`.

| Change | Commit(s) | Evidence |
| --- | --- | --- |
| Shared NetCDF inputs, recovered profiles and PMB | `2537f46` | [Input schema/readback](../shared_input.md), [input provenance](v018_input_contract.md) |
| Fortran precipitation onset; MATLAB post-step splitting and qt clipping in both implementations | `1b3443c`, `b70343c` | [Thermodynamic review](../maintenance/history_summary.md#record-v018-thermodynamic-review) |
| Inversion, saturation roundoff and liquid/ice Newton derivatives | `516da38`, `1b00033`, `b5eaf39` | [Thermodynamic alignment](../maintenance/history_summary.md#record-v018-thermodynamic-alignment) |
| Fortran ice heat-capacity reference temperature | `1ac8d27` | [Ci alignment](../maintenance/history_summary.md#record-v018-ice-heat-capacity-alignment) |
| Fixed environmental reference Tv from shared input | `fdf4cd1` | [Reference-Tv alignment](../maintenance/history_summary.md#record-v018-reference-tv-alignment) |
| Source-root normalization, path-only driver adjustments | `9665658` | [Normalization map](v018_normalization.md) |
| Exact preservation in all three full Manus reruns after normalization | `9f83e23` | [Release verification](../releases/v0.18.0.md#normalization-and-local-release-procedure) |

## Scientific evidence and retained questions

| Evidence | Result or scope |
| --- | --- |
| [Initial runtime comparison](../maintenance/history_summary.md#record-v018-runtime-comparison) | Matched single/multi dry and precipitating 4 s / 120 s cases before the subsequent corrections |
| [Aligned runtime comparison](../maintenance/history_summary.md#record-v018-aligned-runtime-comparison) | Dry/liquid short trajectories after initial thermodynamic alignment |
| [Atmospheric validation](../maintenance/history_summary.md#record-v018-atmospheric-validation) | Documented thermodynamic probes and their limitations |
| [Ice trajectories](../maintenance/history_summary.md#record-v018-ice-precipitation-comparison), [mixed-phase trajectories](../maintenance/history_summary.md#record-v018-mixed-precipitation-comparison) | Focused single/multi short-run phase and active-precipitation checks |
| [Reference-Tv isolation](../maintenance/history_summary.md#record-v018-reference-tv-diagnostic) | Temporary diagnostic preceding the reviewed production change |
| [Mixed residual](../maintenance/history_summary.md#record-v018-mixed-residual-diagnostic) | Common-cache probes and finite-difference rounding contributions |
| [Forward evaluation](../maintenance/history_summary.md#record-v018-forward-evaluation-diagnostic), [pressure power](../maintenance/history_summary.md#record-v018-pressure-power-diagnostic) | Temporary substitutions isolate binary64 evaluation differences; not production fixes |
| [Phase-endpoint proposal](../maintenance/history_summary.md#record-v018-phase-endpoint-proposal) | Known counterexamples remain; no endpoint proposal applied for this release |
| [SingleACE, no precipitation](../maintenance/history_summary.md#record-manus208-single-saturated-bubble-3h), [with precipitation](../maintenance/history_summary.md#record-manus208-single-saturated-bubble-precip-3h) | Frozen Manus 208 three-hour references |
| [MultiACE outer pulse](../maintenance/history_summary.md#record-manus208-multi-outer-pulse-12h) | Twelve hours with native precipitation, matched initial state, eight ACEs and the combined MF plot |

Each linked scientific report retains its original run settings, source hashes
and numerical evidence. Earlier statements about missing data, available tools
or unresolved changes describe that report's tested revision; they do not
supersede the final release decision.

Known precipitation masks, boundary behavior, phase-endpoint counterexamples,
finite-difference rounding and late trajectory drift remain documented.
Full physical water/energy budget closure, universal phase/branch identity,
Intel/GNU equivalence and independent observational validation are not claimed.
These questions are retained for later scientific work; the developer's bounded
acceptance does not add them as new blockers to the completed v0.18 release.
No universal error tolerance or cross-implementation byte equality is imposed.

## Historical candidate identities

The table below records the original selection, not current release behavior.
Its candidate/validation descriptions belong to the 2026-09-28 source audit.
Historical paths can be inspected at `c9ae729`; current sources are directly
under `matlab/` and `fortran/`.


| Role | Commit and evidence | Decision / uncertainty |
| --- | --- | --- |
| MATLAB original v0.18 | `a0f30cd` (2024-10-14), `ace_v018_dev_8aces.m` plus that commit's utility tree. Message identifies a staggered grid and vector WENO. | **Primary MATLAB candidate.** It predates the Fortran reproduction claim and keeps the optional original MF diffusion routine. This is a source candidate, not a validated release. |
| MATLAB January v0.18 | `25d49e7` (2025-01-15), same driver plus 61 added and 4 removed lines; utilities unchanged. | Retain as a distinct historical state. It adds joint implicit tracer/MF diffusion, replaces the optional call with `ImDiff`, and leaves two local functions named `ImDiffMF`; the default diffusion switch is off. Its science and parse behavior need separate review. It cannot silently replace the October baseline. |
| Fortran alignment anchor | `bb72a55` (2024-12-16), message says it can reproduce MATLAB v0.18. | Important evidence of intent, with no archived matched output or input hashes found. The code suppresses all but the first ACE tendency, has no active precipitation sink, and its makefile lacks `-r8`. It is not sufficient as a unified release state. |
| Fortran v0.18 source candidate | `ffdd734` (2025-01-06 PST / 2025-01-07 UTC), target of the existing Fortran `v0.18` tag. Its history contains `daab45c` and `e586558` for precipitation, multiple ACEs and buoyancy changes. | **Primary Fortran candidate for validation**, with `bb72a55` retained as the original alignment anchor. The tag is a historical Fortran marker. Source changes after `bb72a55` include scientific changes, so alignment must be retested. |
| Beyond the boundary | After `ffdd734`, the later branch changes state ordering at `ad7d1b6` (2025-01-08), moves toward `th_q` at `ba6e11f`, changes to `th,qv,ql,qi` at `0d8dc4c`, and adds P3 at `381402d`; these enter main through `88e4af5`. | These identify the v0.18 boundary only. They are outside this audit. Do not substitute a later Fortran claim of MATLAB consistency for v0.18 evidence. |

The MATLAB original and January commits have the same v0.18 filename but
different model behavior when diffusion is enabled. The preserved
`matlab/history/original_git/ace_v018_dev_8aces.m` matches the January state;
use `a0f30cd` directly to inspect the original driver. The Fortran tag and the
December reproduction message also identify different source states. A joint
v0.18 release cannot be inferred from any of those labels.
