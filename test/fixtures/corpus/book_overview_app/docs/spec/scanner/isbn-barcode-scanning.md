---
id: SPEC-004
title: "ISBN 條碼掃描規格"
status: draft
source_proposal: PROP-015
created: "2026-03-30"
updated: "2026-06-20"
version: "3.0"
owner: ""

domain: scanner
subdomain: null

related_usecases: [UC-03]
related_specs: [SPEC-010]
implements_requirements: []
depends_on_domains: [book_info, library]
---

# ISBN 條碼掃描規格

## 概述

定義 ISBN 條碼掃描功能的辨識規則、相機整合與掃描結果處理流程。整合 `mobile_scanner` 套件實現 EAN-13 條碼辨識，連接多來源查詢（SPEC-010）補充書目資訊。

## 與 feat/1.1.0-W2-001-qr-scan-restore 的整合

`feat/1.1.0-W2-001-qr-scan-restore` 分支已實作大部分掃描基礎設施：

| 元件 | 檔案 | 狀態 |
|------|------|------|
| `mobile_scanner` ^7.0.1 | `pubspec.yaml` | 已加入 |
| `Isbn` Value Object | `lib/domains/scanner/value_objects/isbn.dart` | 已實作（含 checksum） |
| `ISBNScannerService` | `lib/domains/scanner/services/isbn_scanner_service.dart` | 已實作（相機整合 TODO） |
| Scanner Domain 結構 | `lib/domains/scanner/` | 已建立（41 檔案） |
| `IsbnValidationService` | `lib/core/services/validation/isbn_validation_service.dart` | 已實作 |

本規格定義的是**相機 ISBN 掃描的行為規格**，實作基於上述已有元件。

## 功能需求 (FR)

### FR-1: 條碼辨識

| 項目 | 規格 |
|------|------|
| 支援格式 | EAN-13（ISBN-13 標準條碼格式） |
| 掃描套件 | `mobile_scanner` ^7.0.0+ |
| Android 後端 | CameraX + MLKit（bundled 或 unbundled） |
| iOS 後端 | AVFoundation + Apple Vision |
| 辨識時間 | < 2 秒（平均 < 1 秒） |
| 自動對焦 | 啟用 |
| 閃光燈控制 | 用戶可切換 |
| 前後鏡頭 | 預設後鏡頭，可切換 |

### FR-2: ISBN 驗證

掃描取得的數字串必須通過以下驗證（已實作於 `Isbn` Value Object）：

1. **長度檢查**：10 位或 13 位
2. **字元檢查**：純數字（ISBN-10 最後一位可為 'X'）
3. **Checksum 驗證**：
   - ISBN-13：加權和（權重交替 1/3）模 10 = 0
   - ISBN-10：加權和（權重 10 到 1）模 11 = 0
4. **ISBN-10 -> ISBN-13 轉換**：`978` + 前 9 位 + 重新計算 check digit
5. **978/979 prefix 語意檢查**（非書籍 EAN-13 判定）：
   - 13 位且 checksum 通過，但開頭非 `978` 或 `979` → 判定為「有效 EAN-13 但非書籍條碼」（如商品條碼）
   - 此判定在本地完成，不需網路
   - 判定為非書籍條碼時，不進入後續建立書籍與 API 查詢流程（見 FR-3 分支）

### FR-3: 掃描流程

```
用戶按「掃描新增」
  -> 檢查相機權限（FR-4）
  -> 開啟 MobileScannerController
  -> 畫面顯示相機預覽 + 掃描框
  -> 偵測到 EAN-13 條碼
  -> 提取數字串
  -> 978/979 prefix 語意檢查（FR-2 規則 5）
  -> 非 978/979 開頭（非書籍 EAN-13）：
       - 本地判定，不送 API 查詢、不建立書籍
       - 顯示明確提示：「此條碼非書籍 ISBN，請掃描書背 ISBN 條碼」
       - 維持掃描狀態，用戶可繼續掃描或選擇手動輸入
  -> 978/979 開頭：Isbn.fromString() 驗證
  -> 驗證通過：震動回饋 + 關閉掃描
  -> ISBNScannerService.processScannedISBN()
  -> 立即建立書籍（ISBN 作暫時書名）
  -> 背景透過 IsbnRegionRouter（SPEC-010）查詢補充資訊
  -> 書庫 UI 即時更新
```

