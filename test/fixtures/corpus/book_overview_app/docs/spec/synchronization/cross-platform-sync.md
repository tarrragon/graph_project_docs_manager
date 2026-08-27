---
id: SPEC-008
title: "跨平台同步規格"
status: draft
source_proposal: PROP-007
created: "2026-03-30"
updated: "2026-06-20"
version: "2.0"
owner: ""

domain: synchronization
subdomain: null

related_usecases: [UC-07]
related_specs: [SPEC-002, SPEC-003, SPEC-017]
implements_requirements: []
depends_on_domains: [library]
---

# 跨平台同步規格

## 概述

定義跨平台（Chrome Extension ↔ Flutter APP）資料同步的同步策略、dedup 機制、衝突解決與離線支援。

跨平台同步走 canonical JSON 格式（`book_overview_v1/docs/spec/book-interchange-v1.md` §8），不走 CSV。

本規格涵蓋四個層面：

1. **同步核心**（FR-1 ~ FR-5）：dedup、id 保留、衝突解決、pass-through 保留、tagTree 合併
2. **QR 離線同步**（FR-6）：零網路依賴的跨裝置同步管道
3. **離線佇列**（FR-7）：離線操作排隊與網路恢復後自動同步
4. **同步準備檢查**（FR-8）：同步前資料完整性與一致性驗證

---

## 功能需求 (FR)

### FR-1：以 id 為主鍵的 dedup（canonical §8）

書籍以 `id` 為主鍵做 dedup。同 id 的書視為同一本，合併時依衝突解決規則（FR-3）選取版本。

`crossPlatformId`/`dataFingerprint` 為 optional 輔助欄位，輔助跨平台軟連結，不取代 `id` 的主鍵地位：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `crossPlatformId` | string\|null | 跨平台統一 ID 軟連結，APP 規劃中 |
| `dataFingerprint` | string\|null | 資料內容指紋，輔助辨識重複書籍 |

APP 自建書（`book_{timestamp}`）與 Extension readmoo stable id（如 `"210327003000101"`）各自保留原 id，不強制統一 id 命名空間。

### FR-2：id 保留（canonical C4）

同步過程（匯入/匯出/合併）中，書籍原始 `id` 必須原樣保留，禁止重生新 id。

### FR-3：updatedAt 衝突解決

同 id 書籍在兩端有衝突時，以 `updatedAt` 較新的版本為主。

| 情境 | 處理 |
|------|------|
| 兩端 `updatedAt` 皆有值 | 取較新者（last-write-wins）|
| 一端 `updatedAt` 為 null | 有值的一端優先 |
| 兩端 `updatedAt` 相同 | 以 `sourceApp` 枚舉優先序決定（待細化，可配置）|

衝突解決結果以 `updatedAt` 更新為合併時間戳。

### FR-4：pass-through 與 extensions 保留（canonical §9）

合併過程中，`_passthrough` 與 `extensions` 欄位來自兩端的內容取聯集保留，禁止因合併而 strip 任一端的專屬欄位。

### FR-5：tagTree 合併（canonical §6）

同步時 `tagTree.ccl` 以系統受控樹為主（Extension 或 APP 任一有最新 CCL 樹即可）；`tagTree.custom` 取兩端聯集（id 相同的節點取較新 `updatedAt`）。

### FR-6：QR 離線同步傳輸（v1.1.0 新增，PROP-014）

零網路依賴的跨裝置同步管道，以 QR Code 動畫作為資料傳輸媒介。

| 項目 | 規格 |
|------|------|
| 傳輸格式 | SPEC-017 QR Frame 二進位格式 v1 |
| 壓縮 | gzip（兩端原生支援） |
| 校驗 | CRC32（對壓縮後資料） |
| 合併規則 | 複用 FR-3（updatedAt last-write-wins） |
| sync_meta | exported_at / source_app / source_device / book_count |
| 防舊蓋新 | exported_at < last_imported_at 時警告 |

Web→App 方向走 QR 動畫掃描（SPEC-017 frame 格式）；App→Web 方向走既有 JSON 匯出/匯入管道（含 sync_meta）。

### FR-7：離線佇列管理

離線狀態下的資料操作排入佇列，網路恢復後自動同步。

