---
id: SPEC-006
title: "Corpus 解析與破洞判定"
status: draft
source_proposal: PROP-005
created: "2026-09-24"
updated: "2026-09-24"
version: "1.0"
owner: "主線程（PM）"

domain: "corpus"
subdomain: null

related_usecases: [UC-01, UC-05, UC-06]
related_specs: [SPEC-001, SPEC-005]
implements_requirements: []
depends_on_domains: [schema, workspace]
---

# Corpus 解析與破洞判定

## 概述

本規格定義 0.3.0（Corpus）的兩段資料管線：**Corpus** 把工作區內的 markdown
語料解析為原始節點與解析錯誤；**Diagnostics** 依 Schema 的 carrier 路徑模式，
把「沒有 frontmatter 的檔案」分成真破洞與合法非節點。兩者的分工依
`docs/domain-map.md` §2 依賴邊：Corpus 是唯一的解析者；「這算不算破洞」需要
解析結果與 carrier 兩者才能回答，因此歸 Diagnostics。

版本契約（PROP-005 §0.3）為兩項整合測試，本規格的 FR 以它們為驗收終點：

| 整合測試 | 驗收的 FR | 斷言 |
|---------|----------|------|
| IT-1 解析語意 | FR-01 | 逐行語意對判別樣本的解析失敗數為 0；天真語意（`split("---")`）對同一批樣本全數失敗，兩者的差即鑑別力 |
| IT-2 破洞分類 | FR-05、FR-06 | 凍結 manifest 內每一列的分類（真破洞／合法非節點）與預期一致 |

兩項的數字取自凍結 manifest 的重新量測值（見〈設計約束〉D3），不沿用
PROP-005 記載的 2026-08-27 即時語料數字（47／1243／130），因為語料之後已變動。

### 本版範圍外

| 項目 | 不在本版的理由 | 承接 |
|------|--------------|------|
| 原始邊（`rawEdges`）的抽取 | 建圖屬 0.4（Graph），兩項整合測試皆不需要邊 | PROP-005 §0.4 |
| 破洞類別 `graphDefect`／`traceGap`／`unlocatable` | 需要圖或追溯資料；本版只實作 `parseFailure` | EVT-DIAGNOSTICS-001、PROP-005 §0.4／§0.6+ |
| frontmatter 存在但 `id` 不符合任何型別的 `id_pattern`，且位於 carrier 路徑內 | 歸哪一類破洞仍是待決項（`docs/domain-map.md` §9「`id_pattern` 隨版本變動時舊語料的不合法 id 歸哪一類破洞」） | 規劃波 Step 6 建票 |
| YAML 損壞檔的部分欄位救回 | 語料中 YAML 錯誤僅 1 件（`docs/domain-map.md` §7），部分救回的演算法沒有樣本可校準 | FR-04 本版只回報、不救回 |

## 功能需求

### FR-01：逐行 frontmatter 語意

**描述**：Corpus 以逐行語意切出 frontmatter，與框架既有解析函式
（`.claude/skills/doc/doc_system/core/frontmatter_parser.py`）的語意相同。

**規則**：

| # | 規則 |
|---|------|
| 1 | 檔案第一行去除前後空白後必須等於 `---`，否則判定為「無 frontmatter」 |
| 2 | 從第二行往下找**第一個**去除前後空白後等於 `---` 的行作為結尾；找不到則判定為「無 frontmatter」 |
| 3 | 兩者之間的內容以 YAML 解析；結果必須是 map，否則判定為「YAML 錯誤」 |
| 4 | 檔案開頭的 UTF-8 BOM 先移除再套用規則 1（框架以 `utf-8-sig` 讀檔） |
| 5 | 禁止以字串切分（`split("---")`）取 frontmatter：frontmatter 內被引號包住的 markdown 表格分隔線（`|---|`）會使其提前截斷 |

**驗收條件**：
- [ ] Given 一份 frontmatter 內含引號字串 `"|---|---|"` 的真實 ticket，When 以逐行語意解析，Then 取得完整 map，且欄位數與框架解析函式一致
- [ ] Given 同一份檔案，When 以天真語意解析，Then 失敗（鑑別對照：兩種語意對判別樣本的結果必須不同）
- [ ] Given 第一行不是 `---` 的檔案，Then 判定為「無 frontmatter」，不是「YAML 錯誤」

