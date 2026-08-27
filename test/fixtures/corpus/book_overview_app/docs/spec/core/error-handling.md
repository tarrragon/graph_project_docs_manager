---
id: SPEC-001
title: "錯誤處理規格"
status: draft
source_proposal: null
created: "2026-03-30"
updated: "2026-06-20"
version: "3.0"
owner: ""

domain: core
subdomain: null

related_usecases: [UC-09]
related_specs: []
implements_requirements: []
depends_on_domains: []
---

# 錯誤處理規格

## 概述

定義系統層級的錯誤處理機制，包括統一例外階層、錯誤碼體系、全域攔截、使用者提示策略與降級恢復流程。系統以 `AppException` 為基底建立五類核心例外，各 Domain 進一步衍生專屬例外，透過 `ErrorHandler` 統一路由，並以三層全域攔截確保無未處理異常。

## 功能需求 (FR)

### FR-1: 統一例外階層

#### FR-1.1: AppException 基底類別

`AppException` 為所有應用程式例外的基底類別，實作 `Exception` 介面。

**欄位定義**：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| errorCode | ErrorCode | 是 | 錯誤碼列舉，來自 ErrorCode enum |
| userMessage | String | 是 | 使用者友善訊息（繁體中文） |
| context | Map<String, dynamic>? | 否 | 錯誤上下文（除錯用） |
| timestamp | DateTime | 自動 | UTC 時間戳，建構時自動產生 |
| stackTrace | StackTrace? | 否 | 堆疊追蹤 |

**介面契約**：

```dart
class AppException implements Exception {
  // 建構函數
  AppException({
    required ErrorCode errorCode,
    required String userMessage,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  });

  // 工廠方法
  factory AppException.withStackTrace({
    required ErrorCode errorCode,
    required String userMessage,
    Map<String, dynamic>? context,
  });

  factory AppException.wrap({
    required Exception originalException,
    required ErrorCode errorCode,
    required String userMessage,
    Map<String, dynamic>? additionalContext,
  });

  factory AppException.validation(String message, {Map<String, dynamic>? context});
  factory AppException.network(String message, {Map<String, dynamic>? context});
  factory AppException.business(String message, {Map<String, dynamic>? context});
  factory AppException.storage(String message, {Map<String, dynamic>? context});
  factory AppException.platform(String message, {Map<String, dynamic>? context});
  factory AppException.fromJson(Map<String, dynamic> json);

  // 衍生屬性
  ErrorCategory get category;
  String get code;
  String get description;
  bool get isRecoverable;

  // 序列化
  Map<String, dynamic> toJson();
  static String formatTimestampToMillis(DateTime timestamp);
}
```

**JSON 序列化格式**（Chrome Extension 相容）：

```json
{
  "type": "AppException",
  "code": "VALIDATION_FAILED",
  "message": "資料驗證失敗",
  "category": "validation",
  "isRecoverable": true,
  "timestamp": "2025-09-27T10:30:00.000Z",
  "context": {}
}
```

時間戳統一截斷為毫秒精度（3 位），與 Chrome Extension (JS `Date.toISOString()`) 格式一致。

#### FR-1.2: 五大分類例外

| 類別 | 說明 | 實作介面 | 專屬欄位 |
|------|------|---------|---------|
| ValidationException | 輸入驗證錯誤 | implements Exception | field, value, validationRule |
| NetworkException | 網路相關錯誤 | implements Exception | url, method, statusCode, responseTime, context |
| BusinessException | 業務邏輯錯誤 | implements Exception | businessRule, entityId, entityType, operation |
| StorageException | 儲存相關錯誤 | implements Exception | storageType, path, operation, availableSpace |
| PlatformException | 平台層級錯誤 | implements Exception | platform, channel, methodName, deviceInfo |

**ValidationException 介面契約**：