| 項目 | 規格 |
|------|------|
| 佇列優先級 | high（刪除/衝突解決）> normal（更新）> low（批次匯入） |
| 重試策略 | offlineFirst: maxRetry=3, delay=30s; batch: maxRetry=5, delay=5min |
| 狀態追蹤 | pending → processing → completed / failed |

### FR-8：同步準備檢查

同步前驗證書庫資料完整性，識別可能影響同步的問題。

| 檢查項目 | 說明 | 可自動修復 |
|---------|------|-----------|
| 缺失標題 | 書籍 title 為空 | 否 |
| 無效時間戳 | updatedAt 早於 createdAt | 是 |
| 無效借閱資料 | 借閱記錄格式不正確 | 否 |
| 缺失變更記錄 | 無對應的 ChangeRecord | 否 |
| 待解決衝突 | 存在未解決的 ConflictResolution | 否 |

---

## 業務規則 (BR)

### BR-1：同步策略

系統提供四種同步策略，預設使用 offlineFirst：

| 策略 | isOfflineFirst | allowConflictResolution | maxRetryAttempts | retryDelay |
|------|---------------|------------------------|-----------------|------------|
| `offlineFirst`（預設） | true | true | 3 | 30s |
| `realtime` | false | true | 1 | 5s |
| `localOnly` | true | false | 0 | 0 |
| `batch` | true | true | 5 | 5min |

### BR-2：衝突嚴重程度分級

| 嚴重程度 | 說明 | 處理方式 |
|---------|------|---------|
| low | 可自動解決（如時間戳優先） | 系統自動解決 |
| medium | 建議人工檢查 | 自動解決後通知使用者 |
| high | 必須人工解決 | 阻擋同步，等待使用者決策 |
| critical | 資料損壞風險 | 阻擋同步，強制使用者介入 |

### BR-3：衝突解決策略優先序

| 衝突類型 | 預設策略 | 說明 |
|---------|---------|------|
| versionConflict | timestampWins | 以 updatedAt 較新者勝出 |
| dataConflict | timestampWins | 以 updatedAt 較新者勝出 |
| deleteConflict | manual | 一方刪除一方修改，需使用者決策 |
| duplicateKeyConflict | merge | 嘗試智慧合併 |
| dependencyConflict | manual | 相關資料不一致，需使用者決策 |

### BR-4：bookTags 合併規則

| 分類 | 合併策略 |
|------|---------|
| 非 custom 分類（author, publisher, platform 等） | local 優先；local 缺失的分類由 remote 補 |
| custom 分類 | 以 value（不分大小寫）去重合併，remote 的 custom tags 中不與 local 重複者加入 |

### BR-5：同步準備就緒條件

同步準備就緒 (`isReady`) 需同時滿足：
- overallProgress == 100（所有檢查通過）
- conflictCount == 0（無待解決衝突）
- issues.isEmpty（無待處理問題）

### BR-6：防舊蓋新

QR 同步與 JSON 匯入時，比較 `sync_meta.exported_at` 與接收端 `last_imported_at`，若匯出時間較舊，顯示警告讓使用者確認。書級別新舊判斷仍以每本書的 `updatedAt` 為準（FR-3）。

---

## 介面契約 (Interface Contracts)

### IC-1：SyncRepository（Domain 層 Repository 介面）

位置：`lib/domains/synchronization/repository/sync_repository.dart`

```dart
abstract class SyncRepository implements SyncQueryPort {
  // 變更記錄管理
  Future<void> recordChange(ChangeRecord changeRecord);
  Future<List<ChangeRecord>> getPendingChanges({int? limit, String? entityType});
  Future<List<ChangeRecord>> getChangesByEntity({required String entityType, required String entityId});
  Future<void> updateChangeRecord(ChangeRecord changeRecord);
  Future<void> markChangeAsSynced({required String changeId, required DateTime remoteTimestamp});
  Future<void> cleanupCompletedChanges({Duration? olderThan});

  // 同步任務管理（UC-08 預留）
  Future<void> createSyncTask(SyncTask syncTask);
  Future<SyncTask?> getSyncTask(String taskId);
  Future<List<SyncTask>> getActiveSyncTasks();
  Future<List<SyncTask>> getSyncTaskHistory({int? limit, DateTime? since});
  Future<void> updateSyncTask(SyncTask syncTask);
  Future<void> deleteSyncTask(String taskId);

  // 衝突解決管理
  Future<void> recordConflict(ConflictResolution conflict);
  Future<List<ConflictResolution>> getPendingConflicts({int? limit});
  Future<ConflictResolution?> getConflictByChangeRecord(String changeRecordId);
  Future<void> updateConflictResolution(ConflictResolution conflict);
  Future<void> cleanupResolvedConflicts({Duration? olderThan});

  // 離線佇列管理（UC-09 預留）
  Future<void> addToOfflineQueue(OfflineQueueItem item);
  Future<List<OfflineQueueItem>> getOfflineQueue({int? limit});
  Future<void> removeFromOfflineQueue(String queueId);
  Future<void> clearOfflineQueue();

  // 同步統計（UC-10 預留）
  Future<SyncStatistics> getSyncStatistics({DateTime? since});
  Future<SyncStatusSummary> getSyncStatusSummary();
}
```