### FR-02：掃描範圍

**描述**：Corpus 掃描工作區根目錄下 `docs/` 內所有副檔名為 `.md` 的檔案（遞迴）。

**規則**：
- 範圍與 PROP-005 §0.3 量測時一致（`docs/**/*.md`），carrier 路徑模式全數落在 `docs/` 之下
- 工作區根目錄取自 Workspace domain（`docs/domain-map.md` §2 依賴邊 Corpus → Workspace）
- 路徑一律以相對於工作區根目錄、以 `/` 分隔的形式參與後續比對

**驗收條件**：
- [ ] Given 工作區含 `docs/` 以外的 `.md`，Then 不進入掃描結果
- [ ] Given `docs/` 下多層子目錄內的 `.md`，Then 全數進入掃描結果

### FR-03：節點判型

**描述**：有 frontmatter 的檔案，以其 `id` 比對 Schema 各節點型別的 `id_pattern` 判型。

**規則**：
- 型別判別以 `id_pattern` 為準，不以 carrier 為準（`docs/domain-map.md` §7）
- 各型別 `id_pattern` 兩兩互斥由上游 conformance 測試保證，一個 `id` 至多命中一型
- `id` 缺席或不命中任何型別：本版不列為節點，也不列為破洞（見〈本版範圍外〉第三列）

**驗收條件**：
- [ ] Given frontmatter `id: SPEC-001`，Then 判為 SPEC；Given `id: DOMAIN-MAP-docs-graph`，Then 判為 DomainBundle
- [ ] Given frontmatter 無 `id`，Then 不產生節點、不產生破洞

### FR-04：YAML 錯誤

**描述**：frontmatter 區塊存在但 YAML 解析失敗時，產生一筆解析錯誤，對應 EVT-CORPUS-003。

**規則**：
- 錯誤帶相對路徑、原因（YAML 錯誤）、行號（解析器提供時）
- `salvagedFields` 本版一律為空清單，不做部分救回
- `lostFields` 依 EVT-CORPUS-003〈lostFields 的算法〉：該型別完整性集合減去實際寫出的鍵；無法判型時為空清單。本項以 `tracking_schema.json` 匯出完整性集合為前提（`0.3.0-W1-079`）
- 單檔失敗不中止整輪掃描

**驗收條件**：
- [ ] Given 一份 YAML 語法錯誤的檔案與其他正常檔案，Then 產生一筆解析錯誤且其他檔案照常解析

### FR-05：讀取失敗

**描述**：檔案無法以 UTF-8 解碼時（用戶裁決 D4），視為「無法讀取」，依 carrier 分流。

**規則**：

| 檔案位置 | 處置 |
|---------|------|
| 符合任一節點型別的 carrier 路徑模式 | 真破洞，原因為「編碼無法讀取」 |
| 不符合任何 carrier 路徑模式 | 與其他非節點相同，不報 |

- 不以寬鬆解碼（取代無效位元組）繼續解析，避免亂碼進入圖譜
- 讀取失敗不中止整輪掃描

**驗收條件**：
- [ ] Given carrier 路徑內一份非 UTF-8 的 `.md`，Then 產生一筆原因為編碼的破洞
- [ ] Given carrier 路徑外一份非 UTF-8 的 `.md`，Then 不產生破洞，且掃描完成

### FR-06：破洞分類（Diagnostics）

**描述**：對「無 frontmatter」與「無法讀取」的檔案，以 Schema 各型別的 carrier
路徑模式判定真破洞或合法非節點，產生 EVT-DIAGNOSTICS-001 的 `parseFailure` 類別。

**規則**：

| # | 規則 |
|---|------|
| 1 | 比對完整相對路徑（含檔名），不只比對所在目錄（`docs/domain-map.md` §7：目錄讀法在實測中 8 項有 7 項誤報） |
| 2 | 路徑模式取自 `tracking_schema.json` 的機器可比對欄位（用戶裁決 D1；上游欄位由 `0.3.0-W1-080` 新增），不解析人讀的 `carrier` 描述文字 |
| 3 | 命中任一型別模式 → 真破洞；全不命中 → 合法非節點，不報 |
| 4 | 同時命中多個型別時，**具體度較高的模式優先**（用戶裁決 D2），具體度算法由上游欄位定義；例如 `docs/spec/<domain>/domain-map.md` 歸 DomainBundle 而非 SPEC |
| 5 | 規則 4 只用於無 frontmatter 的檔案；有 frontmatter 的檔案仍依 FR-03 以 `id_pattern` 判型 |
| 6 | 每一筆破洞帶：相對路徑、歸屬型別、原因（無 frontmatter／編碼無法讀取／YAML 錯誤），資訊足以讓使用者直接去修 |