```dart
class ValidationException implements Exception {
  ValidationException({
    required ErrorCode errorCode,
    required String userMessage,
    String? field,
    dynamic value,
    String? validationRule,
  });

  factory ValidationException.required(String fieldName);
  factory ValidationException.invalid(String fieldName, dynamic value, {String? expectedFormat});
  factory ValidationException.outOfRange(String fieldName, dynamic value, {dynamic min, dynamic max});
  factory ValidationException.general(String message);
  factory ValidationException.fromJson(Map<String, dynamic> json);

  bool get hasFieldInfo;   // field != null
  bool get hasValueInfo;   // value != null
  Map<String, dynamic> toJson();
}
```

**NetworkException 介面契約**：

```dart
class NetworkException implements Exception {
  NetworkException({
    required ErrorCode errorCode,
    required String userMessage,
    String? url,
    String? method,
    int? statusCode,
    int? responseTime,
    Map<String, dynamic>? context,
  });

  factory NetworkException.timeout({String? url, int? responseTime});
  factory NetworkException.noConnection();
  factory NetworkException.quotaExhausted({required DateTime resetTime});
  factory NetworkException.serverError(int statusCode, {String? url, String? details});
  factory NetworkException.unauthorized({String? url});
  factory NetworkException.badRequest(String details, {String? url, int? statusCode});

  bool get hasHttpInfo;      // statusCode != null
  bool get hasTimingInfo;    // responseTime != null
  Map<String, dynamic> toJson();
}
```

**BusinessException 介面契約**：

```dart
class BusinessException implements Exception {
  BusinessException({
    required ErrorCode errorCode,
    required String userMessage,
    String? businessRule,
    String? entityId,
    String? entityType,
    String? operation,
  });

  factory BusinessException.notFound(String entityType, String entityId);
  factory BusinessException.duplicate(String entityType, String field, String value);
  factory BusinessException.invalidState(String entityType, String entityId, String currentState, String attemptedOperation);
  factory BusinessException.operationFailed(String operation, String reason, {String? entityType, String? entityId});
  factory BusinessException.fromJson(Map<String, dynamic> json);

  bool get hasEntityInfo;       // entityId != null && entityType != null
  bool get hasBusinessRule;     // businessRule != null
  bool get hasOperationInfo;    // operation != null
  Map<String, dynamic> toJson();
}
```

**StorageException 介面契約**：

```dart
class StorageException implements Exception {
  StorageException({
    required ErrorCode errorCode,
    required String userMessage,
    StorageType? storageType,
    String? path,
    String? operation,
    int? availableSpace,
  });

  factory StorageException.readError(String path, [String? details]);
  factory StorageException.writeError(String path, [String? details]);
  factory StorageException.fileNotFound(String path);
  factory StorageException.insufficientSpace(int availableSpace, int requiredSpace);
  factory StorageException.databaseError(String operation, String details, {String? tableName});
  factory StorageException.permissionDenied(String path, [String? operation]);
  factory StorageException.general(String message);

  Map<String, dynamic> toJson();
}
```

**PlatformException 介面契約**：

```dart
class PlatformException implements Exception {
  PlatformException({
    required ErrorCode errorCode,
    required String userMessage,
    String? platform,
    String? channel,
    String? methodName,
    Map<String, dynamic>? deviceInfo,
  });

  factory PlatformException.cameraError(String message, {String? details});
  factory PlatformException.widgetError(String message, {String? widgetName});
  factory PlatformException.navigationError(String message, {String? routeName});
  factory PlatformException.channelError(String channelName, String methodName, {String? message});
  factory PlatformException.fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson();
}
```

#### FR-1.3: 衍生例外類別

| 類別 | 繼承自 | 說明 |
|------|-------|------|
| QueueException | AppException | 請求佇列管理錯誤 |
| StandardError | BusinessException | 標準化業務錯誤（簡化建構） |

**QueueException 介面契約**：

```dart
class QueueException extends AppException {
  factory QueueException.overflow({int? currentSize, int? maxSize});
  factory QueueException.requestNotFound(String requestId);
  factory QueueException.timeout({String? requestId, Duration? elapsed});
}
```

**StandardError 介面契約**：

