# MATLAB historical inventory

Role: historical-only archaeology reference. Inspection dates, paths,
commit IDs, tool availability and unresolved findings below describe the
recorded investigation. Import completion is tracked in the
[import record](matlab_import_plan.md); current architecture and development
order are in the [unified roadmap](matlab_fortran_alignment_plan.md).
Archive/staging paths do not prescribe permanent source directories. Later
v0.18 data inspection is recorded in the [input contract](v018_input_contract.md).

This inventory records the pre-LFS archive and commit IDs. In the current Git
history, MATLAB `data/` blobs are LFS pointers; their full original contents
are verified by the [LFS manifest](matlab_data_lfs_manifest.tsv). Use the
[commit map](matlab_data_lfs_commit_map.csv) for current rewritten IDs.

Inspected 2026-09-23. This is repository archaeology, before import. Archive paths below are relative to `migration_work/ACE_MATLAB/`. The symlink resolves to the historical `../ACE_MATLAB` working repository; it was treated as read-only. Git objects were read from the unified repository's existing remote refs. No fetch, checkout, source normalization, model execution, import, or commit was performed.

## Evidence and limits

- MATLAB ref: `ace-matlab/main` = `d9d50a8b45824c919ba8932b4cf8e7d9606d4bbc`.
- Fortran ref: `ace-fortran/main` = `b57f0bb` (context only; no assumption of implementation equivalence).
- Unified repository: `migration/matlab-history`, HEAD `1953c17`; initially clean.
- All 116 paths in the MATLAB tip tree are present at archive root and match their Git blobs byte for byte, including binaries. All 100 root utility files match. Root utilities are a preserved Git collection, not a v0.20/v0.24 library.
- Every reachable MATLAB commit tree was enumerated. Main-program and utility differences were inspected separately, including local functions, configuration, and experimental subdirectories. Byte comparison includes CRLF/LF differences; text diffs were decoded in memory only.
- Binary files were inventoried and hashed. MAT files identify as v7.3; the available SciPy reader cannot inspect their arrays and h5py is unavailable. Kernel contents, dimensions, and scientific equivalence have therefore **not** been validated. No numerical regression results are claimed.
- File timestamps and names do not establish ancestry. “Complete” below distinguishes a collected source package from a runnable package with all required data and dependencies.

See [version matrix](matlab_version_matrix.md) and [lineage and scientific findings](matlab_lineage.md).

## Developer-defined migration convention

For historical standalone MATLAB mains without their own utility directories, the assigned baseline is **v0.18-era root utilities by developer-defined migration convention.** This applies to `ace_v019_K24_8aces.m`, `ace_v019_dev_2d88aces.m`, and `ace_v020_dev_2d88aces.m`. The baseline is collection R: the 100 root utility files whose Git identity is recorded in the inventory. Snapshots with their own utilities retain their documented accompanying collections.

The evidence categories are distinct:

- **Git-confirmed historical facts:** the root utility bytes and their introduction in the MATLAB Git history.
- **Source-code inference:** driver-family relationships and compatibility findings derived from source comparisons.
- **Developer-defined migration decision:** assigning R to standalone mains for migration. This resolves the baseline selection; it does not establish which utilities, working directory or MATLAB path were used historically, prove numerical compatibility, or change the inferred source lineage.

## Archive collections

R = archive root excluding the three snapshot directories and `.git`; S19 = `ACE_V019.3`; S20 = `ACE_V020`; S24 = `ACE_V024.87`. Recursive counts include backups, tests, autosaves and binary files.

| Collection | Files | Bytes | Basis | Plume | Thermodynamics | Time integration | WENO | Data |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| R | 119 | 27269772 | 7 | 3 | 69 | 7 | 14 | 12 |
| S19 | 98 | 452620791 | 37 | 7 | 31 | 0 | 17 | 5 |
| S20 | 52 | 165892 | 9 | 2 | 37 | 1 | 2 | 0 |
| S24 | 50 | 517743 | 2 | 2 | 40 | 1 | 2 | 0 |

