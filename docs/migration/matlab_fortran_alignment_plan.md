# Unified ACE alignment roadmap

Status: source candidates staged for validation, 2026-09-29. This replaces
the earlier strategy of advancing the active MATLAB layout on its own. The
S20/S24 utility staging is preserved for later milestones. Historical MATLAB
and Fortran source remains untouched.

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
The [static audit](v018_alignment.md) includes provisional review dispositions;
precipitation and ice-inversion differences still require focused evidence and
an explicit scientific decision. The MATLAB eight-ACE basis and Manus sounding
are preserved. The original Fortran initialization and PMB binaries have not
been located; an unverified PMB candidate has been extracted. Their provenance
and binary reads are recorded in the [v0.18 input contract](v018_input_contract.md).
No matched initial state, operator test, short run, or active-layout run has
been completed. The next action is to recover or reproducibly derive the
Fortran initialization input, verify the PMB candidate, and compare loaded
initial states. Keep any correction separate from the byte-identical source
copies.

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
ACE release. A source-staging merge into `main` provides a common baseline for
validation; it does not establish a release or scientific equivalence.
