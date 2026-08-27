---
# 提案（Proposal）

id: PROP-018
title: "Design token 值層統一——token manifest 雙向校驗層 + 平台覆蓋機制"
status: draft
source: cross-project
proposed_by: "book_overview_v1 統一強度評估用戶決策（2026-07-11，sibling PROP-014）"
proposed_date: "2026-07-11"
confirmed_date: null
target_version: null                 # PROP-016（v0.38.0）完成後再定，避免與元件庫遷移波次衝突
priority: P2
evaluation_level: heavy              # 跨專案（APP + Extension）

# 轉化產出追蹤
outputs:
  spec_refs: ["docs/spec/design-system-spec.md §14.6 差異標記色值平台校準條目（spec v1.3，0.38.0-W10-001）"]
  usecase_refs: []
  ticket_refs: []

# 關聯
related_proposals: [PROP-016]        # 元件層命名契約（§14.6）由其建立；本提案管 token 值層，兩者正交
supersedes: null
---

# PROP-018: Design token 值層統一——token manifest 雙向校驗層 + 平台覆蓋機制

> **Sibling 提案**：Extension 端 `book_overview_v1/docs/proposals/PROP-014-design-token-value-unification.md`（同日建立，含雙端盤點 Reality Test 全文）。
> **分層**：spec §12/§14.6 markdown 契約管「命名與語意」；本提案管「值的機器可讀單一真實來源」。

## 需求來源

2026-07-11 V1 端統一強度評估，用戶決策：

1. design-system 統一強度採「值層也統一」——token 值需有機器可讀 SSOT，取代 markdown 契約 + 人工 diff。
2. 色值分歧仲裁：V1 primary `#1A56DB`（WCAG AA 校色）vs APP `#2196F3` 屬**平台校準層**，雙端各自維持；以中介格式的 platform overrides 承載，並須補記 §14.6 差異標記。

## 問題描述

1. token 值硬編碼在雙端原生檔（APP `lib/core/design_system/*.dart`、V1 `src/core/design-system/*.js`），無中介格式。
2. 人工同步已實際失效一次：V1 色值校準分歧未入 §14.6 差異標記（差異標記僅記 rsp vs px 單位差異）。
3. token 覆蓋面不對稱（V1 缺 divider 系列、石碑刻痕陰影、xxxl/vertical 間距），漂移無機制偵測。

## 範圍界定

### 本提案要做的（In Scope，APP 端）

> 2026-07-11 更新：V1 端 heavy 評估（ticket 1.5.0-W6-006，linux + thyme 雙視角審查）採**方案 D：token manifest 雙向校驗層**——值仍雙端手寫，機器可讀 manifest 記載雙端對照（token 名 + base 值 + 平台覆蓋 + 理由），CI 雙向校驗使漂移不可能靜默。生成方案（Style Dictionary / 自訂生成器）被否決（實測值變更年約 1 次，複雜度超過問題量級），保留為升級路徑。

> 2026-07-13 實況同步：V1 W6-007/W6-008 **均已完成**——manifest schema v1.0.0 定案、`token-manifest.json` 初版已存在（V1 repo `src/core/design-system/`，含 APP 114 tokens 完整對照：path + value + category 四分類）、V1 端雙向校驗 script 已接入 V1 CI。APP 端工作因此從「等 schema」轉為「複核與消費」。

1. **manifest APP 對照對帳**（文件層，立即可做）：manifest 內 `platforms.app` 的 path/value 由 V1 端 agent 盤點產出，未經 APP 端驗證；須逐項比對 `lib/core/design_system/` 真實檔，差異回報 V1 端修正（ticket 0.38.0-W10-004）。
2. **APP 端校驗機制**（程式層，第二階段）：Dart token 值 vs manifest 的雙向比對 script + APP CI 接線；值仍手寫於 `lib/core/design_system/`，不引入生成。**前置依賴：APP CI Pipeline（1.0.0-W1-001）**——CI 未建前上校驗 script 會退化回「人工記得跑」，即原失效模式。
3. **spec §14.6 差異標記補記**：新增「色值屬平台校準層」條目（primary：APP `#2196F3` / V1 `#1A56DB`，理由 WCAG AA 校色 0.19.1-W3-001）——不依賴 schema，可先行（ticket 0.38.0-W10-001）。
4. token 覆蓋面對帳：manifest `platformOnlyApp` 49 項確認屬平台獨有或應入契約（併入工作項 1 的對帳範圍）。

### 文件先行兩段式定位（2026-07-13，WRAP APP 端分析 + 用戶決策）

雙專案主力維護者皆為 AI agent，用戶決策：**文件規格統一優先於程式碼調整**。方案 D 據此重新定位：

| 階段 | 內容 | 性質 | 前置 |
|------|------|------|------|
| 第一段（文件層） | manifest 本體 = 雙端 AI 讀取 token ground truth 的統一規格文件；§14.6 補記；雙端提案對齊 | 規格文件 | 無（V1 端已完成 manifest） |
| 第二段（程式層） | APP 端比對 script + CI 接線 = 規格的 enforcement 附件 | 工具 | 1.0.0-W1-001（CI） |

manifest 作為規格文件在 CI 建立前即有完整價值（AI session 讀 manifest 而非同時開兩 repo 原生檔互相對照）；CI 校驗是把「靠 AI 自覺」升級為「機器強制」的後續步驟。

### manifest 跨 repo 消費機制（候選，PROP-018 confirm 時定案）

manifest 存放權威為 V1 repo（`src/core/design-system/token-manifest.json`，事實決策，V1 W6-007 產出）。APP 端消費機制候選：