S19 contains its two Heaviside basis files and three sounding files. Its time integration is implemented locally in the main, so absence of `util_timeint/` is not by itself a missing dependency. S20 and S24 have all five utility directories but **no `data/` directory** in this archive. S24's README describes a ~155 MB self-contained package with three kernel files and a sounding; those data are absent here. The README also mentions `IB_BENCHMARKS.md`, which is absent.

R contains twelve committed basis files, but no root `data/soundings/`. v0.16/v0.18 use `../data/` relative to the working directory, rather than the root's own `data/`. The standalone 2D mains use absolute Windows Dropbox data paths. These are historical path contracts, not paths repaired by this investigation.

## Original Git history: actual trees

Dates are author dates with original offsets. Each commit below has the preceding row as its Git parent; the first is the root. There are no merges in this MATLAB history.

| Commit | Author date | Tracked files | Actual change |
| --- | --- | --- | --- |
| `a29286e6a169fe6a2275606f355e37b0194f5ff6` | 2024-09-08T10:56:04-07:00 | 1 | License only. |
| `8e5cb2d95233344be39c42f8536b6c92f0faab74` | 2024-10-02T14:34:33-07:00 | 98 | Add v0.16 main and 96 utilities. |
| `b924022aef4f48797c12b405c012737cd8a9aa2f` | 2024-10-02T14:37:18-07:00 | 110 | Add twelve binary basis files. |
| `7f3ea6e35df8e11d0aa94122a9e59a1f4dbaf33e` | 2024-10-02T15:03:13-07:00 | 111 | Add README. |
| `fda0904e974e755363b8d30ef8aa842846e0bab6` | 2024-10-14T19:03:18-07:00 | 115 | Add cd2, cd4, up3 and vector WENO utilities; v0.16 retained. |
| `a328496a5f2e43d44a60b90712e2becdc6313918` | 2024-10-14T19:04:25-07:00 | 116 | Add v0.18 main; v0.16 retained. |
| `5cc173a3d2c633cb3c5e10cc54890b19e6250beb` | 2025-01-15T22:43:37-08:00 | 116 | Modify only v0.18 main: joint implicit tracer/MF diffusion. |
| `8c2f60417607578a78f100e15d71b9b4bfce9af1` | 2025-01-28T13:52:47-08:00 | 116 | README only. |
| `0422a2bac08657712f93165f6b863473b5de0fff` | 2025-02-04T16:11:50-08:00 | 116 | README only. |
| `d9d50a8b45824c919ba8932b4cf8e7d9606d4bbc` | 2025-03-28T14:17:08-07:00 | 116 | README only. |

The v0.18 upload is 935 text lines; the January update is 992. Neither commit replaces or renames v0.16. No v0.19, v0.20, or v0.24 main or snapshot directory is tracked in any of these trees. No tracked utility is modified or removed after its addition: the four WENO additions at `fda0904` are the only later utility-tree evolution. README changes are documentation, not model releases.

## Main-program identities

Hashes below are SHA-256 of the unmodified file bytes. The initial Git-only v0.18 state is included separately.

