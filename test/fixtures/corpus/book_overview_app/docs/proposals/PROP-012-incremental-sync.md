---
id: PROP-012
title: 增量同步與自動排程設計提案
status: rejected
rejected_reason: "前置 PROP-011 rejected。增量同步的複雜度（change log、合併策略、tombstone）大部分在補 Google Drive 非同步工具的缺口。JSON 匯出/匯入方案不需要增量機制。"
rejected_at: "2026-06-18"
evaluation_level: heavy
created: "2026-06-18"
---

# PROP-012: 增量同步與自動排程設計提案

## 基本資訊

| 項目 | 值 |
|------|------|
| 提案 ID | PROP-012 |
| 狀態 | draft |
| 優先級 | P0 |
| 建立日期 | 2026-06-18 |
| 關聯 UC | UC-07（跨平台同步） |
| 關聯 Spec | SPEC-008（跨平台同步規格） |
| 前置提案 | PROP-011（Google Drive 同步技術方案） |

---

## 1. 背景與目標

PROP-011 定義了完整同步（full sync）的基礎架構：每次同步上傳/下載完整 books.json。當書庫成長到數百本以上，完整同步的 payload 過大且浪費頻寬。本提案設計增量同步機制，僅傳輸自上次同步後的變更。

**目標**：
- 減少同步 payload（從完整書庫 → 僅變更項目）
- 定義自動觸發時機（使用者不需手動操作）
- 設計離線佇列（斷網期間操作不遺失）
- 提供同步進度 UI

---

## 2. 增量偵測機制

### 2.1 方案比較

| 方案 | 說明 | 優點 | 缺點 |
|------|------|------|------|
| A. updated_at 時間戳 | 比較各書 updated_at 與 last_sync_at | 簡單、零額外儲存 | 時鐘偏差風險 |
| B. 變更日誌 (Change Log) | 記錄每次操作為 event log | 精確、可追溯 | 額外儲存、日誌膨脹 |
| C. 內容 Hash | 對每本書算 hash，比較差異 | 不依賴時鐘 | CPU 開銷、無法知道「什麼變了」 |
| D. 混合：updated_at + Change Log | updated_at 快篩 + change log 精確比對 | 兼顧效率與精確 | 實作複雜度中等 |

**建議**：方案 D（混合）。理由：

1. `updated_at` 作為第一道快篩：比 last_sync_at 新的書才需處理
2. Change Log 記錄操作類型（create/update/delete），合併時知道意圖
3. 兩者結合能處理「時鐘偏差」邊界案例（change log 作為兜底）

### 2.2 Change Log 設計

每端本機維護一個 change log，記錄自上次成功同步後的所有操作：

```json
{
  "since_sync_at": "2026-06-18T14:00:00Z",
  "changes": [
    {
      "book_id": "book_1718700000",
      "operation": "update",
      "fields_changed": ["tags.reading_status", "progress.percentage"],
      "timestamp": "2026-06-18T15:30:00Z"
    },
    {
      "book_id": "book_1718700100",
      "operation": "create",
      "fields_changed": null,
      "timestamp": "2026-06-18T16:00:00Z"
    },
    {
      "book_id": "book_1718600000",
      "operation": "delete",
      "fields_changed": null,
      "timestamp": "2026-06-18T16:05:00Z"
    }
  ]
}
```

| 欄位 | 說明 |
|------|------|
| `since_sync_at` | 上次成功同步的時間點，同步成功後重置 |
| `operation` | `create` / `update` / `delete` |
| `fields_changed` | update 時記錄哪些欄位變了（供欄位級合併用） |
| `timestamp` | 操作發生時間 |

**日誌生命週期**：同步成功 → 清空 changes 陣列 → 更新 since_sync_at。

### 2.3 增量同步流程

```text
觸發同步
  → 讀本機 change log（取得 local changes）
  → 下載 Drive 上 books.json 的 modifiedTime
    → modifiedTime == last_sync_at → 雲端無變更 → 單向上推
    → modifiedTime > last_sync_at → 雲端有變更 → 雙向合併
  → 合併策略（見 §3）
  → 上傳合併結果
  → 清空 change log + 更新 sync-meta.json
```

---

## 3. 合併策略

### 3.1 單向場景（簡單）

| 場景 | 處理 |
|------|------|
| 僅本機有變更 | 套用 local changes 到 books.json → 上傳 |
| 僅雲端有變更 | 下載 → 套用到本機 |

### 3.2 雙向場景（合併）

```text
本機 changes + 雲端 changes → 合併演算法
```

