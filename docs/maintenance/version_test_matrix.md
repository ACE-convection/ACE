# ACE 版本與測試清單（截至 v0.21.87，含詳細設定）

基準：`545c284ede5adbc3dd59293bc6a72601f3f240e9`；2026-10-15 盤點現存資料，沒有新執行模型。
本文件分為已人工核對的測試家族、逐份 tracked 證據索引、逐本機工作目錄索引與詳細設定。來源及整併決策見 [彙整報告](history_summary.md)。

完整配置欄位及其原文 SHA-256 集中在 [test_evidence.json](test_evidence.json) 的 `records[原路徑].data`。
標為 `complete configuration file` 的紀錄保留完整 JSON；其他紀錄只擷取設定／provenance／狀態欄位，沒有取代原始數值結果。原始結果、scripts、輸入、lookup、frozen baselines 仍需保留。
缺漏欄位表示「該紀錄未明載」，不以目前 production defaults 補填。檔案內不同層級的 duration/threads 可能屬不同子測試，不合併成單一設定。

本文件與設定附件保留盤點時的原commit IDs；本機歷史清理後請使用 [commit map](history_commit_map.tsv) 查找對應新ID。四個tag的前後object值見 [套用紀錄](history_rewrite.json)。

## 1. 版本定位與通過定義

| Tag | 盤點時原 commit（剝除 annotated tag object） | 測試證據的意義 |
| --- | --- | --- |
| `v0.18.0` | `d7d25b10c1bbad99543ed579a11196673d531c17` | 收錄該開發階段的證據；非全部在此 commit 重跑 |
| `v0.20.0` | `115cc50db158f2a0f0ba55fca66027958a895060` | 收錄該開發階段的證據；非全部在此 commit 重跑 |
| `v0.20.87` | `a0658ec19f427bb3dac349f96fad4b22d0c53156` | 收錄該開發階段的證據；非全部在此 commit 重跑 |
| `v0.21.87` | `545c284ede5adbc3dd59293bc6a72601f3f240e9` | 收錄該開發階段的證據；非全部在此 commit 重跑 |

「完成」表示紀錄聲明完成預定輸出；「gate passed」只在指定 gate 與配置下成立；「科學接受」另依 release／developer acceptance。compile-only、benchmark、取消、失敗、僅準備分開記載。
歷史 source snapshot v0.16／v0.19／S20、S24 與統一 tags 不一對一；找不到執行證據者不能填成通過。`tests/cases/manus_saturated_bubble.json` 的跨版本計畫字樣也不表示所有版本已跑。

## 2. v0.18 開發與 v0.18.0

共同長案例配置：八個 ACE、完整 PMB，dz=50 m、top=40 km、801 MF levels；SSPRK93，dt=4 s；原 damping 保留、MF diffusion 關閉。single 是 dynamics tendency mask，保留完整幾何與非局部 response。
主比較使用 MATLAB R2023b Update 9、GNU Fortran 11.2.0 real64；典型 flags 為 `-O2 -ffree-form -fdefault-real-8 -fdefault-double-8 -ffree-line-length-none` 與 netCDF-Fortran。其他精度依個別配置覆蓋。
Manus208 input SHA-256：`85f8f5ebf0b4a0bca4a96b9b3f6f9b43a1d9bdb4470658b018dcd71d5219b1d9`。

| 測試家族 | 詳細設定／範圍 | 結果與界限 | 主要證據／runner |
| --- | --- | --- | --- |
| 共同輸入／roundtrip | sounding、basis 與 shared NetCDF 所有變數；MATLAB/Fortran 初始化 | 記錄 exact readback／舊輸入對照；非完整長 run | `docs/shared_input_validation.json`；`tests/input/validate_fortran.py` |
| 熱力學 inversion 修正 | saturation boundary；液水與冰 Newton derivative；固定液／冰／mixed cases；保留 branch/iteration trace | 各修正有獨立 JSON；早期 broad scan 的 invalid／邊界問題不能因後續局部 pass 消失 | `docs/v018_*validation.json`、`*_review.json`；`tests/thermodynamics/` |
| 1200 大氣條件 | 隨機 seed、壓力／溫度／qt 範圍及分類見 `v018_atmospheric_validation.json` | 1199 cases branch/iteration 一致；case1106 phase endpoint 仍有分支差異；未套用新 phase epsilon | `docs/v018_atmospheric_validation.json` |
| 完整 timestep gates | single/multi × dry/liquid precip；Manus208；0:4:120 s，共31 samples；phase diagnostics 0/4/60/120 s；liquid ql=0.00049/0.00050/0.00051 kg/kg、pulse ACE levels11–30 | saved values finite；記錄 theta_e/qt/MF 差異；不宣稱 universal equality | `docs/v018_aligned_runtime_comparison.json`；`tests/alignment/run.py` |
| cold ice／interior mixed | 額外製造 cold/mixed seed；單／多 ACE；設定與 seed hashes 詳見各 configuration | 有 precip phase 證據；不是自然 sounding 或獨立 physical validation | `docs/v018_ice_precipitation_comparison.json`、`v018_mixed_precipitation_comparison.json` |
| Ci／reference Tv／roundoff 診斷 | 同 input 的 controlled variants；共同 seed、temperature forward evaluation、power/exp、phase residual | Ci 與 reference Tv 有經確認修正；其餘局部敏感度／phase-endpoint preview 保留各自範圍 | `docs/v018_ice_heat_capacity_alignment.json`、`v018_reference_tv_alignment.json`、`v018_*diagnostic.json` |
| GOAmazon314 no bubble | arm3、singleACE1；MF=0.03 sin(pi z/1000)，0–1000 m；precip off；3h，60 s輸出、181 states | 完成；max MF差1.493633e-11；早期 sandbox 失敗目錄不是成功 run | `migration_work/goamazon314_single_no_precip_3h_native/results.json`；`tests/alignment/run_sounding_case.py` |
| GOAmazon314 saturated bubble | 上述配置＋ACE1 levels11–51（500–2500m）+1 K、qsat、無新增 condensate；MATLAB匯出共同 seed | 完成；max MF差1.373079e-11；precip off | `migration_work/goamazon314_single_saturated_bubble_3h/results.json` |
| Manus208 single bubble | 與 GOAmazon bubble 同 grid/MF/bubble；input換Manus208；3h；181 states；分別 precip off/on | 兩個獨立參考；on 使用當時 native stage-1 thermo cache、sink、qt clamp、damping | `tests/cases/`、`tests/reference/`；`tests/alignment/run_reference_case.py` |
| Manus208 multi outer pulse | 全8 ACE evolve；ACE8 MF=0.03 sin(pi z/1000)，0–1000m；無bubble；native precip；12h、721 minute states；共同 seed | 完成並接受；MF最大差7.577286e-6；晚期差異增長；不代表穩態 | `docs/manus208_multi_outer_pulse_12h.json` |
| real32 native precipitation | 3h single 與12h multi；real32 model，PMB/input binary64；有修正前後、real64 control | v0.18 結果接受；精度差異保留；不推廣至 KHN26/P3 | `docs/fortran_single_precision_precipitation.json`、`fortran_single_precision_multiace.json`、`fortran_multiace_precision_control.json`；`tests/precision/` |
| source normalization preservation | default/explicit input 初始化；3h single off/on；12h multi | 針對路徑／結構調整的前後比較；非新 physical model | `docs/releases/v018_normalization_*.json`；`tests/alignment/verify_source_normalization.py` |

## 3. v0.20 KHN26 開發與 v0.20.0

長案例共同輸入為 `data/input/manaus1342_khn26.nc`，SHA-256 `09408f4d0343afd8659df82f8f1cfe5dc59308cff150fb2bcfd569b1b8794d35`。
101-ACE slab（兩端2.5km、內部5km）、dz=100m、top=40km、401 stored levels；完整 PMB，PMDv/PMD placeholders 停用；k=2 WENO、SSPRK93。
正式接受的三小時案例使用 dt=4s、ACE1 saturated +1K bubble（levels11–51），不同於 production dt=6s、+0.25K、6h defaults。
P3 lookup `p3_lookupTable_1.dat-v6.4-2momI` SHA-256：`57d2e839b4bbc52fa15892ac47d04a76c0854577a5df34dae264e55bdad4baf3`，外部本機供應；Fortran source 宣告 P3 5.3.1。

| 測試家族 | 詳細設定／範圍 | 結果與界限 | 主要證據／runner |
| --- | --- | --- | --- |
| shared-input／initialization | 101 ACE 全部 profiles、geometry、PMB；disabled-operator guards | readback/初始化與guard有結果；compile32不等於runtime32通過 | `docs/migration/v020_khn26_input_validation.json`、`v020_khn26_alignment_validation.json` |
| interp1 pchip/makima | 21 deterministic cases，seed20261004；每method/policy 3094 queries，共18564 values；extrapolate/hold/default；GNU real64 checked | tolerance=128×float64 eps=2.84217e-14（amplitude-scaled）；全部通過；real32 compile-only | `tests/interpolation/results.json`、`tests/interpolation/run.py` |
| PCHIP binary-search adoption | 126 method/policy/case output files；另外 annular 10 steps、dt4 serial real64 | 前後bytes相同；不包含OpenMP/debug model acceptance | `tests/interpolation/production_adoption_results.json` |
| singleACE dynamics／physical review | ACE1 dynamics mask；+1K、initial MF0.03；physics off；debug10steps後3h；早期 serial/OpenMP6 與後來 MATLAB default/Fortran32 分開 | 完成者各有結果；圖形、水存量／KE review 不等於budget closure | `tests/khn26/openmp_gate_results.json`、`openmp_diagnostic_results.json`；`docs/figures/khn26_single_native_3h/review.json` |
| native precipitation／Ci | 共同 states、12180 thermodynamic samples、10個 single-step replays；不同 trial 有 Ci／written MATLAB arithmetic 對齊 | 局部敏感度與修正證據；不宣稱唯一長軌跡誤差原因 | `tests/khn26/replay_precipitation_results.json`、`ci_correction_validation.json`、`thermodynamics_matlab_alignment_results.json` |
| fresh MATLAB arithmetic gates | multiACE，zero initial MF、+1K；none/native各600s、dt4、150steps；MATLAB default、Fortran32 | passed（個別 gate詳見JSON）；只認證短 gate | `tests/khn26/matlab_alignment_gate_results.json` |
| WENO k=2 alignment | component coefficients/grouping；同上 none/native 10min 配置 | passed；更高order未因此驗證 | `tests/khn26/weno_matlab_alignment_gate_results.json` |
| native multi3h | WENO-aligned；zero initial MF；native；181 minute states；MATLAB default（test host80 threads）、GNU real64 OpenMP32 | 完成、finite、qt非負；跨語言差異仍存在；已接受觀察 | `docs/figures/khn26_multi_weno_3h/review_results.json`、`source_configuration.json` |
| P3 smoke | 101ACE、dt4、+1K、zero initial MF、32threads；checked10steps／production prefix；600s、11 minute states | 正常完成，finite、非負water/number；不包含MATLAB/P3 equality | `tests/khn26/p3_smoke_results.json`；`tests/khn26/p3_smoke.py` |
| P3 single/multi3h | 同P3 smoke case、10800s、181 states；各自fresh process；11 prognostic fields | 正常完成，qrim≤qi；較早孤立dry/warm invalid仍未解決 | `docs/figures/khn26_p3_3h/review_results.json`、`source_configuration.json`；`tests/khn26/p3_long.py` |
| native/P3 MF panels | 比較各自3h snapshots；single native initialMF0.03，P3=0；multi initialMF均0 | single不能隔離P3效應；物理定義不同 | `docs/figures/khn26_native_p3_mf/*configuration.json` |
| minute precipitation replay | multi MATLAB/native Fortran/P3；181 records、每60s；t0 zeros、minute與cumulative amounts | 各自state與舊reference exact；ACE1 totals 124.247018/124.247018/19.272898mm，area mean0.866025/0.866025/0.218001mm；native removal與P3 surface不同 | `docs/figures/khn26_multi_precipitation_3h/results.json`；`tests/khn26/precip_timeseries.py` |
| PMB packing/compiler/SIMD | 真實forcing snapshots、O2/O3/check flags、serial/block-output；1min15steps、15min225steps，dt4 | 成分與whole-step evidence分開；15min blocked candidate有結果；MATLAB單thread15min取消 | `tests/basis_layout/*results.json`、`tests/khn26/serial_benchmark_results.json`、`matlab_single_cancellation.json` |
| profiler/timing | default/serial/thread配置、interleaved controls、1min evolving model與kernel | 只對記錄硬體／thread／構型成立；不能推論全8h speedup | `docs/performance/`、`tests/khn26/*profile*results.json` |
| 原6h／12h等launches | 目標時間與實際run不同；有stopped、failed gates、license failure | 不列為6h／12h完成；逐目錄狀態見附錄 | `migration_work/khn26_six_hour`、`khn26_multi*12h`、`khn26_precipitation_three_hour` |

## 4. v0.20.87 OOP preservation

Frozen baseline `115cc50db158f2a0f0ba55fca66027958a895060`（v0.20.0），reference architecture `b3f922e48e238581a85d31469bafcb800569a748`。
基礎 staged gates 使用 Manaus1342、GNU11.2 real64/OpenMP32，dt4、default bubble+0.25K、prefix10steps／minute output；none/native/P3 在fresh process，另有synthetic/cropped lifecycle fixtures。
不能把 staged gate 的+0.25K覆蓋成 final3h的+1K。完整 source/build hashes 及子case commands見各stage JSON配置。

| 階段 | 檢驗內容 | 紀錄結果 |
| --- | --- | --- |
| OOP-0 | frozen source、observation layout、baseline artifacts | `oop_stage0_results.json` passed |
| OOP-1 | passive type declaration | `oop_stage1_results.json` passed |
| OOP-2 | initialization、arrays ownership、error gates | `oop_stage2_results.json` passed |
| OOP-3a | response ownership／adapter | `oop_stage3a_results.json` passed |
| OOP-3b | integration/options/cache、9 RK observation frames | `oop_stage3b_results.json` passed；早期本機失敗嘗試分開保留 |
| OOP-4a | diagnostic isolation／no-op observation | `oop_stage4a_results.json` passed |
| OOP-4b | output ownership、record bookkeeping與error cases | `oop_stage4b_results.json` passed |
| OOP-5a | native damping cache；不同grid/dt順序objects；frozen damping oracle | `oop_stage5a_results.json` passed；cropped NetCDF chunk layout曾造成效能問題，後續fixture bytes audit保留 |
| OOP-5b | P3 wrapper lifecycle、one-context/process；legacy/model guards | `oop_stage5b_results.json` passed；24 commands、195 artifacts exact，165 layout/frame checks、18 state streams；real32/serial only compile/link |
| final native/P3 3h | source `2dbeb65361c3ff45481c580b9d5a607266c854d9`；+1K、initialMF0、dt4、10800s、32threads、各fresh process；plain/observed minuteprefix先比對 | `oop_long_results.json` passed；各181 state／9-field real32正常輸出／precip records與各自參考bitwise identical |

所有上述 JSON 在 `tests/khn26/`。Runners：`oop_regression.py`、`oop_initialization_contract.py`、`oop_integration_contract.py`、`oop_diagnose_contract.py`、`oop_output_contract.py`、`oop_damping_contract.py`、`oop_p3_contract.py`、`oop_long_regression.py`。
不能刪除 frozen baseline 與 long reference 後仍聲稱這些scripts可直接重跑。此驗證不建立多P3 context、concurrent/reset/copy或KHN26 real32 numerical acceptance。

## 5. v0.21.87 slab

共同配置：GOAmazon filtered314、arm3；88等寬5km columns；dz100m、top40km、dt6s；SSPRK93；native precipitation；DHh/DHv on；ACE1 saturated +0.25K、levels11–51；initialMF0。
來源 input/basis hashes、NetCDF layout 與轉換政策在 `data/input/goamazon314_88aces.provenance.json`。basis、共享NetCDF與parts必須local-only，不能因整併紀錄而commit／upload。
GNU11.2 real64 build：`-cpp -O2 -ffree-form -ffree-line-length-none -fdefault-real-8 -fdefault-double-8 -fopenmp`；debug另加 `-g -fcheck=all,no-array-temps -ffpe-trap=invalid,zero,overflow -fbacktrace`。
最終threads=32：MATLAB `maxNumCompThreads(32)`；Fortran `OMP_NUM_THREADS=32`、`OMP_THREAD_LIMIT=32`，具體環境以凍結configuration為準。

| 測試 | 設定／判準 | 已記錄結果 |
| --- | --- | --- |
| input readback | PMB/PMDv/PMD完整source readback、binary64不rescale、native units | exact；非新舊basis相同 |
| momentum component/oracle | 4種DHh/DHv組合、nonzero-MF、全forcing cells於5個response ACE與5個edge heights；independent NumPy oracle/additivity | 揭露並修正DHh forcing的1e6 SI/native差；combined response先相加再makima |
| old-case preservation | 舊Manaus input，DHh/DHv off，10steps | correction前後與packing後bitwise preserved |
| production one-step | MATLAB正常production輸出、GNUdebug/production；另P3one-step | short-state limits通過；P3不是8h acceptance；real32 compile-only |
| momentum packing | 4-mode components、native/nonzero-MF steps、old-case10steps、P3step與budget | pre/post-layout bytes相同；單step timing8threads70.15→2.04s，排除init/build |
| 8thread短suite | physics-off/native各600s；dt6/3/1.5 refinement | 完成；短limits為MF1e-9、theta_e1e-7K、qt1e-11；refinement要求dt3對dt1.5誤差不比dt6大超過shortlimits，dt6誤差低於shortlimits+10min變化量1% |
| 32thread native10min | 600s、11 states | 完成audit；states/budgets及Fortran正常輸出與8threads bitwise相同 |
| 32thread native1h | 3600s、61states | 完成audit；max errors MF6.599498725279318e-10、theta_e5.7565898714528885e-9、qt1.4730716646482733e-12 |
| 32thread native8h | 28800s、4800steps、481minute states；來源 `native8h_threads32` | 完成並接受；finite、qt非負、inventory連續；Fortran正常9fields finite且prognostics為exact real32cast；MATLAB測試driver跳過finalnormalpostprocessing |
| MATLAB thread/kernel prototypes | default/32/64/80 threads、block/packed/matrix；記錄component/fullstep設定 | kernel範圍；不代表production採用 |
| nonlocal Precomputed benchmark | captured input、32threads；fullstep從記錄的startstate測試 | 修改floating-pointgrouping；benchmark-only，沒有production或長trajectoryacceptance |

short limits 是既有短state門檻；長run報告差異，不新增通用trajectory tolerance。inventory bookkeeping通過不代表closed physical water/energy budget。
完整 evidence：[validation](../migration/v02187_validation.json)、[slab runner 說明](../../tests/slab/README.md)、[benchmark](../../benchmarks/nonlocal_response/PRECOMPUTED.md)。

## 6. 逐份 tracked JSON 證據索引

「最早收錄tag」僅由已存在四個tag的路徑查詢得到，不是實際被測source版本。
「目前bytes首次收錄tag」另比對Git blob，避免把後來修訂報告誤配早期tag；詳細source revision仍看紀錄本身。
所有118份原始tracked JSON均列於此（含provenance／case／manifest，不代表118個獨立通過測試）。

