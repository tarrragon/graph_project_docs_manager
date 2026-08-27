---
id: DOMAIN-MAP-scanner
domain: "scanner"
source_specs: [SPEC-004, SPEC-010]
related_usecases: [UC-03]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — scanner

> 產出來源：0.38.1-W5-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。

## 1. 目的與 UC / DDD 正交關係

scanner domain 管理 ISBN 條碼掃描、ISBN 驗證、書籍建立與多來源 API 查詢路由。依賴 library（Book/BookRepository）、synchronization（SyncRepository）、book_info（`lib/domains/book_info/`，BookEnrichmentData）和 `lib/core/`（errors/validation，應用核心層）。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：單 aggregate（ScanResult）+ command-side 協調（ISBNScannerService 跨 aggregate 協調）

```
presentation (IsbnScannerViewModel)
        │
read-model（BookCreationResult / MultiSourceQueryResult）
        │
domain service（ISBNScannerService / IsbnRegionRouter）
        │
   +----------+
   │          │
ScanResult    Isbn VO
   ▲
   │
 data（IsbnScannerRepository impl / MultiSourceQueryService / ApiSourceClient impl）
```

**依賴方向底線**：
- scanner → library（Book / BookRepository / BookTitle / BookTag / TagCategoryIds）：合法，scanner 建立 Book 實例。
- scanner → synchronization（SyncRepository / SyncOperation）：合法，離線佇列。
- scanner → book_info（`lib/domains/book_info/`，BookEnrichmentData）：合法，補充資料結構。
- scanner → `lib/core/`（errors / isbn_validation_service）：合法，應用核心層依賴（非 domain-to-domain）。
- scanner 不 import data / presentation / UI 框架。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| Isbn | supporting VO | Isbn VO（fromString/toIsbn13/formatted/standardized）+ IsbnType 列舉 + checksum 驗證（ISBN-10 加權和 mod 11 / ISBN-13 加權和 mod 10）+ 978/979 prefix 語意檢查 | API 查詢 | `lib/domains/scanner/value_objects/` | unit：checksum 邊界值、ISBN-10→13 轉換、非書籍 EAN-13 判定 | 已實作 | N/A |
| ScanResult | aggregate root | ScanResult 實體（isbn/status/scannedAt/method/errorMessage）+ ScanStatus 列舉 + ScanMethod 列舉 | 持久化 | `lib/domains/scanner/entities/` + `enums/` | unit：success/failure 工廠方法 | 已實作 | N/A |
| BookCreationResult | read-model | BookCreationResult（bookId/status/createdBook/existingBook/enrichedBook）+ BookCreationStatus 列舉 | UI 顯示 | `lib/domains/scanner/models/` | unit：狀態分類正確性 | 已實作 | N/A |
| ISBNScannerService | domain service | validateISBN / processScannedISBN（驗證→重複檢測→建立→背景補充）| 相機硬體整合 | `lib/domains/scanner/services/` | unit + integration：完整流程、重複處理 | 已實作 | N/A |
| IsbnRegionRouter | domain service | ISBN prefix 地區路由（957/986/626→台灣 NBINet→Google / 0/1→英語 Google→OpenLibrary / ...）| API HTTP 呼叫 | `lib/domains/scanner/services/`（目標位置） | unit：各 prefix 路由正確性 | 已實作（實際位於 lib/domains/book_info/services/isbn_region_router.dart，尚未搬至目標位置） | N/A |
| ISBNBookEnrichmentService | domain service（介面） | enrichByISBN / batchEnrichByISBN | 實作（infra 層） | `lib/domains/scanner/services/` | unit：mock 測試介面契約 | 已實作 | N/A |
| CameraPermissionService | domain service（介面） | requestPermission / checkPermission / openSettings | 平台 API 呼叫 | `lib/domains/scanner/services/` | unit：mock | 已實作 | N/A |
| IsbnScannerRepository | 非 domain（infrastructure） | IsbnScannerRepository 介面：scanBarcode / stopScanning / scanStream | 相機硬體 | `lib/domains/scanner/repositories/` | repository test | 已實作 | 不適用（相機硬體介面無持久化；見方法論第 2 節） |
| Scanner Exceptions | supporting VO | BarcodeDetectionException / CameraHardwareException / InvalidBarcodeDataException / InvalidScanTaskIdException | 錯誤處理邏輯 | `lib/domains/scanner/exceptions/` | unit：建構與欄位 | 已實作 | N/A |
| Scanner Enums | supporting VO | EnrichmentStatus / InputSource / NetworkStatus / PermissionStatus / ScanType / ScanStatus | 列舉值 | `lib/domains/scanner/enums/` | unit：列舉完整性 | 已實作 | N/A |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| Isbn | ISBN-13 checksum 加權和（權重 1/3 交替）mod 10 = 0；ISBN-10 checksum 加權和（10 到 1）mod 11 = 0；非 978/979 開頭的 13 位有效 EAN-13 判定為非書籍條碼 |
| ScanResult | success 工廠 isbn 必非 null；failure 工廠 status = scanFailed |
| ISBNScannerService | 同一 ISBN 不可重複建立書籍（以 ISBN-13 為 key）；掃描後立即建立書籍（ISBN 作暫時書名），背景補充非阻塞 |
| BookCreationResult | created 狀態時 createdBook 必非 null；duplicate 狀態時 existingBook 必非 null |

