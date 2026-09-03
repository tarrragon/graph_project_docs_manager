# W2-003 關鍵發現摘要

**分析日期**: 2026-01-10
**分析代理人**: sage-test-architect (TDD Test Engineer Specialist)
**Ticket**: 0.25.0-W2-003 - Unit 測試失敗模式分析

---

## 📊 失敗測試統計

| 類別 | 數量 | 佔比 | 狀態 |
|------|------|------|------|
| 設計變更未同步 | 6 | 37.5% | ISBNScannerService, Book Domain |
| 測試過時 | 8 | 50% | SyncWidget 相關 |
| 功能未實作 | 2 | 12.5% | BookInfoEnrichmentService |
| **合計** | **16** | 100% | ✅ 全數分析完成 |

---

## 🔍 核心發現

### 發現 1: ISBNScannerService 異常處理模式不一致

**問題**: 掃描服務使用混合異常模式，造成測試困惑

**詳情**:
```dart
// startScanning(): 拋出異常後被內部 catch 攔截，返回 Result
Future<ScanResult> startScanning() async {
  try {
    throw UnimplementedError('相機掃描邏輯尚未整合');  // ← 拋出
  } catch (e) {
    return ScanResult.failure(...);  // ← 返回 Result
  }
}

// stopScanning(): 不拋出異常，直接返回 void
Future<void> stopScanning() async {
  _isScanning = false;
  // 不拋出異常
}
```

**測試期望**: 拋出 UnimplementedError
**實作行為**: 返回失敗的 Result 物件（或不拋出異常）
**測試狀態**: ❌ 失敗

**設計建議**:
- 統一採用 **Result 物件模式**（無異常），符合現代 Dart/Flutter 最佳實踐
- 修改測試驗證返回的 ScanResult 狀態，而非期望異常拋出

**修復優先級**: 🔴 **高**

---

### 發現 2: Book Domain 簡化模型的驗證策略變更

**問題**: v0.24.0 簡化了 Book 模型，不再驗證空值

**詳情**:
```dart
// v0.24.0 之前：應該拋出 ValidationException
Book.create(id: '', title: '...');  // ← 拋出異常

// v0.24.0 之後：返回 Book 實例，內部有預設值
Book.create(id: '', title: '...');  // ← 正常返回
```

**受影響測試**:
- `should_validate_book_creation_with_required_fields`
  - 期望: `returnsNormally` ✓ 正確
  - 但需要驗證建立的 Book 實例屬性

- `should_link_book_to_platform_correctly`
  - 期望: Platform/Source 系統存在
  - 實行: 系統已簡化移除
  - 需要: 移除該測試或改為驗證基本屬性

**設計建議**:
- 確認 Book 簡化模型的邊界情況處理規則
- 更新測試反映新的驗證策略

**修復優先級**: 🔴 **高**

---

### 發現 3: SyncWidget 外觀期望值在 UI 統一化後失效

**問題**: v0.24.0 UI 統一化改變了 Widget 的外觀和標籤文字

**受影響測試** (8 個):
- **SyncStatusIndicator** (6 個):
  - WG-01 ~ WG-06：期望特定圖標和顏色
  - 例: `Icons.storage` 灰色、`Icons.check_circle` 綠色等

- **SyncSettingsPage** (1 個):
  - WG-38: 導航邏輯可能已改變

- **ConflictPreviewCard** (1 個):
  - WG-25: 按鈕標籤或回調邏輯可能已改變

**例子**:
```dart
// 測試期望
expect(find.byIcon(Icons.storage), findsOneWidget);
expect(iconWidget.color, equals(Colors.grey));  // ← 灰色

// 實作可能改為
expect(find.byIcon(Icons.cloud_queue), findsOneWidget);  // ← 不同圖標
// 顏色也可能改變
```

**修復方式**:
1. 檢查 `lib/presentation/sync/widgets/sync_status_indicator.dart` 實現
2. 列出實際的圖標和顏色對應
3. 更新測試期望值

