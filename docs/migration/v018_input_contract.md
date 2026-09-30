# v0.18 input provenance and binary contract

## Shared-input recovery and migration update

On 2026-09-30 the original Manus 208 and additional GOAmazon 314 binaries
were supplied from the external `ACE_FORTRAN/input_data/` directory.
All twelve records match the active MATLAB preprocessing exactly; supplied
PMB matches every preserved basis value and the previously derived hash.
The active readers now have a shared NetCDF route; historical contracts below
remain preserved evidence. See [schema and validation](../shared_input.md)
and [machine-readable evidence](../shared_input_validation.json) for actual
input hashes, numerical checks and remaining compiler/runtime limitations.
The original generating compiler/version is still unconfirmed.


Role: canonical v0.18 input and data provenance. Paths under `history/` and
`active/` identify preserved evidence and temporary validation staging. The
[roadmap](matlab_fortran_alignment_plan.md#shared-runtime-data-direction)
defines future shared `ACE/data/` and common netCDF inputs. It does not change
the historical MAT/NetCDF and binary contracts recorded here; runtime data
conversion and interface design are separate reviewed work.

Status: static source and file inspection on 2026-09-28. No model run or
MATLAB-to-Fortran numerical equivalence has been demonstrated. The historical
Fortran `ini_manus_208.dat` and `PMB.dat` were not found in this repository.
The preserved MATLAB MAT and NetCDF files are supplied through Git LFS;
their contents and SHA-256 values are unchanged by the
[storage migration](matlab_data_lfs_migration.md).

## Preserved source data

| Input | Preserved source | SHA-256 | Observed content |
| --- | --- | --- | --- |
| MATLAB eight-ACE basis | `matlab/history/original_git/data/basis/COMPOSITE_ACE_BASIS_8ACEs.mat` | `6053e923f12da0eb87cc0d65ea776e5fa9ba9bf6fe4dc4399fd1b4b9b645cf45` | MATLAB v7.3 HDF5 file; `DCASES=[5,10,15,25,35,45,55]` km, `Lx=Ly=64` km; `/PMB` is little-endian double with on-disk shape `(8,8,200,201)`. |
| Manus sounding | `matlab/history/snapshots/ACE_V019.3/data/soundings/manus_3hr_ARMBEsonde_profiles.nc` | `b909a2a61b040c5efe5b2f22375bd04c1a93ab4018e427be797a9adc05e23032` | NetCDF with 37 pressure levels and 43,832 times; includes `pressure`, `pr`, `ta`, and `hus`. |

Applying the MATLAB driver's complete-temperature, complete-humidity, and
finite-precipitation filter to this NetCDF yields 5,211 profiles. Its profile
208 is raw time index 7,616 in one-based indexing. The Fortran source's
commented preprocessing uses the same validity filter and `nprof=208`, but
its later interpolation and hydrostatic calculations are not identical to
the MATLAB routines; the missing binary cannot be assumed to equal either
reconstruction.

The basis geometry values agree with the seven radial boundaries and 64 km
outer square specified in `fortran/active/src/test.F`. This is a source-level
geometry check, not proof that the historical Fortran PMB binary used this
particular basis file.

## Fortran reads

`test.F` skips its netCDF preprocessing with `goto 838`. It reads direct-access
records 5–12 from `./input_data/ini_manus_208.dat` into `rho_zm`, `zm`,
`theta_e`, `q`, `Tv`, `p`, `rho`, and `z`, in that order. The historical README
describes 12 records total. Source declares 801 double-precision values per
record and opens the file with `recl=nz*2`, using the original `ifort -r8`
makefile. The byte meaning of `recl` must be confirmed on the actual compiler
platform before writing or reading this binary.

`ace_initialization` reads 12,800 PMB records: response column outermost,
then forcing column, then 200 coarse levels, with 201 double-precision edge
values per record. The source stores the result as
`PMB(response,forcing,coarse,edge)` and opens with
`recl=(coarse_nz+1)*2`. The MATLAB driver's PMB declaration is
`PMB(edge,coarse,forcing,response)`; the HDF5 on-disk dimensions reverse that
order. The relationship is supported by source and file inspection but must
be validated by a compiler-side read and selected numerical comparisons.

## Derived PMB candidate

An **unverified candidate** was extracted outside the repository at
`/tmp/ACE-v018-data/PMB.dat` with `h5dump` 1.14.5:

```sh
h5dump -d /PMB -b LE -o /tmp/ACE-v018-data/PMB.dat -O /dev/null \
  matlab/history/original_git/data/basis/COMPOSITE_ACE_BASIS_8ACEs.mat
```

It contains 20,582,400 bytes (`8*8*200*201*8`) and has SHA-256
`d112f87d5791ab92660d57eda496c466b2d41e9096b31f2e126c3c474c5b6dad`.
The first three binary doubles match HDF5 `/PMB(0,0,0,0:2)`; the value at
HDF5 index `(2,3,10,20)` also matches the calculated binary offset
`6126640`. These spot checks confirm extraction order at those locations only.
The candidate has not been accepted as the historical Fortran input and was
not placed under `fortran/active/input_data/`.

## Remaining decisions

1. Locate the original Fortran binary files if available and compare their
   hashes, lengths, selected records, geometry, and PMB values with the
   preserved MATLAB inputs and the derived candidate.
2. If the original initialization file is unavailable, specify a reviewed
   derivation from the preserved Manus profile 208 and MATLAB initialization
   logic. Check profile indexing, interpolation, units, all 12 records, and
   real kind before using a generated file.
3. Verify compiler direct-access record units, byte order, and array ordering
   with an isolated readback before any model comparison.
