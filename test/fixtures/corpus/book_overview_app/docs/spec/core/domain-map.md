---
id: DOMAIN-MAP-core
domain: "core"
source_specs: [SPEC-001]
related_usecases: [UC-09]
created: "2026-07-23"
updated: "2026-07-25"
---

# Domain Map — core

> 產出來源：0.38.1-W5-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。

## 1. 目的與 UC / DDD 正交關係

本文件描述 `lib/core/`（應用核心層）的 bundle 界定。`lib/core/` 提供跨 domain 共用的錯誤處理、日誌與降級基礎設施，被所有其他 domain 依賴。注意：`lib/core/` 是應用核心層，與 `lib/domains/core/`（僅含 `domain_event.dart`，定義 DomainEvent 基底類別）不同。

核心準則：domain 層保持純——無 I/O、無 UI 形狀、對顯示偏好與框架一無所知。分類術語（aggregate root / kernel / read-model / supporting VO / domain service）定義見 `.claude/methodologies/domain-bundle-mapping-methodology.md` §2。

## 2. 分層與依賴方向

**形態**：基礎設施共享層（被多 domain 消費）

```
所有 domain（library / scanner / search / ...）
        │ 依賴（單向）
        ▼
core aggregate + VO（AppException / ErrorCode / ErrorHandler / AppLogger）
```

**依賴方向底線**：
- `lib/core/` 不得 import 任何 domain（book_info / library / scanner / search / ...）。已驗證：lib/core/ 跨 domain import = 0。
- `lib/core/` 不得 import data / presentation / UI 框架。
- 所有 domain 可依賴 `lib/core/`（errors / logging），此為應用核心層依賴，非 domain-to-domain 依賴。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 | 資料契約文件引用連結 |
|---|---|---|---|---|---|---|---|
| AppException 階層 | aggregate root | AppException 基底 + 五大分類例外（Validation/Network/Business/Storage/Platform）+ 衍生例外（QueueException/StandardError）| 各 domain 專屬例外定義 | `lib/core/errors/` | unit：例外建構、分類一致性、JSON 序列化 | 已實作 | N/A |
| ErrorCode 體系 | supporting VO | ErrorCode 列舉（28 碼）+ ErrorCategory 列舉 + extension 屬性（code/description/isRecoverable/category）| 錯誤路由邏輯 | `lib/core/errors/` | unit：碼→分類映射、isRecoverable 正確性 | 已實作 | N/A |
| CommonErrors | supporting VO | 29 個預編譯常用錯誤實例 | 動態建構的錯誤 | `lib/core/errors/` | unit：常數存取 < 0.01ms | 已實作 | N/A |
| ErrorHandler | domain service | 靜態路由（handleError/logError/shouldNotifyUser/getUserMessage/reportError）| UI 層錯誤顯示 | `lib/core/errors/` | unit：分派邏輯、通知策略 | 已實作 | N/A |
| AppLogger | 非 domain（cross-cutting） | 統一日誌 API（debug/info/warning/error/fatal + static 方法 + QuickLog extension）| 日誌持久化（infra 層） | `lib/core/logging/` | unit：級別過濾、格式輸出 | 已實作 | N/A |
| GracefulDegradation | domain service | GracefulDegradationHandler + DegradedModeStrategy + FriendlyMessageGenerator + DegradationResult | API 呼叫實作 | `lib/core/` | unit：降級等級決策邏輯 | 已實作 | N/A |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| AppException 階層 | BusinessException 建構時 errorCode.category 必為 business（assert）；所有例外 toJson 必含 type/code/message/category/isRecoverable/timestamp 六欄位 |
| ErrorCode 體系 | 28 個 ErrorCode 各有唯一 SCREAMING_SNAKE_CASE code；每個 ErrorCode 屬於且僅屬於一個 ErrorCategory |
| CommonErrors | 29 個預編譯錯誤為 static final，常數時間存取 |
| ErrorHandler | handleError 對五大分類例外各有獨立處理方法；shouldNotifyUser 對 bookNotFound/duplicateBook/invalidIsbn 回傳 false |
| GracefulDegradation | quotaExhausted → offline 降級；rateLimitExceeded + failureRate > 0.7 → offline 降級；其餘 → basicInfo |

## 4. 邊界決策

### 4.1 core 不持有 domain 專屬例外

各 domain 的專屬例外（如 EnrichmentException、ImportException）在各自 domain 內定義，繼承 core 的基底例外。core 僅定義基礎骨架（五大分類）。依據：單一職責，避免 core 成為所有 domain 例外的集散地。

### 4.2 日誌為 cross-cutting 非 domain

AppLogger 雖在 core 目錄，但其職責為跨切面基礎設施（格式化輸出、級別過濾），非業務計算。分類為非 domain（cross-cutting），與真 domain bundle 視覺區隔。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 例外體系修改 | domain | 按 §3 AppException 階層 bundle；新增 ErrorCode 需同步 CommonErrors。粒度：新增一個 ErrorCode 為一張 ticket |
| 日誌工具修改 | cross-cutting | AppLogger API 變更影響所有 domain 的 catch 區塊。粒度：API 變更需一次更新所有消費者，合成一張 ticket |
| 降級策略修改 | domain | GracefulDegradation bundle，不影響 ErrorHandler 路由 |

## 6. 觀察到的技術債（待追蹤）

- Domain 例外一致性：library/scanner/search 的專屬例外直接 implements Exception，未繼承 core 例外體系（SPEC-001 差距分析已記錄）
- 錯誤記錄未持久化至 SQLite（UC-09 8A.3 要求，目前僅 console 輸出）

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-1（統一例外階層） | AppException 階層 | domain |
| FR-2（錯誤碼體系） | ErrorCode 體系 + CommonErrors | domain |
| FR-3（Domain 專屬例外） | 非 core bundle（各 domain 自管） | 各 domain 定義 |
| FR-4（全域錯誤攔截） | 非 domain（infrastructure） | main.dart 三層攔截屬 infra 層 |
| FR-5（ErrorHandler 路由） | ErrorHandler | domain service |
| FR-6（日誌系統） | AppLogger | cross-cutting |
| FR-7（降級恢復） | GracefulDegradation | domain service |

---

**Last Updated**: 2026-07-25 | **Source**: 0.38.1-W5-002 | 0.38.1-W9-003 補「實作狀態」欄 | 0.38.1-W10-006 補「資料契約文件引用連結」欄（core 無持久化 bundle，全列 N/A；template 2.2.0）