| 候選 | 說明 | 取捨 |
|------|------|------|
| a. APP repo 持副本 + hash 比對 | manifest 副本入 APP repo，校驗 script 附帶檢查副本與 `$schemaVersion`/`generatedAt` 一致性 | 無跨 repo fetch 依賴；副本同步是新的雙寫點，需 hash 防漂移 |
| b. CI 跨 repo fetch | APP CI 直接抓 V1 repo raw manifest | 無副本漂移；引入外部依賴與 auth 複雜度，本地開發不自足 |
| c. 移至共用 repo | manifest 獨立於雙專案之外 | 中立權威；多一個 repo 的維護面，對 2-repo 規模過度 |

### 本提案不做的（Out of Scope）

- V1 端 manifest schema 設計與校驗 script → sibling PROP-014（W6-007/W6-008）承擔
- Dart token 檔生成物化 → 已被審查否決（值變更頻率不支撐；行內註解是資產）
- 元件層命名契約變更 → PROP-016 / §14.6 既有範圍
- 色值歸一 → 已仲裁為平台校準分歧，本提案僅承載

## 驗收條件（草案）

- [ ] 中介 token schema 與 V1 端（PROP-014）採用同一版本（現行 manifest `$schemaVersion` 1.0.0）
- [ ] APP token 值仍手寫於 `lib/core/design_system/`，manifest 記載雙端對照，APP 端雙向校驗攔截漂移（方案 D：值層統一 = 分歧受控可見，非值歸一亦非生成）
- [ ] manifest 之 APP 對照經 APP 端逐項複核（0.38.0-W10-004）
- [ ] spec §14.6 差異標記含色值平台校準條目
- [ ] 同步校驗機制存在且接入 APP CI，人工 diff 退役
- [ ] 既有測試 100% 通過

## Reality Test / 觸發案例實證

觸發案例與雙端盤點數據見 sibling PROP-014「Reality Test」章（2026-07-11 雙 Explore agent 實測：APP 端 token 檔 8 個 / 元件 8 個 / §14.6 契約已產出；V1 端 token 檔 4+1 生成 CSS / 工廠 7 函式）。

2026-07-13 APP 端 WRAP 分析補充實測：`lib/core/design_system/` 9 檔 919 行（純值層約 500 行，buttons.dart 421 行屬元件組合非扁平 token，manifest 已顯性排除）；目錄於 0.37.0-W8-003 集中（歷史僅 1 commit，值變更頻率沿用 V1 量測約 1 次/年，標記為假設）；生成方案在 APP 端的原驗證項（build_runner 生成可行性、`.w`/`.rsp` 生成器設計）隨方案 D 採用**不再需要**——`.w`/`.rsp` 響應式單位與行內註解反而是生成方案在 APP 端成本高於 V1 端的證據。

**絆腳索（監測條款）**：若未來 12 個月內 token 值變更 >= 3 次，變更頻率假設翻盤，屆時建評估 ticket 重啟生成方案（升級路徑：manifest schema 可直接作為 Style Dictionary / 自訂生成器的 SSOT 輸入，無損遷移）。

## 討論記錄

### 2026-07-11

隨 V1 端 PROP-014 同日建立（用戶決策落地）。工作項 3（§14.6 色值差異補記）無 schema 依賴可先行。confirmed 前置：heavy 級評估（3+ 候選逐一評估表 + 多視角審查）。

### 2026-07-11（V1 端 heavy 評估完成，方案收斂）

V1 ticket 1.5.0-W6-006 完成 heavy 評估：5 候選逐評（Style Dictionary / 自訂生成器 / 契約基線 / manifest 校驗層 / 單向提取），linux + thyme 雙視角排序一致 **D > B >> A ≈ E**，用戶確認 V1 PROP-014 confirmed（target v1.5.0）採方案 D。本提案 In Scope 已同步改寫為「消費 manifest schema + APP 端校驗（第二階段）+ §14.6 補記」，生成方案移入 Out of Scope。APP 端 confirmed 時機：建議 PROP-016（v0.38.0）完成後，屆時 V1 W6-007 manifest schema 應已定案可直接消費。

### 2026-07-13（APP 端 WRAP 分析 + 文件先行決策 + 實況同步）

APP 端獨立 WRAP 分析確認方案 D 在 APP 端同樣成立且更成立（`.w`/`.rsp` 與行內註解使生成成本更高；問題真實形態是「刻意分歧未被記錄」而非「值意外漂移」）。用戶補充決策條件：雙專案主力維護者為 AI，**文件規格統一優先於程式碼調整**——manifest 定位從「校驗工具的資料檔」修正為「雙端 AI 讀取的統一規格文件本體」，校驗 script 降為 enforcement 附件（見「文件先行兩段式定位」節）。同步 V1 實況：W6-007/008 已完成，manifest 已存在且含 APP 對照。APP 端第二段（校驗 script）依賴 CI（1.0.0-W1-001）。sibling PROP-014 同步修正文件漂移（V1 ticket 1.5.0-W6-027）。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| Ticket | 0.38.0-W10-001（§14.6 色值平台校準補記） | 2026-07-12 | pending |
| Ticket | 0.38.0-W10-002（提案文件漂移修正） | 2026-07-12 | in_progress |
| Ticket | 0.38.0-W10-003（提案內容統一：實況同步 + 兩段式 + 消費機制） | 2026-07-13 | in_progress |
| Ticket | 0.38.0-W10-004（manifest APP 對照對帳） | 2026-07-13 | pending |
| Ticket | APP 端校驗 script + CI 接線（IMP，blockedBy 1.0.0-W1-001；1.0.0 版本 activate 後開立——create 版本閘門限 active 版本） | | 待開立 |
| Ticket | V1 端 1.5.0-W6-027（sibling PROP-014 文件漂移修正，V1 repo） | 2026-07-13 | pending |
