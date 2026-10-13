# v0.20 source and input preparation

Current reference decision (2026-10-04): the author-selected v0.20 release
reference is November 2025 KHN26. This page preserves the earlier S20/P3
work and its evidence scope; use the [KHN26 review](v020_khn26_review.md)
for the original source/input review. Active KHN26 adapters and numerical
evidence are recorded in the [KHN26 integration](v020_khn26_integration.md).

Reviewed 2026-10-04 on `migration/v020-preparation`, based on released
`d7d25b1`. This is source inspection and preservation of existing probe
evidence, not a new simulation or acceptance of the historical v0.20 model.
[Machine-readable inventory](v020_source_inventory.json) records file hashes.

## Source identities

| Component | Confirmed source | Current finding |
| --- | --- | --- |
| MATLAB packaged S20 | `c9ae729:matlab/history/snapshots/ACE_V020/` | 52 files, including `ACE_V020_2D88ACEs.m` and its own libraries; no basis/sounding directory in this package |
| Historical Fortran v0.20 | `/scratch/peter50504/ACE_FORTRAN`, tag `v0.20`, commit `88e4af5892ec2b93f6bde65fbc11c506276e420f` | P3 module, ACE wrapper and build integration are present |
| Initial P3 addition | `381402d` in that separate Fortran repository | Resolves there; the unified repository imported Fortran only through `ffdd734`, so later P3 commits are not currently imported |
| P3 source | Historical `src/microphy_p3.F` | Source declares version 5.3.1, last updated June 2023; equivalence to a particular upstream revision has not been established |

The separate Fortran repository is on `jupyter` at `88e4af5`, with local
modifications to `makefile` and `src/test.F`. Preserve these changes. Its
`ace_module.F` and `microphy_p3.F` match HEAD. Migration should use pinned
committed files and review local driver/build modifications separately.
The unified v0.18 production source remains unchanged.

## MATLAB S20 input contract

The packaged driver requires `data/basis/COMPOSITE_ACE_BASIS_2D_V020.mat`,
loading `D`, `Z`, `PMB`, `PMD`, and `PMDv`. Operators are indexed by vertical
response, vertical forcing, forcing region, response region. `Ni=length(D)`
determines the entity count; the filename's `88ACEs` is not sufficient to
establish actual dimensions. The default grid is dz=100 m, top=40 km,
dt=6 s and duration=8 h. Horizontal/vertical momentum forcing operators
are disabled by default, but the driver accesses their loaded arrays first.

The supplied composite builder reads `PRECOMPUTED_VERTICAL_MODES_2D.mat`
from a hard-coded Windows directory. It saves `COMPOSITE_ACE_BASIS_2D.mat`
with `PMB`, `PMDv`, `PMD`, `Z`, `L`, `N`, and `x`; its explicit save list
does not contain `D`. Thus the supplied builder is not yet a demonstrated
producer of the driver's exact input contract. Its collection script also
defaults to deleting intermediate mode files after collection. Review this
chain in an isolated copy before generation.

The exact named driver basis and mode prerequisite were not found by filename
scan of the local `ACE_MATLAB`, `ACE_MATLAB_old`, `KHN26-ACE_MATLAB` and
`Processed_soundings` trees. Two candidates exist in
`/scratch/peter50504/ACE_MATLAB_old/basis/`:

| Candidate | Bytes | MAT header creation date |
| --- | ---: | --- |
| `COMPOSITE_ACE_BASIS_2D.mat` | 4441244911 | 2025-04-04 |
| `COMPOSITE_ACE_BASIS_2D-001.mat` | 3223276682 | 2025-03-13 |

These are MATLAB 7.3/HDF5 files. Their variable contents, dimensions, full
hashes and builder provenance have not been inspected in this task; header
dates are metadata, not proof of lineage. Do not rename or substitute either
candidate as the v0.20 basis based on its filename.

