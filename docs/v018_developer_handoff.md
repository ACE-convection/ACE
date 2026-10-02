# ACE v0.18 developer handoff

> 2026-10-02 update: the developer accepted the Manus singleACE/multiACE
> milestone and authorized normalization before release. Start with the
> [release record](releases/v0.18.0.md), [tests](../tests/README.md), and
> [normalization map](migration/v018_normalization.md). Current sources are
> directly under `matlab/` and `fortran/`. The remaining staging instructions
> below are historical evidence; they do not describe the normalized checkout.

> Shared-input development update: `feature/shared-netcdf-input` adds the
> shared case NetCDF interface to the active drivers. See
> [schema, operating instructions and validation](shared_input.md).
> The original-input blockers and byte-identical active-source descriptions
> below record the handoff baseline; they do not describe the new readers.
> This does not complete the cross-implementation numerical release gates.


更新日期：2026-09-30。本文是跨主機接手測試的入口；細節以文末連結的稽核與 input contract 為準。**目前的 v0.18 是待驗證的 MATLAB／Fortran 候選版本，尚非已驗證的共同 release。**

## 整體方向與目前進度

完整順序與架構以 [canonical roadmap](migration/matlab_fortran_alignment_plan.md) 為準：先完成 **v0.18 MATLAB／Fortran 對照與共同驗證**，再經獨立 review 做 repository normalization，驗證正規化後的 checkout，最後建立 unified `v0.18.0`。其後兩個實作沿同一個 ACE Git history 共同開發，視需要處理 v0.19，再到 v0.20.0 發表／可重現性 release 與 v0.24 共同開發目標。

本文保留在 `docs/v018_developer_handoff.md`，作為 canonical 驗證操作文件；[migration index](migration/README.md) 是總入口。下列 `matlab/active/`、`fortran/active/` 與 `history/` 路徑只適用於目前的暫時 staging。驗證完成前保留這些目錄；正規化後目前原始碼直接位於 `matlab/`、`fortran/`，歷史由 commits／branches／tags 保存。本文的執行路徑須在該步驟更新並驗證。已保存的 S20／S24 工具程式屬於後續階段，不應混入 v0.18 測試。未來共用 `ACE/data/`／netCDF 的方向不改變本次測試的歷史輸入契約。

| 項目 | 已完成 | 尚未完成 |
| --- | --- | --- |
| 原始碼 | `matlab/active/ace.m` 與其 20 個直接依賴的 `util_*` 檔案，對應 2024-10-14 MATLAB commit `a0f30cd`；`fortran/active/` 的 makefile 與兩個 `src/*.F`，對應 Fortran commit／歷史標籤 `v0.18` 的 `ffdd734`。這些 active 原始碼是 byte-identical staging，MATLAB driver 只有檔名改為 `ace.m`。 | 尚未證明兩個實作在數值上相同。 |
| 程式比較 | 已完成靜態 component audit，列出已知差異與待查項目；已整理 v0.18 input contract。 | 未完成配對的初始狀態、單一 operator、單一步長或短時間積分比較，也沒有正式接受的誤差容許值。 |
| MATLAB 資料 | 八個 ACE 的 basis 與 Manus sounding 已保存在歷史目錄；17 個歷史 `data/` MAT／NC 檔已轉為 Git LFS，檔案大小及 SHA-256 驗證通過，GitHub `main` 已推送。 | `matlab/active/` 所預期的執行時 `../data/` 目錄尚未配置；active driver 尚未執行。 |
| Fortran 資料與執行 | 已釐清直接存取的 binary record 順序；另有一份從 basis 擷取的 **未驗證 PMB 候選檔**，其做法與雜湊記於 input contract。 | 原始 `ini_manus_208.dat` 與 `PMB.dat` 未在倉庫中找到；active source 尚未 build 或執行。候選 PMB 不能直接當成已確認的歷史 input。 |

原交接紀錄記載 GitHub `main` 的 LFS 遷移提交是 `70e656b`；這是當時的狀態，並非本次重新查驗遠端的結果。本文件完成後請以實際 checkout 的 `git rev-parse HEAD` 記錄測試版本；不要假設未來 `main` 仍停在這個提交。LFS 遷移改寫過 MATLAB 歷史 commit ID；本文使用改寫後 ID。若舊紀錄引用原 ID，請查 [commit map](migration/matlab_data_lfs_commit_map.csv)。Fortran 歷史 `v0.18` 標籤未改動。

## 在另一台主機上先做什麼

1. 安裝 Git LFS，clone 此倉庫並固定要測試的 commit。於倉庫根目錄執行 `git lfs pull`、`git lfs fsck`、`git status --short`，並記錄 `git rev-parse HEAD`。以 [LFS manifest](migration/matlab_data_lfs_manifest.tsv) 核對所用 MAT／NC 檔的大小及 SHA-256；若看到幾行 `version https://git-lfs.github.com/spec/v1` 文字，代表取得的是 pointer，還不是資料本身。
2. 記錄作業系統、MATLAB 版本、Intel Fortran 版本、netCDF-Fortran 版本、編譯旗標及資料雜湊。Fortran 原 makefile 使用 `ifort -r8 -fp-model precise`，並寫死 `/opt/libs-intel-oneapi/netcdf-4.7.4/` 的 include/lib 路徑。若環境不同，將 build 調整及其影響另行記錄；不要把不同編譯器的結果默認為等價。
3. 先讀 [v0.18 alignment audit](migration/v018_alignment.md) 及 [input contract](migration/v018_input_contract.md)。測試以 MATLAB `a0f30cd` 對 Fortran `ffdd734` 為第一組候選；MATLAB 2025-01-15 版本 `25d49e7` 與 Fortran 2024-12-16 對齊宣稱 `bb72a55` 是不同歷史狀態，應另列實驗，不能取代這組候選。

