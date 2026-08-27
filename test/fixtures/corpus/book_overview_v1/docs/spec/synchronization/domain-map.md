---
id: DOMAIN-MAP-synchronization
domain: "synchronization"
source_specs: [SPEC-009]
related_usecases: [UC-07]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — synchronization

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-009（QR Frame Format）交叉引用。

## 1. 目的

synchronization domain 定義跨裝置同步的協議規格（QR 離線同步 frame 格式、sync_meta 結構）。本 domain 的同步實作分散在 `src/sync/`（編碼/格式純計算：qr-encoder.js、sync-json-builder.js）與 `src/background/domains/data-management/services/`（協調流程：SynchronizationOrchestrator 等），無統一的 `src/synchronization/` 目錄。協議規格獨立於實作歸本 domain。

## 2. 分層與依賴方向

```
synchronization domain（協議定義：frame 格式、sync_meta、合併規則）
        │ 參照（單向，spec-level）
        ▼
core（基礎型別）+ data-management（Book/Tag aggregate 定義，被同步的資料結構）
```

**消費者**：data-management（消費同步協議，實際執行同步流程——SynchronizationOrchestrator 等）。

> 本 domain 無統一 `src/synchronization/` 目錄。`src/sync/` 含編碼純計算（import core），DAG 箭頭同時表 code import 和 spec-level 參照。

**依賴方向底線（不可違反）**：

- synchronization 不得 import presentation / UI 框架 / Chrome Storage API。違反則協議層耦合實作。
- synchronization 的 frame 格式定義為跨平台契約（Extension 編碼、App 解碼），不得含平台專屬邏輯。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| QR Frame Codec | supporting VO | Frame Header 結構（15 bytes：magic/version/total_frames/frame_index/total_size/crc32）、frame 切塊/拼接規則 | QR Code 影像編解碼 | `src/sync/qr-encoder.js` | unit：header 編解碼、CRC32 驗證 | 已實作 |
| Sync Meta | supporting VO | sync_meta 結構（source/exported_at/total_books）、format_version | 實際同步執行 | `src/sync/sync-json-builder.js` | unit：schema 驗證 | 已實作 |
| Merge Rules | domain service | 5 案例合併規則（正常遷移 / privacyBookId 缺失 / cover-openbook 碰撞（Readmoo 書籍 ID 格式 cover-{isbn} 與 openbook-{hash} 同書兩 ID 造成重複判定）/ 同 ID 多筆 / cross-device 衝突） | 衝突偵測實作（歸 data-management） | `docs/spec/synchronization/` | unit：合併邏輯 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| QR Frame Codec | magic 恆為 0x5152；version 恆為 0x01；frame_index 0-based 連續；所有 frame 的 total_frames 和 crc32 相同；拼接後長度等於 total_size | 已實作 |
| Sync Meta | format_version 必填；source 必為 'extension'；total_books >= 0 | 已實作 |
| Merge Rules | 正常遷移產出 reader-{privacyBookId} 格式 ID；同 ID 多筆合併後 tagIds 為並集 | 已實作 |

## 4. 邊界決策

### 4.1 協議規格 vs 實作分離

synchronization domain 定義協議（frame 格式、合併規則），編碼純計算實作在 `src/sync/`（qr-encoder.js、sync-json-builder.js），協調流程（SynchronizationOrchestrator 等）歸 data-management domain 的 Sync Coordination bundle。此為現況邊界——V1 無統一的 `src/synchronization/` 目錄，與 APP（獨立 synchronization domain）架構不同。

### 4.2 測試 fixtures 歸本 domain

`docs/spec/synchronization/test-fixtures/` 下的 frame-format-vectors.json、sync-meta-schema.json、merge-scenarios.json 為跨平台共用測試向量，歸本 domain 管理。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 同步協議版本升級 | domain | 更新 SPEC-009 + 測試向量 |
| 同步流程實作修改 | data-management | 修改 Sync Coordination bundle（在 data-management domain） |

## 6. 觀察到的技術債（待追蹤）

- V1 無獨立 synchronization src 目錄，與 APP 架構不一致（domain-architecture-comparison-report 已記錄）
- cross-device sync 衝突（合併規則案例 5）標記為範圍外，由 follow-up ticket 處理

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| SPEC-009 QR Frame Format | QR Frame Codec + Sync Meta | 跨平台契約 |
| 合併邏輯（docs/bookstores/readmoo.md §4） | Merge Rules | 5 案例合併規則 |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
