---
id: DOMAIN-MAP-page
domain: "page"
source_specs: [SPEC-006]
related_usecases: [UC-05]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — page

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-006（FR 清單）交叉引用。

## 1. 目的

page domain 管理頁面偵測、導航事件處理、Content Script 協調和標籤頁狀態追蹤。專注於「使用者目前在看什麼頁面」的知識，為 extraction 和 user-experience 提供頁面上下文。

## 2. 分層與依賴方向

```
extraction（消費頁面偵測結果觸發提取）
        │
page domain service（偵測、導航、tab 追蹤）
        │ 依賴（單向）
        ▼
core（ErrorCodes）+ messaging（跨 context 通訊）
```

**依賴方向底線（不可違反）**：

- page 不得 import extraction / data-management / user-experience。違反則頁面偵測耦合業務邏輯。
- page 不得 import presentation / UI 框架。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Page Detection | domain service | PageDetectionService（SW 側）、PageDetector（CS 側，頁面類型識別：library/shelf/reader/unknown）、hostname 偵測、SPA hash 路由處理 | DOM 提取（歸 extraction） | `src/background/domains/page/services/`, `src/content/detectors/` | unit：頁面類型分類正確性 | 已實作 |
| Content Script Coordination | domain service | ContentScriptCoordinatorService（CS 生命週期管理） | CS 內部業務邏輯 | `src/background/domains/page/services/` | unit：CS 注入/銷毀流程 | 已實作 |
| Tab State Tracking | read-model | TabStateTrackingService（tab 提取狀態追蹤、tab 切換歷史）| 提取邏輯 | `src/background/domains/page/services/` | unit：狀態追蹤正確性 | 已實作 |
| Navigation | domain service | NavigationService（URL 變更偵測、MutationObserver） | 頁面內容處理 | `src/background/domains/page/services/` | unit：URL 變更事件 | 已實作 |
| Permission Management | 非 domain（infra） | PermissionManagementService（activeTab / scripting 權限） | 業務授權 | `src/background/domains/page/services/` | unit：權限檢查 | 已實作 |
| Page Type Detector Utils | domain service | page-type-detector.js（頁面類型判斷工具函式） | CS 側偵測器 | `src/background/domains/page/utils/` | unit：判斷邏輯 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Page Detection | readmoo.com 域名必須偵測為 isReadmooPage=true；library/shelf 頁面 isExtractablePage=true；SPA hash 路由（#/library）正確識別 | 已實作 |
| Content Script Coordination | CS 初始化九步驟依序執行；Step 9 reportReadyStatus 為最後步驟 | 已實作 |
| Tab State Tracking | tab 狀態變更有對應事件記錄；tabHistory 保留最近 N 筆 | 已實作 |
| Navigation | URL 變更偵測不漏（含 SPA hash 變更）；MutationObserver 正確清理 | 已實作 |
| Permission Management | 必要權限（activeTab / scripting）缺失時回傳明確錯誤 | 已實作 |
| Page Type Detector Utils | page-type-detector.js 判斷函式覆蓋所有已知頁面類型（library / shelf / reader / unknown） | 已實作 |

## 4. 邊界決策

### 4.1 PageDetector CS 側 vs SW 側

PageDetector 在 Content Script（CS）側（`src/content/detectors/`）執行頁面偵測，PageDetectionService 在 Service Worker（SW）側（`src/background/domains/page/`）協調。決策：此雙環境分佈源於 Chrome Extension 架構限制（CS 可存取 DOM、SW 不可），無需統一。

### 4.2 content-modular.js 歸 page 而非 extraction

content-modular.js 是 Content Script 入口，負責初始化九步驟（含頁面偵測），屬 page domain 的 CS 協調職責。提取觸發由 extraction domain 的 BookDataExtractor 處理。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 新書城頁面偵測 | domain | 在 PageDetector 加新 hostname/pageType |
| Tab 追蹤擴展 | domain | 修改 Tab State Tracking bundle |

## 6. 觀察到的技術債（待追蹤）

- MutationObserver 偵測 SPA 路由變更有已知限制（僅 DOM 子節點變動觸發，hash-only 變更可能漏觸發，W6-012.9.4 已驗證）

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 頁面偵測與管理 | Page Detection + Content Script Coordination + Tab State Tracking + Navigation + Permission Management + Page Type Detector Utils | 全部 bundle 覆蓋單一 FR |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