| Collection | Main | Lines | SHA-256 | First tracked / provenance |
| --- | --- | --- | --- | --- |
| R | ace_v016_dev_8aces.m | 939 | `ef2a7bb8a30c5fa356b4e4ae1165b986030af3630d940f6f221f20a094b51537` | 8e5cb2d |
| R | ace_v018_dev_8aces.m | 992 | `3c693f677f2ccb92da5bdfdfc79270d49039339254e54c57975fc1fd1a027a1b` | a328496 |
| R | ace_v019_K24_8aces.m | 1155 | `d338d4b1724720015853e6405d8bb863f3d1b86d906a5bad033190cdbfa98371` | archive only |
| R | ace_v019_dev_2d88aces.m | 787 | `06f67c523580373dc540a4f64952d6e98bd6224158889887e7e903ac3c45fde2` | archive only |
| R | ace_v020_dev_2d88aces.m | 781 | `71b7e2a95c7597adc1f2697ed00537e02edfdcab0d1c80b7f314e93dc176299c` | archive only |
| S19 | ace_v019_K24_8aces.m | 1008 | `760fde0352f2e691c060212057d9c19aceb60fa2c75e66897963f4062d8cfd18` | archive only |
| S20 | ACE_V020_2D88ACEs.m | 797 | `3a5b33e48b2a085aa1fa5524a923167cd97b3acb60a2f01b11935c058f87397a` | archive only |
| S24 | ACE_V024GF87.m | 2921 | `60bdfb26deb2eac1bc766003f367cabe504b7a6baedbaa1bca80ba45e87206f7` | archive only |
| S24 | ACE_V024p87.m | 2535 | `2cee66602ee92842e265fedd5f7b9989c52ef0c7db42042d03005c1c6e238252` | archive only |
| Git a328496 | ace_v018_dev_8aces.m | 935 | `80e617a2fd896576a0d46a5718ee82bff5dd8de90cfc931a93dbb29e58e54dc2` | a328496; superseded in-place at 5cc173a |

## File presence and utility evolution ledger

This ledger enumerates every non-main archive file, including data, tests and backups. Each cell is a 12-character SHA-256 prefix; `—` means absent. Equal cells were checked using full file bytes, not merely hash prefixes. `First Git` applies to R only. Together with the commit table, it specifies all files in each historical Git tree: include paths whose first commit has occurred, plus the mains above. Only README and v0.18 subsequently change.

For any comparison A → B: absent → hash = added to the compared collection; hash → absent = absent from the compared collection; different hashes = changed; equal hashes = byte-identical. **Snapshot absences do not prove historical deletion.** Directory labels establish comparison direction only, not parentage. No Git-confirmed rename exists. Candidate renames are discussed in the lineage report.