### IC-2：SyncQueryPort（精簡查詢介面 — ISP）

位置：`lib/domains/synchronization/ports/sync_query_port.dart`

```dart
abstract class SyncQueryPort {
  Future<List<ChangeRecord>> getPendingChanges({int? limit});
  Future<List<ConflictResolution>> getPendingConflicts({int? limit});
}
```

SyncReadinessService 只依賴此精簡介面（2 個方法），不依賴完整 SyncRepository（23 個方法）。

### IC-3：SyncReadinessService（同步準備服務介面）

位置：`lib/domains/synchronization/services/sync_readiness_service_impl.dart`

```dart
abstract class SyncReadinessService {
  Future<SyncReadinessStatus> performReadinessCheck();
  Future<List<ChangeRecord>> getPendingChanges({int? limit});
  Future<List<ConflictResolution>> getPendingConflicts({int? limit});
  Future<bool> fixDataIntegrityIssues(List<String> bookIds);
}
```

實作類 `SyncReadinessServiceImpl` 依賴：
- `SyncQueryPort`（精簡介面，查詢變更與衝突）
- `BookRepository`（完整介面，修復功能需要 findById + updateBook）
- `EventBus`（發佈檢查開始/完成/修復事件）

### IC-4：SyncService（Infrastructure 層雲端同步介面）

位置：`lib/infrastructure/sync/sync_service.dart`

```dart
abstract class SyncService {
  Future<SyncResult> pushChanges();
  Future<SyncResult> pullChanges();
  Future<SyncResult> sync();
  Future<SyncStatus> getSyncStatus();
}
```

實作類 `BookSyncService` 依賴：
- `CachedBookRepository`
- `SyncApi`（遠端 API 抽象）
- `ConflictResolver`（衝突解決器）

### IC-5：SyncMergeService（智慧合併服務）

位置：`lib/domains/synchronization/services/sync_merge_service.dart`

```dart
class SyncMergeService {
  MergeResult merge({
    required List<Map<String, dynamic>> incomingBooks,
    required List<Map<String, dynamic>> existingBooks,
    required DateTime exportedAt,
    DateTime? lastImportedAt,
  });
}
```

合併規則：
- incoming 書不在 existing → added
- incoming 書的 updatedAt 較新 → updated
- 其餘 → unchanged
- exportedAt < lastImportedAt → `isStaleImport = true`

### IC-6：QR 同步服務群

位置：`lib/domains/synchronization/services/`

```dart
// QR 幀解碼器
class QrFrameDecoder {
  static const int headerSize = 15;
  static const int magicValue = 0x5152;  // ASCII "QR"
  static const int currentVersion = 0x01;

  QrFrameHeader? decode(Uint8List rawBytes);
}

// QR 同步緩衝區
class QrSyncBuffer {
  QrSyncProgress get progress;
  bool addFrame(QrFrameHeader frame);
  QrSyncResult assemble();
  void reset();
}

// sync_meta 建構器
class SyncMetaBuilder {
  SyncMeta build({
    required int bookCount,
    required String sourceApp,
    String? sourceDevice,
  });
}
```

### IC-7：Use Case 層

位置：`lib/use_cases/sync/`

