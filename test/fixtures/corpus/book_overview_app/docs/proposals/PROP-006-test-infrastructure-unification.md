---
id: PROP-006
title: "Widget 測試規範化與測試指南"
status: approved
source: "W7-001 Legacy Code 驗證教訓"
proposed_by: "W7-001 四視角審查（Consistency + Impact + linux + parsley）"
proposed_date: "2026-03-31"
confirmed_date: null
target_version: null
priority: P1

outputs:
  spec_refs: []
  usecase_refs: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07]
  ticket_refs: [0.31.1-W8-001]

related_proposals: [PROP-004]
supersedes: null
---

# PROP-006: Widget 測試規範化與測試指南

## 需求來源

0.31.1-W7-001 Legacy Code 驗證過程中，6 個 UC 的測試反覆出現相同類型的系統性問題。

## 根因分析（四視角審查結論）

### W7-001 反覆出現的問題

1. **Widget 類型斷言錯誤**：測試用 `AlertDialog` 但實作用 `Dialog`，用 `TextButton` 但實作用 `AppButton`（UC-03, UC-06, UC-07）
2. **l10n 上下文缺失**：Widget 測試未配置 `AppLocalizations.delegate`（UC-07）
3. **ScreenUtil 初始化不一致**：部分測試未用 `WidgetTestHelper`（UC-06）
4. **Mock 不完整**：`MockAppLocalizations` 缺少 `importProgress(int)` 等方法（UC-01）
5. **整合測試缺失**：複雜模組（133+ 檔案）無整合測試（UC-05）

### 根因診斷

| 問題 | 初始歸因 | 真正根因 | 來源 |
|------|---------|---------|------|
| Widget 類型斷言錯誤 | 基礎設施不足 | 代理人不知道 AppButton 等自訂元件存在 | linux + parsley 視角 |
| l10n 上下文缺失 | Widget 測試規範化 | 代理人不知道要加 delegate | linux + parsley 視角 |
| ScreenUtil 初始化不一致 | WidgetTestHelper 採用率低 | 代理人不知道 Helper 存在 | linux + parsley 視角 |
| Mock 不完整 | Mock 審計 | `createFullTestApp()` 已提供 real delegates，多數場景不需要 Mock l10n | parsley 視角 |

**核心結論**：五個問題中有三個的根因是「代理人知識不足」，而非「基礎設施缺陷」。代理人知識已在 commit 4bbcf18f 更新。剩下的問題是讓 `createFullTestApp()` 成為阻力最小的路徑。

## 提案方案（審查後精簡版）

### 工作項 1：Widget 測試統一（核心）

**目標**：讓 `createFullTestApp()` 成為所有 Widget 測試的標準入口，直接解決 80%+ 的 W7-001 失敗類型。

**具體步驟**：
1. 為 `createFullTestApp()` 新增 `overrides` 參數支援 Provider 注入
2. 審計未使用 Helper 的 Widget 測試，區分「需要遷移」和「有特殊需求」
3. 遷移需要 l10n/ScreenUtil 的測試到 Helper
4. 全量回歸驗證

**設計決策**：
- 使用 real `AppLocalizations` delegates 而非 Mock，消除 MockAppLocalizations 依賴
- 有特殊 Provider override 需求的測試使用 `createFullTestApp(overrides: [...])`
- 不強制「採用率 80%」，而是「所有需要 l10n/ScreenUtil 的 Widget 測試都正確初始化」

### 工作項 2：測試撰寫指南（輔助）

**目標**：1 頁 `test/README.md`，讓代理人寫測試時有明確的參考。

**內容**：
- 專案自訂元件清單（AppButton、AppDialog 等 7 個元件）
- canonical test pattern：使用 `createFullTestApp()` 的標準範例
- fixture 使用方式：何時用哪個 fixture
- 常見陷阱：W7-001 教訓摘要

## 審查過程中被否決的方案

### 初版方案（6 票 → 精簡為 2 項工作）

| 原方案 | 否決原因 | 審查視角 |
|--------|---------|---------|
| T1: re-export hub | Dart IDE auto-import 已解決 discovery，barrel file 是維護負擔 | linux + parsley |
| T2: 擴展 fixture 場景 | 按需做即可，不需要專門票 | linux + parsley |
| T3: 1089 處 Book 建立替換（6 子票） | 測試全部通過，分散建立是美觀問題不是缺陷原因 | linux + parsley |
| T4: MockAppLocalizations 全量補齊 | 6.6x 成本換 <5% 改善 | Impact（初版即否決） |
| T5: 33 個 Mock 全量審計 | `createFullTestApp()` 的 real delegates 取代多數 Mock 需求 | parsley |
| T6: AppWidgetFinder 工具類 | 僅 19 處使用，不值得新抽象 | Impact（初版即否決） |
| T8: 全量回歸驗證獨立票 | 是基本動作，併入工作項 1 | linux + parsley |

### 否決的核心理由

> 「測試全部通過。基礎設施能用。問題是人不知道怎麼用。教人用比重建基礎設施便宜 100 倍。」—— linux 視角

> 「W7-001 測試失敗的原因從來不是『test Book 有錯誤的 ISBN 格式』或『不一致的測試資料』，而是 Widget 類型斷言錯誤和缺少 l10n setup。」—— parsley 視角

## 風險評估

| 風險 | 等級 | 緩解措施 |
|------|------|---------|
| 遷移損失特殊初始化 | 中 | 先審計再替換，有特殊需求的保留原模式 |
| 測試回歸 | 低 | 每批遷移後跑全量測試 |

## 量化指標

| 指標 | 當前值 | 目標值 |
|------|--------|--------|
| 需要 l10n/ScreenUtil 的 Widget 測試正確使用 Helper | 未量測 | 100% |
| 測試通過率 | 100% | 維持 100% |
| test/README.md | 不存在 | 建立 |