### FR-4: 相機權限管理

| 情境 | 行為 |
|------|------|
| 首次使用 | 顯示權限說明 -> 請求權限 |
| 用戶拒絕 | 顯示「手動輸入 ISBN」替代方案 + 引導到系統設定 |
| 權限已授權 | 直接開啟掃描 |
| 權限被撤銷 | 下次使用時重新請求 |

### FR-5: 手動 ISBN 輸入（fallback）

| 項目 | 規格 |
|------|------|
| 輸入欄位 | 支援 ISBN-10 和 ISBN-13 |
| 自動清理 | 移除連字符號、空白 |
| 即時驗證 | 輸入時即時顯示格式是否有效 |
| Checksum 回饋 | 驗證失敗時顯示「ISBN 格式無效」 |
| 確認送出 | 驗證通過後啟用「新增」按鈕 |

### FR-6: 重複檢測

掃描或手動輸入 ISBN 後，查詢本地書庫是否已有相同 ISBN：

| 情境 | 行為 |
|------|------|
| 書庫無此 ISBN | 正常新增流程 |
| 書庫已有此 ISBN | 顯示已存在書籍資訊，提供「查看書籍」或「更新資訊」選項 |

### FR-7: 離線掃描

| 情境 | 行為 |
|------|------|
| 無網路 | 掃描仍可運作（本地 ISBN 驗證） |
| 書籍建立 | 以 ISBN 作暫時書名加入書庫，標記 `source_type = physical` |
| 背景補充 | 加入離線同步佇列（`SyncRepository.addToOfflineQueue`），恢復網路後自動補充 |

## 業務規則 (BR)

### BR-1: ISBN 標準化

所有 ISBN 在系統內部統一以 **ISBN-13** 格式儲存和比較。

| 規則 | 說明 |
|------|------|
| 儲存格式 | 一律 ISBN-13（不含連字符號） |
| ISBN-10 輸入 | 自動透過 `Isbn.toIsbn13()` 轉換為 ISBN-13 |
| 相等比較 | 兩個 ISBN 相等當且僅當其 ISBN-13 標準化形式相同 |
| 清理規則 | 移除所有非數字字符（僅 ISBN-10 末位保留 'X'） |

### BR-2: 書籍建立規則

| 規則 | 說明 |
|------|------|
| 暫時書名 | 格式為 `ISBN: {isbn13}`，離線模式為 `ISBN: {isbn13} (離線模式)` |
| 暫時作者 | `Unknown`（Use Case 層）或 `Unknown Author`（Domain Service 層） |
| 來源類型 | `source_type = physical`（實體書） |
| 書籍 ID | Use Case 層由 Repository 產生；Domain Service 層為 `book-{timestamp}` |
| 唯一性約束 | 同一 ISBN 不可重複建立（以 ISBN-13 為 key 查詢） |

### BR-3: 資訊補充規則

| 規則 | 說明 |
|------|------|
| 非阻塞 | 查詢失敗不影響書籍已在書庫中的存在 |
| 合併策略 | 保留已有資訊，只補充空缺欄位 |
| 例外安全 | 補充服務捕獲所有異常，失敗時返回原始書籍 |
| 多來源路由 | 依 ISBN prefix 選擇 API 優先順序（SPEC-010 FR-3） |
| 降級機制 | 主 API 失敗自動 fallback 到下一個來源（SPEC-010 FR-4） |
| 作者/出版社寫入 | PROP-007 tag model 終態：author、publisher 以 BookTag 承載（非 Book 直接欄位） |

### BR-4: 掃描超時與重試

| 規則 | 說明 |
|------|------|
| 掃描逾時 | 30 秒無成功辨識即超時 |
| 超時行為 | 停止掃描、顯示「掃描逾時，請重新嘗試」 |
| 重新掃描 | 用戶可選擇重新掃描或手動輸入 |

### BR-5: 掃描狀態轉移

