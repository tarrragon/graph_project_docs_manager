---
id: PROP-013
title: 元件庫統一化（Extension 端）——ui-factory 升級為核心元件庫並對齊 APP 命名契約
status: confirmed
evaluation_level: standard
created: "2026-07-08"
confirmed_date: "2026-07-11"
target_version: v1.5.0
priority: P2
related_proposals: [PROP-007, PROP-008]
---

# PROP-013: 元件庫統一化（Extension 端）——ui-factory 升級為核心元件庫並對齊 APP 命名契約

> **Sibling 提案**：APP 端 `book_overview_app/docs/proposals/PROP-016-component-library-unification.md`。
> 命名契約 SSOT：APP 端 `docs/spec/design-system-spec.md`「元件庫章節 + 跨平台元件對照表」（PROP-016 工作項 5 產出），延續 PROP-008「從 APP 移植」的既有 reference 方向。

## 需求來源

雙專案同步開發。APP 端於 v0.37.0 完成 design token 參數集中後，PROP-016 提案補完元件層（AppButton/AppDivider 等統一元件、禁止散落自製）。用戶要求 Extension 端同步建立相同的元件庫，共有元件（按鈕、框線/分隔線等）使用相同命名和樣式。

## 問題描述

PROP-008 已完成 token 層移植（`src/core/design-system/` colors/spacing/typography/shadows + design-system.css），但元件層停留在局部方案：

1. **元件工廠只覆蓋 popup**：`src/popup/components/ui-factory.js`（createButton 等純函式）僅供 popup 使用，其 class 名綁定 popup.html 內嵌 `<style>`，overview 等其他 UI 面無法複用。
2. **樣式仍散落**：popup.html 內嵌約 36 條 CSS class 規則（未收斂進 design-system.css）；overview.css 有 10 處 design-system 外的 `border:` 宣告；2 處 `createElement('button')` 繞過工廠直建。
3. **雙端命名無契約**：ui-factory 的 variant（primary/secondary/danger）與 APP 端 AppButton、spec §4 語意化按鈕系統（五種類型）尚未正式對照，各自演化將重蹈 token 曾經散落的覆轍。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `src/core/`（新增元件庫目錄）、`src/popup/`（ui-factory 遷移 + popup.html 樣式收斂）、`src/overview/`（border 收斂） |
| 檔案 | ui-factory.js（升級搬遷）、popup.html（內嵌 style ~36 條）、overview.css（border: 10 處）、createElement('button') 直建 2 處 |
| 測試 | ui-factory 既有 jsdom 測試連動（import 路徑 + class 名斷言） |
| 規格 | 引用 APP 端 design-system-spec 元件庫章節作為命名契約，不在本 repo 另建 SSOT |

## 範圍界定

### 本提案要做的（In Scope）

1. **元件庫升格**：ui-factory 從 `src/popup/components/` 升遷至核心目錄（如 `src/core/ui/components/`，命名依 JS 連字號慣例），成為全 Extension 共用元件庫；popup / overview 統一引用。
2. **命名契約對齊**：元件語意名、variant/size 命名、引用 token 依 APP 端 spec 跨平台元件對照表對齊（等 PROP-016 工作項 5 產出後執行；按鈕 variant 對齊 spec §4 五種語意類型）。
3. **補框線/分隔線元件**：依 spec §8.2「分割陰影取代分隔線」新增 divider 元件（subtle/normal/strong 三變體，與 APP 端 AppDivider 同命名同 token），收斂 overview.css 10 處 border 宣告中屬分隔語意者。
4. **樣式收斂**：popup.html 內嵌 style 遷入 design-system.css 或元件層級 CSS；消除 2 處 createElement('button') 直建。
5. **測試同步**：ui-factory 既有測試隨搬遷修正，新元件補測試。

### 本提案不做的（Out of Scope）

- APP 端任何改動 → PROP-016（APP repo）承擔
- 命名契約的制定 → SSOT 在 APP 端 spec，本提案只消費不制定；契約內容有異議時回 PROP-016 討論
- token 值變更 → PROP-008 既有範圍，本提案元件一律引用既有 token
- overview/popup 的功能性重構 → 僅樣式與元件收斂，不動行為邏輯

## 提案方案

依 APP 端 PROP-016 同款「補元件 + 存量遷移 + 防新增」策略，但 Extension 端散落量小（~50 個收斂點 vs APP 端 ~120），可單 wave 完成。技術形態差異：Flutter 是 Widget 類別（AppButton），Extension 是 DOM 工廠函式（createButton）——**對齊的是語意層（元件名、variant 名、token 引用），不是 API 形狀**，此邊界寫入命名契約。