```dart
// 書籍同步 Use Case
class SyncBooksUseCase {
  Future<SyncBooksResult> execute();
  Future<SyncBooksResult> executeIncremental({int? limit});
  Future<SyncBooksResult> executeOfflineQueueSync({
    List<Map<String, dynamic>> incomingBooks,
    List<Map<String, dynamic>> existingBooks,
    DateTime? exportedAt,
    DateTime? lastImportedAt,
  });
}

// QR 還原 Use Case
class RestoreFromQrUseCase {
  QrRestoreProgress addFrame(Uint8List rawBytes);
  QrRestoreResult execute({
    required List<Map<String, dynamic>> existingBooks,
    DateTime? lastImportedAt,
  });
  void reset();
}
```

### IC-8：Domain Services（變更追蹤、衝突解決、編排）

位置：`lib/domains/synchronization/services/`

```dart
// 變更追蹤服務
class ChangeTracker {
  ChangeTracker({required SyncRepository syncRepository, Uuid? uuid});

  Future<void> trackCreate({required String entityType, required String entityId, required Map<String, dynamic> data});
  Future<void> trackUpdate({required String entityType, required String entityId, required Map<String, dynamic> beforeData, required Map<String, dynamic> afterData});
  Future<void> trackDelete({required String entityType, required String entityId, required Map<String, dynamic> data});
  Future<void> trackBatchImport({required String entityType, required List<String> entityIds, required Map<String, dynamic> batchData});
  Future<List<ChangeRecord>> getPendingChanges({int? limit});
}

// 衝突解決服務
class ConflictResolver {
  ConflictResolver({required SyncRepository syncRepository, Uuid? uuid});

  Future<ConflictResolution?> detectAndResolveConflict({
    required ChangeRecord localChange,
    required Map<String, dynamic> remoteData,
    required DateTime remoteTimestamp,
  });
}

// 同步編排服務
class SyncOrchestrator {
  SyncOrchestrator({
    required SyncRepository syncRepository,
    required ChangeTracker changeTracker,
    required ConflictResolver conflictResolver,
    Uuid? uuid,
  });

  Future<SyncResult> performFullSync({SyncStrategy strategy, NetworkStatus networkStatus});
  Future<SyncResult> performIncrementalSync({int? limit});
  Future<SyncResult> processOfflineQueue();
}
```

### IC-9：離線同步服務群

位置：`lib/domains/synchronization/services/`

```dart
// 網路連通性服務
class NetworkConnectivityService {
  NetworkConnectivityService({required ConnectivityService connectivityService, required EventBus eventBus});

  Future<void> initialize();
  bool get isOnline;
  // 發佈 OnlineToOfflineEvent / OfflineToOnlineEvent
}

// 離線佇列管理服務
class OfflineQueueService {
  Future<void> enqueue({required String entityType, required String entityId, required SyncOperation operation, required Map<String, dynamic> data, OfflineQueuePriority priority});
  Future<List<OfflineQueueItemExtended>> getQueue({OfflineQueuePriority? minPriority});
  Future<void> removeItem(String queueId);
  Future<OfflineQueueStatistics> getStatistics();
}

// 離線同步服務
class OfflineSyncService {
  bool get isSyncing;
  Stream<OfflineSyncProgressEvent> get progressStream;
  Future<void> startSync();
  Future<void> cancelSync();
}
```

---

## 資料模型 (Data Model)

### DM-1：Entity（實體）

#### ChangeRecord — 變更記錄

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| id | String | 是 | UUID v4 唯一識別符 |
| entityType | String | 是 | 實體類型（如 'book', 'tag'） |
| entityId | String | 是 | 實體識別符 |
| operation | SyncOperation | 是 | 操作類型（create/update/delete/batchImport） |
| localTimestamp | DateTime | 是 | 本地時間戳 |
| remoteTimestamp | DateTime? | 否 | 遠端時間戳（同步完成後設定） |
| syncStatus | SyncStatus | 是 | 同步狀態（pending/syncing/completed/failed/conflict/skipped） |
| beforeData | Map<String, dynamic>? | 否 | 變更前資料（JSON） |
| afterData | Map<String, dynamic>? | 否 | 變更後資料（JSON） |
| conflictData | Map<String, dynamic>? | 否 | 衝突資料 |
| retryCount | int | 是 | 重試次數（預設 0） |
| errorMessage | String? | 否 | 錯誤訊息 |

