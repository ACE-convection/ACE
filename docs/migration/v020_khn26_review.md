# v0.20 KHN26 reference review

Reviewed 2026-10-04 at `c7d9183` on `migration/v020-preparation`.
This preserves the pre-promotion source/contract review. Statements about
"current" code below refer to that baseline. The subsequent authorized source
promotion, adapters and numerical evidence are in the
[KHN26 integration record](v020_khn26_integration.md).

## Reference decision and provenance

The developer reports author confirmation: an earlier v0.20 existed in
June 2025; KHN26 is the November 2025 version and is the intended v0.20
publication reference. This supersedes selection of packaged S20 as the
final release reference. The dates are author testimony relayed by the
developer, not Git or file-metadata conclusions. Mapping every older
snapshot to the June version remains unconfirmed.

The inspected reference is
`/scratch/peter50504/KHN26-ACE_MATLAB/ACE_V020_2D88ACEs_NoGlobal.m`
and its accompanying utility directories. Current `matlab/ace.m` still
contains the earlier packaged S20 plus shared-input adaptations; current
Fortran descends from historical P3 v0.20 plus the recorded alignment edits.
Neither current driver is yet an accepted KHN26 reference implementation.
Historical source, v0.18.0 and existing test evidence remain preserved.

The [inventory](v020_khn26_source_inventory.json) pins every KHN26 `.m`
file with SHA-256, current counterparts and comparisons to preserved S20.
There are 51 `.m` files: 39 exactly identical to current counterparts,
six different and six without a counterpart at the same current path.
Four missing paths are `util_basis/bak/` evidence; the other two builders
match the preserved S20 `uneven_tests/` files. Missing paths are not missing
runtime dependencies. The selected basis and sounding were subsequently inspected after the
developer confirmed the case; input-only conversion/readback is recorded below. Full comparison patches are retained in ignored
`migration_work/khn26_review/`. An exact 51-file source candidate is
preserved under its `candidate/matlab/` directory with a candidate manifest;
no active source has been replaced.

## MATLAB review

| Component | Confirmed comparison and impact |
| --- | --- |
| Main initialization | KHN26 reads processed `acelevels_*.nc` directly, reconstructs environmental T/q/condensate from theta_e/qt, then replaces reference Tv with `eval_Tv(Ta,Qa,QLa+QIa)`. Current shared S20 instead uses supplied Tv_zc and T_env. Bubble uses inverted Ta in KHN26. Scientific difference. |
| Time integration | KHN26 computes buoyancy before SSPRK93, zeros dTH/dQt during all nine stages, removes mean MF in SSPRK93, recomputes thermodynamics/precipitation after dynamics, applies explicit precipitation, then damping and optional MF diffusion. Current S20 includes start-of-step precipitation during SSPRK and accumulates its diagnostics. KHN26 no longer advances those diagnostic slots through that stage forcing. Scientific difference. |
| Buoyancy mean removal | KHN26 performs area-weighted removal inside NONLOCAL_RESPONSE. Earlier S20 performs it in timeint. For fixed start-of-step buoyancy, this is structurally consistent; numerical equivalence still needs checking. |
| SSPRK93 and WENO | Accompanying time integrator, vector WENO and UP3 files are byte-identical to current S20. Default k=2. MATLAB also supports k=3..6, whereas current Fortran vector routine supports k=2/3 only. |
| Dynamics and diffusion | expFun changes the NONLOCAL_RESPONSE call to pass Ai/zero_ref_buoyancy. FH, F, dz2FH, DHh formulas and both MF diffusion functions otherwise remain as in S20. MATLAB mean-MF removal and qt clipping are unchanged. |
| Active thermodynamics | theta_e forward/inversion, saturation functions, density temperature, constants, derivatives, heat-capacity and latent-heat helpers are byte-identical. Their identity is not cross-language validation. |
| theta_il utilities | eval_theta_il changes CPL from 1005.7+864.3*qt to 1005.7+3184.3*qt. inv_T_from_theta_il removes the optional tolerance argument and uses 2834.e6 in ice expressions instead of 2.834e6 (factor 1000), plus a changed mixed-phase denominator. These routines are not called by the default theta_e driver. Preserve as historical scientific findings; do not silently correct or port them. |
| Plume utilities | cin_cape_calc identical. entrain_plume_calc restores global qc_cap/eps_tur instead of a local 4e-3 cap. It is not called by the default KHN26 driver. Importing it changes the standalone utility contract. |
| Basis generation | Vertical-mode defaults change Lx=880 km/Nx=880 to Lx=1000 km/Nx=1600 (625 m). Collection selects the named 4UNEVEN file. The two composite/uneven builders are identical to earlier preserved experimental files. Backup source is retained separately. |
| Output/postprocessing | Main output changes MAT to NetCDF. POST_PROCESS formulas remain unchanged. The two accumulated precipitation slots are not updated by the post-dynamics precipitation operation; their interpretation cannot be carried over from S20 without review. |