```
initial -> permissionDenied  （權限被拒）
initial -> ready             （權限已授予）
ready -> scanning            （開始掃描）
ready -> manualInput         （用戶選擇手動輸入）
scanning -> scanned          （掃描成功）
scanning -> error            （掃描失敗/逾時）
scanned -> ready             （重置/重新掃描）
manualInput -> scanned       （手動輸入確認）
manualInput -> ready         （取消手動輸入）
error -> ready               （重置）
```

## 介面契約

### Use Case 層

#### ScanIsbnBarcodeUseCase

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/use_cases/scanner/scan_isbn_barcode_usecase.dart` |
| 依賴 | `CameraPermissionService`, `IsbnScannerRepository` |

```dart
class ScanIsbnBarcodeUseCase {
  ScanIsbnBarcodeUseCase({
    required CameraPermissionService permissionService,
    required IsbnScannerRepository scannerRepository,
  });

  Future<ScanResult> execute();
  Future<void> stopScanning();
  Stream<ScanResult> get scanStream;
}
```

| 方法 | 參數 | 回傳 | 異常 |
|------|------|------|------|
| `execute()` | 無 | `Future<ScanResult>` | `PlatformException(permissionDenied)` 當權限被拒絕 |
| `stopScanning()` | 無 | `Future<void>` | 無 |
| `scanStream` | getter | `Stream<ScanResult>` | 無 |

#### CreateBookFromIsbnUseCase

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/use_cases/scanner/create_book_from_isbn_usecase.dart` |
| 依賴 | `BookRepository` |

```dart
class CreateBookFromIsbnUseCase {
  CreateBookFromIsbnUseCase({required BookRepository bookRepository});

  Future<Book> execute(Isbn isbn);
  Future<bool> isbnExists(Isbn isbn);
}
```

| 方法 | 參數 | 回傳 | 異常 |
|------|------|------|------|
| `execute(isbn)` | `Isbn` | `Future<Book>` | `BusinessException(duplicateBook)` 當 ISBN 已存在 |
| `isbnExists(isbn)` | `Isbn` | `Future<bool>` | 無 |

#### EnrichBookByIsbnUseCase

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/use_cases/scanner/enrich_book_by_isbn_usecase.dart` |
| 依賴 | `MultiSourceQueryService`, `BookRepository` |

```dart
class EnrichBookByIsbnUseCase {
  EnrichBookByIsbnUseCase({
    required MultiSourceQueryService multiSourceQueryService,
    required BookRepository bookRepository,
  });

  Future<Book> execute(Isbn isbn, String bookId);
  Future<Book> enrichBook(Book book);
}
```

| 方法 | 參數 | 回傳 | 異常 |
|------|------|------|------|
| `execute(isbn, bookId)` | `Isbn`, `String` | `Future<Book>` | 不拋出異常（失敗返回原始書籍） |
| `enrichBook(book)` | `Book` | `Future<Book>` | 不拋出異常 |

#### ManualInputIsbnUseCase

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/use_cases/scanner/manual_input_isbn_usecase.dart` |
| 依賴 | 無（純邏輯） |

```dart
class ManualInputIsbnUseCase {
  Future<Isbn> execute(String rawIsbn);
  bool validate(String rawIsbn);
  String getIsbn13(Isbn isbn);
}
```

| 方法 | 參數 | 回傳 | 異常 |
|------|------|------|------|
| `execute(rawIsbn)` | `String` | `Future<Isbn>` | `ValidationException` 當格式無效 |
| `validate(rawIsbn)` | `String` | `bool` | 無（內部捕獲） |
| `getIsbn13(isbn)` | `Isbn` | `String` | 無 |

### Domain 層

#### IsbnScannerRepository（抽象介面）

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/repositories/isbn_scanner_repository.dart` |
| 層級 | Domain（介面定義），Infrastructure（實作） |

```dart
abstract class IsbnScannerRepository {
  Future<ScanResult> scanBarcode();
  Future<void> stopScanning();
  Stream<ScanResult> get scanStream;
}
```

| 方法 | 回傳 | 異常 |
|------|------|------|
| `scanBarcode()` | `Future<ScanResult>` | `CameraPermissionDeniedException`, `ScanTimeoutException`, `ScanCancelledException`, `InvalidBarcodeException` |
| `stopScanning()` | `Future<void>` | 無 |
| `scanStream` | `Stream<ScanResult>` | 無 |

#### CameraPermissionService（抽象介面）

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/services/camera_permission_service.dart` |
| 層級 | Domain（介面定義） |