```dart
class StandardError extends BusinessException {
  factory StandardError.validation(String message, [Map<String, dynamic>? details]);
  factory StandardError.operationFailed(String operation, [Map<String, dynamic>? details]);
  factory StandardError.unsupportedOperation(String operation, [Map<String, dynamic>? details]);
  factory StandardError.notFound(String resource, [Map<String, dynamic>? details]);
}
```

### FR-2: 錯誤碼體系

#### FR-2.1: ErrorCode 列舉

`ErrorCode` 列舉定義 28 個錯誤碼，分為 5 個 `ErrorCategory`：

| ErrorCategory | ErrorCode 值 | isRecoverable |
|--------------|-------------|---------------|
| validation | validationFailed | true |
| validation | invalidInput | true |
| validation | requiredFieldMissing | true |
| validation | valueOutOfRange | true |
| network | networkTimeout | true |
| network | noConnection | true |
| network | offlineError | true |
| network | serverError | false |
| network | badRequest | true |
| network | unauthorized | false |
| network | quotaExhausted | true |
| business | bookNotFound | true |
| business | duplicateBook | true |
| business | invalidIsbn | true |
| business | invalidBookState | false |
| business | activeLoanExists | true |
| business | loanNotFound | true |
| storage | storageError | false |
| storage | fileAccessDenied | false |
| storage | fileSystemError | false |
| storage | databaseError | false |
| platform | permissionDenied | false |
| platform | cameraError | true |
| platform | widgetError | true |
| platform | navigationError | true |
| platform | platformChannelError | false |
| platform | uncaughtAsyncError | false |
| platform | queueOverflow | true |
| platform | requestNotFound | true |
| platform | requestTimeout | true |
| platform | unknownError | false |

#### FR-2.2: ErrorCode 擴展屬性

每個 ErrorCode 透過 extension 提供：

| 屬性 | 型別 | 說明 |
|------|------|------|
| code | String | SCREAMING_SNAKE_CASE 字串（如 `VALIDATION_FAILED`） |
| description | String | 繁體中文使用者訊息 |
| isRecoverable | bool | 是否可透過使用者操作恢復 |
| category | ErrorCategory | 分類（validation / network / business / storage / platform） |

#### FR-2.3: 預編譯常用錯誤

`CommonErrors` 提供 29 個高頻錯誤的預建構實例（`static final`），避免重複建構：

| 分類 | 數量 | 範例 |
|------|------|------|
| 驗證錯誤 | 6 | titleRequired, isbnRequired, authorRequired, invalidIsbnFormat, invalidDateFormat, fieldLengthExceeded |
| 網路錯誤 | 5 | networkTimeout, noConnection, serverError, apiRateLimited, invalidApiResponse |
| 業務錯誤 | 4 | bookNotFound, duplicateBook, operationNotAllowed, invalidBookState |
| 儲存錯誤 | 5 | databaseError, fileNotFound, writeError, readError, insufficientSpace |
| 平台錯誤 | 5 | cameraPermissionDenied, cameraHardwareError, widgetRenderError, navigationFailed, channelError |
| 系統錯誤 | 4 | （全域錯誤處理器專用） |

存取方式：`CommonErrors.titleRequired`、`CommonErrors.networkTimeout` 等。

### FR-3: Domain 專屬例外

各 domain 定義專屬例外類別，繼承自 core 例外或直接實作 `Exception`：

#### FR-3.1: Enrichment Domain

| 例外類別 | 繼承自 | 說明 |
|---------|-------|------|
| EnrichmentException | AppException | 資料補充通用錯誤 |
| ApiQuotaExceededException | AppException | API 配額耗盡 |
| ApiResponseFormatException | AppException | API 回應格式錯誤 |
| NetworkConnectionException | AppException | 網路連線失敗 |
| DataParsingException | AppException | 資料解析失敗 |
| SimilarityCalculationException | EnrichmentException | 相似度計算錯誤 |
| EnrichmentConfigurationException | AppException | 補充設定錯誤 |

#### FR-3.2: Import Domain