### Actual default case and input contract

The developer confirmed these source defaults as the selected publication case:

- `COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN.mat`, not `_V020.mat`.
- `arm=1` selects `acelevels_manaus.nc`; the effective profile index is
  **1342**, overriding the earlier assignment of 314. The old arm comment
  and GoAmazon/profile314 output filename do not describe this selection.
- 401 MF and tracer levels, dz=100 m, top=40 km; 200 m basis grouping,
  dt=6 s, six hours, output every 60 s.
- No MF pulse; saturated +0.25 K bubble in ACE 1, levels 11..51;
  native precipitation active; diffusion off; DHv/DHh off;
  reference-buoyancy mean and MF mean removal on.
- Ai=D in km^2 and Bi=1 km: a one-km slab span. Actual entity count
  follows D, not the `88ACEs` or `UNEVEN41ACEs` filenames.
  The builder's Lx=1000 km, DX=5 km defaults imply 101 columns for
  4UNEVEN, while its active coarsening block also saves a 61-column
  derivative. The 41-column block is commented out. The selected MAT was subsequently inspected: PMB disk shape is
  (101,101,200,201), D has 101 widths (2.5 km at both ends, 5 km inside),
  and only PMB/D/Z/L/N are present. The developer confirmed this basis
  and Manaus profile 1342; the filename saying 41 is not the actual grid.

The composite builder saves **PMB/Z/L/N/D only** and clears ADV/ADX;
it does not produce PMDv/PMD. The default driver assigns missing momentum
operators to scalar zero before use when their switches are off, so absence
alone does not make the default run fail. Optional truncation or vertical-
nonlocal replacement accesses momentum arrays before those assignments;
those options require separate contract review. Subsequent inspection
confirms the selected MAT has no PMDv/PMD.

Current `create_s20_shared_input.m`, both schema-2 adapters and Fortran slab
initialization require all three full operators. The converter also extracts
raw-sounding preprocessing from `matlab/ace.m`; it does not implement the
KHN26 direct processed-profile path. It must not re-interpolate, re-filter
or humidity-adjust the processed KHN26 profile and claim identity. Decide a
reviewed representation for disabled/missing momentum operators, preserving
that they were not supplied rather than claiming a generated scientific basis.

## Current Fortran versus KHN26