```dart
abstract class CameraPermissionService {
  Future<bool> requestPermission();
  Future<bool> checkPermission();
  Future<bool> openSettings();
}
```

| 方法 | 回傳 | 異常 |
|------|------|------|
| `requestPermission()` | `Future<bool>` | `PermissionPermanentlyDeniedException` |
| `checkPermission()` | `Future<bool>` | 無 |
| `openSettings()` | `Future<bool>` | 無 |

#### ISBNScannerService（Domain Service）

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/services/isbn_scanner_service.dart` |
| 依賴 | `BookRepository`, `SyncRepository`, `ISBNBookEnrichmentService`, `IsbnValidationService` |

```dart
class ISBNScannerService {
  ISBNScannerService({
    required BookRepository bookRepository,
    required SyncRepository syncRepository,
    required ISBNBookEnrichmentService enrichmentService,
    IsbnValidationService? isbnValidator,
  });

  bool validateISBN(String isbn);
  Future<BookCreationResult> processScannedISBN(String isbn);
  Future<ScanResult> startScanning();       // [TODO] 相機整合
  Future<void> stopScanning();              // [TODO] 相機整合
  Stream<ScanResult> startBatchScanning();  // [TODO] 批次掃描
  bool get isScanning;
}
```

| 方法 | 參數 | 回傳 | 說明 |
|------|------|------|------|
| `validateISBN(isbn)` | `String` | `bool` | 驗證 ISBN 格式 |
| `processScannedISBN(isbn)` | `String` | `Future<BookCreationResult>` | 完整掃描處理流程（驗證 -> 重複檢測 -> 建立 -> 背景補充） |
| `startScanning()` | 無 | `Future<ScanResult>` | [TODO] 相機掃描（尚未整合 mobile_scanner） |
| `stopScanning()` | 無 | `Future<void>` | [TODO] 停止掃描 |
| `startBatchScanning()` | 無 | `Stream<ScanResult>` | [TODO] 批次掃描 |

#### ISBNBookEnrichmentService（抽象介面）

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/services/isbn_book_enrichment_service.dart` |
| 層級 | Domain（介面定義） |

```dart
abstract class ISBNBookEnrichmentService {
  Future<BookEnrichmentData?> enrichByISBN(String isbn);
  Future<List<BookEnrichmentData?>> batchEnrichByISBN(List<String> isbns);
}
```

### Infrastructure 層

#### MultiSourceQueryService

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/infrastructure/multi_source/multi_source_query_service.dart` |
| 依賴 | `Map<BookInfoSource, ApiSourceClient>`, `CircuitBreakerRegistry`, `QueryResultCache` |

```dart
class MultiSourceQueryService {
  MultiSourceQueryService({
    required Map<BookInfoSource, ApiSourceClient> clients,
    required CircuitBreakerRegistry circuitBreakers,
    required QueryResultCache cache,
  });

  Future<MultiSourceQueryResult> queryByIsbn(String isbn);
}
```

| 常數 | 值 | 說明 |
|------|-----|------|
| `_perApiTimeout` | 5 秒 | 單一 API 查詢逾時 |
| `_overallTimeout` | 15 秒 | 整體查詢逾時 |

#### ApiSourceClient（抽象介面）

```dart
abstract class ApiSourceClient {
  Future<BookEnrichmentData?> queryByIsbn(String isbn);
}
```

#### CircuitBreakerRegistry

```dart
class CircuitBreakerRegistry {
  CircuitBreakerRegistry({int failureThreshold = 3, Duration recoveryDuration = Duration(minutes: 5)});

  bool isOpen(BookInfoSource source);
  void recordSuccess(BookInfoSource source);
  void recordFailure(BookInfoSource source);
  void reset();
}
```

#### QueryResultCache

```dart
class QueryResultCache {
  QueryResultCache({int maxSize = 500});

