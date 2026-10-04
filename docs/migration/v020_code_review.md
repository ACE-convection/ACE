# v0.20 code confirmation and requested basis

Reviewed 2026-10-04. Scope: static inspection of packaged MATLAB S20 at
`c9ae729:matlab/history/snapshots/ACE_V020/` and committed historical Fortran
`88e4af5` in `/scratch/peter50504/ACE_FORTRAN`. No basis candidate contents
were inspected, no simulation was run and no production source was changed.

## Confirmed code structure

| Component | Confirmed contract | Consequence for migration |
| --- | --- | --- |
| MATLAB S20 state | theta_e, qt, MF, accumulated precipitation theta_e change and water removal | Uses its packaged thermodynamics and external SSPRK93; not the Fortran P3 prognostic state |
| MATLAB S20 geometry | `Ni=length(D)`, `Ai=D'`, `Bi=ones(Ni,1)` | Slab/2D geometry; entity count comes from data, not the driver/output filename |
| MATLAB nonlocal response | PMB, PMDv, PMD indexed `(response z, forcing z, forcing ACE, response ACE)`; summed over forcing z and ACE, then interpolated using `Z` | All five input variables below are required by the unmodified default driver |
| Historical Fortran state | `n_prog=3`: MF/theta_e/qt; `n_prog=11`: MF/theta/qv/qc/nc/qr/nr/qi/ni/qrim/brim | P3 is implemented in this later source; shared thermodynamic quantities need explicit conversion |
| Historical Fortran geometry | Eight ACEs with circular/annular areas and outer environment; binary `PMB.dat` | Does not implement the MATLAB S20 2D setup simply by enabling P3 |
| Historical Fortran physics | `p3_wrapper_ace` calls P3 5.3.1, one ice category, two-moment ice, predicted droplet number | Source and matching lookup files exist locally; initialization and recorded zero-ice exception need review |

MATLAB's default settings use `Wbar_eq_zero=1`, area-mean buoyancy removal,
dz=100 m, dt=6 s, a 0.25 K saturated bubble, and GoAmazon profile 314.
The historical Fortran driver uses dz=50 m, dt=2 s, Manus 208, eight ACEs,
and an inner-ACE initial MF pulse of 0.3 kg m-2 s-1. These are different
experiments. They must be matched explicitly before a cross-language
comparison; the source version labels do not establish agreement.

## MATLAB code findings requiring review

- Direct external thermodynamic helpers, WENO functions and `ssprk93`
  are present in the packaged tree. This checks named dependencies;
  it does not certify MATLAB path resolution or every optional branch.
- Precipitation is computed by `microrad` before SSPRK93 and incorporated
  into stage tendencies. This differs from the accepted v0.18 post-dynamics
  precipitation update. Preserve it as a scientific difference for review.
- The S20 precipitation routine retains `log(1+exp(x))` and the 1e-8
  condensate derivative. It does not contain the accepted v0.18 Fortran
  stability correction; do not port that correction into a historical
  reference silently.
- The imaginary-value diagnostic in local `INV_THETA_E` refers to `p_mf`,
  which is not passed to that function. The script's `p_mf` does not become
  a local-function variable automatically; this exceptional branch needs
  correction if used.
- Default setup evaluates `normpdf` (Statistics and Machine Learning
  Toolbox dependency). The default output path is `OUTPUT\...`; the
  historical output-directory contract needs an explicit portable adapter.
- The supplied basis builder saves a different filename and omits `D`.
  This is a driver/builder contract discrepancy, not permission to invent
  widths or rename an unverified basis.

## Historical Fortran code findings requiring review

- P3 is present in committed v0.20 source, rather than only a saturation
  helper. Build order includes `microphy_p3.o`; the committed driver selects
  `n_prog=11` and initializes theta from temperature/Exner after theta_e
  inversion.
- The dry/warm SIGFPE evidence remains an earlier probe observation, not a
  new test. The reported conditional at P3 line 2346 includes a division by
  total ice. Reproduce and review before modifying the third-party routine.
- P3 surface precipitation diagnostics are local wrapper arrays and are
  not returned to the ACE driver. Their exposure needs a reviewed interface
  if release diagnostics will use them.
- The final driver output block refreshes temperature and liquid/ice, but
  leaves vapor `q` from an earlier output iteration. RH and buoyancy there
  can therefore use stale vapor. The main output loop does refresh vapor.
- The binary PMB loader uses the historical `recl` convention, and the
  driver depends on `ini_manus_208.dat` and `PMB.dat`. Migration needs a
  reviewed input adapter; the current shared v0.18 input is not a proven
  replacement for S20's 2D operators.
- Local modifications in the separate repository select native physics
  and change driver/build behavior. Review separately from pinned HEAD;
  they are preserved without alteration.

## Basis file requested from the developer

For the selected packaged MATLAB S20 driver, supply the actual completed
**`COMPOSITE_ACE_BASIS_2D_V020.mat`** used with
`ACE_V020_2D88ACEs.m`, containing:

| Variable | Requirement inferred from code |
| --- | --- |
| `D` | Positive row vector of ACE widths in km, length `Ni`; used in `Ai=D'`, entrainment and entity-count initialization |
| `Z` | Vertical response-coordinate vector in meters, with one value per first operator dimension; used directly by `interp1` |
| `PMB` | Buoyancy/nonlocal operator, `(response z, forcing z, forcing ACE, response ACE)` |
| `PMDv` | Vertical momentum operator, same shape/order as PMB |
| `PMD` | Horizontal momentum operator, same shape/order as PMB |

With the default 40 km top, dz=100 m and `coarse_z=200/dz=2`, forcing has
400 fine levels averaged into 200 coarse layers. The expected operator shape
is **`[201, 200, Ni, Ni]`** and the expected `Z` length is 201. This is
inferred from the driver and accompanying builder's 200 m vertical basis;
the actual supplied grid and provenance still require confirmation. Do not
assume Ni=88 or Ni=101 from filenames. PMDv and PMD are accessed before
their default switches replace them with scalar zero, so their presence is
required by the unmodified driver even when momentum forcing is disabled.

If the historical run used a differently named final basis, provide that
file with its original name and the associated driver revision/configuration.
A filename mismatch can then be documented rather than silently renamed.
If available, include the producing builder revision and grid/width settings.

`PRECOMPUTED_VERTICAL_MODES_2D.mat` is an optional additional request only
for rebuilding the basis. It is not needed to consume a complete final file.
P3 lookup tables are already present locally; they are not the missing
MATLAB 2D basis. The existing v0.18 eight-ACE basis is also a different input.
