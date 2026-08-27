---
id: DOMAIN-MAP-system
domain: "system"
source_specs: [SPEC-007]
related_usecases: [UC-08]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — system

> 產出來源：1.6.1-W2-002。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 SPEC-007（FR 清單）交叉引用。

## 1. 目的

system domain 管理 Chrome Extension 的生命週期（SW 啟動/關閉）、配置管理、版本控制、健康監控和系統診斷。

## 2. 分層與依賴方向

```
所有其他 domain（透過 lifecycle hooks 啟動/停止）
        │
system domain service（生命週期、配置、版本、健康）
        │ 依賴（單向）
        ▼
core（ErrorCodes, EventBus）
```

**依賴方向底線（不可違反）**：

- system 不得 import 業務 domain（extraction / data-management / user-experience）。違反則系統管理耦合業務邏輯。
- system 不得 import presentation / UI 框架。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 | 實作狀態 |
|---|---|---|---|---|---|---|
| Lifecycle Management | domain service | LifecycleManagementService、background.js（SW 啟動）、BackgroundCoordinator、install-handler、startup-handler、shutdown-handler、lifecycle-coordinator | 各 domain 的初始化邏輯 | `src/background/`, `src/background/lifecycle/`, `src/background/domains/system/` | unit + integration：初始化順序、關閉清理 | 已實作 |
| Config Management | domain service | ConfigManagementService（配置載入、預設值、覆蓋） | 業務配置項 | `src/background/domains/system/services/` | unit：配置載入、合併、驗證 | 已實作 |
| Version Control | domain service | VersionControlService（版本檢查、升級管理） | Schema migration（歸 data-management） | `src/background/domains/system/services/` | unit：版本比較、升級判斷 | 已實作 |
| Health Monitoring | read-model | HealthMonitoringService（系統狀態監控、心跳） | 業務狀態監控 | `src/background/domains/system/services/` | unit：健康指標計算 | 已實作 |
| Diagnostics | read-model | DiagnosticService（除錯資訊收集、健康報告） | 業務診斷 | `src/background/domains/system/services/` | unit：報告生成 | 已實作 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） | 已實作 |
|---|---|---|
| Lifecycle Management | SW 啟動順序：install-handler → startup-handler → registerServiceWorkerEvents；shutdown 廣播 SYSTEM.SHUTDOWN 後才回收 | 已實作 |
| Config Management | 配置必有預設值；使用者覆蓋不影響預設值完整性 | 已實作 |
| Version Control | 版本比較遵循 semver；升級從低到高單調；降級被拒 | 已實作 |
| Health Monitoring | 健康狀態為 healthy/degraded/unhealthy 三態；心跳間隔可配置 | 已實作 |
| Diagnostics | 診斷報告包含所有必要系統資訊（版本、配置、模組狀態） | 已實作 |

## 4. 邊界決策

### 4.1 Lifecycle 元件物理位置

install-handler / startup-handler / shutdown-handler / lifecycle-coordinator 物理上在 `src/background/lifecycle/` 而非 `src/background/domains/system/`，但職責屬 system domain 的生命週期管理。background.js 為 SW 入口，協調所有 domain 的初始化，歸 system domain。

### 4.2 BackgroundCoordinator 歸 system

BackgroundCoordinator 統一協調所有 Background 模組（含各 domain coordinator），屬 system domain 的系統級協調職責。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| SW 啟動順序修改 | domain | 修改 Lifecycle Management bundle；更新 SPEC-002a §4 Lifecycle 契約 |
| 健康監控指標新增 | domain | 修改 Health Monitoring bundle |
| 版本升級策略 | domain | 修改 Version Control bundle |

## 6. 觀察到的技術債（待追蹤）

- Lifecycle 元件分散在 `src/background/lifecycle/` 和 `src/background/domains/system/`，物理位置不統一

## 7. FR → Bundle 覆蓋對照

| FR | 覆蓋 | 備註 |
|---|---|---|
| FR-01 Extension 生命週期管理 | Lifecycle Management + Config Management + Version Control | domain |
| FR-02 健康監控與診斷 | Health Monitoring + Diagnostics | read-model |

---

**Last Updated**: 2026-07-23 | **Source**: 1.6.1-W2-002