**修復優先級**: 🟡 **中** (功能本身未改變，只是表現層)

---

### 發現 4: BookInfoEnrichmentService 邊界情況功能缺失

**問題**: 補充服務的取消和速率控制功能未完整實作

**受影響測試** (3 個):
- `cancelEnrichment() 應該回傳已完成的補充結果`
- `cancelEnrichment() 應該立即停止處理剩餘書籍`
- `enrichBatch() 應該遵守速率控制限制`

**可能的根因**:
1. 功能確實未實作 → 需要實作或移除測試
2. 實作與測試期望不符 → 需要調整測試

**修復方式**:
1. 檢查 `BookInfoEnrichmentService` 是否實作了 `cancelEnrichment()`
2. 檢查 `enrichBatch()` 是否實裝了速率控制邏輯
3. 若功能未實作，決定是否實作或標記為跳過

**修復優先級**: 🟡 **中** (邊界情況，非核心功能)

---

## 🎯 設計決策確認清單

Wave 3 (設計階段) 需要確認以下決策：

- [ ] **決策 1**: ISBNScannerService 應採用何種異常處理模式？
  - 選項 A: Result 物件模式（無異常拋出）✓ **推薦**
  - 選項 B: 保留異常模式
  - 選項 C: 保留混合模式

- [ ] **決策 2**: Book Domain 的驗證規則是什麼？
  - 空值是否允許？→ 允許（v0.24.0 設計）
  - 建立 Book 時是否驗證必填欄位？→ 不驗證，提供預設值
  - 需要記錄在設計文檔中

- [ ] **決策 3**: SyncWidget 的顏色和圖標方案是什麼？
  - 檢查實現的 Widget 取得準確的對應關係
  - 更新測試期望值

- [ ] **決策 4**: BookInfoEnrichmentService 的 cancelEnrichment() 是否在 MVP 範圍內？
  - 若是：實作功能
  - 若否：移除測試

---

## 📈 修復工作估算

| 工作項 | 優先級 | 估計工時 | 說明 |
|--------|--------|--------|------|
| ISBNScannerService (2) | 🔴 高 | 20 min | 修改測試期望值 |
| Book Domain (2) | 🔴 高 | 15 min | 確認驗證規則，修改測試 |
| SyncWidget (8) | 🟡 中 | 60 min | 檢查實作，更新期望值 |
| BookInfoEnrichmentService (3) | 🟡 中 | 45 min | 檢查功能，決定實作或跳過 |
| **合計** | | **140 min** | **~2.3 小時** |

---

## 🚀 後續行動

### 立即行動 (Wave 3)
1. 確認四大設計決策
2. 檢查相關實現程式碼
3. 列出具體的修復清單

### 實行行動 (Wave 4)
1. 修改測試期望值以符合實作
2. 若發現實作不符合需求，進行最小修復
3. 執行所有測試確保通過率達到 100%

---

## 📚 相關文件

- **詳細報告**: `W2-003-unit-test-failure-analysis.md`
- **工作日誌**: `v0.25.0-tech-debt-resolution.md`
- **測試檔案**:
  - `test/domains/library/book_test.dart`
  - `test/unit/domains/scanner/isbn_scanner_service_test.dart`
  - `test/unit/infrastructure/import/book_info_enrichment_service_test.dart`
  - `test/unit/presentation/sync/widgets/sync_status_indicator_test.dart`

- **實現檔案**:
  - `lib/domains/scanner/services/isbn_scanner_service.dart`
  - `lib/domains/library/entities/book.dart`
  - `lib/presentation/sync/widgets/sync_status_indicator.dart`

---

**分析狀態**: ✅ 完成
**下一步**: 確認設計決策，進入 Wave 3 設計階段
**目標**: 完整根因分析 + 修復策略設計，為 Wave 4 實作提供清晰路線圖