| Area | Current Fortran status / required work |
| --- | --- |
| Input profiles and geometry | Dynamic slab dimensions and explicit basis-axis mapping already implemented; synthetic reader checks passed. KHN26 processed-profile adapter and actual basis readback remain required. Unequal widths must be used in weighted means and flux tests. |
| Reference buoyancy | Fortran uses file Tv_zc. KHN26 recomputes reference Tv from theta_e/qt inversion before the bubble. Prior fixed-file-Tv alignment is not final KHN26 alignment. Record both input and reconstructed reference values; agree on construction/state mapping before changing code. |
| Shared momentum/tracer equations | Slab outer self-boundaries, area-weighted reference-buoyancy removal, mean-MF removal, coarse block means, PMB contraction and makima/direct-grid branches are implemented. Their formula-level correspondence survives the reference change; no full tendency or trajectory agreement has been demonstrated. |
| Momentum units | Existing SI conversion multiplies MATLAB Ai by 1e6 and Bi by 1e3. Tracer and FH ratios cancel that scale, but DHh=ioflow^2/(rho*A) scales by 1e6. Unconverted PMD coefficients therefore cannot simply be activated as equivalent. Momentum terms remain off; review normalization/units before enabled-operator tests. |
| SSPRK and qt bound | Same nine-stage coefficients; cached start-of-step buoyancy matches KHN26's stage policy. MATLAB clips qt after SSPRK, before physics. Fortran has no corresponding qt clipping in its n_prog=3 branch; P3 species are a separate contract. |
| Native precipitation | n_prog=3 uses cached start-of-step Ta/q/ql/qi, a max(x,0) approximation rather than MATLAB log(1+exp(x)), and computes ql/qc and qi/qc before checking qc<=0. Needs post-dynamics refresh and reviewed numerically stable evaluation. The accepted v0.18 precipitation correction was not preserved by historical P3 source promotion. |
| P3 versus shared reference | Production driver fixes n_prog=11 (MF/theta/qv/qc/nc/qr/nr/qi/ni/qrim/brim); MATLAB evolves theta_e/qt plus two diagnostic slots. Establish a separate matched native/dynamics case; do not identify qv with qt or force P3 into MATLAB. |
| Initialization | Fortran stores inverted theta/qv but drops initial ql/qi and leaves condensate/number/riming zero. Its MF pulse is 0.3 below 1 km, dt=2 s, default duration 100 days. These differ from KHN26; total-water consistency and matched bubble mapping need explicit checks. |
| Thermodynamics | Same broad theta_e formulas and 1e-3 K inversion stopping scale, but source differences remain: condensate-free cold Newton derivative uses +300708 in Fortran versus -300708 in MATLAB; real-only versus complex fallback; initial temperature estimates and derivative evaluation differ. Existing v0.18 reports are historical evidence, not validation of current imported Fortran. Recheck forward/inverse states before release. |
| Reconstruction/boundaries | k=2 interior and lower UP3 formulas correspond. Fortran weno_vec leaves indices 1 and nz unassigned before the caller multiplies the entire output by MF and then zeroes surface flux. Undefined values can trigger invalid operations even if boundary tendencies are later overwritten. MATLAB returns all entries using circshift. Fortran UP3 zeros the top two entries while MATLAB computes them; top masking limits but does not prove absence of effects through coarse nonlocal forcing. |
| Damping/diffusion | Fixed 6 km/180 s sponge and density-scaled damping structurally correspond for mapped reference fields. MATLAB optional nonlinear MF diffusion is absent from the current Fortran driver. Keep diffusion off for the first matched case; document support limits. |
| Diagnostics/output | Fortran retains nine-field real32 direct-access output and native P3 interpretation. KHN26 writes NetCDF theta_e/qt and derived fields. Matched diagnostics, variable ordering, coordinates, units and precipitation accounting need separate adapters. |
| P3 reliability | Previously recorded dry/warm invalid-operation issue remains unresolved. P3 source is unchanged by recent dynamics alignment; standalone interpolation and successful compilation do not validate P3. |

### Additional source findings

- KHN26 `INV_THETA_E` references `p_mf` in its imaginary-result diagnostic
  branch although this local function receives `p_zc`; `p_mf` is not in
  its local scope. Normal real-valued runs do not exercise this branch.
- NetCDF output writes radius as D/2 with units m although D is used as km
  widths; a radius is also ambiguous for slab columns. MF metadata says
  `kg m^2 s^-1`, inconsistent with the code's kg m^-2 s^-1 convention;
  qi is labelled liquid water. These need reviewed diagnostic corrections.
- The mode collection defaults to deleting intermediate MAT files.
  Do not run it on original data. Preserve source and use isolated output
  paths with deletion disabled if rebuilding is authorized.
- Optional ensemble and restart initialize bubbles on the MF profile
  instead of the default cell-center inversion path. They need separate
  acceptance if included in the publication scope.

## Proposed implementation sequence for review

1. Preserve the exact KHN26 source collection and its provenance in Git
   through a reviewed source import. Use stable active name `matlab/ace.m`;
   keep historical backup/experimental evidence out of the active MATLAB
   path. Import changes and scientific corrections must be separate.
2. Adapt shared input to read KHN26 processed profiles directly, with
   explicit author-selected basis/case, reference-Tv policy and disabled
   momentum-operator representation. Verify array axes, SI conversion,
   profiles, initialization and unequal-width geometry independently.
3. Align a native theta_e/qt Fortran comparison path in small scientific
   changes: reference construction, post-dynamics precipitation, qt bound,
   initialized boundary values and matched bubble/dt. Keep P3 separately
   selectable and preserve its native variables.
4. Validate thermodynamic forward/inverse states and frozen-buoyancy
   tendencies, then one SSPRK step with physics off/on. Reuse the passing
   standalone real64 interp1 evidence when its source hash remains unchanged.
   Run a short matched case before the selected full KHN26 trajectory.
5. Validate P3 initialization/water mapping and dry/warm/ice coupling
   separately, then document publication scope, precision and retained
   limitations before creating v0.20.0.

