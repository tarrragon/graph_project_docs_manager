---
id: DOMAIN-MAP-extraction
domain: "extraction"
source_specs: [SPEC-002, SPEC-002a]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-06]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — extraction

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-002（FR 清單）、SPEC-002a（E2E 契約規格）交叉引用。

## 1. 目的

extraction domain 負責從電子書平台網頁提取書籍資料，涵蓋提取協調、資料處理、驗證、品質控制。提取結果透過事件系統傳遞至 data-management 寫入 Storage，不直接操作 Storage。

## 2. 分層與依賴方向

```
presentation（popup 觸發按鈕 — 歸 user-experience）
        │
extraction domain service（協調、處理、驗證、品質控制）
        │ 依賴（單向）
        ▼
core（ErrorCodes, EventBus）+ platform（平台偵測）+ messaging（跨 context 通訊）+ page（頁面偵測結果）
```

**依賴方向底線（不可違反）**：

- extraction 不得 import data-management / Storage API。違反則提取與儲存耦合，無法獨立測試提取邏輯。提取結果透過事件（EXTRACTION.COMPLETED）傳遞，由 event-coordinator 橋接至 Storage。
- extraction 不得 import presentation / UI 框架。
- Content Script 側的 adapter（ReadmooAdapter）直接操作 DOM（瀏覽器環境限制），但業務邏輯保持可測。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Extraction Coordinator | domain service | ExtractionDomainCoordinator、ExtractionStateService | Storage 寫入 | `src/background/domains/extraction/` | unit + integration：協調流程 | 已實作 |
| Data Processing | domain service | DataProcessingService（格式轉換、管道處理、快取） | DOM 操作 | `src/background/domains/extraction/services/` | unit：資料管道處理 | 已實作 |
| Extraction Validation | domain service | ValidationService（批量驗證、規則管理、錯誤報告） | Storage I/O | `src/background/domains/extraction/services/` | unit：驗證規則覆蓋 | 已實作 |
| Quality Control | read-model | QualityControlService（品質評估、異常偵測） | 資料修正（歸 data-management） | `src/background/domains/extraction/services/` | unit：品質評分計算 | 已實作 |
| Platform Adapters | 非 domain（infra） | ReadmooAdapter（DOM 提取）、PlatformAdapterInterface、BookDataExtractor | domain 計算 | `src/content/adapters/`, `src/content/extractors/` | E2E + unit：DOM 選擇器、資料正規化 | 已實作 |
| Readmoo Validator | domain service | ReadmooDataValidator（平台專屬驗證規則、清理、統計） | 通用驗證邏輯（歸 Extraction Validation） | `src/extractors/` | unit：平台專屬規則 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Extraction Coordinator | 提取狀態機：idle → extracting → completed/failed；不可從 completed 直接回 extracting | 已實作 |
| Data Processing | 管道處理順序固定（parse → normalize → validate）；快取命中時跳過 parse | 已實作 |
| Extraction Validation | 必填欄位（id, title）缺失時驗證失敗；batch 驗證回傳每本書的個別結果 | 已實作 |
| Quality Control | 品質分數 0-100；異常偵測閾值可配置 | 已實作 |
| Platform Adapters | adapter 實作 PlatformAdapterInterface 全部方法；DOM 選擇器命中 0 元素時回傳空陣列非 null | 已實作 |
| Readmoo Validator | Readmoo 專屬規則集（URL 格式、作者格式、進度範圍）全部覆蓋 | 已實作 |

## 4. 邊界決策

### 4.1 提取與儲存透過事件解耦

extraction 不直接呼叫 data-management 的 Storage API。提取完成後 emit `EXTRACTION.COMPLETED` 事件攜帶 books 資料，由 Background 層的 event-coordinator 橋接至 tag-storage-adapter 寫入。這使得提取邏輯可在無 Chrome Storage 環境下測試。

### 4.2 Content Script 側 adapter 歸 infra

ReadmooAdapter 和 BookDataExtractor 直接操作瀏覽器 DOM（Chrome Extension Content Script 環境限制），屬 infrastructure 層。PlatformAdapterInterface 定義的契約屬 domain。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 新書城 adapter | data（infra） | 實作 PlatformAdapterInterface，不修改 extraction domain |
| 提取驗證規則新增 | domain | 在 ValidationService 加規則 |
| E2E 契約變更 | 跨層 | 先更新 SPEC-002a 再改 code |

## 6. 觀察到的技術債（待追蹤）

- ExportService 物理上在 extraction domain 服務目錄下，但功能屬 data-management 的匯出（歷史遺留位置）

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 資料提取協調 | Extraction Coordinator + Data Processing + Extraction Validation + Quality Control | domain 層 |
| FR-02 Readmoo 資料驗證 | Readmoo Validator | domain service |
| FR-03 Content Script 資料提取 | Platform Adapters | 非 domain（infra） |
| SPEC-002a E2E 契約 | 橫切所有 bundle | 跨進程邊界契約 |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