  BookEnrichmentData? get(String isbn);
  void put(String isbn, BookEnrichmentData data, Duration ttl);
  void clear();
  int get size;
}
```

### Presentation 層

#### IsbnScannerViewModel

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/presentation/scanner/isbn_scanner_view_model.dart` |
| 基底類別 | `Notifier<IsbnScannerState>`（Riverpod 3.0） |
| 依賴 | `BookService`, `CameraService`, `IsbnValidationService`（透過 `ref.watch()` DI） |

```dart
class IsbnScannerViewModel extends Notifier<IsbnScannerState> {
  IsbnScannerState build();
  Future<void> checkCameraPermission();
  Future<void> requestCameraPermission();
  Future<void> startScanning();
  Future<void> stopScanning();
  void showManualInput();
  void updateManualInput(String value);
  void confirmManualInput();
  void cancelManualInput();
  Future<void> addBookToLibrary();
  void resetToReady();
  Future<void> rescan();
}
```

#### IsbnScannerState

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/presentation/scanner/isbn_scanner_state.dart` |
| 基底類別 | `Equatable` |

| 欄位 | 型別 | 預設值 | 說明 |
|------|------|--------|------|
| `status` | `IsbnScannerStatus` | `initial` | 掃描狀態 |
| `scannedIsbn` | `String?` | `null` | 掃描到的 ISBN |
| `hasPermission` | `bool` | `false` | 相機權限狀態 |
| `errorMessage` | `String?` | `null` | 錯誤訊息 |
| `manualInputValue` | `String?` | `null` | 手動輸入值 |
| `manualInputError` | `String?` | `null` | 手動輸入驗證錯誤 |

| 狀態查詢 | 說明 |
|---------|------|
| `canStartScanning` | `hasPermission && !isScanning && !isManualInput` |
| `canStopScanning` | `isScanning` |
| `canManualInput` | `hasPermission && !isScanning` |
| `canAddToLibrary` | `hasResult && errorMessage == null` |

## 資料模型

### Isbn Value Object

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/value_objects/isbn.dart` |
| 特性 | 不可變、建立時驗證、相等性基於 ISBN-13 |

| 欄位/方法 | 型別 | 說明 |
|-----------|------|------|
| `value` | `String` | 清理後的 ISBN 字串（純數字） |
| `type` | `IsbnType` | `isbn10` 或 `isbn13` |
| `toIsbn13()` | `String` | 轉換為 ISBN-13 格式 |
| `standardized` | `String` | 等同 `toIsbn13()` |
| `formatted` | `String` | 含連字符號格式（`978-X-XXX-XXXXX-X`） |
| `fromString(raw)` | factory | 清理 + 驗證 + 建立，無效時拋 `ValidationException` |

### ScanResult Entity

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/entities/scan_result.dart` |
| 特性 | 不可變、工廠方法建立 |

| 欄位 | 型別 | 說明 |
|------|------|------|
| `isbn` | `Isbn?` | 掃描到的 ISBN（失敗時為 null） |
| `status` | `ScanStatus` | `scanSuccess` 或 `scanFailed` |
| `scannedAt` | `DateTime` | 掃描時間 |
| `method` | `ScanMethod` | `camera` 或 `manual` |
| `errorMessage` | `String?` | 錯誤訊息（成功時為 null） |

| 工廠方法 | 說明 |
|---------|------|
| `ScanResult.success({isbn, scannedAt?, method?})` | 建立成功結果 |
| `ScanResult.failure({errorMessage, scannedAt?, method?})` | 建立失敗結果 |

### BookCreationResult Model

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/scanner/models/book_creation_result.dart` |
| 特性 | 掃描後書籍建立的狀態封裝 |

| 欄位 | 型別 | 說明 |
|------|------|------|
| `bookId` | `String` | 書籍 ID |
| `status` | `BookCreationStatus` | 建立狀態 |
| `createdBook` | `Book?` | 新建立的書籍 |
| `existingBook` | `Book?` | 已存在的書籍（重複時） |
| `error` | `AppException?` | 錯誤資訊 |
| `enrichedBook` | `Future<Book?>?` | 背景補充結果的 Future |

