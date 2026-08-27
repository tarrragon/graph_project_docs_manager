---
id: PROP-007
title: "跨專案規格對齊（Tag-based Model / Interchange Format v2 / Google Drive 同步）"
status: confirmed
proposed: "2026-04-02"
confirmed: "2026-04-02"
source: cross-project
target_version: "v0.20.0"
reference: "Flutter App 專案 docs/proposals/PROP-007-cross-project-spec-alignment.md"
evaluation_level: heavy
---

# PROP-007: 跨專案規格對齊

## 說明

本提案為跨專案提案，完整版位於 Flutter App 專案（Book Overview App）。本文件為 Chrome Extension 端的引用摘要，記錄對 Extension 的影響範圍。

**完整提案路徑**：`~/project/book_overview_app/docs/proposals/PROP-007-cross-project-spec-alignment.md`

## 對 Extension 的影響摘要

### 1. Tag-based Model

- Chrome Storage 資料結構將從現有格式改為 tag-based model
- 書籍分類從階層式改為標籤式，與 Flutter App 對齊
- 預計在 v0.20.0 實施資料結構遷移

### 2. Interchange Format v2

- JSON 匯出格式升級為 Interchange Format v2
- 確保 Extension 匯出的資料可被 Flutter App 正確匯入
- 格式包含 tag-based 分類、借閱記錄、同步狀態等欄位

### 3. Google Drive 同步（v2.0 階段）

- 同步方案從原先規劃的自建伺服器改為 Google Drive API
- v1.0 階段使用 JSON 匯出/匯入手動同步
- v2.0 階段透過 Google Drive `drive.file` scope 實現自動同步
- PROP-002 中的進階同步功能（斷點續傳、智慧合併等）延後至 v2.0

## 相關文件

- PROP-002: 跨設備同步機制完善（部分被本提案更新）
- UC-07: 跨平台資料同步準備
- SPEC-004: 資料管理規格

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-04-02 | 初始建立，從 Flutter App 專案引用 |
| 1.1 | 2026-05-05 | 補 evaluation_level=heavy + 5 必填章節（0.18.0-W10-098.7） |

---

## 替代方案

### 候選方案一：維持現有階層式分類（不遷移）

- 說明：保留 Chrome Storage 現有的階層式書籍分類結構，不與 Flutter App 對齊。
- 優點：零遷移成本，不影響現有用戶資料。
- 缺點：Extension 與 Flutter App 資料格式長期不相容，無法實現跨裝置同步；Interchange Format v2 無法支援。
- 結論：不採用，長期維護成本過高且阻礙跨裝置同步目標。

### 候選方案二：自訂 Interchange Format（不採用 Tag-based Model）

- 說明：設計一套轉換層，在 Extension 端保持階層式結構，匯出時轉換為 Flutter App 可接受的格式。
- 優點：Extension 端不需大幅重構。
- 缺點：轉換層本身成本高，且需要長期維護雙向映射邏輯；Tag-based 語意在轉換過程中可能失真。
- 結論：不採用，技術負債過高。

### 候選方案三：採用 Tag-based Model 對齊（本提案選擇）

- 說明：Chrome Extension Chrome Storage 資料結構全面遷移為 Tag-based Model，與 Flutter App PROP-007 規格一致。
- 優點：統一資料模型、Interchange Format v2 可直接對接、跨裝置同步路徑清晰。
- 缺點：需要 v0.17.x 資料結構遷移，現有用戶需資料轉換。
- 結論：採用，為 v0.20.0 跨平台同步奠定基礎。

---

## 失敗防護

### 失敗情境一：資料遷移中途失敗（部分用戶資料轉換不完整）

- 風險：從舊階層式結構遷移至 Tag-based Model 時，若 Chrome Storage 操作中斷，可能導致資料狀態不一致。
- 防護措施：
  1. 遷移前備份原始資料至獨立 key（`_legacy_backup`）。
  2. 遷移採原子性設計：先寫入新格式、驗證成功後才刪除舊格式。
  3. 提供手動復原指令（開發者工具 console 可觸發）。