### util_basis

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `util_basis/4jupyter/PRECOMPUTE_VERTICAL_MODES.m` | — | 02276754b336 | — | — | — |
| `util_basis/4jupyter/PRECOMPUTE_VERTICAL_MODES_PF.m` | — | d600dc714f21 | — | — | — |
| `util_basis/4jupyter/WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` | — | 0b0021c6e402 | — | — | — |
| `util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES.m` | 607831e7e5f9 | c88d70d04432 | — | — | 8e5cb2d |
| `util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES_2D.m` | — | — | caca37f99f09 | — | — |
| `util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES_DH.m` | — | c69cc5a1e976 | — | — | — |
| `util_basis/COLLECT_PRECOMPUTE_VERTICAL_MODES_hires.m` | — | ad6a82501d4b | — | — | — |
| `util_basis/DH_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` | — | c79ad1e7b100 | — | — | — |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS.m` | a4554508ebb7 | 4c18ebfd1d60 | — | — | 8e5cb2d |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS_2D.m` | — | 39bec67cc646 | 338aad46c71a | — | — |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS_ADZtemp.m` | — | 352e3bd0755b | — | — | — |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS_DHtemp.asv` | — | 3ee4cb45e31f | — | — | — |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS_DHtemp.m` | — | 18dcd5e9ad07 | — | — | — |
| `util_basis/PRECOMPUTE_COMPOSITE_ACE_BASIS_hires.m` | — | 0f28e70b53b7 | — | — | — |
| `util_basis/PRECOMPUTE_MASSFLUX_BASIS.m` | d0dbd2c4055c | d0dbd2c4055c | — | — | 8e5cb2d |
| `util_basis/PRECOMPUTE_MASSFLUX_BASIS_SQ.m` | e56660292371 | e56660292371 | — | — | 8e5cb2d |
| `util_basis/PRECOMPUTE_MASSFLUX_BASIS_bak.m` | — | 0f3e6cd25075 | — | — | — |
| `util_basis/PRECOMPUTE_VERTICAL_MODES-bak.m` | — | 7cd5b90c320b | — | — | — |
| `util_basis/PRECOMPUTE_VERTICAL_MODES.m` | 0d3437a76dd8 | cb0019e67578 | — | — | 8e5cb2d |
| `util_basis/PRECOMPUTE_VERTICAL_MODES_2D.m` | — | dc5577edae43 | 1de958b52e5e | — | — |
| `util_basis/PRECOMPUTE_VERTICAL_MODES_DHtemp.m` | — | d3b795d473a2 | — | — | — |
| `util_basis/PRECOMPUTE_VERTICAL_MODES_PF.m` | 4cb320220c80 | 4cb320220c80 | — | — | 8e5cb2d |
| `util_basis/PRECOMPUTE_VERTICAL_MODES_diff_res.m` | — | 096b2d10a4e4 | — | — | — |
| `util_basis/PRECOMPUTE_VERTICAL_MODES_hires.m` | — | 11a571aab6f1 | — | — | — |
| `util_basis/V024p87_CONSTRUCT_KERNELS.m` | — | — | — | bd979aa949cd | — |
| `util_basis/VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL-bak.m` | — | 1593a2ff1a7a | — | — | — |
| `util_basis/VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` | — | cf6add6b78fb | — | — | — |
| `util_basis/WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL-bak.m` | — | 030a9fb38fdd | — | — | — |
| `util_basis/WKB_VERTICAL_SOLUTIONS_RECONSTRUCT_UTIL.m` | 0b0021c6e402 | 0b0021c6e402 | — | — | 8e5cb2d |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_01.mat` | — | 7e334cd2d501 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_02.mat` | — | 2ba325224630 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_03.mat` | — | 6d00c84f511c | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_04.mat` | — | 572993011d75 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_05.mat` | — | 40dd45f272e3 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_06.mat` | — | 20cd1e37cf0f | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_07.mat` | — | 345de41e7787 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_08.mat` | — | 4082dcab6717 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_09.mat` | — | 239217cfa828 | — | — | — |
| `util_basis/hires-temp/COMPOSITE_ACE_BASIS_hires_10.mat` | — | e675754919c6 | — | — | — |
| `util_basis/uneven_tests/COLLECT_PRECOMPUTE_VERTICAL_MODES_2D.m` | — | — | 40af7d61aa58 | — | — |
| `util_basis/uneven_tests/PRECOMPUTE_COMPOSITE_ACE_BASIS_2D_4uneven.m` | — | — | acd47fb0839b | — | — |
| `util_basis/uneven_tests/PRECOMPUTE_COMPOSITE_ACE_BASIS_2D_truncate.m` | — | — | 4c98737aa095 | — | — |
| `util_basis/uneven_tests/PRECOMPUTE_VERTICAL_MODES_2D.m` | — | — | a48f64b41c2c | — | — |
| `util_basis/uneven_tests/vertical_solutions_reconstruct_util.m` | — | — | 48e242ae4d6b | — | — |
| `util_basis/util_layergreen.m` | — | — | — | 803340c71ac3 | — |
| `util_basis/vertical_solutions_reconstruct_util.m` | — | — | 48e242ae4d6b | — | — |

### util_plume

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `util_plume/cin_cape_calc.m` | d3dd0639db6b | d3dd0639db6b | d3dd0639db6b | d3dd0639db6b | 8e5cb2d |
| `util_plume/entrain_plume_calc-bak.m` | — | 9eb6efe5e145 | — | — | — |
| `util_plume/entrain_plume_calc.m` | 0a066663dcd5 | ab7a4297ca87 | ea1fe088e0a9 | ea1fe088e0a9 | 8e5cb2d |
| `util_plume/entrain_plume_calc_steady.m` | — | 228cd6ad5dd5 | — | — | — |
| `util_plume/trad_plume-bak.m` | — | cdc544ced17f | — | — | — |
| `util_plume/trad_plume.m` | ad8d87e97f3b | ad8d87e97f3b | — | — | 8e5cb2d |
| `util_plume/trad_plume_BnoVirtual.m` | — | 6264177e40fe | — | — | — |