| 原始JSON | 最早收錄tag | 目前bytes首次收錄tag | 原始狀態／scope摘要 |
| --- | --- | --- | --- |
| [benchmarks/nonlocal_response/fullsteps/results.json](../../benchmarks/nonlocal_response/fullsteps/results.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [benchmarks/nonlocal_response/fullsteps/status.json](../../benchmarks/nonlocal_response/fullsteps/status.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [benchmarks/nonlocal_response/manifest.json](../../benchmarks/nonlocal_response/manifest.json) | v0.21.87 | v0.21.87 | scope="No production edits; native GOAmazon314 actual 88ACE current coarse_z only; 32 threads; retain makima; timeit and actual-input error tests" |
| [benchmarks/nonlocal_response/results/checkpoint.json](../../benchmarks/nonlocal_response/results/checkpoint.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [benchmarks/nonlocal_response/results/profile.json](../../benchmarks/nonlocal_response/results/profile.json) | v0.21.87 | v0.21.87 | 結構化資料；無統一pass欄位 |
| [benchmarks/nonlocal_response/results/results.json](../../benchmarks/nonlocal_response/results/results.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [data/distribution/v02187/manifest.json](../../data/distribution/v02187/manifest.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [data/input/goamazon314_88aces.provenance.json](../../data/input/goamazon314_88aces.provenance.json) | v0.21.87 | v0.21.87 | 已保存紀錄；不可由檔案存在推定通過 |
| [data/input/manaus1342_khn26.provenance.json](../../data/input/manaus1342_khn26.provenance.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_multi_native_3h/manifest.json](../figures/khn26_multi_native_3h/manifest.json) | v0.20.0 | v0.20.0 | scope="Versioned copies of completed plots, numerical reports and source configuration. Raw state streams and MF NPZ remain in the preserved local workspace. No new simulation or regeneration of source plots." |
| [docs/figures/khn26_multi_native_3h/plot_scope.json](../figures/khn26_multi_native_3h/plot_scope.json) | v0.20.0 | v0.20.0 | scope="Descriptive MF response; nonlocal pressure and mean-MF projection can cause immediate remote response. Phase/arrival interpretation needs review." |
| [docs/figures/khn26_multi_native_3h/snapshot_results.json](../figures/khn26_multi_native_3h/snapshot_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_multi_native_3h/source_configuration.json](../figures/khn26_multi_native_3h/source_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_multi_native_3h/state_results.json](../figures/khn26_multi_native_3h/state_results.json) | v0.20.0 | v0.20.0 | scope="Only saved states at 60-second intervals, minutes 0–180. Intentional stops; no full-step tendencies, closed water budget, or predefined three-hour scientific tolerance." |
| [docs/figures/khn26_multi_precipitation_3h/manifest.json](../figures/khn26_multi_precipitation_3h/manifest.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_multi_precipitation_3h/results.json](../figures/khn26_multi_precipitation_3h/results.json) | v0.20.0 | v0.20.0 | scope="Actual model-step diagnostics, exact minute-saved state reproduction. Native removal equivalent and P3 transported surface precipitation have different definitions." |
| [docs/figures/khn26_multi_weno_3h/manifest.json](../figures/khn26_multi_weno_3h/manifest.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_multi_weno_3h/review_results.json](../figures/khn26_multi_weno_3h/review_results.json) | v0.20.0 | v0.20.0 | scope="Minute-saved states only; no predefined three-hour acceptance tolerance, wave-speed validation, or closed water budget." |
| [docs/figures/khn26_multi_weno_3h/source_configuration.json](../figures/khn26_multi_weno_3h/source_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_native_p3_mf/manifest.json](../figures/khn26_native_p3_mf/manifest.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.json](../figures/khn26_native_p3_mf/multiACE_mf_20min_snapshots.json) | v0.20.0 | v0.20.0 | scope="Descriptive MF-only comparison of preserved runs with different physics; not a precision-error or physics-only attribution test." |
| [docs/figures/khn26_native_p3_mf/multiACE_native_configuration.json](../figures/khn26_native_p3_mf/multiACE_native_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_native_p3_mf/p3_configuration.json](../figures/khn26_native_p3_mf/p3_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.json](../figures/khn26_native_p3_mf/singleACE_mf_20min_snapshots.json) | v0.20.0 | v0.20.0 | scope="Descriptive MF-only comparison of preserved runs with different physics; not a precision-error or physics-only attribution test." |
| [docs/figures/khn26_native_p3_mf/singleACE_native_configuration.json](../figures/khn26_native_p3_mf/singleACE_native_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_p3_3h/manifest.json](../figures/khn26_p3_3h/manifest.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_p3_3h/review_results.json](../figures/khn26_p3_3h/review_results.json) | v0.20.0 | v0.20.0 | scope="Descriptive minute-saved state plots, no scientific acceptance threshold or closed water budget." |
| [docs/figures/khn26_p3_3h/source_configuration.json](../figures/khn26_p3_3h/source_configuration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/figures/khn26_single_native_3h/review.json](../figures/khn26_single_native_3h/review.json) | v0.20.0 | v0.20.0 | scope="SingleACE with full basis and other ACE dynamics masked. Descriptive stored-state diagnostics; not a multiACE gravity-wave test or closed precipitation/energy budget." |
| [docs/figures/v02187/scope.json](../figures/v02187/scope.json) | v0.21.87 | v0.21.87 | scope="Descriptive MF response; nonlocal pressure and mean projection can cause immediate remote response. Physical wave interpretation remains pending." |
| [docs/fortran_multiace_precision_control.json](../fortran_multiace_precision_control.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/fortran_single_precision_multiace.json](../fortran_single_precision_multiace.json) | v0.18.0 | v0.18.0 | status="passed execution checks; MF visual comparison ready; no scientific tolerance imposed"; scope="All eight ACEs, original ACE 8 outer pulse, no bubble or sustained forcing; native precipitation, full geometry/PMB, original da…（完整原文見連結） |
| [docs/fortran_single_precision_precipitation.json](../fortran_single_precision_precipitation.json) | v0.18.0 | v0.18.0 | status="passed focused numerical and runtime checks; no scientific acceptance tolerance assigned"; scope="Default real32 or real64 prognostics; PMB and NetCDF input remain binary64. Fixed Manus 208 saturated bubble seed, native pr…（完整原文見連結） |
| [docs/manus208_multi_outer_pulse_12h.json](../manus208_multi_outer_pulse_12h.json) | v0.18.0 | v0.18.0 | comparison_status="Descriptive errors only; no byte equality or acceptance tolerance required" |
| [docs/manus208_sounding_time_verification.json](../manus208_sounding_time_verification.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v018_normalization_manifest.json](../migration/v018_normalization_manifest.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_khn26_alignment_validation.json](../migration/v020_khn26_alignment_validation.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_khn26_input_validation.json](../migration/v020_khn26_input_validation.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_khn26_integration.json](../migration/v020_khn26_integration.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_khn26_source_inventory.json](../migration/v020_khn26_source_inventory.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_source_inventory.json](../migration/v020_source_inventory.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/migration/v020_source_merge_manifest.json](../migration/v020_source_merge_manifest.json) | v0.20.0 | v0.20.0 | scope="Isolated source migration candidate; not active-source promotion or validated code." |
| [docs/migration/v02187_validation.json](../migration/v02187_validation.json) | v0.21.87 | v0.21.87 | status="Developer accepted native eight-hour results and response plots for v0.21.87; release commit/main merge/tag authorized" |
| [docs/performance/matlab_default_results.json](../performance/matlab_default_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/performance/serial_timestep_results.json](../performance/serial_timestep_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/releases/v018_normalization_default_input.json](../releases/v018_normalization_default_input.json) | v0.18.0 | v0.18.0 | status="passed" |
| [docs/releases/v018_normalization_multi_12h.json](../releases/v018_normalization_multi_12h.json) | v0.18.0 | v0.18.0 | status="passed: all saved numerical values exactly reproduced"; scope="Same implementation before/after source normalization; exact equality is not a MATLAB/Fortran acceptance criterion" |
| [docs/releases/v018_normalization_single_no_precip.json](../releases/v018_normalization_single_no_precip.json) | v0.18.0 | v0.18.0 | status="passed: all saved numerical values exactly reproduced"; scope="Same implementation before/after source normalization; exact equality is not a MATLAB/Fortran acceptance criterion" |
| [docs/releases/v018_normalization_single_precip.json](../releases/v018_normalization_single_precip.json) | v0.18.0 | v0.18.0 | status="passed: all saved numerical values exactly reproduced"; scope="Same implementation before/after source normalization; exact equality is not a MATLAB/Fortran acceptance criterion" |
| [docs/shared_input_validation.json](../shared_input_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/v018_aligned_runtime_comparison.json](../v018_aligned_runtime_comparison.json) | v0.18.0 | v0.18.0 | scope="Four matched 4-second/120-second trajectories; no acceptance tolerance or production source change" |
| [docs/v018_atmospheric_validation.json](../v018_atmospheric_validation.json) | v0.18.0 | v0.18.0 | scope="1200 stratified synthetic atmospheric states; no Cartesian sweep; theta_e 200..400 K; no-condensate es>p trials excluded." |
| [docs/v018_forward_evaluation_diagnostic.json](../v018_forward_evaluation_diagnostic.json) | v0.18.0 | v0.18.0 | scope="Standalone forward/sink probes; temporary EPS spelling, staged multiplication, exact-argument exp substitution; no integration" |
| [docs/v018_ice_derivative_validation.json](../v018_ice_derivative_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/v018_ice_heat_capacity_alignment.json](../v018_ice_heat_capacity_alignment.json) | v0.18.0 | v0.18.0 | scope="Approved Ci reference alignment only; four 4-second/120-second trajectories and ten common physics probes; no tolerance adjustment" |
| [docs/v018_ice_precipitation_comparison.json](../v018_ice_precipitation_comparison.json) | v0.18.0 | v0.18.0 | scope="Matched 4-second/120-second trajectories; no acceptance tolerance or production source change" |
| [docs/v018_ice_saturation_case.json](../v018_ice_saturation_case.json) | v0.18.0 | v0.18.0 | scope="Only ice saturation input; theta_e > 400 K case deferred by developer. No sweep." |
| [docs/v018_liquid_boundary_validation.json](../v018_liquid_boundary_validation.json) | v0.18.0 | v0.18.0 | scope="Five targeted liquid-boundary inputs only. qt multipliers 1+[-1e-4,-1e-8,0,1e-8,1e-4]. No sweep; no theta_e>400 K cases." |
| [docs/v018_liquid_derivative_validation.json](../v018_liquid_derivative_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/v018_liquid_newton_review.json](../v018_liquid_newton_review.json) | v0.18.0 | v0.18.0 | scope="Single T=280 K, p=90000 Pa liquid saturation input; no sweep. Current and hypothetical derivative diagnostics only." |
| [docs/v018_mixed_phase_validation.json](../v018_mixed_phase_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/v018_mixed_precipitation_comparison.json](../v018_mixed_precipitation_comparison.json) | v0.18.0 | v0.18.0 | scope="Matched 4-second/120-second trajectories; no acceptance tolerance or production source change" |
| [docs/v018_mixed_residual_diagnostic.json](../v018_mixed_residual_diagnostic.json) | v0.18.0 | v0.18.0 | scope="Identical-state one-step replay; native and identical-thermodynamic-cache sink probes; production unchanged" |
| [docs/v018_phase_endpoint_preview.json](../v018_phase_endpoint_preview.json) | v0.18.0 | v0.18.0 | status="Preview only; proposal not applied to production and not recommended as a complete branch-alignment fix." |
| [docs/v018_pressure_power_diagnostic.json](../v018_pressure_power_diagnostic.json) | v0.18.0 | v0.18.0 | scope="1200 matched-state forward/sink probes; exact-input pressure-power substitution only; no integration" |
| [docs/v018_reference_tv_alignment.json](../v018_reference_tv_alignment.json) | v0.18.0 | v0.18.0 | scope="Current active sources: matched 4-second/120-second trajectories; no acceptance tolerance" |
| [docs/v018_reference_tv_diagnostic.json](../v018_reference_tv_diagnostic.json) | v0.18.0 | v0.18.0 | scope="Temporary reference Tv substitution only; unchanged MATLAB fixture, equations, inverse, RK, precipitation, damping and production sources." |
| [docs/v018_runtime_comparison.json](../v018_runtime_comparison.json) | v0.18.0 | v0.18.0 | scope="4-second one-step and 120-second dry/controlled-precipitating trajectories; single dry/precip completed before multi dry/precip; no acceptance tolerance; no scientific algorithm correction" |
| [docs/v018_saturation_boundary_validation.json](../v018_saturation_boundary_validation.json) | v0.18.0 | v0.18.0 | scope="Five targeted ice-saturation inputs. qt multipliers 1+[-1e-4,-1e-8,0,1e-8,1e-4]. No sweep; no theta_e > 400 K cases." |
| [docs/v018_targeted_inversion_cases.json](../v018_targeted_inversion_cases.json) | v0.18.0 | v0.18.0 | scope="Exactly two known mismatches. No sweep invoked." |
| [docs/v018_thermodynamic_review.json](../v018_thermodynamic_review.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [docs/v018_thermodynamic_validation.json](../v018_thermodynamic_validation.json) | v0.18.0 | v0.18.0 | status="Scientific agreement unresolved; developer requested failure-path review before further Cartesian scanning" |
| [tests/basis_layout/blocked_15min_results.json](../../tests/basis_layout/blocked_15min_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/blocked_model_results.json](../../tests/basis_layout/blocked_model_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/compiler_results.json](../../tests/basis_layout/compiler_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/model_results.json](../../tests/basis_layout/model_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/production_profile_results.json](../../tests/basis_layout/production_profile_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/profile_results.json](../../tests/basis_layout/profile_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/repeated_production_profile_results.json](../../tests/basis_layout/repeated_production_profile_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/results.json](../../tests/basis_layout/results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/basis_layout/serial_simd_results.json](../../tests/basis_layout/serial_simd_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/cases/manus_saturated_bubble.json](../../tests/cases/manus_saturated_bubble.json) | v0.18.0 | v0.18.0 | status="canonical initial comparison case for v0.18, v0.20 and v0.24" |
| [tests/cases/manus_saturated_bubble_precip.json](../../tests/cases/manus_saturated_bubble_precip.json) | v0.18.0 | v0.18.0 | status="additional precipitation-enabled comparison case; completed v0.18 execution checks" |
| [tests/interpolation/production_adoption_results.json](../../tests/interpolation/production_adoption_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/interpolation/results.json](../../tests/interpolation/results.json) | v0.20.0 | v0.20.0 | scope="production interp1 only; no basis or model integration" |
| [tests/khn26/ci_correction_validation.json](../../tests/khn26/ci_correction_validation.json) | v0.20.0 | v0.20.0 | scope="Previously completed validation of the authorized Ci correction; no new model run or performance measurement." |
| [tests/khn26/low_perturbation_comparison.json](../../tests/khn26/low_perturbation_comparison.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/matlab_alignment_gate_results.json](../../tests/khn26/matlab_alignment_gate_results.json) | v0.20.0 | v0.20.0 | gate_passed={"passed":true}; status={"state":"gates_passed","full_started":false}; scope="Fresh ten-minute multiACE dry/native regression gates after MATLAB literal/arithmetic alignment; background execution, MATLAB default and Fo…（完整原文見連結） |
| [tests/khn26/matlab_control_results.json](../../tests/khn26/matlab_control_results.json) | v0.20.0 | v0.20.0 | scope="Original MATLAB timeint tic/toc; no section timers. One cold evolving minute on shared hardware." |
| [tests/khn26/matlab_profile_results.json](../../tests/khn26/matlab_profile_results.json) | v0.20.0 | v0.20.0 | scope="Exclusive comparison aggregates are additive. MATLAB basis timing includes original coarsening/temporary arrays and disabled PMDv/PMD expressions; Fortran packs forcing separately. MATLAB microrad includes two inversion/sin…（完整原文見連結） |
| [tests/khn26/matlab_single_cancellation.json](../../tests/khn26/matlab_single_cancellation.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/oop_long_results.json](../../tests/khn26/oop_long_results.json) | v0.20.87 | v0.20.87 | passed=true |
| [tests/khn26/oop_stage0_results.json](../../tests/khn26/oop_stage0_results.json) | v0.20.87 | v0.20.87 | passed=true |
| [tests/khn26/oop_stage1_results.json](../../tests/khn26/oop_stage1_results.json) | v0.20.87 | v0.20.87 | passed=true |
| [tests/khn26/oop_stage2_results.json](../../tests/khn26/oop_stage2_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage3a_results.json](../../tests/khn26/oop_stage3a_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage3b_results.json](../../tests/khn26/oop_stage3b_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage4a_results.json](../../tests/khn26/oop_stage4a_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage4b_results.json](../../tests/khn26/oop_stage4b_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage5a_results.json](../../tests/khn26/oop_stage5a_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/oop_stage5b_results.json](../../tests/khn26/oop_stage5b_results.json) | v0.20.87 | v0.20.87 | passed=true; scope="GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun." |
| [tests/khn26/openmp_diagnostic_results.json](../../tests/khn26/openmp_diagnostic_results.json) | v0.20.0 | v0.20.0 | scope="Saved states only; initial pulse precedes mean correction. No independent energy/water budget acceptance." |
| [tests/khn26/openmp_gate_results.json](../../tests/khn26/openmp_gate_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/p3_smoke_results.json](../../tests/khn26/p3_smoke_results.json) | v0.20.0 | v0.20.0 | status={"state":"completed","full_started":true} |
| [tests/khn26/precip_output_results.json](../../tests/khn26/precip_output_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/profile_paired_results.json](../../tests/khn26/profile_paired_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/profile_sensitivity_results.json](../../tests/khn26/profile_sensitivity_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/replay_precipitation_results.json](../../tests/khn26/replay_precipitation_results.json) | v0.20.0 | v0.20.0 | status={"state":"completed"} |
| [tests/khn26/serial_benchmark_results.json](../../tests/khn26/serial_benchmark_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/serial_gate_results.json](../../tests/khn26/serial_gate_results.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/single_physical_review.json](../../tests/khn26/single_physical_review.json) | v0.20.0 | v0.20.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/khn26/ten_minute_error_source_results.json](../../tests/khn26/ten_minute_error_source_results.json) | v0.20.0 | v0.20.0 | scope="Local error-source controls on selected gate steps; no unique causal proof for full history." |
| [tests/khn26/thermodynamics_matlab_alignment_results.json](../../tests/khn26/thermodynamics_matlab_alignment_results.json) | v0.20.0 | v0.20.0 | scope="Authorized Fortran alignment to written MATLAB literals and arithmetic order; 12,180 common thermodynamic samples and ten single-step replays. No new long simulation or timing study." |
| [tests/khn26/weno_matlab_alignment_gate_results.json](../../tests/khn26/weno_matlab_alignment_gate_results.json) | v0.20.0 | v0.20.0 | gate_passed={"passed":true}; status={"state":"gates_passed","full_started":false}; scope="k=2 WENO MATLAB-written coefficient/grouping alignment; dry/native ten-minute multiACE gates, 150 dt=4 s steps each; no long integration or …（完整原文見連結） |
| [tests/reference/manus_saturated_bubble/bubble_validation.json](../../tests/reference/manus_saturated_bubble/bubble_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/reference/manus_saturated_bubble/results.json](../../tests/reference/manus_saturated_bubble/results.json) | v0.18.0 | v0.18.0 | comparison_status="Descriptive errors only; no byte equality or acceptance tolerance required" |
| [tests/reference/manus_saturated_bubble_precip/bubble_validation.json](../../tests/reference/manus_saturated_bubble_precip/bubble_validation.json) | v0.18.0 | v0.18.0 | 已保存紀錄；不可由檔案存在推定通過 |
| [tests/reference/manus_saturated_bubble_precip/results.json](../../tests/reference/manus_saturated_bubble_precip/results.json) | v0.18.0 | v0.18.0 | comparison_status="Descriptive errors only; no byte equality or acceptance tolerance required" |

## 7. 本機工作目錄總表

總表列出135個工作目錄；三個註冊worktree另排除，不視為test run。每目錄可能包含多個case、build、失敗重試或reference。
分類僅是依資料夾家族進行的導航，**不是source version認證**。配置／result內的commit/hash較可靠；無結果者記錄未明，不補上成功。
「原始狀態」直接摘錄root status；沒有rootstatus時列子jobstatus，可能包含歷史 `running`，未查核live PID，不能據此清除正在使用的檔案。
容量是邏輯MiB，不能相加當作可釋放容量。

| 工作目錄 | 導航家族（非版本認證） | 邏輯MiB | JSON數／配置數 | 原始狀態 |
| --- | --- | ---: | ---: | --- |
| [aligned_timestep_build](#workspace-001) | v0.18 development／utility | 0.23 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [aligned_timestep_run](#workspace-002) | v0.18 development／utility | 138.38 | 9/1 | 未有root狀態；查result/config；未認定通過 |
| [alignment](#workspace-003) | v0.18 development／utility | 69.32 | 5/1 | 未有root狀態；查result/config；未認定通過 |
| [alignment_precip](#workspace-004) | v0.18 development／utility | 138.02 | 7/1 | 未有root狀態；查result/config；未認定通過 |
| [alignment_repro](#workspace-005) | v0.18 development／utility | 69.32 | 5/1 | 未有root狀態；查result/config；未認定通過 |
| [fortran_v020_oop_long](#workspace-006) | v0.20.87 OOP | 1,327.15 | 10/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage0](#workspace-007) | v0.20.87 OOP | 13,954.52 | 6/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage1](#workspace-008) | v0.20.87 OOP | 13,959.24 | 8/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage2](#workspace-009) | v0.20.87 OOP | 14,543.40 | 12/3 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage3a](#workspace-010) | v0.20.87 OOP | 14,545.98 | 13/3 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage3a_compile](#workspace-011) | v0.20.87 OOP | 0.12 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [fortran_v020_oop_stage3b](#workspace-012) | v0.20.87 OOP | 33.07 | 10/3 | failure.json: {}; status.json: {"state":"running"} |
| [fortran_v020_oop_stage3b_acceptance](#workspace-013) | v0.20.87 OOP | 14,702.58 | 17/3 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage3b_verified](#workspace-014) | v0.20.87 OOP | 64.82 | 10/3 | status.json: {"state":"running"} |
| [fortran_v020_oop_stage4a](#workspace-015) | v0.20.87 OOP | 15,518.06 | 10/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage4b](#workspace-016) | v0.20.87 OOP | 16,012.26 | 11/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage5a](#workspace-017) | v0.20.87 OOP | 17,378.77 | 16/1 | status.json: {"state":"completed"} |
| [fortran_v020_oop_stage5b](#workspace-018) | v0.20.87 OOP | 17,006.84 | 14/1 | status.json: {"state":"completed"} |
| [forward_evaluation_exp_check](#workspace-019) | v0.18 development／utility | 5.32 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [forward_evaluation_exp_review](#workspace-020) | v0.18 development／utility | 3.93 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [forward_evaluation_recheck](#workspace-021) | v0.18 development／utility | 0.44 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [forward_evaluation_recheck_native](#workspace-022) | v0.18 development／utility | 5.32 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [forward_evaluation_review](#workspace-023) | v0.18 development／utility | 3.81 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [goamazon314_single_no_precip_3h](#workspace-024) | v0.18 development／utility | 27.70 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [goamazon314_single_no_precip_3h_native](#workspace-025) | v0.18 development／utility | 75.54 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [goamazon314_single_saturated_bubble_3h](#workspace-026) | v0.18 development／utility | 75.79 | 4/1 | 未有root狀態；查result/config；未認定通過 |
| [ice_heat_capacity_build](#workspace-027) | v0.18 development／utility | 0.23 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [ice_heat_capacity_run](#workspace-028) | v0.18 development／utility | 138.35 | 9/1 | 未有root狀態；查result/config；未認定通過 |
| [ice_precipitation_run](#workspace-029) | v0.18 development／utility | 69.84 | 8/1 | 未有root狀態；查result/config；未認定通過 |
| [input_adapter_review_20261004](#workspace-030) | v0.18 development／utility | 39.52 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [interp1_validation_20261004](#workspace-031) | v0.20 development／utility | 0.45 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_alignment](#workspace-032) | v0.20 development／utility | 2,195.49 | 4/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_alignment_initial](#workspace-033) | v0.20 development／utility | 2,144.55 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_basis_layout](#workspace-034) | v0.20 development／utility | 2.90 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_basis_layout_full](#workspace-035) | v0.20 development／utility | 9.61 | 3/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_blocked_model_15min](#workspace-036) | v0.20 development／utility | 37.80 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_blocked_model_1min](#workspace-037) | v0.20 development／utility | 20.89 | 5/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_ci_validation32](#workspace-038) | v0.20 development／utility | 0.03 | 4/1 | status.json: {"state":"superseded_by_matlab96_fortran32_request"} |
| [khn26_common_precip32](#workspace-039) | v0.20 development／utility | 7.24 | 6/1 | status.json: {"state":"completed"} |
| [khn26_common_precip32_ci](#workspace-040) | v0.20 development／utility | 7.24 | 5/1 | status.json: {"state":"completed"} |
| [khn26_compiler_profile](#workspace-041) | v0.20 development／utility | 0.15 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_compiler_profile_controlled](#workspace-042) | v0.20 development／utility | 0.99 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_compiler_profile_packed_forcing](#workspace-043) | v0.20 development／utility | 12.80 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_full96_32_sequence](#workspace-044) | v0.20 development／utility | 0.00 | 3/1 | status.json: {"state":"stopped_by_user","reason":"User requested stopping MATLAB; later long-run scheduling halted to prevent restarting MATLAB."} |
| [khn26_matlab_control_1min](#workspace-045) | v0.20 development／utility | 7.59 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_matlab_profile_1min](#workspace-046) | v0.20 development／utility | 7.60 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_matlab_profile_interleaved](#workspace-047) | v0.20 development／utility | 9.49 | 3/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_matlab_profile_paired](#workspace-048) | v0.20 development／utility | 0.18 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_matlab_profile_sensitivity](#workspace-049) | v0.20 development／utility | 37.95 | 11/5 | 未有root狀態；查result/config；未認定通過 |
| [khn26_matlab_single_15min](#workspace-050) | v0.20 development／utility | 0.07 | 3/1 | cancellation.json: {"state":"cancelled_by_user","reason":"User requested interruption because the single-thread run takes too long."}; status.json: {"state":"cancelled_by_user","reason":"User requested interruption because the single-thread run takes…（詳見下方紀錄） |
| [khn26_multi32_bubble_12h](#workspace-051) | v0.20 development／utility | 398.70 | 3/1 | status.json: {"state":"failed","error":"Driver affinity changed"} |
| [khn26_multi32_bubble_ci_12h](#workspace-052) | v0.20 development／utility | 6,965.50 | 18/1 | status.json: {"state":"gates_passed","full_started":false} |
| [khn26_multi32_bubble_native_12h](#workspace-053) | v0.20 development／utility | 6,878.56 | 12/1 | status.json: {"state":"failed","error":"10-minute state gate failed: [1.89661256e-07 1.02527878e-06 1.35876066e-10]"} |
| [khn26_multi_boundary_common_state](#workspace-054) | v0.20 development／utility | 139.62 | 3/1 | status.json: {"state":"completed"} |
| [khn26_multi_boundary_matlab_order](#workspace-055) | v0.20 development／utility | 139.62 | 4/1 | status.json: {"state":"completed"} |
| [khn26_multi_boundary_replay](#workspace-056) | v0.20 development／utility | 9.27 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_multi_matlab96_fortran32_12h](#workspace-057) | v0.20 development／utility | 0.43 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_multi_matlab_alignment_10min](#workspace-058) | v0.20 development／utility | 6,965.52 | 22/1 | status.json: {"state":"gates_passed","full_started":false} |
| [khn26_multi_matlab_default_fortran32_12h](#workspace-059) | v0.20 development／utility | 1,182.05 | 13/1 | status.json: {"state":"stopped_at_revised_target_pending_comparison"} |
| [khn26_multi_precipitation_three_hour](#workspace-060) | v0.20 development／utility | 1,970.09 | 7/1 | status.json: {"state":"completed"} |
| [khn26_multi_replay_precip](#workspace-061) | v0.20 development／utility | 5.78 | 6/1 | status.json: {"state":"completed"} |
| [khn26_multi_replay_precip_matlab_order](#workspace-062) | v0.20 development／utility | 8.58 | 9/1 | status.json: {"state":"completed"} |
| [khn26_multi_replay_precip_recheck](#workspace-063) | v0.20 development／utility | 5.80 | 7/1 | status.json: {"state":"completed"} |
| [khn26_multi_weno_alignment_10min](#workspace-064) | v0.20 development／utility | 3.91 | 4/1 | status.json: {"state":"failed","error":"MATLAB gate startup failed"} |
| [khn26_multi_weno_alignment_10min_licensed](#workspace-065) | v0.20 development／utility | 6,965.47 | 20/1 | status.json: {"state":"gates_passed","full_started":false} |
| [khn26_multi_weno_three_hour](#workspace-066) | v0.20 development／utility | 1,198.42 | 9/1 | status.json: {"state":"completed_pending_scientific_review"} |
| [khn26_multi_weno_three_hour_gates](#workspace-067) | v0.20 development／utility | 6,965.46 | 20/1 | status.json: {"state":"gates_passed","full_started":false} |
| [khn26_multi_weno_three_hour_sequence](#workspace-068) | v0.20 development／utility | 0.06 | 3/1 | status.json: {"state":"completed_pending_scientific_review"} |
| [khn26_p3_smoke](#workspace-069) | v0.20 development／utility | 132.73 | 7/1 | status.json: {"state":"completed","full_started":true} |
| [khn26_p3_three_hour](#workspace-070) | v0.20 development／utility | 1,826.51 | 13/1 | status.json: {"state":"completed_pending_scientific_review","full_started":true} |
| [khn26_packed_model](#workspace-071) | v0.20 development／utility | 68.45 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_precipitation_three_hour](#workspace-072) | v0.20 development／utility | 30.60 | 11/1 | status.json: {"state":"stopped_by_user"}; stop_record.json: {"state":"stopped_by_user"} |
| [khn26_review](#workspace-073) | v0.20 development／utility | 3,532.59 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_profile](#workspace-074) | v0.20 development／utility | 0.00 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_profile_1min](#workspace-075) | v0.20 development／utility | 5.21 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_profile_interleaved](#workspace-076) | v0.20 development／utility | 5.21 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_profile_sections](#workspace-077) | v0.20 development／utility | 5.62 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_simd](#workspace-078) | v0.20 development／utility | 13.38 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_serial_simd_controls](#workspace-079) | v0.20 development／utility | 17.16 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single32_native_3h](#workspace-080) | v0.20 development／utility | 3,495.92 | 8/1 | status.json: {"state":"gate_failed_pending_review"} |
| [khn26_single32_native_ci_3h](#workspace-081) | v0.20 development／utility | 3,495.91 | 7/1 | status.json: {"state":"gates_passed"} |
| [khn26_single_3h](#workspace-082) | v0.20 development／utility | 751.09 | 17/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_matlab96_fortran32_3h](#workspace-083) | v0.20 development／utility | 466.07 | 4/1 | status.json: {"state":"stopped_by_user","reason":"User requested stopping MATLAB; later long-run scheduling halted to prevent restarting MATLAB."} |
| [khn26_single_matlab_default_fortran32_3h](#workspace-084) | v0.20 development／utility | 1,095.97 | 7/1 | status.json: {"state":"completed_pending_scientific_review"} |
| [khn26_single_openmp6_3h](#workspace-085) | v0.20 development／utility | 448.76 | 8/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_production_3h](#workspace-086) | v0.20 development／utility | 89.31 | 4/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_serial_15min](#workspace-087) | v0.20 development／utility | 107.95 | 7/2 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_serial_3h](#workspace-088) | v0.20 development／utility | 106.20 | 3/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_stage_budget](#workspace-089) | v0.20 development／utility | 0.94 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [khn26_single_stage_budget_3h](#workspace-090) | v0.20 development／utility | 0.05 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [khn26_six_hour](#workspace-091) | v0.20 development／utility | 43.58 | 7/2 | 未有root狀態；查result/config；未認定通過 |
| [khn26_ten_minute_error_sources](#workspace-092) | v0.20 development／utility | 167.87 | 6/1 | status.json: {"state":"completed"} |
| [khn26_ten_minute_error_thermo](#workspace-093) | v0.20 development／utility | 7.52 | 6/1 | status.json: {"state":"completed"} |
| [makima_validation_20261004](#workspace-094) | v0.20 development／utility | 0.33 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [makima_validation_20261004_repeat](#workspace-095) | v0.20 development／utility | 0.33 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [manus208_multi_outer_pulse_12h](#workspace-096) | v0.18 development／utility | 385.57 | 7/1 | 未有root狀態；查result/config；未認定通過 |
| [manus208_multi_outer_pulse_12h_sandbox](#workspace-097) | v0.18 development／utility | 1.21 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [manus208_single_saturated_bubble_3h](#workspace-098) | v0.18 development／utility | 75.87 | 6/1 | 未有root狀態；查result/config；未認定通過 |
| [manus208_single_saturated_bubble_precip_3h](#workspace-099) | v0.18 development／utility | 1.21 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [manus208_single_saturated_bubble_precip_review](#workspace-100) | v0.18 development／utility | 94.23 | 5/1 | 未有root狀態；查result/config；未認定通過 |
| [manus_multi_double_precision_12h](#workspace-101) | v0.18 development／utility | 177.14 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [manus_multi_precision_comparison](#workspace-102) | v0.18 development／utility | 0.84 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [manus_multi_single_precision_12h](#workspace-103) | v0.18 development／utility | 135.84 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [mixed_precipitation_run](#workspace-104) | v0.18 development／utility | 69.87 | 8/1 | 未有root狀態；查result/config；未認定通過 |
| [mixed_residual_replay](#workspace-105) | v0.18 development／utility | 180.63 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [mixed_residual_review](#workspace-106) | v0.18 development／utility | 180.73 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [p3_inventory](#workspace-107) | v0.20 development／utility | 32.51 | 3/0 | 未有root狀態；查result/config；未認定通過 |
| [pchip_adoption_after](#workspace-108) | v0.20 development／utility | 0.46 | 3/0 | 未有root狀態；查result/config；未認定通過 |
| [pchip_adoption_before](#workspace-109) | v0.20 development／utility | 0.33 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [pchip_adoption_model](#workspace-110) | v0.20 development／utility | 6.63 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [pressure_power_audit](#workspace-111) | v0.18 development／utility | 2.87 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [pressure_power_check](#workspace-112) | v0.18 development／utility | 2.87 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [pressure_power_review](#workspace-113) | v0.18 development／utility | 2.87 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_alignment](#workspace-114) | v0.18 development／utility | 0.96 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_build](#workspace-115) | v0.18 development／utility | 0.23 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_diagnostic](#workspace-116) | v0.18 development／utility | 21.18 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_isolation](#workspace-117) | v0.18 development／utility | 21.18 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_paired](#workspace-118) | v0.18 development／utility | 21.24 | 2/1 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_regression](#workspace-119) | v0.18 development／utility | 275.61 | 16/1 | 未有root狀態；查result/config；未認定通過 |
| [reference_tv_run](#workspace-120) | v0.18 development／utility | 21.18 | 1/1 | 未有root狀態；查result/config；未認定通過 |
| [shared_input](#workspace-121) | v0.18 development／utility | 175.85 | 7/0 | 未有root狀態；查result/config；未認定通過 |
| [single_precision_precip](#workspace-122) | v0.18 development／utility | 1.74 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [single_precision_precip_corrected](#workspace-123) | v0.18 development／utility | 607.45 | 5/0 | 未有root狀態；查result/config；未認定通過 |
| [single_precision_precip_runner_check](#workspace-124) | v0.18 development／utility | 4.68 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [single_precision_precip_smoke](#workspace-125) | v0.18 development／utility | 4.33 | 2/0 | 未有root狀態；查result/config；未認定通過 |
| [thermodynamic_alignment](#workspace-126) | v0.18 development／utility | 3.18 | 28/4 | 未有root狀態；查result/config；未認定通過 |
| [v018_normalized_multi_12h](#workspace-127) | v0.18 development／utility | 381.57 | 3/1 | 未有root狀態；查result/config；未認定通過 |
| [v018_normalized_single_no_precip](#workspace-128) | v0.18 development／utility | 75.38 | 5/1 | 未有root狀態；查result/config；未認定通過 |
| [v018_normalized_single_precip](#workspace-129) | v0.18 development／utility | 93.77 | 5/1 | 未有root狀態；查result/config；未認定通過 |
| [v018_pre_normalization](#workspace-130) | v0.18 development／utility | 224.40 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [v02087_author_input](#workspace-131) | v0.20 development／utility | 4,235.58 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [v020_source_review](#workspace-132) | v0.20 development／utility | 1.48 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [v02187_github_release](#workspace-133) | v0.21.87／release作業 | 0.02 | 1/0 | 未有root狀態；查result/config；未認定通過 |
| [v02187_release_reconstruction](#workspace-134) | v0.21.87／release作業 | 9,739.16 | 0/0 | 未有root狀態；查result/config；未認定通過 |
| [v02187_validation](#workspace-135) | v0.21.87／release作業 | 8,878.59 | 142/42 | status.json: {"phase":"completed"}; status.json: {"phase":"stopped_for_unit_mapping_correction"}; status.json: {"phase":"stopped_investigate_matlab_thread_slowdown"}; status.json: {"phase":"completed_pending_scientific_review"}; status.json: {"phase"…（詳見下方紀錄） |

## 8. 本機詳細設定與結果路徑

每份configuration完整內容存於設定附件，以下另摘錄人類閱讀用欄位，保留JSON key path以免把planned duration與actual duration混淆。
來源SHA-256可用於確定是哪一份配置；這次只重新hash文字證據，沒有重新hash所有巨型binary結果或重驗數值。未捕捉的command／array shape／source patches等以完整configuration、results及runner為準。

<a id="workspace-001"></a>

<details>
<summary>001 — migration_work/aligned_timestep_build</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/aligned_timestep_build/build_commands.json)

</details>

<a id="workspace-002"></a>

<details>
<summary>002 — migration_work/aligned_timestep_run</summary>


**[migration_work/aligned_timestep_run/configuration.json](../../migration_work/aligned_timestep_run/configuration.json)**

原檔SHA-256：`d5a0ae781c0c58404257d5e7baaa77285b2570d4648d12cb7deafee3bec008a8`。完整附件key：`records["migration_work/aligned_timestep_run/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/aligned_timestep_run/configuration.json)
- [multi_comparison.json](../../migration_work/aligned_timestep_run/multi_comparison.json)
- [multi_precip_comparison.json](../../migration_work/aligned_timestep_run/multi_precip_comparison.json)
- [single_comparison.json](../../migration_work/aligned_timestep_run/single_comparison.json)
- [single_precip_comparison.json](../../migration_work/aligned_timestep_run/single_precip_comparison.json)
- [thermo_comparison.json](../../migration_work/aligned_timestep_run/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/aligned_timestep_run/thermo_labels.json)
- [ice_forward_review/comparison.json](../../migration_work/aligned_timestep_run/ice_forward_review/comparison.json)
- [ice_forward_trace/comparison.json](../../migration_work/aligned_timestep_run/ice_forward_trace/comparison.json)

</details>

<a id="workspace-003"></a>

<details>
<summary>003 — migration_work/alignment</summary>


**[migration_work/alignment/configuration.json](../../migration_work/alignment/configuration.json)**

原檔SHA-256：`526a5bae13218b75a6cde6b7dab97661624dee2f526d344558ea5434481d60e1`。完整附件key：`records["migration_work/alignment/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/alignment/configuration.json)
- [multi_comparison.json](../../migration_work/alignment/multi_comparison.json)
- [single_comparison.json](../../migration_work/alignment/single_comparison.json)
- [thermo_comparison.json](../../migration_work/alignment/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/alignment/thermo_labels.json)

</details>

<a id="workspace-004"></a>

<details>
<summary>004 — migration_work/alignment_precip</summary>


**[migration_work/alignment_precip/configuration.json](../../migration_work/alignment_precip/configuration.json)**

原檔SHA-256：`62ae50c19869fd1aadbc4fb9bced2a8e2ee330e81ef1e152035ee89b7fe15e8e`。完整附件key：`records["migration_work/alignment_precip/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/alignment_precip/configuration.json)
- [multi_comparison.json](../../migration_work/alignment_precip/multi_comparison.json)
- [multi_precip_comparison.json](../../migration_work/alignment_precip/multi_precip_comparison.json)
- [single_comparison.json](../../migration_work/alignment_precip/single_comparison.json)
- [single_precip_comparison.json](../../migration_work/alignment_precip/single_precip_comparison.json)
- [thermo_comparison.json](../../migration_work/alignment_precip/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/alignment_precip/thermo_labels.json)

</details>

<a id="workspace-005"></a>

<details>
<summary>005 — migration_work/alignment_repro</summary>


**[migration_work/alignment_repro/configuration.json](../../migration_work/alignment_repro/configuration.json)**

原檔SHA-256：`2a80bfae535dbf40bb5b42e42a45dd3b9d1a3342b47da015daa0a99d9663de76`。完整附件key：`records["migration_work/alignment_repro/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/alignment_repro/configuration.json)
- [multi_comparison.json](../../migration_work/alignment_repro/multi_comparison.json)
- [single_comparison.json](../../migration_work/alignment_repro/single_comparison.json)
- [thermo_comparison.json](../../migration_work/alignment_repro/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/alignment_repro/thermo_labels.json)

</details>

<a id="workspace-006"></a>

<details>
<summary>006 — migration_work/fortran_v020_oop_long</summary>

- 原始狀態 [migration_work/fortran_v020_oop_long/status.json](../../migration_work/fortran_v020_oop_long/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_long/configuration.json](../../migration_work/fortran_v020_oop_long/configuration.json)**

原檔SHA-256：`90f17dccfad63b4df0346db464017d6b25f7205f70ca3d54c96d0ff3bf6051cd`。完整附件key：`records["migration_work/fortran_v020_oop_long/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `duration_seconds` | 10800 |
| `dt_seconds` | 4 |
| `bubble_K` | 1 |
| `initial_MF` | 0 |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/fortran_v020_oop_long/build_commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_long/configuration.json)
- [results.json](../../migration_work/fortran_v020_oop_long/results.json)
- [status.json](../../migration_work/fortran_v020_oop_long/status.json)
- [native/full/launch.json](../../migration_work/fortran_v020_oop_long/native/full/launch.json)
- [p3/full/launch.json](../../migration_work/fortran_v020_oop_long/p3/full/launch.json)
- [prefix/native/plain/launch.json](../../migration_work/fortran_v020_oop_long/prefix/native/plain/launch.json)
- [prefix/native/precip/launch.json](../../migration_work/fortran_v020_oop_long/prefix/native/precip/launch.json)
- [prefix/p3/plain/launch.json](../../migration_work/fortran_v020_oop_long/prefix/p3/plain/launch.json)
- [prefix/p3/precip/launch.json](../../migration_work/fortran_v020_oop_long/prefix/p3/precip/launch.json)

</details>

<a id="workspace-007"></a>

<details>
<summary>007 — migration_work/fortran_v020_oop_stage0</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage0/status.json](../../migration_work/fortran_v020_oop_stage0/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage0/configuration.json](../../migration_work/fortran_v020_oop_stage0/configuration.json)**

原檔SHA-256：`c5b863afb041318049fb65c04b885ca4e422a5ede85ee8c6957391ecb70b86d8`。完整附件key：`records["migration_work/fortran_v020_oop_stage0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/fortran_v020_oop_stage0/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage0/configuration.json)
- [environment_evidence.json](../../migration_work/fortran_v020_oop_stage0/environment_evidence.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage0/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage0/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage0/status.json)

</details>

<a id="workspace-008"></a>

<details>
<summary>008 — migration_work/fortran_v020_oop_stage1</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage1/status.json](../../migration_work/fortran_v020_oop_stage1/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage1/configuration.json](../../migration_work/fortran_v020_oop_stage1/configuration.json)**

原檔SHA-256：`9ef6945f4c2a1a0e0901f7a77e31a13467c8fe2169ec01dd0252c177fb61d547`。完整附件key：`records["migration_work/fortran_v020_oop_stage1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage1/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage1/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage1/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage1/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage1/results.json)
- [source_scope_check.json](../../migration_work/fortran_v020_oop_stage1/source_scope_check.json)
- [status.json](../../migration_work/fortran_v020_oop_stage1/status.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage1/compatibility/results.json)

</details>

<a id="workspace-009"></a>

<details>
<summary>009 — migration_work/fortran_v020_oop_stage2</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage2/status.json](../../migration_work/fortran_v020_oop_stage2/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage2/configuration.json](../../migration_work/fortran_v020_oop_stage2/configuration.json)**

原檔SHA-256：`de896ec25265594255200eebcd6aa34a64e09a8089ca641451419f1a5ce39f70`。完整附件key：`records["migration_work/fortran_v020_oop_stage2/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

**[migration_work/fortran_v020_oop_stage2/adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage2/adapter_multi/configuration.json)**

原檔SHA-256：`2e439341527e29168f9b9c0156dcb306c4dd6c642cf23aad8abf96f11df149f3`。完整附件key：`records["migration_work/fortran_v020_oop_stage2/adapter_multi/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.3 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

**[migration_work/fortran_v020_oop_stage2/adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage2/adapter_single/configuration.json)**

原檔SHA-256：`9ded61de9939b8df9bbfbb1089999c381c75d978a1605a8f0dbf925e34a0f83c`。完整附件key：`records["migration_work/fortran_v020_oop_stage2/adapter_single/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage2/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage2/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage2/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage2/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage2/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage2/status.json)
- [adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage2/adapter_multi/configuration.json)
- [adapter_profile/results.json](../../migration_work/fortran_v020_oop_stage2/adapter_profile/results.json)
- [adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage2/adapter_single/configuration.json)
- [adapter_single/single_case.json](../../migration_work/fortran_v020_oop_stage2/adapter_single/single_case.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage2/compatibility/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage2/initialization_contract/results.json)

</details>

<a id="workspace-010"></a>

<details>
<summary>010 — migration_work/fortran_v020_oop_stage3a</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage3a/status.json](../../migration_work/fortran_v020_oop_stage3a/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage3a/configuration.json](../../migration_work/fortran_v020_oop_stage3a/configuration.json)**

原檔SHA-256：`a199780245ce73a170da072789e4428b3af751c170dafb31803ba3b67369f341`。完整附件key：`records["migration_work/fortran_v020_oop_stage3a/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

**[migration_work/fortran_v020_oop_stage3a/adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3a/adapter_multi/configuration.json)**

原檔SHA-256：`b6ef4de23ea8dda4575386511acf6254da363bc85a823f8ae9dd94e90982c2b3`。完整附件key：`records["migration_work/fortran_v020_oop_stage3a/adapter_multi/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.3 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

**[migration_work/fortran_v020_oop_stage3a/adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3a/adapter_single/configuration.json)**

原檔SHA-256：`8019164d77231aab35cad33b01be5e3994c513289d7374e6da18ffc04417e7ae`。完整附件key：`records["migration_work/fortran_v020_oop_stage3a/adapter_single/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage3a/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage3a/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage3a/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage3a/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage3a/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage3a/status.json)
- [adapter_components/results.json](../../migration_work/fortran_v020_oop_stage3a/adapter_components/results.json)
- [adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3a/adapter_multi/configuration.json)
- [adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3a/adapter_single/configuration.json)
- [adapter_single/guard_results.json](../../migration_work/fortran_v020_oop_stage3a/adapter_single/guard_results.json)
- [adapter_single/single_case.json](../../migration_work/fortran_v020_oop_stage3a/adapter_single/single_case.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage3a/compatibility/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage3a/initialization_contract/results.json)

</details>

<a id="workspace-011"></a>

<details>
<summary>011 — migration_work/fortran_v020_oop_stage3a_compile</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-012"></a>

<details>
<summary>012 — migration_work/fortran_v020_oop_stage3b</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage3b/failure.json](../../migration_work/fortran_v020_oop_stage3b/failure.json)：`{}`
- 原始狀態 [migration_work/fortran_v020_oop_stage3b/status.json](../../migration_work/fortran_v020_oop_stage3b/status.json)：`{"state":"running"}`

**[migration_work/fortran_v020_oop_stage3b/configuration.json](../../migration_work/fortran_v020_oop_stage3b/configuration.json)**

原檔SHA-256：`2e1a8e7bb6d439810013800d4e327c927dc722e7dfbf6580d09cb5b28c7fe5de`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

**[migration_work/fortran_v020_oop_stage3b/adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b/adapter_multi/configuration.json)**

原檔SHA-256：`cfd27aed3fdc7a9de9b3f84dffe12ec6a878c2caa0cf56827412218a719a2ac6`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b/adapter_multi/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

**[migration_work/fortran_v020_oop_stage3b/adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b/adapter_single/configuration.json)**

原檔SHA-256：`e70173b1e7bba6bed8ee8be4c63afcfee8ded78db9a94ced16031019d7b4743c`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b/adapter_single/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/fortran_v020_oop_stage3b/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage3b/configuration.json)
- [failure.json](../../migration_work/fortran_v020_oop_stage3b/failure.json)
- [status.json](../../migration_work/fortran_v020_oop_stage3b/status.json)
- [adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b/adapter_multi/configuration.json)
- [adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b/adapter_single/configuration.json)
- [adapter_single/guard_results.json](../../migration_work/fortran_v020_oop_stage3b/adapter_single/guard_results.json)
- [adapter_single/single_case.json](../../migration_work/fortran_v020_oop_stage3b/adapter_single/single_case.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage3b/compatibility/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage3b/integration_contract/results.json)

</details>

<a id="workspace-013"></a>

<details>
<summary>013 — migration_work/fortran_v020_oop_stage3b_acceptance</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage3b_acceptance/status.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage3b_acceptance/configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/configuration.json)**

原檔SHA-256：`ed80ed21919ce24d77f7433d89ef0e5f051696371b1e641b474835ab31505312`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_acceptance/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

**[migration_work/fortran_v020_oop_stage3b_acceptance/adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_multi/configuration.json)**

原檔SHA-256：`2716a189d3fd08f29aa3746f5faf5d4254e0a62f5a9dfc1d84c81f82a8fcb7dd`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_acceptance/adapter_multi/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

**[migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/configuration.json)**

原檔SHA-256：`90afcddce804ac6f788fab84fd5498f0b2ae2e7b3ffab978c5c7ce505e52b69d`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/status.json)
- [supplemental_validity.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/supplemental_validity.json)
- [adapter_components/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_components/results.json)
- [adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_multi/configuration.json)
- [adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/configuration.json)
- [adapter_single/guard_results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/guard_results.json)
- [adapter_single/single_case.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/adapter_single/single_case.json)
- [common_probe_compile/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/common_probe_compile/results.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/compatibility/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/integration_contract/results.json)
- [legacy_driver_contract/results.json](../../migration_work/fortran_v020_oop_stage3b_acceptance/legacy_driver_contract/results.json)

</details>

<a id="workspace-014"></a>

<details>
<summary>014 — migration_work/fortran_v020_oop_stage3b_verified</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage3b_verified/status.json](../../migration_work/fortran_v020_oop_stage3b_verified/status.json)：`{"state":"running"}`

**[migration_work/fortran_v020_oop_stage3b_verified/configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/configuration.json)**

原檔SHA-256：`c62e3520a659ef44f01961f1565b15e440793a13200d7f7a5a37440177209c50`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_verified/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

**[migration_work/fortran_v020_oop_stage3b_verified/adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_multi/configuration.json)**

原檔SHA-256：`12333ebf910dc8a808020c84b835106c2d46eb0701c84e9ca522c1d54ea74bf1`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_verified/adapter_multi/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

**[migration_work/fortran_v020_oop_stage3b_verified/adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_single/configuration.json)**

原檔SHA-256：`d3e95624c77f3b8b7be56f078902c23bf9ffcd85c4c60b5bfde28d1290e3a262`。完整附件key：`records["migration_work/fortran_v020_oop_stage3b_verified/adapter_single/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/fortran_v020_oop_stage3b_verified/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/configuration.json)
- [status.json](../../migration_work/fortran_v020_oop_stage3b_verified/status.json)
- [adapter_components/results.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_components/results.json)
- [adapter_multi/configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_multi/configuration.json)
- [adapter_single/configuration.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_single/configuration.json)
- [adapter_single/single_case.json](../../migration_work/fortran_v020_oop_stage3b_verified/adapter_single/single_case.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage3b_verified/compatibility/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage3b_verified/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage3b_verified/integration_contract/results.json)

</details>

<a id="workspace-015"></a>

<details>
<summary>015 — migration_work/fortran_v020_oop_stage4a</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage4a/status.json](../../migration_work/fortran_v020_oop_stage4a/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage4a/configuration.json](../../migration_work/fortran_v020_oop_stage4a/configuration.json)**

原檔SHA-256：`a2512fbc053339b3dcd4653d018edcfe6fc8240ac777fd2e47d2a4356868bc59`。完整附件key：`records["migration_work/fortran_v020_oop_stage4a/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage4a/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage4a/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage4a/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage4a/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage4a/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage4a/status.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage4a/compatibility/results.json)
- [diagnose_contract/results.json](../../migration_work/fortran_v020_oop_stage4a/diagnose_contract/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage4a/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage4a/integration_contract/results.json)

</details>

<a id="workspace-016"></a>

<details>
<summary>016 — migration_work/fortran_v020_oop_stage4b</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage4b/status.json](../../migration_work/fortran_v020_oop_stage4b/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage4b/configuration.json](../../migration_work/fortran_v020_oop_stage4b/configuration.json)**

原檔SHA-256：`7f4452a27a9e022d4b7ba2df58b8d7b897035cfbd926185bc159eda732496999`。完整附件key：`records["migration_work/fortran_v020_oop_stage4b/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage4b/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage4b/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage4b/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage4b/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage4b/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage4b/status.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage4b/compatibility/results.json)
- [diagnose_contract/results.json](../../migration_work/fortran_v020_oop_stage4b/diagnose_contract/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage4b/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage4b/integration_contract/results.json)
- [output_contract/results.json](../../migration_work/fortran_v020_oop_stage4b/output_contract/results.json)

</details>

<a id="workspace-017"></a>

<details>
<summary>017 — migration_work/fortran_v020_oop_stage5a</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage5a/status.json](../../migration_work/fortran_v020_oop_stage5a/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage5a/configuration.json](../../migration_work/fortran_v020_oop_stage5a/configuration.json)**

原檔SHA-256：`968976b6f597acbc87c3dae631e0b66d93310f9c331885133e4f8a55edeedb8d`。完整附件key：`records["migration_work/fortran_v020_oop_stage5a/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage5a/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage5a/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage5a/configuration.json)
- [fixture_layout_audit.json](../../migration_work/fortran_v020_oop_stage5a/fixture_layout_audit.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage5a/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage5a/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage5a/status.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage5a/compatibility/results.json)
- [damping_contract/attempt_status.json](../../migration_work/fortran_v020_oop_stage5a/damping_contract/attempt_status.json)
- [damping_contract/results.json](../../migration_work/fortran_v020_oop_stage5a/damping_contract/results.json)
- [damping_contract_aligned/results.json](../../migration_work/fortran_v020_oop_stage5a/damping_contract_aligned/results.json)
- [diagnose_contract/results.json](../../migration_work/fortran_v020_oop_stage5a/diagnose_contract/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage5a/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage5a/integration_contract/results.json)
- [output_contract/results.json](../../migration_work/fortran_v020_oop_stage5a/output_contract/results.json)
- [profile_adapter/results.json](../../migration_work/fortran_v020_oop_stage5a/profile_adapter/results.json)

</details>

<a id="workspace-018"></a>

<details>
<summary>018 — migration_work/fortran_v020_oop_stage5b</summary>

- 原始狀態 [migration_work/fortran_v020_oop_stage5b/status.json](../../migration_work/fortran_v020_oop_stage5b/status.json)：`{"state":"completed"}`

**[migration_work/fortran_v020_oop_stage5b/configuration.json](../../migration_work/fortran_v020_oop_stage5b/configuration.json)**

原檔SHA-256：`4068568455f6b50171a916ecd08d83a3174016c4fabc9e30d1ddf79b18bd1856`。完整附件key：`records["migration_work/fortran_v020_oop_stage5b/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `threads` | 32 |
| `default_bubble_K` | 0.25 |
| `dt_seconds` | 4 |
| `prefix_steps` | 10 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [baseline_comparison.json](../../migration_work/fortran_v020_oop_stage5b/baseline_comparison.json)
- [commands.json](../../migration_work/fortran_v020_oop_stage5b/commands.json)
- [configuration.json](../../migration_work/fortran_v020_oop_stage5b/configuration.json)
- [observation_layouts.json](../../migration_work/fortran_v020_oop_stage5b/observation_layouts.json)
- [results.json](../../migration_work/fortran_v020_oop_stage5b/results.json)
- [status.json](../../migration_work/fortran_v020_oop_stage5b/status.json)
- [compatibility/results.json](../../migration_work/fortran_v020_oop_stage5b/compatibility/results.json)
- [damping_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/damping_contract/results.json)
- [diagnose_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/diagnose_contract/results.json)
- [initialization_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/initialization_contract/results.json)
- [integration_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/integration_contract/results.json)
- [output_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/output_contract/results.json)
- [p3_contract/results.json](../../migration_work/fortran_v020_oop_stage5b/p3_contract/results.json)
- [profile_adapter/results.json](../../migration_work/fortran_v020_oop_stage5b/profile_adapter/results.json)

</details>

<a id="workspace-019"></a>

<details>
<summary>019 — migration_work/forward_evaluation_exp_check</summary>


**[migration_work/forward_evaluation_exp_check/configuration.json](../../migration_work/forward_evaluation_exp_check/configuration.json)**

原檔SHA-256：`0dadba2a6b1e55bbb42bd6ca7291589a1c4ad533cd7433638782468dfd6d44d2`。完整附件key：`records["migration_work/forward_evaluation_exp_check/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/forward_evaluation_exp_check/configuration.json)
- [results.json](../../migration_work/forward_evaluation_exp_check/results.json)

</details>

<a id="workspace-020"></a>

<details>
<summary>020 — migration_work/forward_evaluation_exp_review</summary>


**[migration_work/forward_evaluation_exp_review/configuration.json](../../migration_work/forward_evaluation_exp_review/configuration.json)**

原檔SHA-256：`0dadba2a6b1e55bbb42bd6ca7291589a1c4ad533cd7433638782468dfd6d44d2`。完整附件key：`records["migration_work/forward_evaluation_exp_review/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/forward_evaluation_exp_review/configuration.json)

</details>

<a id="workspace-021"></a>

<details>
<summary>021 — migration_work/forward_evaluation_recheck</summary>


**[migration_work/forward_evaluation_recheck/configuration.json](../../migration_work/forward_evaluation_recheck/configuration.json)**

原檔SHA-256：`e91c7321ab9ef1c12794b97e74ea9cc87c1efa330b7b35bfca8cf9a975f022f1`。完整附件key：`records["migration_work/forward_evaluation_recheck/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/forward_evaluation_recheck/configuration.json)

</details>

<a id="workspace-022"></a>

<details>
<summary>022 — migration_work/forward_evaluation_recheck_native</summary>


**[migration_work/forward_evaluation_recheck_native/configuration.json](../../migration_work/forward_evaluation_recheck_native/configuration.json)**

原檔SHA-256：`e91c7321ab9ef1c12794b97e74ea9cc87c1efa330b7b35bfca8cf9a975f022f1`。完整附件key：`records["migration_work/forward_evaluation_recheck_native/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/forward_evaluation_recheck_native/configuration.json)
- [results.json](../../migration_work/forward_evaluation_recheck_native/results.json)

</details>

<a id="workspace-023"></a>

<details>
<summary>023 — migration_work/forward_evaluation_review</summary>


**[migration_work/forward_evaluation_review/configuration.json](../../migration_work/forward_evaluation_review/configuration.json)**

原檔SHA-256：`0dadba2a6b1e55bbb42bd6ca7291589a1c4ad533cd7433638782468dfd6d44d2`。完整附件key：`records["migration_work/forward_evaluation_review/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/forward_evaluation_review/configuration.json)
- [results.json](../../migration_work/forward_evaluation_review/results.json)

</details>

<a id="workspace-024"></a>

<details>
<summary>024 — migration_work/goamazon314_single_no_precip_3h</summary>


**[migration_work/goamazon314_single_no_precip_3h/configuration.json](../../migration_work/goamazon314_single_no_precip_3h/configuration.json)**

原檔SHA-256：`e91c7321ab9ef1c12794b97e74ea9cc87c1efa330b7b35bfca8cf9a975f022f1`。完整附件key：`records["migration_work/goamazon314_single_no_precip_3h/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/goamazon314_single_no_precip_3h/configuration.json)

</details>

<a id="workspace-025"></a>

<details>
<summary>025 — migration_work/goamazon314_single_no_precip_3h_native</summary>


**[migration_work/goamazon314_single_no_precip_3h_native/configuration.json](../../migration_work/goamazon314_single_no_precip_3h_native/configuration.json)**

原檔SHA-256：`e91c7321ab9ef1c12794b97e74ea9cc87c1efa330b7b35bfca8cf9a975f022f1`。完整附件key：`records["migration_work/goamazon314_single_no_precip_3h_native/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/goamazon314_single_no_precip_3h_native/configuration.json)
- [results.json](../../migration_work/goamazon314_single_no_precip_3h_native/results.json)

</details>

<a id="workspace-026"></a>

<details>
<summary>026 — migration_work/goamazon314_single_saturated_bubble_3h</summary>


**[migration_work/goamazon314_single_saturated_bubble_3h/configuration.json](../../migration_work/goamazon314_single_saturated_bubble_3h/configuration.json)**

原檔SHA-256：`ca79049c5035ec4bdf45532f80ea92c2fe57ec3cf0a257b7698c8aba062dfefa`。完整附件key：`records["migration_work/goamazon314_single_saturated_bubble_3h/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [bubble_validation.json](../../migration_work/goamazon314_single_saturated_bubble_3h/bubble_validation.json)
- [commands.json](../../migration_work/goamazon314_single_saturated_bubble_3h/commands.json)
- [configuration.json](../../migration_work/goamazon314_single_saturated_bubble_3h/configuration.json)
- [results.json](../../migration_work/goamazon314_single_saturated_bubble_3h/results.json)

</details>

<a id="workspace-027"></a>

<details>
<summary>027 — migration_work/ice_heat_capacity_build</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/ice_heat_capacity_build/build_commands.json)

</details>

<a id="workspace-028"></a>

<details>
<summary>028 — migration_work/ice_heat_capacity_run</summary>


**[migration_work/ice_heat_capacity_run/configuration.json](../../migration_work/ice_heat_capacity_run/configuration.json)**

原檔SHA-256：`1108d9f111f90b940524ef8c88ce479035381fbd588d6007fcd3429f911693eb`。完整附件key：`records["migration_work/ice_heat_capacity_run/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [change_scope.json](../../migration_work/ice_heat_capacity_run/change_scope.json)
- [configuration.json](../../migration_work/ice_heat_capacity_run/configuration.json)
- [multi_comparison.json](../../migration_work/ice_heat_capacity_run/multi_comparison.json)
- [multi_precip_comparison.json](../../migration_work/ice_heat_capacity_run/multi_precip_comparison.json)
- [review.json](../../migration_work/ice_heat_capacity_run/review.json)
- [single_comparison.json](../../migration_work/ice_heat_capacity_run/single_comparison.json)
- [single_precip_comparison.json](../../migration_work/ice_heat_capacity_run/single_precip_comparison.json)
- [thermo_comparison.json](../../migration_work/ice_heat_capacity_run/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/ice_heat_capacity_run/thermo_labels.json)

</details>

<a id="workspace-029"></a>

<details>
<summary>029 — migration_work/ice_precipitation_run</summary>


**[migration_work/ice_precipitation_run/configuration.json](../../migration_work/ice_precipitation_run/configuration.json)**

原檔SHA-256：`ac80bf9afedca4bcdb6c75c134ffc62c15a480dc985bff3a3964f6c3093a4ada`。完整附件key：`records["migration_work/ice_precipitation_run/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/ice_precipitation_run/configuration.json)
- [multi_ice_precip_comparison.json](../../migration_work/ice_precipitation_run/multi_ice_precip_comparison.json)
- [multi_ice_precip_ice_evidence.json](../../migration_work/ice_precipitation_run/multi_ice_precip_ice_evidence.json)
- [review.json](../../migration_work/ice_precipitation_run/review.json)
- [single_ice_precip_comparison.json](../../migration_work/ice_precipitation_run/single_ice_precip_comparison.json)
- [single_ice_precip_ice_evidence.json](../../migration_work/ice_precipitation_run/single_ice_precip_ice_evidence.json)
- [thermo_comparison.json](../../migration_work/ice_precipitation_run/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/ice_precipitation_run/thermo_labels.json)

</details>

<a id="workspace-030"></a>

<details>
<summary>030 — migration_work/input_adapter_review_20261004</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/input_adapter_review_20261004/results.json)

</details>

<a id="workspace-031"></a>

<details>
<summary>031 — migration_work/interp1_validation_20261004</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/interp1_validation_20261004/metadata.json](../../migration_work/interp1_validation_20261004/metadata.json)**

原檔SHA-256：`f8bad0f673a892c71c3e710b46f1412d4adb2551c563643d9b76b0aac645ba66`。完整附件key：`records["migration_work/interp1_validation_20261004/metadata.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

**[migration_work/interp1_validation_20261004/results.json](../../migration_work/interp1_validation_20261004/results.json)**

原檔SHA-256：`840d08050f3a02d3525750a424e3971dc32829a59478ae1b63c873a57920a5ad`。完整附件key：`records["migration_work/interp1_validation_20261004/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [metadata.json](../../migration_work/interp1_validation_20261004/metadata.json)
- [results.json](../../migration_work/interp1_validation_20261004/results.json)

</details>

<a id="workspace-032"></a>

<details>
<summary>032 — migration_work/khn26_alignment</summary>


**[migration_work/khn26_alignment/configuration.json](../../migration_work/khn26_alignment/configuration.json)**

原檔SHA-256：`2bb02878a74d298f1749b49d14713b9443a345b8c2b38f2417310ae6823bd967`。完整附件key：`records["migration_work/khn26_alignment/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_alignment/configuration.json)
- [guard_results.json](../../migration_work/khn26_alignment/guard_results.json)
- [results.json](../../migration_work/khn26_alignment/results.json)
- [smoke_results.json](../../migration_work/khn26_alignment/smoke_results.json)

</details>

<a id="workspace-033"></a>

<details>
<summary>033 — migration_work/khn26_alignment_initial</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_alignment_initial/results.json](../../migration_work/khn26_alignment_initial/results.json)**

原檔SHA-256：`2e8d62acfe1a5d54641350269ae60b0565de836af0b5b57da7540eefaddfc24d`。完整附件key：`records["migration_work/khn26_alignment_initial/results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/khn26_alignment_initial/build_commands.json)
- [results.json](../../migration_work/khn26_alignment_initial/results.json)

</details>

<a id="workspace-034"></a>

<details>
<summary>034 — migration_work/khn26_basis_layout</summary>


**[migration_work/khn26_basis_layout/configuration.json](../../migration_work/khn26_basis_layout/configuration.json)**

原檔SHA-256：`b5ad90f404aad87ffde9939e042982096ea9bdb6434c9822513978a6ac9bc9de`。完整附件key：`records["migration_work/khn26_basis_layout/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `seed` | "/scratch/peter50504/ACE/migration_work/khn26_single_3h/smoke_fortran_states.bin" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_basis_layout/configuration.json)

</details>

<a id="workspace-035"></a>

<details>
<summary>035 — migration_work/khn26_basis_layout_full</summary>


**[migration_work/khn26_basis_layout_full/configuration.json](../../migration_work/khn26_basis_layout_full/configuration.json)**

原檔SHA-256：`08f60fc0de4a3df39ac8460da4a9db88b1d6eab301a6f6396570a7e46df2a22f`。完整附件key：`records["migration_work/khn26_basis_layout_full/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `seed` | "/scratch/peter50504/ACE/migration_work/khn26_single_3h/smoke_fortran_states.bin" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_basis_layout_full/configuration.json)
- [matlab_results.json](../../migration_work/khn26_basis_layout_full/matlab_results.json)
- [results.json](../../migration_work/khn26_basis_layout_full/results.json)

</details>

<a id="workspace-036"></a>

<details>
<summary>036 — migration_work/khn26_blocked_model_15min</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_blocked_model_15min/profile_results.json](../../migration_work/khn26_blocked_model_15min/profile_results.json)**

原檔SHA-256：`bad870404834cb637522675959c6d062236bd6b8a96f677eee6f1775cf49005c`。完整附件key：`records["migration_work/khn26_blocked_model_15min/profile_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 900 |
| `steps` | 225 |
| `flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [profile_results.json](../../migration_work/khn26_blocked_model_15min/profile_results.json)

</details>

<a id="workspace-037"></a>

<details>
<summary>037 — migration_work/khn26_blocked_model_1min</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_blocked_model_1min/blocked_model_results.json](../../migration_work/khn26_blocked_model_1min/blocked_model_results.json)**

原檔SHA-256：`221a872de8eeeb0f19710743199bde6dafe98ba12a9079cd667328663b322b86`。完整附件key：`records["migration_work/khn26_blocked_model_1min/blocked_model_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `comparison` | [{"section":"nonlocal_response_interpolation_assembly","matlab_ms_per_step":1559.1510333333335,"control_before_ms_per_step":4060.3170963333337,"outputs4_ms_per_step":2327.5786608666644,"outputs8_ms_per_step":2327.159776799999,"control_after_ms_per_step":4074.4347521999966},{"section":"transport_and_other_buoyancy_setup","matlab_ms_per_step":143.44083333333336,"control_before_ms_per_step":49.10616800000005,"outputs4_ms_per_step":51.195798533333345,"outputs8_ms_per_step":56.39525413333333,"control_after_ms_per_step":49.174574666666686},{"section":"thermodynamic_inversions","matlab_ms_per_step":187.33596666666668,"control_before_ms_per_step":12.797050933333319,"outputs4_ms_per_step":12.841846799999983,"outputs8_ms_per_step":12.813277933333348,"control_after_ms_per_step":12.83141946666665},{"section":"damping","matlab_ms_per_step":0.6554000000000001,"control_before_ms_per_step":0.25410746666666667,"outputs4_ms_per_step":0.25347546666666665,"outputs8_ms_per_step":0.2536658,"control_after_ms_per_step":0.25311646666666665},{"section":"other_driver_timer_overhead","matlab_ms_per_step":11.975333333332898,"control_before_ms_per_step":2.442952533333672,"outputs4_ms_per_step":2.602279000002265,"outputs8_ms_per_step":2.8321145333345994,"control_after_ms_per_step":2.4636602666693834}] |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [blocked_model_results.json](../../migration_work/khn26_blocked_model_1min/blocked_model_results.json)
- [control_after/profile_results.json](../../migration_work/khn26_blocked_model_1min/control_after/profile_results.json)
- [control_before/profile_results.json](../../migration_work/khn26_blocked_model_1min/control_before/profile_results.json)
- [outputs4/profile_results.json](../../migration_work/khn26_blocked_model_1min/outputs4/profile_results.json)
- [outputs8/profile_results.json](../../migration_work/khn26_blocked_model_1min/outputs8/profile_results.json)

</details>

<a id="workspace-038"></a>

<details>
<summary>038 — migration_work/khn26_ci_validation32</summary>

- 原始狀態 [migration_work/khn26_ci_validation32/status.json](../../migration_work/khn26_ci_validation32/status.json)：`{"state":"superseded_by_matlab96_fortran32_request"}`

**[migration_work/khn26_ci_validation32/configuration.json](../../migration_work/khn26_ci_validation32/configuration.json)**

原檔SHA-256：`90b7c5de3bd61b0fcb0520e32806ccc36d343c46fccf6a91703bf516b9aa66f8`。完整附件key：`records["migration_work/khn26_ci_validation32/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `policy` | "Single and multi short gates both finish before long runs. All stages run sequentially; each language has cap 32 and disjoint cores. Unchanged regression limits." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_ci_validation32/configuration.json)
- [outcomes.json](../../migration_work/khn26_ci_validation32/outcomes.json)
- [status.json](../../migration_work/khn26_ci_validation32/status.json)
- [supervisor.json](../../migration_work/khn26_ci_validation32/supervisor.json)

</details>

<a id="workspace-039"></a>

<details>
<summary>039 — migration_work/khn26_common_precip32</summary>

- 原始狀態 [migration_work/khn26_common_precip32/status.json](../../migration_work/khn26_common_precip32/status.json)：`{"state":"completed"}`

**[migration_work/khn26_common_precip32/configuration.json](../../migration_work/khn26_common_precip32/configuration.json)**

原檔SHA-256：`63642b63b6a37f1b56e1ba83134c4962f2023b769027a5ac9e4b231bf4d22970`。完整附件key：`records["migration_work/khn26_common_precip32/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 19248 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [ci_attribution.json](../../migration_work/khn26_common_precip32/ci_attribution.json)
- [configuration.json](../../migration_work/khn26_common_precip32/configuration.json)
- [results.json](../../migration_work/khn26_common_precip32/results.json)
- [sample_labels.json](../../migration_work/khn26_common_precip32/sample_labels.json)
- [status.json](../../migration_work/khn26_common_precip32/status.json)
- [supervisor.json](../../migration_work/khn26_common_precip32/supervisor.json)

</details>

<a id="workspace-040"></a>

<details>
<summary>040 — migration_work/khn26_common_precip32_ci</summary>

- 原始狀態 [migration_work/khn26_common_precip32_ci/status.json](../../migration_work/khn26_common_precip32_ci/status.json)：`{"state":"completed"}`

**[migration_work/khn26_common_precip32_ci/configuration.json](../../migration_work/khn26_common_precip32_ci/configuration.json)**

原檔SHA-256：`2913197f0b31b336b863eeeb4df415f5aa655810a1ebd4c151373d295901628d`。完整附件key：`records["migration_work/khn26_common_precip32_ci/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 19248 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_common_precip32_ci/configuration.json)
- [results.json](../../migration_work/khn26_common_precip32_ci/results.json)
- [sample_labels.json](../../migration_work/khn26_common_precip32_ci/sample_labels.json)
- [status.json](../../migration_work/khn26_common_precip32_ci/status.json)
- [supervisor.json](../../migration_work/khn26_common_precip32_ci/supervisor.json)

</details>

<a id="workspace-041"></a>

<details>
<summary>041 — migration_work/khn26_compiler_profile</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-042"></a>

<details>
<summary>042 — migration_work/khn26_compiler_profile_controlled</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-043"></a>

<details>
<summary>043 — migration_work/khn26_compiler_profile_packed_forcing</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_compiler_profile_packed_forcing/compiler_results.json](../../migration_work/khn26_compiler_profile_packed_forcing/compiler_results.json)**

原檔SHA-256：`3c6161fba0d0bb6fd9792e96b38d33889c5b94b2dfa5f3193761539b5c668be7`。完整附件key：`records["migration_work/khn26_compiler_profile_packed_forcing/compiler_results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [compiler_results.json](../../migration_work/khn26_compiler_profile_packed_forcing/compiler_results.json)

</details>

<a id="workspace-044"></a>

<details>
<summary>044 — migration_work/khn26_full96_32_sequence</summary>

- 原始狀態 [migration_work/khn26_full96_32_sequence/status.json](../../migration_work/khn26_full96_32_sequence/status.json)：`{"state":"stopped_by_user","reason":"User requested stopping MATLAB; later long-run scheduling halted to prevent restarting MATLAB."}`

**[migration_work/khn26_full96_32_sequence/configuration.json](../../migration_work/khn26_full96_32_sequence/configuration.json)**

原檔SHA-256：`47519239e7dd733213bde5a07f8a9d7120bb6a5615fe43d22ebc5a3c34277892`。完整附件key：`records["migration_work/khn26_full96_32_sequence/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `policy` | "Finish active multiACE short gates, then native singleACE three hours, then native multiACE twelve hours. Sequential runs; no physical-core overlap between languages." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_full96_32_sequence/configuration.json)
- [status.json](../../migration_work/khn26_full96_32_sequence/status.json)
- [supervisor.json](../../migration_work/khn26_full96_32_sequence/supervisor.json)

</details>

<a id="workspace-045"></a>

<details>
<summary>045 — migration_work/khn26_matlab_control_1min</summary>


**[migration_work/khn26_matlab_control_1min/configuration.json](../../migration_work/khn26_matlab_control_1min/configuration.json)**

原檔SHA-256：`93bc3d8c74981c448d0a926427c81b3de1279e1be03acf5d7f328628cbc8af78`。完整附件key：`records["migration_work/khn26_matlab_control_1min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_matlab_control_1min/configuration.json)
- [control_results.json](../../migration_work/khn26_matlab_control_1min/control_results.json)

</details>

<a id="workspace-046"></a>

<details>
<summary>046 — migration_work/khn26_matlab_profile_1min</summary>


**[migration_work/khn26_matlab_profile_1min/configuration.json](../../migration_work/khn26_matlab_profile_1min/configuration.json)**

原檔SHA-256：`ef0078e88f959e31f99887f3ef1a7747c5f5bdec398022d89115f7dc1ab841bd`。完整附件key：`records["migration_work/khn26_matlab_profile_1min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_matlab_profile_1min/configuration.json)
- [profile_results.json](../../migration_work/khn26_matlab_profile_1min/profile_results.json)

</details>

<a id="workspace-047"></a>

<details>
<summary>047 — migration_work/khn26_matlab_profile_interleaved</summary>


**[migration_work/khn26_matlab_profile_interleaved/configuration.json](../../migration_work/khn26_matlab_profile_interleaved/configuration.json)**

原檔SHA-256：`c145a8127a1bcd57cfb003620d2e5399e7ebd8b009592a2bf061848de377796a`。完整附件key：`records["migration_work/khn26_matlab_profile_interleaved/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [combined_profile_results.json](../../migration_work/khn26_matlab_profile_interleaved/combined_profile_results.json)
- [configuration.json](../../migration_work/khn26_matlab_profile_interleaved/configuration.json)
- [paired_results.json](../../migration_work/khn26_matlab_profile_interleaved/paired_results.json)

</details>

<a id="workspace-048"></a>

<details>
<summary>048 — migration_work/khn26_matlab_profile_paired</summary>


**[migration_work/khn26_matlab_profile_paired/configuration.json](../../migration_work/khn26_matlab_profile_paired/configuration.json)**

原檔SHA-256：`cca197541fae3afdaaa877fdb1d6889a3360abeea0336fdff4cceee9ee61d54f`。完整附件key：`records["migration_work/khn26_matlab_profile_paired/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_matlab_profile_paired/configuration.json)

</details>

<a id="workspace-049"></a>

<details>
<summary>049 — migration_work/khn26_matlab_profile_sensitivity</summary>


**[migration_work/khn26_matlab_profile_sensitivity/control_after/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/control_after/configuration.json)**

原檔SHA-256：`841546ab3667f532c5e748cfaaa2464c214bc81842aacf72bfebbd561d258fe0`。完整附件key：`records["migration_work/khn26_matlab_profile_sensitivity/control_after/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

**[migration_work/khn26_matlab_profile_sensitivity/control_before/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/control_before/configuration.json)**

原檔SHA-256：`c8ddeae3f03e0780bcfadbfbad0546f695fcb364de00a5493256654470f0fd80`。完整附件key：`records["migration_work/khn26_matlab_profile_sensitivity/control_before/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

**[migration_work/khn26_matlab_profile_sensitivity/split_only/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/split_only/configuration.json)**

原檔SHA-256：`1c70e74acebea7844feb1f8252f769c7ca74c1a684e4b3ce704ceccd8d03b7e8`。完整附件key：`records["migration_work/khn26_matlab_profile_sensitivity/split_only/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

**[migration_work/khn26_matlab_profile_sensitivity/split_timers/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/split_timers/configuration.json)**

原檔SHA-256：`9c3e2434c6c0b7382a08f4a1c99dd66fa1d063e72b42fbc67782f9662a91a65f`。完整附件key：`records["migration_work/khn26_matlab_profile_sensitivity/split_timers/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

**[migration_work/khn26_matlab_profile_sensitivity/unsplit_timers/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/unsplit_timers/configuration.json)**

原檔SHA-256：`7d738c0339fb37e035fab17d5cf4eb33f216aa3bc0647ee182fc6098f5c97c8a`。完整附件key：`records["migration_work/khn26_matlab_profile_sensitivity/unsplit_timers/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [sensitivity_results.json](../../migration_work/khn26_matlab_profile_sensitivity/sensitivity_results.json)
- [control_after/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/control_after/configuration.json)
- [control_after/control_results.json](../../migration_work/khn26_matlab_profile_sensitivity/control_after/control_results.json)
- [control_before/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/control_before/configuration.json)
- [control_before/control_results.json](../../migration_work/khn26_matlab_profile_sensitivity/control_before/control_results.json)
- [split_only/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/split_only/configuration.json)
- [split_only/control_results.json](../../migration_work/khn26_matlab_profile_sensitivity/split_only/control_results.json)
- [split_timers/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/split_timers/configuration.json)
- [split_timers/profile_results.json](../../migration_work/khn26_matlab_profile_sensitivity/split_timers/profile_results.json)
- [unsplit_timers/configuration.json](../../migration_work/khn26_matlab_profile_sensitivity/unsplit_timers/configuration.json)
- [unsplit_timers/profile_results.json](../../migration_work/khn26_matlab_profile_sensitivity/unsplit_timers/profile_results.json)

</details>

<a id="workspace-050"></a>

<details>
<summary>050 — migration_work/khn26_matlab_single_15min</summary>

- 原始狀態 [migration_work/khn26_matlab_single_15min/cancellation.json](../../migration_work/khn26_matlab_single_15min/cancellation.json)：`{"state":"cancelled_by_user","reason":"User requested interruption because the single-thread run takes too long."}`
- 原始狀態 [migration_work/khn26_matlab_single_15min/status.json](../../migration_work/khn26_matlab_single_15min/status.json)：`{"state":"cancelled_by_user","reason":"User requested interruption because the single-thread run takes too long."}`

**[migration_work/khn26_matlab_single_15min/configuration.json](../../migration_work/khn26_matlab_single_15min/configuration.json)**

原檔SHA-256：`269c0356d7429812437bcf73335ecc87030dbfb50a1e47e23af4c04255fd0aae`。完整附件key：`records["migration_work/khn26_matlab_single_15min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 900 |
| `steps` | 225 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [cancellation.json](../../migration_work/khn26_matlab_single_15min/cancellation.json)
- [configuration.json](../../migration_work/khn26_matlab_single_15min/configuration.json)
- [status.json](../../migration_work/khn26_matlab_single_15min/status.json)

</details>

<a id="workspace-051"></a>

<details>
<summary>051 — migration_work/khn26_multi32_bubble_12h</summary>

- 原始狀態 [migration_work/khn26_multi32_bubble_12h/status.json](../../migration_work/khn26_multi32_bubble_12h/status.json)：`{"state":"failed","error":"Driver affinity changed"}`

**[migration_work/khn26_multi32_bubble_12h/configuration.json](../../migration_work/khn26_multi32_bubble_12h/configuration.json)**

原檔SHA-256：`8f861adaf23528a567ed5ae50693dc103be614a5bdaae098f114ad6d05b64dea`。完整附件key：`records["migration_work/khn26_multi32_bubble_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 43200 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi32_bubble_12h/configuration.json)
- [status.json](../../migration_work/khn26_multi32_bubble_12h/status.json)
- [supervisor.json](../../migration_work/khn26_multi32_bubble_12h/supervisor.json)

</details>

<a id="workspace-052"></a>

<details>
<summary>052 — migration_work/khn26_multi32_bubble_ci_12h</summary>

- 原始狀態 [migration_work/khn26_multi32_bubble_ci_12h/status.json](../../migration_work/khn26_multi32_bubble_ci_12h/status.json)：`{"state":"gates_passed","full_started":false}`

**[migration_work/khn26_multi32_bubble_ci_12h/configuration.json](../../migration_work/khn26_multi32_bubble_ci_12h/configuration.json)**

原檔SHA-256：`6668264f4256360c233888af7d593ddc38c28a198e55ad65febe0de542611117`。完整附件key：`records["migration_work/khn26_multi32_bubble_ci_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 43200 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi32_bubble_ci_12h/configuration.json)
- [gate_native_gate_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native_gate_results.json)
- [gate_native_passed.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native_passed.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native_tendency_results.json)
- [gate_none_gate_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none_gate_results.json)
- [gate_none_passed.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none_passed.json)
- [gate_none_state_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none_state_results.json)
- [gate_none_tendency_results.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none_tendency_results.json)
- [gate_passed.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_passed.json)
- [status.json](../../migration_work/khn26_multi32_bubble_ci_12h/status.json)
- [gate_native/exits.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native/exits.json)
- [gate_native/plot_status.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native/plot_status.json)
- [gate_native/comparison/scope.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_native/comparison/scope.json)
- [gate_none/exits.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none/exits.json)
- [gate_none/plot_status.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none/plot_status.json)
- [gate_none/comparison/scope.json](../../migration_work/khn26_multi32_bubble_ci_12h/gate_none/comparison/scope.json)

</details>

<a id="workspace-053"></a>

<details>
<summary>053 — migration_work/khn26_multi32_bubble_native_12h</summary>

- 原始狀態 [migration_work/khn26_multi32_bubble_native_12h/status.json](../../migration_work/khn26_multi32_bubble_native_12h/status.json)：`{"state":"failed","error":"10-minute state gate failed: [1.89661256e-07 1.02527878e-06 1.35876066e-10]"}`

**[migration_work/khn26_multi32_bubble_native_12h/configuration.json](../../migration_work/khn26_multi32_bubble_native_12h/configuration.json)**

原檔SHA-256：`9f713b6db4fef48e36b9d61fd15c7020360be5bd79f057e6b923b6eed25199ca`。完整附件key：`records["migration_work/khn26_multi32_bubble_native_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 43200 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi32_bubble_native_12h/configuration.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_native_precipitation_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_native_tendency_results.json)
- [gate_none_passed.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none_passed.json)
- [gate_none_state_results.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none_state_results.json)
- [gate_none_tendency_results.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none_tendency_results.json)
- [status.json](../../migration_work/khn26_multi32_bubble_native_12h/status.json)
- [supervisor.json](../../migration_work/khn26_multi32_bubble_native_12h/supervisor.json)
- [gate_native/exits.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_native/exits.json)
- [gate_none/exits.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none/exits.json)
- [gate_none/plot_status.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none/plot_status.json)
- [gate_none/comparison/scope.json](../../migration_work/khn26_multi32_bubble_native_12h/gate_none/comparison/scope.json)

</details>

<a id="workspace-054"></a>

<details>
<summary>054 — migration_work/khn26_multi_boundary_common_state</summary>

- 原始狀態 [migration_work/khn26_multi_boundary_common_state/status.json](../../migration_work/khn26_multi_boundary_common_state/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_boundary_common_state/configuration.json](../../migration_work/khn26_multi_boundary_common_state/configuration.json)**

原檔SHA-256：`34058fabdcd84c782bd890e899c00b114b0302763f0534e5a590904e5ef29b21`。完整附件key：`records["migration_work/khn26_multi_boundary_common_state/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_boundary_common_state/configuration.json)
- [results.json](../../migration_work/khn26_multi_boundary_common_state/results.json)
- [status.json](../../migration_work/khn26_multi_boundary_common_state/status.json)

</details>

<a id="workspace-055"></a>

<details>
<summary>055 — migration_work/khn26_multi_boundary_matlab_order</summary>

- 原始狀態 [migration_work/khn26_multi_boundary_matlab_order/status.json](../../migration_work/khn26_multi_boundary_matlab_order/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_boundary_matlab_order/configuration.json](../../migration_work/khn26_multi_boundary_matlab_order/configuration.json)**

原檔SHA-256：`5f95fd2bfeb7cd7dce78d597d375c1829bb24205328774b2b008267b1dc7ca62`。完整附件key：`records["migration_work/khn26_multi_boundary_matlab_order/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_boundary_matlab_order/configuration.json)
- [results.json](../../migration_work/khn26_multi_boundary_matlab_order/results.json)
- [status.json](../../migration_work/khn26_multi_boundary_matlab_order/status.json)
- [supervisor.json](../../migration_work/khn26_multi_boundary_matlab_order/supervisor.json)

</details>

<a id="workspace-056"></a>

<details>
<summary>056 — migration_work/khn26_multi_boundary_replay</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-057"></a>

<details>
<summary>057 — migration_work/khn26_multi_matlab96_fortran32_12h</summary>


**[migration_work/khn26_multi_matlab96_fortran32_12h/configuration.json](../../migration_work/khn26_multi_matlab96_fortran32_12h/configuration.json)**

原檔SHA-256：`1792fabe005a3237c452e78d16b30488a1fc7c353c7be27e3d68908b28ab802f`。完整附件key：`records["migration_work/khn26_multi_matlab96_fortran32_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 43200 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `policy` | "User requested completion speed, no efficiency observations. MATLAB uses both siblings on 48 physical cores; Fortran uses one CPU on each of 32 other physical cores. No physical-core overlap." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_matlab96_fortran32_12h/configuration.json)

</details>

<a id="workspace-058"></a>

<details>
<summary>058 — migration_work/khn26_multi_matlab_alignment_10min</summary>

- 原始狀態 [migration_work/khn26_multi_matlab_alignment_10min/status.json](../../migration_work/khn26_multi_matlab_alignment_10min/status.json)：`{"state":"gates_passed","full_started":false}`

**[migration_work/khn26_multi_matlab_alignment_10min/configuration.json](../../migration_work/khn26_multi_matlab_alignment_10min/configuration.json)**

原檔SHA-256：`f1540b963d4b240316b8b788d98307ab3fd5f60f0a7847d3a4ca5bd33e996aa7`。完整附件key：`records["migration_work/khn26_multi_matlab_alignment_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |
| `policy` | "Only two ten-minute gates; no MATLAB thread/affinity restriction; Fortran 32. No long run or performance study." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_matlab_alignment_10min/configuration.json)
- [gate_native_gate_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native_gate_results.json)
- [gate_native_passed.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native_passed.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native_tendency_results.json)
- [gate_none_gate_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none_gate_results.json)
- [gate_none_passed.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none_passed.json)
- [gate_none_state_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none_state_results.json)
- [gate_none_tendency_results.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none_tendency_results.json)
- [gate_passed.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_passed.json)
- [maximum_difference_locations.json](../../migration_work/khn26_multi_matlab_alignment_10min/maximum_difference_locations.json)
- [status.json](../../migration_work/khn26_multi_matlab_alignment_10min/status.json)
- [supervisor.json](../../migration_work/khn26_multi_matlab_alignment_10min/supervisor.json)
- [gate_native/exits.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native/exits.json)
- [gate_native/matlab_execution_policy.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native/matlab_execution_policy.json)
- [gate_native/plot_status.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native/plot_status.json)
- [gate_native/comparison/scope.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_native/comparison/scope.json)
- [gate_none/exits.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none/exits.json)
- [gate_none/matlab_execution_policy.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none/matlab_execution_policy.json)
- [gate_none/plot_status.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none/plot_status.json)
- [gate_none/comparison/scope.json](../../migration_work/khn26_multi_matlab_alignment_10min/gate_none/comparison/scope.json)

</details>

<a id="workspace-059"></a>

<details>
<summary>059 — migration_work/khn26_multi_matlab_default_fortran32_12h</summary>

- 原始狀態 [migration_work/khn26_multi_matlab_default_fortran32_12h/status.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/status.json)：`{"state":"stopped_at_revised_target_pending_comparison"}`

**[migration_work/khn26_multi_matlab_default_fortran32_12h/configuration.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/configuration.json)**

原檔SHA-256：`c1884ad24fc229457137ab6d2b124285ea5419d4593593cab70a4dad09ce3a09`。完整附件key：`records["migration_work/khn26_multi_matlab_default_fortran32_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 43200 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `policy` | "MATLAB has no imposed thread limit or CPU binding; Fortran has 32 threads. Both start together, CPU overlap allowed, no efficiency observations." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [accepted_gate.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/accepted_gate.json)
- [configuration.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/configuration.json)
- [matlab_execution_policy.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/matlab_execution_policy.json)
- [snapshot_plotter.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/snapshot_plotter.json)
- [status.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/status.json)
- [supervisor.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/supervisor.json)
- [ten_minute_prefix_results.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/ten_minute_prefix_results.json)
- [three_hour_controller.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour_controller.json)
- [three_hour_state_results.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour_state_results.json)
- [three_hour_stop_policy.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour_stop_policy.json)
- [full/comparison/mf_20min_snapshots.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/full/comparison/mf_20min_snapshots.json)
- [three_hour/ace101_results.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour/ace101_results.json)
- [three_hour/comparison/scope.json](../../migration_work/khn26_multi_matlab_default_fortran32_12h/three_hour/comparison/scope.json)

</details>

<a id="workspace-060"></a>

<details>
<summary>060 — migration_work/khn26_multi_precipitation_three_hour</summary>

- 原始狀態 [migration_work/khn26_multi_precipitation_three_hour/status.json](../../migration_work/khn26_multi_precipitation_three_hour/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_precipitation_three_hour/configuration.json](../../migration_work/khn26_multi_precipitation_three_hour/configuration.json)**

原檔SHA-256：`c0e31ac980ce5947ab2be39e4051f0c28b5de7d6e85538eeeb74fea94f3920bf`。完整附件key：`records["migration_work/khn26_multi_precipitation_three_hour/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `duration_seconds` | 10800 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/khn26_multi_precipitation_three_hour/build_commands.json)
- [configuration.json](../../migration_work/khn26_multi_precipitation_three_hour/configuration.json)
- [status.json](../../migration_work/khn26_multi_precipitation_three_hour/status.json)
- [supervisor.json](../../migration_work/khn26_multi_precipitation_three_hour/supervisor.json)
- [multiACE_fortran/launch.json](../../migration_work/khn26_multi_precipitation_three_hour/multiACE_fortran/launch.json)
- [multiACE_matlab/launch.json](../../migration_work/khn26_multi_precipitation_three_hour/multiACE_matlab/launch.json)
- [multiACE_p3/launch.json](../../migration_work/khn26_multi_precipitation_three_hour/multiACE_p3/launch.json)

</details>

<a id="workspace-061"></a>

<details>
<summary>061 — migration_work/khn26_multi_replay_precip</summary>

- 原始狀態 [migration_work/khn26_multi_replay_precip/status.json](../../migration_work/khn26_multi_replay_precip/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_replay_precip/configuration.json](../../migration_work/khn26_multi_replay_precip/configuration.json)**

原檔SHA-256：`bd9245f95716b7b887240dc10b7e3e39a346794cbb56da503b45766b7b00fdc0`。完整附件key：`records["migration_work/khn26_multi_replay_precip/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 12180 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [attribution.json](../../migration_work/khn26_multi_replay_precip/attribution.json)
- [configuration.json](../../migration_work/khn26_multi_replay_precip/configuration.json)
- [results.json](../../migration_work/khn26_multi_replay_precip/results.json)
- [sample_labels.json](../../migration_work/khn26_multi_replay_precip/sample_labels.json)
- [selection.json](../../migration_work/khn26_multi_replay_precip/selection.json)
- [status.json](../../migration_work/khn26_multi_replay_precip/status.json)

</details>

<a id="workspace-062"></a>

<details>
<summary>062 — migration_work/khn26_multi_replay_precip_matlab_order</summary>

- 原始狀態 [migration_work/khn26_multi_replay_precip_matlab_order/status.json](../../migration_work/khn26_multi_replay_precip_matlab_order/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_replay_precip_matlab_order/configuration.json](../../migration_work/khn26_multi_replay_precip_matlab_order/configuration.json)**

原檔SHA-256：`cfa0c08433042f1b1f19493bf64fa3727cdc6484517defac83a4575abfeffe9d`。完整附件key：`records["migration_work/khn26_multi_replay_precip_matlab_order/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 12180 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [attribution.json](../../migration_work/khn26_multi_replay_precip_matlab_order/attribution.json)
- [configuration.json](../../migration_work/khn26_multi_replay_precip_matlab_order/configuration.json)
- [recheck.json](../../migration_work/khn26_multi_replay_precip_matlab_order/recheck.json)
- [results.json](../../migration_work/khn26_multi_replay_precip_matlab_order/results.json)
- [sample_labels.json](../../migration_work/khn26_multi_replay_precip_matlab_order/sample_labels.json)
- [selection.json](../../migration_work/khn26_multi_replay_precip_matlab_order/selection.json)
- [status.json](../../migration_work/khn26_multi_replay_precip_matlab_order/status.json)
- [supervisor.json](../../migration_work/khn26_multi_replay_precip_matlab_order/supervisor.json)
- [checked_build/commands.json](../../migration_work/khn26_multi_replay_precip_matlab_order/checked_build/commands.json)

</details>

<a id="workspace-063"></a>

<details>
<summary>063 — migration_work/khn26_multi_replay_precip_recheck</summary>

- 原始狀態 [migration_work/khn26_multi_replay_precip_recheck/status.json](../../migration_work/khn26_multi_replay_precip_recheck/status.json)：`{"state":"completed"}`

**[migration_work/khn26_multi_replay_precip_recheck/configuration.json](../../migration_work/khn26_multi_replay_precip_recheck/configuration.json)**

原檔SHA-256：`90e5cc219fcc4196bffe08041f4cb589fc2278e5d12e938b18d6bd6beefac10b`。完整附件key：`records["migration_work/khn26_multi_replay_precip_recheck/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 12180 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_replay_precip_recheck/configuration.json)
- [recheck.json](../../migration_work/khn26_multi_replay_precip_recheck/recheck.json)
- [results.json](../../migration_work/khn26_multi_replay_precip_recheck/results.json)
- [sample_labels.json](../../migration_work/khn26_multi_replay_precip_recheck/sample_labels.json)
- [selection.json](../../migration_work/khn26_multi_replay_precip_recheck/selection.json)
- [status.json](../../migration_work/khn26_multi_replay_precip_recheck/status.json)
- [supervisor.json](../../migration_work/khn26_multi_replay_precip_recheck/supervisor.json)

</details>

<a id="workspace-064"></a>

<details>
<summary>064 — migration_work/khn26_multi_weno_alignment_10min</summary>

- 原始狀態 [migration_work/khn26_multi_weno_alignment_10min/status.json](../../migration_work/khn26_multi_weno_alignment_10min/status.json)：`{"state":"failed","error":"MATLAB gate startup failed"}`

**[migration_work/khn26_multi_weno_alignment_10min/configuration.json](../../migration_work/khn26_multi_weno_alignment_10min/configuration.json)**

原檔SHA-256：`70d048c034393ec456c678a1e6d7abf2e073c47dc9a16eb3e45b0270c1f2654e`。完整附件key：`records["migration_work/khn26_multi_weno_alignment_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |
| `policy` | "Only two ten-minute gates; no MATLAB thread/affinity restriction; Fortran 32. No long run or performance study." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_weno_alignment_10min/configuration.json)
- [status.json](../../migration_work/khn26_multi_weno_alignment_10min/status.json)
- [weno_component_results.json](../../migration_work/khn26_multi_weno_alignment_10min/weno_component_results.json)
- [gate_none/matlab_execution_policy.json](../../migration_work/khn26_multi_weno_alignment_10min/gate_none/matlab_execution_policy.json)

</details>

<a id="workspace-065"></a>

<details>
<summary>065 — migration_work/khn26_multi_weno_alignment_10min_licensed</summary>

- 原始狀態 [migration_work/khn26_multi_weno_alignment_10min_licensed/status.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/status.json)：`{"state":"gates_passed","full_started":false}`

**[migration_work/khn26_multi_weno_alignment_10min_licensed/configuration.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/configuration.json)**

原檔SHA-256：`5d6aedf56da8f35364d324e9a2c37e1027ce992d3be199a9462328958bf939fb`。完整附件key：`records["migration_work/khn26_multi_weno_alignment_10min_licensed/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |
| `policy` | "Only two ten-minute gates; no MATLAB thread/affinity restriction; Fortran 32. No long run or performance study." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/configuration.json)
- [gate_native_gate_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native_gate_results.json)
- [gate_native_passed.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native_passed.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native_tendency_results.json)
- [gate_none_gate_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none_gate_results.json)
- [gate_none_passed.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none_passed.json)
- [gate_none_state_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none_state_results.json)
- [gate_none_tendency_results.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none_tendency_results.json)
- [gate_passed.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_passed.json)
- [status.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/status.json)
- [gate_native/exits.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native/exits.json)
- [gate_native/matlab_execution_policy.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native/matlab_execution_policy.json)
- [gate_native/plot_status.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native/plot_status.json)
- [gate_native/comparison/scope.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_native/comparison/scope.json)
- [gate_none/exits.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none/exits.json)
- [gate_none/matlab_execution_policy.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none/matlab_execution_policy.json)
- [gate_none/plot_status.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none/plot_status.json)
- [gate_none/comparison/scope.json](../../migration_work/khn26_multi_weno_alignment_10min_licensed/gate_none/comparison/scope.json)

</details>

<a id="workspace-066"></a>

<details>
<summary>066 — migration_work/khn26_multi_weno_three_hour</summary>

- 原始狀態 [migration_work/khn26_multi_weno_three_hour/status.json](../../migration_work/khn26_multi_weno_three_hour/status.json)：`{"state":"completed_pending_scientific_review"}`

**[migration_work/khn26_multi_weno_three_hour/configuration.json](../../migration_work/khn26_multi_weno_three_hour/configuration.json)**

原檔SHA-256：`aa5909c880109f39ec35204b36bd600e7162ccc02fc8472299135a4a4d1722c0`。完整附件key：`records["migration_work/khn26_multi_weno_three_hour/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `policy` | "MATLAB has no imposed thread limit or CPU binding; Fortran has 32 threads. Both start together, CPU overlap allowed, no efficiency observations." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [accepted_gate.json](../../migration_work/khn26_multi_weno_three_hour/accepted_gate.json)
- [configuration.json](../../migration_work/khn26_multi_weno_three_hour/configuration.json)
- [full_state_results.json](../../migration_work/khn26_multi_weno_three_hour/full_state_results.json)
- [matlab_execution_policy.json](../../migration_work/khn26_multi_weno_three_hour/matlab_execution_policy.json)
- [status.json](../../migration_work/khn26_multi_weno_three_hour/status.json)
- [ten_minute_prefix_results.json](../../migration_work/khn26_multi_weno_three_hour/ten_minute_prefix_results.json)
- [full/exits.json](../../migration_work/khn26_multi_weno_three_hour/full/exits.json)
- [full/plot_status.json](../../migration_work/khn26_multi_weno_three_hour/full/plot_status.json)
- [full/comparison/scope.json](../../migration_work/khn26_multi_weno_three_hour/full/comparison/scope.json)

</details>

<a id="workspace-067"></a>

<details>
<summary>067 — migration_work/khn26_multi_weno_three_hour_gates</summary>

- 原始狀態 [migration_work/khn26_multi_weno_three_hour_gates/status.json](../../migration_work/khn26_multi_weno_three_hour_gates/status.json)：`{"state":"gates_passed","full_started":false}`

**[migration_work/khn26_multi_weno_three_hour_gates/configuration.json](../../migration_work/khn26_multi_weno_three_hour_gates/configuration.json)**

原檔SHA-256：`0f1bd8965dd0c918670d424cf2c23ba8c2141ae53dac81f4a8aedd0101debff5`。完整附件key：`records["migration_work/khn26_multi_weno_three_hour_gates/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.0 |
| `case.physics` | "native" |
| `case.gate_physics` | ["none","native"] |
| `case.multiACE` | true |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 600 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |
| `policy` | "Only two ten-minute gates; no MATLAB thread/affinity restriction; Fortran 32. No long run or performance study." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_weno_three_hour_gates/configuration.json)
- [gate_native_gate_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native_gate_results.json)
- [gate_native_passed.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native_passed.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native_tendency_results.json)
- [gate_none_gate_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none_gate_results.json)
- [gate_none_passed.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none_passed.json)
- [gate_none_state_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none_state_results.json)
- [gate_none_tendency_results.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none_tendency_results.json)
- [gate_passed.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_passed.json)
- [status.json](../../migration_work/khn26_multi_weno_three_hour_gates/status.json)
- [gate_native/exits.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native/exits.json)
- [gate_native/matlab_execution_policy.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native/matlab_execution_policy.json)
- [gate_native/plot_status.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native/plot_status.json)
- [gate_native/comparison/scope.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_native/comparison/scope.json)
- [gate_none/exits.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none/exits.json)
- [gate_none/matlab_execution_policy.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none/matlab_execution_policy.json)
- [gate_none/plot_status.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none/plot_status.json)
- [gate_none/comparison/scope.json](../../migration_work/khn26_multi_weno_three_hour_gates/gate_none/comparison/scope.json)

</details>

<a id="workspace-068"></a>

<details>
<summary>068 — migration_work/khn26_multi_weno_three_hour_sequence</summary>

- 原始狀態 [migration_work/khn26_multi_weno_three_hour_sequence/status.json](../../migration_work/khn26_multi_weno_three_hour_sequence/status.json)：`{"state":"completed_pending_scientific_review"}`

**[migration_work/khn26_multi_weno_three_hour_sequence/configuration.json](../../migration_work/khn26_multi_weno_three_hour_sequence/configuration.json)**

原檔SHA-256：`febb3281246466a254d337741b93f3a7e69f008332f40a8f1e4bb77e7ef3d192`。完整附件key：`records["migration_work/khn26_multi_weno_three_hour_sequence/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 10800 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_multi_weno_three_hour_sequence/configuration.json)
- [status.json](../../migration_work/khn26_multi_weno_three_hour_sequence/status.json)
- [supervisor.json](../../migration_work/khn26_multi_weno_three_hour_sequence/supervisor.json)

</details>

<a id="workspace-069"></a>

<details>
<summary>069 — migration_work/khn26_p3_smoke</summary>

- 原始狀態 [migration_work/khn26_p3_smoke/status.json](../../migration_work/khn26_p3_smoke/status.json)：`{"state":"completed","full_started":true}`

**[migration_work/khn26_p3_smoke/configuration.json](../../migration_work/khn26_p3_smoke/configuration.json)**

原檔SHA-256：`787c91aa5b00d2a5bb69950b24f491f16691c08d628f683ef1f78b0379285699`。完整附件key：`records["migration_work/khn26_p3_smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `ncols` | 101 |
| `nz` | 401 |
| `physics` | "p3" |
| `dt_seconds` | 4 |
| `bubble_delta_K` | 1 |
| `initial_MF` | 0 |
| `duration_seconds` | 600 |
| `threads` | 32 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [additional_checks.json](../../migration_work/khn26_p3_smoke/additional_checks.json)
- [commands.json](../../migration_work/khn26_p3_smoke/commands.json)
- [configuration.json](../../migration_work/khn26_p3_smoke/configuration.json)
- [status.json](../../migration_work/khn26_p3_smoke/status.json)
- [debug_prefix/results.json](../../migration_work/khn26_p3_smoke/debug_prefix/results.json)
- [production_prefix/results.json](../../migration_work/khn26_p3_smoke/production_prefix/results.json)
- [ten_minute/results.json](../../migration_work/khn26_p3_smoke/ten_minute/results.json)

</details>

<a id="workspace-070"></a>

<details>
<summary>070 — migration_work/khn26_p3_three_hour</summary>

- 原始狀態 [migration_work/khn26_p3_three_hour/status.json](../../migration_work/khn26_p3_three_hour/status.json)：`{"state":"completed_pending_scientific_review","full_started":true}`

**[migration_work/khn26_p3_three_hour/configuration.json](../../migration_work/khn26_p3_three_hour/configuration.json)**

原檔SHA-256：`82d775432181cf9db0aff73fd49c801e76363dd1d67edd9921ebb53930f46e36`。完整附件key：`records["migration_work/khn26_p3_three_hour/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.initial_MF` | 0 |
| `case.ncols` | 101 |
| `case.nz` | 401 |
| `case.threads` | 32 |
| `duration_seconds` | 10800 |
| `output_interval_seconds` | 60 |
| `expected_saved_states` | 181 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/khn26_p3_three_hour/build_commands.json)
- [configuration.json](../../migration_work/khn26_p3_three_hour/configuration.json)
- [status.json](../../migration_work/khn26_p3_three_hour/status.json)
- [supervisor.json](../../migration_work/khn26_p3_three_hour/supervisor.json)
- [multiACE/full/launch.json](../../migration_work/khn26_p3_three_hour/multiACE/full/launch.json)
- [multiACE/full/results.json](../../migration_work/khn26_p3_three_hour/multiACE/full/results.json)
- [singleACE/gate_results.json](../../migration_work/khn26_p3_three_hour/singleACE/gate_results.json)
- [singleACE/checked_prefix/launch.json](../../migration_work/khn26_p3_three_hour/singleACE/checked_prefix/launch.json)
- [singleACE/checked_prefix/results.json](../../migration_work/khn26_p3_three_hour/singleACE/checked_prefix/results.json)
- [singleACE/full/launch.json](../../migration_work/khn26_p3_three_hour/singleACE/full/launch.json)
- [singleACE/full/results.json](../../migration_work/khn26_p3_three_hour/singleACE/full/results.json)
- [singleACE/production_prefix/launch.json](../../migration_work/khn26_p3_three_hour/singleACE/production_prefix/launch.json)
- [singleACE/production_prefix/results.json](../../migration_work/khn26_p3_three_hour/singleACE/production_prefix/results.json)

</details>

<a id="workspace-071"></a>

<details>
<summary>071 — migration_work/khn26_packed_model</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_packed_model/validation_results.json](../../migration_work/khn26_packed_model/validation_results.json)**

原檔SHA-256：`d84aafe6d6226f50a253a591b16f804e12a05b473fbb4cfdc06e0a3c0b9c1f25`。完整附件key：`records["migration_work/khn26_packed_model/validation_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `threads` | 8 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [validation_results.json](../../migration_work/khn26_packed_model/validation_results.json)

</details>

<a id="workspace-072"></a>

<details>
<summary>072 — migration_work/khn26_precipitation_three_hour</summary>

- 原始狀態 [migration_work/khn26_precipitation_three_hour/status.json](../../migration_work/khn26_precipitation_three_hour/status.json)：`{"state":"stopped_by_user"}`
- 原始狀態 [migration_work/khn26_precipitation_three_hour/stop_record.json](../../migration_work/khn26_precipitation_three_hour/stop_record.json)：`{"state":"stopped_by_user"}`

**[migration_work/khn26_precipitation_three_hour/configuration.json](../../migration_work/khn26_precipitation_three_hour/configuration.json)**

原檔SHA-256：`ffd744b7adb90f96a939396ad1bcd90df63ea58b9835a6987c04ddf42ece7531`。完整附件key：`records["migration_work/khn26_precipitation_three_hour/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `duration_seconds` | 10800 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/khn26_precipitation_three_hour/build_commands.json)
- [configuration.json](../../migration_work/khn26_precipitation_three_hour/configuration.json)
- [status.json](../../migration_work/khn26_precipitation_three_hour/status.json)
- [stop_record.json](../../migration_work/khn26_precipitation_three_hour/stop_record.json)
- [supervisor.json](../../migration_work/khn26_precipitation_three_hour/supervisor.json)
- [multiACE_fortran/launch.json](../../migration_work/khn26_precipitation_three_hour/multiACE_fortran/launch.json)
- [multiACE_matlab/launch.json](../../migration_work/khn26_precipitation_three_hour/multiACE_matlab/launch.json)
- [multiACE_p3/launch.json](../../migration_work/khn26_precipitation_three_hour/multiACE_p3/launch.json)
- [singleACE_fortran/launch.json](../../migration_work/khn26_precipitation_three_hour/singleACE_fortran/launch.json)
- [singleACE_matlab/launch.json](../../migration_work/khn26_precipitation_three_hour/singleACE_matlab/launch.json)
- [singleACE_p3/launch.json](../../migration_work/khn26_precipitation_three_hour/singleACE_p3/launch.json)

</details>

<a id="workspace-073"></a>

<details>
<summary>073 — migration_work/khn26_review</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [candidate_manifest.json](../../migration_work/khn26_review/candidate_manifest.json)

</details>

<a id="workspace-074"></a>

<details>
<summary>074 — migration_work/khn26_serial_profile</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-075"></a>

<details>
<summary>075 — migration_work/khn26_serial_profile_1min</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_serial_profile_1min/profile_results.json](../../migration_work/khn26_serial_profile_1min/profile_results.json)**

原檔SHA-256：`d2324ff7e78c7b6d48b08695bfe45239dbde2f4d2f265ca7d9c746dd57e66279`。完整附件key：`records["migration_work/khn26_serial_profile_1min/profile_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [profile_results.json](../../migration_work/khn26_serial_profile_1min/profile_results.json)

</details>

<a id="workspace-076"></a>

<details>
<summary>076 — migration_work/khn26_serial_profile_interleaved</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_serial_profile_interleaved/profile_results.json](../../migration_work/khn26_serial_profile_interleaved/profile_results.json)**

原檔SHA-256：`629e3b2fba84b6cec16fbcabddad334e3ac313030917b80a2c590c77795591b9`。完整附件key：`records["migration_work/khn26_serial_profile_interleaved/profile_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `duration_seconds` | 60 |
| `steps` | 15 |
| `flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [profile_results.json](../../migration_work/khn26_serial_profile_interleaved/profile_results.json)

</details>

<a id="workspace-077"></a>

<details>
<summary>077 — migration_work/khn26_serial_profile_sections</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_serial_profile_sections/profile_results.json](../../migration_work/khn26_serial_profile_sections/profile_results.json)**

原檔SHA-256：`75f694028af0aa0a421c104b25c5f708e79d28778163e4d986d724d463ec36e4`。完整附件key：`records["migration_work/khn26_serial_profile_sections/profile_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [profile_results.json](../../migration_work/khn26_serial_profile_sections/profile_results.json)

</details>

<a id="workspace-078"></a>

<details>
<summary>078 — migration_work/khn26_serial_simd</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_serial_simd/serial_simd_results.json](../../migration_work/khn26_serial_simd/serial_simd_results.json)**

原檔SHA-256：`c7028ddb332ef8c897a604c5bb6af2ecf2b33bd41cd10b7e5b5319ff6317c78b`。完整附件key：`records["migration_work/khn26_serial_simd/serial_simd_results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [serial_simd_results.json](../../migration_work/khn26_serial_simd/serial_simd_results.json)

</details>

<a id="workspace-079"></a>

<details>
<summary>079 — migration_work/khn26_serial_simd_controls</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/khn26_serial_simd_controls/serial_simd_results.json](../../migration_work/khn26_serial_simd_controls/serial_simd_results.json)**

原檔SHA-256：`eea79e73de2cbacb36bcda36e4c529f0f29cf2505d6e22d52517582beac6e545`。完整附件key：`records["migration_work/khn26_serial_simd_controls/serial_simd_results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [serial_simd_results.json](../../migration_work/khn26_serial_simd_controls/serial_simd_results.json)

</details>

<a id="workspace-080"></a>

<details>
<summary>080 — migration_work/khn26_single32_native_3h</summary>

- 原始狀態 [migration_work/khn26_single32_native_3h/status.json](../../migration_work/khn26_single32_native_3h/status.json)：`{"state":"gate_failed_pending_review"}`

**[migration_work/khn26_single32_native_3h/configuration.json](../../migration_work/khn26_single32_native_3h/configuration.json)**

原檔SHA-256：`d3c328f95eb034b211c8def9628882bffe766e9b4d5f47e3eb89e22e5a329b03`。完整附件key：`records["migration_work/khn26_single32_native_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.03 |
| `case.physics` | "native" |
| `case.gate_physics` | ["native"] |
| `case.multiACE` | false |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_single32_native_3h/configuration.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_single32_native_3h/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_single32_native_3h/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_single32_native_3h/gate_native_tendency_results.json)
- [gate_results.json](../../migration_work/khn26_single32_native_3h/gate_results.json)
- [status.json](../../migration_work/khn26_single32_native_3h/status.json)
- [supervisor.json](../../migration_work/khn26_single32_native_3h/supervisor.json)
- [gate_native/exits.json](../../migration_work/khn26_single32_native_3h/gate_native/exits.json)

</details>

<a id="workspace-081"></a>

<details>
<summary>081 — migration_work/khn26_single32_native_ci_3h</summary>

- 原始狀態 [migration_work/khn26_single32_native_ci_3h/status.json](../../migration_work/khn26_single32_native_ci_3h/status.json)：`{"state":"gates_passed"}`

**[migration_work/khn26_single32_native_ci_3h/configuration.json](../../migration_work/khn26_single32_native_ci_3h/configuration.json)**

原檔SHA-256：`d527e3894ec3807f2aa1541471a8f47d95fadd2af98bcac0098cb5820972b4c4`。完整附件key：`records["migration_work/khn26_single32_native_ci_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.03 |
| `case.physics` | "native" |
| `case.gate_physics` | ["native"] |
| `case.multiACE` | false |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.threads_per_language` | 32 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_single32_native_ci_3h/configuration.json)
- [gate_native_precipitation_results.json](../../migration_work/khn26_single32_native_ci_3h/gate_native_precipitation_results.json)
- [gate_native_state_results.json](../../migration_work/khn26_single32_native_ci_3h/gate_native_state_results.json)
- [gate_native_tendency_results.json](../../migration_work/khn26_single32_native_ci_3h/gate_native_tendency_results.json)
- [gate_results.json](../../migration_work/khn26_single32_native_ci_3h/gate_results.json)
- [status.json](../../migration_work/khn26_single32_native_ci_3h/status.json)
- [gate_native/exits.json](../../migration_work/khn26_single32_native_ci_3h/gate_native/exits.json)

</details>

<a id="workspace-082"></a>

<details>
<summary>082 — migration_work/khn26_single_3h</summary>


**[migration_work/khn26_single_3h/configuration.json](../../migration_work/khn26_single_3h/configuration.json)**

原檔SHA-256：`f47c4047e389062eaa2dbecc062426d3785a65402ff993b3983718310edb185a`。完整附件key：`records["migration_work/khn26_single_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_single_3h/configuration.json)
- [partial_001080s_checks.json](../../migration_work/khn26_single_3h/partial_001080s_checks.json)
- [plot_status.json](../../migration_work/khn26_single_3h/plot_status.json)
- [single_case.json](../../migration_work/khn26_single_3h/single_case.json)
- [single_status.json](../../migration_work/khn26_single_3h/single_status.json)
- [smoke_results.json](../../migration_work/khn26_single_3h/smoke_results.json)
- [preview_000900s/mf_summary.json](../../migration_work/khn26_single_3h/preview_000900s/mf_summary.json)
- [preview_000900s/results.json](../../migration_work/khn26_single_3h/preview_000900s/results.json)
- [preview_000960s/results.json](../../migration_work/khn26_single_3h/preview_000960s/results.json)
- [preview_001020s/results.json](../../migration_work/khn26_single_3h/preview_001020s/results.json)
- [preview_001080s/results.json](../../migration_work/khn26_single_3h/preview_001080s/results.json)
- [preview_001140s/results.json](../../migration_work/khn26_single_3h/preview_001140s/results.json)
- [preview_001200s/results.json](../../migration_work/khn26_single_3h/preview_001200s/results.json)
- [preview_001260s/results.json](../../migration_work/khn26_single_3h/preview_001260s/results.json)
- [preview_001320s/results.json](../../migration_work/khn26_single_3h/preview_001320s/results.json)
- [preview_001380s/results.json](../../migration_work/khn26_single_3h/preview_001380s/results.json)
- [smoke_comparison/results.json](../../migration_work/khn26_single_3h/smoke_comparison/results.json)

</details>

<a id="workspace-083"></a>

<details>
<summary>083 — migration_work/khn26_single_matlab96_fortran32_3h</summary>

- 原始狀態 [migration_work/khn26_single_matlab96_fortran32_3h/status.json](../../migration_work/khn26_single_matlab96_fortran32_3h/status.json)：`{"state":"stopped_by_user","reason":"User requested stopping MATLAB; later long-run scheduling halted to prevent restarting MATLAB."}`

**[migration_work/khn26_single_matlab96_fortran32_3h/configuration.json](../../migration_work/khn26_single_matlab96_fortran32_3h/configuration.json)**

原檔SHA-256：`3472e9a14bbe876b08f3dce28e40137f5da826aa7090a2b705ee289947583d79`。完整附件key：`records["migration_work/khn26_single_matlab96_fortran32_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.03 |
| `case.physics` | "native" |
| `case.gate_physics` | ["native"] |
| `case.multiACE` | false |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `policy` | "User requested completion speed, no efficiency observations. MATLAB uses both siblings on 48 physical cores; Fortran uses one CPU on each of 32 other physical cores. No physical-core overlap." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [accepted_gate.json](../../migration_work/khn26_single_matlab96_fortran32_3h/accepted_gate.json)
- [configuration.json](../../migration_work/khn26_single_matlab96_fortran32_3h/configuration.json)
- [status.json](../../migration_work/khn26_single_matlab96_fortran32_3h/status.json)
- [ten_minute_prefix_results.json](../../migration_work/khn26_single_matlab96_fortran32_3h/ten_minute_prefix_results.json)

</details>

<a id="workspace-084"></a>

<details>
<summary>084 — migration_work/khn26_single_matlab_default_fortran32_3h</summary>

- 原始狀態 [migration_work/khn26_single_matlab_default_fortran32_3h/status.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/status.json)：`{"state":"completed_pending_scientific_review"}`

**[migration_work/khn26_single_matlab_default_fortran32_3h/configuration.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/configuration.json)**

原檔SHA-256：`9fe5575b34fd0359b9b04989f96b361e0b78aebb123436c9d916a7bb5cda1e50`。完整附件key：`records["migration_work/khn26_single_matlab_default_fortran32_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.geometry` | "slab" |
| `case.profile_index` | 1342 |
| `case.full_basis_columns` | 101 |
| `case.dt_seconds` | 4 |
| `case.bubble_delta_K` | 1 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.initial_mf_amplitude` | 0.03 |
| `case.physics` | "native" |
| `case.gate_physics` | ["native"] |
| `case.multiACE` | false |
| `case.mean_mf_zero` | true |
| `case.gate_duration_seconds` | 600 |
| `case.gate_steps` | 150 |
| `case.duration_seconds` | 10800 |
| `case.output_interval_seconds` | 60 |
| `case.basis_policy` | "Full KHN26 PMB; marked PMDv/PMD remain disabled; no MF diffusion." |
| `policy` | "User requested MATLAB with no imposed thread or CPU-affinity restrictions; Fortran remains 32 threads. Both start together. No efficiency observations. CPU overlap is permitted." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/configuration.json)
- [full_state_results.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/full_state_results.json)
- [matlab_execution_policy.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/matlab_execution_policy.json)
- [status.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/status.json)
- [supervisor.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/supervisor.json)
- [ten_minute_prefix_results.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/ten_minute_prefix_results.json)
- [full/exits.json](../../migration_work/khn26_single_matlab_default_fortran32_3h/full/exits.json)

</details>

<a id="workspace-085"></a>

<details>
<summary>085 — migration_work/khn26_single_openmp6_3h</summary>


**[migration_work/khn26_single_openmp6_3h/timing_configuration.json](../../migration_work/khn26_single_openmp6_3h/timing_configuration.json)**

原檔SHA-256：`d827b5c88b4192e3934a2e5e9e91e776e7a7ead6c7b8d487e9edccdb068202d7`。完整附件key：`records["migration_work/khn26_single_openmp6_3h/timing_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `threads` | 6 |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [debug_gate_results.json](../../migration_work/khn26_single_openmp6_3h/debug_gate_results.json)
- [efficiency_results.json](../../migration_work/khn26_single_openmp6_3h/efficiency_results.json)
- [full_results.json](../../migration_work/khn26_single_openmp6_3h/full_results.json)
- [single_case.json](../../migration_work/khn26_single_openmp6_3h/single_case.json)
- [timing_configuration.json](../../migration_work/khn26_single_openmp6_3h/timing_configuration.json)
- [timing_status.json](../../migration_work/khn26_single_openmp6_3h/timing_status.json)
- [full_comparison/diagnostic_summary.json](../../migration_work/khn26_single_openmp6_3h/full_comparison/diagnostic_summary.json)
- [full_comparison/results.json](../../migration_work/khn26_single_openmp6_3h/full_comparison/results.json)

</details>

<a id="workspace-086"></a>

<details>
<summary>086 — migration_work/khn26_single_production_3h</summary>


**[migration_work/khn26_single_production_3h/timing_configuration.json](../../migration_work/khn26_single_production_3h/timing_configuration.json)**

原檔SHA-256：`b0a83dd09331430a5271e7a7d5a461064211d6fc9a88e221200dd14e22a2df32`。完整附件key：`records["migration_work/khn26_single_production_3h/timing_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `production_flags` | ["-cpp","-ffree-form","-ffree-line-length-none","-O2","-fdefault-real-8","-fdefault-double-8"] |
| `debug_flags` | ["-g","-fcheck=all,no-array-temps","-ffpe-trap=invalid,zero,overflow","-fbacktrace"] |

本目錄所有JSON紀錄（含巢狀子測試）：

- [debug_gate_results.json](../../migration_work/khn26_single_production_3h/debug_gate_results.json)
- [single_case.json](../../migration_work/khn26_single_production_3h/single_case.json)
- [timing_configuration.json](../../migration_work/khn26_single_production_3h/timing_configuration.json)
- [timing_status.json](../../migration_work/khn26_single_production_3h/timing_status.json)

</details>

<a id="workspace-087"></a>

<details>
<summary>087 — migration_work/khn26_single_serial_15min</summary>


**[migration_work/khn26_single_serial_15min/benchmark_configuration.json](../../migration_work/khn26_single_serial_15min/benchmark_configuration.json)**

原檔SHA-256：`6fca878bb971a29c3d3dfc4647b4563ce2e34817e4be3e24c248874e68236652`。完整附件key：`records["migration_work/khn26_single_serial_15min/benchmark_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 900 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `steps` | 225 |

**[migration_work/khn26_single_serial_15min/recovery_configuration.json](../../migration_work/khn26_single_serial_15min/recovery_configuration.json)**

原檔SHA-256：`3801293cdb0ae0419309b7c6800de0359f14568c9e8f7a9fdb0273f55e5d82a4`。完整附件key：`records["migration_work/khn26_single_serial_15min/recovery_configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [benchmark_configuration.json](../../migration_work/khn26_single_serial_15min/benchmark_configuration.json)
- [benchmark_results.json](../../migration_work/khn26_single_serial_15min/benchmark_results.json)
- [benchmark_status.json](../../migration_work/khn26_single_serial_15min/benchmark_status.json)
- [full_results.json](../../migration_work/khn26_single_serial_15min/full_results.json)
- [gate_results.json](../../migration_work/khn26_single_serial_15min/gate_results.json)
- [recovery_configuration.json](../../migration_work/khn26_single_serial_15min/recovery_configuration.json)
- [single_case.json](../../migration_work/khn26_single_serial_15min/single_case.json)

</details>

<a id="workspace-088"></a>

<details>
<summary>088 — migration_work/khn26_single_serial_3h</summary>


**[migration_work/khn26_single_serial_3h/timing_configuration.json](../../migration_work/khn26_single_serial_3h/timing_configuration.json)**

原檔SHA-256：`6b3be3a8c663f5fcbf83a2bd7b4f3817dae8a7c849bc7d3e36e184e8f5d7309b`。完整附件key：`records["migration_work/khn26_single_serial_3h/timing_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |

本目錄所有JSON紀錄（含巢狀子測試）：

- [single_case.json](../../migration_work/khn26_single_serial_3h/single_case.json)
- [timing_configuration.json](../../migration_work/khn26_single_serial_3h/timing_configuration.json)
- [timing_status.json](../../migration_work/khn26_single_serial_3h/timing_status.json)

</details>

<a id="workspace-089"></a>

<details>
<summary>089 — migration_work/khn26_single_stage_budget</summary>


**[migration_work/khn26_single_stage_budget/configuration.json](../../migration_work/khn26_single_stage_budget/configuration.json)**

原檔SHA-256：`2932dfa877352e20eb308f68e8476e458963e4a93ef8fc587ee1b4bc256f43fe`。完整附件key：`records["migration_work/khn26_single_stage_budget/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case.duration_seconds` | 10800 |
| `case.dt_seconds` | 4.0 |
| `case.bubble_delta_K` | 1.0 |
| `case.physics` | "none" |
| `case.mean_mf_zero` | true |
| `case.initial_mf_amplitude` | 0.03 |
| `case.input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |
| `case.active_ace_one_based` | 1 |
| `case.full_basis_columns` | 101 |
| `case.profile_index` | 1342 |
| `case.bubble_levels_one_based` | [11,51] |
| `case.output_interval_seconds` | 60 |
| `case.policy` | "Mask dynamics tendencies in ACEs 2..101; physics and damping retain driver behavior." |
| `case.basis_policy` | "Complete geometry and PMB retained; PMDv/PMD disabled." |
| `threads` | 6 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_single_stage_budget/configuration.json)

</details>

<a id="workspace-090"></a>

<details>
<summary>090 — migration_work/khn26_single_stage_budget_3h</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-091"></a>

<details>
<summary>091 — migration_work/khn26_six_hour</summary>


**[migration_work/khn26_six_hour/configuration.json](../../migration_work/khn26_six_hour/configuration.json)**

原檔SHA-256：`c71755e2fc799a37d33b7e6ccfa149c0bb385a53141cc551425f41f76fbd5ed4`。完整附件key：`records["migration_work/khn26_six_hour/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

**[migration_work/khn26_six_hour/trajectory_configuration.json](../../migration_work/khn26_six_hour/trajectory_configuration.json)**

原檔SHA-256：`3dc1f5e3e06150d9bd04b223fd88d0b8da11f8a3d659a271b4aab6a6adc81da6`。完整附件key：`records["migration_work/khn26_six_hour/trajectory_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/manaus1342_khn26.nc" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_six_hour/configuration.json)
- [diagnostic_manifest.json](../../migration_work/khn26_six_hour/diagnostic_manifest.json)
- [trajectory_configuration.json](../../migration_work/khn26_six_hour/trajectory_configuration.json)
- [trajectory_status.json](../../migration_work/khn26_six_hour/trajectory_status.json)
- [diagnostic_short/diagnostic_manifest.json](../../migration_work/khn26_six_hour/diagnostic_short/diagnostic_manifest.json)
- [diagnostic_short/identity.json](../../migration_work/khn26_six_hour/diagnostic_short/identity.json)
- [diagnostic_short/output_layout_check.json](../../migration_work/khn26_six_hour/diagnostic_short/output_layout_check.json)

</details>

<a id="workspace-092"></a>

<details>
<summary>092 — migration_work/khn26_ten_minute_error_sources</summary>

- 原始狀態 [migration_work/khn26_ten_minute_error_sources/status.json](../../migration_work/khn26_ten_minute_error_sources/status.json)：`{"state":"completed"}`

**[migration_work/khn26_ten_minute_error_sources/configuration.json](../../migration_work/khn26_ten_minute_error_sources/configuration.json)**

原檔SHA-256：`ad5279e8b8c6166cdaaa923703e19b253dfbff527389a0b8a5a653e194bae1c6`。完整附件key：`records["migration_work/khn26_ten_minute_error_sources/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_ten_minute_error_sources/configuration.json)
- [error_source_analysis.json](../../migration_work/khn26_ten_minute_error_sources/error_source_analysis.json)
- [reference_probe_commands.json](../../migration_work/khn26_ten_minute_error_sources/reference_probe_commands.json)
- [results.json](../../migration_work/khn26_ten_minute_error_sources/results.json)
- [status.json](../../migration_work/khn26_ten_minute_error_sources/status.json)
- [supervisor.json](../../migration_work/khn26_ten_minute_error_sources/supervisor.json)

</details>

<a id="workspace-093"></a>

<details>
<summary>093 — migration_work/khn26_ten_minute_error_thermo</summary>

- 原始狀態 [migration_work/khn26_ten_minute_error_thermo/status.json](../../migration_work/khn26_ten_minute_error_thermo/status.json)：`{"state":"completed"}`

**[migration_work/khn26_ten_minute_error_thermo/configuration.json](../../migration_work/khn26_ten_minute_error_thermo/configuration.json)**

原檔SHA-256：`e60f222fd061fa7dd2963bd05d33e6e24e33d7954882fe745a07dc0c11b9f868`。完整附件key：`records["migration_work/khn26_ten_minute_error_thermo/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `samples` | 14616 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/khn26_ten_minute_error_thermo/configuration.json)
- [results.json](../../migration_work/khn26_ten_minute_error_thermo/results.json)
- [sample_labels.json](../../migration_work/khn26_ten_minute_error_thermo/sample_labels.json)
- [selection.json](../../migration_work/khn26_ten_minute_error_thermo/selection.json)
- [status.json](../../migration_work/khn26_ten_minute_error_thermo/status.json)
- [supervisor.json](../../migration_work/khn26_ten_minute_error_thermo/supervisor.json)

</details>

<a id="workspace-094"></a>

<details>
<summary>094 — migration_work/makima_validation_20261004</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/makima_validation_20261004/metadata.json](../../migration_work/makima_validation_20261004/metadata.json)**

原檔SHA-256：`772f40bf3422804877a3c750b5f219a4cfc7736a35e882fdac814f38e8f4f073`。完整附件key：`records["migration_work/makima_validation_20261004/metadata.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

**[migration_work/makima_validation_20261004/results.json](../../migration_work/makima_validation_20261004/results.json)**

原檔SHA-256：`b33c645cc630b724c6e50ad5ae590d34ebbd19fb6d8c6bdf92ac632e8d9f9f31`。完整附件key：`records["migration_work/makima_validation_20261004/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [metadata.json](../../migration_work/makima_validation_20261004/metadata.json)
- [results.json](../../migration_work/makima_validation_20261004/results.json)

</details>

<a id="workspace-095"></a>

<details>
<summary>095 — migration_work/makima_validation_20261004_repeat</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/makima_validation_20261004_repeat/metadata.json](../../migration_work/makima_validation_20261004_repeat/metadata.json)**

原檔SHA-256：`772f40bf3422804877a3c750b5f219a4cfc7736a35e882fdac814f38e8f4f073`。完整附件key：`records["migration_work/makima_validation_20261004_repeat/metadata.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

**[migration_work/makima_validation_20261004_repeat/results.json](../../migration_work/makima_validation_20261004_repeat/results.json)**

原檔SHA-256：`9202a20d4f8b7a134667dc45cb44f70d42684dd5f66a5c26b228ddc9097053a1`。完整附件key：`records["migration_work/makima_validation_20261004_repeat/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [metadata.json](../../migration_work/makima_validation_20261004_repeat/metadata.json)
- [results.json](../../migration_work/makima_validation_20261004_repeat/results.json)

</details>

<a id="workspace-096"></a>

<details>
<summary>096 — migration_work/manus208_multi_outer_pulse_12h</summary>


**[migration_work/manus208_multi_outer_pulse_12h/configuration.json](../../migration_work/manus208_multi_outer_pulse_12h/configuration.json)**

原檔SHA-256：`8f274f2aaf85c7f8be4f8cae764d27fcbfe34684add3de99bcc86cdc28447a5a`。完整附件key：`records["migration_work/manus208_multi_outer_pulse_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |
| `ace_mode` | "multi" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/manus208_multi_outer_pulse_12h/commands.json)
- [configuration.json](../../migration_work/manus208_multi_outer_pulse_12h/configuration.json)
- [experiment.json](../../migration_work/manus208_multi_outer_pulse_12h/experiment.json)
- [initial_state_validation.json](../../migration_work/manus208_multi_outer_pulse_12h/initial_state_validation.json)
- [matlab_response.json](../../migration_work/manus208_multi_outer_pulse_12h/matlab_response.json)
- [multi_diagnostics.json](../../migration_work/manus208_multi_outer_pulse_12h/multi_diagnostics.json)
- [results.json](../../migration_work/manus208_multi_outer_pulse_12h/results.json)

</details>

<a id="workspace-097"></a>

<details>
<summary>097 — migration_work/manus208_multi_outer_pulse_12h_sandbox</summary>


**[migration_work/manus208_multi_outer_pulse_12h_sandbox/configuration.json](../../migration_work/manus208_multi_outer_pulse_12h_sandbox/configuration.json)**

原檔SHA-256：`8f274f2aaf85c7f8be4f8cae764d27fcbfe34684add3de99bcc86cdc28447a5a`。完整附件key：`records["migration_work/manus208_multi_outer_pulse_12h_sandbox/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |
| `ace_mode` | "multi" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/manus208_multi_outer_pulse_12h_sandbox/configuration.json)

</details>

<a id="workspace-098"></a>

<details>
<summary>098 — migration_work/manus208_single_saturated_bubble_3h</summary>


**[migration_work/manus208_single_saturated_bubble_3h/configuration.json](../../migration_work/manus208_single_saturated_bubble_3h/configuration.json)**

原檔SHA-256：`78db67dd1b07fd4779a8adc344fd206827df8d1050e1344a5b6cdfce970232e2`。完整附件key：`records["migration_work/manus208_single_saturated_bubble_3h/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [bubble_validation.json](../../migration_work/manus208_single_saturated_bubble_3h/bubble_validation.json)
- [commands.json](../../migration_work/manus208_single_saturated_bubble_3h/commands.json)
- [configuration.json](../../migration_work/manus208_single_saturated_bubble_3h/configuration.json)
- [reference_case.json](../../migration_work/manus208_single_saturated_bubble_3h/reference_case.json)
- [reference_comparison.json](../../migration_work/manus208_single_saturated_bubble_3h/reference_comparison.json)
- [results.json](../../migration_work/manus208_single_saturated_bubble_3h/results.json)

</details>

<a id="workspace-099"></a>

<details>
<summary>099 — migration_work/manus208_single_saturated_bubble_precip_3h</summary>


**[migration_work/manus208_single_saturated_bubble_precip_3h/configuration.json](../../migration_work/manus208_single_saturated_bubble_precip_3h/configuration.json)**

原檔SHA-256：`0b8502891dc6f17beffedead3c95f33ffad65b275541f4a3dbdf85c45c1c445d`。完整附件key：`records["migration_work/manus208_single_saturated_bubble_precip_3h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/manus208_single_saturated_bubble_precip_3h/configuration.json)

</details>

<a id="workspace-100"></a>

<details>
<summary>100 — migration_work/manus208_single_saturated_bubble_precip_review</summary>


**[migration_work/manus208_single_saturated_bubble_precip_review/configuration.json](../../migration_work/manus208_single_saturated_bubble_precip_review/configuration.json)**

原檔SHA-256：`0b8502891dc6f17beffedead3c95f33ffad65b275541f4a3dbdf85c45c1c445d`。完整附件key：`records["migration_work/manus208_single_saturated_bubble_precip_review/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/manus208_single_saturated_bubble_precip_review/commands.json)
- [configuration.json](../../migration_work/manus208_single_saturated_bubble_precip_review/configuration.json)
- [reference_case.json](../../migration_work/manus208_single_saturated_bubble_precip_review/reference_case.json)
- [reference_comparison.json](../../migration_work/manus208_single_saturated_bubble_precip_review/reference_comparison.json)
- [results.json](../../migration_work/manus208_single_saturated_bubble_precip_review/results.json)

</details>

<a id="workspace-101"></a>

<details>
<summary>101 — migration_work/manus_multi_double_precision_12h</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/manus_multi_double_precision_12h/results.json](../../migration_work/manus_multi_double_precision_12h/results.json)**

原檔SHA-256：`44cf6042cefcb7f913a84b8649f59da21c3af8ada40c7e2a9afcc950d2ba2903`。完整附件key：`records["migration_work/manus_multi_double_precision_12h/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case` | "manus" |
| `profile_index` | 208 |
| `duration_seconds` | 43200 |
| `dt_seconds` | 4 |
| `output_step_seconds` | 60 |
| `ace_mode` | "multi" |
| `precipitation` | "enabled" |
| `precision_bits` | 64 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/manus_multi_double_precision_12h/results.json)

</details>

<a id="workspace-102"></a>

<details>
<summary>102 — migration_work/manus_multi_precision_comparison</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/manus_multi_precision_comparison/results.json](../../migration_work/manus_multi_precision_comparison/results.json)**

原檔SHA-256：`be6eda58f70370e699478eac528313f14279c56573a6ac7b6e5e232b44654df9`。完整附件key：`records["migration_work/manus_multi_precision_comparison/results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/manus_multi_precision_comparison/results.json)

</details>

<a id="workspace-103"></a>

<details>
<summary>103 — migration_work/manus_multi_single_precision_12h</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/manus_multi_single_precision_12h/results.json](../../migration_work/manus_multi_single_precision_12h/results.json)**

原檔SHA-256：`0298dad57ff70120d6e5ecbdc2ade4b008bfcfa1ade598d9ccbc9a7f9f386895`。完整附件key：`records["migration_work/manus_multi_single_precision_12h/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `case` | "manus" |
| `profile_index` | 208 |
| `duration_seconds` | 43200 |
| `dt_seconds` | 4 |
| `output_step_seconds` | 60 |
| `ace_mode` | "multi" |
| `precipitation` | "enabled" |
| `precision_bits` | 32 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/manus_multi_single_precision_12h/results.json)
- [preview/results.json](../../migration_work/manus_multi_single_precision_12h/preview/results.json)

</details>

<a id="workspace-104"></a>

<details>
<summary>104 — migration_work/mixed_precipitation_run</summary>


**[migration_work/mixed_precipitation_run/configuration.json](../../migration_work/mixed_precipitation_run/configuration.json)**

原檔SHA-256：`f7c380d32e7edea7ac745c33facbf826b6b3546697f7993725e02720c4a24b08`。完整附件key：`records["migration_work/mixed_precipitation_run/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/mixed_precipitation_run/configuration.json)
- [multi_mixed_precip_comparison.json](../../migration_work/mixed_precipitation_run/multi_mixed_precip_comparison.json)
- [multi_mixed_precip_mixed_evidence.json](../../migration_work/mixed_precipitation_run/multi_mixed_precip_mixed_evidence.json)
- [phase_build_command.json](../../migration_work/mixed_precipitation_run/phase_build_command.json)
- [single_mixed_precip_comparison.json](../../migration_work/mixed_precipitation_run/single_mixed_precip_comparison.json)
- [single_mixed_precip_mixed_evidence.json](../../migration_work/mixed_precipitation_run/single_mixed_precip_mixed_evidence.json)
- [thermo_comparison.json](../../migration_work/mixed_precipitation_run/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/mixed_precipitation_run/thermo_labels.json)

</details>

<a id="workspace-105"></a>

<details>
<summary>105 — migration_work/mixed_residual_replay</summary>


**[migration_work/mixed_residual_replay/configuration.json](../../migration_work/mixed_residual_replay/configuration.json)**

原檔SHA-256：`9fd44b1a2419de29decce37e7ea3f5b079526c768e1922adf64d5cd038ff8800`。完整附件key：`records["migration_work/mixed_residual_replay/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/mixed_residual_replay/configuration.json)
- [results.json](../../migration_work/mixed_residual_replay/results.json)

</details>

<a id="workspace-106"></a>

<details>
<summary>106 — migration_work/mixed_residual_review</summary>


**[migration_work/mixed_residual_review/configuration.json](../../migration_work/mixed_residual_review/configuration.json)**

原檔SHA-256：`9fd44b1a2419de29decce37e7ea3f5b079526c768e1922adf64d5cd038ff8800`。完整附件key：`records["migration_work/mixed_residual_review/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/mixed_residual_review/configuration.json)
- [results.json](../../migration_work/mixed_residual_review/results.json)

</details>

<a id="workspace-107"></a>

<details>
<summary>107 — migration_work/p3_inventory</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/p3_inventory/source_inventory.json](../../migration_work/p3_inventory/source_inventory.json)**

原檔SHA-256：`6f03adc8ddb39b06988262c214a8c7ddc860a3310abc0dd93d5cdf8933e50af9`。完整附件key：`records["migration_work/p3_inventory/source_inventory.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [compile_summary.json](../../migration_work/p3_inventory/compile_summary.json)
- [source_inventory.json](../../migration_work/p3_inventory/source_inventory.json)
- [wrapper_summary.json](../../migration_work/p3_inventory/wrapper_summary.json)

</details>

<a id="workspace-108"></a>

<details>
<summary>108 — migration_work/pchip_adoption_after</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pchip_adoption_after/bitwise_comparison.json](../../migration_work/pchip_adoption_after/bitwise_comparison.json)**

原檔SHA-256：`45092bc374d1dc3d5d4178cde7303a0834bf63ec06970e99f7c2024acf43dedd`。完整附件key：`records["migration_work/pchip_adoption_after/bitwise_comparison.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

**[migration_work/pchip_adoption_after/metadata.json](../../migration_work/pchip_adoption_after/metadata.json)**

原檔SHA-256：`a92b7b44cedf9f24c6388fdb2af96ea5ab3e5e59db4672fdac20d01d2810c7ac`。完整附件key：`records["migration_work/pchip_adoption_after/metadata.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

**[migration_work/pchip_adoption_after/results.json](../../migration_work/pchip_adoption_after/results.json)**

原檔SHA-256：`52f3d630f64ab629282b4cee37880a63f5806e7b33f12456de8c265ad7e45bef`。完整附件key：`records["migration_work/pchip_adoption_after/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [bitwise_comparison.json](../../migration_work/pchip_adoption_after/bitwise_comparison.json)
- [metadata.json](../../migration_work/pchip_adoption_after/metadata.json)
- [results.json](../../migration_work/pchip_adoption_after/results.json)

</details>

<a id="workspace-109"></a>

<details>
<summary>109 — migration_work/pchip_adoption_before</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pchip_adoption_before/metadata.json](../../migration_work/pchip_adoption_before/metadata.json)**

原檔SHA-256：`f8bad0f673a892c71c3e710b46f1412d4adb2551c563643d9b76b0aac645ba66`。完整附件key：`records["migration_work/pchip_adoption_before/metadata.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `seed` | 20261004 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [metadata.json](../../migration_work/pchip_adoption_before/metadata.json)

</details>

<a id="workspace-110"></a>

<details>
<summary>110 — migration_work/pchip_adoption_model</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pchip_adoption_model/results.json](../../migration_work/pchip_adoption_model/results.json)**

原檔SHA-256：`a7d606602bdf67cc03debf10bc9965e64a1d115a195604e8c3b06357d1e53b39`。完整附件key：`records["migration_work/pchip_adoption_model/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `steps` | 10 |
| `dt_seconds` | 4 |
| `saved_states` | 11 |
| `ncols` | 8 |
| `nz` | 801 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/pchip_adoption_model/results.json)

</details>

<a id="workspace-111"></a>

<details>
<summary>111 — migration_work/pressure_power_audit</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pressure_power_audit/results.json](../../migration_work/pressure_power_audit/results.json)**

原檔SHA-256：`3e8763b3390fea2ceea4f9241ca3153680fa771efd1e3258a86977474cccfded`。完整附件key：`records["migration_work/pressure_power_audit/results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/pressure_power_audit/results.json)

</details>

<a id="workspace-112"></a>

<details>
<summary>112 — migration_work/pressure_power_check</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pressure_power_check/results.json](../../migration_work/pressure_power_check/results.json)**

原檔SHA-256：`a758e7ae85f2921f96b48a6466ca67f318a597785f316dc89b01b2c8fb5fa6cd`。完整附件key：`records["migration_work/pressure_power_check/results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/pressure_power_check/results.json)

</details>

<a id="workspace-113"></a>

<details>
<summary>113 — migration_work/pressure_power_review</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/pressure_power_review/results.json](../../migration_work/pressure_power_review/results.json)**

原檔SHA-256：`5aeb8fb7db1a43121aacf87898f88d0f16543fb70c340a8e2f35c72dacdc0f1d`。完整附件key：`records["migration_work/pressure_power_review/results.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [results.json](../../migration_work/pressure_power_review/results.json)

</details>

<a id="workspace-114"></a>

<details>
<summary>114 — migration_work/reference_tv_alignment</summary>


**[migration_work/reference_tv_alignment/configuration.json](../../migration_work/reference_tv_alignment/configuration.json)**

原檔SHA-256：`757ce855386e58907b01d1c4a1efcb071616c9ebca34d555ef8feccd179ed512`。完整附件key：`records["migration_work/reference_tv_alignment/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_alignment/configuration.json)

</details>

<a id="workspace-115"></a>

<details>
<summary>115 — migration_work/reference_tv_build</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [build_commands.json](../../migration_work/reference_tv_build/build_commands.json)

</details>

<a id="workspace-116"></a>

<details>
<summary>116 — migration_work/reference_tv_diagnostic</summary>


**[migration_work/reference_tv_diagnostic/configuration.json](../../migration_work/reference_tv_diagnostic/configuration.json)**

原檔SHA-256：`f5ad1bdc269e035d520e653e7e563c66b02071aa64059066b9f27e603a4cbe50`。完整附件key：`records["migration_work/reference_tv_diagnostic/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_diagnostic/configuration.json)

</details>

<a id="workspace-117"></a>

<details>
<summary>117 — migration_work/reference_tv_isolation</summary>


**[migration_work/reference_tv_isolation/configuration.json](../../migration_work/reference_tv_isolation/configuration.json)**

原檔SHA-256：`f5ad1bdc269e035d520e653e7e563c66b02071aa64059066b9f27e603a4cbe50`。完整附件key：`records["migration_work/reference_tv_isolation/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_isolation/configuration.json)

</details>

<a id="workspace-118"></a>

<details>
<summary>118 — migration_work/reference_tv_paired</summary>


**[migration_work/reference_tv_paired/configuration.json](../../migration_work/reference_tv_paired/configuration.json)**

原檔SHA-256：`f5ad1bdc269e035d520e653e7e563c66b02071aa64059066b9f27e603a4cbe50`。完整附件key：`records["migration_work/reference_tv_paired/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_paired/configuration.json)
- [results.json](../../migration_work/reference_tv_paired/results.json)

</details>

<a id="workspace-119"></a>

<details>
<summary>119 — migration_work/reference_tv_regression</summary>


**[migration_work/reference_tv_regression/configuration.json](../../migration_work/reference_tv_regression/configuration.json)**

原檔SHA-256：`757ce855386e58907b01d1c4a1efcb071616c9ebca34d555ef8feccd179ed512`。完整附件key：`records["migration_work/reference_tv_regression/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_regression/configuration.json)
- [multi_comparison.json](../../migration_work/reference_tv_regression/multi_comparison.json)
- [multi_ice_precip_comparison.json](../../migration_work/reference_tv_regression/multi_ice_precip_comparison.json)
- [multi_ice_precip_ice_evidence.json](../../migration_work/reference_tv_regression/multi_ice_precip_ice_evidence.json)
- [multi_mixed_precip_comparison.json](../../migration_work/reference_tv_regression/multi_mixed_precip_comparison.json)
- [multi_mixed_precip_mixed_evidence.json](../../migration_work/reference_tv_regression/multi_mixed_precip_mixed_evidence.json)
- [multi_precip_comparison.json](../../migration_work/reference_tv_regression/multi_precip_comparison.json)
- [phase_build_command.json](../../migration_work/reference_tv_regression/phase_build_command.json)
- [single_comparison.json](../../migration_work/reference_tv_regression/single_comparison.json)
- [single_ice_precip_comparison.json](../../migration_work/reference_tv_regression/single_ice_precip_comparison.json)
- [single_ice_precip_ice_evidence.json](../../migration_work/reference_tv_regression/single_ice_precip_ice_evidence.json)
- [single_mixed_precip_comparison.json](../../migration_work/reference_tv_regression/single_mixed_precip_comparison.json)
- [single_mixed_precip_mixed_evidence.json](../../migration_work/reference_tv_regression/single_mixed_precip_mixed_evidence.json)
- [single_precip_comparison.json](../../migration_work/reference_tv_regression/single_precip_comparison.json)
- [thermo_comparison.json](../../migration_work/reference_tv_regression/thermo_comparison.json)
- [thermo_labels.json](../../migration_work/reference_tv_regression/thermo_labels.json)

</details>

<a id="workspace-120"></a>

<details>
<summary>120 — migration_work/reference_tv_run</summary>


**[migration_work/reference_tv_run/configuration.json](../../migration_work/reference_tv_run/configuration.json)**

原檔SHA-256：`f5ad1bdc269e035d520e653e7e563c66b02071aa64059066b9f27e603a4cbe50`。完整附件key：`records["migration_work/reference_tv_run/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [configuration.json](../../migration_work/reference_tv_run/configuration.json)

</details>

<a id="workspace-121"></a>

<details>
<summary>121 — migration_work/shared_input</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [reports/comparison_environment.json](../../migration_work/shared_input/reports/comparison_environment.json)
- [reports/fortran_readback.json](../../migration_work/shared_input/reports/fortran_readback.json)
- [reports/goamazon314_comparison.json](../../migration_work/shared_input/reports/goamazon314_comparison.json)
- [reports/input_manifest.json](../../migration_work/shared_input/reports/input_manifest.json)
- [reports/manus208_comparison.json](../../migration_work/shared_input/reports/manus208_comparison.json)
- [reports/shared_input_fortran_validation.json](../../migration_work/shared_input/reports/shared_input_fortran_validation.json)
- [reports/shared_input_matlab_validation.json](../../migration_work/shared_input/reports/shared_input_matlab_validation.json)

</details>

<a id="workspace-122"></a>

<details>
<summary>122 — migration_work/single_precision_precip</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-123"></a>

<details>
<summary>123 — migration_work/single_precision_precip_corrected</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/single_precision_precip_corrected/results.json](../../migration_work/single_precision_precip_corrected/results.json)**

原檔SHA-256：`500747ee86bd8ef50a65b74a0ff835f87df415720690f73f5a3a08ceae6a2978`。完整附件key：`records["migration_work/single_precision_precip_corrected/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 10800 |
| `dt_seconds` | 4 |

**[migration_work/single_precision_precip_corrected/verified_results.json](../../migration_work/single_precision_precip_corrected/verified_results.json)**

原檔SHA-256：`f9eceef1d495aaddde60347272ce923fde509d20ce6ac65f783a416615906037`。完整附件key：`records["migration_work/single_precision_precip_corrected/verified_results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 10800 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/single_precision_precip_corrected/commands.json)
- [results.json](../../migration_work/single_precision_precip_corrected/results.json)
- [verified_results.json](../../migration_work/single_precision_precip_corrected/verified_results.json)
- [matlab_comparison/results.json](../../migration_work/single_precision_precip_corrected/matlab_comparison/results.json)
- [production_build32/results.json](../../migration_work/single_precision_precip_corrected/production_build32/results.json)

</details>

<a id="workspace-124"></a>

<details>
<summary>124 — migration_work/single_precision_precip_runner_check</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/single_precision_precip_runner_check/results.json](../../migration_work/single_precision_precip_runner_check/results.json)**

原檔SHA-256：`76854c5d828bd6c020ffb4482e3154917be83ad93b64ac5ea231620a5bc792d7`。完整附件key：`records["migration_work/single_precision_precip_runner_check/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 60 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/single_precision_precip_runner_check/commands.json)
- [results.json](../../migration_work/single_precision_precip_runner_check/results.json)

</details>

<a id="workspace-125"></a>

<details>
<summary>125 — migration_work/single_precision_precip_smoke</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/single_precision_precip_smoke/results.json](../../migration_work/single_precision_precip_smoke/results.json)**

原檔SHA-256：`6ffd74c111afd052f6ea976cb22f4374da92494ce4d5f150343dcfbb9f72d1be`。完整附件key：`records["migration_work/single_precision_precip_smoke/results.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 60 |
| `dt_seconds` | 4 |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/single_precision_precip_smoke/commands.json)
- [results.json](../../migration_work/single_precision_precip_smoke/results.json)

</details>

<a id="workspace-126"></a>

<details>
<summary>126 — migration_work/thermodynamic_alignment</summary>


**[migration_work/thermodynamic_alignment/focused/configuration.json](../../migration_work/thermodynamic_alignment/focused/configuration.json)**

原檔SHA-256：`7950427ba5d214fb0afa3a3bbc4f1219cf33f5e42b291924fdaeb36203559119`。完整附件key：`records["migration_work/thermodynamic_alignment/focused/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `acceptance_tolerance` | "None; reports bitwise equality and raw differences" |

**[migration_work/thermodynamic_alignment/pilot/configuration.json](../../migration_work/thermodynamic_alignment/pilot/configuration.json)**

原檔SHA-256：`dc2e99ad2261b78f5740eb901eac7c87a82e4252c6fc9676212db9a1fa94812d`。完整附件key：`records["migration_work/thermodynamic_alignment/pilot/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `acceptance_tolerance` | "None; reports bitwise equality and raw differences" |

**[migration_work/thermodynamic_alignment/pressure_1100/configuration.json](../../migration_work/thermodynamic_alignment/pressure_1100/configuration.json)**

原檔SHA-256：`c09e8fb76feec8984a0fbda8376b6d7b89ce2ddbe69909efe3564e956c7268e7`。完整附件key：`records["migration_work/thermodynamic_alignment/pressure_1100/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `acceptance_tolerance` | "None; reports bitwise equality and raw differences" |

**[migration_work/thermodynamic_alignment/runner_smoke/configuration.json](../../migration_work/thermodynamic_alignment/runner_smoke/configuration.json)**

原檔SHA-256：`ee564cf54a88e9524b75177303433eeec8a2b72f3093f5876266588073b51f14`。完整附件key：`records["migration_work/thermodynamic_alignment/runner_smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `acceptance_tolerance` | "None; reports exact-value equality, bitwise equality and raw differences" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [atmospheric_1200/manifest.json](../../migration_work/thermodynamic_alignment/atmospheric_1200/manifest.json)
- [atmospheric_1200/results.json](../../migration_work/thermodynamic_alignment/atmospheric_1200/results.json)
- [focused/configuration.json](../../migration_work/thermodynamic_alignment/focused/configuration.json)
- [focused/failure_review.json](../../migration_work/thermodynamic_alignment/focused/failure_review.json)
- [focused/focused_results.json](../../migration_work/thermodynamic_alignment/focused/focused_results.json)
- [focused/scope_verification.json](../../migration_work/thermodynamic_alignment/focused/scope_verification.json)
- [focused/summary.json](../../migration_work/thermodynamic_alignment/focused/summary.json)
- [ice_derivative_25/manifest.json](../../migration_work/thermodynamic_alignment/ice_derivative_25/manifest.json)
- [ice_derivative_25/results.json](../../migration_work/thermodynamic_alignment/ice_derivative_25/results.json)
- [ice_saturation/cases.json](../../migration_work/thermodynamic_alignment/ice_saturation/cases.json)
- [liquid_boundary/base_input.json](../../migration_work/thermodynamic_alignment/liquid_boundary/base_input.json)
- [liquid_boundary/cases.json](../../migration_work/thermodynamic_alignment/liquid_boundary/cases.json)
- [liquid_derivative_25/manifest.json](../../migration_work/thermodynamic_alignment/liquid_derivative_25/manifest.json)
- [liquid_derivative_25/results.json](../../migration_work/thermodynamic_alignment/liquid_derivative_25/results.json)
- [liquid_derivative_25/verified_results.json](../../migration_work/thermodynamic_alignment/liquid_derivative_25/verified_results.json)
- [mixed_phase_25/manifest.json](../../migration_work/thermodynamic_alignment/mixed_phase_25/manifest.json)
- [mixed_phase_25/results.json](../../migration_work/thermodynamic_alignment/mixed_phase_25/results.json)
- [phase_endpoint_preview/manifest.json](../../migration_work/thermodynamic_alignment/phase_endpoint_preview/manifest.json)
- [phase_endpoint_preview/results.json](../../migration_work/thermodynamic_alignment/phase_endpoint_preview/results.json)
- [pilot/configuration.json](../../migration_work/thermodynamic_alignment/pilot/configuration.json)
- [pilot/summary.json](../../migration_work/thermodynamic_alignment/pilot/summary.json)
- [pressure_1100/configuration.json](../../migration_work/thermodynamic_alignment/pressure_1100/configuration.json)
- [pressure_1100/summary.json](../../migration_work/thermodynamic_alignment/pressure_1100/summary.json)
- [runner_smoke/configuration.json](../../migration_work/thermodynamic_alignment/runner_smoke/configuration.json)
- [runner_smoke/focused_0000000.json](../../migration_work/thermodynamic_alignment/runner_smoke/focused_0000000.json)
- [runner_smoke/summary.json](../../migration_work/thermodynamic_alignment/runner_smoke/summary.json)
- [saturation_boundary/cases.json](../../migration_work/thermodynamic_alignment/saturation_boundary/cases.json)
- [targeted_boundaries/cases.json](../../migration_work/thermodynamic_alignment/targeted_boundaries/cases.json)

</details>

<a id="workspace-127"></a>

<details>
<summary>127 — migration_work/v018_normalized_multi_12h</summary>


**[migration_work/v018_normalized_multi_12h/configuration.json](../../migration_work/v018_normalized_multi_12h/configuration.json)**

原檔SHA-256：`4b3e3780edb0521ec3f88c0db9212d2fe4d8e54757a027e9db58b15aa23e12b7`。完整附件key：`records["migration_work/v018_normalized_multi_12h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |
| `ace_mode` | "multi" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/v018_normalized_multi_12h/commands.json)
- [configuration.json](../../migration_work/v018_normalized_multi_12h/configuration.json)
- [results.json](../../migration_work/v018_normalized_multi_12h/results.json)

</details>

<a id="workspace-128"></a>

<details>
<summary>128 — migration_work/v018_normalized_single_no_precip</summary>


**[migration_work/v018_normalized_single_no_precip/configuration.json](../../migration_work/v018_normalized_single_no_precip/configuration.json)**

原檔SHA-256：`bf5250092ff80553dc271eb0a0208a29ff37533e89b7f10c509f757e1dfc37b1`。完整附件key：`records["migration_work/v018_normalized_single_no_precip/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "disabled" |
| `ace_mode` | "single" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/v018_normalized_single_no_precip/commands.json)
- [configuration.json](../../migration_work/v018_normalized_single_no_precip/configuration.json)
- [reference_case.json](../../migration_work/v018_normalized_single_no_precip/reference_case.json)
- [reference_comparison.json](../../migration_work/v018_normalized_single_no_precip/reference_comparison.json)
- [results.json](../../migration_work/v018_normalized_single_no_precip/results.json)

</details>

<a id="workspace-129"></a>

<details>
<summary>129 — migration_work/v018_normalized_single_precip</summary>


**[migration_work/v018_normalized_single_precip/configuration.json](../../migration_work/v018_normalized_single_precip/configuration.json)**

原檔SHA-256：`799a2885de07a8fba08332d96c556ecbcf6c89cdcbef9ed50f2b526a8fc64a12`。完整附件key：`records["migration_work/v018_normalized_single_precip/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `precipitation` | "enabled" |
| `ace_mode` | "single" |

本目錄所有JSON紀錄（含巢狀子測試）：

- [commands.json](../../migration_work/v018_normalized_single_precip/commands.json)
- [configuration.json](../../migration_work/v018_normalized_single_precip/configuration.json)
- [reference_case.json](../../migration_work/v018_normalized_single_precip/reference_case.json)
- [reference_comparison.json](../../migration_work/v018_normalized_single_precip/reference_comparison.json)
- [results.json](../../migration_work/v018_normalized_single_precip/results.json)

</details>

<a id="workspace-130"></a>

<details>
<summary>130 — migration_work/v018_pre_normalization</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [manifest.json](../../migration_work/v018_pre_normalization/manifest.json)

</details>

<a id="workspace-131"></a>

<details>
<summary>131 — migration_work/v02087_author_input</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [inspection.json](../../migration_work/v02087_author_input/inspection.json)

</details>

<a id="workspace-132"></a>

<details>
<summary>132 — migration_work/v020_source_review</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

**[migration_work/v020_source_review/manifest.json](../../migration_work/v020_source_review/manifest.json)**

原檔SHA-256：`7bead33dbe775357beb2a6cb9a312742aa02227159515099d9d4583b3d0570d2`。完整附件key：`records["migration_work/v020_source_review/manifest.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

本目錄所有JSON紀錄（含巢狀子測試）：

- [manifest.json](../../migration_work/v020_source_review/manifest.json)

</details>

<a id="workspace-133"></a>

<details>
<summary>133 — migration_work/v02187_github_release</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- [release.json](../../migration_work/v02187_github_release/release.json)

</details>

<a id="workspace-134"></a>

<details>
<summary>134 — migration_work/v02187_release_reconstruction</summary>


未找到獨立configuration；以下結果可能含embedded設定，不表示未執行或已通過。

本目錄所有JSON紀錄（含巢狀子測試）：

- 無JSON紀錄；來源／log需另行人工審核。

</details>

<a id="workspace-135"></a>

<details>
<summary>135 — migration_work/v02187_validation</summary>

- 原始狀態 [migration_work/v02187_validation/basis_threads_extended/status.json](../../migration_work/v02187_validation/basis_threads_extended/status.json)：`{"phase":"completed"}`
- 原始狀態 [migration_work/v02187_validation/gates/status.json](../../migration_work/v02187_validation/gates/status.json)：`{"phase":"stopped_for_unit_mapping_correction"}`
- 原始狀態 [migration_work/v02187_validation/matlab_default_fortran32/status.json](../../migration_work/v02187_validation/matlab_default_fortran32/status.json)：`{"phase":"stopped_investigate_matlab_thread_slowdown"}`
- 原始狀態 [migration_work/v02187_validation/native8h_threads32/status.json](../../migration_work/v02187_validation/native8h_threads32/status.json)：`{"phase":"completed_pending_scientific_review"}`
- 原始狀態 [migration_work/v02187_validation/native_units/status.json](../../migration_work/v02187_validation/native_units/status.json)：`{"phase":"stopped_layout_preservation"}`
- 原始狀態 [migration_work/v02187_validation/packed_momentum/status.json](../../migration_work/v02187_validation/packed_momentum/status.json)：`{"phase":"stopped_stopped_for_matlab_default_fortran32"}`
- 原始狀態 [migration_work/v02187_validation/parallel32_10min_1h/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/status.json)：`{"phase":"completed_awaiting_8h_decision"}`
- 原始狀態 [migration_work/v02187_validation/parallel32_10min_1h/native_10min/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/status.json)：`{"phase":"completed_pending_scientific_review"}`
- 原始狀態 [migration_work/v02187_validation/parallel32_10min_1h/native_1h/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/status.json)：`{"phase":"completed_pending_scientific_review"}`
- 原始狀態 [migration_work/v02187_validation/threads32/status.json](../../migration_work/v02187_validation/threads32/status.json)：`{"phase":"stopped_parallel_10min_1h_no_8h"}`

**[migration_work/v02187_validation/basis_threads_extended/configuration.json](../../migration_work/v02187_validation/basis_threads_extended/configuration.json)**

原檔SHA-256：`f1752621a12bb1c4a52da063be5f235b5225893c4a65e0c925a75fc9f9a70440`。完整附件key：`records["migration_work/v02187_validation/basis_threads_extended/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `environment` | "inherited unchanged by Python; no concurrent test Fortran" |

**[migration_work/v02187_validation/gates/configuration.json](../../migration_work/v02187_validation/gates/configuration.json)**

原檔SHA-256：`39b61701872946242f3a560dd1ccf2c8c60a9de33c03a67b806542f8504a5606`。完整附件key：`records["migration_work/v02187_validation/gates/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 8 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/gates/smoke/configuration.json](../../migration_work/v02187_validation/gates/smoke/configuration.json)**

原檔SHA-256：`96e27445db89cff36707efcd3bc73b8efe5f188c87f4cfba11bb3f2ee3a7cbb4`。完整附件key：`records["migration_work/v02187_validation/gates/smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/matlab_default_fortran32/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/configuration.json)**

原檔SHA-256：`c0433d2676e6004252aeb5519b00a57314ef5e664b37c5fe027b462db2cbf4f8`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 32 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/matlab_default_fortran32/dry_10min/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/dry_10min/configuration.json)**

原檔SHA-256：`864326061fe943dba82a66e5c2a37805fcc3de9a5eed4f8e3af89238f559f706`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/dry_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "none" |
| `pulse` | false |

**[migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v0/configuration.json)**

原檔SHA-256：`4187049cd3591e3dbd58d7bbe6b5755d113e4e798a9adb74dc74c63a4f820f6f`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v1/configuration.json)**

原檔SHA-256：`bc4cbf973058588d5f0a8af170b0e3a7102b5c067cadcb97b9737a5489f27fe6`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v0/configuration.json)**

原檔SHA-256：`8f0bdf9786745d32ee9d4f9fb7670b2310fd3c00ebbc1f9ba9d793eeb8eecb83`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v1/configuration.json)**

原檔SHA-256：`46128d4be70b287bce9036d0326047f25257c9a30ec49a7ed141955ac5977560`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/matlab_default_fortran32/smoke/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/smoke/configuration.json)**

原檔SHA-256：`ba9a0860af08f60f77f06cca2a4e1fcea59cf368168779aab958796ccf9cf0b8`。完整附件key：`records["migration_work/v02187_validation/matlab_default_fortran32/smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/matlab_inherited_environment_profile/configuration.json](../../migration_work/v02187_validation/matlab_inherited_environment_profile/configuration.json)**

原檔SHA-256：`bfa6e75fdaa0a6ee7b7661f7249e34cf305358b0041542845dd02ef7a0105237`。完整附件key：`records["migration_work/v02187_validation/matlab_inherited_environment_profile/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `dt_seconds` | 6 |
| `physics` | "native" |

**[migration_work/v02187_validation/matlab_inherited_environment_smoke/configuration.json](../../migration_work/v02187_validation/matlab_inherited_environment_smoke/configuration.json)**

原檔SHA-256：`5598329f8aebf8c420f8eae48afc447a43fb16e17f586f77771ca6a1ede16363`。完整附件key：`records["migration_work/v02187_validation/matlab_inherited_environment_smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `dt_seconds` | 6 |
| `physics` | "native" |

**[migration_work/v02187_validation/native8h_threads32/configuration.json](../../migration_work/v02187_validation/native8h_threads32/configuration.json)**

原檔SHA-256：`695449132e636d9f42920aff33ca156c3183c0cde105f6fcea8c212277c05829`。完整附件key：`records["migration_work/v02187_validation/native8h_threads32/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 32 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/native8h_threads32/launch_configuration.json](../../migration_work/v02187_validation/native8h_threads32/launch_configuration.json)**

原檔SHA-256：`dd674e51634d97e0bc24ee60a3067cd69931b643d1010070f8a0a019dc3c323f`。完整附件key：`records["migration_work/v02187_validation/native8h_threads32/launch_configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 28800 |

**[migration_work/v02187_validation/native8h_threads32/native_8h/configuration.json](../../migration_work/v02187_validation/native8h_threads32/native_8h/configuration.json)**

原檔SHA-256：`dcab1be04a2e9716f5b3ec63ea97a2051ae7741e9463a6dbce2387416f2f8d54`。完整附件key：`records["migration_work/v02187_validation/native8h_threads32/native_8h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 28800 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/native_units/configuration.json](../../migration_work/v02187_validation/native_units/configuration.json)**

原檔SHA-256：`d0d7d34c818afa37b226664952f618d43bb174de5857573b8cf37f9702db543a`。完整附件key：`records["migration_work/v02187_validation/native_units/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 8 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/native_units/dry_10min/configuration.json](../../migration_work/v02187_validation/native_units/dry_10min/configuration.json)**

原檔SHA-256：`b727b4dd74e1f49018831d1f98a9c125c15fe4cdf134e802e8c86bb910df05b7`。完整附件key：`records["migration_work/v02187_validation/native_units/dry_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "none" |
| `pulse` | false |

**[migration_work/v02187_validation/native_units/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v0/configuration.json)**

原檔SHA-256：`652e691745f16c3e8906ad78f15c73f42fbf57cdb377b6706c5f47f89bbd5e22`。完整附件key：`records["migration_work/v02187_validation/native_units/nonzero_mf_h0v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/native_units/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v1/configuration.json)**

原檔SHA-256：`bf8420cea08ffa2e41a4bdb8c0ca7e015abb9fb9111477dc203149cb0989258b`。完整附件key：`records["migration_work/v02187_validation/native_units/nonzero_mf_h0v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/native_units/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v0/configuration.json)**

原檔SHA-256：`b296aa4e3cbfe44c58c64ac0b11564aa95a764aa64520f0ea3c3281dafe7dcc6`。完整附件key：`records["migration_work/v02187_validation/native_units/nonzero_mf_h1v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/native_units/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v1/configuration.json)**

原檔SHA-256：`93d1987794e2595b792c996455f92dcf50f00da22ac691186738351fb5227823`。完整附件key：`records["migration_work/v02187_validation/native_units/nonzero_mf_h1v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/native_units/smoke/configuration.json](../../migration_work/v02187_validation/native_units/smoke/configuration.json)**

原檔SHA-256：`34d603bc4f4c045dc1cafac3ebcf8c4975bc3bd81471e034c4d64efbfd010011`。完整附件key：`records["migration_work/v02187_validation/native_units/smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/configuration.json](../../migration_work/v02187_validation/packed_momentum/configuration.json)**

原檔SHA-256：`f0573135684099119561abe143123fa8bc0ffee4fcfe34dcd3ec1b108110daae`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 8 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/packed_momentum/dry_10min/configuration.json](../../migration_work/v02187_validation/packed_momentum/dry_10min/configuration.json)**

原檔SHA-256：`f0923ebb95a4d7c5c41641f289d4ab13e9f2499d8f10891eb8299db3aba546f6`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/dry_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "none" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/dt_1p5/configuration.json](../../migration_work/v02187_validation/packed_momentum/dt_1p5/configuration.json)**

原檔SHA-256：`57822de5a19df04a1ab57c4c6638ff93e8889dcc4ddfa292f352fbe8ef9f27d0`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/dt_1p5/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/dt_3/configuration.json](../../migration_work/v02187_validation/packed_momentum/dt_3/configuration.json)**

原檔SHA-256：`e335f3d9512382c47640db3a1ec0520e9ac32b96765d783eebb1a3c514f23cee`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/dt_3/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/native_10min/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_10min/configuration.json)**

原檔SHA-256：`bfc4ad0d54ae94b2b6b22655239d9cba63b54c96a3e7767e959b672180e996a2`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/native_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/native_1h/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_1h/configuration.json)**

原檔SHA-256：`4e3737d963d3cff252dc1b46dbc8501ed01dda91562a7da169135e8192032bbc`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/native_1h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 3600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/native_8h/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_8h/configuration.json)**

原檔SHA-256：`7296192566154d4b805d4b1d1f065d072f1046d3333138f49b8d7f1ad3d6c001`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/native_8h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 28800 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v0/configuration.json)**

原檔SHA-256：`d0d083c277b6f8b017efb3d67ba4e1a5d1f71e1ac66993dae8e5a280f84e5505`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v1/configuration.json)**

原檔SHA-256：`20d751eaa7e8d374bfead328b8ce841a7fcb37479a5dafec6dc28da06ed131d5`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v0/configuration.json)**

原檔SHA-256：`58b1c2b8f8c74598737b52ea435b4ad832cd5de6717dde1fb6288412e0e9c84a`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v1/configuration.json)**

原檔SHA-256：`cd55542ecaea623c19cf5b674ee8a21ca7f3ac33a7a0f8207bb89f76596cdcd2`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v1/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/packed_momentum/smoke/configuration.json](../../migration_work/v02187_validation/packed_momentum/smoke/configuration.json)**

原檔SHA-256：`6e82481e4b11d8e211dfcbfb11ee680ac099971f29cdf99b666d50d121313faf`。完整附件key：`records["migration_work/v02187_validation/packed_momentum/smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/parallel32_10min_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/configuration.json)**

原檔SHA-256：`5fd58dbb76a0761d616f9ea708b0d9644e38bdbf5192d99e8d949bd13d3f4139`。完整附件key：`records["migration_work/v02187_validation/parallel32_10min_1h/configuration.json"].data`。

此檔使用其他schema；請查完整配置，不推定defaults。

**[migration_work/v02187_validation/parallel32_10min_1h/native_10min/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/configuration.json)**

原檔SHA-256：`695449132e636d9f42920aff33ca156c3183c0cde105f6fcea8c212277c05829`。完整附件key：`records["migration_work/v02187_validation/parallel32_10min_1h/native_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 32 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/configuration.json)**

原檔SHA-256：`c4c40fa35fa4b0a84788b0cdaae610eff8ff94cd4222575bd35a1ff40cc80ec7`。完整附件key：`records["migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/parallel32_10min_1h/native_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/configuration.json)**

原檔SHA-256：`695449132e636d9f42920aff33ca156c3183c0cde105f6fcea8c212277c05829`。完整附件key：`records["migration_work/v02187_validation/parallel32_10min_1h/native_1h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 32 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/parallel32_10min_1h/native_1h/native_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/native_1h/configuration.json)**

原檔SHA-256：`44f984bd35e49645a616ef77e7498a25c4cb0c0fa445db10ca62201f446f4fc1`。完整附件key：`records["migration_work/v02187_validation/parallel32_10min_1h/native_1h/native_1h/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 3600 |
| `physics` | "native" |
| `pulse` | false |

**[migration_work/v02187_validation/threads32/configuration.json](../../migration_work/v02187_validation/threads32/configuration.json)**

原檔SHA-256：`695449132e636d9f42920aff33ca156c3183c0cde105f6fcea8c212277c05829`。完整附件key：`records["migration_work/v02187_validation/threads32/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `input` | "/scratch/peter50504/ACE/data/input/goamazon314_88aces.nc" |
| `duration_seconds` | 28800 |
| `dt_seconds` | 6 |
| `dz_m` | 100 |
| `bubble_K` | 0.25 |
| `initial_MF` | 0 |
| `short_absolute_limits` | [1e-09,1e-07,1e-11] |
| `threads` | 32 |
| `flags` | ["-cpp","-O2","-ffree-form","-ffree-line-length-none","-fdefault-real-8","-fdefault-double-8","-fopenmp"] |

**[migration_work/v02187_validation/threads32/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/threads32/nonzero_mf_h0v0/configuration.json)**

原檔SHA-256：`42eac8ac4dbf40e4ab400064eaf63a8e15516159a36093dccb8a88b9342c59df`。完整附件key：`records["migration_work/v02187_validation/threads32/nonzero_mf_h0v0/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "none" |
| `pulse` | true |

**[migration_work/v02187_validation/threads32/smoke/configuration.json](../../migration_work/v02187_validation/threads32/smoke/configuration.json)**

原檔SHA-256：`93e3c9ca0c36c4e8f7a46052a42b6a10e02c369d1448ed26232f70ed9cf885ce`。完整附件key：`records["migration_work/v02187_validation/threads32/smoke/configuration.json"].data`。

| 原欄位 | 記錄值 |
| --- | --- |
| `duration_seconds` | 6 |
| `physics` | "native" |
| `pulse` | false |

本目錄所有JSON紀錄（含巢狀子測試）：

- [basis_thread_comparison.json](../../migration_work/v02187_validation/basis_thread_comparison.json)
- [corrected_momentum_comparison.json](../../migration_work/v02187_validation/corrected_momentum_comparison.json)
- [corrected_old_case_regression.json](../../migration_work/v02187_validation/corrected_old_case_regression.json)
- [input_results.json](../../migration_work/v02187_validation/input_results.json)
- [matlab_optimization_review.json](../../migration_work/v02187_validation/matlab_optimization_review.json)
- [momentum_unit_review.json](../../migration_work/v02187_validation/momentum_unit_review.json)
- [old_case_regression.json](../../migration_work/v02187_validation/old_case_regression.json)
- [preservation_checks.json](../../migration_work/v02187_validation/preservation_checks.json)
- [production_matlab_smoke.json](../../migration_work/v02187_validation/production_matlab_smoke.json)
- [production_one_step_comparison.json](../../migration_work/v02187_validation/production_one_step_comparison.json)
- [repack_results.json](../../migration_work/v02187_validation/repack_results.json)
- [basis_blocks32/results.json](../../migration_work/v02187_validation/basis_blocks32/results.json)
- [basis_matrix32/results.json](../../migration_work/v02187_validation/basis_matrix32/results.json)
- [basis_packed16_paired32/results.json](../../migration_work/v02187_validation/basis_packed16_paired32/results.json)
- [basis_threads_16/results.json](../../migration_work/v02187_validation/basis_threads_16/results.json)
- [basis_threads_32/results.json](../../migration_work/v02187_validation/basis_threads_32/results.json)
- [basis_threads_8/results.json](../../migration_work/v02187_validation/basis_threads_8/results.json)
- [basis_threads_extended/configuration.json](../../migration_work/v02187_validation/basis_threads_extended/configuration.json)
- [basis_threads_extended/results.json](../../migration_work/v02187_validation/basis_threads_extended/results.json)
- [basis_threads_extended/status.json](../../migration_work/v02187_validation/basis_threads_extended/status.json)
- [basis_threads_extended/00_default/results.json](../../migration_work/v02187_validation/basis_threads_extended/00_default/results.json)
- [basis_threads_extended/01_64/results.json](../../migration_work/v02187_validation/basis_threads_extended/01_64/results.json)
- [basis_threads_extended/02_32/results.json](../../migration_work/v02187_validation/basis_threads_extended/02_32/results.json)
- [basis_threads_extended/03_80/results.json](../../migration_work/v02187_validation/basis_threads_extended/03_80/results.json)
- [basis_threads_extended/04_80/results.json](../../migration_work/v02187_validation/basis_threads_extended/04_80/results.json)
- [basis_threads_extended/05_32/results.json](../../migration_work/v02187_validation/basis_threads_extended/05_32/results.json)
- [basis_threads_extended/06_64/results.json](../../migration_work/v02187_validation/basis_threads_extended/06_64/results.json)
- [basis_threads_extended/07_default/results.json](../../migration_work/v02187_validation/basis_threads_extended/07_default/results.json)
- [basis_threads_inherited/results.json](../../migration_work/v02187_validation/basis_threads_inherited/results.json)
- [build32/results.json](../../migration_work/v02187_validation/build32/results.json)
- [gates/component_results.json](../../migration_work/v02187_validation/gates/component_results.json)
- [gates/configuration.json](../../migration_work/v02187_validation/gates/configuration.json)
- [gates/launch.json](../../migration_work/v02187_validation/gates/launch.json)
- [gates/status.json](../../migration_work/v02187_validation/gates/status.json)
- [gates/smoke/configuration.json](../../migration_work/v02187_validation/gates/smoke/configuration.json)
- [guards/guard_results.json](../../migration_work/v02187_validation/guards/guard_results.json)
- [layout_timing/results.json](../../migration_work/v02187_validation/layout_timing/results.json)
- [matlab_basis_kernel_default/results.json](../../migration_work/v02187_validation/matlab_basis_kernel_default/results.json)
- [matlab_default_fortran32/audit_results.json](../../migration_work/v02187_validation/matlab_default_fortran32/audit_results.json)
- [matlab_default_fortran32/component_results.json](../../migration_work/v02187_validation/matlab_default_fortran32/component_results.json)
- [matlab_default_fortran32/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/configuration.json)
- [matlab_default_fortran32/launch.json](../../migration_work/v02187_validation/matlab_default_fortran32/launch.json)
- [matlab_default_fortran32/status.json](../../migration_work/v02187_validation/matlab_default_fortran32/status.json)
- [matlab_default_fortran32/dry_10min/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/dry_10min/configuration.json)
- [matlab_default_fortran32/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v0/configuration.json)
- [matlab_default_fortran32/nonzero_mf_h0v0/results.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v0/results.json)
- [matlab_default_fortran32/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v1/configuration.json)
- [matlab_default_fortran32/nonzero_mf_h0v1/results.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h0v1/results.json)
- [matlab_default_fortran32/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v0/configuration.json)
- [matlab_default_fortran32/nonzero_mf_h1v0/results.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v0/results.json)
- [matlab_default_fortran32/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v1/configuration.json)
- [matlab_default_fortran32/nonzero_mf_h1v1/results.json](../../migration_work/v02187_validation/matlab_default_fortran32/nonzero_mf_h1v1/results.json)
- [matlab_default_fortran32/smoke/configuration.json](../../migration_work/v02187_validation/matlab_default_fortran32/smoke/configuration.json)
- [matlab_default_fortran32/smoke/results.json](../../migration_work/v02187_validation/matlab_default_fortran32/smoke/results.json)
- [matlab_inherited_environment_profile/configuration.json](../../migration_work/v02187_validation/matlab_inherited_environment_profile/configuration.json)
- [matlab_inherited_environment_profile/profile.json](../../migration_work/v02187_validation/matlab_inherited_environment_profile/profile.json)
- [matlab_inherited_environment_profile/results.json](../../migration_work/v02187_validation/matlab_inherited_environment_profile/results.json)
- [matlab_inherited_environment_smoke/configuration.json](../../migration_work/v02187_validation/matlab_inherited_environment_smoke/configuration.json)
- [matlab_inherited_environment_smoke/results.json](../../migration_work/v02187_validation/matlab_inherited_environment_smoke/results.json)
- [native8h_threads32/audit_results.json](../../migration_work/v02187_validation/native8h_threads32/audit_results.json)
- [native8h_threads32/configuration.json](../../migration_work/v02187_validation/native8h_threads32/configuration.json)
- [native8h_threads32/launch.json](../../migration_work/v02187_validation/native8h_threads32/launch.json)
- [native8h_threads32/launch_configuration.json](../../migration_work/v02187_validation/native8h_threads32/launch_configuration.json)
- [native8h_threads32/status.json](../../migration_work/v02187_validation/native8h_threads32/status.json)
- [native8h_threads32/summary.json](../../migration_work/v02187_validation/native8h_threads32/summary.json)
- [native8h_threads32/native_8h/configuration.json](../../migration_work/v02187_validation/native8h_threads32/native_8h/configuration.json)
- [native8h_threads32/native_8h/results.json](../../migration_work/v02187_validation/native8h_threads32/native_8h/results.json)
- [native8h_threads32/native_8h/gravity_wave_png/scope.json](../../migration_work/v02187_validation/native8h_threads32/native_8h/gravity_wave_png/scope.json)
- [native_units/audit_results.json](../../migration_work/v02187_validation/native_units/audit_results.json)
- [native_units/component_results.json](../../migration_work/v02187_validation/native_units/component_results.json)
- [native_units/configuration.json](../../migration_work/v02187_validation/native_units/configuration.json)
- [native_units/launch.json](../../migration_work/v02187_validation/native_units/launch.json)
- [native_units/performance_observation.json](../../migration_work/v02187_validation/native_units/performance_observation.json)
- [native_units/status.json](../../migration_work/v02187_validation/native_units/status.json)
- [native_units/dry_10min/configuration.json](../../migration_work/v02187_validation/native_units/dry_10min/configuration.json)
- [native_units/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v0/configuration.json)
- [native_units/nonzero_mf_h0v0/results.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v0/results.json)
- [native_units/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v1/configuration.json)
- [native_units/nonzero_mf_h0v1/results.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h0v1/results.json)
- [native_units/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v0/configuration.json)
- [native_units/nonzero_mf_h1v0/results.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v0/results.json)
- [native_units/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v1/configuration.json)
- [native_units/nonzero_mf_h1v1/results.json](../../migration_work/v02187_validation/native_units/nonzero_mf_h1v1/results.json)
- [native_units/smoke/configuration.json](../../migration_work/v02187_validation/native_units/smoke/configuration.json)
- [native_units/smoke/results.json](../../migration_work/v02187_validation/native_units/smoke/results.json)
- [p3_smoke/results.json](../../migration_work/v02187_validation/p3_smoke/results.json)
- [packed_build32/results.json](../../migration_work/v02187_validation/packed_build32/results.json)
- [packed_momentum/audit_results.json](../../migration_work/v02187_validation/packed_momentum/audit_results.json)
- [packed_momentum/component_results.json](../../migration_work/v02187_validation/packed_momentum/component_results.json)
- [packed_momentum/configuration.json](../../migration_work/v02187_validation/packed_momentum/configuration.json)
- [packed_momentum/launch.json](../../migration_work/v02187_validation/packed_momentum/launch.json)
- [packed_momentum/layout_preservation.json](../../migration_work/v02187_validation/packed_momentum/layout_preservation.json)
- [packed_momentum/prefix_preservation.json](../../migration_work/v02187_validation/packed_momentum/prefix_preservation.json)
- [packed_momentum/status.json](../../migration_work/v02187_validation/packed_momentum/status.json)
- [packed_momentum/timestep_results.json](../../migration_work/v02187_validation/packed_momentum/timestep_results.json)
- [packed_momentum/dry_10min/configuration.json](../../migration_work/v02187_validation/packed_momentum/dry_10min/configuration.json)
- [packed_momentum/dry_10min/fortran_audit.json](../../migration_work/v02187_validation/packed_momentum/dry_10min/fortran_audit.json)
- [packed_momentum/dry_10min/results.json](../../migration_work/v02187_validation/packed_momentum/dry_10min/results.json)
- [packed_momentum/dry_10min/figures/scope.json](../../migration_work/v02187_validation/packed_momentum/dry_10min/figures/scope.json)
- [packed_momentum/dt_1p5/configuration.json](../../migration_work/v02187_validation/packed_momentum/dt_1p5/configuration.json)
- [packed_momentum/dt_1p5/results.json](../../migration_work/v02187_validation/packed_momentum/dt_1p5/results.json)
- [packed_momentum/dt_3/configuration.json](../../migration_work/v02187_validation/packed_momentum/dt_3/configuration.json)
- [packed_momentum/dt_3/results.json](../../migration_work/v02187_validation/packed_momentum/dt_3/results.json)
- [packed_momentum/native_10min/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_10min/configuration.json)
- [packed_momentum/native_10min/results.json](../../migration_work/v02187_validation/packed_momentum/native_10min/results.json)
- [packed_momentum/native_10min/figures/scope.json](../../migration_work/v02187_validation/packed_momentum/native_10min/figures/scope.json)
- [packed_momentum/native_1h/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_1h/configuration.json)
- [packed_momentum/native_1h/results.json](../../migration_work/v02187_validation/packed_momentum/native_1h/results.json)
- [packed_momentum/native_8h/configuration.json](../../migration_work/v02187_validation/packed_momentum/native_8h/configuration.json)
- [packed_momentum/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v0/configuration.json)
- [packed_momentum/nonzero_mf_h0v0/results.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v0/results.json)
- [packed_momentum/nonzero_mf_h0v1/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v1/configuration.json)
- [packed_momentum/nonzero_mf_h0v1/results.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h0v1/results.json)
- [packed_momentum/nonzero_mf_h1v0/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v0/configuration.json)
- [packed_momentum/nonzero_mf_h1v0/results.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v0/results.json)
- [packed_momentum/nonzero_mf_h1v1/configuration.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v1/configuration.json)
- [packed_momentum/nonzero_mf_h1v1/results.json](../../migration_work/v02187_validation/packed_momentum/nonzero_mf_h1v1/results.json)
- [packed_momentum/smoke/configuration.json](../../migration_work/v02187_validation/packed_momentum/smoke/configuration.json)
- [packed_momentum/smoke/results.json](../../migration_work/v02187_validation/packed_momentum/smoke/results.json)
- [packed_support/results.json](../../migration_work/v02187_validation/packed_support/results.json)
- [parallel32_10min_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/configuration.json)
- [parallel32_10min_1h/launch.json](../../migration_work/v02187_validation/parallel32_10min_1h/launch.json)
- [parallel32_10min_1h/results.json](../../migration_work/v02187_validation/parallel32_10min_1h/results.json)
- [parallel32_10min_1h/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/status.json)
- [parallel32_10min_1h/native_10min/audit_results.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/audit_results.json)
- [parallel32_10min_1h/native_10min/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/configuration.json)
- [parallel32_10min_1h/native_10min/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/status.json)
- [parallel32_10min_1h/native_10min/native_10min/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/configuration.json)
- [parallel32_10min_1h/native_10min/native_10min/results.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/results.json)
- [parallel32_10min_1h/native_10min/native_10min/thread_comparison.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_10min/native_10min/thread_comparison.json)
- [parallel32_10min_1h/native_1h/audit_results.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/audit_results.json)
- [parallel32_10min_1h/native_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/configuration.json)
- [parallel32_10min_1h/native_1h/status.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/status.json)
- [parallel32_10min_1h/native_1h/native_1h/configuration.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/native_1h/configuration.json)
- [parallel32_10min_1h/native_1h/native_1h/results.json](../../migration_work/v02187_validation/parallel32_10min_1h/native_1h/native_1h/results.json)
- [threads32/component_results.json](../../migration_work/v02187_validation/threads32/component_results.json)
- [threads32/configuration.json](../../migration_work/v02187_validation/threads32/configuration.json)
- [threads32/launch.json](../../migration_work/v02187_validation/threads32/launch.json)
- [threads32/status.json](../../migration_work/v02187_validation/threads32/status.json)
- [threads32/nonzero_mf_h0v0/configuration.json](../../migration_work/v02187_validation/threads32/nonzero_mf_h0v0/configuration.json)
- [threads32/smoke/configuration.json](../../migration_work/v02187_validation/threads32/smoke/configuration.json)
- [threads32/smoke/results.json](../../migration_work/v02187_validation/threads32/smoke/results.json)

</details>

## 9. 重跑與保留規則

先按原configuration提供matching input、lookup、seed、compiler、thread與source snapshot，再使用該版本runner或已保存executed runner；不要直接以目前default覆蓋舊設定。
長run與回歸比較先完成其short gates；重跑應用全新workspace，避免覆寫原證據。此輪是盤點，不因現有紀錄曾寫「launch」而自動啟動任何模型。
39份舊敘述文件已整併並移除原路徑，references已更新；PDF仍保留。若之後批准刪除PDF，需更新references與manifest；如果刪除原始run，必須另外決定放棄哪些replay能力。保留hash並不能重建缺失的binary reference。