The default sounding is GoAmazon `maoarmbeatmM1.c1.20140101.003000.nc`,
profile 314. Copies exist under local `ACE_MATLAB/data/soundings/` and
`ACE_MATLAB_old/soundings/`; content identity and selection remain to be
checked before establishing the S20 reference run. The existing Manus
v0.18 cases remain separate pinned regression evidence.

## Historical Fortran P3 contract

At `88e4af5`, the timestep selects native precipitation for `n_prog=3` and
`p3_wrapper_ace` for `n_prog=11`. The P3 state ordering is:
`MF, theta, qv, qc, nc, qr, nr, qi, ni, qrim, brim`. This changes the
thermodynamic representation from v0.18's theta_e/qt and requires explicit
initialization, transport, damping and diagnostic review. MATLAB S20 still
uses theta_e/qt; shared dynamics comparison needs a recorded state mapping.

The wrapper calls `p3_init` once, then `p3_main` after dynamics each step.
It selects one ice category, predicts cloud-droplet number, disables
three-moment ice and liquid fraction, and hard-codes `./input_data/`.
P3 declares intended lookup versions 6.4-2momI, 6.4-3momI and 6.0.
The three files are present locally and hashed in the inventory, but are
not tracked at the historical Fortran HEAD. The current configuration uses
the 2-moment table; the other tables serve optional configurations.
Document data acquisition and third-party attribution before distribution.

Committed `test.F` enables `n_prog=11` and converts initialized theta_e to
theta. Its active initialization inversion occurs before that conversion;
the output-loop inversion calls are commented out and temperature is
computed from theta. Its final output block does not refresh `q` from the
current state, which needs diagnostic review. The locally modified driver instead
selects `n_prog=3`. The committed makefile builds `microphy_p3.F` with Intel
real64 defaults. Local modifications must not silently become release source.

## Previously preserved probe evidence

`migration_work/p3_inventory/` contains a source inventory, compile summaries,
probe sources and logs. Current hashes match that inventory for all seven
listed source/build/data files. These observations were read, not rerun:

- P3 and ACE module compilation succeeded under the recorded GNU real32
  and real64 flags.
- Dry and warm wrapper probes terminated with SIGFPE in both precisions;
  ice probes returned successfully. These are short wrapper probes, not
  full-model tests.
- The real64 dry backtrace points to `microphy_p3.F:2346`, whose conditional
  includes `qiliq/qitot`. Fortran does not guarantee short-circuit evaluation
  of `.and.`; zero ice is a plausible trigger. A focused reproduction is
  needed before selecting a fix.
- With traps disabled, preserved dry output is finite but reports the IEEE
  invalid flag. Finite output alone does not resolve the exception.
- A reference probe illustrates that applying theta_e inversion to a theta
  value yields a different temperature. It motivates diagnostic review;
  it is not a full runtime trace locating all affected production calls.

## Proposed small migration steps

1. Inspect candidate basis metadata and recover the exact driver/builder
   contract, including `D` and operator dimensions. Pin sounding identity.
2. Preserve the historical Fortran v0.20 sources/ancestry and external table
   provenance separately from active-source promotion. Review the two local
   modifications rather than copying the working tree wholesale.
3. In an isolated copy, reproduce the P3 zero-ice exception and review the
   state/diagnostic mapping. Propose focused corrections with scientific
   impact and regression evidence for developer review.
4. Establish an unchanged MATLAB S20 reference with verified inputs before
   adapting paths or replacing active MATLAB source. Validate shared dynamics
   separately from Fortran-only P3 coupling.

Active-source replacement, public-interface changes and scientific corrections
require the review described by `AGENTS.md`. This inventory authorizes none
of those changes automatically. v0.18 is complete; these findings belong to
the v0.20 preparation work.

## Developer steering: code first

The developer requested code confirmation before inspecting basis candidates.
Candidate data inspection and basis generation are deferred. The
[code review and exact requested input](v020_code_review.md) record the next
findings. A supplied final composite basis is sufficient for the first
reference-run preparation; the vertical-mode prerequisite is needed only
if rebuilding the basis becomes necessary.