#### ConflictResolution — 衝突解決記錄

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| id | String | 是 | 唯一識別符 |
| changeRecordId | String | 是 | 關聯的變更記錄 ID |
| conflictType | ConflictType | 是 | 衝突類型 |
| severity | ConflictSeverity | 是 | 嚴重程度 |
| strategy | ConflictResolutionStrategy | 是 | 解決策略 |
| localData | Map<String, dynamic> | 是 | 本地資料 |
| remoteData | Map<String, dynamic> | 是 | 遠端資料 |
| resolvedData | Map<String, dynamic>? | 否 | 解決後資料 |
| detectedAt | DateTime | 是 | 偵測時間 |
| resolvedAt | DateTime? | 否 | 解決時間 |
| status | ConflictStatus | 是 | 衝突狀態 |
| autoResolutionReason | String? | 否 | 自動解決原因 |
| userDecision | String? | 否 | 使用者決定 |

#### SyncTask — 同步任務

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| id | String | 是 | 任務識別符 |
| name | String | 是 | 任務名稱（使用 SyncTaskNameCode） |
| strategy | SyncStrategy | 是 | 同步策略 |
| status | SyncStatus | 是 | 任務狀態 |
| networkStatus | NetworkStatus | 是 | 網路狀態 |
| createdAt | DateTime | 是 | 建立時間 |
| startedAt | DateTime? | 否 | 開始時間 |
| completedAt | DateTime? | 否 | 完成時間 |
| progressPercentage | int | 是 | 進度百分比（0-100） |
| totalItems | int | 是 | 處理項目總數 |
| processedItems | int | 是 | 已處理項目數 |
| successfulItems | int | 是 | 成功處理項目數 |
| failedItems | int | 是 | 失敗項目數 |
| conflictItems | int | 是 | 衝突項目數 |

#### OfflineQueueItemExtended — 離線佇列項目

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| queueId | String | 是 | 佇列唯一識別碼 |
| entityType | String | 是 | 實體類型 |
| entityId | String | 是 | 實體識別碼 |
| operation | SyncOperation | 是 | 操作類型 |
| data | Map<String, dynamic> | 是 | 操作資料 |
| createdAt | DateTime | 是 | 建立時間（UTC） |
| retryCount | int | 是 | 重試次數 |
| errorMessage | String? | 否 | 錯誤訊息 |
| priority | OfflineQueuePriority | 是 | 優先級（high/normal/low） |
| status | OfflineQueueItemStatus | 是 | 狀態（pending/processing/completed/failed） |

### DM-2：Value Objects（值物件）

#### SyncMeta — 同步元資料

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| exportedAt | DateTime | 是 | 匯出時間 |
| sourceApp | String | 是 | 來源應用（"chrome-extension" / "flutter-app"） |
| sourceDevice | String? | 否 | 來源裝置 |
| bookCount | int | 是 | 匯出書籍數量 |

#### MergeResult — 合併結果

| 欄位 | 型別 | 說明 |
|------|------|------|
| added | List<Map<String, dynamic>> | 新增的書籍 |
| updated | List<Map<String, dynamic>> | 更新的書籍 |
| unchanged | List<Map<String, dynamic>> | 未變更的書籍 |
| isStaleImport | bool | 是否為過期匯入 |

#### QrFrameHeader — QR 幀標頭

| 欄位 | 型別 | 說明 |
|------|------|------|
| totalFrames | int | 總幀數 |
| frameIndex | int | 本幀索引（0-based） |
| totalSize | int | 壓縮資料總長度（bytes） |
| crc32 | int | CRC32 校驗值 |
| payload | Uint8List | 本幀資料切塊 |

#### QrSyncProgress — QR 同步進度

| 欄位 | 型別 | 說明 |
|------|------|------|
| totalFrames | int | 總幀數 |
| receivedCount | int | 已接收幀數 |
| receivedIndices | Set<int> | 已接收幀索引集合 |
| isComplete | bool | 是否收齊（computed） |
| progress | double | 進度比例 0.0-1.0（computed） |

#### SyncReadinessStatus — 同步準備狀態

| 欄位 | 型別 | 說明 |
|------|------|------|
| overallProgress | int | 整體進度（0-100） |
| dataIntegrityCheck | CheckResult | 資料完整性檢查結果 |
| timestampConsistencyCheck | CheckResult | 時間戳一致性檢查結果 |
| pendingChangesCount | int | 待同步變更數量 |
| conflictCount | int | 衝突數量 |
| lastCheckTime | DateTime | 最後檢查時間 |
| issues | List<BookSyncIssue> | 資料問題列表 |
| isReady | bool | 是否準備就緒（computed，見 BR-5） |

