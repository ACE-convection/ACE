# ACE_V024p87 / ACE_V024GF87

Yi-Hung Kuo (yhkuo@atmos.ucla.edu)
Atmospheric & Oceanic Sciences, UCLA

Two-dimensional periodic array of Anelastic Convective Entities (ACEs), one entity per column, with
immersed-boundary terrain: capacitance closure with windowed precomputed responses (no online global Poisson
solve), vorticity-flux (Lamb) form with WENO upwind reconstruction of the vorticity, SSPRK(9,3) time stepping,
level-mean momentum equation with the diagnosed pressure drag, moist thermodynamics with a batched theta_e
inversion, optional viscosity / wall model / mixing-length SGS.

Self-contained package (about 155 MB). Copy the whole directory and start MATLAB inside it; every path is resolved
relative to `pwd`.

## Contents

| File / directory | What it is |
|---|---|
| `ACE_V024p87.m` | The model: one script plus local functions. The header documents the physics, the presets and the run modes. |
| `ACE_V024GF87.m` | The same model plus two acceleration flags, `GPU` (fp64 state-resident march on a CUDA device) and `FFT` (K1/K2 x-convolution in wavenumber space). Both default 0, which executes the `ACE_V024p87.m` arithmetic verbatim. |
| `data/basis/COMPOSITE_ACE_BASIS_2D_V024_dx=500m_NT=30.mat` | Precomputed basis (K1 and K2 tables in one file), dx = 500 m, +-30 columns (production). |
| `data/basis/COMPOSITE_ACE_BASIS_2D_V024_dx=5km_NT={3,10}.mat` | Basis for dx = 5 km, +-3 and +-10 columns. |
| `data/soundings/maoarmbeatmM1.c1.20140101.003000.nc` | GOAmazon ARMBE sounding (103 MB). Loaded by every run mode (it builds the base state; the mountain-wave cases then replace it by the idealized sounding); also the `SND = 'arm'` case preset. |
| `util_basis/V024p87_CONSTRUCT_KERNELS.m`, `util_basis/util_layergreen.m` | Offline construction of the kernel tables (see "Building kernel tables"). |
| `util_weno/`, `util_timeint/`, `util_thermodynamics/`, `util_plume/` | Libraries: WENO reconstruction, thermodynamic constants and functions, the batched theta_e inversion (`inv_T_batch_warm.m`, `inv_T_batch.m`), and its GPU-safe scalar copy (`inv_T_from_theta_e_gpu.m`). |

## Environment

MATLAB R2024b or later (uses `ncread` and `-v7.3` saves). `ACE_V024p87.m` needs no toolbox; `ACE_V024GF87.m` with
`GPU=1` needs the Parallel Computing Toolbox and a CUDA device with fp64 support. `maxNumCompThreads(4)` is set
inside the scripts; change it on a machine with more cores. `FFT=1` adds about 0.9 GB of spectral tables;
`NT=439` with `FFT=1` needs about 8 GB of RAM.

## How to run

Presets are plain variables set before the script is called; run from inside this directory.

```matlab
% installation check (about 10 min): must end with ALL T2b GATES PASS
RUN_MODE='mwgates'; ACE_V024p87
% nonlinear mountain wave, H = 1500 m, a = 5 km, U0 = 15 m/s, 4 h
RUN_MODE='mw'; SKIPGATES=1; ACE_V024p87
% linear mountain wave, H = 300 m, 30 min
RUN_MODE='mw'; SKIPGATES=1; MW_H=300; MW_T=0.5; ACE_V024p87
% the same with the terrain-following surface point
RUN_MODE='mw'; SKIPGATES=1; MW_H=300; MW_T=0.5; IBSLOPE=1; ACE_V024p87
% continuous sine topography, 5 h
RUN_MODE='mwsine'; ACE_V024p87
% extend a finished run (record in OUTPUT/) by 4 h
RUN_MODE='mwextend'; EXTTAG='ACE_V024p87_880_mw_H1500_a5_U15_mu1'; ACE_V024p87
% boundary-layer cases: Rayleigh (no-slip + viscosity) and log law (wall model + mixing-length SGS)
RUN_MODE='rayleigh'; RT=3; VISC=50; ACE_V024p87
RUN_MODE='loglaw'; LL_ZN=1500; ACE_V024p87
% dx = 5 km, H = 1000 m, a = 20 km (Nx = 88; NT = 3 or 10 tables)
NX=88; DX=5000; NT=3; MW_H=1000; MW_A=20e3; RUN_MODE='mw'; SKIPGATES=1; ACE_V024p87
% moist convection over flat ground: GOAmazon sounding, sheared profile, cold block in columns 40:49, 8 h
NX=88; DX=5000; NT=3; MW_H=0; SND='arm'; UBAR='profile'; IC='coldblock'; MW_U0=10; MW_TAU=0; MW_T=8; MW_DTOUT=120; RUN_MODE='mw'; SKIPGATES=1; ACE_V024p87
% acceleration (ACE_V024GF87.m): GPU = device march, FFT = spectral K1/K2 convolution; independent flags
RUN_MODE='mwgates'; GPU=1; FFT=1; ACE_V024GF87
RUN_MODE='mw'; SKIPGATES=1; MW_H=300; MW_T=0.5; GPU=1; FFT=1; ACE_V024GF87
% the untruncated kernel, NT = 439 = Nx/2 - 1 (FFT=1 only; build the table first, see below)
RUN_MODE='mw'; SKIPGATES=1; NT=439; GPU=1; FFT=1; ACE_V024GF87
```

