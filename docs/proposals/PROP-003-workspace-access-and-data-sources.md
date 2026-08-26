---
id: PROP-003
title: "工作資料夾存取與資料來源範圍"
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

related_proposals: [PROP-001]
supersedes: null
---

# PROP-003: 工作資料夾存取與資料來源範圍

## 需求來源

本 App 為框架的配套工具，需在多個使用該框架的專案之間切換檢視。
專案本身不做同步 —— 多機同步由框架的 ticket 系統與 GitHub 承擔。

## 問題描述

兩個子問題：

1. **如何記住使用者選定的資料夾**，使其跨 App 啟動仍有效
2. **要讀取該資料夾內的哪些內容**

第一點原本依賴 security-scoped bookmark（沙盒下的唯一解），但 PROP-001 關閉
沙盒後該機制已非必要。第二點決定解析器的範圍與效能特性。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | 工作資料夾管理、檔案監看、解析器 |
| 檔案 | `lib/workspace/workspace_repository.dart`、`macos/Runner/MainFlutterWindow.swift` |
| 用例 | 「選擇／切換專案資料夾」、所有依賴專案資料的檢視 |

## 範圍界定

### 本提案要做的（In Scope）

- 以路徑字串保存工作資料夾，每次取用時實際確認可用性
- 資料來源涵蓋：`docs/` 圖譜節點 frontmatter、`docs/work-logs/**/tickets/*.md`、
  `docs/traceability.yaml`
- 外部改動採自動偵測並重新載入（file watcher）
- 資料夾不可用時（刪除、改名、磁碟未掛載）明確回報，並保留最後已知路徑供提示

### 本提案不做的（Out of Scope）

- security-scoped bookmark → 沙盒已關閉，機制冗餘；上架 MAS 時需重新引入
- 跨機器同步 → 由框架的 ticket 系統與 GitHub 承擔，非本 App 職責
- **git 歷史（邊的變更歷史）** → 非核心價值，成本為 O(commits × files)，
  另立提案處理
- 同時開啟多個專案 → 一次一個，切換即重新載入

## 提案方案

### 資料夾存取：路徑字串

沙盒關閉後，路徑字串即足以跨啟動存取。與 security-scoped bookmark 的取捨：

| 面向 | 路徑字串 | security-scoped bookmark |
|------|---------|------------------------|
| 追蹤對象 | 路徑 | 檔案系統節點 |
| 資料夾被搬移 | 失效，需重選 | 自動跟隨 |
| 實作成本 | 無 | 約 300 行含原生層 |
| 沙盒需求 | 不需要 | 沙盒下的唯一解 |

對開發者工具而言，專案資料夾被搬移時讓使用者重選一次是可接受的。
既有的 bookmark 實作已移除。

**路徑字串會過期**，因此每次取用皆實際確認資料夾存在且可讀，不假設存下即長期有效。

### 資料來源與規模

| 來源 | 用途 | 規模參考（flutter_balance） |
|------|------|------------------------|
| `docs/` 圖譜節點 frontmatter | PROP / SPEC / UC / EVT / DomainBundle | PROP 2、SPEC 4、UC 1、EVT 5 |
| `docs/work-logs/**/tickets/*.md` | 進度與狀態 | **1295 張** |
| `docs/traceability.yaml` | 四軸追溯矩陣，已結構化 | 1 檔 |

Ticket 為主要的效能熱點。**1295 為全量，非 pending 數（約 190）** —— 兩者
相差近 7 倍，換頁與虛擬捲動的壓力測試須以全量為準。

其他可用語料：`book_overview_app`、`book_overview_v1`（框架版本較舊、
文件缺欄位，適合驗證解析寬容度）、`monitor`、`screen_clock`（擱置中）。

## 驗收條件

- [x] 工作資料夾以路徑字串保存並可跨啟動還原
- [x] 資料夾不存在或不可讀時回報明確原因並保留最後已知路徑
- [x] security-scoped bookmark 實作已移除
- [ ] 解析器可讀取三類資料來源
- [ ] 外部改動可被偵測並觸發重新載入
- [ ] 以 1295 張 ticket 的規模驗證清單效能

## 風險與 Tripwire

**風險**：舊框架版本的專案（如 `book_overview_v1`）文件缺少必要欄位。
解析器須寬容並給出明確錯誤，而非崩潰或靜默略過。

**Tripwire**：若未來決定上架 Mac App Store → 路徑字串不再足夠，
需重新引入 security-scoped bookmark（實作可自 git 歷史取回）。
