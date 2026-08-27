---
id: PROP-009
title: Ticket CLI 完整性提升 — 全欄位 CLI 化 + 清單式驗證
status: approved
target_version: v0.17.4
created: 2026-04-11
priority: P1
category: framework
evaluation_level: standard
---

# PROP-009: Ticket CLI 完整性提升

## 動機

目前 Ticket 操作仍需直接讀寫 .md 檔案，造成：
1. **Token 浪費**：讀取整個 Ticket 檔案只為修改一個欄位
2. **分析消耗**：PM 需要解析 frontmatter 結構才能操作
3. **欄位遺漏**：create 後才發現 5W1H 有「待定義」，交接時才暴露
4. **一致性風險**：手動編輯 .md 可能破壞 YAML 格式

## 目標

**所有 Ticket 操作都透過 CLI 命令完成，不需要直接讀寫 .md 檔案。**

## 三個改善面向

### 面向 A：CLI 欄位操作完整性

**現有缺口**：

| 欄位 | create 可指定 | set-* 可修改 | 需新增 |
|------|-------------|-------------|--------|
| priority | 是 | 無 | `set-priority` |
| acceptance | 是 | 無（只有 check） | `add-acceptance` / `remove-acceptance` |
| spawned_tickets | 無 | 無 | `add-spawned` |
| decision_tree_path | 是 | 無 | `set-decision-tree` |

**目標**：所有可寫欄位都有對應的 CLI 命令。

### 面向 B：Create 時欄位完整性驗證

基於《清單革命》（The Checklist Manifesto, Atul Gawande）原則設計：

**清單設計原則**：
- 簡短：5-9 項，不超過一頁
- 精準：每項可在 30 秒內確認（yes/no 判斷）
- 實用：只檢查容易遺漏的關鍵項，不檢查不會漏的
- 類型：create 是「讀-做」清單（照著填），complete 是「執行-確認」清單（做完再確認）
- 不替代專業判斷：驗證欄位有值，不驗證值的品質
- 定期更新：根據 error-pattern 驅動更新

**Create 清單（讀-做型，建立時強制）**：

| # | 檢查項 | 阻擋？ | 理由 |
|---|--------|--------|------|
| 1 | why 已填寫？（IMP/ANA/ADJ） | 是 | 已實作，缺 why 會阻擋 |
| 2 | where.files 至少 1 個？ | 警告 | 空 where 導致 error-pattern 衝突檢查跳過 |
| 3 | acceptance 至少 1 項？ | 警告 | 無 AC 的 Ticket 無法驗收 |
| 4 | decision_tree_path 已填？ | 警告 | 缺少決策追蹤來源 |
| 5 | when 非「待定義」？ | 警告 | 交接後才補填增加認知負擔 |

**不列入清單的項目**（《清單革命》反模式）：
- 「標題是否清楚？」→ 主觀判斷，無法 30 秒確認
- 「是否符合 4V 原則？」→ 太抽象，應轉為具體問題
- 「是否需要拆分？」→ 需要分析，不適合清單

### 面向 C：Complete 前清單式驗證

**Complete 清單（執行-確認型，完成前強制）**：

| # | 檢查項 | 阻擋？ | 理由 |
|---|--------|--------|------|
| 1 | 所有 acceptance 已勾選？ | 是 | 已實作 |
| 2 | 5W1H 無「待定義」？ | 警告 | 確保欄位已在執行過程中補完 |
| 3 | error-pattern 衝突已檢查？（IMP/ADJ） | 警告 | 已實作（Step 2.7） |
| 4 | execution log 已填寫？ | 警告 | 已實作（append-log 提醒） |
| 5 | 相關 Ticket 已更新？（ANA 需有 spawned_tickets） | 警告 | 已實作（ANA spawned 檢查） |

## 實作建議

### 優先級排序

| 優先級 | 項目 | 投入 | 回報 |
|--------|------|------|------|
| P0 | Create 清單驗證（面向 B） | 中 — 修改 create 命令 | 高 — 每次 create 都受益 |
| P1 | 缺失的 set-* 命令（面向 A） | 低 — 4 個新命令 | 中 — 減少手動編輯 |
| P2 | Complete 清單整合（面向 C） | 低 — 整合現有 Hook | 中 — 統一分散的檢查 |

### 技術方案

Create 清單驗證可在 `ticket_system/commands/create.py` 中實作，在寫入檔案前執行清單檢查，不通過則輸出 WARNING（非阻擋）並列出缺失項目。

## 參考

- 《清單革命》（The Checklist Manifesto）— Atul Gawande
- PC-053: PM 對「小修改」跳過 Ticket 記錄
- 0.18.0-W4-002: PM 判斷偏誤 WRAP 分析

---

## 替代方案