| 例外類別 | 繼承自 | 說明 |
|---------|-------|------|
| ImportException | AppException | 匯入通用錯誤 |
| JsonFormatException | ValidationException | JSON 格式錯誤 |
| FileReadException | StorageException | 檔案讀取失敗 |
| DataValidationException | ValidationException | 資料驗證失敗 |
| MemoryLimitException | PlatformException | 記憶體超限 |
| ProcessingTimeoutException | NetworkException | 處理超時 |
| DuplicateBookException | ImportException | 重複書籍 |
| BatchProcessingException | ImportException | 批次處理失敗 |
| ImportCancelledException | ImportException | 匯入取消 |
| ChromeExtensionFormatException | ValidationException | Chrome Extension 格式錯誤 |
| ImportConfigurationException | ValidationException | 匯入設定錯誤 |
| BatchImportException | implements Exception | 批次匯入錯誤（獨立實作） |
| InvalidImportTaskIdException | implements Exception | 無效匯入任務 ID |
| InvalidImportSourceException | implements Exception | 無效匯入來源 |
| InvalidJsonFormatException | implements Exception | JSON 格式無效 |
| JsonParseException | implements Exception | JSON 解析錯誤 |

#### FR-3.3: Library Domain

| 例外類別 | 繼承自 | 說明 |
|---------|-------|------|
| InvalidBookIdException | implements Exception | 無效書籍 ID |
| InvalidBookTitleException | implements Exception | 無效書名 |
| InvalidBookSourceException | implements Exception | 無效書籍來源 |
| InvalidISBNException | implements Exception | 無效 ISBN |
| DuplicateBookException | implements Exception | 重複書籍 |
| BookDataIntegrityException | implements Exception | 資料完整性錯誤 |
| ConcurrentModificationException | implements Exception | 並行修改衝突 |

#### FR-3.4: Scanner Domain

| 例外類別 | 繼承自 | 說明 |
|---------|-------|------|
| BarcodeDetectionException | implements Exception | 條碼偵測失敗 |
| CameraHardwareException | implements Exception | 相機硬體錯誤 |
| InvalidBarcodeDataException | implements Exception | 無效條碼資料 |
| InvalidScanTaskIdException | implements Exception | 無效掃描任務 ID |

#### FR-3.5: Search Domain

| 例外類別 | 繼承自 | 說明 |
|---------|-------|------|
| ApiTimeoutException | implements Exception | API 超時 |
| NetworkConnectivityException | implements Exception | 網路連線錯誤 |
| NoSearchResultsException | implements Exception | 無搜尋結果 |
| ApiRateLimitException | implements Exception | API 速率限制（含 retryAfter: Duration） |
| InvalidSearchCriteriaException | implements Exception | 無效搜尋條件 |
| InvalidSearchQueryIdException | implements Exception | 無效搜尋查詢 ID |

### FR-4: 全域錯誤攔截

三層全域攔截（`main.dart`），確保所有錯誤都經過統一處理：

| 層級 | 機制 | 捕獲範圍 | 錯誤碼 |
|------|------|---------|--------|
| Widget 層 | FlutterError.onError | Widget 建置階段錯誤 | widgetError |
| 平台層 | PlatformDispatcher.instance.onError | 平台級未處理異常 | platformChannelError |
| 非同步層 | runZonedGuarded | 非同步未處理異常（Timer callback、Future chain） | uncaughtAsyncError |

三層皆路由至 `ErrorHandler.handleError()` + `ErrorHandler.reportError()`。

### FR-5: ErrorHandler 路由

`ErrorHandler` 提供靜態方法的統一錯誤處理入口（無全域狀態）：

**介面契約**：

```dart
class ErrorHandler {
  static void handleError(Exception error, {Map<String, dynamic>? context});
  static void logError(Exception error, {Map<String, dynamic>? context, String severity = 'error'});
  static bool shouldNotifyUser(Exception error);
  static String getUserMessage(Exception error, {bool includeAction = false});
  static void reportError(Exception error, {Map<String, dynamic>? context, String? userId, bool fatal = false});
}
```