The developer has selected KHN26 and requested this review. Large source
replacement, input-interface changes and uncertain scientific corrections
still need the concrete proposal confirmation required by AGENTS.md sections
5 and 8. No active numerical sources, tags or commits were changed. The subsequently
authorized processed-case conversion creates new input data without modifying
the original basis or sounding.

## Evidence boundary

All 51 MATLAB source files were fingerprinted and compared. Differing main
sections, utility changes, active call paths and the current Fortran
initialization/dynamics/physics/reconstruction/thermodynamic paths were
inspected. Existing interpolation/readback evidence is reused with its
original scope; no full MATLAB driver execution, model integration or P3 probe was performed.
The subsequently authorized input conversion and reader checks have a separate
evidence scope below. Static correspondence
and source identity are not proof of scientific equivalence.

## Confirmed shared-input preparation

The developer confirmed on 2026-10-04: use the selected 4UNEVEN basis and
processed Manaus profile **1342**, generating one NetCDF for different codes.
Source paths under KHN26/data resolve to the corresponding ACE_MATLAB/data
files. This authorizes input preparation; full source promotion and uncertain
scientific corrections remain separate reviewed operations.

`tools/input/create_khn26_shared_input.py` writes
`data/input/manaus1342_khn26.nc` using existing schema 2. It copies all twelve
shared profile fields, T at centers/edges, original coordinates and PMB
without sounding preprocessing or operator resampling. D is converted km
to m; slab area/perimeter use the historical 1 km span. The supplied Tv
fields are preserved; KHN26 inversion-derived reference construction remains
a driver alignment task. Profile metadata is Manaus/1342, not the historical
GoAmazon314 output filename. Original sounding time/calendar metadata is
preserved as source_* fields without interpreting or correcting it.

Absent PMDv/PMD are full-shape compressed zeros, explicitly tagged
`disabled_zero_placeholder`. These permit current schema-2 reader access
without representing a supplied/generated momentum basis. Momentum terms
must stay disabled. Existing model initializers do not yet enforce this
metadata, so adding an activation guard belongs in the input-adapter change.

The original driver declares nominal p=(1000:-5:100)*100; this unused grid
is included for current MATLAB reader compatibility. That reader also
requires plev units: plev is an explicitly labelled alias of processed
P_zc, not an invented raw sounding or a second preprocessing result. No
raw-sounding intermediates (T_p/q_p/etc.) are invented. The current S20
main still expects them and needs a processed-input branch before it can
initialize from this file. Fortran reader compatibility likewise does not
make its P3/default case match KHN26.

Run from the repository root, using a fresh output path:

```bash
python tools/input/create_khn26_shared_input.py \
  /scratch/peter50504/KHN26-ACE_MATLAB/data/basis/COMPOSITE_ACE_BASIS_2D_KHN26_4UNEVEN.mat \
  /scratch/peter50504/KHN26-ACE_MATLAB/data/soundings/acelevels_manaus.nc \
  data/input/manaus1342_khn26.nc
```

The converter refuses an existing destination. The adjacent provenance JSON
records SHA-256 of source basis, sounding, converter and output. The NC is
a large local runtime artifact covered by the existing ignored *.nc rule;
LFS staging/release distribution remains a developer-controlled Git step.
Input-only readback is checked against the original profiles/PMB and both current readers; final results are recorded below.

### Input-only validation result

GNU Fortran 11.2.0 compiled the current `ace_input.F` with `-fcheck=all`.
Its actual reader outputs were compared by MATLAB R2023b using current
`read_shared_input.m`. All twelve profiles match original profile 1342,
and **all 410,080,200 PMB values** match the original MAT and Fortran reader
exactly. Geometry/coarse/profile readback (5,415 doubles) is exactly equal
between readers. Widths match D*1000 and supplied Z is preserved. Both
readers verify disabled momentum operators are zero. These are actual-data
input checks, not synthetic fixtures or model trajectory acceptance.

The [input report](v020_khn26_input_validation.json) pins source/output/
converter hashes, tool versions, checks and limitations. Probe sources,
Fortran readback and MATLAB log remain in the ignored review directory.
The initial MATLAB sandbox run could not contact its license server; the
approved execution outside the sandbox completed successfully. No P3 or
full model executable was exercised. Active defaults still select the
earlier, ungenerated GoAmazon314 file; source promotion and the new
processed-input branch remain the next reviewed implementation step.
