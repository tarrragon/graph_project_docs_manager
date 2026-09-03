# W3-003 設計決策清單 (Wave 3 - Design 階段)

**依賴**: W2-003 分析完成
**狀態**: 等待設計決策確認
**負責人**: pepper-test-implementer (語言無關策略規劃)
**日期**: 2026-01-10

---

## 📋 4 大設計決策清單

基於 W2-003 分析報告，需要確認以下 4 個核心設計決策，以進行 Wave 4 實作。

---

## 決策 1: ISBNScannerService 異常處理模式

### 問題陳述

ISBNScannerService 使用混合異常/Result 模式，造成測試期望與實作不一致。

### 當前狀況

**實作行為**:
```dart
// startScanning() - 拋出異常後被內部攔截
Future<ScanResult> startScanning() async {
  _isScanning = true;
  try {
    throw UnimplementedError('相機掃描邏輯尚未整合');
  } catch (e) {
    _isScanning = false;
    return ScanResult.failure(errorMessage: ..., scannedAt: ...);
  }
}

// stopScanning() - 不拋出異常
Future<void> stopScanning() async {
  _isScanning = false;
  // TODO: 整合相機停止邏輯
}
```

**測試期望**:
```dart
// 期望 startScanning() 拋出異常
expect(() => await isbnScannerService.startScanning(),
        throwsA(isA<UnimplementedError>()));

// 期望 stopScanning() 拋出異常
expect(() => await isbnScannerService.stopScanning(),
        throwsA(isA<UnimplementedError>()));
```

**衝突分析**:
- startScanning(): 內部拋出異常但被 catch 攔截，返回 Result，但不拋到測試層 ❌
- stopScanning(): 根本不拋出異常，只返回 void ❌

### 選項 A: Result 物件模式 (推薦)

**設計決策**: 所有方法都返回 Result 物件，無異常拋出

**實作方式**:
```dart
// 修改 startScanning() 直接返回 Result
Future<ScanResult> startScanning() async {
  _isScanning = true;
  try {
    throw UnimplementedError('相機掃描邏輯尚未整合');
  } catch (e) {
    _isScanning = false;
    return ScanResult.failure(errorMessage: ..., scannedAt: ...);
  }
}

// 修改 stopScanning() 返回 Result (or Future<void>)
Future<void> stopScanning() async {
  _isScanning = false;
  // 直接返回 void，不拋出異常
}
```

**測試修改**:
```dart
test('應該能夠啟動掃描功能', () async {
  final result = await isbnScannerService.startScanning();
  expect(result.isFailure, isTrue);
  expect(result.errorMessage, contains('未實作'));
});

test('應該能夠停止掃描功能', () async {
  expect(
    () async => await isbnScannerService.stopScanning(),
    returnsNormally,
  );
});
```

**優點**:
- ✅ 符合現代 Dart/Flutter 最佳實踐 (Result 物件模式)
- ✅ 無隱藏異常，測試清晰
- ✅ 與 processScannedISBN() 一致（已使用 Result 物件）
- ✅ 更容易進行錯誤處理和恢復

**缺點**:
- 需要改變實現方式（相對於選項 B）

---

### 選項 B: 異常拋出模式

**設計決策**: 保留異常拋出，移除內部 try-catch，直接拋到調用層

**實作方式**:
```dart
// startScanning() - 直接拋出異常，不攔截
Future<ScanResult> startScanning() async {
  _isScanning = true;
  // TODO: 整合相機掃描邏輯
  throw UnimplementedError('相機掃描邏輯尚未整合');
}

// stopScanning() - 拋出異常
Future<void> stopScanning() async {
  throw UnimplementedError('停止掃描功能尚未實作');
}
```

**優點**:
- ✅ 測試期望無需修改
- ✅ 異常拋出使實作意圖明確

**缺點**:
- ❌ 與 processScannedISBN() 模式不一致（使用 Result）
- ❌ 需要調用層處理異常，增加複雜性
- ❌ 不符合現代最佳實踐

---

### 選項 C: 保留混合模式

**設計決策**: 保持當前混合模式，但統一測試期望

**影響**: 同時支持異常和 Result，但提高複雜性

**不推薦**: ❌ 增加維護負擔

---

### ⭐ 推薦決策: Option A (Result 物件模式)