#### SyncStrategy — 同步策略

| 欄位 | 型別 | 說明 |
|------|------|------|
| name | String | 策略名稱 |
| isOfflineFirst | bool | 是否離線優先 |
| allowConflictResolution | bool | 是否允許衝突解決 |
| maxRetryAttempts | int | 最大重試次數 |
| retryDelay | Duration | 重試間隔 |

### DM-3：Enums（列舉）

| Enum | 值 | 位置 |
|------|------|------|
| SyncOperation | create / update / delete / batchImport | `enums/sync_operation.dart` |
| SyncStatus | pending / syncing / completed / failed / conflict / skipped | `enums/sync_operation.dart` |
| NetworkStatus | online / offline / unstable | `enums/sync_operation.dart` |
| ConflictType | versionConflict / dataConflict / deleteConflict / duplicateKeyConflict / dependencyConflict | `value_objects/conflict_type.dart` |
| ConflictSeverity | low / medium / high / critical | `value_objects/conflict_type.dart` |
| ConflictResolutionStrategy | localWins / remoteWins / timestampWins / merge / manual | `value_objects/conflict_type.dart` |
| ConflictStatus | pending / autoResolved / manuallyResolved / ignored / escalated | `entities/conflict_resolution.dart` |
| OfflineQueuePriority | high(3) / normal(2) / low(1) | `enums/offline_queue_priority.dart` |
| OfflineQueueItemStatus | pending / processing / completed / failed | `entities/offline_queue_item_extended.dart` |
| SyncIssueCode | missingTitle / invalidTimestamp / invalidLoanData / missingChangeRecord / pendingConflict | `enums/sync_message_code.dart` |

### DM-4：Domain Events

| Event | 說明 | 位置 |
|-------|------|------|
| SyncReadinessCheckStartedEvent | 同步準備檢查開始 | `events/` |
| SyncReadinessCheckCompletedEvent | 同步準備檢查完成 | `events/` |
| SyncChangeRecordedEvent | 變更已記錄 | `events/` |
| SyncConflictDetectedEvent | 衝突已偵測 | `events/` |
| SyncConflictResolvedEvent | 衝突已解決 | `events/` |
| SyncConflictIgnoredEvent | 衝突已忽略 | `events/` |
| SyncDataIssueFoundEvent | 資料問題已發現 | `events/` |
| SyncDataIssueFixedEvent | 資料問題已修復 | `events/` |
| OnlineToOfflineEvent | 從線上切換到離線 | `events/` |
| OfflineToOnlineEvent | 從離線切換到線上 | `events/` |
| OfflineModeStatusChangedEvent | 離線模式狀態變更 | `events/` |
| OfflineQueueItemAddedEvent | 離線佇列項目已新增 | `events/` |
| OfflineQueueItemRemovedEvent | 離線佇列項目已移除 | `events/` |
| OfflineSyncStartedEvent | 離線同步已開始 | `events/` |
| OfflineSyncProgressEvent | 離線同步進度更新 | `events/` |
| OfflineSyncCompletedEvent | 離線同步已完成 | `events/` |
| OfflineSyncFailedEvent | 離線同步失敗 | `events/` |
| OfflineSyncItemProcessedEvent | 離線同步項目已處理 | `events/` |

---

## 非功能需求 (NFR)

### NFR-1：離線容忍

APP 在離線狀態下仍可讀寫本地書庫；網路恢復後執行同步。離線期間修改的書籍以 `updatedAt` 標記，同步時依 FR-3 解決衝突。

### NFR-2：dedup 不重生

同步過程不允許對既有書籍重生 id。new book 才產生新 id（APP `book_{timestamp}`），既有書籍 id 一律保留（canonical C4）。

### NFR-3：跨平台無損保證

同步走 JSON canonical（不走 CSV），保證 everything-as-tags 多值欄位（多 author/isbn/custom tag 等）無損（canonical C1）。

---

## 需求與實作差距

### GAP-1：crossPlatformId 與 dataFingerprint 未實作

**需求來源**：app-requirements-spec.md L146-147（`cross_platform_id` 用於同步、`data_fingerprint` 用於衝突偵測）

