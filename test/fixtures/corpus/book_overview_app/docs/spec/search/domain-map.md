---
id: DOMAIN-MAP-search
domain: "search"
source_specs: [SPEC-005, SPEC-012]
related_usecases: [UC-04]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — search

> 產出來源：0.38.1-W5-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。

## 1. 目的與 UC / DDD 正交關係

search domain 管理關鍵字搜尋、候選比對、資料合併策略、衝突偵測與批次補充。主要消費 library 的 Book 聚合根和 book_info 的 BookEnrichmentData。

核心準則：domain 層保持純——無 I/O、無 UI 形狀、對顯示偏好與框架一無所知。分類術語定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：多 aggregate（SearchSession + BatchEnrichmentSession）+ command-side 協調

```
presentation (SearchBookViewModel / BatchEnrichViewModel)
        │
read-model（ScoredCandidate / ImprovementResult / CacheStatistics）
        │
kernel（BookSimilarityCalculator）    domain service（AutoMatchProcessor / ManualConfirmationHandler / ConflictResolutionAnalyzer / ReliabilityBasedResolver）
        │                                │
   +----------+                    +-----+-----+
   │          │                    │           │
SearchSession  BatchEnrichmentSession（獨立 aggregate）
   ▲              ▲
   │              │
 data（IGoogleBooksRepository impl / SearchResultCache）
```

**依賴方向底線**：
- search domain import library（Book / BookRepository）和 book_info（`lib/domains/book_info/`，BookEnrichmentData）。已驗證。
- search domain 不 import data / presentation / UI 框架。
- SearchSession 與 BatchEnrichmentSession 為獨立 aggregate，by-id 參照（sessionId / BookId）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| SearchSession | aggregate root | SearchSession（sessionId/bookId/keyword/status 狀態機 pending→executing→completed/cancelled）+ SearchCandidate + SearchSessionId | UI 狀態管理 | `lib/domains/search/entities/` | unit：狀態轉換守衛、getActiveKeyword | 已實作 | N/A |
| BatchEnrichmentSession | aggregate root | BatchEnrichmentSession（sessionId/bookIds/progress/status 狀態機 pending→processing⇄paused→completed/cancelled）+ BatchEnrichmentResult | UI 進度顯示 | `lib/domains/search/entities/` | unit：狀態轉換、progress 計算 | 已實作 | N/A |
| GoogleBooksSearchResult | supporting VO | GoogleBooksSearchResult（fromJson 解析 volumeInfo + industryIdentifiers + imageLinks）| API HTTP 呼叫 | `lib/domains/search/models/` | unit：JSON 解析邊界值 | 已實作 | N/A |
| SearchCriteria | supporting VO | SearchCriteria（query + fields + caseSensitive + exactMatch）+ SearchField 列舉 | 搜尋執行 | `lib/domains/search/value_objects/` | unit：validate 驗證、isAdvanced 計算 | 已實作 | N/A |
| SimilarityScore | supporting VO | SimilarityScore（overall/title/author/publisher/isbn）+ SimilarityLevel 列舉 | UI 顯示格式 | `lib/domains/search/value_objects/` | unit：level 分級邊界值 | 已實作 | N/A |
| BookSimilarityCalculator | domain kernel（共享） | 多維相似度計算（書名包含關係 + 詞基相似度 + 作者空值處理 + 權重配置）| UI 渲染 | `lib/domains/search/services/` | unit：各維度計算正確性 | 已實作 | N/A |
| DataMergeStrategy | domain service | 三策略（fillMissingOnly/preferEnriched/userConfirmed）+ merge 方法 | 持久化 | `lib/domains/search/strategies/` | unit：各策略欄位覆蓋規則 | 已實作 | N/A |
| ConflictDetection | domain service | InformationConflictDetector + InformationConflict（type/field/existingValue/newValue/severity）+ ConflictDetectionResult | UI 比較表 | `lib/domains/search/services/` | unit：衝突偵測 6 欄位 | 已實作 | N/A |
| ConflictResolution | domain service | ConflictResolutionAnalyzer + ReliabilityBasedResolver + InformationImprovementAnalyzer + ResolutionStrategy/Recommendation | UI 選擇介面 | `lib/domains/search/services/` | unit：策略推薦、可靠度排序 | 已實作 | N/A |
| AutoMatchProcessor | domain service | 自動比對（processMatch/processBatch/getBestMatch/getAutoMatches）+ AutoMatchResult | 手動確認 | `lib/domains/search/services/` | unit：閾值命中判定 | 已實作 | N/A |
| ManualConfirmationHandler | domain service | createConfirmationRequest/handleConfirmation + ManualConfirmationRequest 狀態機 | 自動比對 | `lib/domains/search/services/` | unit：狀態轉換 | 已實作 | N/A |
| SearchResultCache | 非 domain（infrastructure） | SearchResultCache：LRU 快取（100 筆 + TTL + 正規化查詢）+ CacheStatistics | 業務邏輯 | `lib/domains/search/services/` | unit：LRU 淘汰、TTL 過期、hit/miss 統計 | 已實作 | 不適用（記憶體 LRU 快取無持久化；見方法論第 2 節） |
| SearchAnalytics | read-model | SearchAnalytics + SearchPatternTracker + SearchPerformanceAnalyzer + SearchMetrics | 持久化 | `lib/domains/search/services/` | unit：指標計算 | 已實作 | N/A |
| Search Events | 非 domain（cross-cutting） | 搜尋/補充/批次事件常量（15 個） | 事件匯流排實作 | `lib/domains/search/events/` | unit：常量值唯一性 | 已實作 | N/A |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| SearchSession | 狀態只能 pending→executing→completed/cancelled，不可回退；getActiveKeyword 回傳 modifiedKeyword ?? initialKeyword |
| BatchEnrichmentSession | progress = processedCount / totalCount（0.0-1.0）；bookIds 大小 1-20 |
| BookSimilarityCalculator | 書名權重 > 作者權重（配置）；ISBN 精確匹配視為最高優先 |
| DataMergeStrategy | fillMissingOnly 不覆蓋非 null 欄位；preferEnriched 不覆蓋 ID/source/addedDate |
| SearchResultCache | size <= capacity（100）；LRU 淘汰最久未存取項 |

