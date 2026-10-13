# v0.20 source merge proposal

Prepared 2026-10-04 after the developer requested code organization and merge
before basis confirmation and testing. Active source replacement is a large
change with public-interface and scientific effects under `AGENTS.md`.
This proposal makes those effects reviewable before promotion.

## Concrete review candidate

The isolated candidate is under
`migration_work/v020_source_review/candidate/`, with separate `matlab.patch`
and `fortran.patch` files in the parent directory. The
[55-file manifest](v020_source_merge_manifest.json) records source commits,
paths and SHA-256 values. There are 23 replacements and 32 additions; no
existing source file is deleted. Candidate source bytes match the selected
historical blobs without numerical corrections or formatting changes.

| Destination | Selected source and proposed operation |
| --- | --- |
| `matlab/ace.m` | Packaged S20 `ACE_V020_2D88ACEs.m`, stable active driver name |
| `matlab/util_*/*.m` | Paired S20 code, including basis builders, plume, thermodynamics, WENO and SSPRK93; 51 MATLAB code files including the driver |
| `fortran/src/ace_module.F` | Committed historical Fortran v0.20 `88e4af5` |
| `fortran/src/microphy_p3.F` | P3 5.3.1 from that same commit |
| `fortran/src/test.F`, `fortran/makefile` | Committed versions, excluding the separate repository's local modifications |

The package's MAT sample is excluded from this code-only candidate.
Existing `matlab/read_shared_input.m`, `matlab/util_weno/reconstruction_weno.m`
and `fortran/src/ace_input.F` are retained. No basis, sounding, lookup data,
reference output or release tag is replaced. Original S20 names and bytes
remain recoverable in Git; renamed-driver provenance is explicit in the
manifest.

## Effects requiring explicit review

Promotion changes model formulation to the historical S20/Fortran v0.20
sources. It is not a behavior-preserving cleanup. The
[code review](v020_code_review.md) identifies differences in geometry,
thermodynamic state, physics splitting, mean-flow treatment and defaults.

The source-only candidate also changes driver interfaces: historical MATLAB
expects its MAT basis and sounding layout, while historical Fortran expects
binary initialization, PMB and P3 lookup files. The retained shared-input
helpers are not used by those historical drivers. Existing shared NetCDF
command/environment interfaces would therefore not be available through
the promoted drivers until explicit adapters are implemented. Source READMEs
must describe this development state if promotion is selected; existing
v0.18 test entry points must not be presented as validated S20 runners.

The P3 zero-ice exception and other code-review findings are preserved in
this candidate. Fixing them is separate scientific/interface work. No
compilation or runtime tests have been performed for the candidate, in
accordance with the requested sequence.

## Proposed execution after scope confirmation

1. Select the merge destination: the v0.20 development branch (recommended)
   or `main`, as requested by the developer. An untested source merge does
   not move the published `v0.18.0` tag or create `v0.20.0`.
2. Promote the reviewed source candidate and update build/run documentation
   to identify the historical input contracts and deferred validation.
3. Commit source promotion separately from subsequent input adapters and
   scientific corrections. Preserve Fortran historical ancestry or document
   the pinned source import explicitly before shared publication.
4. Add input adapters and focused corrections through small reviewed changes;
   confirm basis contents and run tests later when authorized.

At preparation time the active MATLAB/Fortran source trees still match the
released v0.18 state. Only review artifacts and documentation have been
created. Branch destination and acceptance of the source/interface scope
remain pending; this proposal is not evidence that active-source merge has
already occurred.

## Execution authorized

The developer subsequently selected integration on the v0.20 development
branch. The candidate is now promoted there; see the
[integration record](v020_source_integration.md). The published main/tag
remain unchanged, and tests and basis inspection remain deferred.
