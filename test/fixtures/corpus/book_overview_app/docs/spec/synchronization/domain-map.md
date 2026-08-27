---
id: DOMAIN-MAP-synchronization
domain: "synchronization"
source_specs: [SPEC-008, SPEC-017]
related_usecases: [UC-07]
created: "2026-07-23"
updated: "2026-07-26"
---

# Domain Map — synchronization

> 產出來源：0.38.1-W5-002。

## 1. 目的與 UC / DDD 正交關係

synchronization domain 管理跨平台（Chrome Extension ↔ Flutter APP）資料同步：dedup、衝突解決、pass-through 保留、tagTree 合併、QR 離線同步傳輸和離線佇列。依賴 library（Book/BookRepository）和 `lib/core/`（errors，應用核心層）。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

```
presentation (SyncViewModel)
        │
domain service（SyncService / DeduplicationService / ConflictResolver / QR frame 編解碼）
        │
aggregate VO（SyncOperation / QR Frame Header）
        ▲
        │
 data（SyncRepository impl / NetworkStatusMonitor / OfflineSyncService）
```

**依賴方向底線**：
- synchronization → library（Book aggregate + BookLoan VO + BookRepository 介面）：合法，同步操作書籍及借閱資料。
- synchronization → `lib/core/`（errors）：合法，應用核心層依賴（非 domain-to-domain）。
- synchronization 不 import 其他 domain。已驗證。
- scanner → synchronization（SyncRepository）：合法，離線佇列入口。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| Deduplication | domain service | id 主鍵 dedup + crossPlatformId/dataFingerprint 輔助 | 持久化 | `lib/domains/synchronization/` | unit：同 id 合併、輔助欄位軟連結 | 已實作（SyncMergeService._buildIdMap 為 id 主鍵 dedup；crossPlatformId/dataFingerprint 輔助未在本 domain 接線） | N/A |
| ConflictResolution | domain service | updatedAt last-write-wins（較新版本優先）+ sourceApp 優先序 fallback | UI 衝突顯示 | `lib/domains/synchronization/` | unit：兩端 updatedAt 比較各情境 | 已實作（SyncMergeService._isNewer） | N/A |
| PassthroughMerge | domain service | _passthrough + extensions 聯集保留 | 格式定義 | `lib/domains/synchronization/` | unit：兩端聯集無遺漏 | 規劃中（`lib/domains/synchronization/` 下無 passthrough 合併邏輯；passthrough 欄位僅見於 Book entity 與 import mapper） | N/A |
| TagTreeMerge | domain service | ccl 系統樹取最新 + custom 聯集（同 id 取較新 updatedAt）| tag 樹 UI | `lib/domains/synchronization/` | unit：ccl 覆蓋、custom 聯集 | 規劃中（`lib/domains/synchronization/` 下無 tagTree 合併邏輯） | N/A |
| QR Frame Format | supporting VO | Frame Header（15 bytes: magic/version/total_frames/frame_index/total_size/crc32）+ payload | QR Code 渲染 | `lib/domains/synchronization/` | unit：header 解析、CRC32 校驗 | 已實作 | N/A |
| QR Data Pipeline | domain service | 編碼（JSON→UTF8→gzip→CRC32→切塊→header+payload）/ 解碼（反向）| 相機掃描 | `lib/domains/synchronization/` | unit：round-trip 無損 | 已實作 | N/A |
| OfflineQueue | domain service | 佇列管理（priority: high>normal>low）+ 重試策略 + 狀態追蹤（pending→processing→completed/failed）| 網路偵測 | `lib/domains/synchronization/` | unit：優先級排序、重試計數 | 已實作 | N/A |
| SyncPreparationCheck | domain service | 同步前資料完整性與一致性驗證 | UI 提示 | `lib/domains/synchronization/` | unit：驗證規則 | 已實作 | N/A |
| SyncRepository | 非 domain（infrastructure） | SyncRepository 介面：addToOfflineQueue / getSyncStatus | 持久化 | `lib/domains/synchronization/repository/` | repository test | 已實作（dormant：無 production 接線） | 豁免不寫契約（0.38.1-W10-004 實查：sync 四表無 production 寫入路徑——ServiceLocator 從未初始化、sync_providers.dart 無消費者；豁免理由與重啟條件見該票 Solution） |
| SyncOperation | supporting VO | SyncOperation 列舉 | 操作執行 | `lib/domains/synchronization/enums/` | unit：列舉完整性 | 已實作 | N/A |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| Deduplication | 同 id 書籍合併後 id 不變（禁重生） |
| ConflictResolution | 兩端 updatedAt 皆有值時取較新者；一端為 null 時有值優先 |
| PassthroughMerge | 合併不 strip 任一端的 _passthrough/extensions 欄位 |
| QR Frame Format | magic 固定 0x5152；version 固定 0x01；CRC32 對壓縮後資料計算 |
| OfflineQueue | high 優先級先於 normal 先於 low 處理 |

## 4. 邊界決策

### 4.1 QR 同步為 synchronization 子功能

QR 離線同步（SPEC-017）的 frame 格式和資料管線屬 synchronization domain，相機掃描硬體整合屬 infrastructure。

### 4.2 exported_at 防舊蓋新

exported_at < last_imported_at 時僅警告不阻擋，使用者可決定是否繼續。此為同步策略決策。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| dedup/衝突解決修改 | domain | Deduplication + ConflictResolution。粒度：dedup 和衝突解決為獨立 bundle，可分開 ticket |
| QR 格式修改 | domain | QR Frame Format + QR Data Pipeline。粒度：frame 格式定義與 data pipeline 實作可分開 |
| 離線佇列修改 | domain | OfflineQueue |
| 同步 UI 修改 | presentation | SyncViewModel |

## 6. 觀察到的技術債（待追蹤）

- 依 SPEC-008/009 差距分析，未發現顯著差距。QR 同步和離線佇列為規劃中功能，技術債將在實作階段產出。

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（id dedup） | Deduplication | domain |
| FR-2（id 保留） | Deduplication | domain |
| FR-3（衝突解決） | ConflictResolution | domain |
| FR-4（pass-through 保留） | PassthroughMerge | domain |
| FR-5（tagTree 合併） | TagTreeMerge | domain |
| FR-6（QR 離線同步） | QR Frame Format + QR Data Pipeline | domain |
| FR-7（離線佇列） | OfflineQueue | domain |
| FR-8（同步準備檢查） | SyncPreparationCheck | domain |

---

**Last Updated**: 2026-07-26 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄，發現 PassthroughMerge / TagTreeMerge 為規劃中（PC-APP-012 印證） | 0.38.1-W10-006 補「資料契約文件引用連結」欄（SyncRepository 標待 0.38.1-W10-004，其餘 N/A；template 2.2.0） | 0.38.1-W10-004 結論回填：SyncRepository 標豁免（sync 四表 dormant，無 production 寫入路徑；重啟條件見該票 Solution） | 0.38.1-W11-004 QR frame 規格編號 SPEC-009 改 SPEC-017