**現狀**：spec 定義為 optional 輔助欄位（FR-1），`Book` entity 有 `crossPlatformId` 欄位，但 domain 層 services 未使用 `dataFingerprint` 做衝突偵測。`ConflictResolver.detectAndResolveConflict()` 依賴 `ChangeRecord` 的 `localTimestamp` 與 `remoteTimestamp` 做衝突偵測，未整合 `dataFingerprint`。

**影響**：衝突偵測完全依賴時間戳，無法偵測內容實際相同但時間戳不同的情況（false positive conflict）。

### GAP-2：Google Drive 同步（v2.0）未實作

**需求來源**：app-requirements-spec.md L239（v2.0: Google Drive API — drive.file scope）

**現狀**：`SyncApi` 介面已定義（`lib/infrastructure/sync/sync_service.dart`），`BookSyncService` 已實作 push/pull/sync 流程骨架，但無 Google Drive 具體實作類別。`SyncApi` 無任何具體實作。

**影響**：雲端同步功能不可用，僅支援 JSON 匯出/匯入（v1.0）和 QR 離線同步（FR-6）。

### GAP-3：Infrastructure 層與 Domain 層存在重複定義

**現狀**：`lib/infrastructure/sync/sync_service.dart` 中定義了獨立的 `ChangeRecord`、`ConflictResolver`、`ConflictResolutionStrategy`、`ChangeOperation` 等型別，與 `lib/domains/synchronization/` 下的同名/同概念型別重複。

**影響**：
- Infrastructure 層 `ChangeRecord`（6 欄位）vs Domain 層 `ChangeRecord`（12 欄位）結構不同
- Infrastructure 層 `ConflictResolutionStrategy`（5 值）vs Domain 層 `ConflictResolutionStrategy`（5 值）名稱不同（如 `lastModifiedWins` vs `timestampWins`）
- 未來整合時需統一為 Domain 層定義，Infrastructure 層改為依賴 Domain 層型別

### GAP-4：SyncRepository 無具體實作

**現狀**：`SyncRepository` 為 abstract class（23 個方法），其中標註 TODO(UC-08/09/10) 的方法尚無具體實作類別。

**影響**：同步任務管理（UC-08）、離線佇列管理（UC-09）、同步儀表板（UC-10）功能不可用。`ChangeTracker`、`ConflictResolver`、`SyncOrchestrator` 等 domain services 依賴此介面但無法在生產環境中執行。

### GAP-5：增量同步識別機制不完整

**需求來源**：app-requirements-spec.md L242（支援增量同步識別，基於 updatedAt 時間戳）

**現狀**：`SyncOrchestrator.performIncrementalSync()` 方法存在（有 `limit` 參數），但 `SyncMergeService.merge()` 的 incoming 書籍來源由呼叫方提供，無自動的「自上次同步後變更」識別機制。`ChangeTracker` 記錄變更但無法自動過濾出上次同步後的增量。

**影響**：增量同步需由呼叫方手動過濾，無法自動執行。

---

## 相關規格

- canonical SSOT：`book_overview_v1/docs/spec/book-interchange-v1.md`（dedup 機制、版本協商、pass-through）
- PROP-007：`docs/proposals/PROP-007-cross-project-spec-alignment.md`（跨專案對齊提案）
- SPEC-002：`docs/spec/import/chrome-extension-import.md`（匯入端 detector + id 保留）
- SPEC-003：`docs/spec/export/library-export.md`（匯出端 canonical 格式）
- SPEC-017：`docs/spec/synchronization/SPEC-017-qr-frame-format-v1.md`（QR 離線同步 Frame 格式；原編號 SPEC-009，0.38.1-W11-004 改號）
- PROP-014：`docs/proposals/PROP-014-qr-offline-sync.md`（QR 離線同步方案）

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-07：跨平台資料同步準備

---

**Last Updated**: 2026-06-20 | **Version**: 2.0 — 充實 spec：新增業務規則（BR-1~BR-6）、介面契約（IC-1~IC-9，含 method signature + 參數/回傳型別）、資料模型（DM-1~DM-4，Entity 欄位定義 + Value Objects + Enums + Domain Events）、需求與實作差距（GAP-1~GAP-5）。新增 FR-7 離線佇列管理、FR-8 同步準備檢查（0.35.0-W2-003）