| 狀態 | 說明 |
|------|------|
| `created` | 成功建立新書籍 |
| `duplicate` | 書庫已有此 ISBN |
| `failed` | 建立失敗 |
| `offline` | 離線模式建立 |

### BookEnrichmentData

| 項目 | 說明 |
|------|------|
| 檔案 | `lib/domains/book_info/entities/book_enrichment_data.dart` |
| 特性 | Domain 層統一的豐富化資料，API 中性 |

| 欄位 | 型別 | 說明 |
|------|------|------|
| `googleBooksId` | `String` | 來源 ID |
| `title` | `String` | 書名 |
| `authors` | `List<String>` | 作者列表 |
| `publisher` | `String?` | 出版社 |
| `publishedDate` | `String?` | 出版日期 |
| `description` | `String?` | 描述 |
| `isbn10` | `String?` | ISBN-10 |
| `isbn13` | `String?` | ISBN-13 |
| `pageCount` | `int?` | 頁數 |
| `categories` | `List<String>` | 分類 |
| `averageRating` | `double?` | 平均評分 |
| `ratingsCount` | `int?` | 評分數 |
| `language` | `String?` | 語言 |
| `imageLinks` | `Map<String, String>` | 圖片連結 |
| `previewLink` | `String?` | 預覽連結 |
| `infoLink` | `String?` | 資訊連結 |

### MultiSourceQueryResult

| 欄位 | 型別 | 說明 |
|------|------|------|
| `data` | `BookEnrichmentData?` | 查詢結果 |
| `source` | `BookInfoSource?` | 資料來源 |
| `isCacheHit` | `bool` | 是否快取命中 |

### 列舉型別

| 列舉 | 檔案 | 值 |
|------|------|-----|
| `IsbnType` | `isbn.dart` | `isbn10`, `isbn13` |
| `ScanStatus` | `enums/scan_status.dart` | `idle`, `requestingPermission`, `permissionGranted`, `permissionDenied`, `scanning`, `scanSuccess`, `scanFailed`, `processing` |
| `ScanMethod` | `entities/scan_result.dart` | `camera`, `manual` |
| `EnrichmentStatus` | `enums/enrichment_status.dart` | `notStarted`, `inProgress`, `completed`, `failed`, `partial` |
| `InputSource` | `enums/input_source.dart` | `camera`, `manual`, `file` |
| `NetworkStatus` | `enums/network_status.dart` | `online`, `offline`, `unknown` |
| `PermissionStatus` | `enums/permission_status.dart` | `granted`, `denied`, `permanentlyDenied`, `restricted` |
| `ScanType` | `enums/scan_type.dart` | `barcode`, `qrCode`, `isbn`, `auto` |
| `BookCreationStatus` | `models/book_creation_result.dart` | `created`, `duplicate`, `failed`, `offline` |
| `IsbnScannerStatus` | `isbn_scanner_state.dart` | `initial`, `permissionDenied`, `ready`, `scanning`, `scanned`, `error`, `manualInput` |
| `BookInfoSource` | `book_info/value_objects/book_info_source.dart` | `nbinet`, `googleBooks`, `openLibrary` |

### 異常類別

| 異常 | 檔案 | 觸發場景 |
|------|------|---------|
| `CameraHardwareException` | `exceptions/camera_hardware_exception.dart` | 相機硬體故障 |
| `BarcodeDetectionException` | `exceptions/barcode_detection_exception.dart` | 條碼辨識失敗 |
| `InvalidBarcodeDataException` | `exceptions/invalid_barcode_data_exception.dart` | 條碼資料無效 |
| `InvalidScanTaskIdException` | `exceptions/invalid_scan_task_id_exception.dart` | 掃描任務 ID 無效 |
| `ValidationException` | `core/errors/errors.dart` | ISBN 格式驗證失敗 |
| `BusinessException` | `core/errors/errors.dart` | 重複 ISBN、書籍未找到 |
| `PlatformException` | `core/errors/errors.dart` | 相機權限被拒絕 |
| `NetworkException` | `core/errors/errors.dart` | 網路連線失敗 |

## 非功能需求 (NFR)

### NFR-1: 效能