## 驗收條件

- [ ] 核心元件庫目錄存在，popup 與 overview 皆引用同一元件庫——對應「要做」1
- [ ] 元件命名與 APP spec 跨平台元件對照表一致（逐項核對）——對應「要做」2
- [ ] divider 元件存在且以分割陰影實作；overview.css 分隔語意 border 已收斂——對應「要做」3
- [ ] popup.html 無內嵌 style class 規則；`createElement('button')` 直建為 0（豁免除外）——對應「要做」4
- [ ] 既有測試全數通過，新元件有對應測試——對應「要做」5

## Reality Test / 觸發案例實證

### 觸發案例

2026-07-08 盤點：ui-factory.js 僅 4 檔引用（全在 popup）；popup.html 內嵌約 36 條 CSS 規則；overview.css 有 10 處 design-system 外 `border:`；2 處 `createElement('button')` 繞過工廠。APP 端同日盤點發現同構問題（PROP-016 Reality Test）。

### 假設列舉與驗證

| 假設 | 驗證方式 | 結果 |
|------|---------|------|
| 假設 1：token 層足以支撐元件實作 | 檢查 `src/core/design-system/` 內容 | 已驗證：colors/spacing/typography/shadows + CSS variables 已落地（PROP-008） |
| 假設 2：ui-factory 模式可推廣至 overview | 檢視 ui-factory 是否耦合 popup 專屬邏輯 | 部分驗證：純函式無狀態設計可搬遷，但 class 名綁定 popup.html 內嵌 style，需先做樣式收斂（工作項 4 為工作項 1 前置） |
| 假設 3：雙端 variant 語意可完全對照 | 比對 ui-factory 3 variants vs spec §4 五類型 | 未驗證：差集（2 個類型）是否 Extension 需要，待命名契約制定時決定 |

## 替代方案

| 方案 | 說明 | 評估 |
|------|------|------|
| A：本提案（元件庫升格 + 命名契約對齊） | ui-factory 升遷核心目錄，雙端命名對齊，散落樣式收斂 | 採用 — 根治散落、雙端一致 |
| B：維持現狀，僅文件規範 | 不搬遷 ui-factory，以文件約定命名規範 | 否決 — PROP-008 已證實「文件規範 vs 工具預設」，工具預設總是贏（opinionated-default 原則）；token 曾散落 89+ 處即為此模式失敗案例 |

## 機會成本

本提案佔用約 1 wave 工時。同期可做的替代項：v1.5.0 多書城適配器開發。權衡：元件層不對齊的技術債會在每個新書城適配器中累積（每新增一個書城 UI 面就多一輪散落），先收斂再擴展書城可避免 N 倍返工。

## 失敗防護

| 失敗情境 | 防護措施 |
|---------|---------|
| popup.html 樣式遷移後視覺回歸 | 遷移前後截圖比對；class 名保持不變只搬位置；測試含 DOM 結構驗證 |
| APP PROP-016 命名契約延遲產出，工作項 2/3 阻塞過久 | 工作項 1/4/5 無外部依賴可先行；命名契約延遲不阻塞本提案整體進度 |
| ui-factory 搬遷破壞既有 import 路徑 | 搬遷 ticket 含全量 grep 引用修正 + 測試修正；TDD 流程保證紅燈即停 |

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| 命名契約未產出前先行實作 | 返工 | 工作項 2/3 依賴 APP PROP-016 spec 增補完成；工作項 4（樣式收斂）無依賴可先行 |
| popup.html 樣式遷移改變渲染 | popup 視覺回歸 | 遷移前後截圖比對；class 名保持不變只搬位置 |
| ui-factory 搬遷破壞既有 import | 測試紅燈 | 搬遷 ticket 含全量引用 grep 與測試修正 |

## 討論記錄

### 2026-07-08

隨 APP 端 PROP-016 同日建立。決策：命名契約 SSOT 放 APP 端 spec（延續 PROP-008 reference 方向與 PROP-007 跨專案對齊模式）；本提案工作項 2/3 阻塞於 APP 端 spec 增補產出，工作項 4 可先行。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | 1.5.0-W6-001（樣式收斂） | 2026-07-11 | pending |
| Ticket | 1.5.0-W6-002（元件庫升格） | 2026-07-11 | pending |
| Ticket | 1.5.0-W6-003（命名契約對齊） | 2026-07-11 | pending |
| Ticket | 1.5.0-W6-004（divider 元件） | 2026-07-11 | pending |
| Ticket | 1.5.0-W6-005（測試同步） | 2026-07-11 | pending |
