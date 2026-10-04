# Unified ACE development roadmap

Updated 2026-10-04 after final release `v0.18.0` at `d7d25b1`.
This document owns the forward development sequence. Accepted results and
limitations belong in the [release record](../releases/v0.18.0.md);
historical evidence is indexed in [migration records](README.md).

## Completed v0.18 milestone

| Work | Completed evidence |
| --- | --- |
| Preserve MATLAB/Fortran history and collected snapshots | [Import record](matlab_import_plan.md), lineage and LFS manifests |
| Recover matched inputs and implement shared NetCDF readers | [Input provenance](v018_input_contract.md), [shared schema and validation](../shared_input.md) |
| Review and implement focused scientific alignment | [Alignment summary](v018_alignment.md) and its linked reports |
| Accept physical evolution for this milestone | Manus singleACE 3 h and outer-pulse multiACE 12 h, with native precipitation; developer acceptance recorded in the release |
| Normalize current source roots | [Path map and manifest](v018_normalization.md), recovery commit `c9ae729` |
| Verify behavior after normalization | GNU build/default input checks and three full reruns; all saved numerical values exactly reproduced within each implementation |
| Accept tested single precision | Stable precipitation evaluation, singleACE/multiACE figures and matched real64 control; physical evolution accepted on 2026-10-04 |
| Publish final v0.18 | `main` merge `d7d25b1`, annotated `v0.18.0`, both pushed; developer reports GitHub Release published |

Broader phase, budget and compiler questions remain documented limitations,
not unfinished release gates for this accepted v0.18 milestone. The original
pre-release plan is recoverable at
`2b62c29:docs/migration/matlab_fortran_alignment_plan.md`.

## Repository philosophy and development sequence

Current sources live directly under `matlab/` and `fortran/`, shared inputs
under `data/`, with `tests/`, `docs/` and `tools/` at repository root.
Migration-only `active/` and `history/` source copies have been retired from
the checkout; Git ancestry preserves them. Use the source-root READMEs for
current build/run paths rather than historical staging instructions.

MATLAB and Fortran advance in one ACE repository history. Each unified
release tag identifies one reviewed commit containing both implementations.
MATLAB is the dynamics reference; additional Fortran-only physics is allowed
when documented. Shared components need comparison, not file-by-file identity.
Keep structural changes separate from scientific changes and use dedicated
branches for reviewable work. Preserve existing release targets and historical
marker meanings; snapshot names do not certify model execution.

## Later milestones

| Milestone | Direction and evidence needed |
| --- | --- |
| v0.19, if needed | Use S19 and standalone artifacts as comparison evidence; do not infer missing parent edges or require a separate release from import order. |
| v0.20.0 | Joint publication/reproducibility release. Packaged MATLAB S20 is the scientific reference. Recover the intended 2D basis and builder inputs, review driver/library contracts, then establish a reference run and a matched Fortran comparison. |
| v0.24 | Joint active development using S24 p87/GF87 formulation evidence. Recover kernel inputs and fingerprint logs; review CPU/GPU behavior separately. Missing v0.21–v0.23 source history is not reconstructed by interpolation. |

For v0.20 input/API blockers, start with the
[driver dependency map](matlab_driver_dependencies.md) and
[standalone readiness](matlab_validation_readiness.md).
For v0.24, use the [p87 input/reference checklist](matlab_p87_validation_gate.md).
The old S24 layout proposal is historical evidence only.

## v0.20 preparation started (2026-10-04)

The developer authorized moving on after publishing v0.18. Development starts
from `d7d25b1` on `migration/v020-preparation`. The accepted real32 trajectory
differences and existing scientific limitations do not reopen v0.18 release
gates.

1. Inspect the packaged MATLAB S20 reference and its own utility collection,
   recoverable at `c9ae729:matlab/history/snapshots/ACE_V020/`. Keep the
   standalone v0.20 driver distinct; its utility pairing is a migration
   convention, not proof of historical runtime compatibility.
2. Identify the intended 2D basis, builder prerequisites and sounding data.
   Review grid dimensions, operator orientation and input contracts before
   generating or substituting inputs. The older readiness reports describe
   missing data at their review dates; check current availability separately.
3. Recover the intended historical Fortran P3 interface and identify its P3
   source version, lookup data, build dependencies and attribution. The old
   audit refers to commit `381402d`, which does not resolve as an object in
   the current unified checkout. It has now been located in the separate
   `ACE_FORTRAN` repository at historical v0.20 `88e4af5`; see the
   [source and input inventory](v020_preparation.md).
4. Present a small source-migration proposal covering state variables,
   thermodynamic formulation and shared dynamics. Review scientific changes
   before replacing active source or public interfaces, as required by
   `AGENTS.md`.
5. Establish the MATLAB S20 dynamics reference and matched Fortran comparison,
   then validate Fortran-only P3 coupling separately from shared dynamics.
   Check precision and build compatibility for the selected P3 version.

This preparation changes documentation and the development branch only.
It does not import historical sources, select a new P3 version or change
production algorithms. MATLAB is the dynamics reference; P3 is planned as
Fortran-only physics rather than a required MATLAB implementation.

## Fixed initial runtime comparison

Reuse the developer-designated Manus 208 singleACE reference: saturated
+1 K bubble at levels 11–51, no initial condensate, precipitation disabled,
3 h, dt=4 s, output every 60 s, full eight-ACE geometry/PMB, original damping
and MF diffusion disabled. The precipitation-enabled variant and 12 h
outer ACE 8 pulse multiACE case provide additional comparisons.

[Tests](../../tests/README.md) own the exact settings, runners and references.
Later-version adapters must record any unsupported configuration or scientific
contract difference; do not silently replace the case with version defaults.
Assess error metrics and physical evolution. Exact preservation after a path
change does not impose byte equality across implementations or versions.

## Shared runtime data direction

The shared `ACE-case-input-1` NetCDF interface is implemented, and the pinned
Manus case is `data/input/manus208.nc`. [Shared input](../shared_input.md)
owns its schema, conversion and reader validation. Extend schemas only through
separate reviewed work; S20/S24 bases are not interchangeable with v0.18 PMB.

Large historical MAT/NC data use Git LFS. Retain hashes, source provenance and
conversion/readback evidence. The completed [LFS migration](matlab_data_lfs_migration.md)
and its commit map are preservation records, not commands to rewrite history
again. Historical binary contracts remain references for legacy input reads.