### util_thermodynamics

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `util_thermodynamics/GPUTEST_SAMPLE.mat` | — | — | 81b5712c6f20 | 81b5712c6f20 | — |
| `util_thermodynamics/IMPORT_CONSTANTS.m` | 9fde477680e8 | 9fde477680e8 | 9fde477680e8 | 9fde477680e8 | 8e5cb2d |
| `util_thermodynamics/IMPORT_CONSTANTS_NOGLOBAL.m` | — | — | 68056228f141 | 68056228f141 | — |
| `util_thermodynamics/NOTE.m` | d8b2a2c3dab6 | d8b2a2c3dab6 | d8b2a2c3dab6 | d8b2a2c3dab6 | 8e5cb2d |
| `util_thermodynamics/bak/IMPORT_CONSTANTS.m` | 9fde477680e8 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/ci.m` | dba544e76ce1 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_B.m` | f7c5a5854299 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_Tv.m` | 8ff84ebd96ff | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_dTes.m` | dccd232253f4 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_dTqs.m` | 58dc2591626c | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_dTqsi.m` | 30e84f58aa1c | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_dTqsscl.m` | 4538b2896b48 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_es.m` | a6d89db08505 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_esi.m` | 13e7d32f678a | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_esscl.m` | b2347af96367 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_q.m` | 851fe9cc38b1 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_qs.m` | 79e9bdd57cec | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_qsat.m` | a4adf98fe967 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_qsi.m` | 03bb4474d823 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_qsscl.m` | 8ac0d465e0a1 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_rho.m` | 8e6de77fee6f | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta.m` | b88972c43b57 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta_e.m` | 39b2deb6c843 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta_es.m` | b2ed4a5e85fd | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta_il.m` | fd886aac3847 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta_l.m` | 7cfd29458c03 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/eval_theta_v.m` | 07fa7707099b | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/inv_T_from_theta_e.m` | 193430a8ffb4 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/inv_T_from_theta_il.m` | 97a6292b54c6 | — | — | — | 8e5cb2d |
| `util_thermodynamics/bak/lv.m` | 3dc1c0bdacdc | — | — | — | 8e5cb2d |
| `util_thermodynamics/ci.m` | dba544e76ce1 | dba544e76ce1 | dba544e76ce1 | dba544e76ce1 | 8e5cb2d |
| `util_thermodynamics/eval_B.m` | 4260dae12c5e | 4260dae12c5e | 4260dae12c5e | 4260dae12c5e | 8e5cb2d |
| `util_thermodynamics/eval_Tv.m` | 4b0b113e2ff4 | 4b0b113e2ff4 | d86992e3f9ef | d86992e3f9ef | 8e5cb2d |
| `util_thermodynamics/eval_dTes.m` | dccd232253f4 | dccd232253f4 | dccd232253f4 | dccd232253f4 | 8e5cb2d |
| `util_thermodynamics/eval_dTqs.m` | f8fb651a0ee1 | f8fb651a0ee1 | 35e4585653c8 | 35e4585653c8 | 8e5cb2d |
| `util_thermodynamics/eval_dTqsi.m` | 9b91370ac36d | 9b91370ac36d | 5ce3913522b0 | 5ce3913522b0 | 8e5cb2d |
| `util_thermodynamics/eval_dTqsscl.m` | 3855ccb95b4d | ed29306fff3d | 4e025fb26f0d | 4e025fb26f0d | 8e5cb2d |
| `util_thermodynamics/eval_es.m` | a6d89db08505 | a6d89db08505 | a6d89db08505 | a6d89db08505 | 8e5cb2d |
| `util_thermodynamics/eval_esi.m` | 13e7d32f678a | 13e7d32f678a | 13e7d32f678a | 13e7d32f678a | 8e5cb2d |
| `util_thermodynamics/eval_esscl.m` | b2347af96367 | 9410bdcb5632 | 7fa1acdff354 | 7fa1acdff354 | 8e5cb2d |
| `util_thermodynamics/eval_h.m` | b9ce02ddd168 | 0841319866e2 | 6a6bc3c99904 | 6a6bc3c99904 | 8e5cb2d |
| `util_thermodynamics/eval_q.m` | 2cf06b7958e5 | 2cf06b7958e5 | 19fc7e2235e5 | 19fc7e2235e5 | 8e5cb2d |
| `util_thermodynamics/eval_q2.m` | — | — | f0986c79fc1b | f0986c79fc1b | — |
| `util_thermodynamics/eval_qs.m` | 79e9bdd57cec | 79e9bdd57cec | 09f7e3c707ed | 09f7e3c707ed | 8e5cb2d |
| `util_thermodynamics/eval_qs2.m` | — | — | 6c1f03213c04 | 6c1f03213c04 | — |
| `util_thermodynamics/eval_qsat.m` | a4adf98fe967 | 21b76eef222d | 1aff97bbd0e4 | 1aff97bbd0e4 | 8e5cb2d |
| `util_thermodynamics/eval_qsat2.m` | — | — | 16a75d060676 | 16a75d060676 | — |
| `util_thermodynamics/eval_qsi.m` | 03bb4474d823 | 03bb4474d823 | 5a92de14d0b0 | 5a92de14d0b0 | 8e5cb2d |
| `util_thermodynamics/eval_qsi2.m` | — | — | 3c7b3674ea2e | 3c7b3674ea2e | — |
| `util_thermodynamics/eval_qsscl.m` | f86c795dfdcd | f86c795dfdcd | 1b47aa01ca8e | 1b47aa01ca8e | 8e5cb2d |
| `util_thermodynamics/eval_rho.m` | b22b7816d519 | b22b7816d519 | b22b7816d519 | b22b7816d519 | 8e5cb2d |
| `util_thermodynamics/eval_theta.m` | c69e40c66320 | c69e40c66320 | c69e40c66320 | c69e40c66320 | 8e5cb2d |
| `util_thermodynamics/eval_theta_e.m` | 631d04f3cac8 | 631d04f3cac8 | 631d04f3cac8 | 631d04f3cac8 | 8e5cb2d |
| `util_thermodynamics/eval_theta_e_check.m` | — | 03c3f2a1cff5 | — | — | — |
| `util_thermodynamics/eval_theta_es.m` | 2e1ad11546d8 | 2e1ad11546d8 | 39ff2e6d87d2 | 39ff2e6d87d2 | 8e5cb2d |
| `util_thermodynamics/eval_theta_il.m` | 785fc6f23c6a | 785fc6f23c6a | 359b4d622450 | 359b4d622450 | 8e5cb2d |
| `util_thermodynamics/eval_theta_l.m` | 6628625f218e | 6628625f218e | 6628625f218e | 6628625f218e | 8e5cb2d |
| `util_thermodynamics/eval_theta_v.m` | f531d0ca252a | f531d0ca252a | f531d0ca252a | f531d0ca252a | 8e5cb2d |
| `util_thermodynamics/gputest_invTq.m` | — | — | c2918e5cb0aa | c2918e5cb0aa | — |
| `util_thermodynamics/inv_T_batch.m` | — | — | — | 563462a1adb1 | — |
| `util_thermodynamics/inv_T_batch_warm.m` | — | — | — | 61c8c2ca1482 | — |
| `util_thermodynamics/inv_T_from_h.m` | c65be1712576 | 58b9c14e51d8 | 73621892b81e | 73621892b81e | 8e5cb2d |
| `util_thermodynamics/inv_T_from_theta_e.m` | 22d548b7a495 | 22d548b7a495 | e001fe0db37d | ee8517503a80 | 8e5cb2d |
| `util_thermodynamics/inv_T_from_theta_e_gpu.m` | — | — | — | e80e35965b0c | — |
| `util_thermodynamics/inv_T_from_theta_e_nogpu.m` | — | — | 0b57c816e4de | 0b57c816e4de | — |
| `util_thermodynamics/inv_T_from_theta_il.m` | 0f7cd1f96d0f | 0f7cd1f96d0f | 1377036c4767 | 1377036c4767 | 8e5cb2d |
| `util_thermodynamics/lv.m` | c389332e5340 | c389332e5340 | c389332e5340 | c389332e5340 | 8e5cb2d |
| `util_thermodynamics/test_inv_T_from_h.m` | e9c134654621 | ba543a1bbf4f | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/inv_T_from_theta_e.m` | dd57339da740 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/inv_T_from_theta_il_new.m` | cdffdcb842e7 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_cases.m` | 0faf8c7f3cea | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_icefree.m` | 472e747e1270 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_iceliquidcoexist.m` | 8286bbc711fd | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_liquidfree.m` | e0c44ee0d0ba | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_new.m` | 6ebbf3164264 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_e_qcfree.m` | 1256a9af6434 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_il_icefree.m` | 5f1a2811e622 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_il_iceliquidcoexist.m` | 829fe92ac5a6 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_il_liquidfree.m` | 5b8fe8cf06e0 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_il_new.m` | 376cea0f1d87 | — | — | — | 8e5cb2d |
| `util_thermodynamics/tests-inv_T_from_theta/test_inv_T_from_theta_il_qcfree.m` | 1898e944513d | — | — | — | 8e5cb2d |