| 指標 | 目標 |
|------|------|
| 條碼辨識時間 | < 2 秒（平均 < 1 秒） |
| 書籍立即顯示 | < 100ms（不等 API 回傳） |
| 相機啟動時間 | < 1 秒 |
| 掃描幀率 | 每 100ms 處理一幀（10fps） |
| 掃描逾時 | 30 秒 |

### NFR-2: APP 體積影響

| 方案 | 體積增加 | 優缺點 |
|------|---------|-------|
| Bundled MLKit | +3-10MB | 離線可用，無需 Google Play Services |
| Unbundled MLKit | +600KB | 需 Google Play Services 下載模型 |

建議 Android 使用 unbundled（減少 APK 體積），iOS 無此選擇（直接用 AVFoundation）。

### NFR-3: 可觀測性

```dart
AppLogger.infoStatic('Barcode detected: type=$format, value=$rawValue', 'ScannerPage');
AppLogger.infoStatic('ISBN validated: $isbn, type=${isbn.type}', 'ISBNScannerService');
AppLogger.warningStatic('ISBN checksum failed: $rawValue', 'Isbn');
```

## 需求與實作差距分析

| 項目 | 需求（UC-03 / app-requirements-spec） | 實作狀態 | 差距 |
|------|---------------------------------------|---------|------|
| 相機掃描整合 | 使用 mobile_scanner 掃描 ISBN 條碼 | `ISBNScannerService.startScanning()` 標記 TODO，拋出 `UnimplementedError` | **未實作**：相機整合邏輯待完成 |
| 批次掃描 | UC-03 未要求，但 Service 有定義 | `startBatchScanning()` 拋出 `UnimplementedError` | **未實作**：可延後 |
| 掃描失敗診斷 | UC-03 替代流程 2a 要求診斷（光線不足/角度/損壞） | `ScanFailureDiagnostics` service 存在但未串接 | **未串接** |
| 離線同步恢復 | UC-03 替代流程 3b7 要求網路恢復時主動通知 | `OfflineSyncService`、`NetworkStatusMonitor` 存在但串接狀態待確認 | **待確認** |
| 重複書籍合併 | UC-03 替代流程 4a5 提供「合併最佳資訊」選項 | `CreateBookFromIsbnUseCase` 只支援拋 `duplicateBook` 異常 | **部分實作**：缺合併選項 |
| ViewModel 新增流程 | 掃描後立即建立 + 背景補充 | `IsbnScannerViewModel.addBookToLibrary()` 走 `BookService.searchByIsbn` 再 `addBook` | **差異**：ViewModel 先查 API 再新增（非立即新增），與 UC-03「立即新增」需求不一致 |
| ISBN 驗證多軌 | 統一使用 `Isbn` Value Object | `IsbnValidationService`、`Isbn` VO、`IsbnUtils` 三套並存 | **冗餘**：三套 ISBN 驗證邏輯需統一 |
| 掃描指標收集 | 效能監控 | `ScanMetricsCollector` service 存在 | **待確認串接** |

### 關鍵差距說明

1. **ViewModel 與 UC-03 流程不一致**：`IsbnScannerViewModel.addBookToLibrary()` 先呼叫 `BookService.searchByIsbn()` 查詢 API，成功後才新增書籍。UC-03 要求「立即新增（ISBN 作暫時書名），背景補充」。`ISBNScannerService.processScannedISBN()` 的實作符合 UC-03 需求，但 ViewModel 未使用此 Service。

2. **ISBN 驗證三軌並存**：`Isbn` Value Object（Scanner Domain）、`IsbnValidationService`（Core）、`IsbnUtils`（Version Management）三者功能重疊，需統一入口。

3. **相機硬體整合**：`ISBNScannerService.startScanning()` 和 `stopScanning()` 都標記 TODO，實際相機整合尚未完成。

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。

## 相關用例

- UC-03: ISBN 條碼掃描新增書籍

## 相關規格

- SPEC-010: ISBN 多來源查詢規格（掃描後的 API 查詢路由）

## 版本記錄

- 2026-07-16：FR-2 新增 978/979 prefix 語意檢查條款、FR-3 新增非書籍 EAN-13 本地判定分支（0.38.1-W1-092）