## 4. 邊界決策

### 4.1 BookSimilarityCalculator 為 kernel

被 AutoMatchProcessor（自動比對）和 CalculateBookSimilarityUseCase（手動流程）共同消費，符合 kernel 判準。

### 4.2 SearchResultCache 歸 search 目錄

快取機制本身是 infrastructure（LRU 淘汰、TTL 過期），但配置參數（100 筆上限、TTL 時長、查詢正規化規則）由 search domain 語意決定。位置放 search 目錄而非 data 層，因為搬至 data 層會使搜尋策略變更須跨層修改。分類維持非 domain（infrastructure）——位置決策（放哪個目錄）與分類決策（屬哪個層）獨立：位置跟著配置語意的擁有者，分類跟著機制本質。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 搜尋流程修改 | domain | SearchSession aggregate + Use Case 層。粒度：搜尋與批次補充為獨立 aggregate，分開 ticket |
| 比對演算法修改 | domain | BookSimilarityCalculator kernel。粒度：比對演算法為共享 kernel，修改影響搜尋 + 衝突解決兩個消費者 |
| 合併策略修改 | domain | DataMergeStrategy |
| 衝突解決修改 | domain | ConflictDetection + ConflictResolution 兩 bundle |
| 快取策略修改 | infrastructure | SearchResultCache |
| 批次補充修改 | domain | BatchEnrichmentSession aggregate |

## 6. 觀察到的技術債（待追蹤）

- BatchEnrichBooksUseCase.execute 內部為模擬操作（SPEC-005 GAP-1）
- maxBatchSize 20 與需求 50 不一致（SPEC-005 GAP-2）
- ValidateSearchCriteriaUseCase 未串接至搜尋流程（SPEC-005 GAP-3）

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（搜尋 Session） | SearchSession aggregate | domain |
| FR-2（搜尋查詢） | 非 domain（infrastructure） | IGoogleBooksRepository 介面 |
| FR-3（搜尋結果） | GoogleBooksSearchResult VO | domain |
| FR-4（候選比對） | BookSimilarityCalculator kernel + AutoMatchProcessor + ManualConfirmationHandler | domain |
| FR-5（資料合併） | DataMergeStrategy | domain service |
| FR-6（衝突偵測與解決） | ConflictDetection + ConflictResolution | domain service |
| FR-7（搜尋快取） | SearchResultCache | infrastructure |
| FR-8（批次補充） | BatchEnrichmentSession aggregate | domain |
| FR-9（搜尋條件） | SearchCriteria VO | domain |
| FR-10（Use Case 層） | presentation/use_cases（非 domain） | Use Case 層 |
| FR-11（分析與追蹤） | SearchAnalytics read-model | domain |
| SPEC-012（BatchSupplementPage） | presentation（非 domain） | Presentation 層 |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（SearchResultCache 標不適用，其餘 N/A；template 2.2.0）
