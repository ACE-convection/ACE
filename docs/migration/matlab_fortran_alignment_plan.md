# Unified ACE alignment roadmap

Status: source candidates staged on `feature/v018-unified`, 2026-09-28. This
replaces the earlier strategy of advancing the active MATLAB layout on its own.
The S20 staging work remains on `refactor/matlab-active-layout` for a later
milestone. Historical MATLAB and Fortran source remains untouched.

```text
v0.18 unified validation and release
    ↓
v0.20 publication and reproducibility release
    ↓
v0.24 unified active development
```

## Current milestone: v0.18

Reconstruct the October 2024 MATLAB v0.18 source and the corresponding
December 2024–January 2025 Fortran state. Establish what is actually shared,
record differences, and validate both implementations with matched inputs.
The candidate commits, component audit, inputs, test gate, and release criteria
are in [v0.18 alignment](v018_alignment.md).

## Source staging progress

| Component | Pinned state | Current result |
| --- | --- | --- |
| MATLAB | Original Git `a328496` | `matlab/active/ace.m` and 20 named utility dependencies are byte-identical copies. The driver's original `pwd` and `../data/` assumptions remain. No runtime input has been installed for this layout. |
| Fortran history | Original Git `ffdd734` | Non-squashed subtree merge `399b994` preserves the original history under `fortran/history/original_git/`, with `ffdd734` as a parent. The historical `v0.18` tag remains unchanged. |
| Fortran active source | Original Git `ffdd734` | `fortran/active/makefile` and both `src/*.F` files are byte-identical copies. The original Intel compiler and binary input assumptions remain. |

This fixes the source candidates for review, not their scientific agreement.
No MATLAB-Fortran numerical comparison or active-layout run has been performed.
The next decision is to classify the known differences in the audit, especially
thermodynamic inversion, precipitation splitting, WENO boundaries, state
mapping, and pressure-kernel ordering. Keep any correction separate from these
byte-identical source copies. The preserved input files, Fortran binary reads,
and provisional PMB extraction are recorded in the
[v0.18 input contract](v018_input_contract.md).

Action sequence for this milestone only:

1. Review the candidate commits and the known scientific differences in the
   v0.18 audit. Decide which differences are accepted v0.18 behavior and which
   require a separately reviewed correction.
2. Recover or reproducibly derive the Fortran initialization and PMB binary
   inputs from the preserved MATLAB basis and Manus sounding. Record hashes,
   array ordering, units, compiler and binary record conventions. Keep the
   historical sources unchanged.
3. Run each preserved candidate and its active-layout copy in isolated,
   reproducible environments with the same reviewed inputs. Compare the
   initial state, selected operators or one-step tendencies, and a short run
   before treating the staged layout as validated.
4. Document tolerances, numerical results, accepted differences and any
   corrections. Pin the jointly validated source and data provenance before
   declaring the unified release.

## Later milestones: sequence only

**v0.20:** after v0.18 is stable, use the preserved packaged MATLAB S20
implementation as the scientific baseline, align Fortran, and perform stronger
cross-implementation validation for publication and reproducibility.

**v0.24:** after v0.20 is stable, advance MATLAB and Fortran together toward
the S24 formulation and use it as the basis for the main active development
line.

These later milestones have no implementation work in the current task.
Future architecture intends a shared top-level `data/` and common netCDF
input; its interface is not designed here.

## Git representation

Keep source-history markers, including `matlab/git/v0.18-*` if introduced for
the preserved MATLAB commits, separate from unified ACE releases. The existing
Fortran `v0.18` tag points to `ffdd734` and is historical evidence, not a
jointly validated unified release. Preserve its target and meaning.

After validation, a unified release commit should contain the reviewed MATLAB
and Fortran source states, validation instructions/results, and input
provenance. Only then may an annotated `v0.18.0` tag identify the first unified
ACE release. Do not merge the staged candidates into `main` or create that tag
until the validation gate and scientific-difference review are complete.