### 失敗情境二：Interchange Format v2 與 Flutter App 版本不相容

- 風險：Extension 端實作 IF-v2 後，若 Flutter App 更新規格但 Extension 未同步，匯入/匯出可能失敗。
- 防護措施：
  1. IF-v2 規格版本號寫入匯出 JSON 的 `schema_version` 欄位。
  2. Flutter App 匯入時先驗證 schema_version，不符時顯示明確錯誤訊息而非靜默失敗。
  3. 維護跨專案規格變更日誌（PROP-007 變更歷史）。

### 失敗情境三：Google Drive 授權失敗導致同步功能不可用

- 風險：v2.0 階段 Google Drive API 授權流程在某些環境（企業帳號、隱私模式）可能無法完成。
- 防護措施：
  1. v1.0 階段保持手動 JSON 匯出/匯入作為永久 fallback 路徑，不依賴 Google Drive。
  2. Drive 授權失敗時顯示明確錯誤訊息與手動同步指引。
  3. `drive.file` scope 限制只存取 Extension 建立的檔案，降低用戶授權顧慮。

---

## Reality Test

### 實證：Tag-based Model 在 PROP-007 Flutter App 端的實際狀態

本提案依賴 Flutter App PROP-007 的 Tag-based Model 規格。實證確認：
- Flutter App 專案已於 v0.17.x 系列完成 Tag-based Book Model 核心重構（PROP-007）。
- Chrome Extension v0.17.x 對應追蹤 ticket 已建立（docs/todolist.md）。
- 跨專案引用路徑在 `~/project/book_overview_app/docs/proposals/PROP-007-cross-project-spec-alignment.md` 已確認存在。

### 假設驗證：IF-v2 向後相容性

- 假設：IF-v2 格式可向後相容 v1 匯出的 JSON。
- 驗證方式：在 v0.17.x 整合測試中加入 v1 → v2 匯入測試案例。
- 當前狀態：待 v0.17.x 實作完成後驗證。

---

## 多視角審查

### 使用者視角

- 影響：現有用戶書庫資料需要遷移，首次啟動 v0.20.0 會觸發自動遷移。
- 風險：遷移耗時可能造成首次啟動感覺「卡頓」。
- 緩解：遷移在背景執行，UI 顯示進度提示。

### 開發者維護視角（linux 視角）

- Tag-based Model 相比階層式結構，查詢複雜度略高（需要 set 交集運算）。
- Chrome Storage 的讀寫 key 設計需要配合 Tag-based Model 重新規劃，避免 key 爆炸問題。
- IF-v2 的 JSON schema 應加入版本控制，防止靜默格式漂移（IMP-068 同類風險）。

### 跨專案同步視角（Multi-view）

- Extension 與 Flutter App 的 PROP-007 規格必須保持同步，任一端變更需在 PROP-007 變更歷史記錄。
- 建議：未來設計自動化跨專案規格 diff 工具（超出本提案範圍，列為 tech debt）。

---

## 機會成本

### 採用本提案的機會成本

執行 PROP-007 Extension 端對齊，主要排擠以下資源：

| 資源 | 機會成本說明 |
|------|------------|
| 開發工時 | v0.17.x Tag-based Model 重構約佔 3-5 個 Wave，同期無法推進 v0.20.0 其他功能（中文分類法、進階 Tag 管理）。 |
| 測試覆蓋 | 遷移邏輯需要完整整合測試，壓縮 E2E 測試（v0.19.x）的開發時間。 |
| 技術選擇彈性 | 一旦對齊 Tag-based Model，若未來發現 Flutter App 規格有重大缺陷，Extension 端回滾成本高。 |

### 不採用的機會成本

若延後或放棄本提案，則：
- 跨裝置同步（v2.0 核心功能）無法實現，影響產品差異化競爭力。
- 資料格式分裂會隨時間累積技術負債，越晚遷移成本越高。

### 結論

機會成本可接受。跨裝置同步是 v2.0 核心賣點，現在遷移比 v1.0 上線後遷移成本更低。