**驗收條件**：
- [ ] Given 凍結 manifest（IT-2），When 逐列分類，Then 每一列的真破洞／合法非節點判定與預期一致
- [ ] Given `docs/spec/<domain>/README.md` 無 frontmatter，Then 為合法非節點（不命中 SPEC）
- [ ] Given `docs/spec/<domain>/domain-map.md` 無 frontmatter，Then 為真破洞且歸屬型別為 DomainBundle
- [ ] Given `docs/work-logs/` 下非 `tickets/` 目錄的工作日誌無 frontmatter，Then 為合法非節點

### FR-07：掃描結果摘要

**描述**：一輪掃描完成時，產出 EVT-CORPUS-001（`rawNodes`、`parseErrors`）與
EVT-DIAGNOSTICS-001（`gaps`），並提供可驗證的計數。

**規則**：
- 計數至少含：掃描檔案總數、成功解析數、YAML 錯誤數、無 frontmatter 數、無法讀取數、真破洞數、合法非節點數
- 真破洞數 + 合法非節點數 = 無 frontmatter 數 + 無法讀取數
- `rawNodes` 攜帶該檔完整 frontmatter map、相對路徑與判定型別；邊的抽取不在本版

**驗收條件**：
- [ ] Given 任一語料，Then 計數守恆式成立

## 非功能需求

### NFR-01：失敗隔離

任一單檔的讀取失敗、YAML 錯誤或判型失敗，都不得中止整輪掃描或使其他檔案的結果改變。
**驗收**：在正常語料中插入三種失敗檔各一份，其餘檔案的解析結果與未插入時逐項相同。

## 錯誤處理

| 錯誤情境 | 處理方式 | 對應 |
|---------|---------|------|
| 檔案無法以 UTF-8 解碼 | 依 carrier 分流 | FR-05 |
| frontmatter YAML 語法錯誤 | 產生解析錯誤，不救回欄位 | FR-04 |
| frontmatter 解析結果不是 map | 同 YAML 錯誤 | FR-01 規則 3 |
| `tracking_schema.json` 缺少機器可比對的 carrier 欄位 | 無法做破洞分類；依 SPEC-001 v1.5 §1 的降級路徑使用 App 內建型別表，內建表同樣須含該欄位 | FR-06 規則 2 |

## 設計約束

| # | 約束 | 來源 |
|---|------|------|
| D1 | carrier 路徑模式由上游 schema 以機器可比對欄位提供，App 不解析描述文字 | 用戶裁決 2026-09-24；`0.3.0-W1-080` |
| D2 | 無 frontmatter 檔案命中多個 carrier 時，具體度較高者優先 | 用戶裁決 2026-09-24 |
| D3 | 整合測試使用凍結 manifest：重新量測五個語料專案（flutter_balance、book_overview_app、book_overview_v1、monitor、screen_clock），凍結為「相對路徑 + 有無 frontmatter／可否讀取 + 預期分類」三欄；預期分類須以獨立於待測實作的規則產生（沿用 `docs/domain-map.md` §7 的類別：`tickets/` 目錄、節點目錄、work-logs 非 ticket 檔、其他 docs 散檔、README／index），不得用待測實作的輸出當預期值。IT-1 另收錄天真語意會截斷的真實檔案作為判別樣本。0.2.0 先例：CI 環境沒有 `~/project` | 用戶裁決 2026-09-24；`test/integration/gate_manifest_test.dart` |
| D4 | 非 UTF-8 檔依 carrier 分流，不寬鬆解碼 | 用戶裁決 2026-09-24 |
| D5 | 完整性集合（`lostFields` 所用）語意為「欄位必須存在，值可為 null 或空清單」 | `tarrragon/claude#99` 第三項裁決；`0.3.0-W1-078` |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-09-24 | 初版：0.3.0 規劃波 Step 2，依 PROP-005 §0.3 與用戶裁決 D1～D5 建立 |
