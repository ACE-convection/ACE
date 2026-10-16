# ACE 截至 v0.21.87：文件、歷史與測試結果彙整

盤點日期：2026-10-15。範圍包含 v0.21.87，基準 commit `545c284ede5adbc3dd59293bc6a72601f3f240e9`。
這是文件與現存證據的整併，沒有重新執行模型，也沒有更改數值算法。

閱讀順序：本文件的里程碑與限制 → [版本測試清單](version_test_matrix.md) → 必要時展開本文件末尾的舊報告原文。
詳細設定集中於 [test_evidence.json](test_evidence.json)，原始結果 JSON、測試程式、輸入識別資料仍保留。
已依開發者確認執行 A1/A3：移除39份已整併的舊Markdown與94個Python cache，並修正文件引用。原始run、圖表、basis與Git舊歷史保留。逐檔紀錄見 [cleanup_receipt.json](cleanup_receipt.json)。

## 1. 範圍與可靠性

- 統計一般工作區、Git 追蹤檔與 ignored `migration_work/`；不遞迴進入 `.git` 或三個已註冊 worktree。三個 worktree 只檢查登錄位置，沒有檢查其完整工作樹，禁止整包刪除。
- v0.16、v0.18、v0.19、v0.20 的歷史 source snapshot 名稱不是統一 release tag。歷史匯入與 lineage 記錄不能當成成功執行證據；詳見 [歷史版本矩陣](../migration/matlab_version_matrix.md)、[lineage](../migration/matlab_lineage.md)、[inventory](../migration/matlab_inventory.md)。
- 正式統一 tags 是 v0.18.0、v0.20.0、v0.20.87、v0.21.87。測試多在其開發過程中執行；確切版本應用執行時 source hashes、patches、build commands 識別，不能把 release 所收錄的每個舊測試說成在 release HEAD 重跑。
- 既有 `docs/migration/v02487_source_review.json`、`.md`、`v02487_upgrade_spec.md` 是未追蹤工作，排除於整併與刪除範圍。較舊 lineage 文件提及 S24 的上下文照原文保存，不代表本次驗證 S24。
- 目錄名中的 3h/6h/12h 是目標或命名；通過與實際完成時間以結果、退出狀態與 saved-state 記錄判讀。沒有結果時記為未知／僅準備，不推定成功。

## 2. 已建立的科學與開發里程碑

| 版本／階段 | 已建立的結果 | 仍須保留的限制 |
| --- | --- | --- |
| 歷史 MATLAB v0.16–v0.20 snapshots | 已盤點來源、utility 配對、basis 與介面差異；有些來源僅歷史保存 | 缺失輸入、靜態問題與分支 lineage 不確定；不能宣稱每版均執行測試 |
| v0.18.0 | 8-ACE Manus208／GOAmazon314；熱力學對齊、共同輸入、3h single 與 12h multi；real32 native precipitation 修正及混合精度控制；source normalization 保持輸出 | 大氣 1200 cases 中仍有 phase endpoint 分支差異；real32 長時間局部振幅／時間不同；沒有一般化 water/energy closure 或 compiler portability 保證 |
| v0.20.0 | KHN26 101-ACE Manaus1342；native thermodynamics／k=2 WENO 對齊；PMB packing；native 與 P3 3h、分鐘降水記帳 | MATLAB/native/P3 不是同一物理；single native/P3 初始 MF 不同；完整 6h defaults、KHN26 real32 runtime、P3 孤立 dry/warm edge cases 未因此通過 |
| v0.20.87 | Fortran `ace_t` OOP-0–5b、ownership／lifecycle contracts；195 artifacts 保持；最終 native/P3 各 3h state、normal output、precipitation 均與各自舊參考 bitwise identical；原 Fortran lineage 保留 | 比較的是 Fortran 重構前後；P3 每個新 process 限一個 wrapper context；一般 reset/copy/concurrent lifecycle 未認證 |
| v0.21.87 | GOAmazon314、88×5 km slab、dt=6 s、dz=100 m、8h、DHh/DHv on；修正 PMD SI/native 單位差 1e6；packing 保持 bytes；32 threads 完成 4800 steps／481 minute states，開發者接受 | P3 僅 one-step compatibility；real32 僅 compile；完整 MATLAB 8h normal postprocessing 未驗；Precomputed 仍只是 benchmark |

v0.21.87 全部 saved states 的 MATLAB/Fortran 最大差異：MF `3.139159160392424e-8`、theta_e `3.164322492921201e-7 K`、qt `7.539331919187431e-11 kg/kg`。
最終 state 分別為 `8.182548128432207e-9`、`3.778535528908833e-8`、`1.5889772136956637e-11`。
這是已接受案例的觀察值，不是新增通用容許誤差。來源：[v0.21.87 validation](../migration/v02187_validation.json)。

較早 JSON 的 `scientific_acceptance: pending` 與後來 release acceptance 可以同時存在；前者保存執行當時狀態，後者記錄開發者後續決定。不能覆寫歷史結果，亦不能把接受擴展至未測情境。

## 3. 證據與必要檔案

| 保留類別 | 位置／用途 |
| --- | --- |
| 目前模型與 build | `matlab/`、`fortran/`、root README、LICENSE、AGENTS.md、Git 設定 |
| 可重跑的測試 | `tests/` 的 runners、MATLAB/Fortran probes、cases、reference seeds／results；需要 source patch 與精度設定 |
| 結果與 provenance | 原始結果 JSON、source/input/executable hashes、CSV/TSV migration maps、作者 source tarballs；hash 只能辨識資料，不能重建資料 |
| 版本決策 | `docs/releases/`，migration inventory/lineage/version matrix、input contracts、current integration 與 implementation difference records |
| 本機科學資料 | 所有 basis、含 PMB/PMDv/PMD 的 NetCDF 與 parts、P3 lookup、唯一 frozen references；v0.21+ 嚴格 local-only |
| 圖表 | 正式接受圖與其數據／plotting code；PNG/PDF 是不同輸出格式，不宣稱內容 byte-identical |
| 效能實驗 | benchmark 程式、configuration、result、capture；Precomputed 未導入 production |

有直接本機依賴的例子：`tests/khn26/precip_timeseries.py` 讀取 native single、native multi、P3 三小時目錄；`oop_long_regression.py` 讀取 `khn26_multi_precipitation_three_hour`；OOP stages 讀取 frozen stage0；`tests/slab/benchmark_threads.py` 讀取原 MATLAB smoke fixture。
刪除這些原始資料會使既有驗證流程失效，僅保留摘要不足以替代。

## 4. 空間盤點

檔案大小是掃描時的數值。logical bytes 包含硬連結重複與 sparse 檔案的邏輯長度；allocated bytes 依 inode 去重，且不等於刪除後一定回收的空間（仍可能有其他 hardlink／儲存層共享）。不把 200 GB 邏輯檔案直接當成可回收容量。

| 目錄 | 檔案數 | 邏輯 MiB | 去重配置 MiB |
| --- | ---: | ---: | ---: |
| `docs/` | 229 | 28.67 | 26.14 |
| `tests/` | 278 | 11.04 | 7.61 |
| `benchmarks/` | 53 | 17.52 | 15.83 |
| `migration_work/` | 13266 | 226,281.45 | 121,063.68 |
| `data/` | 22 | 21,952.71 | 21,064.81 |
| `matlab/` | 54 | 0.17 | 0.26 |
| `fortran/` | 17 | 1.41 | 0.70 |

合計掃描 13,934 個一般檔案；547 個初始 tracked paths；135 個本機工作目錄；938 份可解析 JSON。另有 symlinks 未追蹤目標內容，三個 worktree 排除遞迴。`.git` 約 9.5 GiB，其中 LFS cache 約 9.2 GiB，Git objects 約 270 MiB；此輪不移除 Git objects 或 LFS cache。

## 5. 具體清理提案與歷史重寫邊界

A1/A3 已依本輪開發者「好，進行提交」確認執行；A2、B、C 保留為尚未執行的選項。下表記錄各組狀態。

| 組別 | 具體範圍 | 預期影響與前置工作 |
| --- | --- | --- |
| A1：合併舊敘述文件 | 下方 39 份 Markdown，原文已移入本文件附錄 | 已移除原路徑並將文件連結改向附錄；未發現程式碼引用；原文、數值來源與主張保留，主要減少檔案數 |
| A2：圖表格式擇一 | 下方 38 個有同名 PNG 的 tracked PDF | 保留 PNG、數據與 plot scripts；會失去現存向量 PDF，可能需原始 run 才能重畫，屬有代價的可選精簡 |
| A3：cache | 本機 94 個 `.pyc`，逐檔 hash 列於本機 inventory | 已移除，可重新產生；`.py` 與所有 compiled scientific executable 保留 |
| B：大型 run | 135 個目錄逐一列於測試清單 | 暫保留；需要先核對每個引用、唯一資料、hardlink 及執行狀態，不能按年代或目錄名直接刪 |
| C：Git 歷史 | 僅 A1/A2 的逐路徑 purge 可作下一個審查範圍 | 需先確認哪些 local branches、remote branches 與 tags 允許改寫；不得擴大至 basis、歷史 source、其他路徑 |

A2+A3 合計邏輯大小約 7.97 MiB；不會釋放 119 GiB 的 run 空間。A1 原文被整併而非丟棄，因此不應把原檔大小當成淨節省量。

`git rm` 加新 commit 只改當前樹，舊版本仍能還原；歷史 purge 則會改寫包含這些路徑的 commits 及後繼 commits，使 commit IDs、annotated tags 與記錄中的歷史定位失效。只有本機 rewrite 不會清掉遠端；更新共享分支／tags 必須另行確認並協調其他 checkout。伺服器 LFS objects 也不會因 refs 改寫而自動消失。
較安全方案是先做 A 組的一般 commit，保留舊 release tags；若仍要歷史 purge，先另存可驗證的 recovery bundle／對照表、在獨立 clone 預演 path filter，檢查舊 source 與 pre-v0.21 basis lineage，再確認要替換的 refs。不能直接對目前有其他 worktree 的 repo 執行全域清理或 garbage collection。

需要確認的依據是 [AGENTS.md](../../AGENTS.md) §7「obtain developer confirmation before destructive cleanup」、§8「summarize the proposed work and obtain developer confirmation」，以及 §13「Rewriting existing/shared history, replacing published tags, force-pushing, or deleting server objects requires explicit separate developer authorization」。本輪已確認一般整理與提交；尚未指定可替換哪些既有共享 refs，因此歷史 rewrite／force-push 未執行。

### 歷史 purge 會涉及的現有 refs

本機歷史查詢找到13個local branches、2個remote-tracking refs、4個release tags曾包含A1/A2路徑。以下是待批准的範圍清單；remote-tracking資訊來自本機，尚未向伺服器確認最新狀態，並未獲准改寫或推送。只改main會讓其他refs繼續保留原檔。

- `refs/heads/docs/archive-test-evidence`
- `refs/heads/docs/consolidate-migration`
- `refs/heads/feature/shared-netcdf-input`
- `refs/heads/feature/v02187-basis-goamazon`
- `refs/heads/fix/fortran-single-precision-precip`
- `refs/heads/main`
- `refs/heads/migration/v020-preparation`
- `refs/heads/migration/v02487-review`
- `refs/heads/refactor/fortran-v020-oop`
- `refs/heads/refactor/normalize-v018`
- `refs/heads/test/khn26-multiace-gravity-wave`
- `refs/heads/test/pmb-stage1-baseline`
- `refs/heads/test/serial-timestep-profile`
- `refs/remotes/origin/feature/shared-netcdf-input`
- `refs/remotes/origin/main`
- `refs/tags/v0.18.0`
- `refs/tags/v0.20.0`
- `refs/tags/v0.20.87`
- `refs/tags/v0.21.87`

### A1：整併原檔與 hash

| 原路徑 | 整併位置 | 原檔 SHA-256 |
| --- | --- | --- |
| `docs/fortran_multiace_precision_control.md` | [原文](#record-fortran-multiace-precision-control) | `ff950c592e649d375400236b83e18559e915ed03ede1524a43cfc091f5b89ed9` |
| `docs/fortran_single_precision_multiace.md` | [原文](#record-fortran-single-precision-multiace) | `78f294ea60069c9fd572906e34ca388955750b71d7683404797cd70436c6a999` |
| `docs/fortran_single_precision_precipitation.md` | [原文](#record-fortran-single-precision-precipitation) | `105add1fe775ddb04169de21f741860c447764247eaf70ef357b8b2825bfc2ec` |
| `docs/goamazon314_single_no_precip_3h.md` | [原文](#record-goamazon314-single-no-precip-3h) | `84256c1e7516ebd2d8625f3b575574f20a5b50570be29bdb3f4533bb735212cb` |
| `docs/goamazon314_single_saturated_bubble_3h.md` | [原文](#record-goamazon314-single-saturated-bubble-3h) | `52cd930a9aea7d1e94d86ee8218833fa823edcef04c8086e1afe54a6c77e58e1` |
| `docs/manus208_multi_outer_pulse_12h.md` | [原文](#record-manus208-multi-outer-pulse-12h) | `15609fe49d34d60baa801ee7a88cdd7877724cac8cdd4fb79b1a006069ba780e` |
| `docs/manus208_single_saturated_bubble_3h.md` | [原文](#record-manus208-single-saturated-bubble-3h) | `09bc33d9f72bc5b04e59604be30dc20e807d617fe80568de4e005bf729cf9341` |
| `docs/manus208_single_saturated_bubble_precip_3h.md` | [原文](#record-manus208-single-saturated-bubble-precip-3h) | `196cd9ad5f0a213d2018839a86640fa433d0c83b37ad3950ce01a8cf7925e501` |
| `docs/migration/v020_khn26_constants_audit.md` | [原文](#record-v020-khn26-constants-audit) | `689d7fcccac314be8d3228666807e7a12ebd040de641a0d6fde51be21153d03a` |
| `docs/migration/v020_khn26_matlab_alignment_ten_minute_gates.md` | [原文](#record-v020-khn26-matlab-alignment-ten-minute-gates) | `ea7c01a24afab0fc6aed524bfa23d792078f79ab2029d774c075b58ff7c02e1c` |
| `docs/migration/v020_khn26_multiace_difference_attribution.md` | [原文](#record-v020-khn26-multiace-difference-attribution) | `362ee8aaa8ce45695912a63d013966218c0f88bf4e6b86fc6928267d481c2201` |
| `docs/migration/v020_khn26_multiace_gravity_wave.md` | [原文](#record-v020-khn26-multiace-gravity-wave) | `e6fa2f20f2a67fdd9f0f27a1c9de1ab22e6f5111f93841293c7d49353fc682f6` |
| `docs/migration/v020_khn26_multiace_three_hour_comparison.md` | [原文](#record-v020-khn26-multiace-three-hour-comparison) | `93f4f302a77c1eb7e176b635150161cccf6b1adc684d53b42d0c8b3fe175e558` |
| `docs/migration/v020_khn26_p3_smoke.md` | [原文](#record-v020-khn26-p3-smoke) | `7609dad627aa3efba03df1a6fba3e63020533993d70a6e8f8e6dba9305851b1c` |
| `docs/migration/v020_khn26_p3_three_hour.md` | [原文](#record-v020-khn26-p3-three-hour) | `d9feee0e715f16a1fd04ab04f6831d8bab4510600e923338b3bf14f935b07af5` |
| `docs/migration/v020_khn26_single.md` | [原文](#record-v020-khn26-single) | `6dad8d0e07488979f3c1936d46e5fcc31d45cc57c8a3288e682d8145a192f5ba` |
| `docs/migration/v020_khn26_single_native_physical_review.md` | [原文](#record-v020-khn26-single-native-physical-review) | `4be19dfcbceb17743a207624ad46d6ece2fdfea09608f4a3b8e0d230d69647a7` |
| `docs/migration/v020_khn26_single_physical_review.md` | [原文](#record-v020-khn26-single-physical-review) | `c16b4ab51662c83ef38adf228d360c1545bcc9e3f329eca955371a8f1b4b50cb` |
| `docs/migration/v020_khn26_single_precip_comparison.md` | [原文](#record-v020-khn26-single-precip-comparison) | `c86c61f198c6dab209c3b4df0515b5448d59443c2294c615de3caed1202100c0` |
| `docs/migration/v020_khn26_six_hour.md` | [原文](#record-v020-khn26-six-hour) | `80eb87a7dd2ad234852b1e20987709a7d950ecd403a8c4633c0851ec1f919f44` |
| `docs/migration/v020_khn26_status.md` | [原文](#record-v020-khn26-status) | `3ad97422ea1528826b3c51099171929d4644a79497c5c7505b1068117c97665f` |
| `docs/migration/v020_khn26_ten_minute_error_sources.md` | [原文](#record-v020-khn26-ten-minute-error-sources) | `4e083c12cd83d6ef9a6d0cfad7978a66f73e697af04a8ad9cfdf2e2d05b562d4` |
| `docs/migration/v020_khn26_thermodynamics_matlab_alignment.md` | [原文](#record-v020-khn26-thermodynamics-matlab-alignment) | `fba17f03eba7bde040cbce391382659b6444ef126a18a5891153bc283db98c39` |
| `docs/migration/v020_khn26_weno_matlab_alignment.md` | [原文](#record-v020-khn26-weno-matlab-alignment) | `d42f5ca913bc5e397b789cb4872c4787822c6476caba0097fc485a54a464986e` |
| `docs/migration/v020_khn26_weno_three_hour_review.md` | [原文](#record-v020-khn26-weno-three-hour-review) | `bfce333f20987c1cff33409dbcd27d7512d64a8ec8ef7145aac1aeb0f0a8d57e` |
| `docs/v018_aligned_runtime_comparison.md` | [原文](#record-v018-aligned-runtime-comparison) | `9112fd712b7a8f2b3eba7e57c4b39f772a87f47e107cde351acc25259de82154` |
| `docs/v018_atmospheric_validation.md` | [原文](#record-v018-atmospheric-validation) | `75af7fbcbbb36926c1097834b6e13a31b9dd33af0fa5932e36041a19a1954f6d` |
| `docs/v018_forward_evaluation_diagnostic.md` | [原文](#record-v018-forward-evaluation-diagnostic) | `1b7df8f5e383ce2a16e5414803b01edbc42e5707260def4b1a37f6c23dc89c56` |
| `docs/v018_ice_heat_capacity_alignment.md` | [原文](#record-v018-ice-heat-capacity-alignment) | `80d08e111efd4173e98a6ffdf9767b44d9129d61d3dc75bbfaedef7c5957f72e` |
| `docs/v018_ice_precipitation_comparison.md` | [原文](#record-v018-ice-precipitation-comparison) | `91dc47604261a8e0ef2a4c8df9e387a53d163ff6c231bbbbbb7ec575dc389d06` |
| `docs/v018_mixed_precipitation_comparison.md` | [原文](#record-v018-mixed-precipitation-comparison) | `d6bb7808eacd5d348bb27aa659e46a582fb8f9d1cd817e67ef9ffa8e9cf24b0d` |
| `docs/v018_mixed_residual_diagnostic.md` | [原文](#record-v018-mixed-residual-diagnostic) | `54965a14f5bc6a4e9a01600b95a677c0e95e96f8c00075fdcb264d9071506bc5` |
| `docs/v018_phase_endpoint_proposal.md` | [原文](#record-v018-phase-endpoint-proposal) | `286a8e8d718a2bd0071f21d2f253f2728ffa83da322590bac34789190d9a9dc9` |
| `docs/v018_pressure_power_diagnostic.md` | [原文](#record-v018-pressure-power-diagnostic) | `bb4b20a437c3e3365cf95ae20b7e69e20814e5357bf02086367e746f57c0685a` |
| `docs/v018_reference_tv_alignment.md` | [原文](#record-v018-reference-tv-alignment) | `c41fdb7caf43ff95f763a85aa3a0a5418a13f30af19295197653f72256306ef4` |
| `docs/v018_reference_tv_diagnostic.md` | [原文](#record-v018-reference-tv-diagnostic) | `9843d0ca06c5da62d93a9cafbd85de9d9b6be5cb18f0a04cd665ac6e3f7e01c6` |
| `docs/v018_runtime_comparison.md` | [原文](#record-v018-runtime-comparison) | `7c3769794b4ae0ce82aced94bcfe361c2f59fc443011cbce56815a70e9bd2973` |
| `docs/v018_thermodynamic_alignment.md` | [原文](#record-v018-thermodynamic-alignment) | `e930de4e34b26b830bb72613af884f06e3183151e19f179a7d2797c665cb9287` |
| `docs/v018_thermodynamic_review.md` | [原文](#record-v018-thermodynamic-review) | `5cadf5a1e9781d831102eb03a4299c8ba1a29df2657ba47ce7b9a273f8c6a837` |

### A2：可選移除的 PDF

- `docs/figures/khn26_single_physical_review.pdf` → 保留 `docs/figures/khn26_single_physical_review.png`
- `docs/figures/manus_multi_outer_pulse_12h_comparison.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_comparison.png`
- `docs/figures/manus_multi_outer_pulse_12h_difference.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_difference.png`
- `docs/figures/manus_multi_outer_pulse_12h_double_precision_comparison.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_double_precision_comparison.png`
- `docs/figures/manus_multi_outer_pulse_12h_fortran.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_fortran.png`
- `docs/figures/manus_multi_outer_pulse_12h_matlab.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_matlab.png`
- `docs/figures/manus_multi_outer_pulse_12h_precision_response.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_precision_response.png`
- `docs/figures/manus_multi_outer_pulse_12h_response.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_response.png`
- `docs/figures/manus_multi_outer_pulse_12h_single_precision_comparison.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_single_precision_comparison.png`
- `docs/figures/manus_multi_outer_pulse_12h_single_precision_response.pdf` → 保留 `docs/figures/manus_multi_outer_pulse_12h_single_precision_response.png`
- `docs/figures/manus_saturated_bubble_mf.pdf` → 保留 `docs/figures/manus_saturated_bubble_mf.png`
- `docs/figures/manus_saturated_bubble_precip_mf.pdf` → 保留 `docs/figures/manus_saturated_bubble_precip_mf.png`
- `docs/figures/manus_saturated_bubble_precip_single_precision_mf.pdf` → 保留 `docs/figures/manus_saturated_bubble_precip_single_precision_mf.png`
- `docs/figures/khn26_multi_native_3h/mf_20min_snapshots.pdf` → 保留 `docs/figures/khn26_multi_native_3h/mf_20min_snapshots.png`
- `docs/figures/khn26_multi_native_3h/selected_aces.pdf` → 保留 `docs/figures/khn26_multi_native_3h/selected_aces.png`
- `docs/figures/khn26_multi_native_3h/spatial_mf.pdf` → 保留 `docs/figures/khn26_multi_native_3h/spatial_mf.png`
- `docs/figures/khn26_multi_native_3h/state_errors.pdf` → 保留 `docs/figures/khn26_multi_native_3h/state_errors.png`
- `docs/figures/khn26_multi_precipitation_3h/multiACE_ACE1_precipitation.pdf` → 保留 `docs/figures/khn26_multi_precipitation_3h/multiACE_ACE1_precipitation.png`
- `docs/figures/khn26_multi_precipitation_3h/multiACE_area_mean_precipitation.pdf` → 保留 `docs/figures/khn26_multi_precipitation_3h/multiACE_area_mean_precipitation.png`
- `docs/figures/khn26_multi_weno_3h/mf_snapshots.pdf` → 保留 `docs/figures/khn26_multi_weno_3h/mf_snapshots.png`
- `docs/figures/khn26_multi_weno_3h/selected_aces.pdf` → 保留 `docs/figures/khn26_multi_weno_3h/selected_aces.png`
- `docs/figures/khn26_multi_weno_3h/spatial_mf.pdf` → 保留 `docs/figures/khn26_multi_weno_3h/spatial_mf.png`
- `docs/figures/khn26_multi_weno_3h/state_errors.pdf` → 保留 `docs/figures/khn26_multi_weno_3h/state_errors.png`
- `docs/figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.pdf` → 保留 `docs/figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.png`
- `docs/figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.pdf` → 保留 `docs/figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.png`
- `docs/figures/khn26_p3_3h/multiACE_mf_snapshots.pdf` → 保留 `docs/figures/khn26_p3_3h/multiACE_mf_snapshots.png`
- `docs/figures/khn26_p3_3h/multiACE_microphysics.pdf` → 保留 `docs/figures/khn26_p3_3h/multiACE_microphysics.png`
- `docs/figures/khn26_p3_3h/multiACE_spatial_mf.pdf` → 保留 `docs/figures/khn26_p3_3h/multiACE_spatial_mf.png`
- `docs/figures/khn26_p3_3h/multiACE_time_height.pdf` → 保留 `docs/figures/khn26_p3_3h/multiACE_time_height.png`
- `docs/figures/khn26_p3_3h/singleACE_microphysics.pdf` → 保留 `docs/figures/khn26_p3_3h/singleACE_microphysics.png`
- `docs/figures/khn26_p3_3h/singleACE_time_height.pdf` → 保留 `docs/figures/khn26_p3_3h/singleACE_time_height.png`
- `docs/figures/khn26_single_native_3h/agreement_and_flow.pdf` → 保留 `docs/figures/khn26_single_native_3h/agreement_and_flow.png`
- `docs/figures/khn26_single_native_3h/time_height_comparison.pdf` → 保留 `docs/figures/khn26_single_native_3h/time_height_comparison.png`
- `docs/figures/khn26_single_native_3h/vertical_profiles.pdf` → 保留 `docs/figures/khn26_single_native_3h/vertical_profiles.png`
- `docs/figures/khn26_single_native_3h/water_and_constraint.pdf` → 保留 `docs/figures/khn26_single_native_3h/water_and_constraint.png`
- `docs/performance/khn26_blocked_15min.pdf` → 保留 `docs/performance/khn26_blocked_15min.png`
- `docs/performance/khn26_blocked_model.pdf` → 保留 `docs/performance/khn26_blocked_model.png`
- `docs/performance/khn26_serial_simd.pdf` → 保留 `docs/performance/khn26_serial_simd.png`

### 排除的 worktrees

- `migration_work/pmb_stage1_main`
- `migration_work/v02187_history_cleanup`
- `migration_work/v02187_history_cleanup_final`

## 6. 本機完整清單與復核

本機 `migration_work/repository_audit/inventory.json` 記錄逐檔路徑、tracked 狀態、logical/allocated bytes、inode、hardlink count、symlinks、候選清理 hash 與工作目錄索引；`records.json` 保存已掃描 JSON 內容與 SHA-256。兩者為 ignored 本機工作材料，不包含二進位 basis 複本，不替代原始 science data。
本文件與版本測試清單、設定附件應一併審閱；原始結果 JSON 仍為數值主張的細節來源。這次沒有重跑耗時模型或聲稱重新通過歷史測試。

## 7. 舊報告完整內容

以下依原路徑合併，保留當時結論、失敗、取消與限制；原文中的「next」「pending」「no commit」是歷史時間點。最新接受狀態以本文件上方與 release notes 為準。
僅將 Markdown 相對連結改成從本文件可解析的路徑；原始 SHA-256 已列於 A1。附錄不會以摘要取代未確認的科學細節。

<a id="record-fortran-multiace-precision-control"></a>

<details>
<summary>docs/fortran_multiace_precision_control.md</summary>

# Corrected real64 multiACE control

## Purpose and matched configuration

The developer authorized a corrected real64 twelve-hour multiACE run after
reviewing the real32 trajectory differences. This control compares the
corrected Fortran model with the preserved MATLAB run, and then compares
corrected real32 and real64 using the same numerical sources and case settings.
It tests whether the corrected real64 model exhibits the large late drift
observed in real32; it does not change the production precipitation algorithm.

The case remains Manus 208, ACE 8 initial MF pulse over 0–1000 m, no thermal
bubble, all eight ACEs evolving, native precipitation, original geometry/PMB
and damping, no sustained forcing, MF diffusion off, SSPRK93, dt=4 s,
duration=43200 s and output every 60 s. Shared input, common seed and reference
MF identities are checked against the committed twelve-hour report. Real64
retains the binary64 seed exactly; real32 uses its explicit binary32 conversion.

The real64 control adds `-fdefault-real-8 -fdefault-double-8` to the same GNU
flags used by the real32 test. Both use array checks and invalid/zero/overflow
traps. Model source, test driver, compiler, input, seed and coordinates must
match before generating the precision response comparison. PMB/input storage
remains binary64 in both builds. MATLAB and the completed real32 simulation
are reused from their preserved, verified outputs.

## Reproduce

```bash
python3 tests/precision/run_multi.py migration_work/manus_multi_real64 --precision 64
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real64 --layout comparison
python3 tests/precision/compare_multi.py migration_work/manus_multi_real32 \
  migration_work/manus_multi_real64 migration_work/manus_multi_precision_comparison
```

See the [precision instructions](../../tests/precision/README.md) for reference
artifact requirements and plotting dependencies. All full histories, executed
source snapshots, commands and logs are preserved in ignored run directories.
No frozen v0.18 reference or release tag is replaced.

## Completed control and visual comparison

The corrected real64 run completed all 43200 s in about 945 s, with 721 saved
times. All states were finite and qt nonnegative; minimum qt was
1.404413e-6 kg/kg. The initial state exactly matched the binary64 seed.
Invalid/zero/overflow traps did not fire. Precipitation removal was positive
in 10586 of 10800 steps and its diagnostics were finite/nonnegative.

The [real64 MF comparison PNG](../figures/manus_multi_outer_pulse_12h_double_precision_comparison.png)
and [PDF](../figures/manus_multi_outer_pulse_12h_double_precision_comparison.pdf)
retain the eight-row MATLAB/Fortran/difference layout. The
[three-way response PNG](../figures/manus_multi_outer_pulse_12h_precision_response.png)
and [PDF](../figures/manus_multi_outer_pulse_12h_precision_response.pdf)
overlay MATLAB (black), corrected real64 (dashed blue), and corrected real32
(orange) for each ACE. Each ACE panel uses its own vertical scale.
Evidence is archived in [the control summary](../fortran_multiace_precision_control.json).

MATLAB and real64 response curves visually overlap across all eight ACEs,
including late oscillations and renewed ACE 1 growth near 12 h. The maximum
full-domain MF difference is 6.678906e-5 kg m-2 s-1. This is an observation,
not a prescribed acceptance tolerance.

| ACE 1 measurement | MATLAB | Corrected real64 | Corrected real32 |
| --- | ---: | ---: | ---: |
| Peak absolute MF (kg m-2 s-1) | 17.962021 | 17.962021 | 18.088482 |
| Peak time (h) | 9.3167 | 9.3167 | 9.85 |
| Peak height (km) | 7.35 | 7.35 | 6.45 |
| Max absolute MF at 12 h (kg m-2 s-1) | 13.098349 | 13.098337 | 0.718233 |

For this case, the large trajectory separation appears when reducing default
real precision with the corrected numerical sources held fixed. The corrected
real64 precipitation evaluation does not produce comparable divergence from
MATLAB. This supports attributing the large difference primarily to the
precision change under this corrected model; it does not locate a particular
sensitive routine or separate every possible precision/algorithm interaction.
Real32 execution remains demonstrated, while long-run MF agreement is limited.
No scientific acceptance decision or production algorithm change follows
automatically from these figures.

<a id="record-fortran-multiace-precision-control--developer-release-acceptance-2026-10-04"></a>

## Developer release acceptance (2026-10-04)

After reviewing the comparison figures, the developer accepted the current
single-precision results as sufficient for this release milestone. The
accepted physical behavior is propagation of the outer disturbance into the
inner ACEs and excitation of ascending motion, consistent with MATLAB and
corrected real64 Fortran. In this case the outer disturbance is the initial
ACE 8 MF pulse; there is no sustained external forcing.

The developer interprets the trajectory separation as amplification of small
differences during long integration and accepts the observed timing and local
amplitude differences for this milestone. This is a scientific acceptance
decision for the tested cases, rather than a demonstrated diagnosis of the
amplification mechanism or a claim of numerical trajectory equality. The
recorded differences and original evidence remain available above.

P3 integration is planned for v0.20 and is not a requirement for this release.
The current Fortran implementation uses native simplified precipitation.
This record does not create a release tag or change the existing v0.18.0 tag.

</details>

<a id="record-fortran-single-precision-multiace"></a>

<details>
<summary>docs/fortran_single_precision_multiace.md</summary>

# Fortran real32 multiACE comparison

## Configuration

The developer requested a multiACE test after visual review of the
[single-ACE MF comparison](#record-fortran-single-precision-precipitation).
This reuses the previously completed
[Manus 208 twelve-hour experiment](#record-manus208-multi-outer-pulse-12h):

- All eight ACE tendencies evolve with the original geometry and full PMB.
- No thermal bubble; the only initial MF pulse is in ACE 8, with amplitude
  0.03 kg m-2 s-1 and the existing sine profile over 0–1000 m.
- No sustained external forcing, native precipitation, original damping,
  MF diffusion disabled, SSPRK93, dt=4 s, duration=43200 s, output every 60 s.
- Corrected default-real32 Fortran prognostics and thermodynamic/tendency
  arrays; existing PMB and shared-input reads remain binary64.

The original MATLAB-exported common seed is converted explicitly to binary32.
Its SHA-256 and the original full eight-ACE MF archive are checked against the
committed twelve-hour report. The pinned shared input is also checked. MATLAB
is reused from that verified completed run. There is no new MATLAB integration
and no P3 in this experiment. The Fortran production numerical routines have
the previously tested precipitation evaluation correction; this task changes
only test mode selection, reporting and plotting.

## Reproduce

From the repository root, with the preserved MATLAB reference available:

```bash
python3 tests/precision/run_multi.py migration_work/manus_multi_real32
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real32 --layout comparison
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_real32
```

Requirements and reference-directory options are in
[the precision test instructions](../../tests/precision/README.md).
On this host, plotting additionally uses
`PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib`.
Use a fresh output directory; completed integration can be analyzed again
with `--analyze-existing` without rerunning the model.

The test traps invalid operations, division by zero and overflow, checks
array accesses, and checks finite model states and nonnegative total water
at each step. The completed-output checks require the exact binary32 seed,
721 saved times, finite/nonnegative sink diagnostics and active precipitation.
Generated sources, their instrumentation diff, commands, logs, sink diagnostics
and full prognostic history are preserved in the ignored run directory.

MF comparisons are visual, using the prior eight-row, three-column layout:
MATLAB, single-precision Fortran, and Fortran-minus-MATLAB. Each panel retains
height/width=1/5. Each ACE row has a MATLAB/Fortran shared color scale and
an independent difference scale; scales differ between rows. Response curves
show max |MF| over the full 0–40 km grid for all eight ACEs. These observations
do not set a new numerical acceptance threshold.

## Completed run and visual review

The real32 run completed 43200 s in about 912 s on this host. All 721 saved
states are finite with nonnegative total water; minimum qt is
1.441313e-6 kg/kg. The initial state equals the binary32 conversion of the
verified common seed. Precipitation sink diagnostics are finite/nonnegative,
with positive removal in 10585 of 10800 steps. Invalid, zero-division and
overflow traps did not fire. These are execution checks, not water-budget
closure or a scientific-equivalence decision.

The completed [comparison PNG](../figures/manus_multi_outer_pulse_12h_single_precision_comparison.png)
and [PDF](../figures/manus_multi_outer_pulse_12h_single_precision_comparison.pdf)
retain all 24 panels and their verified 1:5 aspect ratio. The
[response curves](../figures/manus_multi_outer_pulse_12h_single_precision_response.png)
and [PDF](../figures/manus_multi_outer_pulse_12h_single_precision_response.pdf)
make the timing differences easier to see. Numerical/source/artifact evidence
is in [the summary JSON](../fortran_single_precision_multiace.json); full run
artifacts remain under `migration_work/manus_multi_single_precision_12h/`.

Both implementations show early outer-ACE activity followed by a much stronger
late inner-ACE response. The strongest MF has a similar magnitude, but the
multiACE trajectories differ visibly:

- ACEs 1 and 2 show additional local real32 signals around 1.5–2 h.
- ACE 1's strongest response is delayed in real32. Its peak |MF| is
  18.088482 kg m-2 s-1 at 9.85 h and 6.45 km, versus MATLAB's
  17.962021 at 9.3167 h and 7.35 km: 32 minutes later and 0.9 km lower
  for the location of the maximum, not a measure of cloud-top displacement.
- After the main response, oscillations and further growth differ across
  the inner ACEs. MATLAB ACE 1 strengthens again near 12 h, while real32
  ACE 1 is much weaker at that time. This is more substantial than the
  three-hour single-ACE MF differences.

This comparison includes both default-real32 arithmetic and the corrected
precipitation evaluation. It does not isolate their individual effects or
identify a cause for the trajectory divergence. The developer subsequently
accepted the physical evolution for this release milestone; see the
[acceptance record](history_summary.md#record-fortran-multiace-precision-control--developer-release-acceptance-2026-10-04).
No production algorithm is changed in response to the difference by this
testing task.

The subsequent [corrected real64 control](#record-fortran-multiace-precision-control)
now provides a matched-source precision comparison. Its MF response closely
reproduces MATLAB, while real32 retains the visible time/evolution differences.
That report records the case-specific inference and preserves this initial
real32 comparison as evidence.

</details>

<a id="record-fortran-single-precision-precipitation"></a>

<details>
<summary>docs/fortran_single_precision_precipitation.md</summary>

# Fortran native precipitation: single-precision evaluation

## Scope

The developer requested default-real32 Fortran validation before testing P3.
This change is confined to evaluation of the existing native precipitation
sinks. The ramp threshold (0.5 g/kg), transition coefficient (20), relaxation
time (300 s), native ACE/vertical masks, stage-1 thermodynamic cache,
post-dynamics update, qt clamp and damping are retained. MATLAB and frozen
`v0.18.0` reference files are unchanged. This is a subsequent numerical
change, not a path-only refactor or a new acceptance of all configurations.

The model's default-real prognostic arrays, thermodynamic work arrays and
tendencies can be compiled as real32. Existing binary64 PMB storage and shared
NetCDF input reads remain binary64; input values are converted explicitly to
the prognostic kind. This validates a mixed-precision model.

## Reproduced defects and correction

For `x = (20/0.0005)*(qc-0.0005)`, the old `log(1+exp(x))` overflows
in binary32 at 3 g/kg liquid or ice condensate (`x=100`). The eight fixed
probes reproduced infinite water tendencies and NaN theta_e tendencies.
The old `1e-8` kg/kg forward difference also returned zero theta_e tendency
at the liquid/ice ramp threshold and a mixed-phase probe in binary32.
Finally, zero condensate was cleared only after dividing liquid and ice by
zero; the corrected routine returns zero sinks before these operations.

The softplus uses the exact identity

```text
log(1+exp(x)) = max(x,0) + log(1+exp(-abs(x))).
```

The exponential argument is nonpositive. For `u=exp(-abs(x))`, the
`log(1+u)` evaluation compensates rounding in `1+u` using
`log(1+u)*u/((1+u)-1)`, or returns `u` when `1+u` rounds to one.
This also retains small sub-threshold sinks that the original real32
expression rounded to zero.

The thermodynamic derivative is taken from the **existing** `theta_e`
formula at fixed temperature, vapor, pressure and liquid/ice ratio. Let
`f=qi/qc`, `Re=(1-qt)*Rd`, `R=Re+q*Rv`, `C=Cpd+qt*(Cl-Cpd)` and
`theta_e=T*exp(U/C)`. Then

```text
dU/dqc = -Rd*log(P0*R/(p*Re))
         + f*((Cl-Ci(T0))*log(T0/T)-Lf/T0)
dtheta_e/dqc = (theta_e/C)*[dU/dqc-(Cl-Cpd)*log(theta_e/T)].
```

The terms from mixture gas constant and vapor pressure cancel at fixed
vapor. Constants and `Ci(T0)` match the current forward function, including
its existing reference-temperature conventions. The precipitation theta_e
tendency is `dqt/dt * dtheta_e/dqc`.
This replaces the finite-increment numerical derivative in both precisions;
double-precision trajectories may therefore differ slightly from the accepted
v0.18 results. No new physical precipitation law or phase selection is added.

## Verification

Use [the reproducible test entry](../../tests/precision/README.md). Eight explicit
states cover dry, small liquid, ramp threshold, high liquid/ice and mixed
condensate. Corrected sinks are finite with nonpositive water tendencies,
and zero-condensate sinks are exactly zero under invalid/zero/overflow traps.
Water sink values match an independent numpy `logaddexp` evaluation.
The largest derivative relative errors against a centered binary64
perturbation of the original forward function are `2.887e-6` (real32) and
`5.105e-10` (real64).

The subsequent runtime comparison uses the fixed Manus 208 saturated bubble,
native precipitation and matched archived initial seed, dt=4 s, output every
minute, single ACE 1 tendencies and full eight-ACE geometry/PMB. Baseline
real64 and corrected real32/real64 are compared without prescribing a
trajectory acceptance tolerance. The production makefile/driver is also
built in an isolated directory and tested with its native multiACE defaults.
Generated sources, command logs and full outputs are preserved under
`migration_work/single_precision_precip_corrected/`; the small summary record
is archived alongside this report.

These checks do not exercise P3 or establish full physical budget closure,
compiler portability or universal phase-boundary agreement.

## Completed three-hour results

GNU Fortran 11.2.0 completed all three runs, each with 181 saved times.
Corrected real32 and real64 had finite states, nonnegative total water and
positive precipitation removal throughout the tested integration. Invalid,
division-by-zero and overflow traps did not fire. The baseline real64 MF
arrays exactly reproduced the frozen precipitation-enabled reference.
An uninstrumented real32 production build using the actual makefile also
completed 60 s with all nine saved output fields finite and total water
nonnegative. See the [archived numerical summary](../fortran_single_precision_precipitation.json).

| Maximum absolute difference from original real64 | Corrected real32 | Corrected real64 |
| --- | ---: | ---: |
| theta_e (K) | 4.713331 | 2.948830e-4 |
| qt (kg/kg) | 9.762560e-4 | 3.508706e-8 |
| MF (kg m-2 s-1) | 0.1585523 | 3.482787e-6 |

Real32 theta_e/qt maxima are localized in ACE 1 near 15.6 km, at
10740 s and 10140 s respectively. The MF maximum difference is at
7740 s and 13.8 km in ACE 1. Peak |MF| is 16.046093 in original real64
and 16.041836 in corrected real32. Similar peak MF alone does not establish
agreement of local thermodynamic evolution.
The real32 differences are observations, not accepted numerical tolerances;
their causes have not been isolated. The developer subsequently accepted the
tested physical evolution as sufficient for this release milestone; see the
[acceptance record](history_summary.md#record-fortran-multiace-precision-control--developer-release-acceptance-2026-10-04).
Numerical trajectory equality is not established. Drift diagnosis remains a
subsequent task, and P3 integration is planned for v0.20.

## MATLAB versus single-precision Fortran MF figure

The developer requested visual MF comparison on 2026-10-03. The previous
three-panel MATLAB/Fortran layout is reused with corrected real32 Fortran
data in the second panel and real32-minus-MATLAB in the third. The MATLAB
panel retains the archived precipitation-enabled reference. Axes, colormap
and shared MATLAB/Fortran scaling follow the original figure; the difference
scale is computed from the new difference field.

[PNG](../figures/manus_saturated_bubble_precip_single_precision_mf.png) ·
[PDF](../figures/manus_saturated_bubble_precip_single_precision_mf.pdf).
The main MF ascent and broad time-height structure look similar at this
scale. Differences are visible along the upper plume and its oscillations,
especially around 12–16 km after approximately one hour. This describes the
figure rather than imposing a new acceptance criterion. Plot inputs and
hashes are included in the archived numerical summary under `mf_plot`.

Reproduce with `tests/precision/plot_mf.py`; see the
[plot instructions](../../tests/precision/README.md). The original double-precision
reference figure remains preserved for traceability.

</details>

<a id="record-goamazon314-single-no-precip-3h"></a>

<details>
<summary>docs/goamazon314_single_no_precip_3h.md</summary>

# GOAmazon 314: three-hour single-ACE integration without precipitation

This report preserves the initial run without a thermal bubble. The requested
[1 K saturated-bubble follow-up](#record-goamazon314-single-saturated-bubble-3h)
uses levels 11–51 in ACE 1 and has separate outputs and figures.

Completed on 2026-10-02 using active sources at `afa0b24`.
Both implementations reached 10800 s with finite prognostic states.
Results are descriptive comparisons; byte equality is not an acceptance goal.

## Configuration

- Input: `data/input/goamazon314.nc`, profile 314 (`arm=3`).
- Single mode: ACE 1 tendencies enabled; ACEs 2–8 tendency-masked.
  All eight ACEs, their geometry and the full PMB remain present.
  Original damping also remains active.
- Initial MF: `0.03*sin(pi*z/1000)` kg m-2 s-1 in ACE 1 from 0–1000 m.
- Duration: 3 hours; dt=4 s; SSPRK93; 50 m vertical grid to 40 km.
- Output: every 60 s, including t=0; 181 snapshots in binary64.
- Precipitation: explicitly disabled by skipping MATLAB's post-step
  `ApplyPrecip` call and Fortran's post-step sink call/update in temporary
  sources. Thermodynamic condensation and its buoyancy effects remain.
- MF diffusion: disabled, matching active defaults.
- MATLAB: R2023b Update 9, actual numerical routines via the test entry,
  without the normal driver's unused plume/radiation/plotting diagnostics.
- Fortran: GNU 11.2.0, `-O2 -ffree-form -fdefault-real-8
  -fdefault-double-8 -ffree-line-length-none` and netCDF-Fortran.

## Results and artifacts

The maximum absolute ACE 1 MF difference is **1.493633e-11 kg m-2 s-1**,
at 55 minutes and 6.2 km. RMS difference is 9.275183e-13 kg m-2 s-1;
relative L2 difference is 3.832487e-11.
MATLAB MF ranges from -0.470806691101 to 0.105230297879 kg m-2 s-1;
Fortran has the same range to the shown practical precision.
Both total-water fields remain nonnegative in all saved states.

Artifacts are retained under ignored
`migration_work/goamazon314_single_no_precip_3h_native/`:

- `mf_three_panels.png` and `.pdf`: top MATLAB, middle Fortran,
  bottom Fortran-minus-MATLAB. Height shown is 0–20 km; the first two panels
  share a color scale and the difference has its own symmetric scale.
- `mf.npz`: time, full 0–40 km height, MATLAB and Fortran ACE 1 MF arrays.
- `matlab.nc` and `fortran.bin`: full eight-ACE prognostic outputs.
- `results.json`: metrics, source/input/artifact hashes and runtime versions.
- Generated sources, access/no-precipitation patches, binaries and model logs.

The initial sandbox attempt could not start MATLAB because its preferences
directory was not writable; its evidence remains in the separate
`goamazon314_single_no_precip_3h/` directory. The successful integration used
authorized execution outside the sandbox. Its original runner is preserved
as `runner_executed.py`. After both integrations completed, a MATLAB NetCDF
axis-order error in Python postprocessing was corrected and analysis was
repeated on the preserved outputs, without rerunning either integration.
The preparatory `configuration.json` came from the Manus-based access builder;
the actual case input and hash are recorded in `results.json` and the model
logs/generated drivers use GOAmazon 314.

## Reproduce

Use a fresh directory and a MATLAB environment with writable preferences:

```bash
python3 tests/alignment/run_sounding_case.py migration_work/goamazon314_repeat
python3 tests/alignment/plot_mf.py migration_work/goamazon314_repeat
```

The runner defaults to GOAmazon 314, 10800 s and 60 s output.
The plotting script requires numpy and matplotlib. On this host, plotting
dependencies were installed only into `/tmp/ace-mf-plot-deps`, so use:

```bash
PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib \
  python3 tests/alignment/plot_mf.py migration_work/goamazon314_single_no_precip_3h_native
```

Production and historical model sources were not modified. These checks
establish completion and close MF agreement for this configuration; physical
interpretation of the approximately 6 km descending feature remains a
separate scientific review.

</details>

<a id="record-goamazon314-single-saturated-bubble-3h"></a>

<details>
<summary>docs/goamazon314_single_saturated_bubble_3h.md</summary>

# GOAmazon 314: single ACE with a 1 K saturated bubble

This is the requested bubble-enabled follow-up to the preserved
[run without a thermal bubble](#record-goamazon314-single-no-precip-3h).
Byte equality is not an acceptance goal.

## Completed results (2026-10-02)

Both MATLAB and GNU Fortran completed 10800 s with finite prognostic output
and 181 saved snapshots. Saved total-water values remain nonnegative.
Common initial-state loading and raw-output-to-MF array mapping were checked;
production and artifact hashes match. No acceptance tolerance was imposed.

ACE 1 MF ranges from -1.663776 to 10.342436 kg m-2 s-1 in both runs.
The maximum absolute Fortran-minus-MATLAB difference is
**1.373079e-11 kg m-2 s-1**, at 140 minutes and 7.25 km.
RMS difference is 8.664643e-13 kg m-2 s-1 and relative L2 difference is
6.216012e-13. The bubble causes a substantially stronger positive MF response
than the earlier run without a bubble; interpreting the sustained ascent
remains a scientific review, separate from the execution check.

The final PNG/PDF are `mf_three_panels.png` and `mf_three_panels.pdf` under
the artifact directory below. `results.json` records runtime configuration,
command arguments, metrics and hashes; `bubble_validation.json` records
the initialization check. The earlier no-bubble outputs were preserved.

## Initialization and configuration

The active MATLAB driver already contains the thermal-bubble initialization
at `BL`, `dTbl`, `dqsat`, `dqcbl`, followed by its `X0` update. Its default
`BL=[]` disables the bubble. The experiment copies that driver into a
temporary `initialize_sounding.m` and changes only:

```matlab
BL = 11:51;
dTbl = 1;
```

The original `dqsat=1` and `dqcbl=0` remain: temperature is increased by
1 K, water vapor is set by the original `eval_qsat`, and no condensate is
added explicitly. The bubble is in ACE 1. Original initialization uses
`T_zm` and `p_mf`, with selected heights 500–2500 m, inclusive (41 layers).
It writes theta_e/qt into the existing prognostic slots. The staggered-grid
convention is preserved; this experiment does not redefine initialization
using `T_env`/`p_zc`.

MATLAB exports the complete initialized theta_e/qt/MF state in binary64,
and Fortran reads it before stepping. Thus the two trajectories start with
the same requested bubble and MF perturbation. An initialization check
verifies saturation against the original `eval_qsat` output, the layer
range, and unchanged thermodynamics outside the bubble and in ACEs 2–8.
This shared seed is an experimental input choice, not a native Fortran
bubble implementation or a trajectory-equality requirement.

Other settings remain those of the preceding experiment: GOAmazon profile
314; three hours; dt=4 s; SSPRK93; output every 60 s; single-ACE tendency
mask with eight-ACE geometry/PMB retained; MF pulse in ACE 1 at 0–1000 m;
MF diffusion off; damping retained. Both temporary numerical drivers
explicitly skip precipitation updates. Thermodynamic condensation and
condensate buoyancy remain active. Production/historical sources are unchanged.

## Reproduce and artifacts

```bash
python3 tests/alignment/run_sounding_case.py migration_work/goamazon314_bubble_repeat \
  --saturated-bubble
python3 tests/alignment/plot_mf.py migration_work/goamazon314_bubble_repeat
```

MATLAB needs writable preferences and a working license. On this host,
the plotting dependencies are available under `/tmp/ace-mf-plot-deps`:

```bash
PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib \
  python3 tests/alignment/plot_mf.py migration_work/goamazon314_single_saturated_bubble_3h
```

Raw evidence is retained under ignored
`migration_work/goamazon314_single_saturated_bubble_3h/`: generated drivers,
initialization/access/no-precipitation patches, source/input hashes,
common initial state, bubble initialization check, both model logs,
full outputs and exported MF arrays. The three plot panels are MATLAB,
Fortran, and Fortran-minus-MATLAB. First/second panels share a color scale;
the difference uses its own symmetric scale. Full 0–40 km MF is retained,
with the figure showing 0–20 km.

</details>

<a id="record-manus208-multi-outer-pulse-12h"></a>

<details>
<summary>docs/manus208_multi_outer_pulse_12h.md</summary>

# Manus 208: twelve-hour multiACE outer MF pulse

Developer acceptance on 2026-10-02: these results are sufficient for the
v0.18 milestone, with the limitations below retained. See the
[release decision](../releases/v0.18.0.md). Paths/hashes in the numerical evidence
describe the original run before source-root normalization.

Executed on 2026-10-02 at source commit `c43e357`, following the developer's
request to extend the outer-ACE multiACE experiment to twelve hours.
Only test drivers, reporting and plotting change; production MATLAB/Fortran
and historical sources are unchanged. [Numerical evidence](../manus208_multi_outer_pulse_12h.json)
records source/input/artifact hashes, configuration, commands, full-domain
error metrics, initialization checks and per-ACE response measurements.

## Configuration and completion

- Manus profile 208, `data/input/manus208.nc`, original eight-ACE geometry/PMB.
- ACE 8 initial MF: `0.03*sin(pi*z/1000)` kg m-2 s-1 over 0–1000 m;
  ACEs 1–7 initially have exactly zero MF. No thermal bubble is added.
- All eight ACE tendencies evolve; no sustained external forcing.
- Native precipitation scheme, original damping, MF diffusion disabled.
- SSPRK93, dt=4 s, 43200 s integration, 60 s output: 721 snapshots.
- Both models start from one MATLAB-exported binary64 theta_e/qt/MF seed.
  All initial theta_e/qt arrays match the unperturbed shared input.
- MATLAB R2023b Update 9; GNU Fortran 11.2.0 with
  `-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none`.

Both runs completed twelve hours with finite saved prognostic fields and
positive saved total water. Minimum qt is 1.404409e-6 kg/kg in both runs.
MATLAB's precipitation qt accumulator is finite, starts at zero and is
monotonic, with a final maximum of 0.08449529 kg/kg. Fortran's per-step
qt sinks are finite and nonnegative, with positive removal in 10586 of
10800 steps. These are sink diagnostics, not a closed domain-water budget.
Wall-clock integration times were about 775 s (MATLAB) and 1143 s (Fortran).

## Inner-ACE response

The curves show an early response in the outer/intermediate regions and a
much larger late response in ACE 1. In both runs, ACE 1's max |MF| first
reaches 0.03 kg m-2 s-1 at 64 minutes, 1 kg m-2 s-1 at 2.75 hours, and
10 kg m-2 s-1 at approximately 9.07 hours. These amplitude markers describe
one-minute samples; they are not physical onset criteria or tolerances.

ACE 1 peaks at **17.962021 kg m-2 s-1**, at **9.3167 hours and 7.35 km**,
in both runs. At twelve hours its max |MF| is approximately 13.09835
kg m-2 s-1. The strongest inner response therefore falls outside the
earlier three-hour comparison window. This experiment records evolution
over twelve hours; it does not establish a steady or final equilibrium.

MATLAB peak max |MF| over the full twelve-hour history and at the terminal
time (Fortran values are numerically close; exact measurements are in JSON):

| ACE | History peak (kg m-2 s-1) | At 12 h (kg m-2 s-1) |
| --- | ---: | ---: |
| 1 | 17.962021 | 13.098349 |
| 2 | 6.141302 | 2.801034 |
| 3 | 3.434877 | 0.883393 |
| 4 | 0.899276 | 0.157945 |
| 5 | 0.798029 | 0.193327 |
| 6 | 0.677068 | 0.304323 |
| 7 | 1.385226 | 0.384973 |
| 8 | 0.803897 | 0.109100 |

[Response curves](../figures/manus_multi_outer_pulse_12h_response.png) show
max |MF| over 0–40 km for every ACE. Time-height figures cover 0–20 km:
[MATLAB](../figures/manus_multi_outer_pulse_12h_matlab.png),
[Fortran](../figures/manus_multi_outer_pulse_12h_fortran.png), and
[Fortran-minus-MATLAB](../figures/manus_multi_outer_pulse_12h_difference.png).
All MF panels share one scale; differences use a separate symmetric scale.
Corresponding PDFs are archived alongside the PNGs.

The developer-requested [combined comparison PNG](../figures/manus_multi_outer_pulse_12h_comparison.png)
and [PDF](../figures/manus_multi_outer_pulse_12h_comparison.pdf) arrange ACEs 1–8
from top to bottom, with MATLAB, Fortran and Fortran-minus-MATLAB from left
to right. Every data panel has height/width = 1/5, verified from the rendered
axes dimensions. In this combined layout each row has its own MF scale,
shared by MATLAB and Fortran, and a separate difference scale. This exposes
weaker outer/intermediate responses; compare colorbar values across rows.

## Cross-implementation measurements and limits

Maximum absolute differences across all saved times, levels and ACEs:

| Quantity | Maximum absolute difference |
| --- | ---: |
| theta_e | 7.406045e-5 K |
| qt | 3.811383e-8 kg/kg |
| MF | 7.577286e-6 kg m-2 s-1 |

MF RMS difference is 9.376968e-8 kg m-2 s-1; relative L2 difference is
1.174445e-7. The maximum MF difference is at 11 h 58 min, 5.35 km, ACE 1:
MATLAB 7.804935504 and Fortran 7.804943081 kg m-2 s-1. Differences grow
in the later part of the experiment; instantaneous full-domain MF max
differences at 8, 9 and 12 hours are 4.370982e-9, 1.519420e-7 and
5.923925e-6 kg m-2 s-1, respectively.

The maximum relative MF error at a nonzero MATLAB reference is 0.363273,
at a near-zero value: MATLAB -1.572689e-6 versus Fortran -1.001374e-6
kg m-2 s-1, at 10 h 38 min, 6.15 km, ACE 2. Absolute and relative errors
are both retained; no denominator floor or acceptance threshold is added.

Native precipitation masks and known numerical/compiler differences are
retained. In particular, MATLAB masks prognostic precipitation sinks in
the top eleven levels, while Fortran applies its sink over all levels.
No experiment here isolates the cause of the later drift, certifies
phase-boundary equivalence, or closes a conservation budget. Successful
execution is not a scientific-equivalence decision. Review these curves
and error measurements before freezing a long-run acceptance criterion.

## Reproduce and retained evidence

```bash
python3 tests/alignment/run_sounding_case.py migration_work/manus_multi_repeat \
  --input data/input/manus208.nc --mode multi --precipitation --duration 43200
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_repeat
python3 tests/alignment/plot_multi_mf.py migration_work/manus_multi_repeat --layout comparison
```

Use a fresh output directory and MATLAB with writable preferences. On this
host, plotting uses `PYTHONPATH=/tmp/ace-mf-plot-deps` and
`MPLCONFIGDIR=/tmp/ace-mf-matplotlib`. The single-ACE runner defaults remain
available; multiACE mode explicitly enables all tendencies, places the
pulse in ACE 8 and exports a common seed even without a thermal bubble.

Raw evidence is preserved under ignored
`migration_work/manus208_multi_outer_pulse_12h/`: generated model sources
and diffs, original executed runner, builds, commands, logs, full eight-ACE
prognostic histories, common initial seed, precipitation observations,
`mf_all_aces.npz` (time, level, ACE), and supplementary diagnostics.
Full-output hashes and initial-state identity were independently verified
after completion. The initial sandbox attempt was stopped by MATLAB's
unwritable preferences directory; it is preserved separately under
`migration_work/manus208_multi_outer_pulse_12h_sandbox/`. The completed fresh
run used authorized execution outside the sandbox.

Recommended next direction: review the late inner-ACE evolution and
cross-implementation drift before fixing this twelve-hour multiACE case
as a release comparison baseline.

</details>

<a id="record-manus208-single-saturated-bubble-3h"></a>

<details>
<summary>docs/manus208_single_saturated_bubble_3h.md</summary>

# Manus 208: three-hour single ACE with a saturated 1 K bubble

**Canonical reference case:** designated by the developer on 2026-10-02
for initial v0.18, v0.20 and v0.24 runtime comparisons. See
[test instructions](../../tests/README.md) and the
[fixed case definition](../../tests/cases/manus_saturated_bubble.json).

This experiment replaces GOAmazon 314 with Manus 208 while retaining the
[bubble-enabled experiment settings](#record-goamazon314-single-saturated-bubble-3h).
GOAmazon outputs remain preserved. Byte equality is not an acceptance goal.

An additional [native-precipitation case](#record-manus208-single-saturated-bubble-precip-3h)
completed the same three-hour experiment on 2026-10-02 and is available as
`manus_saturated_bubble_precip`. This original case retains precipitation disabled.

## Completed results (2026-10-02)

Both implementations completed 10800 s with finite prognostic output and
181 saved snapshots. Saved total-water values remain nonnegative.
The common initial bubble state, output time/height mapping, and source/input/
artifact hashes were checked. No production source was modified.

ACE 1 MF ranges from -0.149537 to 15.247966 kg m-2 s-1 in both runs.
Maximum absolute MF difference is **6.448175e-13 kg m-2 s-1**, at
179 minutes and 15.15 km. RMS difference is 7.502137e-14 kg m-2 s-1;
relative L2 difference is 1.357981e-14. These are descriptive measurements,
not a byte-equality or physical-validation acceptance criterion.

## Configuration

- Input: `data/input/manus208.nc`, Manus profile 208 (`arm=1`).
- ACE 1 thermal bubble: levels 11–51, inclusive; +1 K; saturated;
  no explicitly added initial condensate.
- Initialization uses the existing MATLAB `T_zm`/`p_mf` convention,
  with bubble heights 500–2500 m. The full initialized theta_e/qt/MF state
  is exported for Fortran to start from the same experimental input.
- Three hours (10800 s), dt=4 s, SSPRK93, 60 s output, 181 snapshots.
- Single-ACE tendency mask: ACE 1 active, eight-ACE geometry/PMB retained.
- Original ACE 1 MF pulse: 0.03*sin(pi*z/1000) kg m-2 s-1 at 0–1000 m.
- Precipitation calls/updates explicitly disabled in temporary sources.
  Thermodynamic condensation and condensate buoyancy remain active.
- MF diffusion disabled; original damping retained.
- MATLAB R2023b Update 9 and GNU Fortran 11.2.0, using the same compiler
  flags and test entry points as the preceding experiment.

The initialization check verifies 41 saturated bubble layers, the Manus
temperature/pressure inputs, and unchanged thermodynamics outside the
bubble and in ACEs 2–8. Production and historical sources are unchanged.

## Reproduce and artifacts

Use a fresh directory and writable MATLAB preferences:

```bash
python3 tests/alignment/run_reference_case.py migration_work/manus208_bubble_repeat
python3 tests/alignment/plot_mf.py migration_work/manus208_bubble_repeat
```

Raw evidence is retained under ignored
`migration_work/manus208_single_saturated_bubble_3h/`: source/input/artifact
hashes, command arguments, initialization check, generated drivers and
patches, model logs, full prognostic outputs, and `mf.npz`.
Plots are `mf_three_panels.png` and `.pdf`, showing MATLAB, Fortran,
and Fortran-minus-MATLAB from top to bottom. The top two panels share a
color scale; the difference uses its own symmetric scale. Full 0–40 km
MF is retained, while the plot shows 0–20 km.

On this host the Python plotting dependencies are installed under `/tmp`:

```bash
PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib \
  python3 tests/alignment/plot_mf.py migration_work/manus208_single_saturated_bubble_3h
```

</details>

<a id="record-manus208-single-saturated-bubble-precip-3h"></a>

<details>
<summary>docs/manus208_single_saturated_bubble_precip_3h.md</summary>

# Manus 208: three-hour saturated bubble with native precipitation

Developer acceptance on 2026-10-02: this case and the twelve-hour multiACE
case are sufficient for the v0.18 milestone, with the documented limitations
retained. See the [release decision](../releases/v0.18.0.md). Original evidence
paths/hashes are preserved across source-root normalization.

Executed on 2026-10-02 at source commit `2a58571`. This adds precipitation
to the [existing Manus reference](#record-manus208-single-saturated-bubble-3h).
Production and historical model sources were unchanged. The new
[fixed test definition](../../tests/cases/manus_saturated_bubble_precip.json)
is an additional case; the original no-precipitation case remains the default.

## Completed execution checks

Both implementations completed 10800 s with 181 saved snapshots. All saved
prognostic fields are finite and total water is positive (minimum about
2.583503e-6 kg/kg). Initial theta_e, qt and MF agree exactly between the
implementations; the common seed is byte-identical to the original
no-precipitation reference. The canonical verifier also checks the bubble
layers, saturation evidence, unchanged thermodynamics outside the bubble,
input/reference hashes and output coordinates.

The native precipitation scheme acts in both implementations. MATLAB's
saved qt-removal accumulation starts at zero, is finite and monotonic, and
has a final maximum of 0.1580208671 kg/kg. Fortran's observed qt sinks are
finite and nonnegative, with positive removal in all 2700 steps. Unweighted
removal sums are 33.94502081350 (MATLAB) and 33.94502081377 (Fortran) kg/kg
over stored levels and ACEs. These sums and accumulated mixing ratios are
sink diagnostics, not precipitation depth, a physical domain-water budget,
or the entire change in qt. Transport and damping also affect qt.

Maximum absolute differences over the full saved histories:

| Quantity | Maximum absolute difference |
| --- | ---: |
| theta_e | 7.914900e-8 K |
| qt | 1.363884e-11 kg/kg |
| ACE 1 MF | 3.802017e-9 kg m-2 s-1 |

MF RMS difference is 3.764049e-10 kg m-2 s-1 and relative L2 difference is
6.170948e-11. The maximum MF difference occurs at 52 minutes and 12.8 km.
ACE 1 MF ranges from approximately -0.119728 to 16.046093 kg m-2 s-1.
Enabling precipitation changes MF by up to 12.88036 kg m-2 s-1 relative to
the no-precipitation run in each implementation; it materially changes
this experiment's evolution.

The case passes execution and precipitation-activity checks. No numerical
acceptance tolerance, scientific-equivalence decision or conservation pass
is inferred from these measurements.

## Fixed configuration and scientific scope

Retain Manus 208 (`data/input/manus208.nc`, `arm=1`), ACE 1's saturated +1 K
bubble at levels 11–51 (500–2500 m), no explicitly added initial condensate,
the common MATLAB-exported theta_e/qt/MF seed, original MF pulse,
eight-ACE geometry/full PMB, dt=4 s, SSPRK93, 60 s output, dz=50 m,
MF diffusion disabled and original damping.

Both implementations apply their existing smooth precipitation sink after
all nine dynamics stages, using the stage-1 thermodynamic cache, then clamp
qt and apply damping. No equations, constants or inversion rules change.
Native precipitation masks are retained: MATLAB masks prognostic sinks in
the top eleven levels and all precipitation slots in ACEs 2–8; Fortran's
sink is applied to all levels and ACEs. The Fortran single-ACE mask controls
dynamics. The known masks are not unified by this test.

MATLAB R2023b Update 9 and GNU Fortran 11.2.0 produce binary64 outputs.
Fortran flags are `-O2 -ffree-form -fdefault-real-8 -fdefault-double-8
-ffree-line-length-none`. Intel/GNU equivalence, complete physical
validation, water-budget closure and later-version adapters remain untested.

## Reproduce and evidence

```bash
python3 tests/alignment/run_reference_case.py --case manus_saturated_bubble_precip --check-only
python3 tests/alignment/run_reference_case.py migration_work/manus_precip_repeat --case manus_saturated_bubble_precip
python3 tests/alignment/plot_mf.py migration_work/manus_precip_repeat
```

Use a fresh directory and MATLAB with writable preferences. On this host,
plotting uses `PYTHONPATH=/tmp/ace-mf-plot-deps` and
`MPLCONFIGDIR=/tmp/ace-mf-matplotlib`. The
[PNG](../figures/manus_saturated_bubble_precip_mf.png) and
[PDF](../figures/manus_saturated_bubble_precip_mf.pdf) show MATLAB, Fortran and
Fortran-minus-MATLAB MF at 0–20 km; full 0–40 km arrays are archived.

[Reference evidence](../../tests/reference/manus_saturated_bubble_precip)
contains MF arrays, common seed, bubble validation, precipitation diagnostics
and [results/source/artifact hashes](../../tests/reference/manus_saturated_bubble_precip/results.json).
Raw histories, generated sources, builds, logs and commands remain under
ignored `migration_work/manus208_single_saturated_bubble_precip_review/`.
The generated Fortran module only adds a read-only sink diagnostic write
after the native sink call; `fort.97` stores time and per-step qt-removal
sum/max/min. MATLAB retains its native accumulation slots in netCDF.
The executed runner is preserved as `runner_executed.py`; final report
analysis adds full prognostic metrics without rerunning integration.
The original patch filenames `fortran_no_precip.diff` and
`matlab_no_precip.diff` in this run are legacy labels; their contents record
enabled native precipitation with diagnostic instrumentation. Future enabled
runs use `*_native_precip.diff` labels.

The initial sandbox attempt at
`migration_work/manus208_single_saturated_bubble_precip_3h/` stopped because
MATLAB's preferences directory was not writable. It is preserved; the
reported fresh run used authorized execution outside the sandbox.

Recommended next direction: use both fixed Manus cases when introducing
v0.20/v0.24 test adapters, keeping native physics differences explicit.

</details>

<a id="record-v020-khn26-constants-audit"></a>

<details>
<summary>docs/migration/v020_khn26_constants_audit.md</summary>

# KHN26 MATLAB / Fortran constants and formula audit

Reviewed 2026-10-07 alongside the authorized Ci correction. Scope is the active
shared-input KHN26 three-prognostic-variable dynamics and native precipitation
path, not the Fortran-only P3 scheme, historical snapshots, or disabled MF
diffusion/PMDv/PMD operators. A matching source expression is not by itself a
proof of scientific equivalence over all states.

## Production change

Only the reference temperature inside Fortran `Ci(T)` changes from
273.1636783445389 to 273.15 K, with an explanatory comment. This matches
MATLAB `ci.m` and Fortran's existing inverse ice coefficient
`dC = 2083.900148084866`. The triple point used for phase selection remains
273.1636783445389 K. Changing every occurrence of a similar temperature would
be incorrect: the heat-capacity fit reference and phase-selection temperature
have different roles.

## Constants reviewed

Sources: `matlab/util_thermodynamics/IMPORT_CONSTANTS_NOGLOBAL.m`, the active
thermodynamic helper functions, `matlab/ace.m`, `fortran/src/ace_module.F`, and
`fortran/src/test.F`.

| Quantity | MATLAB and Fortran values / relationship | Finding |
| --- | --- | --- |
| Dry / vapor gas constants | 287.04 / 461.5 J/(kg K) | Match |
| Dry Cp / Cv | 1005.7 / 719 J/(kg K) | Match |
| Vapor Cp / Cv | 1870 / 1410 J/(kg K) | Match |
| Liquid heat capacity | 4190 J/(kg K) | Match |
| Liquid minus vapor Cp | 2320 J/(kg K) | Match |
| Liquid minus dry Cp | 3184.3 J/(kg K) | Match |
| Lv at 273.15 K | 2.501e6 J/kg | Match |
| Ls / Lf declarations | 2.834e6 / 0.3337e6 J/kg | Match; Ls is not directly used by this forward theta_e formula |
| Reference pressure | 1e5 Pa | Match |
| Phase-selection triple point | 273.1636783445389 K | Match |
| Lv fit reference | 273.15 K | Match |
| Ci slope / intercept | 7.3 / 2106 | Match |
| Ci fit reference | 273.15 K after correction | Confirmed former mismatch, now corrected |
| Gravity | 9.80665 m/s² | Match |
| Newton temperature tolerance | 1e-3 K | Match |
| Saturation at triple point | 611.3902114165171 Pa | Match in inverse expressions |
| Lv(T0)/T0 | 9155.566660243245 | Match in inverse declarations; some branches recompute it |
| Lv(T0) | 2500968.266240670 J/kg | MATLAB literal matches Fortran Lv(T0) |
| Lf/T0 | 1221.611899584641 | MATLAB literal matches Fortran expression |
| Liquid inverse derivative coefficient | 1867292 = 2.501e6 - 2320*273.15 | Match |
| Ice inverse heat-capacity difference | 2083.900148084866 | Match |
| Unsaturated ice Newton derivative coefficient | 300708, with minus sign | Match |
| Tetens initial-guess temperatures | Liquid 273.15; ice 273.16 K | Match; these are distinct from the phase triple point |
| Tetens initial-guess offset | 5.939876353793538 | Match |
| Precipitation qc ramp / smoothness / time scale | 0.5e-3 kg/kg / 20 / 300 s | Match |
| Condensate derivative perturbation | 1e-8 kg/kg | Match; cancellation still affects floating-point results |
| Turbulent entrainment nju | 0.09 | Match with geometry unit conversion |
| Sponge depth / time scale | 6000 m / 180 s | Match |
| Active WENO k / weight power / epsilon | 2 / 2 / 1e-10 | Match |
| Active SSPRK stages and divisors | 9 stages, 6 and 15 | Match |

## Formula review and remaining implementation differences

- Liquid saturation pressure uses coefficients 53.67957, 6743.769 and
  -4.8451; ice uses 23.33086, 6111.72784 and +0.15215. The mathematical
  pressure formulas and their temperature derivatives match.
- Saturation specific humidity uses EPS*e*(1-qt)/(p-e) in both languages.
  The condensate-free initialization converts this mixing-ratio expression
  to specific humidity in both drivers.
- Forward theta_e has the same vapor, pressure, latent-heat and ice factors
  after Ci correction. Fixed T/q/ql/qi comparison now has maximum forward
  theta_e error 2.27374e-13 K across 19,248 sampled states, compared with
  3.20455e-6 K before correction.
- MATLAB's precomputed EPS is 0.621971830985916; Fortran also computes
  Rd/Rv = 0.6219718309859156 in parts of theta_e/inversion. The virtual
  temperature coefficient is identically hardcoded as 0.607789855072462
  in the active dynamics. The dry theta exponent is a MATLAB literal
  0.285413145073083 versus Fortran Rd/Cp. These differences are confined
  to final decimal/binary rounding; they were documented, not changed.
- Native qt sink uses direct log(1+exp(ramp)) in MATLAB and a mathematically
  equivalent overflow-resistant expression in Fortran. The fixed-thermo
  maximum qt sink difference is 1.05879e-22 kg/kg/s after the Ci correction.
- Native theta_e sink still uses finite differences in both languages.
  Fixed-thermo maximum difference after the actual Ci correction is
  1.57906e-10 K/s, versus 8.59693e-9 K/s before correction. No derivative
  scheme or regression limit was changed.
- MATLAB inverse computations use complex numbers, imaginary/NaN guards,
  and strip imaginary parts at the local wrapper; Fortran uses real numbers
  and different exceptional-state handling. This is an existing behavior
  difference. On the sampled states, inversion maximum temperature difference
  is 1.13687e-13 K, and vapor/liquid differences are 1.64799e-16 kg/kg.
- Virtual temperature groups `ql+qi` in MATLAB, versus subtracting ql and qi
  separately in Fortran. Buoyancy and damping group products/divisions
  differently. These expressions are mathematically equivalent but can round
  differently.
- MATLAB geometry uses km²/km internally; Fortran uses m²/m. The apparent
  MATLAB nju/1000 versus Fortran nju coefficient matches after Bi/Ai unit
  conversion, so no entrainment coefficient was altered.
- MATLAB WENO uses decimal 2/3 and 1/3 literals; Fortran forms the fractions.
  The active k=2 weights, stencil coefficients and regularization match
  mathematically. Unused scalar WENO helpers are not the dynamics call path.
- Both apply native precipitation after SSPRK and before implicit damping.
  qt clipping and mean MF removal are ordered differently but affect distinct
  fields for finite states. Stage buoyancy is fixed from the beginning of
  each step in both implementations.

No further systematic mismatch comparable to Ci was identified in this
reviewed path. This does not assert equivalence for untested exceptional
states, disabled operators or P3.

## Completed validation

The [preserved validation summary](../../tests/khn26/ci_correction_validation.json)
records before/after common-state results, raw artifact hashes, the corrected
production-source hash, and unchanged ten-minute regression limits/results.
Before preparing this commit, all common-state artifact hashes were checked,
and the corrected common-state and single/multi short-test configurations were
verified to reference the current `fortran/src/ace_module.F` hash. Gate report
configuration hashes were also verified. No model simulation was rerun.

Across 19,248 byte-identical common samples, fixed-thermodynamic forward
theta_e maximum difference decreased from 3.20455e-6 to 2.27374e-13 K.
The native theta_e sink difference decreased from 8.59693e-9 to
1.57906e-10 K/s; the derivative scheme was unchanged.

Corrected native singleACE and dry/native multiACE ten-minute tests all passed
their original state, SSPRK tendency and precipitation regression limits.
Each language used 32 computational/OpenMP threads, and checked/production
Fortran ten-step exports were byte-identical. Native singleACE maximum state
errors (MF, theta_e, qt) were (2.71477e-10, 3.27663e-9, 1.47139e-13);
native multiACE values were (1.21188e-10, 1.95786e-9, 1.23635e-13).

The workspaces remain `migration_work/khn26_common_precip32_ci`,
`migration_work/khn26_single32_native_ci_3h`, and
`migration_work/khn26_multi32_bubble_ci_12h`. These local simulation artifacts
are not included in this source-fix commit. The later long-run thread/order
changes are separate experiments, not prerequisites for the correction.
See the [three-hour multiACE comparison](#record-v020-khn26-multiace-three-hour-comparison)
for its final scope and numerical/physical interpretation limits.

</details>

<a id="record-v020-khn26-matlab-alignment-ten-minute-gates"></a>

<details>
<summary>docs/migration/v020_khn26_matlab_alignment_ten_minute_gates.md</summary>

# KHN26 MATLAB-aligned Fortran: fresh ten-minute multiACE gates

Both dry and native-precipitation gates passed after the thermodynamics
alignment in `b1010ea`. Each integrates 150 dt=4 s steps, saving all 151
states and comparing all nine SSPRK tendencies per step. The slab geometry,
101 ACEs, +1 K ACE-1 bubble (scalar levels 11–51), zero initial MF and shared
input profile match the preceding multiACE tests.

`tests/khn26/gate_matlab_default.py` is a gate-only entry point using the
existing numerical gate criteria. Execution was in the background. MATLAB
had no imposed thread controls or CPU binding and reported 80 computational
threads at both start and finish. Fortran used 32 OpenMP threads with the
existing CPU placement. The two programs ran concurrently within each gate;
the checked Fortran ten-step run preceded its production run. The dry gate
preceded the native gate. There was no long simulation or efficiency study.

## Results

Maximum absolute errors over every saved cell and time:

| State | No precipitation | Native precipitation | Existing limit |
| --- | ---: | ---: | ---: |
| MF, kg m−2 s−1 | 8.97060e−14 | 1.63794e−10 | 1e−9 |
| theta_e, K | 2.27374e−12 | 2.13765e−9 | 1e−7 |
| qt, kg kg−1 | 1.28370e−16 | 1.60804e−13 | 1e−11 |

| Tendency | No precipitation | Native precipitation | Existing limit |
| --- | ---: | ---: | ---: |
| MF, kg m−2 s−2 | 1.01050e−15 | 1.89319e−12 | 1e−9 |
| theta_e, K s−1 | 2.88910e−14 | 1.59720e−10 | 1e−8 |
| qt, kg kg−1 s−1 | 1.78809e−18 | 4.27456e−15 | 1e−11 |

All saved states and native sinks were finite, saved qt was nonnegative,
and native water sinks were nonpositive. Native precipitation was exercised
with nonzero removal. Across all 150 post-SSPRK sink frames, maximum errors
were 1.70526e−10 K s−1 for theta_e and 1.39720e−15 kg kg−1 s−1 for qt,
below the existing limits of 1e−7 and 1e−11 respectively.

Area-averaged, vertically and temporally integrated native water removal
was 0.02760122572581196 kg m−2 (MATLAB) and 0.02760122572560357 kg m−2
(Fortran), using the physical first 400 scalar levels. This is diagnostic
water removal, not transported surface precipitation or a closed water budget.

For each gate, the checked Fortran build used array checks and traps for
invalid operations, division by zero and overflow. Its first ten steps of
states/tendencies (and native sinks where enabled) were byte-identical to the
production build. Both production drivers exited normally. Source/input
hashes and the gate configuration hash were verified at completion.

These are ten-minute numerical regression results. They do not establish
three-hour agreement or identify the cause of the earlier accumulated
boundary-region drift. The precipitation finite-difference sensitivity
identified in the common-state probes remains present.

## Where the largest differences occur

`tests/khn26/locate_gate_differences.py` verifies the completed gate's source
and binary hashes, then locates the maxima in saved states, SSPRK tendencies
and native sink frames. Every located maximum reproduces the original gate
report exactly. Heights use `zm` for MF interfaces and `z` for scalar centers.
If maxima tie, the first occurrence in the scan is reported.

| State / case | Maximum absolute difference | Time | ACE | Height |
| --- | ---: | ---: | ---: | ---: |
| MF, dry | 8.97060e−14 | 600 s | 1 | 3.20 km |
| theta_e, dry | 2.27374e−12 K | 520 s | 78 | 22.55 km |
| qt, dry | 1.28370e−16 | 600 s | 1 | 3.75 km |
| MF, native | 1.63794e−10 | 600 s | 1 | 2.90 km |
| theta_e, native | 2.13765e−9 K | 464 s | 1 | 2.95 km |
| qt, native | 1.60804e−13 | 600 s | 1 | 3.55 km |

All native state maxima are in the bubble column, ACE 1. The global dry
theta_e maximum is above the 0–20 km plotting range and is much smaller
than the native maximum.

For native physics, largest MF tendency discrepancy occurs in step 147,
stage 1 (584–588 s), ACE 1 at 3.40 km. The theta_e tendency maximum is in
step 134, stage 1 (532–536 s), ACE 1 at 5.35 km. The qt tendency maximum
is in step 140, stage 1 (556–560 s), ACE 1 at 3.45 km. These tendencies
are dynamics evaluations on the independently evolved states; precipitation
is applied after SSPRK, so they are not direct precipitation tendencies.

The largest native theta_e sink discrepancy, 1.70526e−10 K s−1, occurs
after SSPRK in step 146 (580–584 s), ACE 1 at 5.65 km. MATLAB's sink is
0.005436260278663257 K s−1 and Fortran's is 0.005436260108137466 K s−1.
The largest qt sink discrepancy, 1.39720e−15 kg kg−1 s−1, occurs in step 117
(464–468 s), ACE 1 at 2.95 km. A step interval locates the calculation in
the split update; it is not an assigned physical time for an SSPRK stage.

Across all ten minutes, ACE 101 state maxima are only 1.90835e−14 (MF),
1.36424e−12 K (theta_e), and 2.77556e−17 (qt) in the native case.
For ACEs 98–101 collectively they are 1.90835e−14, 1.76215e−12 K,
and 2.77556e−17 respectively. Thus the dominant ten-minute discrepancy
is not concentrated at the right boundary.

The larger native-versus-dry discrepancies and the ACE-1 sink location are
consistent with the previously demonstrated precipitation roundoff sensitivity.
These observations do not isolate how much is newly introduced in step 146
versus inherited from earlier independent trajectories. A common-state
replay around that step is the next targeted causal check.

Reproduce the location analysis without running the model:

```sh
python3 tests/khn26/locate_gate_differences.py migration_work/khn26_multi_matlab_alignment_10min
```

The runtime `maximum_difference_locations.json` and the `difference_locations`
section in `tests/khn26/matlab_alignment_gate_results.json` preserve exact
signed values, positions, per-ACE maxima and the analysis source hash.

The subsequent [local error-source controls](#record-v020-khn26-ten-minute-error-sources)
separate inherited-state differences from newly introduced differences and
demonstrate upstream roundoff amplification in the precipitation update.

## Reproduction and evidence

Prepare a new, nonexistent workspace and launch the gate-only supervisor:

```sh
python3 tests/khn26/gate_matlab_default.py migration_work/khn26_multi_matlab_alignment_10min --prepare
python3 tests/khn26/gate_matlab_default.py migration_work/khn26_multi_matlab_alignment_10min --launch
```

The completed runtime workspace is
`migration_work/khn26_multi_matlab_alignment_10min`. It contains raw states,
tendencies, precipitation sinks, logs, checked/production executables,
configuration hashes, gate results and comparison PNG/PDF figures for each
gate. Final status is `gates_passed` with `full_started: false`.

`tests/khn26/matlab_alignment_gate_results.json` preserves the source/build
configuration, gate decisions, state/tendency summaries, native sink results,
driver exits, thread-policy evidence and artifact hashes for review.

</details>

<a id="record-v020-khn26-multiace-difference-attribution"></a>

<details>
<summary>docs/migration/v020_khn26_multiace_difference_attribution.md</summary>

# KHN26 multiACE: location and single-step difference attribution

The results below precede the subsequent Fortran literal/arithmetic alignment.
For that authorized source change and fresh short-test results, see
[thermodynamics MATLAB alignment](#record-v020-khn26-thermodynamics-matlab-alignment).

The three-hour saved-state maxima are:

| Field | Maximum absolute difference | Time | ACE | Height |
| --- | ---: | ---: | ---: | ---: |
| MF | 6.0735474051e−6 kg m−2 s−1 | 158 min | 99 | 5.8 km, MF interface |
| theta_e | 5.5267481230e−5 K | 155 min | 98 | 6.25 km, scalar center |
| qt | 2.1667431026e−8 kg kg−1 | 155 min | 98 | 6.25 km, scalar center |

These locate the accumulated differences; they do not identify a source term.
The largest differences are near the right boundary, but not at ACE 101.

## Saved-state replay

`tests/khn26/replay_multi.py` prepares isolated MATLAB/Fortran probes using
the current production routines. States from each language at minutes 90,
120, 155, 158 and 180 are replayed for one dt=4 s step (ten common seeds).
Each seed is read from the same binary input by both implementations.
The shared reference Tv is exported from MATLAB to exclude the tiny
environment-inversion difference. Both use the original shared PMB and
slab geometry, all-ACE dynamics, native precipitation and original damping.
There is no new multi-hour trajectory or production source edit.

The probes observe vertical tracer fluxes, UP3 mfc/wc, horizontal flow,
local MF forcing, raw/mean-adjusted buoyancy, total first-stage tendencies,
and states after SSPRK, precipitation and damping. MATLAB area-weighted
flux diagnostics are converted from km² to m² in postprocessing; raw
output bytes are preserved. Generated sources, compilation commands,
source hashes and outputs are in
`migration_work/khn26_multi_boundary_common_state`.
The initial preparation attempt in `migration_work/khn26_multi_boundary_replay`
is preserved separately; it failed before generating/running the probes.

## Findings on identical seeds

Across the ten sampled states:

| Quantity / stage | Maximum implementation difference |
| --- | ---: |
| UP3 reconstructed mfc and wc | Exactly zero in exported values |
| Local MF forcing | 1.38778e−17 in native forcing units |
| MF first-stage tendency | 3.17346e−16 kg m−2 s−2 |
| MF first-stage tendency in ACEs 98–101 | At most 1.68369e−16 kg m−2 s−2 |
| MF after SSPRK | 1.77636e−15 kg m−2 s−1 |
| theta_e after SSPRK | 2.27374e−13 K |
| theta_e after native precipitation | 5.04258e−10 K |
| qt after SSPRK / precipitation | 3.46945e−18 kg kg−1 |

The largest new theta_e discrepancy is in the native precipitation update,
at ACE 1, scalar level 82 (8.15 km), for the minute-180 MATLAB seed.
Its corresponding SSPRK discrepancy is about three orders smaller.
After precipitation, damping changes this maximum only to 5.04144e−10 K.
It is not a newly created large right-boundary flux discrepancy.

This identifies the **update stage**, not a unique mathematical expression:
the update includes thermodynamic inversion and the native finite-difference
theta_e sink. The previously completed common-thermodynamic-state checks
show finite-difference sink evaluation differences at a compatible scale;
that is supporting evidence, not proof that all three-hour drift is seeded
by this expression alone.

## Accumulated input difference versus current implementation difference

For each timestamp, compare MATLAB(MATLAB seed), Fortran(MATLAB seed) and
Fortran(Fortran seed). This separates the current implementation effect
from propagation of the existing saved-state mismatch using one common
reference environment. The difference fields add pointwise; their separate
maxima are descriptive norms and need not occur at the same cell.

For the minute-158 state, after one full step:

| Field | Same seed, different implementations | Different seeds, same Fortran implementation |
| --- | ---: | ---: |
| MF | 1.77636e−15 | 6.08393e−6 |
| theta_e | 4.11262e−10 | 4.98654e−5 |
| qt | 3.46945e−18 | 1.95272e−8 |

At these sampled late times, the large boundary-region differences are
overwhelmingly carried by the already diverged input trajectories, rather
than regenerated by a mismatched boundary calculation on the same seed.
This supports reviewing small discrepancy accumulation/amplification.
It does not establish the first divergent timestep, a unique initial cause,
or an independent stability/dispersion analysis. Native-physics-off controls
and a longer controlled replay would be needed for causal attribution of
the full history; no boundary algorithm or precision was changed here.

The structured evidence is in `results.json` in the replay workspace, including
component maxima/locations, input-difference decomposition and output hashes.

## Thermodynamic inversion and precipitation finite-difference isolation

`tests/khn26/probe_replay_precip.py` extracts 12,180 post-SSPRK states from
the ten replays, using both implementations' SSPRK outputs. It includes all
401 levels of ACE 1 and scalar levels 50–101 of ACEs 98–101. The existing
common-state precipitation probe now accepts supplied samples while retaining
its original sampling as the default. Both short probes use 32 threads;
this is not an efficiency test or a new trajectory.

For every sample, MATLAB and Fortran read byte-identical theta_e/qt/pressure.
Fortran additionally evaluates the unchanged forward thermodynamics and
precipitation routines on the exact MATLAB T/q/ql/qi values. This separates
the effect of inversion outputs from forward-function implementation effects.
All outputs are finite. Production model sources and formulas are unchanged.

At the original largest replay discrepancy (minute-180 MATLAB seed, ACE 1,
scalar level 82, 8.15 km), the pre-precipitation theta_e and qt are exactly
equal in the two replays. Under identical theta_e/qt/pressure inputs:

| Quantity | Fortran minus MATLAB |
| --- | ---: |
| Inverted temperature | −5.68434e−14 K |
| Inverted vapor q | approximately −1.69e−17 kg kg−1 |
| Forward theta_e before condensate perturbation | −2.27374e−13 K |
| Forward theta_e after condensate perturbation | −1.13687e−13 K |
| Finite-difference condensate derivative | +1.13687e−5 |
| theta_e precipitation tendency | −1.26067e−10 K s−1 |
| theta_e after the 4 s update | −5.04258e−10 K |

The unequal rounding in the two forward evaluations is divided by the shared
1e−8 condensate perturbation. Its derivative difference, multiplied by the
precipitation sink, explains the tendency difference. Reconstructing the
4 s updates reproduces the actual replay difference exactly, including the
rounding when adding the tendencies to the state. When T/q/ql/qi are fixed
to identical MATLAB values, the forward calculations, derivative and sinks
at this particular point are exactly equal. Thus the local discrepancy is
seeded by tiny inversion-output differences and amplified by the unchanged
finite-difference precipitation update; it is not evidence of a different
physical constant or boundary condition.

This behavior is state-dependent. At ACE 1, 6.65 km, minute-180 Fortran seed
using the MATLAB SSPRK output, inversion outputs are exactly equal while
the two forward calculations differ by +1.13687e−13 and −5.68434e−14 K.
The resulting derivative difference is −1.70530e−5 and sink difference is
+1.36887e−10 K s−1 even with identical T/q/ql/qi. Both inversion roundoff
and forward-evaluation roundoff can therefore feed the same cancellation
sensitivity. Across all selected samples, maximum independent-inversion
sink difference is 1.39942e−10 K s−1; fixed-thermodynamic-state maximum is
1.36887e−10 K s−1.

The local cause is confirmed for the sampled discrepancy; the source of
the full three-hour accumulated boundary-region drift remains unproven.
Changing perturbation size or replacing the derivative would affect the
numerical method and requires a separately reviewed scientific change.

Reproducible preparation and execution:

```sh
python3 tests/khn26/probe_replay_precip.py migration_work/khn26_multi_replay_precip --prepare
python3 tests/khn26/probe_replay_precip.py migration_work/khn26_multi_replay_precip --run
```

Preparation requires the completed replay workspace and creates a new output
directory. The runtime binaries remain in `migration_work/khn26_multi_replay_precip`.
`tests/khn26/replay_precipitation_results.json` preserves the structured results,
exact update reconstruction, source/build/input hashes and diagnostic log hashes.

</details>

<a id="record-v020-khn26-multiace-gravity-wave"></a>

<details>
<summary>docs/migration/v020_khn26_multiace_gravity_wave.md</summary>

# KHN26 multiACE bubble: paired 32-thread experiment

## Final status

The native multiACE comparison was completed for **three hours**, following
the developer's shortened target. MATLAB used its unrestricted platform
default and Fortran used 32 threads. Both processes were intentionally stopped
and all outputs preserved; no twelve-hour trajectory was completed.
See the [final comparison](#record-v020-khn26-multiace-three-hour-comparison)
for results, and the [current workflow](../../tests/khn26/README.md#native-precipitation-and-three-hour-wave-comparison)
and [script index](../../tests/khn26/scripts.md) for reproducible commands.

The sections below preserve the original setup and successive authorizations.
Their twelve-hour targets and runtime paths describe experiment history;
they are not an active queue or the final comparison scope.

Requested on 2026-10-07: investigate spatial/gravity-wave response in the
current KHN26 geometry, check ten-minute tendencies, test precipitation,
then launch twelve hours **with native precipitation**, in the background.
The developer selected zero initial MF, so the bubble is the only initial
perturbation. This is a new case, not a continuation of the masked singleACE
trajectory or the v0.18 eight-ACE outer-pulse experiment.

## Configuration

- Shared `data/input/manaus1342_khn26.nc`, Manaus profile 1342.
- Full KHN26 101-ACE slab PMB: 5 km internal widths, 2.5 km at both
  endpoints, 500 km total width. Fine vertical spacing 100 m, 401 MF levels.
- Saturated +1 K bubble in ACE 1, one-based scalar levels 11..51;
  all initial MF exactly zero. Every ACE's dynamics tendency evolves.
- SSPRK93, dt=4 s, area-mean MF correction and original damping retained.
- PMDv/PMD remain disabled placeholders; MF diffusion remains disabled.
- Two fresh ten-minute gates: physics `none`, then physics `native`.
- A fresh twelve-hour trajectory uses native precipitation and saves every
  minute, yielding 721 states if completed. The gates save each 4 s step,
  yielding 151 states and 1350 full-domain SSPRK tendency arrays each.

Production MATLAB/Fortran equations and active source files are unchanged.
The preparer modifies isolated driver copies for duration, dt, bubble,
output paths, thread evidence and gate-only tendency/precipitation exports.
Generated diffs, commands and source/input/object/executable hashes are kept
with the experiment. Existing outputs are preserved by using fresh paths.

## Equal CPU budget

The host exposes 160 logical CPUs on 80 physical cores across four NUMA
nodes. Each language receives **32 distinct physical cores**, eight on each
NUMA node. The allocations do not share cores or SMT siblings:

| Language | CPU allocation |
| --- | --- |
| MATLAB | 0–7, 20–27, 40–47, 60–67 |
| Fortran | 8–15, 28–35, 48–55, 68–75 |

`taskset` establishes the process mask before allocation/first touch.
MATLAB sets and asserts `maxNumCompThreads(32)` before and after each run.
Fortran sets `OMP_NUM_THREADS=32`, disables dynamic teams/nested active
parallel regions, and asserts an actual 32-thread OpenMP team before model
initialization. Its explicit OpenMP places contain only the assigned CPUs.
BLAS thread caps are also 32. The supervisor verifies that the union of
all thread affinity masks stays inside each process's allocation. A bound
OpenMP main thread can legitimately have a one-CPU mask.

These are equal CPU allowances, not proof that every routine uses all 32
cores. MATLAB can have background threads. The host remains shared, and
this experiment does not measure isolated hardware performance.

## Gates before the long run

For each physics mode the background supervisor:

1. Starts MATLAB on its assigned cores and a checked Fortran ten-step
   prefix on the separate Fortran cores.
2. Requires the checked Fortran process to exit successfully, then runs
   the production Fortran ten-minute case on the same allocation.
3. Requires both ten-minute processes to exit with code 0. Checked and
   production Fortran initial/ten-step states and tendencies must be
   byte-identical; native precipitation sink prefixes must also match.
4. Compares every evolved prognostic state and all nine SSPRK tendencies
   at each step over all 101 ACEs. Checks finite states/tendencies,
   nonnegative saved qt, zero-initial-MF policy, poststep area-mean MF and
   nonzero response outside ACE 1.
5. For the native case, compares actual per-step theta_e/qt precipitation
   sinks, requires finite sinks, nonnegative water removal and at least
   one nonzero sink. Integrated removal uses reference density, 400 physical
   scalar levels and normalized ACE area. This is not transported surface
   rain or an independent closed water budget.
6. Verifies MATLAB computational caps, the Fortran team size and hashes.
   Only after **both gates** pass does it start the paired twelve-hour
   native-precipitation processes from the original initial conditions.

Fixed numerical regression gates, in MF/theta_e/qt order:

| Comparison | Maximum absolute error limits |
| --- | --- |
| Ten-minute states | `[1e-9, 1e-7, 1e-11]` in native units |
| Corresponding stage tendencies | `[1e-9, 1e-8, 1e-11]` in native units/s |
| Native theta_e/qt precipitation sinks | `[1e-7, 1e-11]` in native units/s |

State limits follow the existing KHN26 real64 comparison scale. Tendency
and sink limits are explicitly declared engineering regression gates,
not new scientific-equivalence criteria. Corresponding tendencies/sinks
come from independently evolving states; they do not force a common
binary seed or silently remove initialization roundoff differences.
The existing native theta_e finite-difference derivative is retained.

Any driver or numerical gate failure stops the paired process, preserves
artifacts and prevents long-run launch. After complete twelve-hour output,
the supervisor records descriptive errors without assuming the short-run
limits apply indefinitely. Each language's saved ten-minute long-run prefix
must reproduce its own native gate byte-for-byte.

## Background lifecycle and artifacts

Original runtime workspace:
`migration_work/khn26_multi32_bubble_native_12h/`.

```sh
python3 tests/khn26/multi.py migration_work/khn26_multi32_bubble_native_12h --prepare --initial-mf 0
python3 tests/khn26/multi.py migration_work/khn26_multi32_bubble_native_12h --launch
```

Use fresh paths, licensed MATLAB, GNU Fortran/netCDF-Fortran, NumPy and
netCDF4. The launcher detaches a supervisor with persistent file logs;
model processes are also detached and explicitly managed by that
supervisor. MATLAB requires a writable preferences directory and access
to its license server; this session uses approved execution outside the
sandbox. No commit or release is implied by launching.

- `supervisor.json`, `supervisor.log`, `status.json`: PIDs, heartbeat,
  state, exits, observed affinity unions and artifact progress.
- `configuration.json`, `cpu_topology.csv`, `executed_runner.py`:
  configuration, exact runner snapshot and provenance.
- `gate_none_*`, `gate_native_*`, `gate_passed.json`: numeric gate reports.
- `gate_native_precipitation_results.json`: actual sink comparisons/removal.
- `full_state_results.json`: complete long-run state comparison, prefix
  identity and thread evidence. Its absence is not a completed result.
- Each case directory preserves state streams, NetCDF/binary output,
  full-domain MF NPZ arrays and driver logs.

The initial workspace `migration_work/khn26_multi32_bubble_12h/` is retained
as a failed supervisor attempt. Its main-thread-only affinity check mistook
normal OpenMP binding for a changed allocation and terminated its partial
physics-off gate before native or long-run launch. The corrected runner
checks all-thread CPU unions and explicitly controls OpenMP places.
No failed partial stream certifies a ten-minute gate.

## Wave response plots and interpretation

After each completed comparison, `plot_multi.py` produces PNG/PDF spatial
MF panels at 1, 5 and 10 km, plus time-height panels for ACEs 1, 2, 10, 50
and 100. MATLAB/Fortran panels share a color scale, with separate difference
scales. Horizontal cell edges use the actual unequal slab widths. Plot
titles and axes use the actual completed time range.

```sh
python3 tests/khn26/plot_multi.py migration_work/khn26_multi32_bubble_native_12h --tag gate_native
python3 tests/khn26/plot_multi.py migration_work/khn26_multi32_bubble_native_12h --tag full
```

Plotting requires matplotlib; the supervisor uses the existing dependencies
at `/tmp/ace-mf-plot-deps` and writable `/tmp/ace-mf-matplotlib`. Plot errors
are recorded separately and do not discard completed numerical results.

Inspect spatial phase evolution and reflections using the slab coordinates.
The pressure response is nonlocal and area-mean MF correction can cause
immediate remote MF. Consequently, a first nonzero remote value alone is
not evidence of a finite-speed gravity-wave arrival. Full physical wave
interpretation, propagation-speed criteria and twelve-hour acceptance
remain developer review items after complete trajectories are available.

## Corrected gates and subsequent twelve-hour authorization

After correcting Fortran Ci's reference to 273.15 K, the fresh gates in
`migration_work/khn26_multi32_bubble_ci_12h` both passed unchanged limits.
The native ten-minute maximum state differences (MF, theta_e, qt) were
`(1.21188e-10, 1.95786e-9, 1.23635e-13)`; tendency differences were
`(1.22362e-12, 1.57495e-10, 3.08139e-15)`. Actual theta_e/qt sink differences
were `(2.21786e-10, 1.07249e-15)`.

The completed three-hour native singleACE default-MATLAB/32-thread-Fortran
run was plotted and reviewed before the user authorized multiACE twelve
hours. The latest workspace is
`migration_work/khn26_multi_matlab_default_fortran32_12h` and its runner is
`tests/khn26/unrestricted_multi.py`. MATLAB has no imposed computational
thread setting, OpenMP/BLAS environment cap, or taskset binding; Fortran
retains its 32-thread team and CPU allocation. Both programs launch together
in the background. CPU overlap is allowed under this user-selected policy;
efficiency observations are not part of this run.

The physical configuration is unchanged: +1 K bubble at ACE 1 levels 11–51,
zero initial MF, dt = 4 s, native precipitation, full 101-column KHN26 basis,
and output every 60 s to twelve hours (721 states). The changed-thread first
ten minutes are numerically checked against each program's own corrected
short gate; exact identity is recorded separately. Source, binary and gate
hashes are retained. Completion means saved-state comparison and descriptive
wave plots are available, followed by scientific interpretation; no long-run
acceptance tolerance is inferred from the short-test thresholds.

</details>

<a id="record-v020-khn26-multiace-three-hour-comparison"></a>

<details>
<summary>docs/migration/v020_khn26_multiace_three_hour_comparison.md</summary>

# KHN26 multiACE: three-hour MATLAB–Fortran comparison

The native precipitation, zero initial MF, +1 K bubble case was compared over
minutes 0–180 at one-minute saved intervals (181 states, all 101 columns and
401 MF interfaces). MATLAB used its unrestricted platform default (queried
80 computational threads); Fortran used 32 threads. No efficiency test was
performed. The original twelve-hour target was shortened by the developer.
Both processes were intentionally stopped; all raw outputs were preserved.
Fortran's longer stream was read only through the three-hour prefix.

Workspace: `migration_work/khn26_multi_matlab_default_fortran32_12h`.
Reproduce with `tests/khn26/compare_multi_prefix.py WORKSPACE`; plotting
dependencies must be available. Configuration and production source provenance
remain in the original workspace; the comparison changes neither model source
nor the original run configuration. Compared raw record hashes are stored in
`three_hour_state_results.json`.

| Field | Maximum absolute difference, all saved states | Relative L2 error |
| --- | ---: | ---: |
| MF (kg m−2 s−1) | 6.0735474051e−6 | 5.8738801320e−7 |
| theta_e (K) | 5.5267481230e−5 | 4.2004993869e−10 |
| qt (kg kg−1) | 2.1667431026e−8 | 2.8712274938e−8 |

The MF maximum is at minute 158, ACE 99, height 5.8 km, near the right
boundary. Differences grow after approximately minute 90. This location does
not establish a boundary-condition discrepancy or identify a cause.
Both implementations have their largest absolute MF at minute 17, ACE 1,
6.5 km: 8.260854635667144 (MATLAB), 8.260854635773516 (Fortran).
All saved values are finite and qt is nonnegative. Maximum absolute
area-mean MF is 2.62536e−17 and 2.22261e−17, respectively.

The 0–20 km MF fields at 20-minute intervals through minute 180 have pattern
correlation at least approximately 0.9999999999994. Visual inspection of the
snapshot panels and physical-distance/time diagrams at 1, 5 and 10 km shows
matching wave bands without a visible phase displacement at this resolution.
The requested snapshot figure has MATLAB left, Fortran right, eight rows
20–160 minutes, panel height:width 1:5 and color limits −1 to +1. All sixteen
panels are present, and their MF hashes were checked against the raw records.
Its horizontal coordinate is ACE index; the additional spatial diagrams use
actual unequal column widths over the 500 km domain.

## Versioned figures and reports

- [Paired MF snapshots, 20–160 minutes](../figures/khn26_multi_native_3h/mf_20min_snapshots.png)
  ([PDF](../figures/khn26_multi_native_3h/mf_20min_snapshots.pdf)): 0–20 km, color limits −1 to +1.
- [Spatial MF propagation](../figures/khn26_multi_native_3h/spatial_mf.png)
  ([PDF](../figures/khn26_multi_native_3h/spatial_mf.pdf)): physical-distance/time panels at 1, 5 and 10 km.
- [Selected ACE time-height comparison](../figures/khn26_multi_native_3h/selected_aces.png)
  ([PDF](../figures/khn26_multi_native_3h/selected_aces.pdf)).
- [Maximum state differences](../figures/khn26_multi_native_3h/state_errors.png)
  ([PDF](../figures/khn26_multi_native_3h/state_errors.pdf)).
- [Numerical report](../figures/khn26_multi_native_3h/state_results.json),
  [snapshot metadata](../figures/khn26_multi_native_3h/snapshot_results.json),
  [source configuration](../figures/khn26_multi_native_3h/source_configuration.json),
  and [artifact manifest](../figures/khn26_multi_native_3h/manifest.json).

These are byte-identical copies of the existing completed artifacts. Before
archiving, both raw 181-record prefix hashes and all 16 snapshot MF hashes
were verified. The manifest records artifact and postprocessing-source hashes.
The original configuration retains its twelve-hour launch target; the final
comparison scope is three hours. Raw state streams and MF NPZ remain in the
preserved local workspace and are required to recompute the comparison.

Original artifacts in the workspace:

- `full/comparison/mf_20min_snapshots.png` and `.pdf`
- `three_hour/comparison/spatial_mf.png` and `.pdf`
- `three_hour/comparison/selected_aces.png` and `.pdf`
- `three_hour/comparison/state_errors.png` and `.pdf`
- `three_hour/mf_all_aces.npz`
- `three_hour_state_results.json`

Conclusion: the three-hour saved-state evolution and resolved MF wave pattern
are highly consistent across implementations. This is not exact numerical
identity or a claim that the short-test thresholds hold for three hours.
No three-hour scientific tolerance was predefined; no threshold was relaxed.
The shared theta_e magnitude dominates its global relative norm, so the
absolute theta_e difference is also reported. Native precipitation is enabled,
but qt agreement alone does not verify accumulated rainfall or a closed water
budget. Full-step tendencies were not saved during this long run, so their
agreement is supported only by the earlier ten-minute tests. Correlation and
visual agreement do not constitute an independent dispersion-relation or
wave-speed validation; nonlocal pressure and mean-MF projection affect remote
response.

</details>

<a id="record-v020-khn26-p3-smoke"></a>

<details>
<summary>docs/migration/v020_khn26_p3_smoke.md</summary>

# KHN26 P3 ten-minute smoke experiment

Completed 2026-10-12 in `migration_work/khn26_p3_smoke`. This is a
Fortran-only P3 runtime experiment, with no native/MATLAB trajectory
comparison and no numerical algorithm or production source modification.

## Case and prognostics

- Shared Manaus profile 1342: `data/input/manaus1342_khn26.nc`.
- Full 101-column slab, 401 vertical interfaces, zero initial MF.
- Saturated +1 K bubble in ACE 1, levels 11–51; dt=4 s.
- P3 v5.3.1, one ice category, predicted cloud-droplet number,
  two-moment ice; ice third moment and liquid-fraction options disabled.
- State order: MF, theta, qv, qc, nc, qr, nr, qi, ni, qrim, brim.
- Initialized environmental cloud water and ice are retained from the
  theta_e/qt inversion; initial particle numbers and riming variables are zero.
  The saturated bubble starts condensate-free.

An isolated driver copy changes only the bubble increment from +0.25 K
to +1 K. The complete driver patch and snapshots of all five Fortran
source files are preserved. The production source hashes were unchanged
after completion.

## Builds, OpenMP and lookup provenance

Fresh debug and production builds used GNU `-O2 -ffree-form
-fdefault-real-8 -fdefault-double-8 -ffree-line-length-none -fopenmp`.
Debug additionally used `-g -fcheck=all,no-array-temps
-ffpe-trap=invalid,zero,overflow -fbacktrace`. NetCDF flags were obtained
from `nf-config`. Every object was rebuilt separately for each build.

Runtime requested `OMP_NUM_THREADS=32`, `OMP_DYNAMIC=FALSE` and a 64 MB
OpenMP stack. OpenMP is used for independent PMB response outputs; the
P3 microphysics source contains no OpenMP directives. The logs confirm
the runtime settings, but this experiment did not instrument actual team
size or measure efficiency. No CPU affinity was imposed.

The run read the external table at
`/scratch/peter50504/ACE_FORTRAN/input_data/p3_lookupTable_1.dat-v6.4-2momI`.
Its SHA-256 is `57d2e839b4bbc52fa15892ac47d04a76c0854577a5df34dae264e55bdad4baf3`,
matching the preserved P3 inventory. The active P3 source also matches that
inventory. The table is not added to this repository; the local external
path is required to reproduce the run.

## Results

1. The checked prefix completed ten steps (40 s), exit code 0, saving
   the initial state plus ten step states. All saved values were finite
   and all water/number/riming variables were nonnegative.
2. The separately built production prefix also exited 0 and its entire
   state stream was byte-identical to the checked prefix:
   `9513d4235a93e01c91ee0e38385a5218162f602cebdbe9b1fb155b64f7d1506d`.
3. The production ten-minute run completed 150 steps, exit code 0,
   saving 11 minute-spaced states through 600 s. The stream has SHA-256
   `67af67db1b2341f42168b29552b79b41e7dc9a49b42256bddd98ed5251ee3e3b`.
   All saved fields were finite and water/number/riming variables nonnegative.
   Every saved state satisfied qrim <= qi. Cloud/rain/ice numbers and rain
   mass became nonzero, and rime mass and volume became nonzero.

Extrema over all physical ACEs/heights and saved minute states:

| Field | Minimum | Maximum | Units |
| --- | ---: | ---: | --- |
| MF | −0.93922406 | 4.04223660 | kg m−2 s−1 |
| qc | 0 | 3.69106582e−3 | kg kg−1 |
| qr | 0 | 9.20757137e−4 | kg kg−1 |
| qi | 0 | 2.12953889e−4 | kg kg−1 |
| nc | 0 | 2.59676569e8 | number kg−1 |
| nr | 0 | 2.83454061e5 | number kg−1 |
| ni | 0 | 5.72556693e5 | number kg−1 |
| qrim | 0 | 1.78966182e−4 | kg kg−1 |
| brim | 0 | 2.15206583e−7 | m3 kg−1 |

At nonzero brim, qrim/brim ranges from approximately 71.26 to 900 kg m−3
across the saved minute states. These are descriptive outputs, not a new
microphysical acceptance threshold. Total water is qv+qc+qr+qi; qrim is
already included in qi.

The checked run reports underflow/denormal flags at exit, but completed
with invalid/division-by-zero/overflow traps enabled. The earlier isolated
dry/warm P3-wrapper failures are separate cases and are not declared fixed
by this full-model smoke result. The long-run stability, initialization of
particle numbers and physical acceptance remain review items. P3 surface
precipitation diagnostics remain local to the wrapper; neither a closed
water budget nor accumulated surface rainfall was verified here.

## Reproduction and preserved evidence

```bash
python3 tests/khn26/p3_smoke.py NEW_WORKSPACE \
  --lookup-directory /scratch/peter50504/ACE_FORTRAN/input_data
```

The workspace must not already exist. The runner checks the debug prefix,
then production-prefix byte identity, before starting the ten-minute run.
It preserves configuration, commands, hashes, source snapshots, logs and
binary64 state streams. The present runner also incorporates the supplemental
rime checks made after the completed experiment; the exact original executed
runner is preserved in the workspace.

The [versioned result record](../../tests/khn26/p3_smoke_results.json) includes
the configuration, prefix checks, minute-state metrics, supplemental checks
and execution-command provenance. Full outputs remain in the runtime workspace:
`debug_prefix/`, `production_prefix/`, and `ten_minute/`.

Recommended next work is a visual review of the P3 cloud, rain, ice and
MF evolution before considering a longer P3 experiment.

</details>

<a id="record-v020-khn26-p3-three-hour"></a>

<details>
<summary>docs/migration/v020_khn26_p3_three_hour.md</summary>

# KHN26 singleACE and multiACE P3 three-hour background runs

## Completed result and figures

The supervisor completed both runs and their saved-state checks on
2026-10-12 at 09:14:46 UTC. Both exited 0, saved 181 states through 10,800 s,
and passed finite-value, nonnegative water/number/riming and qrim <= qi
checks. Runtime state is `completed_pending_scientific_review`; this does
not establish physical acceptance or a closed water budget.

The plotter independently verified complete binary64 stream lengths,
dimensions and SHA-256 hashes against the completed results before reading
the saved states. The model state is Fortran real64, even though the separate
legacy interval output uses real32 storage. Scalar panels use the physical
first 400 levels at scalar-center heights; MF uses all 401 interfaces.
Plots show 0–20 km and the complete three-hour time axis.

- [singleACE time-height evolution](../figures/khn26_p3_3h/singleACE_time_height.png)
  ([PDF](../figures/khn26_p3_3h/singleACE_time_height.pdf)).
- [singleACE microphysics](../figures/khn26_p3_3h/singleACE_microphysics.png)
  ([PDF](../figures/khn26_p3_3h/singleACE_microphysics.pdf)).
- [multiACE time-height evolution](../figures/khn26_p3_3h/multiACE_time_height.png)
  ([PDF](../figures/khn26_p3_3h/multiACE_time_height.pdf)).
- [multiACE microphysics](../figures/khn26_p3_3h/multiACE_microphysics.png)
  ([PDF](../figures/khn26_p3_3h/multiACE_microphysics.pdf)).
- [multiACE spatial MF evolution](../figures/khn26_p3_3h/multiACE_spatial_mf.png)
  ([PDF](../figures/khn26_p3_3h/multiACE_spatial_mf.pdf)).
- [multiACE MF snapshots through minute 180](../figures/khn26_p3_3h/multiACE_mf_snapshots.png)
  ([PDF](../figures/khn26_p3_3h/multiACE_mf_snapshots.pdf)); colors clipped
  at ±1 kg m−2 s−1 to show weak spatial structure.

Time-height and microphysics plots show ACE 1. theta and total-water changes
are relative to each run's initial ACE-1 state. Total water is qv+qc+qr+qi;
qrim is included in qi and must not be added again. qc, qr and qi plots show
absolute species values. Rimed fraction qrim/qi is masked where qi is zero.
Each figure uses its own color limits, so independent figures should not
be compared by color intensity alone. Rain-water content is not surface
rainfall accumulation.

Maximum absolute MF is 9.2592605982 kg m−2 s−1 at minute 13, ACE 1, 4.5 km
for singleACE, and 5.1862390739 at minute 22, ACE 1, 6.5 km for multiACE.
These are descriptive trajectory observations, not an acceptance criterion.
The plotter and its [results](../figures/khn26_p3_3h/review_results.json),
[source configuration](../figures/khn26_p3_3h/source_configuration.json) and
[artifact manifest](../figures/khn26_p3_3h/manifest.json) preserve provenance.

```bash
python3 tests/khn26/plot_p3.py migration_work/khn26_p3_three_hour \
  --output docs/figures/khn26_p3_3h
```

This postprocessing reads preserved runs without launching another model.
## Native Fortran versus Fortran P3: MF-only paired snapshots

The developer clarified the requested layout: native Fortran on the left,
Fortran P3 on the right, following the previous paired MF snapshot format.
Both sides use real64 model states. These figures contain only MF, with
eight rows at minutes 20–160, height 0–20 km, panel height:width 1:5, and a
shared color scale −1 to +1 kg m−2 s−1. The horizontal coordinate is ACE
index 1–101, matching the earlier figure rather than physical distance.
The source runs cover three hours; the selected snapshot layout ends at
minute 160, as did the earlier eight-row layout.

- [multiACE paired MF snapshots](../figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.png)
  ([PDF](../figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.pdf)).
- [singleACE paired MF snapshots](../figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.png)
  ([PDF](../figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.pdf)).

The multiACE native reference is `migration_work/khn26_multi_weno_three_hour`;
the singleACE native reference is
`migration_work/khn26_single_matlab_default_fortran32_3h`. The plotter verifies
input hash, dt, bubble amplitude, MF heights, stream dimensions/completeness
and saved-stream hashes, and preserves each panel's MF hash. It does not
rerun a model or diagnose the cause of differences.

Native singleACE starts with a 0.03 MF pulse, while P3 singleACE starts with
zero MF; this mismatch is marked on the figure. Different preserved source
versions and physics are not controlled away. The figures are descriptive
comparisons, not a precision-error test or an isolated P3 effect estimate.
singleACE's response is restricted to the first dynamics column, so its
full-domain snapshots concentrate the visible signal near ACE 1.

```bash
python3 tests/khn26/plot_p3_mf_comparison.py migration_work/khn26_p3_three_hour \
  --native-single migration_work/khn26_single_matlab_default_fortran32_3h \
  --native-multi migration_work/khn26_multi_weno_three_hour \
  --output docs/figures/khn26_native_p3_mf
```

The [singleACE metadata](../figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.json),
[multiACE metadata](../figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.json)
and [manifest](../figures/khn26_native_p3_mf/manifest.json) record provenance;
source configurations are preserved alongside the figures.

## Preserved launch record

Authorized and launched 2026-10-12. Workspace:
`migration_work/khn26_p3_three_hour`. The background supervisor PID at
launch was 3444817. This is a launch record, not a completed result or
scientific acceptance report. Consult the workspace `status.json` for
the latest gate/run state.

The fresh singleACE checked/production gate passed with byte-identical
40-second streams. At 08:39:41 UTC, the supervisor reported both full runs
running: singleACE PID 3451553 and multiACE PID 3451554. These PIDs describe
the launch and must not be treated as proof of later completion.

Both independent Fortran runs use shared Manaus profile 1342, full
101-column slab basis, zero initial MF, a saturated +1 K bubble in ACE 1
at levels 11–51, dt=4 s, P3's eleven prognostics and 10,800 s duration.
Each run writes 181 minute-spaced binary64 state records if complete,
plus the existing real32 interval output. Field order is MF, theta, qv,
qc, nc, qr, nr, qi, ni, qrim, brim.

singleACE follows the existing ACE experiment definition: only ACE 1
dynamics tendencies are active, retaining the full basis, area-mean MF
projection, physics and damping in all columns. It is not a replacement
one-column basis. multiACE enables dynamics in all physical columns.
The production model sources are unchanged; the isolated singleACE
source only enables the existing dynamics mask. The +1 K isolated driver
was inherited from the [completed P3 smoke experiment](#record-v020-khn26-p3-smoke).

Both runs use GNU real64 `-O2 -fopenmp`. Runtime requests
`OMP_NUM_THREADS=32`, `OMP_THREAD_LIMIT=32`, `OMP_DYNAMIC=FALSE` and a
64 MB OpenMP stack for each model. No CPU affinity is imposed. OpenMP
accelerates PMB response, while P3 microphysics itself remains serial.
This is not an efficiency experiment. Lookup table version 6.4-2momI
and its hash are inherited and verified from the smoke configuration.

The supervisor first runs the fresh singleACE checked ten-step prefix,
then its separately rebuilt production prefix, requiring valid saved
states and byte-identical streams. The multiACE executable is a copy of
the completed ten-minute smoke run's production executable, with matching
source/input/table provenance. After the singleACE gate passes, both
three-hour integrations start together. The user deferred visual review,
cross-implementation comparison and drift-source investigation.

## Files and reproduction

- `configuration.json`: case settings, input/table/source/executable hashes.
- `build_commands.json`, `executed_runner.py`, `executed_state_reader.py`:
  exact build commands and preserved scripts.
- `supervisor.json`, `supervisor.log`, `status.json`: persistent process
  identity, supervisor output and progress/exit status.
- `singleACE/checked_prefix/`, `singleACE/production_prefix/`,
  `singleACE/gate_results.json`: fresh short-gate evidence.
- `singleACE/full/`, `multiACE/full/`: independent `launch.json`,
  `run.log`, `states.bin` and `fields.dat`.
- Each full directory receives `results.json` after completion. Successful
  process exit alone does not certify all expected records or valid fields.

```bash
python3 tests/khn26/p3_long.py NEW_WORKSPACE --prepare
python3 tests/khn26/p3_long.py NEW_WORKSPACE --launch
```

Preparation requires the completed smoke workspace and the same external
lookup path. The launch command detaches a supervisor and returns; the
supervisor and model processes redirect input/output and run in separate
sessions. Prepared workspaces cannot be launched twice. The supervisor
records each model's exit independently and checks finite values,
nonnegative water/number/riming fields, qrim <= qi and record completeness
at completion. This does not close a water budget or export P3 surface
rainfall from the wrapper.

</details>

<a id="record-v020-khn26-single"></a>

<details>
<summary>docs/migration/v020_khn26_single.md</summary>

# KHN26 singleACE dynamics comparison

Started 2026-10-05 on `migration/v020-preparation`, baseline `5d44949`,
following developer instruction to begin with singleACE testing and the
subsequent instruction to proceed. The first proposed setting was used:

| Setting | Value |
| --- | --- |
| Shared input | `data/input/manaus1342_khn26.nc`, Manaus profile 1342 |
| Basis/geometry | Complete 101-column KHN26 4UNEVEN slab PMB |
| Grid | 100 m; 401 fine levels and 200 coarse layers |
| Active dynamics | ACE 1; existing tendency mask in ACEs 2–101 |
| Bubble | Saturated +1 K in levels 11–51; no initial bubble condensate |
| Initial MF | ACE 1 sine pulse, amplitude 0.03 kg m−2 s−1, 0–1000 m; others zero |
| Integration | SSPRK93, dt=4 s, 3 h, output every 60 s |
| Physics | Precipitation disabled; existing damping retained; MF diffusion disabled |
| Momentum operators | PMDv/PMD disabled placeholders |
| Mean MF | Existing domain-mean MF=0 projection retained after SSPRK |
| Precision | MATLAB double and GNU Fortran real64 with bounds/FPE checks |

The mask acts on dynamics tendencies, not all physics/damping. Retaining
the mean-MF projection produces compensation MF in inactive columns; they
must not be described as having identically zero MF throughout the run.
These settings reuse older singleACE test parameters on the KHN26
Manaus/basis/grid contract; they do not reproduce the archived Manus case.

The [singleACE preparer/supervisor](../../tests/khn26/single.py) creates
isolated copies in `migration_work/khn26_single_3h/`, retaining source diffs,
compiler commands, input/generated-source hashes and `single_case.json`.
Release source files are unchanged. A one-step numerical comparison and
inactive-column/pulse checks gate the three-hour runs. The supervisor
records heartbeat, PIDs and driver exit codes in `single_status.json` and
preserves partial artifacts if a driver fails. Completed comparisons write
`smoke_results.json`, `full_results.json` and MF arrays.

The earlier six-hour multiACE session has incomplete outputs and a stale
status timestamp; its old interactive execution sessions are unavailable.
It has not established six-hour acceptance. This singleACE work uses a
detached supervisor rather than relying on those interactive sessions.

One-step gate passed: maximum absolute MF/theta_e/qt differences were
`2.151e-16` / `4.547e-13 K` /
`7.633e-17 kg/kg`. Both smoke drivers exited with code 0.
The detached supervisor started both three-hour drivers at that time.

Current full-run acceptance: pending. Review full MF/theta_e/qt evolution and
MATLAB/Fortran errors after successful completion. P3, real32 acceptance
and release publication remain separate work.

## Current status and evidence review (2026-10-05)

The original supervisor is recorded as `stopped_by_user` at 17:04:47 UTC
to replace the strided PMB kernel. MATLAB exited with code 0 and its saved
stream contains all 181 configured states; the stopped Fortran stream has
24 complete states through 1,380 s plus incomplete trailing bytes. There is
no `full_results.json`, so the original paired three-hour comparison is
incomplete. Preserve these artifacts as the legacy reference.

The packed production integration at `85f4128` is documented in the
[PMB layout record](../migration/v020_basis_layout.md). During this review, source, input,
baseline executable, legacy stream, packed stream and analysis-script hashes
were rechecked against the saved preparation/model reports. Binary comparisons
were repeated for serial/OpenMP masked single steps, the unmasked all-response
single step and the complete 24-state trajectory prefix. All passed. Saved-state
analysis reproduced MF/theta_e/qt maximum absolute differences from MATLAB of
`[1.76748e-13, 1.36424e-12, 2.71658e-15]`; finite states, nonnegative qt,
inactive-column behavior and mean-MF checks also passed. This review reused
saved outputs; it did not rerun model integration or kernel timings.

The next small validation step is a fresh three-hour Fortran singleACE run
using the checked packed serial build and exactly the existing case settings,
following developer instruction to run without OpenMP in the background.
Compare all 181 states with the preserved completed MATLAB stream after
verifying its input/generated-source provenance. Retain the 23-minute legacy
identity check separately, record actual driver exit status and new build/run
hashes, and produce matched trajectory plots only from validated complete
states. Keep all forcing/response columns and the existing compensation-MF
policy. A response-only shortcut, further numerical changes, six-hour native
physics budgets and release acceptance remain separate steps.

The serial timing supervisor is prepared in
`migration_work/khn26_single_serial_3h/` using
[`serial_timing.py`](../../tests/khn26/serial_timing.py). It will compare the
complete trajectory and report integration wall minutes per simulated hour
against the preserved MATLAB timing of 5,798.9891 s for three hours
(32.2166 minutes per simulated hour). Fortran process wall time is recorded
separately; MATLAB process wall time is unavailable. Completion and Fortran
timing remain pending until the supervisor records a successful driver exit
and writes `efficiency_results.json`.

## Debug gate then production run (2026-10-06 UTC)

The developer selected a ten-step debug gate followed by long integration
without debug flags, and explicitly requested stopping the existing run
first. The checked serial supervisor (2755264) and driver (2755425) were
terminated and their stopped status recorded before starting the replacement.
Partial streams in `migration_work/khn26_single_serial_3h/` are preserved;
they do not establish a completed three-hour result.

The replacement workspace is `migration_work/khn26_single_production_3h/`.
All objects are rebuilt independently in debug and production directories,
with GNU real64 `-O2`, no OpenMP and no fast-math. Only debug includes `-g`,
`-fcheck=all,no-array-temps`, `-ffpe-trap=invalid,zero,overflow` and `-fbacktrace`.
The supervisor runs ten 4 s steps with each build, checks successful exits,
complete finite/nonnegative-water states, byte identity between builds and
initial/single-step identity against frozen legacy. A failed gate stops there.
A successful gate starts a fresh production three-hour trajectory and the
existing MATLAB state/efficiency comparison. Scientific settings and PMB
response/forcing selection remain unchanged.

The gate passed at approximately 07:34 UTC: both drivers exited with code 0,
all eleven saved states were finite with nonnegative qt, and debug/production
streams were byte-identical, including agreement with the frozen initial/
single-step output. The [gate report](../../tests/khn26/serial_gate_results.json)
records output hashes and commands. Process wall times including initialization
and state I/O were 164.60 s (debug) and 77.11 s (production); these are not
integration-only timings. The production three-hour driver (2977978) then
started under supervisor 2970044. Full trajectory/efficiency acceptance remains
pending in the new workspace.

## Six-thread OpenMP replacement (2026-10-06 UTC)

The developer requested stopping the serial production run and using six
OpenMP threads. Supervisor 2970044 and driver 2977978 were confirmed stopped
before the replacement launcher ran. Their partial outputs remain in
`migration_work/khn26_single_production_3h/`; full acceptance is incomplete.

The new workspace is `migration_work/khn26_single_openmp6_3h/`, launched with
`serial_timing.py --threads 6`. Both independent builds add `-fopenmp` to
the existing real64 `-O2` settings. Only debug has runtime checks/debug flags;
the long production run has none. Runtime settings request six threads,
disable dynamic teams, cap the team at six and use close/core affinity.
OpenMP directives exist only around PMB contraction, over independent
response/edge outputs; the inner vertical-then-forcing reduction stays serial.
All other model calculations remain serial. No BLAS, new kernel algorithm,
single-response shortcut or scientific setting change is introduced.

The supervisor requires both ten-step gates to exit successfully with finite,
nonnegative-water and byte-identical states, and additionally compares all
eleven states against the preserved serial ten-step output. Only then does it
start the fresh three-hour integration and existing MATLAB comparison.

Both six-thread gates passed: eleven saved states are byte-identical between
debug/production and the preserved serial gate; values are finite and qt is
nonnegative. The [OpenMP gate report](../../tests/khn26/openmp_gate_results.json)
records successful exits, commands and hashes. The six-thread production
driver 3033599 started at 08:09:28 UTC under supervisor 3030121. Complete
trajectory and integration-efficiency results remain pending.

## Completed trajectory and plotted diagnostics (2026-10-06)

The six-thread run subsequently exited with code 0 at 08:46:33 UTC and saved
all 181 states through 10,800 s. Integration wall time was 2,173.9511 s
(36.2325 minutes); process wall time including initialization/output was
2,214.9312 s. Against the preserved MATLAB integration time of 5,798.9891 s,
the measured integration ratio is 2.66749. These are shared-host measurements.

The developer requested plots and diagnostics before a fresh 15-minute timing
comparison. `tests/khn26/plot_single.py` and
`tests/khn26/diagnose_single.py` produce MF time-height panels, theta_e/qt
anomaly panels and saved-state diagnostic curves in
`migration_work/khn26_single_openmp6_3h/full_comparison/`, with PNG/PDF
artifacts and hashes. Complete-state comparison was rerun before diagnostics.
The MF rise and later oscillations, and scalar anomaly structures, coincide
between implementations. Maximum absolute MF/theta_e/qt errors are
`[1.73328e-12, 9.54969e-12, 1.33808e-14]` in native units.
All saved states are finite with nonnegative qt. Maximum poststep area-mean
MF is `[1.56776e-16, 1.85507e-16]` for MATLAB/Fortran; the initial pulse is
excluded because it precedes mean correction. Inactive columns have equal
compensation MF. Their maximum theta_e/qt reference deviations are
`[1.53477e-10 K, 9.36751e-15 kg/kg]` in both implementations, below the
existing bounds. Saved-state checks are not independent energy/water budget
acceptance or release acceptance.

Next, `tests/khn26/benchmark_single.py` rebuilds current serial production
sources with real64 `-O2`, no OpenMP/debug flags, and requires ten-step
identity with the preserved serial gate. It copies the original MATLAB
three-hour launcher/source, changing only duration and artifact paths and
querying (not setting) its natural computational-thread cap. The two programs
run sequentially for 900 simulated seconds from the same initial state, with
`dt=4 s` (225 steps) and 60 s saved-state spacing. Initialization/output
process wall times are separate from integration timing. Each new stream
must reproduce its completed three-hour prefix before seconds per step are
reported. Runtime results are preserved in
`migration_work/khn26_single_serial_15min/`.

The 15-minute comparison completed successfully. Both drivers exited with
code 0 and saved 16 states. Each state stream is byte-identical to its own
completed three-hour prefix (Fortran uses the six-thread prefix as reference).
Maximum MATLAB/Fortran MF/theta_e/qt errors were
`[7.06102e-14, 1.13687e-12, 3.88578e-16]`; finite/nonnegative-water and
inactive-column/compensation checks passed. Results are recorded in
[`serial_benchmark_results.json`](../../tests/khn26/serial_benchmark_results.json).

| Implementation | Integration wall seconds | Wall seconds per 4 s step |
| --- | ---: | ---: |
| Current Fortran, serial production `-O2` real64 | 921.366582 | 4.094963 |
| MATLAB, original batch/default thread settings | 413.089800 | 1.835955 |

MATLAB's queried natural thread cap was 80; no setter or affinity restriction
was used. MATLAB was about 2.23043 times faster than serial Fortran in this
measurement. Do not combine this result with the six-thread three-hour ratio
as though they were the same execution mode or timing sample. The shorter
run's evolving-state average and shared-host load differ from the historical
three-hour MATLAB average (2.147774 s per step).

The first sandbox MATLAB startup failed to reach the license server (-96).
An approved execution outside the sandbox resumed only MATLAB using the
same launcher. `full_matlab.log` preserves the failure;
`resumed_matlab.log` records the successful integration, and
`recovery_configuration.json` records the recovery and script hash.
Fortran's integration wall timer was retained, but its full-process wall
duration was not persisted before the original supervisor exited and is
reported as null rather than reconstructed. MATLAB process wall time was
440.317156 s, including initialization/output. These are one sequential run
per language on shared hardware, with the timing scopes described above.

</details>

<a id="record-v020-khn26-single-native-physical-review"></a>

<details>
<summary>docs/migration/v020_khn26_single_native_physical_review.md</summary>

# Three-hour native singleACE visual review

Completed outputs: `migration_work/khn26_single_matlab_default_fortran32_3h`.
MATLAB used its unrestricted default computational-thread setting; Fortran
used 32 threads. The Ci correction was included. This review reads the
181 saved states from 0 to 180 minutes and does not rerun either model.
The plotting script verifies the saved-state and NetCDF hashes against the
completed comparison report before generating figures.

## Figures

- [ACE 1 time-height comparison](../figures/khn26_single_native_3h/time_height_comparison.png)
  shows MF, theta_e anomaly and total-water anomaly relative to the shared
  reference. MATLAB and Fortran use the same physical-field color scales.
  Difference panels have independently amplified scales, so visible colors
  do not imply differences comparable to the physical signal.
- [Vertical profiles](../figures/khn26_single_native_3h/vertical_profiles.png)
  at 0, 10, 60, 120 and 180 minutes overlay MATLAB solid and Fortran dashed.
  MF is on interfaces; theta_e and qt are on their scalar-center heights.
- [Agreement and flow diagnostics](../figures/khn26_single_native_3h/agreement_and_flow.png)
  show maximum errors over all ACEs, peak MF, peak vertical velocity and
  domain vertical kinetic energy. The dotted regression limits belong to
  the ten-minute checks; no three-hour acceptance limit was established.
- [Water storage and MF constraint](../figures/khn26_single_native_3h/water_and_constraint.png)
  show stored water changes and mean-MF residual excluding the initial state.

Each figure also has a PDF in the same directory. Numerical summaries and
source hashes are in `docs/figures/khn26_single_native_3h/review.json`.

## Findings

The time-height evolution and the physical diagnostic curves visually
coincide. An initial rising disturbance develops into sustained oscillations
in ACE 1. Both implementations have their maximum saved MF at 16 minutes,
6.6 km: 13.05280309157 (MATLAB) and 13.05280309178 (Fortran) kg/(m² s).
The maximum vertical velocity over the trajectory is approximately
22.29387986 m/s in both implementations; it is not asserted to occur at
the maximum-MF location or time.

| Field | Maximum absolute difference over all saved states/ACEs | Relative L2 difference |
| --- | ---: | ---: |
| MF | 4.10229e-9 kg/(m² s) | 1.31764e-10 |
| theta_e | 1.76331e-8 K | 1.12511e-13 |
| qt | 7.56377e-12 kg/kg | 6.02747e-12 |

MF exceeds the earlier 1e-9 ten-minute regression limit during the longer
trajectory; theta_e and qt remain below their respective short-test limits.
The difference plot makes this visible rather than treating the three-hour
run as an automatic pass. Finite saved states and nonnegative qt were checked.
The area-mean MF residual after the initial state is at most 1.99602e-16
(MATLAB) and 1.84043e-16 (Fortran) kg/(m² s).

Domain-mean stored water increases by 0.07094474669 kg/m², while the ACE 1
column increases by 14.18899710 kg/m². The two implementations agree on
these changes. Native precipitation removes water, but scalar exchange,
mixing and damping also operate; dynamics in ACEs 2–101 are masked in this
singleACE experiment. This is not a closed full-domain water-budget test,
and stored-water change is not surface precipitation. Likewise, the plotted
vertical kinetic energy omits horizontal kinetic, internal and potential
energy and is not a total-energy conservation test.

These figures establish close cross-implementation agreement for this
saved trajectory, without certifying all aspects of the physical solution.
The experiment is singleACE and cannot establish multiACE horizontal
gravity-wave propagation. The subsequent
[three-hour multiACE comparison](#record-v020-khn26-multiace-three-hour-comparison)
reviews the spatial wave pattern separately; interpreting the sustained
singleACE oscillations remains a distinct scientific task.

## Reproduction

```sh
PYTHONPATH=/tmp/ace-mf-plot-deps MPLCONFIGDIR=/tmp/ace-mf-matplotlib python tests/khn26/plot_single_native.py migration_work/khn26_single_matlab_default_fortran32_3h --output docs/figures/khn26_single_native_3h
```

</details>

<a id="record-v020-khn26-single-physical-review"></a>

<details>
<summary>docs/migration/v020_khn26_single_physical_review.md</summary>

# KHN26 singleACE saved-state physical review

This review uses the completed three-hour MATLAB and Fortran real64,
six-thread trajectories from `migration_work/khn26_single_openmp6_3h`.
No model integration, performance test or numerical source modification was
performed. The input, binary state streams and MATLAB NetCDF hashes are
verified against the preserved case and complete comparison report.

The configuration is Manaus sounding 1342, full 101-ACE KHN26 geometry,
100 m spacing, 4 s SSPRK93 steps, no precipitation physics, ACE 1 dynamics
only, and poststep area-mean MF removal. There are 181 saved states, spaced
60 s apart. This is a masked dynamics experiment, not a closed isolated
column or an unmasked multiACE conservation experiment.

## Evolution and implementation agreement

Both implementations have the same sampled maximum positive ACE 1 MF at
960 s and 6600 m: 11.9332357851 kg m-2 s-1. The sampled maximum positive
vertical velocity over the trajectory is about 20.1622 m/s; its maximum
need not occur at the same time/height as maximum MF because reference
density varies with height. At three hours the ACE 1 MF extrema are
approximately -0.280644 and 7.096212 kg m-2 s-1. The saved trajectory
therefore retains upward motion and includes downward motion at some levels.
The evolution is consistent with the earlier matched MF/scalar panels;
these observations alone do not establish physical realism or stability
outside this case.

Maximum complete saved-state MATLAB/Fortran differences in MF, theta_e and
qt remain `[1.73328e-12, 9.54969e-12, 1.33808e-14]` in native units.
Finite/nonnegative-water checks were repeated by the new analysis tool.

## Water inventory and exchange

Domain water inventory is
`sum_i sum_k (A_i/sum(A)) * rho_zc(k) * dz * qt(i,k)`
over physical scalar levels 1..400; the extra top scalar entry is excluded.
Column inventory omits the normalized area factor. Inventory changes are
computed from anomalies to avoid subtracting large background totals.

| Quantity | MATLAB | Fortran |
| --- | ---: | ---: |
| Initial domain water (kg/m2) | 61.48764621935 | 61.48764621935 |
| Three-hour domain change (kg/m2) | +0.107786043461 | +0.107786043461 |
| Relative domain change | +0.1752971% | +0.1752971% |
| ACE 1 column change (kg/m2) | +21.5572086922 | +21.5572086922 |

Net water changes differ between implementations by about 5.4e-15 kg/m2.
An independent calculation from the separate MATLAB NetCDF output uses
longdouble summation and checks the binary-stream inventory change.

The singleACE mask retains lateral advection and turbulent mixing in ACE 1
but suppresses the corresponding dynamics tendency in columns 2..101.
Thus the opposing lateral transfer is not applied to the receiving/supplying
column. Domain water change must be interpreted with this prescribed
reservoir behavior. Mean-MF correction changes MF in the inactive columns
but does not restore their missing scalar transport. This experiment cannot
be used to certify closed-domain multiACE water conservation.

The independent analysis reconstructs ACE 1 lateral advection from
`dm/dz * C_upwind`, turbulent mixing from
`-nju * perimeter/area * (C_1-C_2)`, and the scalar sponge relaxation rate
from `-exp((z-z_top)/SLD)/(SLTau*rho_zc) * (C-C_ref)`.
Constants are checked against both preserved drivers. Dynamics acts only
on levels 1..390 because the top eleven tendencies are zeroed. Vertical
flux convergence telescopes to the cutoff interface; its saved ACE 1 MF is
exactly zero. Surface tracer flux is explicitly zero in both drivers.
These boundary observations concern saved states, not all intermediate stages.

Trapezoidal integration of the reconstructed **60 s snapshot rates** gives:

| Water term | Three-hour sampled integral (kg/m2) |
| --- | ---: |
| Lateral advection | +0.225505649 |
| Turbulent mixing | -0.061469562 |
| Sponge relaxation | -0.055957461 |
| Sum | +0.108078626 |
| Observed change minus sampled sum | -0.000292583 |

The sampled terms explain the sign and approximate magnitude of the observed
increase, but do not close the discrete budget. The residual includes sparse
time sampling, implicit damping/operator splitting and any unobserved qt
clipping. The continuous sponge rate is not the exact implicit-step
increment. No conservation threshold is assigned to this residual. Exact
accounting requires tendencies at every SSPRK stage and the pre/post clipping
and damping inventories for every 4 s step.

## Energy scope

The theta_e inventory changes by about -41.040483 K kg/m2 in both models.
This is a transported-tracer inventory and must not be labeled total energy.

A separate diagnostic integrates **vertical kinetic energy only** on the
MF interface grid:
`sum_i (A_i/sum(A)) * integral MF_i(z)^2/(2*rho_mf(z)) dz`,
using trapezoidal endpoint weights from 0 to 40 km. Both implementations
give approximately 0.001024708 J/m2 initially, a sampled peak of
1898.573403 J/m2 at 900 s, and 641.839841 J/m2 at three hours. The maximum
cross-language difference at saved times is 2.47e-10 J/m2.

Growth of this diagnostic accompanies the developed updraft, followed by
smaller oscillating values. A mechanistic energy balance would additionally
require buoyancy work, pressure/nonlocal work, horizontal kinetic energy,
thermodynamic/internal and potential energy under an agreed model definition,
mixing, damping, mean-MF projection, masking and boundary/reservoir terms.
Those terms were not recorded in the existing trajectories. Consequently
this review establishes agreement of water and vertical-KE diagnostics,
but **does not establish total-energy conservation or scientific acceptance**.

## Artifacts and reproduction

- [Machine-readable report](../../tests/khn26/single_physical_review.json)
- [Review figure (PNG)](../figures/khn26_single_physical_review.png)
- [Review figure (PDF)](../figures/khn26_single_physical_review.pdf)
- [Analysis tool](../../tests/khn26/review_single.py)

```sh
python3 tests/khn26/review_single.py migration_work/khn26_single_openmp6_3h --output tests/khn26/single_physical_review.json --plot docs/figures/khn26_single_physical_review
```

NumPy and netCDF4 are required; plotting additionally requires matplotlib.
In this session the preexisting matplotlib dependencies were supplied with
`PYTHONPATH=/tmp/ace-mf-plot-deps` and `MPLCONFIGDIR=/tmp/ace-mf-matplotlib`.
No packages were installed. Existing model artifacts are read only;
the selected analysis report/figure paths are regenerated.

Recommended next scientific step: define the masked-case reservoir and
total-energy accounting conventions, then instrument isolated diagnostic
copies to accumulate stage/step terms and verify exact saved-state identity
against these completed trajectories. No scientific equations should be
changed to force apparent closure.

</details>

<a id="record-v020-khn26-single-precip-comparison"></a>

<details>
<summary>docs/migration/v020_khn26_single_precip_comparison.md</summary>

# KHN26 singleACE native precipitation comparison

Code and saved-output review on 2026-10-07. No simulation was rerun and no
production numerical method was changed during this review.

## What changed for this supplementary run

The isolated driver copies select singleACE dynamics, +1 K saturated bubble,
dt = 4 s, an ACE 1 initial MF pulse of 0.03 kg/m²/s below 1 km, and native
precipitation. The complete basis and 101 columns remain. Added stream exports
and thread assertions are recorded in the workspace's generated diffs.
The source precipitation and thermodynamic formulas were not edited for this
supplement. Native precipitation and damping operate on all columns.

## Existing implementation differences

- MATLAB `PRECIP_SINKS` evaluates `log(1+exp(ramp))`; Fortran `precip_sinks`
  evaluates `max(ramp,0)+log(1+exp(-abs(ramp)))`. These expressions are
  mathematically equivalent, but floating-point rounding can differ. The
  Fortran expression avoids exponential overflow. Both use qc_ramp = 0.5e-3,
  dqc = 20, tau_pr = 300 s and zero sinks for qc <= 0.
- Both estimate the theta_e condensate derivative by perturbing ql/qi with
  total magnitude 1e-8, subtracting two theta_e values, and dividing by 1e-8.
  Cancellation can amplify small differences in thermodynamic evaluations.
  This is a possible contributor, not a demonstrated sole cause.
- MATLAB `inv_T_from_theta_e` uses complex arithmetic and imaginary/NaN
  checks; Fortran `inv_theta_e` uses real arithmetic. Both Newton tolerances
  are 1e-3 K. MATLAB hardcodes several precomputed constants; Fortran computes
  some from constituent constants. Expression evaluation and exceptional
  state handling are not identical.
- MATLAB clips qt before area-mean MF removal; Fortran removes mean MF before
  clipping qt. For finite states these operations act on different fields.
  Both apply precipitation after SSPRK and before implicit damping. This
  order difference alone is not evidence of the observed discrepancy.

## Historical scientific changes

Commit `5d44949` predates this supplement and aligned Fortran to MATLAB. Its
diff includes replacing the old `max(ramp,0)` sink with the smooth ramp,
recomputing thermodynamic equilibrium from the post-SSPRK state before
precipitation, correcting the ice unsaturated Newton derivative from a plus
to a minus sign, and aligning saturation derivatives and initial guesses.
Thus historical formulas did change, but these changes are already present
in the source used by this comparison; they were not introduced by the
supplementary test. Passing a physics-off test does not validate every native
precipitation calculation.

## Evidence from saved streams

Workspace: `migration_work/khn26_single32_native_3h`.

- Initial maximum differences (MF, theta_e, qt):
  `(0, 3.41061e-13, 7.63278e-17)`.
- First step's nine dynamics stages differ at most about 5.73e-17 in MF
  tendency and 2.07e-16 in theta_e tendency. First applied theta_e sink
  difference is 1.06894e-16 K/s; qt sinks are identical at that step.
- Saved theta_e differences first exceed 1e-10 K at 192 s, 1e-9 K at
  212 s, 1e-8 K at 256 s and 1e-7 K at 352 s.
- Largest theta_e sink difference is 8.78773e-9 K/s at step 150, ACE 1,
  scalar level 68. The corresponding sinks are 0.00657289198738 (MATLAB)
  and 0.00657288319965 (Fortran) K/s.
- Checked and production Fortran ten-step exports are byte-identical.

The trajectory starts very close and differences grow with integration.
Current tendency/sink comparisons use each program's own evolving state;
they cannot separate a local formula difference from differences inherited
from earlier steps. A forced common-state thermodynamic/sink comparison is
the recommended next check if further investigation is authorized. No
regression limit has been changed, and no long run was started.

## Common-state follow-up: confirmed Ci formula difference

The background follow-up in `migration_work/khn26_common_precip32` completed
19,248 samples with 32-thread caps verified in both programs. Samples come
from both saved trajectories at 0, 180, 192, 212, 352 and 600 s, ACEs 1, 2,
51 and 101, and all 401 levels. Each program re-exported its input;
the re-export hashes match the common binary input byte for byte. No formula
was modified. The MATLAB local inversion/sink functions were copied exactly
from `ace.m`; the Fortran probe calls the existing production procedures.

| Comparison on identical inputs | Maximum absolute difference |
| --- | ---: |
| Inverted temperature | 1.13687e-13 K |
| Inverted vapor / liquid | 1.64799e-16 kg/kg |
| Inverted ice | 4.51028e-17 kg/kg |
| Forward theta_e, identical T/q/ql/qi | 3.20455e-6 K |
| theta_e sink, identical T/q/ql/qi | 8.59693e-9 K/s |
| qt sink, identical T/q/ql/qi | 1.05879e-22 kg/kg/s |

The forward formula discrepancy is in **ice heat capacity**:

- MATLAB `util_thermodynamics/ci.m`: `2106 + 7.3*(T-273.15)`.
- Fortran `ace_module.F`, function `Ci`: `2106 + 7.3*(T-273.1636783445389)`.

At the triple point, these give 2106.099851915134 and 2106 J/(kg K).
Both forward theta_e procedures use `(4190-Ci(T0))*qi/Cpl` as the exponent
of `(T0/T)`. Thus the formulas differ when qi is nonzero and T is not T0.
Fortran's inverse procedure separately uses dC = 2083.900148084866, consistent
with MATLAB's Ci(T0), rather than the 2084 implied by its own forward Ci(T0).
The inverse and forward ice coefficients are therefore inconsistent.

An analytical correction factor based only on this Ci offset reproduces the
Fortran forward theta_e to within 2.27374e-13 K across the sampled common
thermodynamic states. Applying the inverse factor to the saved Fortran base
and perturbed theta_e reduces their forward mismatch from 3.20455e-6 K to
2.27374e-13 K. The resulting postprocessed sink maximum mismatch decreases
from 8.59693e-9 to 2.29255e-10 K/s. Subtraction/division rounding remains in
this postprocessing; it is not a replacement for rerunning the actual formula.

This confirms a systematic ice-formula difference and its contribution to
the local theta_e sink difference. It does not yet establish how much of the
entire ten-minute trajectory error would remain after a production fix.
Git blame traces the Fortran Ci expression to commit `f3f3e240` (2024-12-16);
the recent test and performance work did not introduce it.

Reproduce the analysis with:

```sh
python tests/khn26/common_precip.py migration_work/khn26_common_precip32 --prepare
python tests/khn26/common_precip.py migration_work/khn26_common_precip32 --launch
python tests/khn26/attribute_ci.py migration_work/khn26_common_precip32
```

Preparation requires a fresh workspace; the completed workspace is preserved.
`results.json`, `ci_attribution.json` and `configuration.json` contain values,
sample locations and source/artifact hashes. The recommended small scientific
fix for developer review is to use 273.15 K as Fortran Ci's reference, matching
MATLAB and the existing inverse coefficient, then repeat this common-state
test and the short native trajectory gates before any long simulation.

</details>

<a id="record-v020-khn26-six-hour"></a>

<details>
<summary>docs/migration/v020_khn26_six_hour.md</summary>

# KHN26 six-hour comparison: historical launch record

Status reviewed 2026-10-08: the text below records the original launch,
not a confirmed current run. The workspace's last `trajectory_status.json`
update is 2026-10-05 08:18:29 UTC, labels the run `running`, and records
incomplete artifacts. No completed six-hour report was found during this
review. Preserve this record and raw status; do not count it as completed
validation. Later three-hour tests use different settings and do not finish
this experiment. See [current development status](#record-v020-khn26-status).

## Original launch and planned checks

Started 2026-10-04 from commit `5d44949` on
`migration/v020-preparation`, with developer authorization to proceed.
Workspace: `migration_work/khn26_six_hour/` (ignored runtime artifacts).

Both production drivers use `data/input/manaus1342_khn26.nc`, actual 101-ACE
4UNEVEN geometry, Manaus profile 1342, native precipitation, dt=6 s and
360 one-minute intervals. Fortran uses GNU real64 with bounds checks and
invalid/zero/overflow traps. The existing preparation script records the
compiler commands and input/source hashes. No scientific source changes,
P3 runtime, real32 acceptance, release or commit is part of this work.

Production runs and separately instrumented copies are running. Diagnostic
copies observe weighted theta_e/total-water inventories before dynamics,
after dynamics plus clipping, after native precipitation and after damping.
They also integrate each column's actual native water sink each 6 s step.
Weights use reference density, layer thickness and normalized ACE area over
400 physical scalar levels. This is tracer accounting, not total-energy
closure or a transported surface-precipitation measurement.

The diagnostic copies passed an initial/6 s exact identity check against
the existing committed validation artifacts, whose SHA256 hashes were
verified. MATLAB initial and evolved prognostics are exactly identical;
Fortran initial/reference/evolved binary streams are exactly identical.
The evidence is `diagnostic_short/identity.json` in the workspace.
Full-trajectory identity is still required before accepting their budgets.

The [trajectory tool](../../tests/khn26/trajectory.py) watches complete
artifact sizes, detects known model failures and writes
`trajectory_status.json`. After both six-hour production and diagnostic
runs finish, it checks identity and input/source stability, compares
saved states and normal production outputs, then writes
`six_hour_report.json` with metrics and hashes. See the
[reproduction instructions](../../tests/khn26/README.md).

At preparation time, MATLAB advances substantially faster than Fortran's
current PMB contraction. Full completion time is not yet established.
Partial output must not be presented as six-hour validation or scientific
acceptance. Review trajectory evolution, dynamics/boundary accounting,
native-removal accumulation and MATLAB/Fortran differences after complete
reports are available. Numerical methods have not been optimized or changed
to address runtime.

</details>

<a id="record-v020-khn26-status"></a>

<details>
<summary>docs/migration/v020_khn26_status.md</summary>

# KHN26 development status

## Release acceptance: 2026-10-12

The developer reviewed the completed precipitation figures, accepted the
current differences, and authorized v0.20.0 release and merge into `main`.
[Release notes](../releases/v0.20.0-notes.md) now define the accepted scope
and retained limitations. Further drift attribution is deferred; earlier
pending-release statements below remain dated history, not current blockers.

The multiACE-only diagnostic runs all completed by 2026-10-12 12:30:19 UTC.
Each has 181 minute precipitation records through 10,800 s, and each saved
state stream exactly matches its own preserved reference. The
[results](../figures/khn26_multi_precipitation_3h/results.json) and ACE-1/domain
area-mean figures are versioned. This establishes output preservation;
it does not establish cross-physics equality or full budget closure.

## Verified update: 2026-10-12

The WENO-aligned native multiACE three-hour run **did complete** on
2026-10-08 at 17:19 UTC, after the review below. The workspace
`migration_work/khn26_multi_weno_three_hour` contains 181 saved states
through 10,800 s and successful MATLAB/Fortran exits. Independent raw-stream
checks and visual review are now recorded in the
[aligned three-hour review](#record-v020-khn26-weno-three-hour-review).
All saved values are finite and qt is nonnegative. Maximum MF/theta_e/qt
differences are approximately 29–30% smaller than the earlier three-hour
run, while late error growth remains. Scientific acceptance, closed water
budgets and the first cause of drift remain unresolved.

This update supersedes the earlier statements below that no aligned long
trajectory existed and that a fresh three-hour run was the next experiment.
The earlier review is retained as a dated historical record. The developer
subsequently deferred further trajectory comparison and drift attribution.

A Fortran-only P3 ten-minute experiment also completed on 2026-10-12.
The checked ten-step prefix passed and was byte-identical to the separately
built production prefix. All 11 minute-spaced states were finite with
nonnegative water/number/riming fields and qrim <= qi. The OpenMP build
requested 32 threads for PMB response; P3 microphysics remains serial.
See the [P3 smoke record](#record-v020-khn26-p3-smoke). This establishes short
runtime evidence, not P3 long-run or physical acceptance. The developer
then deferred visual review and requested background three-hour P3 singleACE
and multiACE runs. Both full integrations started on 2026-10-12 after the
fresh singleACE checked/production prefix gate passed. See the
[P3 three-hour record](#record-v020-khn26-p3-three-hour). Both runs subsequently
completed with 181 saved states, exit code 0 and passed saved-state validity
checks. P3 time-height, microphysics and spatial MF figures are now preserved
there, together with the subsequently requested MF-only native/P3 paired
snapshots in the previous eight-row format. The singleACE initial-MF
mismatch is explicitly marked. These are descriptive results, not physical
acceptance, a closed water budget or an isolated physics-effect estimate.

The later precipitation-curve request exposed missing long-run precipitation
diagnostics. Six isolated diagnostic replays were started, then explicitly
stopped by the developer; their workspace
`migration_work/khn26_precipitation_three_hour` preserves the partial outputs
and stop record. The diagnostic output generator now accumulates precipitation
at each step and writes minute amounts plus running totals every 60 s, with
an initial zero record. Focused MATLAB/Fortran bookkeeping checks passed;
no model was restarted for this change. See
[minute precipitation output](../migration/v020_precipitation_output.md). Existing completed
three-hour state runs remain unchanged.

The developer then authorized a fresh multiACE-only three-hour diagnostic
run: MATLAB with default threads, Fortran native and P3 with 32 OpenMP threads
each. All three started together on 2026-10-12 at 10:49:22 UTC in
`migration_work/khn26_multi_precipitation_three_hour`, using minute amounts
and running precipitation totals. See the output record above and the new
workspace status for the completed replay; the release update above supersedes
this historical launch-only description.

## Historical review: 2026-10-08

Reviewed 2026-10-08 on `test/khn26-multiace-gravity-wave`, with production
source at `b1010ea`. This page indexes existing evidence; the status review
does not run the model or establish release acceptance.

Subsequent authorized work on 2026-10-08 aligns the working Fortran k=2
WENO calculation with MATLAB; both fresh dry/native ten-minute multiACE
gates passed. See [WENO alignment and regression](#record-v020-khn26-weno-matlab-alignment).
The production change and its results are tracked separately from the
three-hour runner policy and documentation cleanup.

Current long-test policy: both singleACE and multiACE use three hours
(10,800 s, 181 minute-spaced states). Gate-only tests retain ten minutes.
The shared runner's premature twelve-hour launch message has been removed;
the long-run message is emitted only when entering the three-hour path.
Fresh matching gates are required after runner/source changes, and preserved
long configurations with other durations are rejected before driver launch.

## Completed work and evidence scope

| Work | Status and scope | Evidence |
| --- | --- | --- |
| KHN26 source promotion and shared input | Implemented; original/shared MATLAB initialization and short native runs checked. | [Integration](../migration/v020_khn26_integration.md) |
| Packed PMB and optional OpenMP | Integrated in `85f4128`; selected legacy steps and the preserved 23-minute trajectory are byte-identical. Kernel timings are separate from full-model timings. | [Layout and regression record](../migration/v020_basis_layout.md) |
| Binary PCHIP interval search | Integrated in `2af198a`; the measured eight-ACE v0.18 annular case is distinct from KHN26 slab, which uses MAKIMA/direct interpolation. | [Timing scope and adoption](../performance/serial_timestep.md) |
| Earlier singleACE three-hour and serial timing tests | Completed; six-thread trajectory and sequential 15-minute serial measurements are recorded for their own configurations. | [SingleACE history](#record-v020-khn26-single) |
| Ci alignment | Implemented in `c509bcf`, with focused validation. | [Constants audit](#record-v020-khn26-constants-audit) |
| Native singleACE three hours | Completed, 181 saved states; numerical and visual review preserved. Predates `b1010ea`. | [Physical review](#record-v020-khn26-single-native-physical-review) |
| Native multiACE three hours | Completed comparison of 181 saved states; original twelve-hour target was shortened and both runs intentionally stopped. Figures/results preserved in `5877e0c`. Predates `b1010ea`. | [Three-hour comparison](#record-v020-khn26-multiace-three-hour-comparison) |
| Boundary-region common-state replay | Ten one-step seeds and 12,180 thermodynamic samples analyzed. Large late-time discrepancies are mainly carried by the already different inputs; the first cause of the full drift remains unresolved. | [Difference attribution](#record-v020-khn26-multiace-difference-attribution) |
| MATLAB-written thermodynamic literals/order | Implemented in `b1010ea`; common-state probes and ten replays completed. Finite-difference sensitivity remains. | [Thermodynamic alignment](#record-v020-khn26-thermodynamics-matlab-alignment) |
| Fresh aligned multiACE ten-minute gates | Dry and native cases passed, 150 dt=4 s steps each. Checked/production first ten steps were byte-identical; no long integration started. | [Gate record](#record-v020-khn26-matlab-alignment-ten-minute-gates), [results](../../tests/khn26/matlab_alignment_gate_results.json) |
| Aligned ten-minute error-source controls | Twelve one-step replays and 14,616 common thermodynamic samples completed. Precipitation finite differences amplify upstream roundoff; selected local sink/update discrepancies reproduce exactly. | [Error-source analysis](#record-v020-khn26-ten-minute-error-sources), [results](../../tests/khn26/ten_minute_error_source_results.json) |
| MATLAB-written k=2 WENO calculation | Working source aligned; fresh dry/native ten-minute gates passed. MF/qt state maxima decreased, while native theta_e maximum slightly increased. No new long trajectory. | [Change and tests](#record-v020-khn26-weno-matlab-alignment), [results](../../tests/khn26/weno_matlab_alignment_gate_results.json) |

The two fresh gate/error-source reports, their JSON results and supporting
scripts were uncommitted at this review. Their completion is supported by
the local runtime reports, rather than inferred from commit presence.

## Historical runtime status and unresolved work

- The [six-hour launch record](#record-v020-khn26-six-hour) is historical.
  `migration_work/khn26_six_hour/trajectory_status.json` last reports
  `running` at 2026-10-05 08:18:29 UTC with incomplete artifacts. This is
  stale evidence, not confirmation of a currently running process or a
  completed six-hour validation. No completed six-hour report was found
  in that workspace during this review.
- The multiACE three-hour workspace still says
  `stopped_at_revised_target_pending_comparison` in its launcher status.
  The subsequent completed `three_hour_state_results.json` and versioned
  comparison document supersede that pending-comparison label. The raw
  launcher record is retained unchanged for traceability.
- Aligned ten-minute runtime statuses are `gates_passed` with
  `full_started: false`; both error-source workspaces report `completed`.
- Three-hour evolution after `b1010ea`, the unique first cause of accumulated
  multiACE drift, full six-hour budgets, P3 runtime, real32 numerical
  acceptance and v0.20 release acceptance remain unestablished.

The three-hour cases use dt=4 s and their documented bubble/masking settings;
they do not complete the original dt=6 s six-hour reference experiment.
Short regression thresholds do not certify three-hour behavior. Integrated
native water removal is not transported surface rainfall or a closed budget.

## Next decision

The [fresh source comparison](../migration/v020_khn26_code_comparison.md) records the
2026-10-08 implementation review, including WENO coefficient differences,
physics-disabled sink evaluation and fixed-grid/dt sponge-cache assumptions.
It adds source-level findings, not a new model trajectory.

Recommended next experiment: a fresh three-hour native multiACE comparison
on the aligned source, retaining the existing case and comparing against
the archived pre-alignment result. It requires the developer's next-step
decision; no simulation is launched by this documentation cleanup.

Keep documentation cleanup separate from the pre-existing gate/replay scripts
and result artifacts when committing. No commit, deletion, runtime-status
rewrite or scientific source change was made by this review.

</details>

<a id="record-v020-khn26-ten-minute-error-sources"></a>

<details>
<summary>docs/migration/v020_khn26_ten_minute_error_sources.md</summary>

# KHN26 ten-minute error sources: current-code review and local controls

This follows the completed MATLAB-default/Fortran-32 dry/native gates on
the aligned production source in `b1010ea`. The developer requested another
review of possible error sources. Production algorithms and constants were
not changed during this investigation.

## Controls performed

Twelve one-step dt=4 s replays use MATLAB and Fortran saved seeds at
0, 460, 464, 532, 580 and 596 s. The nonzero timestamps bracket the largest
theta_e state difference, native sink discrepancy and late-time errors.
Both implementations read each identical seed. MATLAB uses its platform
thread default; Fortran uses 32 threads. A common MATLAB environment Tv
removes independent reference-inversion differences from these replays.

The resulting post-SSPRK states supply 14,616 common thermodynamic samples:
all ACE-1 levels and scalar levels 50–101 in ACEs 98–101, using both solvers'
SSPRK outputs. On byte-identical theta_e/qt/p, compare independent inversions
and forward/sink calculations. Fortran also repeats the calculation using
the exact MATLAB T/q/ql/qi values. These scalar thermodynamic probes use
32 threads per program; they are not new trajectories or timing tests.
An additional 401-level Fortran probe reconstructs the production environment
Tv independently for comparison with the MATLAB replay initialization.

## Confirmed numerical sensitivity

At step 146 (580–584 s), ACE 1, scalar level 57 / 5.65 km, the original
maximum native sink difference is −1.70525790537e−10 K s−1 (Fortran minus
MATLAB). Using the **same** post-SSPRK theta_e/qt/p values in the two thermal
implementations gives **exactly zero** sink difference there.

Three local effects add algebraically to the original discrepancy:

| Effect at 5.65 km | theta_e sink difference, K s−1 |
| --- | ---: |
| Different thermal implementation on identical MATLAB SSPRK state | 0 |
| Different SSPRK result from identical starting seed, evaluated by Fortran | +4.33681e−18 |
| Existing MATLAB/Fortran starting-state mismatch, propagated by Fortran | −1.70525794874e−10 |

The reconstructed MATLAB and Fortran sinks equal the original gate's saved
sink values exactly. Therefore this particular largest sink discrepancy is
inherited-input sensitivity, not evidence that the two sink routines produce
different results on that same input. This does not identify its first seed
in the preceding 145 steps.

At the same step, ACE 1, scalar level 61 / 6.05 km, a different effect is
confirmed. Identical starting seeds produce a post-SSPRK theta_e difference
of only −5.68434e−14 K, with exactly equal qt. Fortran thermodynamics applied
to these slightly different inputs gives a condensate-derivative difference
of +1.13687e−5 and a sink difference of −7.77339e−11 K s−1. The rounded
4 s updates reproduce the observed −3.10990344587e−10 K state discrepancy
exactly. On either of those individually fixed inputs, the two thermal
implementations produce the same sink at this point.

This demonstrates that even an upstream dynamics/SSPRK roundoff perturbation
can be amplified by the 1e−8 precipitation finite difference. The discrepancy
is not attributable to thermal inversion implementation alone.

Across all common thermodynamic samples, independent inversion T differences
are at most 1.13687e−13 K. Phase selection matches in every sample. On fixed
T/q/ql/qi, forward theta_e differences reach 2.27374e−13 K; the derivative
difference reaches 1.70530e−5 and sink difference reaches 8.96589e−11 K s−1.
Thus forward evaluation roundoff is another demonstrated source even when
inversion-output differences are removed. Complex versus real arithmetic
and library evaluation of powers/exponentials are candidates for this small
roundoff; their individual contributions have not been isolated.

## Remaining code-level sources

| Calculation | Remaining implementation difference | Evidence / limit |
| --- | --- | --- |
| Thermal inversion | MATLAB explicitly uses complex arithmetic; Fortran uses real arithmetic, both at double precision in these tests. | T differs by at most 1.13687e−13 K in these probes; no phase mismatch. Arithmetic mode alone has not been proven to account for all differences. |
| Environment reference Tv | Each production driver inverts the environment independently. | Tv maximum difference 1.13687e−13 K at level 37, 3.65 km; excluded by the common-reference replays, not proven dominant. |
| Tv and buoyancy | MATLAB subtracts `(ql+qi)` and evaluates `rho*(g*(Tv−Tv_ref)/Tv_ref)`; Fortran subtracts ql then qi and groups `g*rho*(Tv−Tv_ref)/Tv_ref`. | Same-seed raw/mean-adjusted buoyancy differs by at most about 7.70e−15 / 7.63e−15 in density-weighted acceleration units. |
| Horizontal flow and transport | MATLAB uses `cumsum`, logical upwind masks and combined expressions; Fortran uses prefix `sum`, half-sum sign splitting and incremental tendency updates. Area units are km² versus m² before diagnostic conversion. | Mathematical definitions match the active slab case; local MF forcing difference at most 3.47e−18. No one expression has been isolated as the sole seed. |
| Pressure response | Both reduce vertically then across forcing columns, but MATLAB vector reductions and Fortran explicit additions can differ in floating-point accumulation. | Included in measured MF tendency differences, at most 2.64e−16 on common seeds. |
| SSPRK arithmetic | For example, MATLAB `(dt/6)*K1` versus Fortran `K1*dt/6`; accumulated stages have additional grouping differences. | Common-seed post-SSPRK theta_e maximum 2.27374e−13 K; the level-61 control demonstrates downstream amplification. |
| Sponge | MATLAB first combines relaxation/density into `damp`; Fortran uses a base coefficient and divides by density in the update. | Roundoff can enter, particularly aloft; maximum post-physics theta_e discrepancy stays 3.58625e−10 K after damping in the selected cases. No dominant sponge amplification found. |

The reviewed thermodynamic coefficients, gravity, precipitation parameters,
shared input precision, grid and timestep remain aligned for this active case.
The scalar phase definitions and unchanged 1e−3 K Newton-step stopping
threshold match. This threshold does not promise a 1e−3 bound on a forward
theta_e residual, nor bit-identical inversions.

The active slab right boundary still uses the outermost ACE itself; surface
tracer fluxes and top tendency masks match. Exported UP3 mfc and wc are
exactly equal on all common seeds. No different active boundary condition
was found. This review does not establish behavior for other geometries,
invalid inputs, disabled momentum-response terms or P3.

## Relative scale and interpretation

Across the twelve same-seed replays, maximum theta_e differences are
2.27374e−13 K after SSPRK and 3.58625e−10 K after precipitation/damping.
At 580 s, the common-seed full-step theta_e maximum is 3.10990e−10 K,
whereas propagation of the already different seeds through the same Fortran
implementation gives a maximum of 1.79944e−9 K. These separate maxima can
occur at different cells and must not be subtracted as a causal budget.

The strongest demonstrated amplifier is the precipitation finite difference.
The upstream seeds include small thermodynamic, buoyancy, transport/reduction
and SSPRK roundoff. The unique first cause of the entire ten-minute or
three-hour divergence is not established. A next small experiment would
align individual upstream expression orders in diagnostic copies and replay
identical states before deciding on any additional production change.

## Reproduction and evidence

Prepare a new workspace, then run the selected gate seeds:

```sh
python3 tests/khn26/replay_multi.py migration_work/khn26_ten_minute_error_sources --prepare --source migration_work/khn26_multi_matlab_alignment_10min --gate-records 0 115 116 133 145 149
python3 tests/khn26/replay_multi.py migration_work/khn26_ten_minute_error_sources --run
python3 tests/khn26/probe_replay_precip.py migration_work/khn26_ten_minute_error_thermo --prepare --replay migration_work/khn26_ten_minute_error_sources
python3 tests/khn26/common_precip.py migration_work/khn26_ten_minute_error_thermo --launch
```

The environment-only probe source and exact build commands are preserved
in `reference_probe.F` and `reference_probe_commands.json` in the replay
workspace. Execute that probe and wait for the common thermodynamic run
to complete before applying the postprocessor:

```sh
python3 tests/khn26/analyze_error_sources.py migration_work/khn26_ten_minute_error_sources migration_work/khn26_ten_minute_error_thermo
```

`tests/khn26/ten_minute_error_source_results.json` preserves component results,
common-state errors, local signed decompositions, exact sink/update reproduction,
phase checks, the environment comparison, and source/artifact hashes.

</details>

<a id="record-v020-khn26-thermodynamics-matlab-alignment"></a>

<details>
<summary>docs/migration/v020_khn26_thermodynamics_matlab_alignment.md</summary>

# KHN26 native thermodynamics: follow the written MATLAB calculation

The developer requested another check of thermal inversion and precipitation
sinks, then requested that Fortran follow the written MATLAB method as closely
as possible. This is a small numerical consistency change on
`test/khn26-multiace-gravity-wave`; MATLAB remains the reference.

## Recheck before changing production code

A fresh background execution of the 12,180 common thermodynamic samples
reproduced all three earlier output streams byte for byte. Both implementations
classified 8,876 samples as condensate-free, 656 as liquid-only, 2,644 as ice-only
and four as liquid/ice coexistence, with zero phase-selection mismatches.
Water partition closure was at most 4.33681e−19 kg kg−1; all species were
nonnegative. Without condensate, both sinks were exactly zero.

The shared Newton stopping threshold is **abs(dT) <= 1e−3 K**, not a bound
on the forward theta_e residual. Re-evaluating theta_e from inverted outputs
gave maximum residuals of 6.48576e−8 K (condensate-free), 6.87681e−5 K
(liquid-only), approximately 2.93299e−5 K (ice-only), and zero (four mixed
samples). These residuals belong to both implementations and must not be
confused with the much smaller MATLAB–Fortran difference.

## Production change

Only `fortran/src/ace_module.F` changes:

- `theta_e` and `inv_theta_e` use MATLAB's written EPS value
  `0.621971830985916`, rather than `Rd/Rv`. The two binary64 values differ
  by 4.44089e−16. The unsaturated inversion also uses MATLAB's written
  `0.378028169014084` complement.
- Heat capacity, triple-point phase comparisons and Newton derivatives use
  MATLAB's written coefficients (`3184.3`, `2.500968266240670e6`,
  `9155.566660243245`, `1867292`, `1221.611899584641`). Products/divisions
  in the unsaturated and condensed equations follow MATLAB's grouping.
- Native precipitation evaluates MATLAB's `log(1+exp(ramp))` expression
  when `exp(ramp)` is representable. For larger positive ramp, Fortran
  retains its former stable softplus fallback. The tested ramp range was
  −20 to 134.3793, so all samples exercised the MATLAB expression.

The Newton threshold, condensate phase rules, 1e−8 finite-difference
perturbation and physical precipitation parameters remain the reference
values. MATLAB's complex-valued inversion arithmetic and diagnostic handling
are not ported to Fortran; identical floating-point results are not promised.
The samples do not validate invalid-input handling or the overflow fallback.

## Validation after alignment

The same common inputs were rerun in the background, with 32 threads per
implementation. The ten dt=4 s saved-state replays were also rerun, using
MATLAB's platform thread default and 32 Fortran threads. Both completed.
No new multi-hour simulation or performance measurement was performed.

| Common-state quantity | Before | After |
| --- | ---: | ---: |
| Maximum independent-inversion T difference | 1.13687e−13 K | 1.13687e−13 K |
| Maximum independent-inversion theta_e sink difference | 1.39942e−10 K s−1 | 1.39942e−10 K s−1 |
| Maximum fixed-T/q/ql/qi theta_e sink difference | 1.36887e−10 K s−1 | 1.36887e−10 K s−1 |
| Phase-selection mismatches | 0 | 0 |
| Maximum water partition closure error | 4.33681e−19 | 4.33681e−19 |

The aligned qt sink matches an independent `logaddexp` evaluation to within
2.11758e−22 kg kg−1 s−1. theta_e sinks agree with qt sink times the exported
condensate derivative to within 1.73472e−18 K s−1, accounting for multiplication
and division order. All outputs are finite.

Across ten one-step replays, maximum post-SSPRK theta_e difference remains
2.27374e−13 K. Maximum post-precipitation difference changes from
5.04258e−10 to 5.04315e−10 K; thus these literal/order alignments do **not**
remove the finite-difference sensitivity. At the original ACE 1, 8.15 km
common-state target, sink difference remains −1.26067e−10 K s−1 and vanishes
when thermodynamic outputs are fixed to common MATLAB values.

A separate Fortran build with `-fcheck=all` and
`-ffpe-trap=invalid,zero,overflow` completed all 12,180 samples. Its input echo,
independent-inversion output and fixed-thermodynamic-state output are byte
identical to the production probe. Current source/input hashes were verified.
The earlier ten-minute gates and three-hour trajectories predate this change;
they are not presented as validations of the modified source.

Structured evidence, configurations and hashes are preserved in
`tests/khn26/thermodynamics_matlab_alignment_results.json`. Runtime evidence is
in `migration_work/khn26_multi_replay_precip_recheck`,
`migration_work/khn26_multi_replay_precip_matlab_order` and
`migration_work/khn26_multi_boundary_matlab_order`.

The audit can be repeated after a common-state run completes:

```sh
python3 tests/khn26/recheck_thermodynamics.py migration_work/khn26_multi_replay_precip_matlab_order --baseline migration_work/khn26_multi_replay_precip
```

Further reduction of cancellation would require a separately reviewed change
to the reference precipitation derivative. The full three-hour drift still
needs a controlled integration comparison; this local audit does not establish
its unique cause.

Fresh ten-minute dry/native multiACE regressions were subsequently completed
on this aligned source; both passed. See
[fresh ten-minute gates](#record-v020-khn26-matlab-alignment-ten-minute-gates)
for the updated validation scope, errors and reproduction commands.

</details>

<a id="record-v020-khn26-weno-matlab-alignment"></a>

<details>
<summary>docs/migration/v020_khn26_weno_matlab_alignment.md</summary>

# KHN26 k=2 WENO alignment with MATLAB

Implemented 2026-10-08 on `test/khn26-multiace-gravity-wave`, based on
`b1010ea`, at the developer's request. The developer subsequently requested
fresh ten-minute multiACE tests. The change is limited to the k=2 branch of
`fortran/src/ace_module.F:weno_vec`; MATLAB remains the reference.

## Written calculation

- Use MATLAB's written weights `0.666666666666667` and
  `0.333333333333333`, rather than evaluating `2./3.` and `1./3.`.
- Select the forward weights for nonnegative flow and reversed weights for
  negative flow, following MATLAB's logical-mask rule for finite inputs.
- Evaluate the middle candidate as `0.5*(v_left+v)` rather than
  `0.5*v_left+0.5*v`.
- Use one circular-stencil loop for all levels, including both endpoints
  and the negative-flow reconstruction at level 2. Nonnegative level-2
  flow still uses the first scalar value. The later zero surface flux and
  top tendency mask remain unchanged.

The circular loop replaces the separate endpoint helper and negative-flow
level-2 formula. It preserves the reference k=2 stencil and boundary policy
while matching the written coefficients and grouping. k=3, UP3, SSPRK,
thermodynamics, precipitation, pressure response and model configuration
are not modified. This changes floating-point results and is not a claim
that the previous and current trajectories are byte-identical.

## Component checks

The extracted production WENO routine compiled with GNU real32 and real64.
An independent NumPy evaluation of the written MATLAB k=2 formula was
compared with a checked GNU real64 build (`-O2`, array checks and
invalid/zero/overflow traps). Twenty 401-level cases combine constant,
smooth, discontinuous, random-temperature and random-water profiles with
positive, negative, zero and mixed flow. All reconstructed outputs were
finite and exactly equal to the NumPy results.

This is an independent formula check, not a MATLAB-runtime bit-identity
test or real32 numerical acceptance. Its inputs, extracted source,
executable, compiler command and JSON report are preserved in
`migration_work/khn26_multi_weno_alignment_10min/weno_*`.

## MultiACE regression

The first sandbox run failed at MATLAB licensing (`-96`, unable to connect
to the license server). Its logs and partial artifacts are preserved in
`migration_work/khn26_multi_weno_alignment_10min`. The paired test is rerun
outside the sandbox in a fresh workspace:
`migration_work/khn26_multi_weno_alignment_10min_licensed`.

The existing gate-only runner uses all 101 ACEs, zero initial MF, a +1 K
ACE-1 bubble at levels 11–51, dt=4 s and 150 steps per dry/native case.
MATLAB uses its unrestricted platform thread default; Fortran requests
32 OpenMP threads. Existing state, tendency and native-sink limits apply.
Checked Fortran ten-step prefixes must be byte-identical to production.
Source/input/configuration hashes are verified by the runner.

Both dry and native gates completed and passed. Both production drivers
exited normally in each case. MATLAB reported 80 computational threads at
start and finish; Fortran reported a 32-thread OpenMP team. All 151 saved
states per case were finite with nonnegative qt. All 1,350 SSPRK tendency
frames per case were compared. Checked and production first-ten-step
states/tendencies (and native sinks where enabled) were byte-identical.

Maximum absolute differences over all cells and saved states:

| Field | Dry before | Dry after | Native before | Native after | Existing limit |
| --- | ---: | ---: | ---: | ---: | ---: |
| MF, kg m−2 s−1 | 8.97060e−14 | 5.41789e−14 | 1.63794e−10 | 1.30354e−10 | 1e−9 |
| theta_e, K | 2.27374e−12 | 2.27374e−12 | 2.13765e−9 | 2.31921e−9 | 1e−7 |
| qt, kg kg−1 | 1.28370e−16 | 8.50015e−17 | 1.60804e−13 | 1.26120e−13 | 1e−11 |

Maximum absolute differences over all tendency frames after alignment:

| Field | Dry | Native | Existing limit |
| --- | ---: | ---: | ---: |
| MF, kg m−2 s−2 | 6.14526e−16 | 1.46654e−12 | 1e−9 |
| theta_e, K s−1 | 2.79607e−14 | 1.78787e−10 | 1e−8 |
| qt, kg kg−1 s−1 | 2.06507e−18 | 3.72555e−15 | 1e−11 |

Native theta_e/qt sink maximum errors are 2.50780e−10 K s−1 and
1.36361e−15 kg kg−1 s−1, below existing limits 1e−7 and 1e−11.
Sinks are finite, native water removal is nonnegative and precipitation
is exercised. Area-averaged integrated native removal is
0.02760122572581196 kg m−2 (MATLAB) and 0.02760122572599152 kg m−2
(Fortran), using the physical first 400 scalar levels. This is not surface
rainfall or a closed water budget.

The baseline is the completed thermodynamics-aligned gate at `b1010ea`.
All 53 MATLAB source hashes and the input hash match between tests. The
MATLAB saved-state/tendency stream identity against that baseline is
recorded in the versioned report. Source/input/build configuration hashes
were rechecked after completion, and both PNG/PDF plotting jobs succeeded.

MF and qt state maxima are smaller in both cases. Native theta_e state
maximum increases by about 8.5%, and its sink maximum increases from
1.70526e−10 to 2.50780e−10 K s−1. Therefore matching the WENO formula does
not uniformly reduce coupled-model discrepancies or remove precipitation
finite-difference sensitivity. These maxima may occur at different cells
and times; their difference is not a local causal error budget.

Final status is `gates_passed`, with `full_started: false`. The shared
supervisor retains a misleading twelve-hour startup sentence immediately
before its gate-only return; no full state streams were created and no
long integration started. This is a ten-minute regression result, not
three-hour validation.

The supervisor message described above belongs to the preserved completed
run. The current runner now prints only gate completion in gate-only mode;
its optional long-run path uses three hours for both singleACE and multiACE.

The [versioned results](../../tests/khn26/weno_matlab_alignment_gate_results.json)
preserve configuration, hashes, component checks, before/after metrics,
gate decisions, sink results and licensing recovery. Raw streams, logs,
executables and figures remain in the completed runtime workspace.

Reproduce in a new, nonexistent workspace:

```sh
python3 tests/khn26/gate_matlab_default.py WORK --prepare
python3 tests/khn26/gate_matlab_default.py WORK --run
```

Licensed MATLAB must be able to reach its license server. Original input,
generated drivers, executable hashes and raw output streams remain in the
runtime workspace. The [source comparison](../migration/v020_khn26_code_comparison.md)
records the pre-change WENO differences and other remaining differences.

</details>

<a id="record-v020-khn26-weno-three-hour-review"></a>

<details>
<summary>docs/migration/v020_khn26_weno_three_hour_review.md</summary>

# KHN26 aligned multiACE: three-hour saved-state review

Reviewed 2026-10-12. The preserved run completed on 2026-10-08 at
17:19 UTC (10:19 America/Los_Angeles), after the status documentation was
written. Workspace: `migration_work/khn26_multi_weno_three_hour`.
Its supervisor records successful exits for preparation, ten-minute gates,
and the three-hour integration. Both model exits are zero. The runtime label
`completed_pending_scientific_review` is retained; this review does not set
a release or scientific acceptance threshold.

The case uses native precipitation, dt=4 s, zero initial MF, a +1 K bubble
in ACE 1, 101 columns over 500 km, and minute-spaced output through 10,800 s
(181 states). MATLAB reports 80 platform-default computational threads;
Fortran reports an OpenMP team of 32. This is not an efficiency comparison.
The archived hashes of `matlab/ace.m`, `fortran/src/ace_module.F` and
`matlab/util_weno/reconstruction_weno_vec.m` match the current checkout.

## Checks and numerical findings

The review independently read both raw streams, verified exact file sizes,
Fortran dimensions and full state-stream SHA-256 hashes, and reproduced all
181 per-state maximum errors exactly. The MF plotting cache also matches
the raw streams exactly. All saved fields are finite, all saved qt values
are nonnegative, and initial MF is zero.

| Field | Maximum absolute difference | Relative L2 error | Reduction in maximum versus older run |
| --- | ---: | ---: | ---: |
| MF (kg m−2 s−1) | 4.2838883678e−6 | 4.5552887582e−7 | 29.47% |
| theta_e (K) | 3.8480542969e−5 | 3.2090490203e−10 | 30.37% |
| qt (kg kg−1) | 1.5097672663e−8 | 2.1923011491e−8 | 30.32% |

The older comparator is the preserved
`khn26_multi_matlab_default_fortran32_12h/three_hour_state_results.json`,
documented in the [earlier three-hour comparison](#record-v020-khn26-multiace-three-hour-comparison).
Input hash, dt, physics, bubble amplitude, initial MF and column widths were
checked for agreement. The reduction is a comparison between complete runs;
it does not isolate the contribution of WENO from thermodynamic alignment.
The new errors are not smaller at every saved time. Their sustained growth
after approximately 90 minutes remains visible.

Maximum MF difference occurs at minute 158, ACE 99, height 5.8 km.
Maximum theta_e and qt differences occur at minute 155, ACE 99, height 6.2 km.
This near-boundary concentration does not establish a boundary-condition bug.
Both implementations peak in absolute MF at minute 17, ACE 1, height 6.5 km:
8.260854635667144 (MATLAB) and 8.260854634946384 (Fortran).
Maximum absolute area-mean MF is 2.62536e−17 and 2.62116e−17, respectively.

## Figures and visual review

- [MF snapshots, 30–180 minutes](../figures/khn26_multi_weno_3h/mf_snapshots.png)
  ([PDF](../figures/khn26_multi_weno_3h/mf_snapshots.pdf)): physical distance
  0–500 km, height 0–20 km, MATLAB/Fortran/difference. MF colors clip at ±1;
  differences use a separate shared scale. These snapshots do not capture
  the minute-17 peak; the selected-column plot includes the full time series.
- [Spatial time evolution at 1, 5 and 10 km](../figures/khn26_multi_weno_3h/spatial_mf.png)
  ([PDF](../figures/khn26_multi_weno_3h/spatial_mf.pdf)).
- [Selected ACE time-height evolution](../figures/khn26_multi_weno_3h/selected_aces.png)
  ([PDF](../figures/khn26_multi_weno_3h/selected_aces.pdf)): ACE 1, 2, 10, 50, 100;
  each difference panel has its own scale.
- [Maximum state errors versus older run](../figures/khn26_multi_weno_3h/state_errors.png)
  ([PDF](../figures/khn26_multi_weno_3h/state_errors.pdf)).

Visual inspection shows matching resolved MF wave bands and no visible
phase displacement at this resolution. The enlarged difference panels show
late differences concentrated near the right boundary. The 0–20 km field
correlations at 20-minute intervals through minute 180 are at least
0.9999999999996947. These observations support close cross-implementation
agreement for this saved trajectory. They do not independently validate
wave speeds, dispersion, governing physics, or boundary behavior; nonlocal
pressure and mean-MF projection affect remote response.

Global theta_e relative L2 is dominated by the shared background magnitude;
its absolute difference is therefore also reported. Native precipitation is
enabled, but qt agreement does not establish transported surface rainfall
or a closed water budget. Checks cover minute-saved states, not every step
or long-run tendencies. The original report's `passed: false` is preserved:
completion and descriptive agreement do not define three-hour acceptance.

## Reproduction and provenance

Run from the repository root with NumPy and Matplotlib available:

```bash
python3 tests/khn26/review_multi.py migration_work/khn26_multi_weno_three_hour \
  --output docs/figures/khn26_multi_weno_3h \
  --baseline migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour_state_results.json
```

This reads preserved runs; it does not launch a simulation. The plotting
command also regenerates the existing workspace's spatial/selected-ACE plots.
This review used existing dependencies in `/tmp/ace-mf-plot-deps` via
`PYTHONPATH`, with `MPLCONFIGDIR=/tmp/ace-mf-matplotlib` and
`OPENBLAS_NUM_THREADS=1`.

[Review results](../figures/khn26_multi_weno_3h/review_results.json) preserve
errors, peak locations, correlations, old error curves and stream hashes.
[Source configuration](../figures/khn26_multi_weno_3h/source_configuration.json)
preserves run settings and source hashes;
[manifest](../figures/khn26_multi_weno_3h/manifest.json) hashes the figures,
reports and review script. Raw streams remain in the local runtime workspace.
No scientific model source, run setting, or original status/result record
was changed. Recommended next work: investigate the persistent late-time
error amplification near ACE 99 before deciding long-run acceptance.

</details>

<a id="record-v018-aligned-runtime-comparison"></a>

<details>
<summary>docs/v018_aligned_runtime_comparison.md</summary>

# v0.18 aligned complete-timestep comparison

Executed on 2026-10-01 at committed source `40d7cf2` on
`feature/shared-netcdf-input`, after Steps 1–3 and approved inverse follow-ups.
[Machine-readable evidence](../v018_aligned_runtime_comparison.json) records
source/input hashes, build commands, full metrics, and artifact hashes.
The [previous runtime comparison](#record-v018-runtime-comparison) remains historical
pre-alignment evidence and has not been overwritten.

## Configuration and test access

MATLAB R2023b Update 9 and GNU Fortran 11.2.0 use the same
`data/input/manus208.nc`, eight ACEs, 801 stored levels, dz=50 m, dt=4 s,
full PMB, disabled implicit MF diffusion, existing masks and sponge.
A fresh Fortran executable was built from current active sources, including
initialization; the old pre-alignment executable was not reused.
Compiler flags are `-O2 -ffree-form -fdefault-real-8 -fdefault-double-8
-ffree-line-length-none`, with netCDF-Fortran and its library rpath.
Comparison outputs retain binary64 rather than the production real*4 dumps.

The existing runner completed single dry, single precipitating, multi dry,
and multi precipitating cases in that order. Single mode uses the existing
single-ACE tendency mask and places the MF pulse in ACE 1; multi uses ACE 8.
Precipitating cases share one MATLAB-generated binary64 initial state with
Fortran: levels 11–30 of the pulse ACE contain liquid condensate
0.00049/0.00050/0.00051 kg/kg. Other levels and reference profiles are retained.
This manufactured liquid-onset test is not a replacement environmental profile.

Test access extracts exact active MATLAB local functions, skips the existing
unavailable plotting/radiation/plume diagnostics, and makes Fortran diagnostics
public only in a temporary module. The test flag enables its existing commented
single-ACE tendency mask. The generated access diff is retained in artifacts.
No production source was changed during this validation.

## Coupling order and cache

Both tested implementations complete all nine SSPRK93 dynamics stages, apply
precipitation once using the full dt, clip qt after precipitation, and then
apply existing damping. MATLAB's disabled MF-diffusion branch remains between
clipping and damping. The precipitation call uses cached T, vapor, ql and qi
from dynamics stage 1, before the dynamics update. Later RK stages retain that
cache; neither code introduces a post-dynamics inversion for precipitation.
This ordering is verified from the active call path and exercised by the
complete-step runs; no runtime call-count instrumentation was added.

## Numerical results

Initial theta_e, qt and MF are exactly equal for all four runs. All stored
trajectory states and raw tendencies are finite. The report checks all 31
samples (0:4:120 s), not just the terminal sample; qt remains positive in all
of them, so these runs do not activate the negative-qt clipping correction.
Temperature/phase/buoyancy diagnostics are sampled at 0, 4, 60 and 120 s.
The dry snapshots have zero condensate; precipitating snapshots activate the
liquid sink, with initial maximum ql+qi about 0.00051 kg/kg.

Maximum absolute differences across levels and ACEs:

| Mode | Time (s) | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: | ---: |
| single | 4 | 4.547474e-13 | 8.470329e-22 | 3.176374e-22 |
| single | 60 | 1.364242e-12 | 3.469447e-18 | 5.811324e-15 |
| single | 120 | 1.591616e-12 | 1.040834e-17 | 1.937686e-14 |
| single_precip | 4 | 3.467449e-12 | 3.469447e-18 | 7.652125e-14 |
| single_precip | 60 | 9.265477e-12 | 4.232725e-16 | 9.983195e-13 |
| single_precip | 120 | 1.330136e-11 | 1.500536e-15 | 1.845926e-12 |
| multi | 4 | 4.547474e-13 | 8.470329e-22 | 1.588187e-22 |
| multi | 60 | 1.591616e-12 | 3.469447e-18 | 3.327362e-15 |
| multi | 120 | 1.818989e-12 | 5.204170e-18 | 6.620789e-15 |
| multi_precip | 4 | 3.467449e-12 | 3.469447e-18 | 2.279513e-14 |
| multi_precip | 60 | 1.165290e-11 | 2.185752e-16 | 2.991114e-13 |
| multi_precip | 120 | 1.438138e-11 | 4.787837e-16 | 5.249134e-13 |

Maximum absolute differences across **all 31 stored time samples**:

| Mode | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: |
| single | 1.591616e-12 | 1.040834e-17 | 1.937686e-14 |
| single_precip | 1.767830e-11 | 1.500536e-15 | 1.845926e-12 |
| multi | 1.818989e-12 | 5.204170e-18 | 6.620789e-15 |
| multi_precip | 1.932676e-11 | 4.787837e-16 | 5.249134e-13 |

Relative L2, maximum relative error for nonzero MATLAB reference, zero-reference
error, RMS and worst locations are retained in JSON. Large relative errors at
near-zero values must be interpreted alongside absolute errors. No acceptance
tolerance was introduced or adjusted; finite trajectories and small observed
errors are evidence for these cases, not general equivalence.

The historical multi-ACE precipitating 120-second errors were about
1.16e-3 K, 6.26e-6 kg/kg and 2.26e-4 kg/m2/s. All three are substantially
smaller after the approved changes. The old manufactured state was generated
using the earlier inversion, so this is evidence of the final aligned
configuration, not an exact same-input attribution of each improvement to
an individual correction.

## Remaining differences

- The initial inverted T difference is now at most 1.13687e-13 K. MATLAB still
  references the shared-input Tv profile, whereas Fortran re-inverts its
  environmental theta_e/qt. Reference Tv differs by 1.84053e-8 K and initial
  buoyancy by 6.19340e-10 m/s2. Those reference-state behaviors were retained.
- The existing upper-boundary upwind difference, unassigned Fortran WENO
  endpoints, and kilometre/metre geometry rounding remain. WENO endpoints
  1 and 801 are excluded from defined-operator metrics, and full state metrics
  include all stored levels. The top-11 dynamics mask remains unchanged.
- Ten standalone warm, cold, liquid, ice and mixed-phase probes all return
  finite outputs. Inversion outputs agree to at most 5.68434e-14 K and
  2.16840e-19 kg/kg. However, **forward theta_e and its precipitation
  thermodynamic adjustment are not fully aligned for ice**. For the saturated
  ice probe at 250 K, 300 hPa and qi=0.001 kg/kg, forward theta_e differs by
  3.11308e-6 K and precipitation dtheta_e by 5.18223e-9 K/s, while dqt is equal.
- Direct inspection identifies `ci.m` using `2106+7.3*(T-273.15)`, versus
  Fortran `Ci` using `2106+7.3*(T-273.1636783445389)`. A temporary diagnostic
  changes only that Fortran Ci reference: forward theta_e then matches exactly
  for this probe; dtheta_e difference falls to 9.47390e-12 K/s. The retained
  1e-8 finite difference can amplify floating-point evaluation differences.
  This confirms an additional forward-thermodynamic difference; it does not
  authorize changing Step 1's precipitation thermodynamic formulation.
  The diagnostic edit is **not applied** to the active model.
- The prior 1200-case pure-ice endpoint branch discrepancy remains unresolved;
  these trajectory cases do not establish that every endpoint input agrees.

## Term-by-term forward-thermodynamic review

This review compares active `eval_theta_e.m`, `ci.m`, `lv.m`, MATLAB
`PRECIP_SINKS`, and Fortran `theta_e`, `Ci`, `Lv`, `eval_es`, `precip_sinks`.
All statements below concern finite real states; MATLAB complex failure paths
and zero-vapor singularities are not certified by these ten inputs.

| Term | MATLAB | Fortran | Finding |
| --- | --- | --- | --- |
| Total water | q+ql+qi | q+ql+qi | Same |
| Vapor pressure | p*q/(q+0.621971830985916*(1-qt)) | p*q/(q+(287.04/461.5)*(1-qt)) | Same mathematical ratio, different binary64 coefficient rounding |
| Dry gas constant / moist gas constant | RE=(1-qt)*287.04; R=RE+461.5*q | Same | Same |
| Heat capacity | 1005.7+3184.3*qt | 1005.7+(4190-1005.7)*qt | Same mathematical coefficient; the tested binary64 subtraction equals 3184.3 |
| Vaporization latent heat | 2501000-2320*(T-273.15) | Same via Cl-Cpv=2320 | Same |
| Saturation pressure and phase switch | Liquid at T>=273.1636783445389, ice otherwise | Same finite real branches and coefficients | Same equations |
| Ice heat capacity | 2106+7.3*(T-273.15) | 2106+7.3*(T-273.1636783445389) | Different reference temperature |
| Ice exponent | (4190-ci(T0))*qi/CPL | (4190-Ci(T0))*qi/CPL | Numerically different when qi>0 |
| Fusion term | -333700*qi/T0 | Same | Same |
| Full theta_e product | T*(1e5*R/p/RE)^chi*(es/e)^gamma*(T0/T)^gammi*exp((q*Lv/T-333700*qi/T0)/CPL) | Same product | Ci and coefficient rounding remain; library/compiler evaluation can differ |
| Smooth dqt | -(q0/a/tau)*log(1+exp((a/q0)*(qc-q0))) | Same | Same formula; tiny arithmetic differences reported |
| Condensate perturbation | dql=1e-8*ql/qc; dqi=1e-8*qi/qc | Same | Same |
| Thermodynamic adjustment | dqt*(theta_e(T,q,ql+dql,qi+dqi,p)-theta_e(T,q,ql,qi,p))/1e-8 | Same | Same finite-difference equation, affected by forward theta_e |
| qc<=0 guard | Overwrite dqt and dtheta_e with zero after evaluation | Same | Same final outputs; intermediate division by zero remains |

At T0, MATLAB ci=2106.099851915134 and Fortran Ci=2106, a difference of
0.099851915134 J/(kg K). The aligned inverse routines both use
`dC=2083.900148084866` directly; they do not call Ci for that coefficient.
Consequently this remaining forward difference does not invalidate the
observed inverse agreement, but it does affect the precipitation adjustment.

The additional reproducible diagnostic reuses the ten saved, identical input
triples and MATLAB outputs. It recompiles only a temporary Fortran module
with Ci's reference changed, retaining the original statement as a comment.
All ten outputs are finite, and assertions confirm inverse outputs and dqt
are exactly unchanged from the original Fortran probe. The pure-ice result
above reproduces; the mixed-phase probe at T=T0 remains unchanged because
the multiplier (T0/T)^gammi is then unity. Changing Ci does not establish
bitwise agreement for the finite-difference tendency or all other states.

Ice/mixed-phase sinks are standalone probes; no ice-precipitating trajectory,
long production run, closed water budget, Intel-compiler comparison or unified
release acceptance was performed. Inactive single-mode columns drift at most
1.70530e-12 in both runs, consistent with retained damping roundoff. No sweep
was run and no model tolerance was loosened.

## Reproduce

Build the current `test.F`, `ace_input.F` and `ace_module.F` in a fresh directory
using the compiler commands preserved in the JSON, then run:

```bash
python3 tests/alignment/run.py migration_work/aligned_timestep_repeat \
  --precip --model migration_work/aligned_timestep_build/ace_model.exe
python3 tests/alignment/compare_ice_forward.py \
  migration_work/aligned_timestep_repeat \
  migration_work/aligned_timestep_repeat/ice_forward_review
python3 tests/alignment/report.py migration_work/aligned_timestep_repeat \
  docs/v018_aligned_runtime_comparison.json \
  --build migration_work/aligned_timestep_build \
  --ice-diagnostic migration_work/aligned_timestep_repeat/ice_forward_review/comparison.json
```

The runner requires a fresh directory and access to the MATLAB license server.
Rebuild the model when sources change. Raw artifacts for this run are retained
in ignored `migration_work/aligned_timestep_run/`; build commands are in
`migration_work/aligned_timestep_build/build_commands.json`. The original Ci
experiment is retained in `ice_forward_trace/`, and the reproducible review
is in `ice_forward_review/`, both beneath the original run directory.
The normal runner does not apply that diagnostic edit; the separate diagnostic
command above changes only its temporary module, not production sources.

Recommended next work: review the ice forward-theta_e/precipitation adjustment
and its Ci reference temperature before any further scientific modification.

</details>

<a id="record-v018-atmospheric-validation"></a>

<details>
<summary>docs/v018_atmospheric_validation.md</summary>

# v0.18 validation of 1200 atmospheric conditions

The developer requested 1200 additional conditions in reasonable atmospheric
settings. The current final inversions were tested without production source,
tolerance, phase-rule or clipping changes. This is stratified synthetic
atmospheric sampling, not a Cartesian sweep or an observational dataset.

## Input design and reproducibility

The active MATLAB forward function constructs identical binary64
(theta_e,qt,p) inputs for both inversions. Random seed 180103 and explicit
category quotas generate exactly 1200 unique cases. Candidate p/T pairs use
broad vertical envelopes rather than independently combining arbitrary
pressures, temperatures and water contents:

| Pressure envelope (hPa) | Temperature envelope (K) |
| --- | --- |
| 900–1050 | 255–310 |
| 700–900 | 245–295 |
| 500–700 | 235–285 |
| 300–500 | 215–270 |
| 150–300 | 195–240 |
| 100–150 | 195–225 |

These are testing envelopes including cold/warm atmospheric extremes, not
claimed climatological limits. Liquid-only cases are above T0, ice-only
cases below T0, and this model's mixed phase is diagnosed only at T0.
Condensate is sampled logarithmically: liquid 1e-9–0.003 kg/kg, ice
1e-9–0.001 kg/kg, mixed 1e-9–0.002 kg/kg. Unsaturated cases include dry
points and vapor fractions from 0.02 to 0.98 of the applicable saturation.
The 200 near-boundary cases include qt perturbations from -1e-6 to +1e-6
relative to saturation and pure-phase T0 endpoints/offsets of +/-1e-6 and
+/-1e-3 K. Mixed-state vapor follows the existing mean liquid/ice saturation
constraint, as in earlier fixed tests.

Candidates are filtered before inversion for finite physical inputs,
theta_e 200–400 K, qt<=0.04 kg/kg and es<p at the constructed state.
The agreed test-only exclusion es>p uses the MATLAB no-condensate trial
state; the production routines gain no new es>=p guard. Rejected candidates
are not counted toward the requested 1200 cases. Actual accepted ranges:

- p: 100.1477603316929–1049.9044162420873 hPa.
- Constructed T: 195.02220200913908–307.96898191146937 K.
- theta_e: 254.21757338305784–399.76052937314967 K.
- qt: 0–35.11368670435436 g/kg.

Reproduce with `tests/thermodynamics/validate_atmosphere.py` and the MATLAB
runner of the same name. [All 1200 case records](../../tests/thermodynamics/results/atmospheric_validation.csv)
retain each input, category, constructed state, four outputs, branch/status/
iteration counts, absolute/relative differences and water closure.
[Summary and provenance](../v018_atmospheric_validation.json) records source
hashes, seed, code hashes, category results and the counterexample trace.
Raw workspaces are retained under ignored migration_work. Relative errors
with zero MATLAB reference are undefined and left blank in CSV.

## Numerical comparison

| Category | Cases | Finite/converged | Exactly equal outputs | Branch/iteration/status mismatches |
| --- | ---: | ---: | ---: | --- |
| Unsaturated | 300 | 300 | 280 | 0 / 0 / 0 |
| Liquid | 250 | 250 | 219 | 0 / 0 / 0 |
| Ice | 250 | 250 | 178 | 0 / 0 / 0 |
| Model mixed phase at T0 | 200 | 200 | 188 | 0 / 0 / 0 |
| Near saturation/phase boundary | 200 | 200 | 175 | 1 / 1 / 0 |
| Total | 1200 | 1200 | 1040 | 1 / 1 / 0 |

Every instrumented MATLAB output was checked against the active MATLAB
function. A separately compiled uninstrumented Fortran module reproduces
all 1200 instrumented four-variable outputs exactly. The observation cap
of 1000 iterations is test-only and no case reached it. Both implementations
return finite, nonnegative water outputs. Maximum water closure error is
8.673617379884035e-19 kg/kg in each implementation. No acceptance tolerance
was changed or imposed; completion is not a claim that every branch agrees.

| Quantity | Maximum absolute difference | Maximum relative difference (nonzero MATLAB reference) |
| --- | ---: | ---: |
| T | 2.7057467377744615e-11 K | 9.905221492740801e-14 |
| qv | 8.192231615300472e-15 kg/kg | 2.2432799174824534e-12 |
| ql | 1.7988207090268061e-16 kg/kg | 1 |
| qi | 8.19184960344126e-15 kg/kg | 0.005220692928334125 |

The large relative water errors have near-zero denominators. The ql
relative maximum compares 3.8201185921168945e-19 with zero. The qi relative
maximum occurs at case 1005: values about 7.14e-18 and 7.10e-18 kg/kg,
with absolute difference 3.7269449679189215e-20 kg/kg. They are retained in
the summary rather than hidden behind a relaxed tolerance.

## Remaining pure-ice endpoint difference: case 1106

Identical input:

```
theta_e = 279.38459687185775 K
qt      = 0.0036545877784970367 kg/kg
p       = 104359.54196921516 Pa
```

The construction is pure ice at T0 with ice about 2.6888106257886e-6 kg/kg.
Both no-condensate solves take two iterations. MATLAB selects mixed phase
with no condensate Newton iterations; Fortran selects ice-only and takes
two more iterations. Outputs:

| | MATLAB | Fortran |
| --- | ---: | ---: |
| T (K) | 273.16367834453888 | 273.16367834456594 |
| qv (kg/kg) | 0.0036518989678712486 | 0.003651898967879441 |
| ql (kg/kg) | 3.8201185921168945e-19 | 0 |
| qi (kg/kg) | 2.6888106257877232e-6 | 2.6888106175958736e-6 |

A single-case follow-up logs the actual phase-comparison values:

| | MATLAB | Fortran |
| --- | ---: | ---: |
| G0 | 1386.5482808172565 | 1386.5482808172565 |
| HT0 | 1386.5482808172562 | 1386.5482808172567 |
| G0-HT0 | +2.2737367544323206e-13 | -2.2737367544323206e-13 |

G0 and the recorded G0 pressure base, chi and power factors match. HT0
last-bit rounding changes the sign of the strict comparison and explains
the branch difference. The exact arithmetic/library origin of HT0 rounding
has not been attributed. This is an in-range atmospheric endpoint, unlike
the previously deferred theta_e>400 K example. The existing saturation
roundoff band controls qt-vs-qsat, not G0-vs-GT0/HT0 phase selection.

No boundary epsilon, new clipping, derivative or tolerance change was
applied after discovering this counterexample. The remaining 1199 cases
have matching branches and iteration counts. Review the desired phase-
endpoint decision rule before making a shared scientific correction.

For states constructed without qt perturbations, the maximum common
forward-inverse temperature error is about 1.02254e-7 K (MATLAB:
1.022543756334926e-7 K; Fortran: 1.0225431879007374e-7 K). This is distinct
from the much smaller cross-language errors above. Maximum observed iteration
counts are three no-condensate and four condensate steps in both languages.

</details>

<a id="record-v018-forward-evaluation-diagnostic"></a>

<details>
<summary>docs/v018_forward_evaluation_diagnostic.md</summary>

# v0.18 forward theta_e evaluation diagnostic

Executed on 2026-10-01 at `d09ad62`. Production MATLAB/Fortran sources,
thermodynamic inversion and precipitation equations are unchanged.
[Numerical evidence](../v018_forward_evaluation_diagnostic.json) records
commands, source/input/fixture hashes, generated patches, 26 intermediate
values for base/perturbed forward evaluations, and native sink metrics.

## Findings

The forward EPS spelling differs between implementations: MATLAB uses the
literal 0.621971830985916; Fortran uses `Rd/Rv`. Replacing only the temporary
Fortran forward function's EPS improves a few comparisons but does not
reduce the maximum finite-difference numerator or theta_e sink discrepancy.
Storing powers, exponentials and successive products separately while
preserving the existing arithmetic order produces exactly the same forward
results as the original expressions in both implementations on these inputs.

At the previously isolated 116 s, ACE 1, level 110 Fortran-trajectory state,
the decisive difference is evaluation of `exp()` on an identical argument.
Replacing only that function result in a temporary forward kernel removes
the point's numerator and theta_e sink difference. This intervention does
not eliminate all differences: the largest remaining sink discrepancy
shifts to a state whose pressure-power inputs agree but whose power result
differs. These observations isolate floating-point function evaluation,
amplified by the existing finite-difference subtraction/division, at the
identified points. They do not establish one universal cause for all errors.

## Matched inputs and controlled variants

Use exactly the MATLAB thermodynamic cache from the reviewed
[mixed residual replay](#record-v018-mixed-residual-diagnostic): ACE 1, levels
91–110, all 30 pre-step states from each native trajectory. This gives
1200 records, including 1120 unique T/qv/ql/qi/p tuples and 1168 records
with positive condensate. Each implementation receives identical binary64
T/qv/ql/qi/p; no inverse is performed in this probe.

Fresh MATLAB native forward results and sinks exactly reproduce the retained
replay's shared-cache results. The freshly instrumented Fortran control also
exactly reproduces its retained shared-cache results. Thus the diagnostics
do not introduce a new native baseline. Both native and perturbed forward
calls use the existing 1e-8 kg/kg condensate increment and phase partition.

The six temporary Fortran variants are:

| Variant | Forward EPS | Expression | Main forward exponential |
| --- | --- | --- | --- |
| control | `Rd/Rv` | Original | Native |
| eps_literal | MATLAB literal | Original | Native |
| staged | `Rd/Rv` | Separate factors/products, original order | Native |
| eps_literal_staged | MATLAB literal | Separate factors/products, original order | Native |
| exp_override | `Rd/Rv` | Original | Exact-argument MATLAB result |
| eps_literal_exp_override | MATLAB literal | Original | Exact-argument MATLAB result |

Only the forward function is substituted; the inverse and all following
production routines remain byte-identical to the prepared control. The
exponential override looks up a MATLAB result only for the exactly equal
binary64 argument, rejects an unrecorded finite argument, and preserves
native evaluation for nonfinite arguments. This last rule retains the
original inactive qc=0 sink's pre-mask NaN behavior; final sink values remain
finite and zero there. Saturation-pressure exponentials are not overridden.
The variants are standalone probes, not integrated model corrections.

GNU Fortran 11.2.0 uses -O2, -fdefault-real-8 and -fdefault-double-8.
MATLAB uses R2023b Update 9. The final run reproduces the original four
variants' metrics from an independent fresh build. All recorded output
blocks are finite; production hashes match before and after execution.

## Quantitative results

Maximum absolute differences across all 1200 records, without tolerances:

| Variant | Numerator difference (K) | theta_e sink difference (K/s) | Exactly matching numerators | Exactly matching theta_e sinks |
| --- | ---: | ---: | ---: | ---: |
| control | 1.705303e-13 | 8.426702e-12 | 1007 | 950 |
| eps_literal | 1.705303e-13 | 8.426702e-12 | 1014 | 956 |
| staged | 1.705303e-13 | 8.426702e-12 | 1007 | 950 |
| eps_literal_staged | 1.705303e-13 | 8.426702e-12 | 1014 | 956 |
| exp_override | 1.136868e-13 | 4.996031e-12 | 1043 | 983 |
| eps_literal_exp_override | 1.136868e-13 | 4.996031e-12 | 1050 | 989 |

Counts include inactive sinks and duplicated records; they are not acceptance
rates or a count of distinct physical conditions. qt sink maximum differences
are 5.293956e-23 kg/kg/s in every variant. RMS, relative L2, nonzero-reference
relative errors and worst record indices are retained in JSON. Changes in
maxima are not additive causal error budgets.

The compiled EPS values are:

| Definition | Binary64 hexadecimal value |
| --- | --- |
| MATLAB literal | `0x1.3e7317823c499p-1` |
| Fortran `Rd/Rv` | `0x1.3e7317823c495p-1` |

Their difference is 4.440892098501e-16, four representable increments.
The heat-capacity slope `Cl-Cpd` agrees exactly with MATLAB's 3184.3 on this
build, and the reference ice heat capacity also agrees. Aligning EPS is a
scientific constant choice; these diagnostics do not approve that change.

## Previously worst point: equal argument, different exp result

With EPS aligned, all base intermediates agree. For the perturbed evaluation,
all intermediates through the powers and partial products agree, except the
main exponential result:

| Quantity | MATLAB | Fortran |
| --- | ---: | ---: |
| Exponential argument | 0.06084092136225619 | 0.06084092136225619 |
| Exponential result | 1.0627298431240209 | 1.0627298431240206 |
| Perturbed theta_e (K) | 348.1148670320586 | 348.1148670320585 |

The exponential result differs by 2.220446049250313e-16, one representable
increment at this magnitude. The forward numerator differs by
1.1368683772161603e-13 K, causing the previously observed
-8.426702044483925e-12 K/s MATLAB-minus-Fortran theta_e sink difference.
Both exponential-override variants make this point's numerator and sink
exactly equal. No claim is made about which library result is correctly
rounded, or which runtime library/compiler transformation produces it.

## Remaining point: equal inputs, different power result

After EPS alignment and main-exp substitution, the largest theta_e sink
error is record 500: the MATLAB-trajectory state at 96 s, ACE 1, level 110.
The base evaluation agrees exactly. For the perturbed evaluation, the first
different recorded factor is the pressure power: the base and exponent
agree, while the result is 1.2023953529445408 in MATLAB versus
1.202395352944541 in Fortran. Subsequent products carry that difference to
348.8781778197536 versus 348.8781778197537 K. The sink discrepancy is
4.9960307158675166e-12 K/s. A power-result substitution was not run.

Across the entire set, remaining intermediate differences also include
saturation-pressure and humidity-power evaluation. Staging here preserves
the original order; it does not explore arbitrary reassociation, compiler
flags, scalar/vector library variants or alternative numerical formulations.
The observed main-exp effect is local to the matched-state probes; no new
trajectory, phase sweep, long run or conservation acceptance is claimed.

## Reproduce and next review

Use matching sources and the retained replay artifacts with a fresh directory:

```bash
python3 tests/alignment/isolate_forward_evaluation.py migration_work/forward_evaluation_repeat \
  --replay migration_work/mixed_residual_review
```

Final raw evidence is retained under ignored
`migration_work/forward_evaluation_exp_check/`. The initial four-variant
run is preserved in `forward_evaluation_review/`. The failed preliminary
override run in `forward_evaluation_exp_review/` is also preserved; its
lookup did not yet retain native handling of inactive-sink NaNs. Only the
corrected successful run supplies the numerical report.

Recommended next development: diagnose the precipitation finite-difference
sensitivity over a reviewed range of condensate increments and phase states,
before proposing any constant, derivative or tolerance change. The current
evidence supports sensitivity to near-roundoff forward evaluations; changing
EPS or merely staging the existing expression does not resolve it.

</details>

<a id="record-v018-ice-heat-capacity-alignment"></a>

<details>
<summary>docs/v018_ice_heat_capacity_alignment.md</summary>

# v0.18 ice heat-capacity reference alignment

The developer authorized proceeding with the ice heat-capacity alignment
after reviewing the [forward-thermodynamic comparison](#record-v018-aligned-runtime-comparison).
This is a separate scientific follow-up to Steps 1–3. It changes only the
Fortran `Ci` reference temperature to the active MATLAB `ci.m` reference.

## Exact change and impact

In `fortran/active/src/ace_module.F`, lines 600–601:

```diff
-real, parameter :: T0=273.1636783445389
+!real, parameter :: T0=273.1636783445389
+real, parameter :: T0=273.15
```

The old statement remains as a comment. The Ci equation remains
`2106+7.3*(T-T0)`. At the model triple-point temperature
273.1636783445389 K, both implementations now return
2106.099851915134 J/(kg K), instead of Fortran's former 2106.

The only active caller is the forward `theta_e` ice exponent
`gammi=(Cl-Ci(T0))*qi/Cpl`. This exponent changes when qi>0; its factor
`(T0/T)^gammi` is unity at T=T0 and unaffected when qi=0.
The model triple-point constant in `theta_e` and `inv_theta_e` is unchanged.
The inverse uses the already aligned `dC=2083.900148084866` directly.

Against parent source `92dbc8a`, the complete module equals the original
with exactly the Ci declaration replaced as shown. All other module bytes,
MATLAB sources, inverse equations, Newton decisions, precipitation smooth
activation, precipitation finite-difference equation, RK/splitting, clipping,
masks, initialization, and damping are unchanged. The precipitation theta_e
tendency can change through its calls to the corrected forward function;
preserving its finite-difference equation does not imply unchanged ice tendency.

## Verification on 2026-10-01

[Numerical evidence](../v018_ice_heat_capacity_alignment.json) pins the parent
commit plus production diff, current source/input hashes, build commands,
four complete trajectories, ten common physics probes and artifact hashes.
GNU Fortran 11.2.0 uses binary64 defaults and -O2; MATLAB is R2023b Update 9.
Both initialization and test access were rebuilt using the corrected source.
No accepted tolerance was introduced or adjusted.

All ten standalone warm/liquid/ice/mixed probes produce finite outputs.
Their Fortran inverse outputs and dqt are exactly unchanged from the
pre-Ci run. The saturated ice input is 250 K, 300 hPa and qi=0.001 kg/kg:

| Compared quantity | Before Ci alignment | After Ci alignment |
| --- | ---: | ---: |
| Absolute forward theta_e difference (K) | 3.113077582383994e-6 | 0 |
| Absolute precipitation dtheta_e difference (K/s) | 5.182225019982958e-9 | 9.473902998907713e-12 |
| Absolute precipitation dqt difference (kg/kg/s) | 0 | 0 |

Small finite-difference tendency differences remain; the result is not a
bitwise identity claim. The earlier coefficient-rounding and math-library
considerations remain documented in the term-by-term comparison.

The four single/multi-ACE dry/liquid-precipitating runs each complete thirty
4-second steps. Initial prognostic arrays agree exactly, all 31 stored state
samples and raw tendencies are finite, and qt remains positive. Both MATLAB
and Fortran trajectories are exactly unchanged from their respective pre-Ci
trajectories. This is expected for the liquid/dry configurations and does
not test an evolving ice-precipitating column.

Across all four cases and all stored samples, maximum MATLAB–Fortran errors
remain 1.9326762412674725e-11 K for theta_e,
1.5005358067199381e-15 kg/kg for qt, and
1.8459261896808243e-12 kg/m2/s for MF. Detailed relative and absolute metrics
are in the JSON; source equality outside Ci is verified separately from
numerical agreement.

The earlier pure-ice endpoint branch mismatch, reference-Tv difference,
boundary behavior, and geometry rounding remain unresolved. No sweep,
long production run, Intel comparison, or closed conservation pass was run.

## Reproduce and next check

Build the current Fortran driver in a fresh workspace using the recorded
compiler commands, then run:

```bash
python3 tests/alignment/run.py migration_work/ice_heat_capacity_repeat \
  --precip --model migration_work/ice_heat_capacity_build/ace_model.exe
python3 tests/alignment/report.py migration_work/ice_heat_capacity_repeat \
  migration_work/ice_heat_capacity_repeat/review.json \
  --build migration_work/ice_heat_capacity_build
```

Raw evidence is retained in ignored `migration_work/ice_heat_capacity_run/`.
Its `production_change.patch` and `change_scope.json` record the approved
source delta; the JSON report additionally compares the retained pre-Ci
outputs. The old `compare_ice_forward.py` diagnostic belongs to the recorded
pre-Ci source and is not required for this corrected-source validation.

Recommended next work: a matched ice-precipitating trajectory to exercise the
corrected forward function during repeated microphysics updates.

</details>

<a id="record-v018-ice-precipitation-comparison"></a>

<details>
<summary>docs/v018_ice_precipitation_comparison.md</summary>

# v0.18 ice-precipitating trajectory comparison

Executed on 2026-10-01 using committed production source `1ac8d27` on
`feature/shared-netcdf-input`, after the approved ice heat-capacity correction.
Only validation tools and documentation changed during this work.
[Machine-readable evidence](../v018_ice_precipitation_comparison.json) preserves
input/source hashes, build commands, raw/diagnostic metrics, and artifact hashes.
The earlier [ice heat-capacity report](#record-v018-ice-heat-capacity-alignment)
records the source correction and dry/liquid regression separately.

## Manufactured cold-column configuration

The shared Manus profile, eight ACEs, 801 stored levels, 50 m spacing, full
PMB, dt=4 s, disabled MF diffusion, existing masks and damping are retained.
Single mode uses the existing tendency mask and a surface MF pulse in ACE 1;
multi mode uses the default pulse in ACE 8. The common starting state is
exported once by MATLAB in binary64 and loaded by Fortran.

Only the pulse ACE's theta_e and qt at levels 151–170 are perturbed:
levels 151–156 prescribe qi=0.00049 kg/kg, 157–163 prescribe 0.00050,
and 164–170 prescribe 0.00051. The temperature comes from the current inverse
of the original state at each level. Vapor is computed as
`eval_qsi(T,p)*(1-qi)`, and the shared theta_e and qt are recomputed with
ql=0. These are manufactured ice-onset tests, not replacement soundings.

The selected pressures range about 35000.45–39774.80 Pa; construction checks
T<263.15 K, ice saturation pressure below p, and theta_e<=400 K.
The cold interval is well away from the previously reported pure-ice endpoint
counterexample. Initial temperature is about 250.57–256.59 K.
Input geometry, pressure, reference profiles and all other initial levels
are retained. The surface MF pulse starts below these levels; buoyancy and
nonlocal coupling subsequently affect the manufactured cloud.

The current compiled Fortran initialization executable was reused from the
Ci-correction build; the validation Fortran module was freshly compiled
from the same current source. GNU Fortran 11.2.0 uses -O2 and default
binary64 flags; MATLAB is R2023b Update 9. Binary64 comparison dumps avoid
production real*4 output rounding. The existing validation access skips
unavailable plotting/plume/radiation diagnostics and uses the actual local
MATLAB time-integration routines. The generated access diff is recorded.

## Complete-step and trajectory results

Both codes retain the stage-1 pre-dynamics thermodynamic cache, complete all
nine SSPRK93 dynamics stages, apply precipitation once with dt, clip qt,
and apply existing damping. No post-dynamics thermodynamic inversion was
introduced. This source call order is exercised by the runs; runtime call
counters were not added.

Initial theta_e, qt and MF agree exactly in both cases. Each run completes
thirty steps; all 31 stored states and raw tendencies are finite. qt remains
positive, so these cases do not activate negative-qt clipping.

Maximum absolute differences over levels and ACEs:

| Case | Time (s) | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: | ---: |
| single_ice_precip | 4 | 2.614797e-12 | 2.385245e-18 | 3.706822e-14 |
| single_ice_precip | 60 | 1.801936e-11 | 5.789640e-16 | 5.806640e-13 |
| single_ice_precip | 120 | 1.978151e-11 | 2.235408e-15 | 1.337777e-12 |
| multi_ice_precip | 4 | 2.614797e-12 | 3.469447e-18 | 1.216545e-14 |
| multi_ice_precip | 60 | 1.045919e-11 | 1.101549e-16 | 1.701521e-13 |
| multi_ice_precip | 120 | 1.222134e-11 | 3.256943e-16 | 2.088607e-13 |

Maximum absolute differences across all 31 time samples:

| Case | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: |
| single_ice_precip | 2.546585e-11 | 2.235408e-15 | 1.337777e-12 |
| multi_ice_precip | 1.688250e-11 | 3.256943e-16 | 2.100334e-13 |

Absolute, relative L2, nonzero-reference relative, zero-reference, RMS and
worst-location metrics are preserved in JSON. No equivalence tolerance was
introduced or loosened. At 120 s the maximum inverted T errors are
1.04308e-11 K (single) and 6.42331e-12 K (multi); maximum qi errors are
2.95423e-15 and 1.06946e-15 kg/kg respectively.

## Evidence that ice microphysics is exercised

At diagnostic times 0, 4, 60 and 120 s, both implementations diagnose ql=0
and qi>0 at every prescribed cloud level. Single-mode sampled cloud
T is about 250.49–256.59 K and qi about 0.00043303–0.00051 kg/kg;
multi-mode T is about 250.55–256.59 K and qi about
0.00047675–0.00051 kg/kg. Intermediate unsampled phase transitions are not
ruled out by these four diagnostics.

An additional read-only MATLAB analysis checks actual state slot 5, the
positive cumulative precipitation loss. Its initial value is exactly zero,
it increases monotonically, and all thirty updates have positive loss
somewhere. At the prescribed levels the 120-second accumulated specific
humidity removal ranges:

| Case | Minimum removed qt (kg/kg) | Maximum removed qt (kg/kg) |
| --- | ---: | ---: |
| single_ice_precip | 3.782771735751030e-6 | 6.875996833559302e-6 |
| multi_ice_precip | 4.194798459602757e-6 | 7.443945773322451e-6 |

These quantities are precipitation-only accumulators, not the entire qt
change, which includes dynamics. Fortran's three-variable comparison state
has no corresponding precipitation accumulator; this is not a matched
sink-budget or closed-conservation test. Fortran ice diagnosis and trajectories
are compared directly, and its existing post-step sink call is retained.

## Remaining limits

The original reference-Tv/initial buoyancy difference remains: the initial
buoyancy error is 6.19340e-10 m/s2. Boundary/geometry rounding and the prior
1200-case pure-ice endpoint mismatch are unchanged. Small forward finite-
difference tendency rounding remains after the Ci correction. The ten
standalone physics probes were also replayed and all outputs are finite.

This validates two cold, pure-ice manufactured trajectories for 120 seconds.
It does not establish general model equivalence, a mixed-phase trajectory,
a long production run, Intel/GNU agreement or a conservation acceptance.
No sweep or unrelated scientific modification was performed.

## Reproduce

With the current Fortran model compiled and license access available, use a
fresh work directory:

```bash
python3 tests/alignment/run.py migration_work/ice_precipitation_repeat \
  --experiments ice_precip \
  --model migration_work/ice_heat_capacity_build/ace_model.exe
matlab -batch "addpath('tests/alignment'); matlab_ice_evidence('migration_work/ice_precipitation_repeat');"
python3 tests/alignment/report.py migration_work/ice_precipitation_repeat \
  migration_work/ice_precipitation_repeat/review.json \
  --build migration_work/ice_heat_capacity_build \
  --cases single_ice_precip multi_ice_precip
```

The existing default dry mode and `--precip` dry/liquid behavior remain
available. `--experiments` selects particular cases and cannot combine with
`--precip`. Report aggregation for ice cases requires the separate
`matlab_ice_evidence` analysis first. Raw results from this run are retained
in ignored `migration_work/ice_precipitation_run/`.

Recommended next work: review a mixed-phase trajectory with an explicitly
chosen distance from the known endpoint ambiguity, before selecting any
broader scientific equivalence tolerances.

</details>

<a id="record-v018-mixed-precipitation-comparison"></a>

<details>
<summary>docs/v018_mixed_precipitation_comparison.md</summary>

# v0.18 mixed-phase precipitation trajectory comparison

Executed on 2026-10-01 at repository commit `732e2c8`, using production
sources unchanged from the approved Ci correction `1ac8d27`. Only test tools
and documentation change in this task. [Numerical evidence](../v018_mixed_precipitation_comparison.json)
pins source/input hashes, builds, trajectory diagnostics and raw artifacts.
This extends the [pure-ice trajectory check](#record-v018-ice-precipitation-comparison).

## Interior mixed-phase construction

Both runs retain the common Manus input, eight ACEs, 801 stored levels,
dz=50 m, dt=4 s, full PMB, disabled MF diffusion, and existing damping/masks.
Single mode uses the existing single-ACE tendency mask and surface MF pulse
in ACE 1; multi mode uses the default pulse in ACE 8.

At levels 91–110 of the pulse ACE, prescribe the model
T0=273.1636783445389 K and total condensate qc=0.00049 (91–96),
0.00050 (97–103), or 0.00051 (104–110) kg/kg. Initially ql=qi=qc/2.
Pressure is retained from the original profile, ranging 51930.44–58508.86 Pa.
All other initial levels and reference fields are retained.
This is a manufactured cloud, not a reconstructed mixed-phase Manus sounding.

At T0, match the inverse's mean liquid/ice saturation diagnosis by solving

```
s = 0.5*0.621971830985916*(es/(p-es) + esi/(p-esi))
qv = s/(1+s)*(1-qc)
qt = qv+qc
```

The current MATLAB forward theta_e generates theta_e from this state. Inputs
are exported once in binary64 and read by Fortran, ensuring exactly identical
initial prognostic fields. Construction asserts es and esi below p,
theta_e<=400 K, diagnosed T=T0, and positive liquid/ice in MATLAB.

Each constructed state's initial diagnosed ice fraction is about 0.5,
with min/max 0.4999999999995609/0.5000000000004663. The normalized decision
position `(G0-min(GT0,HT0))/abs(GT0-HT0)` ranges
0.4999243800773675–0.4999272628938396. Both fraction and decision position
must be between 0.25 and 0.75. These restrictions select an interior test
fixture; they are not production tolerances or changed phase-selection rules.
The production strict comparisons and the earlier endpoint counterexample
remain unchanged.

## Dynamics–microphysics comparison

MATLAB R2023b Update 9 and GNU Fortran 11.2.0 use binary64 comparison outputs;
Fortran flags retain -O2 and default-real-8/default-double-8. The validation
module was freshly compiled, while the initialization executable from the
unchanged Ci-correction build was reused. Test-only Fortran access and exact
copies of active MATLAB local dynamics routines follow the existing runner.
Plotting/plume/radiation diagnostics are skipped as previously documented.

Both implementations use the pre-dynamics stage-1 thermodynamic cache,
finish all nine SSPRK93 dynamics stages, apply precipitation once using dt,
clip qt, then apply damping. No post-dynamics inversion or phase rule change
is introduced. Runtime stage-call counters were not added.

Both runs complete thirty steps, with all 31 stored prognostic samples and
raw tendencies finite. qt remains positive; negative clipping is not activated.

Maximum absolute differences across levels and ACEs:

| Case | Time (s) | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: | ---: |
| single_mixed_precip | 4 | 4.320100e-12 | 1.190454e-15 | 4.217127e-12 |
| single_mixed_precip | 60 | 4.289973e-10 | 1.230890e-13 | 6.209500e-11 |
| single_mixed_precip | 120 | 1.241744e-09 | 3.622424e-13 | 1.138232e-10 |
| multi_mixed_precip | 4 | 1.705303e-12 | 2.151057e-16 | 1.370758e-12 |
| multi_mixed_precip | 60 | 1.573426e-10 | 4.360531e-14 | 1.982065e-11 |
| multi_mixed_precip | 120 | 4.349658e-10 | 1.225972e-13 | 3.457579e-11 |

Maximum absolute differences across all 31 stored time samples:

| Case | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: |
| single_mixed_precip | 1.241744e-09 | 3.622424e-13 | 1.138232e-10 |
| multi_mixed_precip | 4.349658e-10 | 1.225972e-13 | 3.457579e-11 |

Relative L2, nonzero-reference relative, zero-reference, RMS, and worst-index
metrics are preserved in JSON. These errors are larger than the pure-ice
trajectory errors but remain quantitatively small for these cases. No
acceptance tolerance has been set or loosened, and small errors alone do
not establish general scientific equivalence.

## Phase evolution and matched-input diagnosis

Four full-domain thermodynamic snapshots are available at 0,4,60,120 s.
An additional read-only diagnostic examines all 31 samples at the twenty
prescribed levels in each trajectory, calling actual current inverse
routines without changing the equations or repeating time integration.

For every sampled time, the MATLAB and Fortran own-trajectory liquid/ice
presence masks match at all prescribed levels. Mixed-phase counts evolve:

| Time (s) | Single mixed levels | Multi mixed levels |
| ---: | ---: | ---: |
| 0–12 | 20 | 20 |
| 16 | 16 | 20 |
| 20 | 4 | 20 |
| 24 | 1 | 20 |
| 28 | 0 | 19 |
| 32,36 | 0 | 19 |
| 40 | 0 | 16 |
| 44 | 0 | 6 |
| 48 | 0 | 4 |
| 52 | 0 | 2 |
| 56–120 | 0 | 0 |

The first stored output with no mixed selected level is 28 s in single mode
and 56 s in multi mode. Exact continuous transition times are not resolved
by 4-second sampling. These tests exercise mixed microphysics initially,
then natural pure-phase evolution; they are not 120-second persistently
mixed-phase tests. No forcing or model rule was added to hold the phase fixed.

To distinguish trajectory drift from inverse disagreement, each case's 620
MATLAB and 620 Fortran selected-level state triples are diagnosed by both
inverse routines. These 1240 pairs per case reuse trajectory states, not
1240 unique manufactured conditions or a parameter sweep. All outputs are
finite real and no common-input phase-presence mismatch is found. Maximum
absolute differences are:

| Case | T (K) | qv (kg/kg) | ql (kg/kg) | qi (kg/kg) |
| --- | ---: | ---: | ---: | ---: |
| Single | 5.68434e-14 | 5.03070e-17 | 1.85344e-16 | 1.85344e-16 |
| Multi | 5.68434e-14 | 5.20417e-17 | 1.85290e-16 | 1.85290e-16 |

Relative differences for nonzero references are reported without replacing
zero denominators by arbitrary floors. Small condensate denominators produce
larger relative errors even with tiny absolute differences. Maximum water
closure error is 8.67362e-19 kg/kg in each implementation. No iteration
instrumentation or iteration-status identity claim is added by this probe.
Liquid/ice presence masks are physical phase classifications, not recorded
internal inversion branch IDs; identical masks do not certify branch identity.

MATLAB's actual precipitation accumulator begins at zero, is monotonic, and
shows positive loss in all thirty updates. At the prescribed levels, final
precipitation-only qt removal ranges from 4.8113e-7 to 3.7430e-5 kg/kg in
single mode, and 9.1951e-7 to 8.9347e-6 kg/kg in multi mode. This is not the
entire qt change or a matched Fortran sink budget. No closed conservation
acceptance follows from the accumulator.

## Remaining differences and limits

The reference-Tv behavior, geometry rounding, undefined Fortran WENO
endpoints and upper-boundary reconstruction differences remain. The initial
buoyancy difference reaches 6.30120e-10 m/s2; this fixture introduces a larger
cloud buoyancy perturbation than the earlier cold-condensate fixture. Known
reference-state and floating-point evaluation differences remain possible
contributors to trajectory drift; this work does not isolate an exclusive
cause for every error. In particular, the common-input diagnosis does not
show a phase disagreement for these sampled states.

The earlier 1200-case endpoint mismatch is not resolved by choosing interior
inputs. No sweep, long production run, Intel/GNU equivalence, accepted model
tolerance, or scientific correction is introduced by this validation.

## Reproduce

Use a fresh workspace and the current compiled model:

```bash
python3 tests/alignment/run.py migration_work/mixed_precipitation_repeat \
  --experiments mixed_precip \
  --model migration_work/ice_heat_capacity_build/ace_model.exe
```

Compile `tests/alignment/fortran_phase_history.f90` against the generated
validation module and input objects to `phase_history.exe` in that workspace;
exact flags and link arguments are preserved in
`supplementary_phase_build_command` in the JSON. Then run from the root:

```bash
matlab -batch "addpath('tests/alignment'); matlab_mixed_evidence(pwd,fullfile(pwd,'migration_work/mixed_precipitation_repeat'));"
python3 tests/alignment/report.py migration_work/mixed_precipitation_repeat \
  migration_work/mixed_precipitation_repeat/review.json \
  --build migration_work/ice_heat_capacity_build \
  --cases single_mixed_precip multi_mixed_precip
```

`matlab_mixed_evidence` requires the probe executable and preserves its common
inputs and outputs. Report aggregation requires this supplementary analysis
first. Raw results are retained in ignored `migration_work/mixed_precipitation_run/`.
Default dry and existing liquid/ice experiment paths retain their behavior.

Recommended next work: review whether to isolate the existing reference-Tv
contribution in a temporary diagnostic before any scientific correction or
longer trajectory comparison.

</details>

<a id="record-v018-mixed-residual-diagnostic"></a>

<details>
<summary>docs/v018_mixed_residual_diagnostic.md</summary>

# v0.18 single mixed-case residual diagnostic

Executed on 2026-10-01 at `fdf4cd1`, after the approved environmental
reference-Tv correction. Production MATLAB/Fortran sources are unchanged.
[Numerical evidence](../v018_mixed_residual_diagnostic.json) records commands,
source/input/fixture hashes, temporary access patches, stream layouts,
per-variable metrics, signed process differences and artifact hashes.

## Finding

The largest retained theta_e trajectory difference is at ACE 1, level 110,
120 s: MATLAB minus Fortran is -1.363673618471e-10 K. Same-state replay
identifies precipitation's finite-difference theta_e sensitivity as a major
local source of discrepancy. Forward evaluation differences at binary64
rounding scale survive even on identical thermodynamic caches and are
amplified by division by the existing 1e-8 kg/kg condensate increment.
This is evidence of cancellation sensitivity, not approval to change the
increment, derivative formulation, constants or acceptance tolerances.

## Controlled replay

Reuse the freshly validated single mixed-case MATLAB and Fortran histories
from `migration_work/reference_tv_regression/`. Export both implementations'
30 pre-step states at 0,4,...,116 s, giving 60 identical-input comparisons.
Each input is the complete three-prognostic-field state of all eight ACEs
and all 801 levels. The fixed environment, density, reference Tv, geometry,
PMB, dt=4 s, masks and all existing numerical routines are retained.

MATLAB uses exact copies of active local functions, initialized through
the existing validation path. Fortran uses the existing diagnostic access
plus a temporary public thermodynamic cache and two writes in `ace_driver`:
after dynamics and after precipitation/clipping. No numerical expression
is changed. Each replay compares stage-1 raw tendency, diagnosed T/qv/ql/qi,
native sinks, base/perturbed forward theta_e, completed dynamics,
post-precipitation/clipping state and the final damped state.

A separate standalone sink probe replaces only the diagnostic Fortran
cache with MATLAB's diagnosed T/qv/ql/qi for that identical input. Its
forward values and sinks isolate evaluation from inversion. The actual
one-step driver then refreshes its own cache through its stage-1 inverse;
the shared-cache probe does not change the integrated replay.

MATLAB replays exactly reproduce every next state of its retained trajectory.
Fortran replays exactly reproduce every next state of its retained trajectory.
All replay output blocks are finite.
Both post-precipitation/clipping qt streams remain strictly positive,
with minimum 2.584753409969474e-6 kg/kg; zero clipping is not activated.
Fresh builds/reruns in
`mixed_residual_replay/` and `mixed_residual_review/` reproduce the same
block metrics. GNU Fortran 11.2.0 uses -O2, default-real-8/default-double-8;
MATLAB and the retained fixture use R2023b Update 9.

## Same-state local differences

Maximum absolute theta_e differences across the 30 identical inputs from
each source trajectory:

| Input-state source | Dynamics, full domain (K) | Dynamics, cloud levels 91–110 (K) | Native sink (K/s) | Sink on identical cache (K/s) | Final step (K) |
| --- | ---: | ---: | ---: | ---: | ---: |
| MATLAB | 2.273737e-13 | 5.684342e-14 | 6.989794e-12 | 5.998741e-12 | 2.796696e-11 |
| Fortran | 1.136868e-13 | 5.684342e-14 | 8.426702e-12 | 8.426702e-12 | 3.370815e-11 |

Native liquid/ice presence masks agree on all 60 common full-domain inputs.
This checks these states, not the unresolved endpoint counterexample or a
new parameter sweep. Per-variable norms and worst indices are recorded in
`components`; aggregate multi-variable block norms are stream diagnostics
and must not be interpreted as quantities with one physical unit.

At 116 s, ACE 1, level 110, using the **Fortran trajectory state** as the
common input, both inverses return exactly the same values:

| Quantity | Common value |
| --- | ---: |
| T (K) | 272.43407398942014 |
| qv (kg/kg) | 0.006917952001001371 |
| ql (kg/kg) | 0 |
| qi (kg/kg) | 0.0007223627354327978 |
| qt precipitation tendency (kg/kg/s) | -7.412205456458214e-7 |

The base forward theta_e is identical, 348.1148744264559 K. The perturbed
value is 348.1148670320586 K in MATLAB and 348.1148670320585 K in Fortran.
The finite-difference numerator therefore differs by 1.136868377216e-13 K.
Multiplication by the common qt sink and division by 1e-8 yield a theta_e
sink difference of -8.426702044484e-12 K/s. The 4-second precipitation
update adds -3.370814738446e-11 K to the same-state step difference.
Dynamics and damping add zero difference at this particular point.
The initial mixed-case fixture has evolved to pure ice here.

An **algebraic counterfactual**, using the actual shared-cache Fortran qt
sink but the MATLAB forward numerator, reduces maximum theta_e sink errors
to 5.421011e-20 K/s on MATLAB inputs and 1.084202e-19 K/s on Fortran inputs.
This reconstruction is not a modified model run or an integrated correction.

## Local evaluation versus accumulated drift

Using the **MATLAB trajectory state** at the same 116 s/level 110 point,
the inverses, forward values, sinks and final step instead agree exactly.
Thus the local discrepancy depends on the binary64 input state. It cannot
be represented as one fixed bias accumulated thirty times.

The final step's signed differences along the two separate native
trajectories telescope as follows:

| Contribution at level 110, 116–120 s | MATLAB minus Fortran (K) |
| --- | ---: |
| Incoming trajectory difference | -7.509015631513e-11 |
| Difference added during dynamics | -1.091393642128e-11 |
| Difference added during precipitation/clipping | -5.042011252954e-11 |
| Difference added during damping | +5.684341886081e-14 |
| Outgoing trajectory difference | -1.363673618471e-10 |

These are differences of sequential process outputs on each implementation's
own incoming state. They include propagated state sensitivity as well as
local implementation differences. They are not additive causal error budgets
or percentages attributable to physical processes. In particular, the
native-trajectory precipitation difference differs from the same-state
Fortran-input replay's -3.3708e-11 K. No exclusive explanation of every
trajectory discrepancy is claimed.

## Reproduce and next review

Use matching active sources/fixtures and a fresh directory:

```bash
python3 tests/alignment/replay_mixed_residual.py migration_work/mixed_residual_repeat \
  --baseline migration_work/reference_tv_regression
```

The runner checks production and input hashes, preserves generated source
and patches, asserts exact own-trajectory next-state reproduction, and
checks production hashes again afterward. Raw final evidence is under
ignored `migration_work/mixed_residual_review/`. The MATLAB initialization
and all generated diagnostic streams are preserved there.

The next small diagnostic should separate forward theta_e constant rounding
from expression/transcendental evaluation. One confirmed source distinction
is MATLAB's literal 0.621971830985916 versus Fortran's `Rd/Rv` in forward
theta_e; their binary64 values differ by four representable increments.
This distinction has not yet been isolated as the cause of the observed
numerator error. Do not silently replace it or redesign the precipitation
derivative based on this diagnostic.

Only this single manufactured cloud trajectory and its recorded states were
replayed. Boundary/WENO endpoints, geometry rounding, phase endpoints,
long runs, compiler equivalence, conservation acceptance and release
equivalence remain outside this diagnosis. No tolerance was introduced.

</details>

<a id="record-v018-phase-endpoint-proposal"></a>

<details>
<summary>docs/v018_phase_endpoint_proposal.md</summary>

# Phase-endpoint rule preview: not applied

The developer requested reviewing a consistent rule for atmospheric case 1106.
This review prepared a concrete [minimal proposed diff](../proposals/v018_phase_endpoint.patch)
and tested it only in temporary source copies. **No production code was
changed. The preview does not establish complete branch agreement and the
proposal is not recommended as a complete fix.**

## Candidate rule

For finite real G0, GT0 and HT0, define

```
phase_roundoff = 8*machine_epsilon*max(abs(G0),abs(GT0),abs(HT0))
liquid: G0-GT0 > phase_roundoff AND G0-HT0 > phase_roundoff
ice:    G0-GT0 < -phase_roundoff AND G0-HT0 < -phase_roundoff
otherwise: existing mixed branch
```

Invalid inputs retain a zero band and their existing decision path. The
proposed patch retains old comparisons as comments. It changes only the
phase-selection comparison, not saturation diagnosis, partition equations,
Newton tolerances/derivatives, clipping or dynamics. The coefficient 8 is an
engineering allowance, not a rigorous math-library error bound. It was not
increased after an adversarial neighbor exposed the new boundary problem.

The choice intentionally allocates a small region around pure-phase endpoints
to the existing mixed branch. This is a new scientific decision, not merely
an expression rewrite. User review/authorization would be needed before
applying a production rule.

## Preview results

`tests/thermodynamics/preview_phase_endpoints.py` replays the exact previously
accepted 1200 binary64 input triples from the CSV. It then appends eighteen
endpoint checks: original cases 1106 (ice endpoint) and 1101 (liquid endpoint),
with theta_e offsets of -64,-16,-8,-4,0,+4,+8,+16,+64 ULP while holding qt,p
fixed. These are repeat/nearby diagnostics, not eighteen additional unique
atmospheric samples or a sweep. Results are in
[preview evidence](../v018_phase_endpoint_preview.json).

All 1218 preview calls converge. On the original 1200, branch, iteration
and status mismatches become zero. Case 1106 yields exactly equal outputs
and mixed-branch decisions. Original case 1126 switches from ice to mixed
in both implementations; this is an additional behavior change to report,
not silently dismiss.

However, one neighboring input remains different: case 1106 theta_e minus
8 ULP. MATLAB selects mixed phase; Fortran selects ice. The finite band's
edge still has a strict comparison, and underlying arithmetic differences
can straddle that edge. Moving an uncertain threshold does not guarantee
identical discrete decisions for every possible binary64 input. Other
neighbors match, including clear pure-phase states outside the band.

## Pinpointed arithmetic difference

An additional trace of the original production formula for case 1106 gives:

| HT0 factor | MATLAB | Fortran |
| --- | ---: | ---: |
| qsi | 0.0036518989678712413 | same binary64 value |
| R | 287.67633849773279 | same binary64 value |
| R^chi | 4.9117944253254695 | 4.9117944253254704 |
| Lv(T0) | 2500968.2662406699 | same binary64 value |
| Exponential argument | 0.032862178184967387 | same binary64 value |
| exp(argument) | 1.0334081032456786 | same binary64 value |

The recorded power differs by one ULP, producing the differing HT0 and
strict phase comparison. The particular library/compiler implementation
behind power rounding has not been attributed. G0 and its recorded factors
match. This is not a single/double precision mismatch in the tested builds.

## Next decision

The tested finite band improves the original 1200 decisions but does not
satisfy universal branch identity. Do not apply it as if it solved that
stronger objective, and do not tune the factor solely to clear the eighteen
neighbors. First clarify whether validation requires bitwise/discrete branch
identity or physically consistent outputs within justified numerical accuracy.
If branch identity is mandatory across all inputs, further investigation of
shared deterministic elementary-function arithmetic would be necessary;
that would be a larger implementation decision and is not authorized here.
Existing fixed atmospheric output differences remain fully reported.

</details>

<a id="record-v018-pressure-power-diagnostic"></a>

<details>
<summary>docs/v018_pressure_power_diagnostic.md</summary>

# v0.18 pressure-power diagnostic

Executed on 2026-10-01 with production sources at `afa0b24`. This extends
the [forward evaluation diagnostic](#record-v018-forward-evaluation-diagnostic).
Production MATLAB/Fortran code, constants, inversion and precipitation
equations are unchanged. [Numerical evidence](../v018_pressure_power_diagnostic.json)
records commands, hashes, metrics, intermediate difference counts and worst
records. No acceptance tolerance is imposed.

## Findings

A fresh six-variant forward run exactly reproduces every per-variant report
in the retained forward diagnostic JSON. In a further temporary Fortran
probe, replacing the pressure-power result for identical base/exponent inputs
confirms the previously identified pressure-power contribution. At record
500 (MATLAB trajectory, 96 s, ACE 1, level 110), the replacement removes the
sink discrepancy. When combined with the earlier EPS-literal and main-exp
substitutions, all 52 recorded base/perturbed intermediates at that point
also agree exactly.

Across all 1200 records, the combined diagnostic reduces the maximum theta_e
sink difference from 4.996031e-12 to 5.956591e-14 K/s. The new worst point's
first recorded difference is ice saturation vapor pressure, propagated
through the humidity power into the perturbed theta_e evaluation. This
localizes the remaining discrepancy; it does not identify which internal
log/exp operation, runtime library or compiler transformation causes it.

## Controlled substitutions and results

Use the same 1200 matched binary64 T/qv/ql/qi/p records: ACE 1, levels
91–110, 30 pre-step states from each native trajectory. This set includes
1120 unique input tuples and 1168 records with positive condensate.
No inversion or time integration is performed. The condensate increment
remains 1e-8 kg/kg, with the existing liquid/ice partition.

The pressure lookup stores MATLAB pressure base, exponent and result from
both native forward calls. Only exactly equal finite base/exponent inputs
can select a result; an unrecorded finite pair stops the probe. Nonfinite
inputs retain native evaluation for inactive sinks. Each repeated pair is
checked for a unique result. Only the forward pressure power and its trace
are substituted. Inverse and subsequent production routines remain
byte-identical to each prepared parent variant.

| Variant | Numerator max difference (K) | theta_e sink max difference (K/s) | Exact numerators | Exact sinks |
| --- | ---: | ---: | ---: | ---: |
| Native control | 1.705303e-13 | 8.426702e-12 | 1007 | 950 |
| Pressure-power substitution | 1.136868e-13 | 8.426702e-12 | 1149 | 1087 |
| EPS literal + main-exp control | 1.136868e-13 | 4.996031e-12 | 1050 | 989 |
| EPS literal + main-exp + pressure-power substitution | 5.684342e-14 | 5.956591e-14 | 1199 | 1133 |

Both freshly compiled controls reproduce their parent output arrays exactly.
Pressure substitution alone removes record 500's discrepancy but leaves the
earlier main-exp worst point. Substitutions are diagnostic interventions,
not additive error budgets or approved model corrections. Counts include
inactive sinks and duplicate inputs; they are not acceptance rates.
Maximum qt sink differences remain 5.293956e-23 kg/kg/s in every variant.
In the combined variant, 66 records have equal numerators but unequal theta_e
sinks, consistent with rounding in the sink evaluation after the numerator.
They are separate from the single remaining unequal numerator.

## Remaining worst point

Record 1007 is the Fortran-trajectory state at 80 s, ACE 1, level 97:
T=272.72360943725766 K, qv=0.0065288364584465 kg/kg, ql=0,
qi=0.000449751297778871 kg/kg, p=56362.86157030448 Pa.

| Intermediate | MATLAB | Combined Fortran probe |
| --- | ---: | ---: |
| Ice saturation pressure (Pa), both calls | 589.566454053634 | 589.5664540536341 |
| Perturbed humidity power base | 0.999999990035061 | 0.9999999900350612 |
| Perturbed humidity power result | 0.9999999999707906 | 0.9999999999707907 |
| Perturbed theta_e (K) | 339.71265322297734 | 339.7126532229774 |
| theta_e sink (K/s) | 7.221502786222827e-06 | 7.2215027266569166e-06 |

The base theta_e agrees exactly. The perturbed difference is
5.684341886080802e-14 K. Across the set, 184 base and 184 perturbed saturation
pressures differ. Only two perturbed humidity-power results differ, and only
one carries into the final perturbed theta_e. MATLAB `eval_esi` and Fortran's
ice branch of `eval_es` use the same displayed constants and expression;
textual agreement alone cannot establish floating-point equivalence. No
saturation-result substitution or internal log/exp trace was performed.

## Reproduction and scope

GNU Fortran 11.2.0 uses `-O2 -ffree-form -fdefault-real-8
-fdefault-double-8 -ffree-line-length-none`; MATLAB is R2023b Update 9.
Use fresh directories, preserving existing evidence:

```bash
python3 tests/alignment/isolate_forward_evaluation.py migration_work/forward_repeat \
  --replay migration_work/mixed_residual_review
python3 tests/alignment/isolate_pressure_power.py migration_work/pressure_repeat \
  --forward migration_work/forward_repeat
```

The second command reuses the verified MATLAB artifact from the first;
it does not invoke MATLAB again. It verifies production, input, probe and
parent-artifact hashes, compiler version, exact controls, finite outputs
and unchanged production hashes after execution. Generated sources, patches,
driver, binaries and logs remain under ignored `migration_work/`.
The reported final run is `pressure_power_check/`, consuming
`forward_evaluation_recheck_native/`; `pressure_power_review/` preserves the
initial successful power experiment. The initial sandbox forward attempt
(`forward_evaluation_recheck/`) failed because MATLAB could not write its
preferences directory; the fresh successful run used authorized execution
outside the sandbox. Failed evidence was preserved.

These results cover matched-state probes only. They do not establish
trajectory agreement, phase-boundary behavior, conservation or release
equivalence, nor decide which runtime result is correctly rounded.
Recommended next development: review a condensate-increment and phase-state
sensitivity experiment before proposing changes to derivatives, constants
or acceptance tolerances.

</details>

<a id="record-v018-reference-tv-alignment"></a>

<details>
<summary>docs/v018_reference_tv_alignment.md</summary>

# v0.18 environmental reference virtual-temperature alignment

Validated on 2026-10-01 from parent commit `18f7333` with the production
change described here. [Numerical evidence](../v018_reference_tv_alignment.json)
records the working-source hashes, commands, build/artifact hashes, all-sample
metrics, phase diagnostics and limitations. Historical sources are preserved.

## Scientific contract and implementation

The common environmental buoyancy reference is the fixed input `Tv_zc`,
used alongside input `rho_zc`. MATLAB already follows this contract.
Fortran previously read input Tv but instead inverted environmental
theta_e/qt/p and calculated reference Tv in each tendency call. Its output
driver also reconstructed reference Tv from initial ACE row 1.

The active Fortran `ace_initialization` now requires `environment_tv(nz)`
after `fname`, before optional `netcdf_input`, and stores a private copy.
`ace_tendency` uses this profile directly; it no longer re-inverts the
environment solely to construct the buoyancy reference. Both netCDF and
legacy binary driver paths pass the loaded `Tv_e` and use it for output
buoyancy. The test driver reads the input reference explicitly, including
when reusing older initialization dumps. All repository callers were updated.
External callers must supply the new argument. An environment supplied with
changed theta_e/qt/p does not implicitly change this fixed reference.

This is a scientific reference-state change. It leaves the prognostic-state
inverse, condensate partition, input density/pressure, entrainment values,
constants, PMB, RK order, precipitation, clipping, damping, geometry and
boundary rules unchanged. MATLAB production source is unchanged.

## Fresh regression evidence

The complete production driver and isolated validation module were freshly
built with GNU Fortran 11.2.0, -O2, -fdefault-real-8 and
-fdefault-double-8. MATLAB R2023b Update 9 was freshly run for all eight
cases; retained MATLAB trajectories were not substituted for these runs.
Each case has eight ACEs, 801 stored levels, dt=4 s and 30 updates, with
31 samples covering 0–120 s. The existing single-ACE mask, fixture
construction and diagnostic access are retained.

All initial prognostic fields agree exactly. Reference Tv agrees exactly
in all eight cases. All prognostic samples are finite and qt remains positive.
The initial buoyancy maximum difference is 3.708173e-15 m/s2 in every case.

Maximum absolute differences over all levels, ACEs and all 31 samples:

| Case | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: |
| single | 1.591616e-12 | 5.204170e-18 | 7.075680e-15 |
| single_precip | 1.921308e-11 | 3.885781e-16 | 5.547507e-13 |
| single_ice_precip | 2.103206e-11 | 7.658804e-16 | 5.705054e-13 |
| single_mixed_precip | 1.363674e-10 | 1.252470e-15 | 8.864021e-13 |
| multi | 1.818989e-12 | 6.938894e-18 | 3.472121e-15 |
| multi_precip | 2.302158e-11 | 6.938894e-16 | 1.904449e-13 |
| multi_ice_precip | 2.290790e-11 | 1.474515e-16 | 8.530503e-14 |
| multi_mixed_precip | 1.472245e-11 | 1.908196e-16 | 7.049916e-14 |

RMS, relative L2, nonzero-reference relative errors, worst indices, and
0/4/60/120 s diagnostics are retained in JSON without an acceptance tolerance.
The `dry` runner option means the existing unperturbed fixture; it does not
assert condensate is absent everywhere during integration.

Both mixed-phase production Fortran prognostic histories are exactly equal
to the earlier paired shared-Tv variant across all 31 samples. A direct
binary comparison checked the initial state and every post-step state.
The fresh production initialization dump's reference Tv also exactly equals
the shared input profile. These checks connect the deployed source change
to the controlled intervention; they do not establish general equivalence.

Supplementary ice diagnostics confirm pure-ice condensate at the prescribed
levels at 0/4/60/120 s. For both mixed-phase cases, own-trajectory phase masks
agree at all prescribed levels across all 31 samples, and the 1240 paired
common-input diagnoses per case have no phase-mask disagreement. MATLAB
precipitation accumulation is monotonic and active in all 30 updates for
the ice and mixed cases. These are diagnostics, not closed water budgets.

## Reproduce and limitations

Raw successful results are retained under ignored
`migration_work/reference_tv_regression/`, with the production build in
`migration_work/reference_tv_build/`. The failed sandbox-only startup is
separately preserved in `migration_work/reference_tv_alignment/`.
Production build commands are included in JSON; execute them in a fresh
build directory with the recorded netCDF flags/library paths.

```bash
python3 tests/alignment/run.py migration_work/reference_tv_repeat \
  --experiments dry precip ice_precip mixed_precip \
  --model migration_work/reference_tv_build/ace_model.exe
```

Compile `tests/alignment/fortran_phase_history.f90` against the generated
validation module/input objects into `phase_history.exe`, using the recorded
`supplementary_phase_build_command`, and preserve that command as
`phase_build_command.json`. Then run:

```bash
matlab -batch "addpath('tests/alignment'); matlab_ice_evidence(fullfile(pwd,'migration_work/reference_tv_repeat')); matlab_mixed_evidence(pwd,fullfile(pwd,'migration_work/reference_tv_repeat'));"
python3 tests/alignment/report.py migration_work/reference_tv_repeat \
  migration_work/reference_tv_repeat/review.json \
  --build migration_work/reference_tv_build \
  --reference-tv-baseline migration_work/reference_tv_paired \
  --cases single single_precip single_ice_precip single_mixed_precip \
          multi multi_precip multi_ice_precip multi_mixed_precip
```

Legacy binary loading was compiled but could not be run: the original input
files remain unavailable. Intel/GNU equivalence, long runs and changing
environment configurations were not tested. The known phase-endpoint
counterexample, undefined WENO endpoints, upper-boundary reconstruction and
geometry/evaluation differences remain unresolved. No release-equivalence
or closed conservation acceptance is claimed.

Recommended next development: isolate the remaining single mixed-case
theta_e discrepancy using identical states and the now-common reference Tv,
before adjusting any thermodynamic, boundary or numerical rule.

</details>

<a id="record-v018-reference-tv-diagnostic"></a>

<details>
<summary>docs/v018_reference_tv_diagnostic.md</summary>

# v0.18 reference virtual-temperature diagnostic

Executed on 2026-10-01 at `c39d83e`. This is a paired temporary-source
experiment, not an approved scientific correction. Production MATLAB and
Fortran sources remain unchanged. [Numerical evidence](../v018_reference_tv_diagnostic.json)
records commands, source/input/fixture hashes, generated patch and executable
hashes, raw tendencies, all-sample metrics, and snapshots at 0,4,60,120 s.

## Question and controlled substitution

MATLAB uses the common input's `Tv_zc`. Fortran `ace_tendency` re-inverts
the environmental theta_e/qt/p and computes reference Tv from its diagnosed
T/q/ql/qi at every tendency call. The environmental row stays fixed in these
cases. The resulting reference-Tv maximum difference is 1.840533e-8 K.

Reuse the previously reviewed single/multi mixed-phase fixtures, each with
8 ACEs, 801 stored levels, dt=4 s, and 30 updates. The control recompiles
current Fortran with existing validation access. The paired variant adds
an isolated setter and replaces only local tendency Tv0 with the unchanged
MATLAB fixture's binary64 reference profile. Its existing inversion call is
retained. No prognostic or environmental theta_e/qt, thermodynamic equation,
Ci reference, precipitation equation, RK/splitting, clipping, mask, PMB,
geometry, damping, or boundary rule is changed.

The test driver also corrects its *diagnostic* reference: the control's
initial buoyancy output uses the actual reinverted tendency reference instead
of merely the initialization dump. The variant's buoyancy output uses the
substituted reference. This diagnostic correction changes no integrated
state. Driver diffs for both variants and the module substitution patch
are preserved in the raw workspace.

MATLAB is not rerun: both variants compare against the identical retained
MATLAB trajectory. Production and input hashes are checked against the
fixture configuration before execution and production hashes again afterward.
GNU Fortran 11.2.0 uses -O2, default-real-8 and default-double-8, matching the
retained validation; MATLAB fixture version is R2023b Update 9.

## Results

Both fresh control histories exactly reproduce their retained Fortran
histories across all 31 prognostic samples. Control/variant initial
prognostic fields are exactly identical. All histories and initial raw
tendencies are finite; qt remains positive (minimum about 2.5845e-6 kg/kg).
The shared-reference profiles match MATLAB exactly.

Across both cases, initial buoyancy maximum difference decreases from
6.301195e-10 to 3.708173e-15 m/s2. Initial theta_e and qt raw tendencies
are exactly unchanged between the paired Fortran runs. Initial MF tendency
maximum MATLAB–Fortran difference decreases from 1.054490e-12 to
6.938894e-17 (single) and from 3.427449e-13 to 1.821460e-17 (multi),
in kg/m2/s2. This connects the substitution to the buoyancy/pressure response
before later trajectory differences develop.

Maximum absolute MATLAB–Fortran differences over all levels, ACEs and 31 samples:

| Case | Variable | Original reference | Shared reference | Reduction of maximum |
| --- | --- | ---: | ---: | ---: |
| single_mixed_precip | theta_e | 1.241744e-09 | 1.363674e-10 | 89.018% |
| single_mixed_precip | qt | 3.622424e-13 | 1.252470e-15 | 99.654% |
| single_mixed_precip | MF | 1.138232e-10 | 8.864021e-13 | 99.221% |
| multi_mixed_precip | theta_e | 4.349658e-10 | 1.472245e-11 | 96.615% |
| multi_mixed_precip | qt | 1.225972e-13 | 1.908196e-16 | 99.844% |
| multi_mixed_precip | MF | 3.457579e-11 | 7.049916e-14 | 99.796% |

Units are K for theta_e, kg/kg for qt and kg/m2/s for MF. These reductions
compare maxima, potentially at different indices; they are not additive
error budgets or percentages of physical processes. Full RMS, relative L2,
nonzero-reference relative errors and worst indices are retained in JSON.
No denominator floor or acceptance tolerance is introduced.

## Source comparison: environmental reference-state contract

Reviewed against active sources at `c39d83e` on 2026-10-01. This review
does not change either production implementation.

The paired experiment was independently rerun with fresh builds under
`/tmp/ace-reference-tv-review-20261001` using the same retained MATLAB
fixtures. Every case result in the new `results.json` exactly matches the
retained report's `cases` object, including control reproduction, initial
state checks, and numerical metrics. The runner's production/input hash
checks passed. This is a Fortran rerun, not a new MATLAB run.

| Reference-state component | MATLAB | Fortran |
| --- | --- | --- |
| Shared-input loading | `ace.m:206,262` retains input `Tv_zc` | `ace_input.F:110` reads the same field; `test.F:213` stores it in `Tv_e` |
| Buoyancy reference | `NONLOCAL_RESPONSE`, `ace.m:615–618`, uses fixed `Tv_zc` | `ace_tendency`, `ace_module.F:173–174`, inverts environmental `X(ncols+1,:,1/2/10)` and constructs local `Tv0` on every call |
| Density reference | Input `rho_zc` | Input `rho_zc` stored in `X(:,:,4)`; not recomputed from local `Tv0` |
| Environment evolution | Global environmental theta_e/qt/p/Tv are fixed in this integration | RK and precipitation update only rows `1:ncols`; environmental row `ncols+1` stays fixed |
| Output buoyancy reference | `ace.m:714` uses the same `Tv_zc` as dynamics | `test.F:252–253` constructs output `Tv0` from initial row 1; dynamics uses the environmental row |

The Fortran driver reads `Tv_e` but does not subsequently use it in active
statements. The two reference profiles therefore represent different
contracts even though their input file is shared. Repeated inversion does
not make the environment prognostic in the current integration.

MATLAB's non-shared preprocessing (`ace.m:736,752–753`) constructs
`Tv_env=eval_Tv(T_env,q_env)` without condensate, then derives
`rho_env=p_z/(RD*Tv_env)` and theta_e from the same T/q with zero liquid/ice.
Its dynamics retains that reference Tv. Fortran instead reconstructs T/q/ql/qi
from theta_e/qt/p while retaining the input density. Both use the coefficient
0.607789855072462 and include condensate loading for ACE buoyancy; MATLAB
groups condensate as qc=ql+qi while Fortran subtracts ql and qi separately,
so floating-point expression ordering can also differ.

The original v0.18 source copies already contain the respective direct-input
and inverse-diagnosed reference paths. Thus shared-input loading did not
introduce this distinction. These source observations establish existing
behavior, not which reference definition is scientifically intended.

For the paired mixed-phase fixtures, using input Tv preserves consistency
with the retained input density and MATLAB baseline and removes most measured
trajectory discrepancy. This supports reviewing input Tv as the common
contract. It does not justify changing thermodynamic inversion, condensate
partition, density, or environmental entrainment fields at the same time.
For configurations with independently evolving or externally replaced
environmental fields, the desired contract must be reviewed separately.

The production Fortran output reference also needs review if initial ACE
row 1 differs from the environment: output buoyancy may then use a different
reference from dynamics. The paired experiment explicitly corrects its
temporary diagnostic driver; it does not repair the production driver.

## Interpretation and remaining work

The controlled intervention identifies reference-Tv behavior as a dominant
contributor to these two short mixed-phase trajectory discrepancies. It does
not establish that it is the only contributor, that MATLAB's reference-state
choice is scientifically preferred, or that the substitution is appropriate
for all model configurations. Residual differences remain, particularly the
single-case theta_e maximum of 1.363674e-10 K.

The previously observed phase-endpoint counterexample, WENO endpoints,
upper-boundary reconstruction, geometry rounding and floating-point evaluation
differences remain unresolved. Phase evolution of the substituted trajectories
is not independently diagnosed here. No long run, sweep, Intel/GNU equivalence,
closed conservation pass or common-release acceptance is claimed.

Recommended next development: review the intended environmental reference-state
contract (input Tv versus inverse-diagnosed Tv), then separately authorize any
production correction and its dry/liquid/ice/mixed regression scope.

## Reproduce

This historical isolation runner targets sources at the diagnostic snapshot
`18f7333` (production sources at `c39d83e`), before the subsequent production
reference-Tv alignment. Use that checkout with the retained matching fixtures;
its hash checks intentionally reject the corrected active implementation.
See [production alignment validation](#record-v018-reference-tv-alignment) for
validation of the corrected implementation.

Retain or reconstruct the reviewed mixed-phase baseline workspace with identical
production/input hashes, then use a fresh work directory:

```bash
python3 tests/alignment/isolate_reference_tv.py migration_work/reference_tv_repeat \
  --baseline migration_work/mixed_precipitation_run
```

Raw evidence is retained under ignored `migration_work/reference_tv_paired/`.
The runner refuses stale production/input fixtures and requires the control
history to exactly reproduce the retained history. Successful execution
establishes those checks and produces metrics; it does not assert scientific
equivalence. The JSON includes fixture hashes so retained files can be checked
against this completed run.

</details>

<a id="record-v018-runtime-comparison"></a>

<details>
<summary>docs/v018_runtime_comparison.md</summary>

# v0.18 single-ACE and multi-ACE runtime comparison

Validated on 2026-09-30 after shared-input commit `2537f46`. MATLAB R2023b
Update 9 and GNU Fortran 11.2.0 used the same `data/input/manus208.nc`.
Complete metrics, input/source hashes and build commands are in
`docs/v018_runtime_comparison.json`; full logs and numerical artifacts are
in the ignored `migration_work/alignment_precip/` workspace.

## Scope and sequence

The comparison first ran single-ACE initialization, raw tendencies, one
4-second step and a 120-second trajectory for dry and controlled
precipitating states, then repeated that sequence for multi-ACE. All
trajectories retain eight ACEs, 801 levels, 50 m spacing,
the complete PMB, dt=4 s, SSPRK93, disabled MF diffusion and the existing
sponge and precipitation routines. No equations or numerical corrections
were introduced in the active model sources.

Single mode enables the existing mask that zeros tendencies in ACEs 2–8.
Its initial 0.03 kg/m2/s sine MF pulse is placed in ACE 1, rather than the
default outer ACE 8, so the evolving column has a nontrivial perturbation.
This is a matched test configuration, not a one-column geometry or truncated
PMB. The multi case restores the default pulse in ACE 8 and evolves all ACEs.

The single switch masks tendencies, not every operation after each RK step.
Fortran retains its post-step precipitation, and both implementations retain
sponge damping. In this case inactive-column state drift is at most about
1.71e-12, consistent with the recorded damping roundoff; the initial masked
tendencies are exactly zero in both implementations.

## Prognostic comparison

Initial theta_e, qt and MF are exactly equal in both cases. Comparison dumps
use binary64, avoiding the production Fortran real*4 output rounding.
Numbers below are maximum absolute differences over all levels and ACEs.

| Mode | Time (s) | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: | ---: |
| Single | 4 | 4.55e-13 | 8.47e-22 | 3.18e-22 |
| Single | 60 | 1.36e-12 | 3.47e-18 | 7.42e-14 |
| Single | 120 | 1.59e-12 | 1.05e-16 | 1.30e-12 |
| Multi | 4 | 4.55e-13 | 8.47e-22 | 1.59e-22 |
| Multi | 60 | 1.59e-12 | 3.47e-18 | 3.25e-14 |
| Multi | 120 | 1.93e-12 | 4.77e-17 | 5.54e-13 |

All trajectory values and raw tendencies are finite. Per-variable RMS,
relative L2 errors, maximum errors and worst locations for each ACE are
recorded in the JSON report. No acceptance tolerance was imposed, and these
small errors do not certify general scientific equivalence.

## Controlled precipitating comparison

The original shared NC is unchanged. In each precipitating test, only the
pulse ACE's theta_e and qt at levels 11–30 are perturbed. At the original
inverted temperature and pressure, the constructed liquid condensate is
0.00049 kg/kg at levels 11–16, 0.0005 at levels 17–23 and 0.00051 at levels
24–30. Vapor is saturation vapor times (1-condensate); qt and theta_e are
recomputed consistently. Reference profiles, geometry, PMB, pulse and all
other levels are preserved. This is a manufactured stress test, not a
replacement Manus sounding.

The resulting initial three-field array is exported once by MATLAB and read
by the Fortran test. It is exactly equal before integration, so the results
do not mix independent initial-state reconstruction errors with evolution.

| Mode | Time (s) | theta_e (K) | qt (kg/kg) | MF (kg/m2/s) |
| --- | ---: | ---: | ---: | ---: |
| Single precip | 4 | 4.44e-5 | 2.31e-7 | 2.28e-8 |
| Single precip | 60 | 6.01e-4 | 3.17e-6 | 1.96e-4 |
| Single precip | 120 | 1.23e-3 | 5.40e-6 | 7.63e-4 |
| Multi precip | 4 | 4.44e-5 | 2.31e-7 | 6.76e-9 |
| Multi precip | 60 | 6.21e-4 | 3.30e-6 | 5.78e-5 |
| Multi precip | 120 | 1.16e-3 | 6.26e-6 | 2.26e-4 |

All trajectories remain finite. Maximum T differences at 120 s are about
4.87e-4 K (single) and 9.51e-5 K (multi). These errors are substantially
larger than the dry case. The isolated sink probes confirm a genuine onset
formula difference, and the unchanged implementations also split the sink
differently in time. No exclusive attribution of every trajectory error to
one difference is asserted; ice inversion/reference-state differences and
other known differences remain present. No tolerance was loosened to accept
these cases as equivalent.

## Confirmed differences and scientific limits

- **Thermodynamic inversion:** initial temperature differs by up to
  1.3672e-6 K. Manufactured warm, ice, saturated and mixed-phase states also
  produce inversion differences. The known opposite ice-branch derivative
  signs and iteration stopping behavior remain unchanged and need review.
- **Reference buoyancy:** MATLAB compares inverted temperature against the
  original input Tv_zc; Fortran recomputes its environmental Tv with its own
  inversion. Initial buoyancy therefore differs by up to 6.1934e-10 m/s2;
  Fortran's initial value is zero. PMB annihilates horizontally uniform
  reference forcing to very high precision in this case (maximum forcing-ACE
  kernel sum is 1.7607e-16, versus maximum entry 0.07987), but that does not
  remove the reference-state difference.
- **MF reconstruction boundary:** the maximum upwind reconstruction
  difference is 7.8217e-4 kg/m2/s at level 801 of the pulse ACE. Below the
  top-11 tendency mask the operators agree exactly in these initial cases.
  The circular MATLAB stencil and explicitly zeroed Fortran upper boundary
  remain different. Fortran WENO does not assign levels 1 and 801; those
  undefined outputs are excluded from the defined-operator comparison.
- **Geometry:** evaluating the same geometry in km versus metres produces
  up to 4.77e-7 m2 area and 1.46e-11 m perimeter differences. The values and
  relative differences are reported; neither implementation was normalized.
- **Precipitation:** all four dry diagnostic snapshots (0, 4, 60, 120 s) have
  zero ql+qi in both single and multi cases. The precipitating trajectories
  above expose evolution differences. Separate manufactured probes
  confirm that the smooth MATLAB sink and hard-ramp Fortran sink differ:
  at qc=0.0005 kg/kg, dqt is -5.7762265e-8 kg/kg/s in MATLAB and zero in
  Fortran. Below threshold it is -4.2751271e-8 versus zero; just above it is
  -7.6084604e-8 versus -3.3333333e-8. Far above threshold (qc=0.002) both
  return -5e-6. Stagewise versus post-step splitting and the MATLAB qt clamp
  remain separate known differences. A dry short trajectory does not test
  those differences under active precipitation.

Area-weighted column-water diagnostics are recorded for the full stored
801-level arrays. They include the extra top level and do not constitute a
conservation pass: sinks, sponge, open boundaries and frozen single columns
need explicit accounting in a later budget test.

## MATLAB availability and test access

MATLAB and the Statistics Toolbox license are available, but this R2023b
installation contains no `normpdf` function. The tests initialize the actual
driver through its input-validation path, then call exact copies of its
local `timeint`, `SSPRK93`, `expFun` and `ImDamp` functions. The unavailable
normpdf is used only in radiation diagnostics that are commented out of
the active tendencies; those diagnostics, traditional plume calculations
and plotting are skipped. No replacement normpdf implementation is injected.
This verifies the actual dynamics routines while leaving the normal plotting
driver's existing toolbox dependency unresolved.

Fortran access is prepared in a temporary build: private diagnostic routines
are made public, the existing commented single-ACE mask is controlled by a
test flag, and a setter populates thermodynamic caches for isolated sink
probes. The complete generated-source diff is saved. Multi mode uses the
unchanged numerical path. The active production sources retain their
default multi-ACE configuration. The GNU compiler uses -O2,
-fdefault-real-8 and -fdefault-double-8; original Intel compiler behavior
has not been validated.

## Reproduce

With shared inputs present, the active Fortran model already compiled, and
MATLAB/netCDF-Fortran available, run from the repository root:

```bash
python3 tests/alignment/run.py migration_work/alignment_run --precip
```

Use a fresh directory. The runner preserves prior results, compiles isolated
Fortran access, runs single dry/precip before multi dry/precip, collects all
31 trajectory samples per case,
calculates four diagnostic snapshots and ten physics probes, and writes logs
and comparison JSON. Under sandbox execution MATLAB must be allowed to reach
its license server; `MATLAB_PREFDIR` may point to a writable temporary folder.
No release pass is encoded: the tool reports quantitative evidence.

Next, review precipitation onset/splitting and ice-inversion differences,
then decide the intended behavior and quantitative acceptance criteria for
the controlled precipitating regression. The present work does not include
the default 12-hour MATLAB or
48-hour Fortran production run, normalization, or a unified release tag.

</details>

<a id="record-v018-thermodynamic-alignment"></a>

<details>
<summary>docs/v018_thermodynamic_alignment.md</summary>

# v0.18 controlled thermodynamic alignment and failure review

Current working-tree review based on `b70343c`, 2026-10-01. Step 1
(`1b3443c`) and Step 2 (`b70343c`) remain unchanged. The current state includes
Fortran inversion alignment plus subsequently approved shared MATLAB/Fortran
saturation-roundoff and liquid/ice Newton derivative corrections.

The subsequent [1200 atmospheric-condition check](#record-v018-atmospheric-validation)
found one in-range pure-ice endpoint branch/iteration mismatch; all calls
converge. No model fix has been applied for that new counterexample. The
[subsequent endpoint-rule preview](#record-v018-phase-endpoint-proposal) removes
that original mismatch but exposes a new-band-edge neighbor difference;
its proposed patch remains unapplied.

[Current review and commit scope](#record-v018-thermodynamic-review) summarizes
these changes and the three 25-case validations. Sweep runs are suspended;
theta_e>400 K cases are deferred, and es>p trial states are excluded from
current testing. **Full-domain equality and full model equivalence have not
been established.** The sections below preserve the earlier source states,
findings and subsequent approvals in order; historical metrics are not
results from the latest source or from new sweep runs.

## Historical initial Step 3 inversion changes

At the initial Step 3 alignment, only `inv_theta_e` in
`fortran/active/src/ace_module.F` changed. Replaced statements were retained
as comments. MATLAB and Fortran outside this subroutine were then verified
identical to `b70343c`. The approved shared follow-ups below additionally
change the MATLAB inverse; the current summary above includes them.

| Calculation | Previous Fortran | MATLAB reference and Step 3 change |
| --- | --- | --- |
| Unsaturated ice derivative | `1 + 300708*qt/CPL/T` | `1 - 300708*qt/CPL/T` |
| Liquid saturation derivative | Latent-heat approximation | Analytic derivative of liquid saturation-pressure expression |
| Ice saturation derivative | Fixed-`Ls` approximation | Analytic derivative of ice saturation-pressure expression |
| Saturated liquid initial guess | Tetens expression + `T0` | + `273.15` |
| Saturated ice initial guess | Tetens expression + `T0` | + `273.16` |
| Tetens logarithm offset | Derived `log(610.78*EPS)` | Reference literal `5.939876353793538` |
| Vapor-pressure coefficients | Derived `EPS` and `1-EPS` | Reference literals `0.621971830985916`, `0.378028169014084` |
| Unsaturated NaN exit/fallback | No explicit NaN fallback | Stop when T is NaN; enter condensate branch on NaN |
| NaN phase selection | Comparisons defaulted to liquid | Reference `T >= T0` / otherwise ice selection |
| `F`, liquid `G`, `GT0` evaluation | Algebraically equivalent, different multiply/divide order | Match reference expression grouping |

The warm unsaturated derivative, liquid/ice/mixed phase comparisons,
mixed-phase partition, nonnegative condensate protections, Newton update,
default 0.001 K stopping threshold and absence of a production iteration
limit are retained. Physical constants and the saturation-pressure functions
are unchanged. No precipitation, RK, clipping, dynamics, initialization,
mask, damping, forward-theta_e function or data interface changed.

MATLAB's complex arithmetic cannot be reproduced by the retained real-valued
Fortran routine. The added NaN fallback does not make all complex failure
paths equivalent; that limitation is exposed in the tests.

## Historical comparison scope before shared follow-ups

The test runner is [tests/thermodynamics](../../tests/thermodynamics/README.md).
It calls temporary instrumented copies of the actual scalar routines, with
identical binary64 inputs. Test-only counters and a 1,000-iteration cap record
unfinished inversions without changing production sources or accepting them.
GNU Fortran 11.2.0 used `-O2 -fdefault-real-8 -fdefault-double-8`; MATLAB was
R2023b Update 9. Intel behavior is not validated.

| Scan | Evaluated | Both finite real converged | Exactly equal four outputs | MATLAB statuses: capped / nonfinite / complex | Fortran nonfinite |
| --- | ---: | ---: | ---: | --- | ---: |
| Manufactured physical/near-saturation/low-condensate/mixed/dry states | 696 | 693 | 597 | 0 / 3 / 0 | 3 |
| Selected Cartesian grid points across 11 pressures | 2,002 | 1,926 | 1,532 | 5 / 20 / 51 | 76 |
| Complete 1100 hPa theta_e/qt plane | 401,401 | 400,969 | 329,864 | 12 / 110 / 310 | 432 |

The full plane includes every theta_e from 200 to 400 K in 0.5 K increments
and every qt from 0 to 100 g/kg in 0.1 g/kg increments. It is **one pressure**,
not the complete 2101-pressure grid. The focused manufactured states also
include some theta_e above 400 K, notably the phase-boundary examples below.
The separately repeated focused run through the command-line entry point
reproduced the same metrics and exercised the prepared-work resume path.

Maximum errors below use only pairs with finite real converged results. No
tolerance was imposed or loosened. Relative errors use a nonzero MATLAB
reference; zero-reference differences are counted separately.

| Quantity | 1100 hPa max absolute | 1100 hPa max relative | Focused max absolute | Focused max relative |
| --- | ---: | ---: | ---: | ---: |
| T (K) | 2.8422e-13 | 9.5153e-16 | 6.5614e-6 | 2.4020e-8 |
| qv (kg/kg) | 7.1471e-16 | 2.8356e-14 | 6.2119e-9 | 4.8654e-7 |
| ql (kg/kg) | 7.1471e-16 | 5.2875e-12 | 6.2119e-9 | 1.2424e-5 |
| qi (kg/kg) | 4.6491e-16 | 1.5592e-11 | 2.7756e-17 | 1.2135e-7 |

Branch/iteration mismatches were 2/2 for the focused scan, 0/57 for the
pilot, and 0/360 for the full plane. The plane had 322 status mismatches:
310 complex MATLAB outputs and 12 capped MATLAB calls versus NaN/nonfinite
Fortran exits. Iteration counts include failed calls, not just successful
pairs. There were no first-branch failure-flag mismatches in these scans.

## Confirmed failure path: es greater than ambient pressure

The reference's saturation formula with given total water is
`qs = EPS*es*(1-qt)/(p-es)`. At diagnosed temperatures with `es > p`, it
returns negative qs. The no-condensate consistency check then evaluates
`qt > qs` as true, even for zero or extremely small water content, and enters
the saturated solver. These failures are present in the original MATLAB
reference, not introduced by the Fortran alignment.

At p=1100 hPa:

| theta_e | qt | No-condensate T | es | qs | Subsequent reference behavior |
| --- | --- | ---: | ---: | ---: | --- |
| 366 K | 0 g/kg | 376.092871506 K | 111632.148 Pa | -42.5402812 kg/kg | Saturated initial guess contains log(0); T/qv/ql become NaN, qi remains zero |
| 375 K | 0.1 g/kg | 384.936198547 K | 150587.190 Pa | -2.30741828 kg/kg | Saturated iteration becomes complex; still unfinished after 1,000 iterations |
| 399 K | 0.1 g/kg | 409.577906757 K | 319873.159 Pa | -0.947868704 kg/kg | Saturated iteration stops with a complex output; Fortran stops with NaN |

For theta_e=399 K, after the first saturated Newton update T is about
404.699839281 K. The next saturation evaluation gives R about -187.958;
raising this negative R to noninteger chi makes MATLAB's G complex and
Fortran's real G NaN. MATLAB eventually returns T about
`1709.550641713 - 672.454611810i` K. This is not a finite real atmospheric
solution. The terminating zero-water and complex cases were additionally
called through the original, uninstrumented MATLAB function and matched the
instrumented outputs. The 375 K original unbounded call was deliberately not
started; the capped trace does not prove it would never converge.

No new es>=p guard, dry-water special case, complex algorithm, fallback
temperature or production iteration cap was introduced. Each would change
the scientific reference's failure behavior and needs a separate decision.

## Remaining finite phase-boundary disagreement

For the focused manufactured input
`theta_e=425.2100518044671 K, qt=0.013267607993738393 kg/kg, p=30000 Pa`,
MATLAB computes `G0-GT0 = 2.2737367544323206e-13`; GNU Fortran computes zero.
The strict comparisons therefore select liquid in MATLAB and mixed phase in
Fortran. The final maximum T difference is 6.5614e-6 K, and qv/ql differ by
6.2119e-9 kg/kg. The measured G0 last-bit rounding is sufficient to explain
the different phase decision; no relaxed phase comparison was added.

A second focused input at T=200 K near exact ice saturation selects the
no-condensate branch in MATLAB and the ice branch in Fortran, with T differing
by about 1.05e-9 K. These boundary cases must not be hidden behind a widened
tolerance or a claim of bitwise equivalence.

## Evidence and next review

[Machine-readable evidence](../v018_thermodynamic_validation.json) contains the
three summaries, source/build provenance, scope verification, and failure
traces. The reproducible test sources and temporary instrumentation diffs
are described in the test README. Raw workspaces, including the separate
command-line smoke test, are retained under the ignored
`migration_work/thermodynamic_alignment/` directory. The initial total-grid
metadata count had an arithmetic error; the published evidence records its
correction to 843,343,501. Input generators and evaluated-case counts were
unaffected.

Review the no-condensate consistency decision for es>=p and the intended
behavior for zero water/complex/nonconverged reference states before making
any further inversion correction. Phase-boundary rounding decisions also
remain open. The full 843,343,501-case sweep was not completed, and no
scientific equivalence or unified release pass is claimed.

## Current scope: targeted mismatches only

The developer has suspended sweep runs. Follow-up analysis uses only the two
known inputs below; the historical scan tables above are not new test runs.
The developer also provisionally excludes `es > p` cases from testing. The
prepared test filter diagnoses es using the MATLAB no-condensate trial T,
not the final condensate solution; it changes neither production inversion.
No exclusion of equality `es == p` was authorized.

The targeted runner is `tests/thermodynamics/trace_mismatches.py`; it prepares
exactly two inputs, logs temporary copies of the actual routines and never
invokes the sweep entry point. [Targeted evidence](../v018_targeted_inversion_cases.json)
contains both traces, outputs, source hashes and absolute/relative errors.

| Case | Identical input: theta_e (K), qt (kg/kg), p (Pa) | MATLAB decision | Fortran decision | Absolute T difference |
| --- | --- | --- | --- | ---: |
| Ice saturation | 282.02296733261414, 3.3710674483252453e-6, 30000 | qt-qsat = 0; no condensate | qt-qsat = 1.1858461261560205e-20; ice solver, then negative-qi protection | 1.0546727935434319e-9 K |
| Triple-point boundary | 425.2100518044671, 0.013267607993738393, 30000 | G0-GT0 = 2.2737367544323206e-13; liquid solver | G0-GT0 = 0; mixed branch | 6.561423901985108e-6 K |

For the ice case, the second no-condensate update returns 200 K in MATLAB
and 199.99999999999997 K in Fortran. The strict consistency comparison
therefore sends only Fortran into two more ice iterations; both ultimately
return qv=qt and ql=qi=0. The exact first arithmetic/library operation causing
the different second Newton update has not yet been isolated.

For the triple-point case, the recorded base `p*RE/P0` and exponent chi are
identical. MATLAB evaluates `(p*RE/P0)^chi` as 3.3222092758056503;
GNU Fortran evaluates it as 3.3222092758056498. Other recorded GT0 factors
are identical. This one-ULP power difference changes the strict branch
comparison. The specific runtime/library mechanism remains unverified.
MATLAB takes three liquid Newton steps, the last being -0.0003748235160713658 K,
within the existing 0.001 K stopping threshold. Its final T is thus slightly
above T0, whereas the mixed branch sets T=T0 directly. This propagates to
qv/ql differences of 6.211900010003046e-9 kg/kg. Both return qi=0.
This manufactured input has theta_e above the originally requested 400 K
maximum; it remains useful for diagnosing the phase boundary.

No boundary epsilon, new tolerance, additional clipping or model edit was
introduced during targeted analysis. Step 1 and Step 2 remain unchanged.

## 2026-10-01: ice-saturation case only

The developer deferred theta_e > 400 K cases as outside expected simulation
conditions. The preceding two-case results remain historical evidence;
`trace_mismatches.py` now prepares only the first input. No sweep was run.

For theta_e=282.02296733261414 K, qt=3.3710674483252453e-6 kg/kg and
p=30000 Pa, the earliest differing recorded factor is the pressure power
inside F0. The base 0.29999837401291823 and exponent
chi=0.28540913656881339 match in binary64. MATLAB returns
0.70919384370099148 for base^chi; GNU Fortran returns
0.70919384370099137 (one ULP lower). The other recorded factors e, gamma
and e^gamma match. Consequently F0 is 200.00839020576743 in MATLAB
and 200.00839020576740 in Fortran, also one ULP apart.

At the second Newton iteration, T, es, es^gamma, exponential argument,
exponential, Lv(T), F and dFdT match. However, F-F0 differs because F0
already differs. This gives dT=2.6109601141528628e-6 in MATLAB versus
2.6109600857322024e-6 K in Fortran. The updated temperatures are 200 K
and 199.99999999999997 K respectively. The strict qt>qsat test then
separates the branches exactly as recorded above. This is a double-precision
rounding/branch-boundary effect, not a single-versus-double precision build
mismatch. The exact library/compiler implementation behind power rounding
has not been attributed.

Both routines terminate with finite real outputs. MATLAB takes two
no-condensate iterations; Fortran takes those two and two ice iterations,
then applies its existing negative-qi protection. Final T differs by
1.054672793543432e-9 K (relative 5.273363967717159e-12); qv, ql and qi
agree exactly. The diagnosed ice vapor pressure is about 0.1626 Pa,
well below 30000 Pa; the provisional es>p exclusion does not apply.

[One-case evidence](../v018_ice_saturation_case.json) preserves full traces,
source hashes and results. No additional scientific source, tolerance or
phase comparison changes were made. Future boundary-rule changes require
scientific review; these results do not establish full model equivalence.

## Approved follow-up: shared saturation roundoff band

After the developer approved the proposed follow-up, the MATLAB reference
and Fortran inverse were both changed at the no-condensate consistency check.
Earlier statements that MATLAB was unchanged describe the preceding Step 3
alignment, not this subsequently authorized boundary fix. Original active
comparisons are retained as comments.

For finite real positive T and finite real qsat, use

```
sat_roundoff = 8*machine_epsilon*(max(abs(q),abs(qsat)) + abs(T*dqsat_dT))
enter_condensate = q-qsat > sat_roundoff
```

This combines the water arithmetic scale with first-order propagation of
relative T roundoff through the existing analytic liquid/ice saturation
derivative. MATLAB uses eps(1); Fortran uses epsilon(T), which follows its
actual real kind. Both tested builds use binary64. The multiplier 8 is an
engineering safety allowance, not a rigorous bound on all math-library
errors, and not a new Newton tolerance. The original NaN/complex triggers
are retained; other invalid states retain a zero roundoff band. No new es>p
production guard was added.

The decision intentionally treats a small positive supersaturation inside
the band as no condensate; it does not change qsat or clip qt. This is a
shared scientific decision at saturation boundaries. No liquid/mixed phase
comparison, iteration stopping rule, derivative equation, precipitation,
RK ordering or post-precipitation qt clipping was changed by the follow-up.

The targeted runner now uses the original ice input plus qt relative changes
of -1e-4, -1e-8, +1e-8 and +1e-4, with theta_e and p held fixed. No sweep or
theta_e > 400 K cases were run. [Validation evidence](../v018_saturation_boundary_validation.json)
contains five results, raw traces, source hashes and scope checks.

| qt relative change | MATLAB/Fortran branch | Iterations (no-condensate / ice) | Absolute T difference | qv/ql/qi differences |
| --- | --- | --- | ---: | --- |
| -1e-4 | No condensate / no condensate | 2 / 0 | 0 | All zero |
| -1e-8 | No condensate / no condensate | 2 / 0 | 0 | All zero |
| 0 | No condensate / no condensate | 2 / 0 | 2.842170943040401e-14 K | All zero |
| +1e-8 | Ice / ice | 2 / 2 | 0 | All zero |
| +1e-4 | Ice / ice | 2 / 2 | 0 | All zero |

All five pairs terminate finite and real, with matching branches and iteration
counts. The original input has a band of about 1.89892138198529e-19 kg/kg.
Its remaining relative T difference is 1.4210854715202004e-16; bitwise
identity is not claimed. Positive-side supersaturation around 3.3752e-14
and 3.3752e-10 kg/kg remains active and returns nonzero ice. These tests
validate the targeted ice boundary, not the complete atmospheric domain or
other compiler/precision configurations.

## Targeted liquid-water boundary follow-up

The next authorized investigation used a single liquid-water saturation
state constructed with the active MATLAB forward reference: T=280 K,
p=90000 Pa, qt=eval_qs(T,p)=0.0068773466638367246 kg/kg, and
theta_e=eval_theta_e(T,qt,0,0,p)=306.88985331179157 K.
Its es=991.01710443943318 Pa is below ambient pressure. Four relative qt
perturbations (-1e-4,-1e-8,+1e-8,+1e-4) hold theta_e and p fixed.
No sweep or theta_e>400 K cases were run. Both production source hashes
match the preceding ice-boundary validation; this follow-up changes tests
and documentation only.

All five pairs have exactly equal T/qv/ql/qi, matching branches and iteration
counts, and finite real converged status. Absolute and relative nonzero-
reference differences are all zero. Results are in
[liquid-boundary evidence](../v018_liquid_boundary_validation.json).

| Relative qt perturbation | Both branches | No-condensate / liquid iterations | T (K) | ql (kg/kg) |
| --- | --- | --- | ---: | ---: |
| -1e-4 | No condensate | 3 / 0 | 280.00162744803271 | 0 |
| -1e-8 | No condensate | 3 / 0 | 280.00000016260736 | 0 |
| 0 | Liquid | 3 / 2 | 280.00001102242504 | 0 |
| +1e-8 | Liquid | 3 / 2 | 280.00001102584434 | 0 |
| +1e-4 | Liquid | 3 / 2 | 280.00004521640540 | 6.70891516261346e-7 |

Agreement between implementations is distinct from exact forward-inverse
recovery. For the constructed saturation state, the no-condensate T is
279.99999999986352 K in MATLAB and 279.99999999986358 K in Fortran;
qt-qsat is about 6.52e-14 kg/kg, above the 2.49878820720743e-16 roundoff
band. Both therefore enter liquid iterations. The old strict q>qsat rule
would do so too. After the existing Newton stopping decision, T is about
1.1022425042028772e-5 K above the construction T; final negative-ql
protection yields qv=qt and ql=0. The very small positive perturbation also
ends with ql=0; the larger positive perturbation returns nonzero liquid.
No Newton tolerance, condensate protection or boundary band was changed to
force the round-trip result to match 280 K. The roundoff band addresses
floating-point branch differences, not all inversion stopping error.

Reproduce the single forward input with
`tests/thermodynamics/make_liquid_boundary.m`, then supply the resulting
JSON triple to `trace_mismatches.py --base-input-json`. The runner still
uses exactly five targeted inputs and does not call the grid driver.

## Liquid Newton derivative and stopping review (analysis only)

A one-input diagnostic in `tests/thermodynamics/review_liquid_newton.m`
reproduces the active MATLAB liquid final T exactly, reviews the final two
updates, and checks derivatives by centered differences. It does not modify
either active implementation or run a sweep. The model source hashes remain
identical to the preceding liquid-boundary validation. Results are in
[Newton review evidence](../v018_liquid_newton_review.json).

For fixed qt and p, the implemented liquid equation is

```
G(T) = T * (RE + Rv*qs(T))^chi * exp(qs(T)*Lv(T)/T/CPL)
Lv(T) = Lv0 - Cpvmcl*(T-273.15)
```

Since `Lv(T)/T = (Lv0+Cpvmcl*273.15)/T - Cpvmcl`, its derivative is
`-(Lv0+Cpvmcl*273.15)/T^2`. The full derivative is therefore

```
G'/G = 1/T + ((Rv*RE/R + Lv(T)/T)*qs'
              - (Lv0+Cpvmcl*273.15)*qs/T^2)/CPL
```

Both active implementations instead use the minus coefficient:
MATLAB literal `1867292`; Fortran `(Lv0-Cpvmcl*273.15)`.
The coefficient from differentiation of the actual Lv equation is
`3134708`. This is a shared equation/derivative inconsistency, not a
MATLAB-versus-Fortran discrepancy or evidence of a different physical Lv.

At 280 K, the current derivative is 11.083753902397838, while the analytic
value is 10.929045328595539 (current excess about 1.4155726246%). Centered
finite differences approach the latter: h=0.01 K gives 10.929045743409915;
h=0.001 K gives 10.929045332545684. Their relative differences from the
analytic value are 3.80e-8 and 3.61e-10 respectively. These are observations,
not adjusted acceptance tolerances.

| Derivative in diagnostic only | First liquid update (K) | Second liquid update (K) | Final T error from 280 K |
| --- | ---: | ---: | ---: |
| Active coefficient 1867292 | -0.05202338798487158 | -0.000777828797774375 | 1.1022425042028772e-5 K |
| Analytic coefficient 3134708 | -0.05276111290457987 | -0.00005112625520569703 | 4.7919002099661157e-11 K |

Both diagnostic paths retain the original 0.001 K step-based stopping
criterion and terminate after two liquid updates. The current final
G-G0 is about 1.20464607335e-4; at the hypothetical final point it is
5.23641574546e-10. Test-only continuation with the current derivative also
approaches the root, showing that the current iteration is converging but
stops with a remaining correction of about -1.08685702616e-5 K.
The shared forward-inverse offset is thus attributable to the derivative
inconsistency together with the existing stopping decision, not solely
floating-point roundoff.

The minimal proposed production change is one liquid derivative statement
in each language, retaining its original statement as a comment:
`1867292 -> 3134708` in MATLAB dGdT and
`Lv0-Cpvmcl*273.15 -> Lv0+Cpvmcl*273.15` in Fortran dGdT.
This changes both scientific references and has **not** been applied.
Newton tolerances, initialization, phase selection, saturation roundoff
band and Steps 1/2 remain unchanged. The same minus coefficient also
appears in ice dHdT; that entire derivative needs a separate review before
any ice change. This liquid-only result does not validate it.

## Approved liquid derivative correction and 25-case validation

The developer approved applying the two proposed liquid dGdT corrections
and requested the original five cases plus twenty distinct validation inputs.
The active MATLAB literal is now `3134708`; the active Fortran coefficient
is now `(Lv0+Cpvmcl*273.15)`. Both previous statements remain comments.
The preceding analysis-only proposal describes the pre-correction state.
No ice dHdT statement, Newton stopping criterion, saturation band, initial
guess, precipitation formula/order, clipping, SSPRK93, dynamics, masks,
constants or I/O was changed by this correction. Reverse reconstruction of
these two statement changes reproduces both pre-change source hashes exactly.

`tests/thermodynamics/validate_liquid.py` prepares temporary instrumented
copies of the active routines. `validate_liquid.m` constructs exactly 25
unique inputs with the active MATLAB forward functions. The first five are
the original liquid-boundary inputs. The twenty additional explicitly listed
states cover 300–1100 hPa, 274–300 K, dry/unsaturated/near-saturation/exact-
saturation/liquid-condensate states, including 1e-9 and 1e-8 kg/kg liquid.
Final theta_e ranges from 266.64690452238824 to 391.1639164672673 K.
All trials satisfy es<p. One initial candidate at 300 hPa had theta_e
400.0226606 K and was rejected before any inversion; its vapor fraction was
reduced from 0.3 to 0.1 to produce the final in-range condition. No global
sweep or theta_e>400 K inversion was run.

[25-case evidence](../v018_liquid_derivative_validation.json) contains every
input, constructed state, T/qv/ql/qi output, absolute/relative difference,
branch and iteration status, source/build provenance, and scope verification.
MATLAB was R2023b Update 9; GNU Fortran used the recorded binary64 flags.
The test-only per-branch iteration cap remains 1000; no call reached it.
Each instrumented MATLAB result also equals the directly called active
MATLAB output. A separately compiled, uninstrumented Fortran module
reproduces all four instrumented Fortran outputs exactly.

| Metric | Result |
| --- | ---: |
| Finite real converged pairs | 25 / 25 |
| Exactly equal T/qv/ql/qi | 20 / 25 |
| Branch mismatches | 0 |
| Iteration-count mismatches | 0 |
| Status mismatches | 0 |
| Maximum absolute T difference | 5.684341886080802e-14 K |
| Maximum relative T difference | 2.0745773306864268e-16 |
| Maximum absolute qv/ql difference | 5.898059818321144e-17 kg/kg |
| Maximum relative qv difference | 3.6574411072901866e-15 |
| Maximum relative ql difference | 3.7204844666053035e-7 |
| qi difference | 0 (all qi=0) |

The relative ql maximum occurs in the original +1e-8 perturbation, where
ql is only about 6.7608e-11 kg/kg and its absolute difference is
2.5153490401663703e-17 kg/kg. This denominator effect is reported rather
than hidden by changing a tolerance. Relative qi error is undefined because
all reference qi values are zero. No acceptance tolerance was imposed.

The original 280 K boundary now returns T=280.0000000000479 K,
reducing the common forward-inverse error from 1.1022425042028772e-5 K to
4.7919002099661157e-11 K without changing the 0.001 K stopping threshold.
The +1e-8 perturbation now returns small positive liquid (about 6.7608e-11
kg/kg), whereas the pre-correction stop led to negative-liquid protection
and zero liquid. This is an intended numerical consequence of the derivative
correction, not an additional clipping edit. The twenty additional cases
are distinct validation states, not a Cartesian scan or full-domain proof.
The shared ice derivative coefficient remains an open, separate review.

## Approved ice derivative correction and fixed-case validation

The developer authorized the ice correction after the liquid review. Full
analytic differentiation of the actual H equation confirms the same plus
coefficient in the ice-only derivative. With fixed qt and p, q=qs_ice(T),
qi=qt-q, R=RE+Rv*q, A=Lv0+Cpvmcl*273.15:

```
H(T) = T*R^chi*(T0/T)^(dC*qi/CPL)*exp((q*Lv(T)/T-Lf/T0*qi)/CPL)
H'/H = 1/T + ((Rv*RE/R + Lv(T)/T + dC*log(T/T0) + Lf/T0)*q'
              - ((A/T-dC)*q + dC*qt)/T)/CPL
```

The other terms match the active equations. The only production changes
in this follow-up are MATLAB ice dHdT `1867292 -> 3134708` and Fortran
ice dHdT `Lv0-Cpvmcl*273.15 -> Lv0+Cpvmcl*273.15`. Complete original
multi-line statements remain comments. Reverse reconstruction of these
changes reproduces both pre-change hashes, confirming that liquid dGdT,
phase decisions, tolerance, saturation roundoff band, initial guesses and
Steps 1/2 were untouched. Previous statements that ice dHdT was uncorrected
refer to the preceding liquid-only state.

The fixed runner `tests/thermodynamics/validate_ice.py` uses no sweep driver.
It tests the original ice-boundary input and four nearby qt perturbations,
plus twenty explicit distinct cold states covering 100–1100 hPa, 200–270 K,
dry/unsaturated/near-saturation/exact-saturation/ice-condensate conditions,
including 1e-9 and 1e-8 kg/kg ice. All theta_e lie between
204.3644158748231 and 385.78724784008364 K; all es<p trial checks pass.
There are no theta_e>400 K inputs. [Ice validation evidence](../v018_ice_derivative_validation.json)
contains all per-case outputs, raw errors, statuses, iteration counts and
scope/build provenance.

| Metric | Result |
| --- | ---: |
| Finite real converged pairs | 25 / 25 |
| Exactly equal T/qv/ql/qi | 21 / 25 |
| Branch mismatches | 0 |
| Iteration-count mismatches | 0 |
| Status mismatches | 0 |
| Maximum absolute T difference | 5.684341886080802e-14 K |
| Maximum relative T difference | 2.273736754347145e-16 |
| Maximum absolute qv/qi difference | 2.949029909160572e-17 kg/kg |
| Maximum relative qv difference | 7.050348130536305e-15 |
| Maximum relative qi difference | 2.94903179279896e-9 |
| ql difference | 0 (all ql=0) |

Both implementations choose no condensate in thirteen inputs and ice-only
in twelve; no test reaches the test-only iteration cap. The active MATLAB
calls equal the instrumented outputs exactly. Separately compiled,
uninstrumented Fortran also reproduces every instrumented four-variable
output exactly. No acceptance tolerance was imposed. Relative ql error is
undefined because all reference liquid values are zero. The relative qi
maximum occurs at about 1e-8 kg/kg ice; absolute errors remain reported.
This validates fixed cold cases, not a complete atmospheric domain or
mixed-phase branch.

An independent derivative check uses T=250 K, p=60000 Pa, ice=1e-4 kg/kg
with saturation vapor constructed by the MATLAB reference. The old dHdT
is 6.144168886525935, and the analytic corrected value is
6.1242329262194515 (old excess 0.32552583395599743%). Centered differences
with h=0.01,0.001,0.0001 K give 6.124233074547192,
6.124232927732010 and 6.1242329263677675, respectively. Relative errors
from the analytic derivative are 2.42e-8,2.47e-10 and 2.42e-11.
This convergence supports the full H differentiation without changing
Newton stopping conditions or tuning a test tolerance.

## Fixed mixed-phase/endpoint checks (inspection only)

The developer requested checking T0 phase partitioning after the liquid and
ice derivative fixes. No production source changed during this follow-up;
both hashes match the completed ice correction. Steps 1/2, both corrected
derivatives, the saturation roundoff band and the strict G0/GT0/HT0 phase
comparisons remain unchanged.

`tests/thermodynamics/validate_mixed.py` prepares exactly 25 fixed inputs:
fifteen interior mixed states at T0 with liquid and ice both present, four
pure-liquid/pure-ice T0 endpoints, two low-condensate mixed states (1e-9 and
1e-8 kg/kg), and four pure-phase states at T0 +/- 1e-6 or 1e-3 K. Pressures
range from 400 to 1100 hPa; theta_e ranges from 273.301531745747 to
383.7717789703386 K. Every es<p trial check passes. No sweep or theta_e>400 K
input was evaluated.

T0 inputs use the active mixed branch's mean liquid/ice saturation definition:
with `S=0.5*EPS*(es/(p-es)+esi/(p-esi))`, set
`qv=S/(1+S)*(1-qc)`, qt=qv+qc, ql=qc*(1-f), qi=qc*f.
The theta_e input is generated by the actual MATLAB forward function. The
near-T0 pure-phase states use the respective liquid or ice saturation. The
comparison logs the actual G0/GT0/HT0 values used by each scalar inverse,
rather than inferring the branch from returned water contents.

[Mixed-phase evidence](../v018_mixed_phase_validation.json) records all inputs,
outputs, branch/iteration/status values, absolute/relative differences,
water closure, constructed-state errors and phase-comparison diagnostics.

| Metric | Result |
| --- | ---: |
| Finite real converged pairs | 25 / 25 |
| Exactly equal T/qv/ql/qi | 23 / 25 |
| Branch mismatches | 0 |
| Iteration-count mismatches | 0 |
| Status mismatches | 0 |
| Branches in each implementation | 21 mixed, 2 ice-only, 2 liquid-only |
| Maximum absolute T difference | 5.684341886080802e-14 K |
| Maximum absolute qv difference | 1.6479873021779667e-17 kg/kg |
| Maximum absolute ql/qi difference | 1.8561541192951836e-16 kg/kg |
| Maximum relative T difference | 2.080936502907841e-16 |
| Maximum relative qv difference | 3.894582202114734e-15 |
| Maximum relative ql difference | 3.7123082385900804e-13 |
| Maximum relative qi difference | 4.1247869317671105e-14 |
| Maximum abs(qv+ql+qi-qt), either implementation | 0 |

All outputs are nonnegative. The four T0 endpoints choose mixed phase in
both implementations; their water allocation follows the existing endpoint
protections. Both very low-condensate cases retain the same mixed-phase
branch. Near-T0 below-freezing inputs select ice and above-freezing inputs
select liquid in both languages. These fixed tests show no branch or
partition mismatch beyond the recorded floating-point differences; they do
not claim bitwise agreement for all phase-boundary inputs.

Direct active MATLAB calls reproduce all instrumented outputs exactly.
A separately compiled uninstrumented Fortran module reproduces all four
instrumented output quantities exactly. No acceptance tolerance or phase
epsilon was added. Historical theta_e>400 K boundary counterexamples remain
deferred and are not reclassified as passing by this inspection.

One nominal pure-liquid endpoint (900 hPa) retains positive qi about
1.0901944282564318e-17 kg/kg in both implementations. Its G0-GT0 is
-2.2737367544323206e-13, so both select the mixed branch and the existing
protection clips only negative water, not this tiny positive remainder.
This shared endpoint roundoff is explicitly retained; no new small-positive
condensate cutoff or clipping rule was introduced during inspection.

</details>

<a id="record-v018-thermodynamic-review"></a>

<details>
<summary>docs/v018_thermodynamic_review.md</summary>

# v0.18 thermodynamic review and proposed commit scope

Latest follow-up: [1200 atmospheric conditions](#record-v018-atmospheric-validation)
found one in-range pure-ice endpoint branch/iteration difference (case 1106),
although all calls converge. Production sources remain identical to this
review. The earlier 25-case tables below remain valid for their recorded
inputs; they do not establish agreement on the expanded set. Review the
new endpoint issue before treating alignment as complete.

Reviewed against `b70343c` on `feature/shared-netcdf-input`, 2026-10-01.
No commits or repository staging changes were made during review. Numerical
metrics were recomputed from existing per-case evidence; no new MATLAB runs
or sweeps were performed. [Machine-readable review](../v018_thermodynamic_review.json)
records source hashes, metrics and the proposed patch sequence.

## Current source changes

| Logical change | Files/regions | Scientific decision |
| --- | --- | --- |
| Initial Fortran inverse alignment | Fortran inv_theta_e | MATLAB reference literals/grouping, no-condensate ice derivative sign, analytic saturation derivatives, Tetens guesses, NaN fallback/phase selection |
| Shared saturation roundoff band | MATLAB and Fortran no-condensate consistency checks | Ignore positive supersaturation within `8*epsilon*(max(abs(q),abs(qsat))+abs(T*dqsat_dT))` |
| Shared condensate Newton correction | MATLAB and Fortran liquid dGdT and ice dHdT | Differentiate the actual Lv(T)/T with coefficient 3134708, not 1867292 |

Only `fortran/active/src/ace_module.F` and
`matlab/active/util_thermodynamics/inv_T_from_theta_e.m` have active source
diffs. Fortran outside inv_theta_e is byte-for-byte unchanged from the
baseline. MATLAB changes are the shared roundoff check and the two derivative
statements. Original replaced statements remain comments.

Step 1 precipitation, Step 2 splitting/qt clipping, SSPRK93, dynamics,
initialization, masks, constants, damping and data interfaces are unchanged.
Newton stopping thresholds and lack of a production iteration limit are
retained. The unsaturated Newton derivative expressions continue to follow
the MATLAB reference; this review does not redesign them.

## Validation review

| Evidence | Cases | Finite/converged | Exactly equal four outputs | Branch/iteration/status mismatches | Max absolute T | Max absolute water |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| [Liquid correction](../v018_liquid_derivative_validation.json) | 25 | 25 | 20 | 0 / 0 / 0 | 5.6843e-14 K | 5.8981e-17 kg/kg |
| [Ice correction](../v018_ice_derivative_validation.json) | 25 | 25 | 21 | 0 / 0 / 0 | 5.6843e-14 K | 2.9490e-17 kg/kg |
| [Mixed/endpoint checks](../v018_mixed_phase_validation.json) | 25 | 25 | 23 | 0 / 0 / 0 | 5.6843e-14 K | 1.8562e-16 kg/kg |

These are three sequential fixed-case validations, not a single newly run
75-case test on the final source. Liquid results were recorded before the
ice-only coefficient fix. The subsequent source reconstruction verifies
that this fix changed only ice dHdT; all liquid validation paths select
no-condensate or liquid branches and do not evaluate that statement.
Ice and mixed evidence use the current final source hashes.

Every recorded group checked active MATLAB outputs against instrumented
copies, and separately compiled uninstrumented Fortran reproduced the
instrumented four outputs exactly. Centered finite differences support both
corrected saturated derivatives. Raw absolute/relative errors, zero-reference
cases, branch and iteration values remain in the evidence; no acceptance
tolerance was introduced or widened. JSON null for zero-reference relative
errors is undefined, not a successful zero relative error.

The evidence review rechecked JSON parsing, Python syntax, 25 unique inputs
per group, theta_e bounds, convergence/status, reported maxima and decision
counts. `git diff --check` passes. This is targeted inversion evidence, not
a coupled-model regression pass or proof of complete-domain equivalence.

## Retained limitations and decisions

- No sweeps are authorized for the current investigation; theta_e>400 K
  inputs remain deferred. Earlier scan and failure reports are historical.
- es>p is a test exclusion using the MATLAB no-condensate trial temperature;
  no production es>=p guard or fallback was added. Current fixed inputs all
  have es<p; equality was not tested.
- MATLAB complex arithmetic and real Fortran failure behavior remain distinct
  outside the tested finite domain. The production solvers retain no cap;
  only temporary test copies have the documented 1000-iteration observation cap.
- The roundoff multiplier 8 is an engineering allowance, not a rigorous
  guarantee for all math libraries or compiler settings. Only the recorded
  GNU binary64 build and MATLAB version were compared; Intel is unvalidated.
- Strict liquid/ice/mixed comparisons remain unchanged. The checked pure-
  liquid endpoint has the same tiny positive ice remainder in both languages;
  no extra small-condensate clipping was added.

## Proposed four-commit sequence

| Order | Proposed title | Contents |
| --- | --- | --- |
| 1 | `fortran: align v0.18 thermodynamic inversion with MATLAB` | Initial Fortran inverse alignment only |
| 2 | `thermodynamics: align saturation roundoff decisions` | Shared roundoff check in both inverses |
| 3 | `thermodynamics: correct liquid and ice Newton derivatives` | Shared 3134708 derivative coefficient correction in both branches |
| 4 | `tests: document and validate v0.18 thermodynamic alignment` | tests/thermodynamics, all new thermodynamic evidence/review documents, and docs/migration/v018_alignment.md update |

Three scientific patches were prepared under ignored
`migration_work/thermodynamic_alignment/review/`. They were applied and
checked in an isolated temporary copy; in sequence they reproduce both
final source files exactly. They provide a concrete way to stage each
logical change later without rewriting the working files. They do not
constitute commits or modify the repository index.

The tests and documentation depend on the final cumulative source state;
the historical evidence records intermediate states separately. Do not
include ignored __pycache__, compiler outputs, temporary MATLAB preferences,
raw binaries or migration_work artifacts in commits. The legacy scan runner
is preserved for traceability, clearly labeled suspended; it was not run
for this review. No history cleanup, file deletion or source refactor is
part of the proposed sequence.

This state is suitable for review and the scoped commit sequence above.
Developer authorization is still required before committing, under AGENTS.md
sections 1 and 9. No push is proposed.

</details>
