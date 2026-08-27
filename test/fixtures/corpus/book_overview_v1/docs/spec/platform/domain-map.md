---
id: DOMAIN-MAP-platform
domain: "platform"
source_specs: [SPEC-003]
related_usecases: [UC-01, UC-07]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — platform

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-003（FR 清單）交叉引用。

## 1. 目的

platform domain 管理電子書平台的偵測、註冊、切換和適配器工廠。目前支援 Readmoo / 博客來 / Kobo，架構已為多平台預留（BookWalker / Kindle / Google Play Books 等）。

## 2. 分層與依賴方向

```
extraction（消費 adapter 實例提取資料）
        │
platform domain service（偵測、註冊、工廠）
        │ 依賴（單向）
        ▼
core（ErrorCodes）
```

**依賴方向底線（不可違反）**：

- platform 不得 import extraction / data-management / user-experience。違反則平台管理耦合業務邏輯。
- platform 不得 import presentation / UI 框架。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Platform Registry | domain service | PlatformRegistryService（平台註冊表、已註冊平台集合） | 平台偵測邏輯 | `src/background/domains/platform/services/` | unit：註冊/查詢/移除 | 已實作 |
| Platform Detection | domain service | PlatformDetectionService（URL/hostname → 平台識別） | Content Script 偵測（歸 page） | `src/background/domains/platform/services/` | unit：各書城 URL 識別 | 已實作 |
| Platform Switcher | domain service | PlatformSwitcherService（活躍平台切換邏輯） | UI 切換按鈕 | `src/background/domains/platform/services/` | unit：切換狀態轉換 | 已實作 |
| Adapter Factory | 非 domain（infra） | AdapterFactoryService（adapter 實例建立、資源池化） | adapter 實作（歸各書城） | `src/background/domains/platform/services/` | unit + integration：工廠建立正確類型 | 已實作 |
| Platform Validators | domain service | ReadmooMigrationValidator | 通用驗證（歸 extraction/data-management）；ReadmooDataValidator 歸 extraction（`src/extractors/`） | `src/platform/` | unit：平台專屬驗證規則 | 已實作 |
| Platform Isolation | 非 domain（infra，刻意暫置） | PlatformIsolationService（1,308 行）、CrossPlatformRouter | 所有其他 bundle | `src/background/domains/platform/services/` | （v2.0+ 啟用後補測試） | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Platform Registry | 註冊的 platformId 唯一；已註冊平台可查詢；未註冊平台查詢回傳 null | 已實作 |
| Platform Detection | readmoo.com 識別為 READMOO；books.com.tw 識別為 BOOKS_COM_TW；kobo.com 識別為 KOBO；未知域名回傳 null | 已實作 |
| Platform Switcher | 切換至已註冊平台成功；切換至未註冊平台失敗 | 已實作 |
| Adapter Factory | 工廠產出的 adapter 實作 PlatformAdapterInterface；資源池化不重複建立相同平台的 adapter | 已實作 |

## 4. 邊界決策

### 4.1 PlatformIsolationService v1.0 刻意暫置

PlatformIsolationService（1,308 行）程式碼已寫好但 v1.0 不啟用。多書城場景下的隔離改由 Storage Adapter 層的 platformBooksKey 簡單隔離（SPEC-STORAGE-ISOLATION）。完整隔離方案延至 v2.0 評估。

### 4.2 Platform Validators 物理位置

ReadmooMigrationValidator 在 `src/platform/` 而非 `src/background/domains/platform/`。ReadmooDataValidator 在 `src/extractors/`，歸 extraction domain。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 新書城平台支援 | domain | Platform Registry 註冊 + Platform Detection 加規則 |
| 新書城 adapter 實作 | data（infra） | 在 Adapter Factory 註冊，adapter 歸 extraction infra |
| v2.0 多平台隔離 | domain + infra | 啟用 Platform Isolation + 建獨立提案 |

## 6. 觀察到的技術債（待追蹤）

- PlatformIsolationService 1,308 行已寫但未啟用（v2.0 決策點）
- CrossPlatformRouter 介面預留但未實作

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 平台偵測與註冊 | Platform Registry + Platform Detection + Platform Switcher + Adapter Factory | domain + infra |
| FR-02 平台資料驗證 | Platform Validators | domain service |
| FR-03 多平台隔離 | Platform Isolation | 非 domain（infra，v2.0+ 暫置） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
