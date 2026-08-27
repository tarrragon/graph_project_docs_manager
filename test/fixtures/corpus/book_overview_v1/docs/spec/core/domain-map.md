---
id: DOMAIN-MAP-core
domain: "core"
source_specs: [SPEC-001]
related_usecases: [UC-01, UC-02, UC-03, UC-04, UC-05, UC-06, UC-07, UC-08]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — core

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-001（FR 清單）交叉引用。

## 1. 目的

core domain 是所有其他 domain 的基礎依賴，提供錯誤處理、事件系統、日誌、訊息字典、列舉、效能監控和資料遷移工具。UC-01 至 UC-08 全部間接依賴 core 提供的基礎設施。

## 2. 分層與依賴方向

```
所有其他 domain（extraction / data-management / messaging / page / platform / system / user-experience / synchronization）
        │ 依賴（單向）
        ▼
domain core（基礎設施層：ErrorCodes / EventBus / Logger / Enums / OperationResult）
```

**依賴方向底線（不可違反）**：

- core 不得 import 任何其他 domain。違反則基礎設施循環依賴，所有消費者耦合。
- core 不得 import data / presentation / UI 框架。違反則喪失純函式可測性。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| ErrorCodes + OperationResult | supporting VO | ErrorCodes 常數（11 類）、StandardError、NetworkError、BookValidationError、ErrorHelper、OperationResult | 各 UC 的 ErrorAdapter/Factory（歸各自 domain） | `src/core/errors/` | unit：錯誤碼唯一性、OperationResult 結構 | 已實作 |
| EventBus | 非 domain（infra） | EventBus、EventHandler、EventSystemUnifier、事件命名與優先級 | 事件消費者（歸各自 domain） | `src/core/events/`, `src/core/` | unit：事件註冊/發射/解除 | 已實作 |
| Logger | 非 domain（infra） | Logger 類別、日誌等級過濾、MessageDictionary 整合 | 各模組的具體日誌呼叫 | `src/core/logging/` | unit：多環境 logger、等級過濾 | 已實作 |
| MessageDictionary | supporting VO | 統一訊息管理、鍵值查詢、參數替換 | 各模組的具體訊息定義 | `src/core/messages/` | unit：鍵值查詢、參數替換 | 已實作 |
| Enum System | supporting VO | OperationStatus、ErrorTypes、MessageTypes、LogLevel、驗證工具 | 業務層列舉（ReadingStatus 歸 data-management） | `src/core/enums/` | unit：列舉值完整性、驗證函式 | 已實作 |
| Performance Monitoring | domain service | MetricsCollector、PerformanceAssessment、異常偵測 | 具體模組的效能資料來源 | `src/core/performance/` | unit：指標收集、評估計算 | 已實作 |
| Migration Tools | domain service | AutoMigrationConverter、MigrationValidator、StandardErrorWrapper | 具體 schema migration（歸 data-management） | `src/core/migration/` | unit：遷移驗證、進度追蹤 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| ErrorCodes + OperationResult | ErrorCodes 11 類分類碼互不重複；OperationResult.success=false 時 error 必存在 | 已實作 |
| EventBus | 同一事件名多次 on 後 emit 觸發全部 handler；off 後不再觸發；事件名符合命名規範 | 已實作 |
| Logger | 日誌等級 ERROR > WARNING > INFO > DEBUG 過濾正確；多環境（browser/Node.js）皆可輸出 | 已實作 |
| MessageDictionary | 鍵值查詢不存在時回傳 fallback；參數替換正確處理多參數 | 已實作 |
| Enum System | 每個列舉型別值集合不重複；驗證函式對非法值回傳 false | 已實作 |
| Performance Monitoring | MetricsCollector 指標不丟失；異常偵測閾值判定正確 | 已實作 |
| Migration Tools | MigrationValidator 驗證通過才允許遷移執行；遷移進度 0-100% 單調遞增 | 已實作 |

## 4. 邊界決策

### 4.1 UC-specific ErrorAdapter 不歸 core

各 UC 的 ErrorAdapter/ErrorFactory（如 UC01-UC07 ErrorAdapter）歸屬各自消費 domain，非 core。core 只提供基礎錯誤類別和 ErrorCodes 常數。依據：ErrorAdapter 包含業務邏輯（特定 UC 的錯誤對映），不屬基礎設施。

### 4.2 Design System 歸 core 但屬 presentation 邊界

`src/core/design-system/`（COLORS / SPACING / FONT_SIZES / SHADOWS）物理上在 core 路徑下，但功能屬 presentation cross-cutting。決策：保留現有路徑不遷出——Design System token 被所有 presentation 元件消費，放 core 確保零循環依賴。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| core domain 修改票 | domain | 按 bundle 拆分；任何 ErrorCodes 新增必須維持 11 類分類碼唯一性 |
| 新增 UC ErrorAdapter | 歸屬 UC 的 domain | 繼承 core StandardError，不修改 core |

## 6. 觀察到的技術債（待追蹤）

- Design System 放在 `src/core/` 目錄下但屬 presentation 關注，與 domain 層職責不一致（可考慮移至 `src/ui/` 或保持現狀加註解）

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 錯誤處理系統 | ErrorCodes + OperationResult | 基礎錯誤類別與常數 |
| FR-02 事件系統 | EventBus | 核心事件匯流排 |
| FR-03 日誌系統 | Logger | 多環境日誌 |
| FR-04 訊息字典 | MessageDictionary | 統一訊息管理 |
| FR-05 Enum 系統 | Enum System | 型別安全列舉 |
| FR-06 效能監控 | Performance Monitoring | 指標收集與評估 |
| FR-07 資料遷移 | Migration Tools | 遷移驗證與工具 |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