From a shell: `matlab -batch "RUN_MODE='mw'; SKIPGATES=1; ACE_V024p87"`.

Under `GPU=1` the script certifies the device path at setup (`GATE K apply`, `GATE GPU ...` lines); a failing
gate stops the run.

### Presets

| Group | Preset | Default | Notes |
|---|---|---|---|
| grid / basis | `NX`, `DX` (m), `NT`, `KFILE` | 880, 500, 30, (by lookup) | The basis file is selected by (dx, NT) in `data/basis/`; any Nx >= 2 NT + 2 works with a given basis. |
| time | `DT` (s) | 6 | |
| mountain | `MW_H`, `MW_A` (m), `MW_HLIN`, `MW_U0`, `MW_TAU` (0 = impulsive), `MW_T` (h), `MW_DTOUT` (s) | 1500, 5e3, 300, 15, 4a/U0, 4, 600 | `MW_H = 0` gives flat ground (still an immersed boundary). |
| case | `SND` ('ideal' / 'arm'), `UBAR` ('uniform' / 'profile'), `IC` ('rest' / 'coldblock'), `IC_COLS`, `IC_BL`, `IC_DT`, `IC_DQC` | ideal, uniform, rest | |
| dynamics | `MEANU` (0 / 1), `MEANUSPONGE`, `DRY`, `LAMB` (0 = flux form), `UPWIND_UP3`, `CAPMODE` ('taper'; 'exact' = diagnostic only) | 1, 1, 0, 1, 0, taper | `MEANU = 1`: level-mean momentum equation with viscous/SGS term, Reynolds-stress divergence, diagnosed pressure drag and level-mean sponge. |
| boundary layer | `VISC` (m2/s), `VISCWALL`, `IBNOSLIP`, `SGSML`, `LL_Z0` / `LL_ZN` / `LL_TAUN`, `LL_NUDGE` | 0, 1, 0, 0, 0.1 / 3000 / 600, 0 | |
| surface | `IBSLOPE` (0 / 1) | 0 | 1 = the constraint point of every face sits at the terrain height h(x_f) (terrain-following bounding streamline; tag `_sl`); 0 = at the higher neighbouring column top (staircase). Rock cells are the same in both. See `IB_BENCHMARKS.md`. |
| run control | `SKIPGATES`, `RESUME`, `EXTTAG` / `EXTT`, `MWPOST_TAG` / `MWPOST_H`, `RT`, `RN1`, `RNOSLIP`, `LL_T`, `NSINE` / `HSINE` / `MSINE_LO` / `MSINE_HI` | | `SKIPGATES = 1` launches a run without the gate battery; `RESUME = 1` continues from the checkpoint. |
| output | `OUTDIR` | 'OUTPUT' | |
| acceleration (`ACE_V024GF87.m` only) | `GPU` (0 / 1), `FFT` (0 / 1) | 0, 0 | |

## Output

Everything a run writes goes into `OUTDIR` (default `OUTPUT/`, relative to the working directory, created if
absent): the record `<tag>.mat` (-v7.3; fields `mf`, `theta_e`, `qt`, `u_tot`, `eta`, `tspan_save`, `mw`, `info`,
...), the checkpoints `<tag>_ckpt.mat` / `<tag>_ckpt0.mat`, and the progress stamps in `progress_V024p87.log`
(`progress_V024GF87.log`). Tags are built from the presets, e.g. `ACE_V024p87_880_mw_H1500_a5_U15_mu1`; informative
suffixes are appended (`_dt<val>`, `_fx`, `_ns`, `_nu<val>`, `_ml`; `ACE_V024GF87.m` adds `_nt<N>`, `_gpu`, `_fft`).
`RESUME = 1`, `RUN_MODE = 'mwextend'` and `RUN_MODE = 'mwpost'` read from the same directory.

## Building kernel tables

A basis for another (dx, NT) is built offline; the expensive part does not depend on NT, so any truncation width
costs the same. The file name carries dx and NT only; the buffer-row count nbuf is fixed at 1 (the model's value) and is
checked against `params.nbuf` when the basis is loaded:

```matlab
addpath('util_basis'); NX=880; DX=500; NTP=439; NBUF=1; V024p87_CONSTRUCT_KERNELS
```

(`NTP`, not `NT`, is the builder's preset.) One file `COMPOSITE_ACE_BASIS_2D_V024_dx=<dx>_NT=<NT>.mat` (K1 and K2
tables together; `dx=5km` for whole kilometres, `dx=500m` otherwise) is written into `data/basis/` and found
automatically by the model with the matching `DX` / `NT`.
`NT = 439` is the maximum for Nx = 880 (the model asserts `Ni >= 2 NT + 2`); at that width use `FFT=1`, whose cost is
NT-independent.