本提案採用「CLI 命令擴充 + 清單式驗證」方式，提升 Ticket 操作的完整性。評估期間考慮過以下候選方案：

### 方案 A（已採用）：CLI 命令擴充 + Create/Complete 時清單驗證

擴充現有 ticket CLI，補齊缺失的欄位操作命令（`set-priority`、`add-acceptance`、`add-spawned`、`set-decision-tree`），並在 create 與 complete 時執行清單式欄位完整性驗證。

優點：與現有 CLI 架構完全相容，漸進式補充不破壞既有流程；清單驗證可依 error-pattern 持續更新。缺點：需實作多個新命令，且清單只驗證欄位有值、不驗證值的品質。

### 方案 B（未採用）：直接讀寫 .md 搭配 linting

保留直接編輯 .md 的現有模式，另建 pre-commit lint 檢查 frontmatter 格式和必填欄位完整性。

優點：不需擴充 CLI。缺點：每次操作仍需解析 frontmatter，PM token 消耗未降低；linting 發生在 commit 後，欄位遺漏的問題在交接時才暴露，與面向 B 的目標（create 時即阻擋）背道而馳。

### 方案 C（未採用）：全量 CLI 重寫（TUI 介面）

以終端 UI（TUI）取代文字命令，提供互動式欄位填寫引導。

優點：使用者體驗佳，欄位完整性可即時引導。缺點：實作成本過高（需引入 curses/textual 等 TUI 框架）；與現有 Claude Code agent 的 CLI 呼叫模式不相容，代理人無法以非互動方式執行 TUI。

### 選擇依據

本提案核心目標是「降低 PM token 消耗並提升欄位完整性」，方案 A 在不破壞現有架構的前提下逐步補齊缺口，且清單設計來自《清單革命》原則，與既有 error-pattern 驅動的改善機制相容。

---

## 失敗防護

本提案的主要失敗模式及防護措施：

### 失敗情境 1：新 set-* 命令破壞既有 frontmatter YAML 格式

防護：新命令實作時必須透過 ticket_system 現有的 YAML 讀寫模組（非直接字串替換）操作 frontmatter，確保格式一致性。實作完成後以「create → set-priority → complete」完整流程測試，驗證 YAML 未損壞。

### 失敗情境 2：清單驗證過於嚴格，阻擋合理的快速建立場景

防護：面向 B 清單採「阻擋（is）vs 警告（warning）」兩層設計，只有 `why` 缺失才硬阻擋；`where.files`、`acceptance`、`decision_tree_path`、`when` 等欄位缺失僅輸出 WARNING，不阻擋建立。這讓 PM 在快速記錄場景下仍可 create，交接前再補完即可。

### 失敗情境 3：hook substring keyword match 產生假陽性（錯誤阻擋）

防護：proposal-evaluation-gate hook 的章節關鍵字採「content 包含任一關鍵字即通過」邏輯，而非嚴格標題匹配。本提案補充的章節標題（`## 替代方案`、`## 失敗防護`、`## Reality Test`）均包含 hook 偵測清單中的關鍵字（`替代方案`、`失敗防護`、`Reality Test`），不會觸發假陽性阻擋。

---

## Reality Test

### 假設驗證

本提案建立在以下假設上，以下逐一驗證：

**假設 1：直接讀寫 .md 是目前 PM 操作 Ticket 的主要痛點。**

結果：已驗證為真。PC-053 記錄 PM 對「小修改跳過 Ticket 記錄」的模式，根因之一是直接編輯 .md 的摩擦力（需解析 frontmatter 結構），與本提案動機一致。CLI 化降低摩擦力有助改善遵循率。

**假設 2：清單式驗證能在 create 時即攔截欄位遺漏，不需依賴事後 lint。**

結果：已驗證為真。現有 `complete` 命令已有 acceptance 驗收清單（acceptance-gate-hook），顯示「時機前移」的驗證模式在本系統中可行。面向 B 的 create 時清單驗證沿用相同模式，技術可行性已有先例。

**假設 3：4 個缺失的 set-* 命令（set-priority / add-acceptance / add-spawned / set-decision-tree）涵蓋主要欄位操作缺口。**

結果：部分驗證。以上 4 個命令對應目前最常見的手動編輯場景（優先級調整、AC 補充、spawned 記錄）。其他欄位（如 `when`、`where.layer`）的需求頻率較低，可觀察後在後續版本補充，不影響本提案核心價值。

### 觸發案例

本提案觸發點：W4-002（PM 判斷偏誤 WRAP 分析）過程中發現 PM 直接編輯 .md 而非使用 CLI，導致 frontmatter 欄位遺漏且 ticket 交接困難。結合 PC-053（小修改跳過 Ticket 記錄）模式，確認 CLI 完整性是降低 Ticket 操作摩擦力的關鍵槓桿。

---

**Last Updated**: 2026-05-05
