---
id: PROP-012
title: QR Code 動畫離線同步方案（Extension 端）
status: confirmed
evaluation_level: standard
created: "2026-06-18"
confirmed_date: "2026-06-18"
target_version: "v1.2"
priority: P0
related_proposals: [PROP-002, PROP-007]
---

# PROP-012: QR Code 動畫離線同步方案（Extension 端）

## 基本資訊

| 項目 | 值 |
|------|------|
| 提案 ID | PROP-012 |
| 狀態 | confirmed |
| 優先級 | P0 |
| 目標版本 | v1.2 |
| 建立日期 | 2026-06-18 |
| 對應 App 端提案 | book_overview_app PROP-014 |
| 關聯 Spec | SPEC-008（跨平台同步規格） |

---

## 1. 背景

Flutter App 端已確認 PROP-014（QR Code 動畫離線同步方案），Extension 端需要對應實作。本提案定義 Extension 端的職責範圍。

### 1.1 跨專案職責分工

| 職責 | Extension（本提案） | Flutter App（PROP-014） |
|------|---------------------|------------------------|
| QR 動畫產生 | Popup 內顯示動畫 QR | — |
| QR 掃描還原 | — | mobile_scanner 連續掃描 |
| JSON 匯出（含 sync_meta） | — | App 匯出 → 傳檔到電腦 |
| JSON 匯入 | 接收 App 匯出的 JSON → 智慧合併 | — |
| 壓縮/解壓 | gzip 壓縮（CompressionStream） | gzip 解壓（GZipDecoder） |
| 合併邏輯 | id 主鍵 + updated_at 勝出（匯入時） | id 主鍵 + updated_at 勝出（掃描時） |

---

## 2. Extension 端需實作功能

### 2.1 QR 動畫產生（Web → App 方向）

在 Extension Popup 內：

1. 收集書庫資料 → 組成 JSON（含 sync_meta）
2. gzip 壓縮（`CompressionStream`，瀏覽器原生 API）
3. 依 ~800 bytes 切塊 + 加 15 bytes frame header
4. Canvas 輪播 QR 動畫（~8 fps）
5. 動態判斷：壓縮後 <= 800 bytes 顯示單張靜態 QR

Frame 二進位格式、QR 參數等技術細節見 App 端 PROP-014 §3。

### 2.2 JSON 匯入（App → Web 方向）

Extension 接收 App 匯出的 JSON 檔案並匯入：

1. 使用者選擇 JSON 檔案（`<input type="file">` 或拖放）
2. 解析 JSON + 驗證 sync_meta
3. 防舊蓋新檢查（比較 exported_at vs 本機 last_imported_at）
4. 智慧合併（id 主鍵 + updated_at 較新者勝出）
5. 顯示合併結果摘要

### 2.3 sync_meta 格式

匯出 JSON 時包含：

```json
{
  "format_version": "2.0",
  "books": [ ... ],
  "sync_meta": {
    "exported_at": "2026-06-18T14:30:00Z",
    "source_app": "chrome-extension",
    "source_device": "ext_xyz",
    "book_count": 155,
    "last_sync_summary": { "added": 3, "updated": 5, "deleted": 0 }
  }
}
```

---

## 3. UI 設計

### 3.1 Popup 同步入口

```text
+----------------------------------+
|  [書庫] [同步] [設定]            |
+----------------------------------+
|                                  |
|  同步到 App                      |
|  [產生 QR 動畫]                  |
|                                  |
|  從 App 匯入                     |
|  [選擇 JSON 檔案]               |
|                                  |
|  上次同步: 2026-06-18 14:30      |
|  來源: flutter-app               |
|  結果: +3 新增 / 5 更新          |
+----------------------------------+
```

### 3.2 QR 動畫顯示

```text
+----------------------------------+
|  < 返回        同步到 App        |
+----------------------------------+
|                                  |
|     +----------------------+     |
|     |                      |     |
|     |    [QR Code 動畫]    |     |
|     |                      |     |
|     +----------------------+     |
|                                  |
|  共 16 幀 | 正在播放...          |
|  請用 App 掃描此動畫              |
|                                  |
+----------------------------------+
```

---

## 4. 技術選型

| 能力 | 方案 | 說明 |
|------|------|------|
| 壓縮 | `CompressionStream('gzip')` | 瀏覽器原生，零依賴 |
| QR 產生 | `qrcode-generator`（Kazuhiko Arase） | 輕量、無依賴、byte mode |
| 動畫繪製 | `<canvas>` + `requestAnimationFrame` | 原生 JS |
| CRC32 | 自行實作 | ~30 行，避免依賴 |
| 檔案選取 | `<input type="file" accept=".json">` | 原生 API |

---

## 5. 替代方案

| 方案 | 不選原因 |
|------|---------|
| Google Drive 同步 | 已 rejected（PROP-011/012/013）：儲存工具非同步工具 |
| WebRTC P2P | 需要信令伺服器，不符合零伺服器目標 |
| Bluetooth Web API | 瀏覽器支援受限，配對體驗差 |

## 6. 失敗防護

| 風險 | 防護 |
|------|------|
| Popup 空間不足 | canvas 固定 280x280px，QR version 控制在 20 以內 |
| 舊 JSON 覆蓋新資料 | sync_meta.exported_at 比對 + 使用者確認彈窗 |

## 7. Reality Test

| 問題 | 回答 |
|------|------|
| 使用者會用嗎？ | Extension 抓書後「掃一下同步到 App」比匯出傳檔簡單 |
| 技術成熟嗎？ | CompressionStream + canvas QR 皆為穩定 Web API |

---

## 8. 實作路線圖

| 階段 | 內容 | 版本 |
|------|------|------|
| Phase 1 | 壓縮 + 切塊 + QR 輪播 canvas（Popup） | v1.2 |
| Phase 2 | JSON 匯入（含 sync_meta 驗證 + 智慧合併） | v1.2 |
| Phase 3 | 與 App 端端到端整合測試 | v1.2 |

---

*提案作者: rosemary-project-manager*
*對應 App 端: book_overview_app/docs/proposals/PROP-014-qr-offline-sync.md*
*最後更新: 2026-06-18*
