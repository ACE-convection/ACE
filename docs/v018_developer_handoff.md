# ACE v0.18 developer handoff

更新日期：2026-10-02。共同版本 `v0.18.0` 已於本機 `main` 合併，
annotated tag 指向 `2b62c29`；尚未推送 GitHub。
[發布紀錄](releases/v0.18.0.md) 定義接受範圍及保留限制，
[migration 入口](migration/README.md) 區分目前指引與歷史證據。

## 接手目前版本

1. 固定要測試的 commit，記錄 `git rev-parse HEAD` 與工作樹狀態。
   在含此本機 release 的 clone 可 checkout `v0.18.0`；目前 GitHub
   尚未收到此 tag，不應假設一般遠端 clone 已有它。
2. 安裝 Git LFS，取得 `data/input/manus208.nc` 的實際內容。
   以 [固定案例檢查](../tests/README.md) 核對 pinned hash；pointer
   文字不是 NetCDF 資料。歷史資料另依 LFS manifest 與 commit map 復原。
3. 使用 [MATLAB 說明](../matlab/README.md) 與
   [Fortran 說明](../fortran/README.md) 的正式目錄和啟動命令。
   MATLAB 從 `matlab/` 執行，Fortran 從 `fortran/` build/run；
   共用輸入預設為 `../data/input/manus208.nc`。
4. 記錄 MATLAB／Fortran／netCDF 工具版本、compiler flags、來源與輸入
   SHA-256、工作目錄、設定、命令和完整 log。已驗證環境為 MATLAB
   R2023b 與 GNU Fortran；原 makefile 的 Intel 設定仍保留，不能默認
   不同 compiler 的數值結果等價。

## 重跑已接受的案例

以 [tests/README.md](../tests/README.md) 為唯一操作入口，使用 fresh
output directory。三個案例為：

- Manus 208 singleACE、飽和 +1 K bubble、3 小時、不含降水：後續
  v0.20／v0.24 的固定初始比較案例。
- 相同 singleACE case 加入 native precipitation，3 小時。
- Manus 208、最外側 ACE 8 的初始 MF pulse、全 8 個 ACE 演進、
  native precipitation、12 小時；沒有持續外加 forcing。

確認共同初始狀態、完整積分、finite saved fields、非負總水與有效降水
診斷，並保留時間演進比較。誤差指標與物理解讀依發布範圍評估，
不要求兩個實作 byte equality，也不把本次數值當成所有版本的 tolerance。
目錄正規化前後的每個實作則已驗證完整儲存數值完全相同。

## 後續開發與歷史復原

依 [共同 roadmap](migration/matlab_fortran_alignment_plan.md) 前進到
v0.20，使用獨立分支、將物理變更與目錄整理分開。S20 的 basis 與
builder-input provenance 尚待確認；不能直接混用歷史同名 utilities。

[Normalization map](migration/v018_normalization.md) 記錄舊路徑與復原
commit `c9ae729`；[input contract](migration/v018_input_contract.md)
保留原始資料及 binary record 證據。完整舊交接說明可從
`v0.18.0:docs/v018_developer_handoff.md` 取得，其 staging 與缺少輸入
敘述屬於當時狀態，不再作為目前啟動條件。
