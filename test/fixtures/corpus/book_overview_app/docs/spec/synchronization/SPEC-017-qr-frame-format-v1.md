---
id: SPEC-017
title: "QR 離線同步 Frame 二進位格式規格 v1"
status: draft
source_proposal: PROP-014
created: "2026-06-18"
updated: "2026-07-26"
version: "1.1"

domain: synchronization
subdomain: qr-offline-sync

related_usecases: [UC-07]
related_specs: [SPEC-008]
---

# QR 離線同步 Frame 二進位格式規格 v1

## 概述

定義 QR Code 動畫離線同步中每一幀 QR Code 承載的二進位 payload 格式。此規格為 Extension 端（編碼方）和 App 端（解碼方）的共用契約。

## 1. Frame Header

固定 15 bytes，所有多位元組整數使用 big-endian。

| 偏移 | 大小 | 欄位 | 型別 | 說明 |
|------|------|------|------|------|
| 0 | 2 bytes | magic | uint16 | 固定 `0x5152`（ASCII "QR"），用於識別本格式 |
| 2 | 1 byte | version | uint8 | 格式版本，本規格 = `0x01` |
| 3 | 2 bytes | total_frames | uint16 | 總幀數 |
| 5 | 2 bytes | frame_index | uint16 | 本幀索引（0-based） |
| 7 | 4 bytes | total_size | uint32 | 原始壓縮資料總長度（bytes） |
| 11 | 4 bytes | crc32 | uint32 | 對整份壓縮資料的 CRC32 校驗值 |
| 15 | N bytes | payload | bytes | 本幀的資料切塊 |

## 2. 資料管線

### 2.1 編碼（Extension 端）

```text
原始 JSON 文字
  → UTF-8 encode
  → gzip 壓縮
  → 計算 CRC32（對壓縮後資料）
  → 依 PAYLOAD_SIZE 切塊
  → 每塊前置 15 bytes header
  → 產生 QR Code（byte mode）
```

### 2.2 解碼（App 端）

```text
QR Code 解碼（byte mode）
  → 讀取前 2 bytes，驗證 magic = 0x5152
  → 解析 header（15 bytes）
  → 驗證 crc32 與已收到的其他幀一致（同一份資料）
  → 依 frame_index 存入 buffer（去重）
  → 收齊 total_frames 幀
  → 拼接 payload → 驗證 total_size
  → CRC32 校驗
  → gzip 解壓
  → UTF-8 decode → JSON parse
```

## 3. QR Code 參數

| 參數 | 值 | 說明 |
|------|------|------|
| Mode | Byte | 傳輸壓縮後的二進位資料 |
| Version | 固定（建議 20-25） | 避免相機重新對焦 |
| Error Correction | M (15%) | 螢幕傳輸不需高容錯 |
| PAYLOAD_SIZE | ~800 bytes | 含 header 後單幀約 815 bytes |

## 4. 播放參數

| 參數 | 建議值 | 說明 |
|------|--------|------|
| 幀率 | 8 fps | 太快相機拍到疊影 |
| 循環 | 無限循環直到接收端確認 | 確保每幀都被掃到 |

## 5. sync_meta JSON 格式

隨 books JSON 匯出時包含的同步元資料：

```json
{
  "format_version": "2.0",
  "books": [],
  "sync_meta": {
    "exported_at": "2026-06-18T14:30:00Z",
    "source_app": "chrome-extension | flutter-app",
    "source_device": "string",
    "book_count": 155,
    "last_sync_summary": {
      "added": 3,
      "updated": 5,
      "deleted": 0
    }
  }
}
```

| 欄位 | 說明 | 接收端用途 |
|------|------|-----------|
| exported_at | 匯出時間（ISO 8601） | 防舊蓋新比對 |
| source_app | 來源應用程式 | 顯示用 |
| source_device | 來源裝置識別 | 多裝置區分 |
| book_count | 匯出書籍數量 | 合併前驗證 |
| last_sync_summary | 最近一次同步的 added/updated/deleted 計數 | 顯示用 |

## 6. 合併規則

接收端匯入書庫 JSON 時的合併策略：

| 情境 | 規則 |
|------|------|
| 同 id，接收端較新 | 保留接收端版本 |
| 同 id，來源端較新 | 採用來源端版本 |
| 僅來源端有 | 新增到接收端 |
| 僅接收端有 | 保留（不刪除） |
| exported_at < 接收端 last_imported_at | 警告「資料較舊」，讓使用者確認 |

「較新」判斷依據：`updated_at` 欄位（對齊 SPEC-008 FR-3）。

---

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關規格

- SPEC-008: 跨平台同步規格（FR-3 衝突解決、canonical JSON 格式）
- PROP-014: QR 離線同步方案（App 端）
- Extension PROP-012: QR 離線同步方案（Extension 端）
- `book_overview_v1/docs/spec/book-interchange-v1.md`: canonical JSON 格式

---

**Last Updated**: 2026-07-26 | **Version**: 1.1 — 編號由 SPEC-009 改為 SPEC-017（0.38.1-W11-004 重複編號治理：本規格未登錄於 `docs/proposals-tracking.yaml`，與已登錄的 SPEC-009 書籍版本管理規格衝突），檔名改為 ID 前綴式 `SPEC-017-qr-frame-format-v1.md`；規格內容未變更
**Version**: 1.0 — 初始建立