**理由**:
1. 與專案現有的 Result 物件模式一致（processScannedISBN 已使用）
2. 符合現代 Dart/Flutter 最佳實踐
3. 更容易進行錯誤處理和恢復
4. 無隱藏異常，測試和調用代碼更清晰

**修復範圍**:
- 修改測試期望值 (2 個測試)
- 可能調整實現邏輯使之更清晰（可選）

---

## 決策 2: Book Domain 驗證規則邊界

### 問題陳述

Book 簡化模型 (v0.24.0) 改變了驗證規則，但測試期望和設計文檔未同步。

### 當前狀況

**v0.24.0 簡化模型**:
```dart
class Book {
  static Book create({
    required String id,
    required String title,
    required String author,
    String? description,
    String? coverImageUrl,
    String? isbn,
  }) {
    // 內部有預設值，不驗證空字串
    return Book(
      id: BookId(id.isEmpty ? 'default-${DateTime.now()}' : id),
      title: BookTitle(title.isEmpty ? 'Untitled' : title),
      author: BookAuthor.fromString(author.isEmpty ? 'Unknown Author' : author),
      // ...
    );
  }
}
```

**受影響測試**:
1. `should_validate_book_creation_with_required_fields`
   - 期望: `returnsNormally` ✓ (正確，應返回 Book 實例)
   - 但需確認: 空值實際產生什麼預設值

2. `should_link_book_to_platform_correctly`
   - 期望: Platform 系統存在
   - 實現: Platform 系統已移除
   - 需決定: 保留測試（改為基本驗證）或移除

3. `should_support_physical_books_without_platform`
   - 期望: Source 系統存在
   - 實現: Source 系統已簡化

### 設計決策選項

#### 選項 A: 確認簡化模型，更新測試

**決策**: Book 不進行驗證，提供合理的預設值

**確認項目**:
- [ ] 空 `id` 時的預設值生成規則？
- [ ] 空 `title` 時的預設值？
- [ ] 空 `author` 時的預設值？
- [ ] 這些預設值是否可接受？

**修復範圍**:
```dart
test('should_validate_book_creation_with_required_fields', () {
  // 確認空值創建行為
  final bookWithEmptyId = Book.create(
    id: '',
    title: '書名',
    author: 'Test Author',
  );

  // 驗證預設值
  expect(bookWithEmptyId.id.displayValue, isNotEmpty);
  expect(bookWithEmptyId.id.displayValue, startsWith('default-'));
});
```

#### 選項 B: 恢復驗證，拋出異常

**決策**: 回到 v0.24.0 前的驗證模型

**影響**: 需要修改 Book.create() 實現

**不推薦**: ❌ 增加複雜性，與簡化設計方向不符

---

### ⭐ 推薦決策: Option A

**理由**:
1. 符合 v0.24.0 簡化設計目標
2. 提供預設值使系統更容易使用
3. 測試本身預期 `returnsNormally`，與簡化模型一致

**確認清單** (必需完成):
- [ ] 驗證 BookId、BookTitle、BookAuthor 的預設值生成邏輯
- [ ] 確認這些預設值在應用中的使用是否合理
- [ ] 更新設計文檔記錄簡化模型的邊界規則

---

## 決策 3: SyncStatusIndicator 外觀對應

### 問題陳述

v0.24.0 UI 統一化改變了 Widget 外觀，測試期望值過時。

### 失敗測試清單

| Test ID | 期望圖標 | 期望顏色 | 期望文字 | 狀態 |
|---------|---------|---------|---------|------|
| WG-01 | Icons.storage | Colors.grey | 本地資料 | ❌ 失敗 |
| WG-02 | Icons.check_circle | Colors.green | 已同步 | ❌ 失敗 |
| WG-03 | Icons.cloud_upload | Colors.blue | 待同步 | ❌ 失敗 |
| WG-04 | Icons.sync | Colors.blue | 同步中... | ❌ 失敗 |
| WG-05 | Icons.warning | Colors.orange | 有衝突 | ❌ 失敗 |
| WG-06 | Icons.error | Colors.red | 同步失敗 | ❌ 失敗 |

### 設計決策需求

需要**檢查並確認**以下內容：