## 4. 邊界決策

### 4.1 scanner 依賴 library aggregate

ISBNScannerService 直接建立 Book 實例（import Book/BookTitle/BookTag）。此為合法依賴：scanner 是 Book 的建立者之一。未來若需降耦可改為透過 BookRepository 介面的 factory 方法。

### 4.2 ISBNScannerService 保留 domain service 分類

ISBNScannerService 持有 `_isScanning` 布林旗標（掃描進行中暫態）。保留 domain service 分類的依據：此旗標為執行期暫態（非持久化），僅控制單一操作的進入守衛（防止重複啟動掃描），不涉及跨 aggregate 協調或補償邏輯，不足以升級為 process manager。

### 4.3 ISBN 驗證三軌並存

Isbn VO（scanner domain）、IsbnValidationService（core）、IsbnUtils（version_management）三套功能重疊。此為技術債，待統一入口（SPEC-004 差距分析已記錄）。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| ISBN 驗證修改 | domain | Isbn VO。粒度：checksum 邏輯與 prefix 語意各可獨立一張 ticket |
| 掃描流程修改 | domain | ISBNScannerService + ScanResult。粒度：驗證→重複檢測→建立→背景補充各階段可獨立 |
| 多來源查詢修改 | domain + infrastructure | IsbnRegionRouter（domain）+ MultiSourceQueryService/ApiSourceClient（infra） |
| 相機整合 | infrastructure | IsbnScannerRepository impl |

## 6. 觀察到的技術債（待追蹤）

- 相機整合 TODO（ISBNScannerService.startScanning 拋 UnimplementedError）
- ISBN 驗證三軌並存（Isbn VO / IsbnValidationService / IsbnUtils）
- ViewModel 先查 API 再新增，與 UC-03「立即新增」需求不一致

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| SPEC-004 FR-1（條碼辨識） | 非 domain（infrastructure） | mobile_scanner 整合 |
| SPEC-004 FR-2（ISBN 驗證） | Isbn VO | domain |
| SPEC-004 FR-3（掃描流程） | ISBNScannerService + ScanResult | domain |
| SPEC-004 FR-4（相機權限） | CameraPermissionService（介面） | domain 介面 |
| SPEC-004 FR-5（手動輸入） | Isbn VO（fromString 驗證） | domain |
| SPEC-004 FR-6（重複檢測） | ISBNScannerService（processScannedISBN） | domain |
| SPEC-004 FR-7（離線掃描） | ISBNScannerService → SyncRepository | domain + infra |
| SPEC-010 FR-1（Open Library） | 非 domain（infrastructure） | OpenLibraryApiClient |
| SPEC-010 FR-2（NBINet） | 非 domain（infrastructure） | NbinetScrapingClient |
| SPEC-010 FR-3（ISBN Prefix 路由） | IsbnRegionRouter | domain service |
| SPEC-010 FR-4（多來源降級） | 非 domain（infrastructure） | MultiSourceQueryService |
| SPEC-010 FR-5（查詢結果合併） | 非 domain（infrastructure） | MultiSourceQueryService |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（IsbnScannerRepository 標不適用，其餘 N/A；template 2.2.0）
