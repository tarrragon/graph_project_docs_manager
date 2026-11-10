---
id: DOMAIN-MAP-observability
domain: "observability"
source_specs: [SPEC-010]
related_usecases: []
depends_on_bundles: []
path_patterns: []               # lib/observability/ 由 1.0.0-W3-553.2.2 建立後補上（validate 要求路徑存在）
created: "2026-11-10"
updated: "2026-11-10"
---

# Domain Map — Observability

> 產出來源：1.0.0-W3-553.2.1（依 1.0.0-W3-553.2 八項裁定新建）。本文件界定 Observability domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Observability domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：記錄的格式、錯誤來源分類、落地與保留政策，或可進入記錄的值的白名單改變

**新建依據**：對最近鄰 Diagnostics 的 SRP 三問與共現檢查通過（`1.0.0-W3-553.2.1` Problem Analysis；依 `docs/tech-decisions.md`〈domain 數量：只觸發檢查，不是上限〉）。兩者的分工：文件內容的缺陷是破洞，歸 Diagnostics；App 執行期的失敗記錄，歸本 domain。

## 2. 分層與依賴方向

層級：L0。本 domain 無出邊：SPEC-010 的型別不依賴任何 domain，工作區根路徑以純值傳入，不經 Workspace。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | 無 | 其他 domain 皆有出邊指向本 domain；本 domain 若依賴任何一個，即形成循環 |
| 入邊 | 其餘每個 domain | 各 domain 以本 domain 的 `LogSink<E>`、`LogFields` 與白名單型別發出日誌（SPEC-010 FR-03、FR-04） |

**依賴邊照實登記**（2026-11-10 用戶裁定，經主控 AUQ；`1.0.0-W3-553.2.1`）：其他 domain 對本 domain 型別契約的引用，與其他 import 關係同樣登記在各 domain-map 的 `depends_on_bundles`，不設橫切契約例外。後果：既有 domain 的層號一律 +1，相對順序不變。

**無出邊是不變式**：「工作區根路徑以純值傳入、不依賴 Workspace」（SPEC-010〈設計約束〉）在本裁定下是必要條件。新增本 domain 的任何依賴前，須先確認不會形成循環。

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Observability | 否 | 記錄只寫檔與 `developer.log`，不佔用使用者的呈現焦點通道；需要使用者知道的失敗由發出端轉為畫面錯誤態（〈2026-08-27〉裁決三） |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Observability** | 記錄格式、錯誤來源分類、落地與保留政策、白名單型別改變 | `LogSink<E>` 型別、`LogFields` 與白名單包裝型別、`ErrorSource`、`LogLevel`、共用 writer | 序列化、檔案輪替、`developer.log` 轉呼 |

### Bundle 不變式清單

目標路徑為 `lib/observability/`（此為目標邊界，非現況：2026-11-10 規劃時該目錄尚不存在）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC 條款 |
|---|---|---|
| Observability | 每筆記錄是一行可解碼的 JSON，必填欄位齊全 | SPEC-010 FR-01 |
| Observability | 全域攔截層發出的記錄，`error_source` 恆為 `internal` | SPEC-010 FR-02、FR-07 |
| Observability | 工作區外的絕對路徑無法建構為工作區相對路徑 | SPEC-010 FR-03 |
| Observability | 帶例外物件的記錄不含例外的 `toString()` 結果 | SPEC-010 FR-03 |
| Observability | 現行檔達上限即輪替，歷史檔數不超過規定值 | SPEC-010 FR-05 |
| Observability | `debug` 記錄不寫檔 | SPEC-010 FR-05 |
| Observability | writer 失敗時呼叫端不收到例外，且 `developer.log` 有一筆 warning | SPEC-010 NFR-01 |

## 6. 待決事項

- 無本 domain 專屬的待決事項。依賴邊的登記方式已於 2026-11-10 裁定（§2）。

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-010（1.0.0 Observability）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | 記錄信封 | Observability | domain unit |
| FR-02 | 錯誤來源分類 | 發出端各 domain（分類在攔下失敗的那一層決定） | 各 domain unit |
| FR-03 | 欄位值白名單 | Observability | domain unit |
| FR-04 | LogSink 契約 | Observability（型別）；各 domain（遷移） | domain unit；各 domain unit |
| FR-05 | 落地位置與輪替 | Observability | domain unit |
| FR-06 | 與 `developer.log` 並寫 | Observability | domain unit |
| FR-07 | 全域攔截出口寫入記錄 | 組裝根（畫面狀態層） | widget／integration |

---

**Last Updated**: 2026-11-10 | **Source**: 1.0.0-W3-553.2.1
