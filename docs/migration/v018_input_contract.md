# v0.18 input provenance and historical binary contract

Updated 2026-10-02. Original Manus 208 initialization and PMB inputs were
recovered on 2026-09-30 from the external `ACE_FORTRAN/input_data/` collection.
All twelve initialization records agree exactly with MATLAB preprocessing;
the supplied PMB agrees with every value of the preserved MATLAB basis.
These input-recovery and ordering checks are complete, not current blockers.

[Shared input](../shared_input.md) owns the implemented NetCDF schema and
current conversion/run instructions. [Readback evidence](../shared_input_validation.json)
records source/runtime hashes, dimensions and validation results. The
[release record](../releases/v0.18.0.md) owns subsequent integration acceptance.
The original input-generating compiler/version remains unconfirmed; the
Intel/GNU dynamics comparison is not established.

## Verified inputs

Historical tree paths below are recoverable at `c9ae729`; they are not
current runtime directories. Data may require materializing LFS objects.

| Input | Source identity | SHA-256 |
| --- | --- | --- |
| Eight-ACE MATLAB basis | `matlab/history/original_git/data/basis/COMPOSITE_ACE_BASIS_8ACEs.mat`, 19,809,507 bytes | `6053e923f12da0eb87cc0d65ea776e5fa9ba9bf6fe4dc4399fd1b4b9b645cf45` |
| Manus source sounding | `matlab/history/snapshots/ACE_V019.3/data/soundings/manus_3hr_ARMBEsonde_profiles.nc`, 40,690,446 bytes | `b909a2a61b040c5efe5b2f22375bd04c1a93ab4018e427be797a9adc05e23032` |
| Recovered Fortran `ini_manus_208.dat` | External original input collection, 76,896 bytes | `dc4a9efc51200005f5a58ad8a92cac212479b13dec70476e240ad240d93749e7` |
| Recovered Fortran `PMB.dat` | External original input collection, 20,582,400 bytes | `d112f87d5791ab92660d57eda496c466b2d41e9096b31f2e126c3c474c5b6dad` |
| Shared Manus case | `data/input/manus208.nc`, 19,757,620 bytes, pinned through Git LFS | `85f8f5ebf0b4a0bca4a96b9b3f6f9b43a1d9bdb4470658b018dcd71d5219b1d9` |

The source NetCDF contains 37 pressure levels and 43,832 times. Complete
`ta`/`hus` profiles with finite `pr` yield 5,211 valid profiles; filtered
profile 208 is raw record 7,616 in one-based indexing. It is 1998-08-09
21:00 UTC, or 1998-08-10 07:00 Manus local time, matching the paper's sounding:
[timestamp and full-profile verification](../manus208_sounding_time_verification.json).

The basis has `DCASES=[5,10,15,25,35,45,55]` km and `Lx=Ly=64` km,
matching the eight-column geometry. `/PMB` in the v7.3 HDF5 file has on-disk
shape `(8,8,200,201)` and little-endian doubles. Full numerical PMB equality
was checked after binary recovery, superseding the original extraction-only
spot checks. Coarse-edge construction has a recorded maximum discrepancy
of `3.637978807091713e-12` m; shared-reader comparisons preserve the reviewed
coordinate contract rather than treating nominal dimensions as proof.

## Historical Fortran binary reads

This section describes `ffdd734`, not the shared-input release driver's
default route. Its `test.F` uses `goto 838` to skip NetCDF preprocessing and
reads direct-access records 5–12 into `rho_zm`, `zm`, `theta_e`, `q`, `Tv`,
`p`, `rho`, `z`, respectively. There are twelve records in the original input,
801 binary64 values per record. The source opens with `recl=nz*2` under
`ifort -r8`; Intel's record-length convention must not be silently applied
to a byte-unit GNU direct-access open.

`ace_initialization` reads 12,800 PMB records, with response column
outermost, then forcing column, then 200 coarse levels. Each record contains
201 binary64 edge values. Fortran stores
`PMB(response,forcing,coarse,edge)` and opens with `recl=(coarse_nz+1)*2`.
MATLAB declares `PMB(edge,coarse,forcing,response)`; HDF5 reverses that order
on disk. Converter/readback tests verify this mapping and reject a wrong
NetCDF PMB order. Legacy reading remains separately selectable as documented
in the shared-input instructions.

## Recovery and validation history

The initial 2026-09-28 inspection extracted `/PMB` with `h5dump` 1.14.5
into `/tmp/ACE-v018-data/PMB.dat`. It produced 20,582,400 bytes with the same
hash later found in the original Fortran binary. The first three doubles
and HDF5 index `(2,3,10,20)` at byte offset `6126640` matched, but that initial
inspection only established extraction order at selected points.
The complete old inspection is preserved at
`v0.18.0:docs/migration/v018_input_contract.md`.

Later validation compared all 9,612 profile values and all 2,572,800 PMB
values, then tested both readers with the shared schema. The readback report
also covers the externally supplied GOAmazon 314 case; its source/input
identities remain in that report and are not substituted for the pinned Manus
reference. Original source generation details, Intel compiler behavior and
later-version basis provenance remain separate questions.

Source-root normalization changed only driver default shared-input paths
from `../../data/input/manus208.nc` to `../data/input/manus208.nc`.
[Normalization verification](../releases/v018_normalization_default_input.json)
shows default and explicit input selection give exactly equal initialization
within each implementation. Historical data identities are retained in the
[LFS manifest](matlab_data_lfs_manifest.tsv), with old IDs translated by the
[commit map](matlab_data_lfs_commit_map.csv).