### util_timeint

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `util_timeint/ImDiffMF.m` | 946a5dd8c026 | — | — | — | 8e5cb2d |
| `util_timeint/ebs23.m` | 333e7a16e2a9 | — | — | — | 8e5cb2d |
| `util_timeint/essprk54.m` | 97926e20d514 | — | — | — | 8e5cb2d |
| `util_timeint/rkf45.m` | 0b1628d67709 | — | — | — | 8e5cb2d |
| `util_timeint/ssprk22.m` | 431a3a181737 | — | — | — | 8e5cb2d |
| `util_timeint/ssprk3.m` | 3f1b3c472713 | — | — | — | 8e5cb2d |
| `util_timeint/ssprk33.m` | 2d299fe1384c | — | — | — | 8e5cb2d |
| `util_timeint/ssprk93.m` | — | — | b23650cbd13f | b23650cbd13f | — |

### util_weno

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `util_weno/NOTE.m` | 6e9b2f5f5fc8 | 6e9b2f5f5fc8 | — | — | 8e5cb2d |
| `util_weno/dyn_entrainment_detrainment_calc.m` | 0a01ad81f7ca | 0a01ad81f7ca | — | — | 8e5cb2d |
| `util_weno/reconstruction_alphar.m` | 09c7272658ba | 09c7272658ba | — | — | 8e5cb2d |
| `util_weno/reconstruction_betar.m` | e365695af34b | e365695af34b | — | — | 8e5cb2d |
| `util_weno/reconstruction_cd2.m` | bc89ef76a1af | bc89ef76a1af | — | — | fda0904 |
| `util_weno/reconstruction_cd4.m` | b7a0da564c3a | b7a0da564c3a | — | — | fda0904 |
| `util_weno/reconstruction_cij.m` | 8e79bf8a61de | 8e79bf8a61de | — | — | 8e5cb2d |
| `util_weno/reconstruction_dr.m` | 98c18187a592 | 98c18187a592 | — | — | 8e5cb2d |
| `util_weno/reconstruction_up3.m` | 748ac867a4a5 | 748ac867a4a5 | 748ac867a4a5 | 748ac867a4a5 | fda0904 |
| `util_weno/reconstruction_weno-bak.m` | c37132aa2465 | — | — | — | 8e5cb2d |
| `util_weno/reconstruction_weno.m` | fd5478923021 | e1af336e74c0 | — | — | 8e5cb2d |
| `util_weno/reconstruction_weno_dtypo456.m` | — | c37132aa2465 | — | — | — |
| `util_weno/reconstruction_weno_pbc_ve_dtypo456.m` | — | dd560f7f9fbe | — | — | — |
| `util_weno/reconstruction_weno_vec.m` | f5f5fc42c9a9 | 95c67acab95c | 7db699727a68 | 7db699727a68 | fda0904 |
| `util_weno/reconstruction_weno_vec_dtypo456.m` | — | ffff9cbae4ae | — | — | — |
| `util_weno/reconstruction_weno_vec_k56asym.m` | — | a8e5ec5b2388 | — | — | — |
| `util_weno/reconstruction_wenoz.m` | 9958d49ce6a2 | — | — | — | 8e5cb2d |
| `util_weno/reconstruction_wenoz__dtypo456.m` | — | 9958d49ce6a2 | — | — | — |
| `util_weno/reconstruction_wr.m` | e94f3917cb4d | e94f3917cb4d | — | — | 8e5cb2d |