**handleError 分派邏輯**：使用 Dart 3 模式匹配（switch expression），依例外型別分派至內部處理方法：

| 例外型別 | 內部處理方法 |
|---------|------------|
| ValidationException | _handleValidationError |
| NetworkException | _handleNetworkError |
| BusinessException | _handleBusinessError |
| StorageException | _handleStorageError |
| PlatformException | _handlePlatformError |
| 其他 Exception | _handleGenericError |

**shouldNotifyUser 通知策略**：

| 例外型別 | 通知使用者 | 說明 |
|---------|----------|------|
| NetworkException | 是 | 使用者可重試或檢查網路 |
| StorageException | 是 | 可能需使用者介入（權限、空間） |
| PlatformException | 是 | 通常需使用者授予權限 |
| ValidationException（有 field） | 是 | 便於修正輸入 |
| BusinessException.bookNotFound | 否 | 預期業務錯誤，UI 層自行處理 |
| BusinessException.duplicateBook | 否 | 預期業務錯誤，UI 層自行處理 |
| BusinessException.invalidIsbn | 否 | 預期業務錯誤，UI 層自行處理 |
| BusinessException.invalidBookState | 是 | 狀態錯誤需使用者注意 |
| 其他 Exception | 否 | 由呼叫端處理 |

**getUserMessage 訊息生成**：依例外型別分派至內部方法（`_getValidationErrorMessage`、`_getNetworkErrorMessage` 等），`includeAction=true` 時附加建議行動文字。

### FR-6: 日誌系統

`AppLogger` 提供統一日誌 API，禁止直接使用 `debugPrint`、`print`。

**介面契約**：

```dart
class AppLogger {
  static void setLogLevel(LogLevel level);

  // 實例方法（需建構 AppLogger 實例）
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace});
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace});
  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void fatal(String message, {String? tag, Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});

  // 靜態方法（直接呼叫）
  static void debugStatic(String message, [String? tag]);
  static void infoStatic(String message, [String? tag]);
  static void warningStatic(String message, [String? tag, Object? error, StackTrace? stackTrace]);
  static void errorStatic(String message, [String? tag, Object? error, StackTrace? stackTrace]);
}

// 字串擴展（便利 API）
extension QuickLog on String {
  void logDebug([String? tag]);
  void logInfo([String? tag]);
  void logWarning([String? tag, Object? error, StackTrace? stackTrace]);
  void logError([String? tag, Object? error, StackTrace? stackTrace]);
}
```

**日誌級別**：

| LogLevel | 方法 | debug 模式 | production 模式 |
|----------|------|-----------|----------------|
| debug | debugStatic() | 輸出 | 不輸出 |
| info | infoStatic() | 輸出 | 不輸出 |
| warning | warningStatic() | 輸出 | 輸出 |
| error | errorStatic() | 輸出 | 輸出 |
| fatal | fatal() | 輸出 | 輸出 |

輸出格式：`[timestamp] [LEVEL] [tag] message`。tag 預設為 `BookLibrary`。

### FR-7: 降級恢復

#### FR-7.1: GracefulDegradationHandler

協調 API 失敗時的服務降級，注入 `DegradedModeStrategy` 和 `FriendlyMessageGenerator`。

**介面契約**：

```dart
class GracefulDegradationHandler {
  const GracefulDegradationHandler({
    required DegradedModeStrategy degradedModeStrategy,
    required FriendlyMessageGenerator messageGenerator,
  });

  Future<DegradationResult> activate({
    required FailureType failureType,
    required QueryType queryType,
    required Map<String, dynamic> queryContext,
    required FailureStatistics failureStats,
  });
}
```

#### FR-7.2: 降級等級（DegradationLevel）

| 降級等級 | 觸發條件 | 停用功能 | 行為 |
|---------|---------|---------|------|
| basicInfo | 網路錯誤、API 超時 | batch_query, realtime_search, cover_image | 提供快取基本資訊，允許核心功能 |
| offline | 配額耗盡；速率限制 + 失敗率 > 70% | batch_query, realtime_search, cover_image, api_query, auto_complete | 開啟手動輸入、離線佇列 |