### MATLAB 的啟動條件

- 從 `matlab/active/` 作為 MATLAB current folder 執行 `ace.m`；driver 使用 `pwd` 加入該目錄下的 `util_weno/`、`util_plume/`、`util_thermodynamics/`。不要遞迴加入整個 `matlab/active/`，因為後續版本的同名函式也被保存於其他子目錄。
- Driver 固定從 `matlab/data/basis/COMPOSITE_ACE_BASIS_8ACEs.mat` 與 `matlab/data/soundings/manus_3hr_ARMBEsonde_profiles.nc` 等相對位置讀資料；LFS 保存的原檔分別位於 `matlab/history/original_git/data/basis/` 與 `matlab/history/snapshots/ACE_V019.3/data/soundings/`。建立執行時資料布局時，請記錄來源、方法及雜湊；目前倉庫未提供已驗證的 `matlab/data/` 布局。
- 第一組對照應保留 driver 既有設定，例如 Manus `arm=1`、`pidx=208`、八個 ACE、`dz=50 m`、`dt=4 s`、`turn_off_mf_diff=1`。Driver 預設 `save_output=0`、`plotting=1`，完整 `tspan` 為 12 小時；若為快速診斷縮短積分或調整輸出，應在獨立測試版本中記錄變更及其 diff。
- 無圖形介面的主機需要先處理 `plotting=1` 的繪圖需求；若關閉繪圖，將此設定變更納入測試紀錄。

### Fortran 的啟動條件

- 在 `fortran/active/` 下 build／run 時，程式會讀 `./input_data/ini_manus_208.dat` 與 `./input_data/PMB.dat`，並寫入 `./data/output_multiACE_manus208.dat`。原始 binary input 尚未找到；在確認 input 的來源、record 長度單位、byte order、real kind 與 PMB 維度順序之前，不應把模型輸出拿來做共同驗證。
- 執行時需提供可寫入的 `fortran/active/data/` 目錄。測試用 input、build 產物及輸出不要混入原始碼提交；若在工作樹內暫放資料，提交前逐項核對 `git status`。
- `test.F` 目前以 `goto 838` 略過 netCDF preprocessing，直接讀 binary profile。MATLAB 的 NetCDF 存在不等於 Fortran 的 binary input 已備妥。若必須重建，應先確認 Manus profile 208 的索引、所有 12 個 initialization records、PMB 的索引轉置與數值，並保留產生方法和雜湊。
- 原始執行長度與輸出設計不是快速測試設定。縮短執行、增加初始狀態 dump 或編譯器移植，都應另存為可檢視的測試改動，保留 staged source 原樣以利比對。

## 建議的驗證順序與交付證據

1. **Input gate：** 找回原始 Fortran binaries，或建立經 review 的衍生流程；用小型讀回測試核對 record、array order、尺寸與幾個指定值。與 MATLAB 載入的 basis、sounding、profile、PMB、幾何及初始參考場逐項比較。這一步尚未完成，是目前最直接的 blocker。
2. **各自可執行：** 記錄 MATLAB／Fortran 的 build 與啟動結果、設定、完整 log、輸入 SHA-256。執行成功只表示各自的環境可用，尚不代表跨實作一致。
3. **逐層比較：** 先比較 `theta_e`、`qt`、MF、垂直網格、ACE 面積、壓力與 PMB 等初始狀態，再測 thermodynamics、WENO／upwind 邊界、PCHIP／pressure response、raw tendency、單一步長，以及短時間積分（例如 Fortran 的 15 steps／60 s 輸出間隔）。逐變數、level、ACE 回報最大絕對／相對誤差與 norm；區分運算精度與 `real*4` 輸出誤差。
4. **科學差異處置：** 重點檢查 precipitation sink 的 stagewise／post-step 分裂與 onset 公式、MATLAB 的 `qt` clamp、ice branch 的 Newton derivative 符號、WENO 邊界及 sponge。這些是已知或疑似科學差異；需要數值證據與 developer 明確決定，不能靠寬鬆 tolerance 略過。

每次實驗請至少留下：Git commit、原始碼／測試改動 diff、平台與工具版本、編譯旗標、input 路徑與 SHA-256、執行命令／工作目錄、設定開關、log、初始狀態摘要、比較指標與失敗原因。將測試結果與任何科學修正分開提交，以便定位差異。現有 Fortran `v0.18` tag 只是歷史 marker；共同 release `v0.18.0` 必須等上述證據、獨立審查的 repository normalization，以及正規化後的重驗結果都通過 review，才能標記含兩個實作的同一個 commit。

## 詳細文件

- [整體 roadmap 與 source staging](migration/matlab_fortran_alignment_plan.md)
- [v0.18 component audit、已知差異及 validation gate](migration/v018_alignment.md)
- [輸入來源、Fortran binary contract 與 PMB 候選檔](migration/v018_input_contract.md)
- [MATLAB data 的 Git LFS 遷移及 commit map](migration/matlab_data_lfs_migration.md)
- [MATLAB active source 說明](../matlab/active/README.md)／[Fortran active source 說明](../fortran/active/README.md)