### data

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `data/basis/COMPOSITE_ACE_BASIS_8ACEs.mat` | 6053e923f12d | — | — | — | b924022 |
| `data/basis/COMPOSITE_ACE_BASIS_Heaviside_4ACEs.mat` | — | 522e07fb3ddd | — | — | — |
| `data/basis/COMPOSITE_ACE_BASIS_Heaviside_7ACEs.mat` | — | 77dd3c8936af | — | — | — |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~10KM.mat` | 3d4bb8122e83 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~15KM.mat` | 5ed7b0d15270 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~3KM.mat` | 987454423cbe | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_ASYMM_d~5KM.mat` | 0367a9f79ef9 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=10KM.mat` | 21f353a0c861 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=15KM.mat` | d41ca69f1612 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=1KM.mat` | 34cd8d1ad2ca | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=20KM.mat` | 6a829ce3c4a0 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=25KM.mat` | a9f9438d9c36 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=3KM.mat` | ace2e92c48d0 | — | — | — | b924022 |
| `data/basis/PRECOMPUTED_MATCHING_STEP_BASIS_d=5KM.mat` | a6a838ecd537 | — | — | — | b924022 |
| `data/soundings/manus_3hr_ARMBEsonde_profiles.nc` | — | b909a2a61b04 | — | — | — |
| `data/soundings/maoarmbeatmM1.c1.20140101.003000.nc` | — | 57016c62474b | — | — | — |
| `data/soundings/nauru_3hr_ARMBEsonde_profiles.nc` | — | 634e40fff121 | — | — | — |

