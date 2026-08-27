---
id: PROP-001
title: "交付形態與發布通路：關閉 App Sandbox，改走 Developer ID"
status: confirmed
source: development
proposed_by: saas-tech-selection 訪談
proposed_date: "2026-08-26"
confirmed_date: "2026-08-26"
target_version: null
priority: P0

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: []
supersedes: null
---

# PROP-001: 交付形態與發布通路：關閉 App Sandbox，改走 Developer ID

## 需求來源

`saas-tech-selection` 訪談的 Stage 0 定錨與交付形態 gate。

專案初期曾裁示「之後要上架 Mac App Store」，並依該前提實作了 App Sandbox
與 security-scoped bookmark。後續訪談釐清本 App 的性質為「claude 框架的配套
開發者工具，設計給所有使用該框架的專案」後，該前提被重新檢視並推翻。

## 問題描述

本 App 需要兩項 App Sandbox 禁止的能力：

1. **執行專案內的 doc CLI** —— 框架的文件工具鏈以 Python CLI 形式提供
2. **讀取使用者指定的任意專案資料夾** —— 且不應要求每次啟動重新授權

沙盒下這兩項皆不可行。沙盒與上架是綁定的（App Store 要求沙盒），因此
「是否上架」實質上決定的是「App 有沒有這兩項能力」，而非單純的通路偏好。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | 工作資料夾存取、未來的 doc CLI 呼叫層 |
| 檔案 | `macos/Runner/*.entitlements`、`macos/Runner/MainFlutterWindow.swift`、`lib/workspace/workspace_repository.dart` |
| 用例 | 無直接對應的 UC——本提案定的是交付形態與能力邊界，不是使用者操作。它使 UC-01 的「選擇任意資料夾」與（尚未落檔的）「呼叫 doc CLI 驗證」成為可能 |

## 範圍界定

### 本提案要做的（In Scope）

- 兩份 entitlements 的 `com.apple.security.app-sandbox` 明確設為 `false`
- 移除沙盒專屬 entitlements（`files.user-selected.read-write`、
  `files.bookmarks.app-scope`、`network.client`）
- 保留 Hardened Runtime 所需的 debug 專屬項（`cs.allow-jit`、`network.server`）
- 契約測試斷言 sandbox 維持關閉

### 本提案不做的（Out of Scope）

- notarization 的實際簽署與公證流程 → 屬發布階段工作，另立提案
- 自動更新機制（Sparkle 等） → 有實際發布需求時再評估
- 雙 build（MAS 版 + 直接發布版） → 維護成本高於收益，需要時另立提案

## 提案方案

### 方案比較

| 面向 | A. 維持 MAS + 沙盒 | B. 直接發布 + 關閉沙盒 |
|------|------------------|---------------------|
| 執行 doc CLI | 不可能 | 可以 |
| 讀取任意資料夾 | 需 security-scoped bookmark | 直接可讀 |
| 取得方式 | App Store 搜尋 | dmg 或 brew |
| 審查 | 每次更新皆需 | 僅 notarization（自動） |
| 適合對象 | 一般消費者 | 開發者工具 |

### 建議方案

**方案 B。**

實測證據（本專案的沙盒化 macOS app 內執行 `Process.run`）：

| 目標 | 沙盒開啟 | 沙盒關閉 |
|------|---------|---------|
| `/bin/echo` | `exit=0` | `exit=0` |
| `/usr/bin/python3` | `xcrun: error: cannot be used within an App Sandbox.` | `exit=0`（Python 3.9.6） |
| 使用者安裝的 `uv` | `ProcessException: Operation not permitted` | `exit=0`（uv 0.8.13） |
| 讀取任意專案資料夾 | 需 bookmark | `exit=0` |

三項的失敗方式各不相同，具診斷價值：`echo` 成功證明 `Process` API 未被禁用；
`python3` 是被工具鏈自身拒絕（xcrun shim 主動檢查沙盒）；`uv` 是被核心沙盒
策略擋下。要繞過需同時解決兩種不同層級的阻擋，不存在單一開關。

另有獨立於沙盒的第二道阻擋：**App Store 審查指南 2.5.2** 要求 app 自包含、
不得下載或執行改變 app 功能的程式碼，明文涵蓋由內建 runtime 執行的直譯式
程式碼（含 Python）。doc CLI 位於使用者選取的資料夾內，即使打包直譯器，
執行的仍是審查時看不到的使用者程式碼。

## 驗收條件

- [x] 兩份 entitlements 的 `app-sandbox` 為 `false`，且 `plutil -lint` 通過
- [x] 沙盒專屬 entitlements 已移除
- [x] `cs.allow-jit` 與 `network.server` 僅出現於 Debug
- [x] `test/entitlements_contract_test.dart` 斷言 sandbox 關閉，且該測試在
      sandbox 被重新開啟時會失敗
- [x] 實測 `Process.run` 可執行 `python3` 與使用者安裝的 `uv`
- [x] 實測可直接讀取專案外的資料夾

## 風險與 Tripwire

**風險**：sandbox 被重新開啟時，`Process.run` 會靜默失去執行 CLI 的能力 ——
無編譯錯誤、無 lint 警告，整合測試亦全綠（bookmark 往返在兩種模式下皆可通過）。
契約測試即為此設計。

**Tripwire**：若未來決定上架 Mac App Store → 回頭重評本提案，屆時必須放棄
doc CLI 呼叫能力，並重新引入 security-scoped bookmark（見 PROP-003）。