#### FR-7.3: DegradationResult

```dart
class DegradationResult {
  final DegradationLevel level;
  final String userMessage;
  final String technicalReason;
  final List<DegradedAction> suggestedActions;
  final ManualInputTemplate? inputTemplate;  // 僅 offline 模式
  final Duration? retryEstimate;

  factory DegradationResult.basicInfo({...});
  factory DegradationResult.offline({...});
}
```

#### FR-7.4: FriendlyMessageGenerator

```dart
abstract class FriendlyMessageGenerator {
  String generate({
    required FailureType failureType,
    required QueryType queryType,
    required DegradationLevel level,
  });
}
```

預設訊息對應：

| FailureType | 基礎訊息 | 建議 |
|-------------|---------|------|
| networkError | 網路連線不穩定 | 目前僅能提供基本資訊 |
| timeout | 查詢時間過長 | 請稍後再試 |
| quotaExhausted | 查詢量已達上限 | 建議明天再試或手動輸入 |
| rateLimitExceeded | 查詢次數過於頻繁 | 請稍候片刻再重試 |
| serverError | 伺服器暫時無法回應 | 請稍後再試 |
| clientError | 查詢條件有誤 | — |
| parsingError | 資料格式異常 | — |
| unknown | 查詢暫時無法完成 | — |

## 業務規則 (BR)

### BR-1: 例外分類一致性

- `BusinessException` 建構時驗證 `errorCode.category == ErrorCategory.business`（assert）
- Domain 專屬例外應繼承對應的 core 例外類別（enrichment/import 已遵循；library/scanner/search 尚未）
- 建構時 assert 僅在 debug 模式生效，production 模式不觸發

### BR-2: 使用者通知分級

- 網路/儲存/平台錯誤：一律通知使用者
- 驗證錯誤：有欄位資訊時通知（便於修正）
- 業務邏輯錯誤：預期性錯誤（bookNotFound, duplicateBook, invalidIsbn）不通知，狀態轉換錯誤通知
- 非 AppException 體系的例外：不通知（由呼叫端處理）

### BR-3: 錯誤恢復優先級

1. 資料完整性：優先保護使用者資料（事務性操作 + rollback）
2. 核心功能：確保基本瀏覽和管理持續可用
3. 使用者體驗：最小化錯誤對操作流程的干擾
4. 系統穩定：防止錯誤擴散和崩潰

### BR-4: catch 區塊規範

| catch 行為 | 要求 |
|-----------|------|
| catch 後 return 預設值 | 必須 `AppLogger.warningStatic()` |
| catch 後 rethrow | 加日誌或直接移除 try-catch |
| catch 後拋出自訂 Exception | 必須 `AppLogger.errorStatic()` 記錄原始錯誤再拋出 |
| 空 catch `catch (_) {}` | 禁止 |

### BR-5: 降級決策邏輯

| 條件 | 降級等級 |
|------|---------|
| FailureType == quotaExhausted | offline |
| FailureType == rateLimitExceeded AND failureRateLastHour > 0.7 | offline |
| 其他 | basicInfo |

### BR-6: JSON 序列化契約

所有例外的 `toJson()` 輸出必須包含：`type`、`code`、`message`、`category`、`isRecoverable`（或 `recoverable`）、`timestamp`。`context` 為條件性欄位（非空時輸出）。時間戳格式：ISO 8601 UTC 毫秒精度（`YYYY-MM-DDTHH:mm:ss.SSSZ`）。

## 資料模型

### DM-1: ErrorCategory 列舉

```dart
enum ErrorCategory { validation, network, business, storage, platform }
```

### DM-2: LogLevel 列舉

```dart
enum LogLevel { debug, info, warning, error, fatal }
```

### DM-3: DegradationLevel 列舉

```dart
enum DegradationLevel { basicInfo, offline }
```

