---
id: DOMAIN-MAP-user-experience
domain: "user-experience"
source_specs: [SPEC-008]
related_usecases: [UC-05, UC-06]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — user-experience

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-008（FR 清單）交叉引用。

## 1. 目的

user-experience domain 涵蓋 Popup 介面、書庫總覽、搜尋篩選、主題管理、通知和無障礙功能。本 domain 大部分 bundle 屬 presentation 層或 cross-cutting，domain 層僅有 SearchEngine 衍生計算。

## 2. 分層與依賴方向

```
user-experience presentation（Popup / Overview / Theme / Notification）
        │ 依賴（單向）
        ▼
user-experience read-model（SearchEngine — 搜尋索引與篩選）
        │ 依賴（單向）
        ▼
core（ErrorCodes, COLORS design-system）+ data-management（Book/Tag aggregate，透過 Storage 讀取）
```

**依賴方向底線（不可違反）**：

- user-experience 不得修改 data-management 的 aggregate（Book / Tag）。只讀取不寫入。寫入操作透過 messaging 觸發 data-management 的服務。
- user-experience domain service 不得 import Chrome Storage API 直接讀取。透過 data-management 提供的介面。
- presentation 層依賴 core design-system（COLORS / SPACING），不反向依賴。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Search Engine | read-model | SearchEngine、SearchIndexManager、SearchCoordinator、FilterEngine、BookSearchFilter | 搜尋 UI 元件 | `src/ui/search/`, `src/ui/` | unit：索引建立、搜尋結果排序、多條件篩選 | 已實作 |
| Popup UI | 非 domain（presentation） | PopupController、PopupEventController、PopupProgressManager、PopupStatusManager、PopupCommunicationService、PopupExtractionService、PopupUIComponents、PopupUIManager、PopupUICoordinationService | 業務邏輯 | `src/popup/` | widget test：UI 渲染、按鈕事件 | 已實作 |
| Overview Page | 非 domain（presentation） | OverviewPageController、overview.js、BookGridRenderer（虛擬滾動） | 業務邏輯 | `src/overview/`, `src/ui/` | widget test：書籍網格渲染、虛擬滾動 | 已實作 |
| Theme & Personalization | 非 domain（cross-cutting） | ThemeManagementService、PreferenceService、PersonalizationService | 業務邏輯 | `src/background/domains/user-experience/services/` | unit：主題切換、偏好持久化 | 已實作 |
| Notification & Accessibility | 非 domain（cross-cutting） | NotificationService、AccessibilityService | 業務邏輯 | `src/background/domains/user-experience/services/` | unit：通知觸發、無障礙合規 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Search Engine | 空搜尋回傳全部書籍；搜尋結果按相關度排序；多條件篩選交集正確 | 已實作 |
| Popup UI | popup 開啟時顯示當前書籍數量；提取按鈕狀態與提取流程同步 | 已實作 |
| Overview Page | 虛擬滾動渲染可見範圍內的書籍卡片；書籍數量 > 0 時 tableBody 非空 | 已實作 |
| Theme & Personalization | 深色/淺色主題切換後 CSS 變數更新；偏好持久化後重啟保留 | 已實作 |
| Notification & Accessibility | 通知顯示後可手動關閉；無障礙色彩對比度 >= 4.5 | 已實作 |

## 4. 邊界決策

### 4.1 SearchEngine 為唯一 domain 層 bundle

user-experience 的大部分功能（Popup / Overview / Theme / Notification / Accessibility）屬 presentation 或 cross-cutting。SearchEngine 是唯一的 domain read-model——它從 Book/Tag aggregate 建立搜尋索引並提供衍生查詢。

### 4.2 UXDomainCoordinator 歸 presentation 層

UXDomainCoordinator 協調 Theme / Preference / Personalization / Notification / Accessibility 五個 service，這些都屬 presentation cross-cutting 關注。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 搜尋功能擴展 | domain | 修改 Search Engine bundle |
| Popup UI 修改 | presentation | 修改 Popup UI bundle，不涉及 domain |
| Overview 顯示調整 | presentation | 修改 Overview Page bundle |
| 新增通知類型 | cross-cutting | 修改 Notification bundle |

## 6. 觀察到的技術債（待追蹤）

截至本次審查，已掃描以下面向均無異常：UXDomainCoordinator 協調複雜度、虛擬滾動實作、SearchEngine 索引策略。

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 Popup 介面 | Popup UI | 非 domain（presentation） |
| FR-02 書庫總覽 | Overview Page | 非 domain（presentation） |
| FR-03 搜尋與篩選 | Search Engine | domain read-model |
| FR-04 主題與個人化 | Theme & Personalization | 非 domain（cross-cutting） |
| FR-05 通知與無障礙 | Notification & Accessibility | 非 domain（cross-cutting） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
