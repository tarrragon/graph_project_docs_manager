---
id: DOMAIN-MAP-export
domain: "export"
source_specs: [SPEC-003]
related_usecases: [UC-02]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — export

> 產出來源：0.38.1-W5-002。

## 1. 目的與 UC / DDD 正交關係

export domain 管理書庫資料匯出：JSON（canonical book-interchange-v1）和 CSV 兩種格式，含匯出範圍選擇、進度回饋、歷史紀錄、完成後操作。依賴 library（Book/BookRepository）和 `lib/core/`（errors，應用核心層）。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：單 aggregate 退化（無持久化 aggregate，以 ExportConfiguration + ExportResult 值物件驅動流程）

```
presentation (ExportViewModel / DataManagementViewModel)
        │
read-model（ExportProgress / ExportResult / CsvExportResult）
        │
domain service（InterchangeExportService / BookQueryService / DataValidationService / CsvExportService）
        │
aggregate VO（ExportConfiguration / ExportScope / ExportFormat）
        ▲
        │
 data（DataExportService / ExportHistoryRepository / FileService）
```

**依賴方向底線**：
- export → library（Book / BookRepository）：合法，讀取書籍資料匯出。
- export → `lib/core/`（errors）：合法，應用核心層依賴（非 domain-to-domain）。
- export → `lib/domains/core/`（domain_event 基底類）：合法，事件繼承基底。
- export 不 import 其他 domain。已驗證。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| ExportConfiguration | supporting VO | ExportConfiguration（format/scope/exportPath/options）+ ExportScope（sealed class: All/BySource/ByTags/ByDateRange）+ ExportFormat（json/csv/pdf 列舉）| 匯出執行 | `lib/domains/export/value_objects/` | unit：validate、copyWith、scope 判定 | 已實作 | N/A |
| ExportProgress | supporting VO | ExportProgress（percentage/processedItems/totalItems/estimatedTimeRemaining）| UI 顯示 | `lib/domains/export/value_objects/` | unit：isComplete/isEmpty 計算 | 已實作 | N/A |
| ExportResult | supporting VO | ExportResult（filePath/totalItems/exportedItems/skippedItems/fileSize/processingTime/sourceBreakdown）| 檔案操作 | `lib/domains/export/value_objects/` | unit：successRate/isFullSuccess 計算 | 已實作 | N/A |
| InterchangeExportService | domain service | exportInterchangeJson（canonical v3.0.0 / legacyArray）| 檔案寫入 | `lib/domains/export/services/` | unit：JSON 結構正確性、totalBooks 交叉驗證 | 已實作 | N/A |
| BookQueryService | domain service | queryBooks（依 scope 查詢）/ countBooks | 持久化 | `lib/domains/export/services/` | unit + integration：各 scope 篩選 | 已實作 | N/A |
| DataValidationService | domain service | validateBook / validateBooks | UI 顯示 | `lib/domains/export/services/` | unit：必填欄位、欄位長度、日期格式 | 已實作 | N/A |
| JsonSerializationService | domain service | serializeBook / deserializeBook（雙向）| 檔案 I/O | `lib/domains/export/services/` | unit：序列化 round-trip | 已實作 | N/A |
| DataTransformService | domain service | transformBook / transformWithProgress | UI 回饋 | `lib/domains/export/services/` | unit：轉換正確性 | 已實作 | N/A |
| CsvExportService | domain service | exportToCsv + CsvFieldMapper + CsvHeaderGenerator + CsvDataTransformer + CsvFileWriter | PDF 匯出 | `lib/domains/export/csv/` | unit + integration：CSV 欄位映射、表頭生成 | 已實作 | N/A |
| ChromeExtensionBookData | supporting VO | ChromeExtensionBookData（id/title/author/isbn/...）+ fromBook/toJson | canonical tag 結構 | `lib/domains/export/value_objects/` | unit：fromBook 轉換 | 已實作 | N/A |
| Export Events | 非 domain（cross-cutting） | 12 通用匯出事件 + 4 CSV 匯出事件 | 事件匯流排 | `lib/domains/export/events/` | unit：事件欄位 | 已實作 | N/A |
| FileHandlingService | 非 domain（infrastructure） | writeFile / readFile / verifyFileIntegrity | 業務邏輯 | `lib/domains/export/services/` | repository test | 已實作 | 不適用（檔案 I/O 無 schema 持久化；見方法論第 2 節） |
| ProgressStatsService | read-model | calculatePercentage / estimateTimeRemaining / calculateSuccessRate | UI 顯示 | `lib/domains/export/services/` | unit：計算公式 | 已實作 | N/A |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| InterchangeExportService | metadata.totalBooks == books.length（BR-2 交叉驗證）；sourceApp 固定為 "book_overview_app" |
| ExportConfiguration | format 為 json/csv 時 isImplemented = true |
| ExportResult | successRate = exportedItems / totalItems |
| CsvExportService | 空書庫禁止匯出（BR-1） |

## 4. 邊界決策

### 4.1 兩條 JSON 匯出路徑並存

InterchangeExportService（canonical v3.0.0）和 JsonDataExporter（legacy 格式）語意重疊。**Why**：legacy 匯出路徑仍有外部消費者（Chrome Extension 匯入端尚未遷移至 canonical 格式）。**Consequence**：新增匯出欄位須同步兩條路徑，維護成本加倍。此為技術債（SPEC-003 差距分析已記錄）。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| JSON 匯出格式修改 | domain | InterchangeExportService。粒度：§4.1 兩條 JSON 匯出路徑須同步修改，合成一張 ticket |
| CSV 匯出修改 | domain | CsvExportService 及子服務。粒度：CSV 獨立於 JSON，可單獨一張 ticket |
| 匯出範圍修改 | domain | ExportScope / BookQueryService |
| 檔案操作修改 | infrastructure | FileHandlingService / DataExportService |

## 6. 觀察到的技術債（待追蹤）

- PDF 匯出未實作（ExportFormat.pdf isImplemented = false）
- ChromeExtensionBookData 未遷移至 canonical tag 結構
- ExportRequest.range/format 為 dynamic 型別

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（JSON canonical） | InterchangeExportService | domain |
| FR-2（everything-as-tags） | InterchangeExportService | domain |
| FR-3（pass-through） | InterchangeExportService | domain |
| FR-4（tagTree） | InterchangeExportService | domain |
| FR-5（CSV） | CsvExportService | domain |
| FR-6（範圍選擇） | ExportScope VO + BookQueryService | domain |
| FR-7（格式選擇） | ExportFormat VO | domain |
| FR-8（進度回饋） | ExportProgress VO + ProgressStatsService | domain |
| FR-9（歷史紀錄） | 非 domain（infrastructure） | ExportHistoryRepository |
| FR-10（完成後操作） | presentation（非 domain） | ExportViewModel |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（FileHandlingService 標不適用，其餘 N/A；template 2.2.0）
