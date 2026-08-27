# SPEC-009: QR Frame Format

> **狀態**: v1.0（v1.2.0 落地）
> **來源**: PROP-012（QR 離線同步）
> **Canonical 位置**: App 端規格（Extension 端為消費者）

## 概述

定義 Extension → App QR 離線同步的 frame 二進位格式。Extension 端將書庫 JSON 壓縮後切塊為 QR frames，App 端掃描 QR 動畫逐幀接收並拼接還原。

## Frame Header 結構

每個 QR frame 的 payload 前綴為固定長度 header：

| 欄位 | 偏移 | 大小 | 說明 |
|------|------|------|------|
| magic | 0 | 2 bytes | `0x5152`（ASCII "QR"） |
| version | 2 | 1 byte | 協定版本，目前為 `0x01` |
| total_frames | 3 | 2 bytes | 總幀數（big-endian） |
| frame_index | 5 | 2 bytes | 當前幀索引，0-based（big-endian） |
| total_size | 7 | 4 bytes | 所有幀 payload 拼接後的總長度（big-endian） |
| crc32 | 11 | 4 bytes | 原始壓縮資料的 CRC32 校驗值 |

Header 總長：15 bytes。Header 之後為該幀的 payload 片段。

## 資料流程

```
原始 JSON（UTF-8）
  → gzip 壓縮
  → CRC32 計算（對壓縮後資料）
  → 切塊（每塊 <= 800 bytes，避免 QR 容量上限）
  → 每塊前綴 15-byte header
  → 編碼為 QR Code（Binary mode）
```

## 驗證規則

- 所有幀的 `magic` 必須為 `0x5152`
- 所有幀的 `version` 必須為 `0x01`
- 所有幀的 `total_frames` 必須相同
- 所有幀的 `crc32` 必須相同（同一份資料）
- `frame_index` 從 0 到 `total_frames - 1` 各出現恰好一次
- 所有 payload 拼接後長度等於 `total_size`
- 拼接後 CRC32 等於 header 中的 `crc32`
- gzip 解壓後為合法 UTF-8 JSON

## sync_meta 結構

QR 傳輸的 JSON 包含 `sync_meta` 區段：

```json
{
  "format_version": "2.0",
  "sync_meta": {
    "source": "extension",
    "exported_at": "2026-06-22T10:00:00Z",
    "total_books": 42
  },
  "books": [...]
}
```

## 測試向量

共用測試 fixtures 位於 `test-fixtures/frame-format-vectors.json`，Extension 編碼與 App 解碼測試皆須通過。

## 相關文件

- `test-fixtures/frame-format-vectors.json` — Frame header 編解碼測試向量
- `test-fixtures/sync-meta-schema.json` — sync_meta 結構驗證範例
- `test-fixtures/merge-scenarios.json` — 合併邏輯邊界案例
- `docs/app-use-cases.md` UC-07 — 跨平台資料同步用例