**合併規則**（遵循 SPEC-008）：

| 情境 | 規則 |
|------|------|
| 同一本書雙端都改了不同欄位 | Field-level merge（各取各的欄位修改） |
| 同一本書雙端改了相同欄位 | Last-write-wins（updated_at 較新者勝出） |
| 一端新增，另一端無此書 | 直接合入 |
| 一端刪除，另一端有修改 | 進入衝突清單（需使用者決定，→ PROP-013） |
| 兩端都刪了同一本書 | 確認刪除 |
| 一端刪除，另一端無修改 | 確認刪除 |

### 3.3 刪除處理（Tombstone）

刪除不能直接從 books.json 移除，否則另一端會以為是新書。使用 tombstone 標記：

```json
{
  "id": "book_1718600000",
  "_deleted": true,
  "_deleted_at": "2026-06-18T16:05:00Z"
}
```

Tombstone 保留期限：30 天後從 books.json 移除（假設 30 天內至少同步過一次）。

---

## 4. 自動同步觸發時機

### 4.1 觸發策略

| 觸發類型 | 時機 | 說明 |
|---------|------|------|
| App 啟動 | 每次打開 App | 取得最新資料 |
| 資料變更後 | 修改/新增/刪除書籍後 5 秒 | debounce 避免頻繁觸發 |
| 定期背景 | 每 30 分鐘（App 在前景時） | 補抓其他端的變更 |
| 網路恢復 | 從離線恢復為連線時 | 推送離線期間的變更 |
| 手動觸發 | 使用者下拉刷新 / 點擊同步按鈕 | 立即同步 |

### 4.2 Debounce 與節流

```text
使用者連續操作（如批量打標籤）：
  修改 A → [5s timer start]
  修改 B → [reset timer to 5s]
  修改 C → [reset timer to 5s]
  ... 5 秒無操作 ...
  → 觸發一次同步（包含 A + B + C 的 changes）
```

| 參數 | 值 | 可配置 |
|------|------|--------|
| Debounce delay | 5 秒 | 是（同步設定頁） |
| 最小同步間隔 | 60 秒 | 否 |
| 背景定期間隔 | 30 分鐘 | 是 |
| Tombstone 保留 | 30 天 | 否 |

### 4.3 Chrome Extension 觸發

| 觸發類型 | 時機 | 說明 |
|---------|------|------|
| 頁面提取完成 | DOM 提取新書後 | 使用 `chrome.alarms` |
| Extension 啟動 | Service Worker 激活 | `chrome.runtime.onStartup` |
| 定期背景 | 使用 `chrome.alarms` 每 30 分鐘 | Service Worker 可能被殺，alarm 確保觸發 |
| 手動觸發 | Popup 中的同步按鈕 | 立即同步 |

---

## 5. 離線佇列

### 5.1 設計原則

- 離線期間所有操作正常執行（本機優先）
- Change log 持續累積，不因離線而丟失
- 上線後自動觸發同步，推送累積的 changes

### 5.2 佇列結構

```text
SQLite（Flutter App）/ IndexedDB（Extension）
  └── sync_queue 表
        ├── id (auto)
        ├── book_id (string)
        ├── operation (create/update/delete)
        ├── fields_changed (json, nullable)
        ├── timestamp (datetime)
        ├── synced (boolean, default false)
        └── retry_count (int, default 0)
```

### 5.3 離線 → 上線流程

```text
偵測到網路恢復（connectivity plugin）
  → 檢查 sync_queue 中 synced=false 的項目
  → 合併為 change log
  → 執行增量同步流程（§2.3）
  → 成功 → 標記 synced=true
  → 失敗 → retry_count++ → 下次觸發時重試
```

### 5.4 長期離線保護

| 離線時間 | 處理 |
|---------|------|
| < 30 天 | 正常增量同步 |
| > 30 天 | tombstone 可能已過期 → 自動降級為完整同步（full sync） |

---

## 6. 同步進度與狀態 UI

### 6.1 狀態指示

| 狀態 | 圖示 | 說明 |
|------|------|------|
| 已同步 | 綠色勾勾 | 本機與雲端一致 |
| 同步中 | 旋轉箭頭 | 正在上傳/下載 |
| 待同步 | 灰色箭頭 | 有 pending changes 等待推送 |
| 離線 | 斷開圖示 | 無網路，操作會進入佇列 |
| 衝突 | 橘色警示 | 有未解決衝突（數字標記） |
| 錯誤 | 紅色叉號 | 同步失敗，點擊查看詳情 |

### 6.2 UI 位置