每個等級透過 extension 提供：`displayName`（繁體中文）、`description`（繁體中文）、`isOffline`、`isBasicInfo`、`disabledFeatures`（Set<String>）。

### DM-4: StorageType 列舉

StorageException 的儲存類型分類（file / database / cache 等）。

### DM-5: FailureType 列舉

降級系統使用的失敗類型：`networkError`、`timeout`、`quotaExhausted`、`rateLimitExceeded`、`serverError`、`clientError`、`parsingError`、`unknown`。

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 |
|------|------|
| Exception 建立時間 | < 0.1ms |
| Exception 記憶體占用 | < 200 bytes |
| 預編譯錯誤存取 | < 0.01ms（常數時間） |
| 錯誤處理路由（handleError） | < 0.5ms |
| JSON 序列化時間 | < 0.5ms |
| 日誌寫入 | 非阻塞（debug 模式 assert 輸出） |
| 降級決策 | < 5ms |
| 使用者訊息生成 | < 0.1ms |

### NFR-2: 跨平台相容

- AppException JSON 序列化格式與 Chrome Extension 保持一致
- 時間戳統一為毫秒精度 UTC（`formatTimestampToMillis`）
- 支援 `fromJson` / `toJson` 雙向轉換

### NFR-3: 可觀測性

- 所有 catch 區塊必須透過 AppLogger 記錄（CLAUDE.md 6.4 節規範）
- 空 catch 禁止
- catch 後 return 預設值時必須 `AppLogger.warningStatic()`
- 全域三層攔截確保無靜默異常

## 需求與實作差距

| 需求（app-requirements-spec / UC-09） | 實作狀態 | 差距說明 |
|---------------------------------------|---------|---------|
| 場景驅動錯誤處理（5 分類） | 已實作 | 28 ErrorCode + 5 分類例外 + 5 domain 專屬例外（36 類） |
| 使用者友善訊息 | 已實作 | ErrorCode.description + getUserMessage + FriendlyMessageGenerator |
| 自動恢復（GracefulDegradationHandler） | 已實作 | offline / basicInfo 兩級降級 |
| 漸進學習（錯誤模式分析） | **未實作** | UC-09 8A.3 要求「記錄錯誤模式和頻率」「動態調整處理策略」，目前缺少錯誤模式分析機制 |
| 統一重試策略（指數退避） | **部分實作** | UC-09 要求指數退避重試（2s, 4s, 8s），目前僅 ApiRateLimitException 含 retryAfter，缺少統一 RetryPolicy |
| 錯誤嚴重程度分級（MINOR/MODERATE/SEVERE/CRITICAL） | **未實作** | UC-09 8A.2 定義四級嚴重程度，目前僅有 isRecoverable 二元判斷 |
| 網路/檔案/相機/系統/資料錯誤 | 已實作 | 五大分類例外完整對應 |
| 降級服務 | 已實作 | GracefulDegradationHandler + DegradedModeStrategy |
| 使用者通知（情境感知） | 部分實作 | shouldNotifyUser + getUserMessage 已實作；UC-09 8C 的「情境感知通知」（首次/熟練使用者差異化）**未實作** |
| 錯誤記錄 | 已實作 | AppLogger + logError |
| 與 Chrome Extension 整合 | 已實作 | AppException JSON 序列化 |
| Domain 例外一致性 | **部分一致** | enrichment/import 繼承 core 例外；library/scanner/search 直接 implements Exception，未進入 ErrorHandler 路由 |
| 錯誤處理系統本身故障（UC-09 8c） | **未實作** | 缺少「最小化安全模式」和「緊急日誌」機制 |
| 錯誤記錄到本地資料庫（UC-09 8A.3） | **未實作** | 目前日誌僅 console 輸出，未持久化到 SQLite |
| 效能要求：偵測 < 100ms / 分類 < 5ms / 恢復 < 1s | 已實作 | Exception 建立 < 0.1ms、預編譯存取 < 0.01ms、handleError < 0.5ms |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-09: 系統錯誤處理與恢復