### other

| Relative file | R | S19 | S20 | S24 | First Git |
| --- | --- | --- | --- | --- | --- |
| `LICENSE` | 3972dc9744f6 | — | — | — | a29286e |
| `README.md` | 0c1edb55f97b | — | — | 0cfaf2e2ea35 | 7f3ea6e |

## Comparison totals

Counts below cover utility files only, recursively, by relative path.

| Comparison | Added paths | Absent paths | Changed common paths | Identical common paths |
| --- | --- | --- | --- | --- |
| R → S19 | 40 | 48 | 12 | 40 |
| S19 → S20 | 16 | 57 | 20 | 15 |
| S20 → S24 | 5 | 9 | 1 | 41 |

## Reproducing the read-only inspection

These were read-only commands for the pre-LFS investigation. Translate old
IDs through the commit map and check archive/ref availability before reuse:

```sh
git log --reverse --format='%H %aI %s' --stat ace-matlab/main
git ls-tree -r ace-matlab/main
git ls-tree -r a328496
git show 5cc173a -- ace_v018_dev_8aces.m
git diff --name-status -M 8e5cb2d ace-matlab/main -- 'util_*'
find -L migration_work/ACE_MATLAB -type f -not -path '*/.git/*'
```

For archive comparisons, compare bytes and relative paths separately; examine main local functions as well as `util_*`. Do not execute these historical drivers in place: some write/delete outputs before the simulation, and the root K24 driver intentionally stops after its export experiment.