| 位置 | 顯示內容 |
|------|---------|
| 首頁 AppBar | 同步狀態小圖示（6 種狀態之一） |
| 同步設定頁 | 上次同步時間 + 詳細狀態 + 手動觸發按鈕 |
| 書籍詳情頁 | 該書的同步狀態（synced/pending/conflict） |

### 6.3 同步進度通知

| 事件 | 通知方式 |
|------|---------|
| 同步成功（無衝突） | AppBar 圖示閃綠一下 → 回到正常 |
| 同步成功（有新書從雲端同步來） | SnackBar「已從雲端同步 N 本新書」 |
| 同步失敗 | SnackBar「同步失敗，稍後重試」+ AppBar 變紅 |
| 發現衝突 | SnackBar「有 N 本書需要處理衝突」+ 徽章 |

---

## 7. 同步方向

### 7.1 方案選擇

| 方案 | 說明 | 優點 | 缺點 |
|------|------|------|------|
| A. 雙向同步 | 兩端平等，互相推拉 | 功能完整 | 衝突處理複雜 |
| B. 單向推送（本機 → 雲端） | 本機為 master | 簡單 | 另一端無法回寫 |
| C. Hub-and-spoke | 雲端為 hub，各端 push/pull | 清晰的權威來源 | 本質仍是雙向 |

**建議**：方案 A（雙向同步）。理由：
- 使用情境天然雙向（Extension 新增書、App 管理書、互相看到）
- 以 SPEC-008 FR-3 last-write-wins 為預設策略，衝突情境有限
- 本機為 source of truth（離線可寫），雲端為 transport medium

### 7.2 同步語意

| 概念 | 定義 |
|------|------|
| Source of Truth | 各端本機（離線可寫、可操作） |
| Transport | Google Drive（僅作為交換介質，非權威資料來源） |
| 合併時機 | 同步觸發時，兩端 changes 在本機合併後再上傳結果 |

---

## 8. 與 PROP-011 / PROP-013 的銜接

| 提案 | 本提案依賴/提供 |
|------|----------------|
| PROP-011 | 依賴：Drive API 操作方式、books.json 格式、OAuth token |
| PROP-013 | 提供：衝突清單來源（§3.2 合併產生的衝突進入 PROP-013 UI） |

**sync-meta.json 擴充**（在 PROP-011 基礎上）：

```json
{
  "endpoints": { "...": "..." },
  "conflicts_pending": 2,
  "last_full_sync_at": "2026-06-01T00:00:00Z",
  "incremental_since": "2026-06-18T14:00:00Z",
  "tombstone_cleanup_at": "2026-07-18T00:00:00Z"
}
```

---

## 9. 待討論事項

| 編號 | 問題 | 選項 | 影響 |
|------|------|------|------|
| D-1 | Debounce delay 預設值？ | 5s / 10s / 30s | 即時性 vs API 呼叫頻率 |
| D-2 | 背景同步頻率？ | 15min / 30min / 60min | 電量 vs 即時性 |
| D-3 | 是否需要「僅 WiFi 同步」選項？ | 是 / 否 | 行動數據使用者 |
| D-4 | Change log 是否需要上傳到 Drive？ | 是（可追溯）/ 否（僅本機） | 偵錯 vs 簡單性 |
| D-5 | 完整同步 fallback 閾值？ | 30 天 / 60 天 / 90 天 | tombstone 膨脹 vs 安全性 |

---

## 10. 實作路線圖

| 階段 | 內容 | 前置 |
|------|------|------|
| Phase 1 | Change Log 本機儲存（SQLite / IndexedDB） | 無 |
| Phase 2 | 增量偵測 + 單向上推（本機 → Drive） | PROP-011 Phase 2 |
| Phase 3 | 雙向合併（含 field-level merge） | Phase 2 |
| Phase 4 | 自動觸發 + debounce + 背景排程 | Phase 3 |
| Phase 5 | 離線佇列 + 網路恢復自動同步 | Phase 4 |
| Phase 6 | 同步進度 UI + 狀態指示 | Phase 5 |

---

## 11. 評估結論

本提案設計了完整的增量同步機制，以「updated_at 快篩 + change log 精確合併」為核心策略。重點在於：本機為 source of truth、Google Drive 為 transport、衝突依 SPEC-008 規則處理，無法自動解決時進入 PROP-013 衝突 UI。

**下一步**：
- 用戶確認 D-1 至 D-5 的設計選項
- 三份提案（PROP-011/012/013）整體方向確認後進入開發規劃

---

*提案作者: rosemary-project-manager*
*最後更新: 2026-06-18*
