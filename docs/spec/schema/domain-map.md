---
id: DOMAIN-MAP-schema
domain: "schema"
source_specs: [SPEC-006, SPEC-007]
related_usecases: [UC-01]
depends_on_bundles: []
path_patterns: [lib/schema/]
created: "2026-08-26"
updated: "2026-10-07"
---

# Domain Map — Schema

> 產出來源：0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）。本文件界定 Schema domain 的 bundle 邊界，作為切層、派發與測試策略的權威依據。
> 跨 domain 的決策（bundle 間依賴方向、通道、邊界決策、容錯、待決）見系統層 `docs/system-layer.md`；
> 本檔 frontmatter 的 `depends_on_bundles` 是兩者的連結點，出邊的唯一權威在本檔 frontmatter。

## 1. 目的與範圍

本文件界定本 App **自身**的 Schema domain 邊界（水平視角）。切分依據是**變更理由的來源**，UC／DDD 正交關係見系統層 §1.1。

**唯一變更理由**：上游 schema 格式或版本語意改變

## 2. 分層與依賴方向

層級：L0（層級圖與完整依賴邊見系統層 §2）。

| 方向 | 對象 | 為什麼 |
|------|------|--------|
| 出邊 | （無） | `depends_on_bundles: []` |
| 入邊 | Corpus | 以 `id_pattern` 為有 frontmatter 的檔案判型；以「路徑對型別」查詢分流沒拿到可用 frontmatter 的檔案（SPEC-006 FR-03、FR-06，見系統層 §5） |

## 2.5 通道與協調圖

通道清單、協調圖與到達類別實例見系統層 §3。本 domain 的逐 domain 判定（判準：該 domain 的公開面是否包含「不必然由使用者當下操作觸發、卻需要佔用使用者呈現焦點通道」的事件）：

| Domain | 是否產生注意力請求 | 依據 |
|--------|:---:|------|
| Schema | 是 | 型別表缺席時降級為顯式啟動關卡（`docs/tech-decisions.md` 補記段「2026-09-03：型別表缺席時降級而非拒絕」，使用者需按「以 App 內建型別表檢視」才能進入） |

## 3. Bundle 界定表

| Domain | 唯一變更理由 | 公開面（OCP） | 內部面 |
|--------|------------|-------------|-------|
| **Schema** | 上游 schema 格式或版本語意改變 | 型別表（節點／邊定義）、版本相容判定、**路徑對型別查詢**（依 carrier 路徑模式與具體度，SPEC-006 FR-06） | JSON 解析、`.claude/VERSION` 讀取、內建表補欄位 |

### Bundle 不變式清單

供 version-bootstrap Step 5 逐條轉成 domain unit test，不靠「剛好出現在某個 UC 場景」被動覆蓋。規則權威在 SPEC-006，本表只列可獨立斷言的不變式；目標路徑為 `lib/schema/`（此為目標邊界，非現況：2026-09-24 規劃時該目錄尚不存在）。

| Bundle | 不變式（每條可轉一個 unit test） | SPEC-006 |
|---|---|---|
| Schema | 路徑對型別查詢比對完整相對路徑、區分大小寫；`docs/spec/<d>/README.md` 不命中 SPEC | FR-06 規則 1、4 |
| Schema | 多型命中時具體度高者勝：整段固定文字才算字面段；先比字面段數，再比跨多段萬用成分數 | FR-06 規則 6 |
| Schema | 具體度相同時回傳平手，列出全部候選並標記 schema 歧義，不擅自取一型 | FR-06 規則 5、6 |
| Schema | 型別表中不帶 `carrier_path_patterns` 的型別（例如 FlowStep）不參與路徑比對；依欄位判定，不依型別名 | FR-06 規則 3、D9 |
| Schema | 路徑模式以 ASCII 語意比對：`\d` 不匹配全形數字 | FR-06 規則 2、D9 |
| Schema | 型別表來源三分：JSON 有路徑模式用 JSON；缺欄位且 JSON 版本不高於內建版本，只補路徑模式；其餘情況查詢不可用 | FR-06 規則 7 |

## 6. 待決事項

- **「App 已知範圍」判準已定案**（`0.2.0-W1-024`，2026-09-23 WRAP 快速模式）：
  `tracking_schema.json` 的 `schema_generated_at_framework_version` 不高於
  App 內建資產 `builtin_schema_version.json` 同名欄位時，版本在範圍內（正常）；
  高於時超出已知範圍（schema 不相容）。判定式為
  `!isHigherThanBuiltinSchemaVersion(jsonSchemaVersion, builtinSchemaVersion)`
  ——重用既有函式，僅第一運算元改為 JSON 版本。CLAUDE.md §6 五項空殼判準
  原列有此項，定案後應移除。依賴本判準的重評項：SPEC-001 §1 L67-68 註記
  （面板改放 App 已知版本範圍，trigger 已滿足）、W3-335.37 R4（O4 重評）

> 跨 domain 的待決事項見系統層 §6。

## 7. FR → Bundle 覆蓋對照

### SPEC-006（0.3.0 Corpus）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-06 | 路徑對型別查詢 | Schema | domain unit；IT-2 |

> SPEC-006 全表的權威在 `docs/spec/corpus/domain-map.md` §7；此處僅列歸屬本 domain 的列。

### SPEC-007（0.4.0 Graph）

| FR | 內容 | Bundle | 測試層 |
|----|------|--------|-------|
| FR-01 | 邊型表 | Schema | domain unit |

> SPEC-007 全表的權威在 `docs/spec/graph/domain-map.md` §7；此處僅列歸屬本 domain 的列。

---

**Last Updated**: 2026-10-07 | **Source**: 0.5.0-W1-070.3（依 0.5.0-W1-070 盤點，拆自原單檔 domain-map）
