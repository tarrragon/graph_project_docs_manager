---
id: DOMAIN-MAP-import
domain: "import"
source_specs: [SPEC-002]
related_usecases: [UC-01]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — import

> 產出來源：0.38.1-W5-002。

## 1. 目的與 UC / DDD 正交關係

import domain 管理從 Chrome Extension 匯入書庫資料：格式辨識（4 來源）、id 保留、pass-through 保留、readingStatus 正規化、重複偵測與處理、取消回滾。依賴 library（Book/BookService）和 `lib/core/`（errors，應用核心層）。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

```
presentation (ChromeExtensionImportViewModel)
        │
domain service（ChromeExtensionImportService / ChromeExtensionParser / ChromeExtensionMapper）
        │
aggregate VO（ChromeExtensionBookData / DuplicateBookInfo / DuplicateHandlingStrategy）
        ▲
        │
 data（FileService / BookService）
```

**依賴方向底線**：
- import → library（Book / BookService）：合法，寫入書籍。
- import → `lib/core/`（errors）：合法，應用核心層依賴（非 domain-to-domain）。
- import 不 import 其他 domain。已驗證。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| ChromeExtensionBookData | supporting VO | DTO（id/title/author/publisher/cover）+ fromJson / isValid | domain 實體轉換 | `lib/domains/import/` | unit：fromJson 邊界值、isValid | 已實作 | N/A |
| ChromeExtensionParser | domain service | parse（File → ChromeExtensionParseResult）+ FileValidator | 檔案 I/O | `lib/domains/import/` | unit：各格式解析 | 已實作 | N/A |
| ChromeExtensionMapper | domain service | toDomainEntity / toDomainEntitiesBatch / toDto 雙向轉換 | 持久化 | `lib/domains/import/` | unit：欄位映射正確性 | 已實作 | N/A |
| ChromeExtensionImportService | domain service | importFromJson / importFromFile | UI 進度 | `lib/domains/import/` | unit + integration：匯入流程 | 已實作 | N/A |
| DuplicateHandling | domain service | DuplicateBookInfo + DuplicateHandlingStrategy（skip/overwrite/merge/cancel）+ 合併規則（existing 優先 imported 補缺）| UI 對話框 | `lib/domains/import/` | unit：各策略行為 | 已實作（enums/duplicate_strategy.dart 僅 3 策略 skip/overwrite/merge，無 cancel；命名與此表不同） | N/A |
| FormatDetection | domain service | 四來源格式辨識（canonical v3.x / V1 v2 / APP legacy / flat v1）| 格式定義 | `lib/domains/import/` | unit：各格式正確辨識 | 已實作 | N/A |
| ReadingStatusNormalization | domain service | readingStatus 正規化（unread→not_started）+ _chromeLegacyStatusMap | 列舉定義 | `lib/domains/import/` | unit：各狀態映射 | 已實作（邏輯位於 mappers/flat_v1_book_mapper.dart、extension_native_book_mapper.dart，非獨立 service） | N/A |
| Import Exceptions | supporting VO | ImportException + 衍生例外（JsonFormat/FileRead/DataValidation/MemoryLimit/ProcessingTimeout/DuplicateBook/BatchProcessing/ImportCancelled 等 16 類）| 錯誤處理邏輯 | `lib/domains/import/` | unit：例外建構 | 已實作 | N/A |

> 資料契約文件引用：本表無 data/infrastructure 列（匯入寫入經 library BookRepository / BookService，books 表契約見 `docs/spec/library/SPEC-014-library-data-contract.md`）；import_progress 表豁免不寫契約（0.38.1-W10-004 實查：ImportProgressRepository 無 production 接線，匯入進度為 in-memory Stream 不落 DB；sync 四表同票豁免。豁免理由與重啟條件見該票 Solution）。

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| ChromeExtensionBookData | isValid = hasValidId && hasValidTitle |
| FormatDetection | format == "book-interchange-v1" 時辨識為 canonical v3.x（最高優先）；不符任何格式時回報格式錯誤（禁靜默失敗） |
| DuplicateHandling | merge 策略：existing 優先、imported 補缺（isbn/publisher/description/coverImageUrl/rating/custom tags）；overwrite 策略：保留 existing.id |
| ReadingStatusNormalization | unread → notStarted；null/空/未知 → notStarted |

## 4. 邊界決策

### 4.1 兩條匯入路徑並存

ViewModel 直接 jsonDecode 路徑和 Domain ChromeExtensionParser 路徑欄位映射不同步。**Why**：ViewModel 路徑為早期快速實作，尚未重構至統一 Domain Parser 入口。**Consequence**：欄位映射變更須同步兩處，否則匯入結果不一致（特定格式走 ViewModel 路徑可能漏欄位）。此為技術債（SPEC-002 GAP-6）。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 格式辨識修改 | domain | FormatDetection。粒度：新增來源格式為一張 ticket |
| 重複處理修改 | domain | DuplicateHandling。粒度：重複策略（skip/overwrite/merge）各為一張 ticket |
| 匯入流程修改 | domain | ChromeExtensionImportService。粒度：§4.1 兩條匯入路徑須同步修改 |

## 6. 觀察到的技術債（待追蹤）

- pass-through/extensions 未從 JSON 映射至 Book（SPEC-002 GAP-2）
- tagTree 重建未實作（SPEC-002 GAP-3）
- ChromeExtensionBookData DTO 僅 5 欄位不足（SPEC-002 GAP-5）
- 兩條匯入路徑並存（SPEC-002 GAP-6）

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（格式辨識） | FormatDetection | domain |
| FR-2（id 保留） | ChromeExtensionMapper | domain |
| FR-3（pass-through） | 未實作（GAP-2） | 技術債 |
| FR-4（readingStatus 正規化） | ReadingStatusNormalization | domain |
| FR-5（tagTree 重建） | 未實作（GAP-3） | 技術債 |
| FR-6（檔案驗證） | presentation + ChromeExtensionValidationService | cross-cutting |
| FR-7（重複偵測） | DuplicateHandling | domain |
| FR-8（取消回滾） | presentation（ViewModel 層） | presentation |
| FR-9（結果統計） | presentation（ViewModel 層） | presentation |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（無 data/infrastructure 列全 N/A，import/sync 表契約待 0.38.1-W10-004；template 2.2.0） | 0.38.1-W10-004 結論回填：import_progress 標豁免（dormant，無 production 接線；重啟條件見該票 Solution）