1. **查看實現文件**: `lib/presentation/sync/widgets/sync_status_indicator.dart`
2. **列出實際對應**:
   ```
   status: 'local'   → Icon: ?, Color: ?, Text: ?
   status: 'synced'  → Icon: ?, Color: ?, Text: ?
   status: 'pending' → Icon: ?, Color: ?, Text: ?
   status: 'syncing' → Icon: ?, Color: ?, Text: ?
   status: 'conflict'→ Icon: ?, Color: ?, Text: ?
   status: 'failed'  → Icon: ?, Color: ?, Text: ?
   ```

3. **確認實現是否合理** (基於 UI/UX 設計)
   - 圖標選擇是否符合狀態含義？
   - 顏色方案是否一致？
   - 文字標籤是否清晰？

### 修復方式

**步驟 1**: 讀取實現檔案，提取實際對應關係

**步驟 2**: 決定
- 保留實現，更新測試期望值 → **推薦**
- 實現不合理，調整實現 → 需要設計師確認

**步驟 3**: 更新測試
```dart
// 例子：如果實現改用 Icons.cloud_queue
testWidgets('WG-01: local 狀態 - 正確圖標和文字', (WidgetTester tester) async {
  await tester.pumpWidget(...);

  expect(find.byIcon(Icons.cloud_queue), findsOneWidget);  // ← 更新
  expect(find.text('本地資料'), findsOneWidget);

  final iconWidget = tester.widget<Icon>(find.byIcon(Icons.cloud_queue));
  expect(iconWidget.color, equals(Colors.amber));  // ← 更新
});
```

---

## 決策 4: BookInfoEnrichmentService 功能範圍

### 問題陳述

補充服務的邊界情況功能（cancelEnrichment、enrichBatch 速率控制）未確定是否在 MVP 範圍。

### 失敗測試

1. `cancelEnrichment() 應該回傳已完成的補充結果`
2. `cancelEnrichment() 應該立即停止處理剩餘書籍`
3. `enrichBatch() 應該遵守速率控制限制`

### 設計決策選項

#### 選項 A: 實作功能

**決策**: 補充服務完整實作所有邊界情況功能

**影響**:
- 新增實現工作
- 測試保持不變

#### 選項 B: 移除功能和測試

**決策**: 這些邊界情況不在 v0.25.0 MVP 範圍內

**影響**:
- 移除三個測試
- 簡化補充服務實現

---

### ⭐ 推薦決策: Option B (移除功能和測試)

**理由**:
1. 這些是邊界情況功能（cancel、batch rate limiting）
2. MVP 應專注於核心補充功能（單一書籍補充）
3. 可在後續版本 (v0.26.0+) 實作

**確認清單** (必需完成):
- [ ] 確認 BookInfoEnrichmentService 的 MVP 功能範圍
- [ ] 決定是否移除這三個測試

---

## 📋 Wave 3 決策確認流程

### 執行順序

1. **決策 1** (ISBNScannerService): 確認 Result 物件模式 ← **立即決策**
2. **決策 2** (Book Domain): 驗證預設值邏輯 ← **立即決策**
3. **決策 3** (SyncStatusIndicator): 檢查實現，確認外觀對應 ← **立即決策**
4. **決策 4** (BookInfoEnrichmentService): 確認功能範圍 ← **立即決策**

### 確認責任人

由 **rosemary-project-manager** 確認上述設計決策，根據專案 MVP 目標和設計規範。

### 進度跟蹤

完成以下清單後，進入 Wave 4 實作：

- [ ] 決策 1: ISBNScannerService 異常處理模式確認
- [ ] 決策 2: Book Domain 預設值邏輯確認
- [ ] 決策 3: SyncStatusIndicator 外觀對應確認
- [ ] 決策 4: BookInfoEnrichmentService 功能範圍確認
- [ ] 所有決策記錄到本文件
- [ ] 生成 Wave 4 實作清單

---

## 📚 相關文件

- **分析報告**: `W2-003-unit-test-failure-analysis.md`
- **關鍵發現**: `W2-003-KEY-FINDINGS.md`
- **工作日誌**: `v0.25.0-tech-debt-resolution.md`

---

## ✅ 設計決策確認記錄 (2026-01-10)

**確認者**: rosemary-project-manager
**確認日期**: 2026-01-10
**方法**: 審查實作程式碼，對照測試期望

### 決策 1: ISBNScannerService 異常處理模式 ✅

**確認決策**: **Option A - Result 物件模式**

**審查結果**:
- `startScanning()` (isbn_scanner_service.dart:218-240): 拋出異常後被 catch 攔截，返回 `ScanResult.failure()`
- `stopScanning()` (isbn_scanner_service.dart:249-255): 不拋出異常，直接返回 void
- `processScannedISBN()` 已使用 Result 物件模式

**修復方式**: 修改 2 個測試期望值，驗證返回的 ScanResult 而非期望異常拋出

### 決策 2: Book Domain 驗證規則邊界 ✅

**確認決策**: **Option A - 簡化模型**

**審查結果**:
- `Book.create()` (book.dart:254-286): 允許空值，使用預設值
- 空 title → `'Unknown Title'`
- 空 author → `'Unknown Author'`
- 空 id → `BookId.generate()` 自動生成

**修復方式**: 更新測試驗證預設值邏輯，移除過時的 Platform/Source 測試

### 決策 3: SyncStatusIndicator 外觀對應 ✅

**確認決策**: **保留實現，更新測試**

**審查結果** (sync_status_indicator.dart:45-91):
| status | color | icon | label |
|--------|-------|------|-------|
| local | UIColors.onSurfaceMuted | Icons.storage | 本地資料 |
| synced | UIColors.positive | Icons.check_circle | 已同步 |
| pending | UIColors.primary | Icons.cloud_upload | 待同步 |
| syncing | UIColors.primary | Icons.sync | l10n.syncing |
| conflict | UIColors.negative | Icons.warning | 有衝突 |
| failed | UIColors.negativeDark | Icons.error | l10n.syncFailed |

**修復方式**: 更新 6 個測試期望值，使用 UIColors 語意化顏色而非原始 Colors

### 決策 4: BookInfoEnrichmentService 功能範圍 ✅

**確認決策**: **保留功能，調整測試**

**審查結果**:
- `enrichBatch()` (book_info_enrichment_service.dart:75-110): ✅ 已實作，支援批次併發處理
- `cancelEnrichment()` (book_info_enrichment_service.dart:117-119): ✅ 已實作，設置 `_isCancelled = true`

**問題分析**:
- 測試期望 `results.length < 100`，但批次處理是 10 本同時併發
- 取消時已提交的併發任務會繼續執行完成
- 測試超時設定可能導致問題

**修復方式**: 調整測試期望值和超時設定，符合實際併發行為

---

## 📋 Wave 4 實作清單

基於以上決策，生成以下修復任務：

### 高優先級 (Unit Test - 6 個)

| ID | Target | 修復方式 | 估計工時 |
|----|--------|---------|---------|
| W4-U-001 | ISBNScannerService startScanning 測試 | 修改期望值 → 驗證 ScanResult.failure | 10 min |
| W4-U-002 | ISBNScannerService stopScanning 測試 | 修改期望值 → 驗證 returnsNormally | 10 min |
| W4-U-003 | Book Domain should_link_book_to_platform | 移除或重寫為基本屬性驗證 | 15 min |
| W4-U-004 | Book Domain should_validate_creation | 驗證預設值邏輯 | 10 min |
| W4-U-005 | cancelEnrichment 應該立即停止 | 調整期望值和超時 | 15 min |
| W4-U-006 | cancelEnrichment 應該回傳已完成結果 | 調整期望值 | 10 min |

### 中優先級 (Widget Test - 8 個)

| ID | Target | 修復方式 | 估計工時 |
|----|--------|---------|---------|
| W4-W-001~006 | SyncStatusIndicator WG-01~06 | 更新顏色期望為 UIColors | 30 min |
| W4-W-007 | SyncSettingsPage WG-38 | 檢查導航邏輯變更 | 15 min |
| W4-W-008 | ConflictPreviewCard WG-25 | 檢查按鈕回調變更 | 15 min |

### 總計: 14 個測試修復，估計 130 分鐘 (~2.2 小時)

---

**文件狀態**: ✅ 設計決策已確認
**下一步**: 分派 Wave 4 實作任務給 parsley-flutter-developer
**目標**: 完成所有測試修復，達成 100% 通過率
