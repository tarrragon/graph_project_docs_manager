---
id: PROP-002
title: "圖譜 schema 消費方式：讀取框架隨附的 tracking_schema.json"
status: confirmed
source: development
proposed_by: saas-tech-selection 訪談
proposed_date: "2026-08-26"
confirmed_date: "2026-08-26"
target_version: null
priority: P0

outputs:
  spec_refs: []
  usecase_refs: []
  ticket_refs: []

related_proposals: [PROP-001]
supersedes: null
---

# PROP-002: 圖譜 schema 消費方式：讀取框架隨附的 tracking_schema.json

## 需求來源

本 App 的核心資料模型是框架的文件圖譜型別表（7 節點 / 16 邊），其唯一 SSOT 為
`.claude/skills/doc/doc_system/core/tracking_schema.py`。該檔檔頭明文規定消費端
一律引用本模組常數、禁止 inline 猜測欄位名，以防雙份 SSOT 漂移。

問題是本 App 以 Dart 撰寫，無法直接 import Python 模組。

## 問題描述

初始討論列出三條路，但都預設了「schema 只以 Python 形式存在」這個可以改變的前提：

1. **執行期呼叫 Python 子程序** —— 需使用者機器有 Python 或 uv
2. **建置期產生 JSON 資產** —— schema 被烘進 binary
3. **Dart 側重建型別表** —— 產生第二個 SSOT

真正的決定性因素是**版本偏斜**：本 App 會安裝在其他人的機器上、讀取他們的
`.claude/`，而該框架版本不等於編譯 App 時的版本。框架演進速度可觀（單日內
自 v2.40.2 至 v2.41.0），且已知 `layer` 欄位的值將於上游 ticket `0.2.1-W3-1110`
變動。

方案 2 因此不成立：使用者的框架比 App 新時，會靜默渲染出錯誤的圖，而雙方
各自都「正確」。**這個問題下游解不掉** —— 契約測試比對的是 build 當下的兩份，
跑不到使用者機器上那一份。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | 圖譜型別載入層、圖建構器、渲染層的型別分派 |
| 檔案 | 尚未建立；預期為 `lib/schema/` 之下 |
| 用例 | 所有依賴節點／邊型別的操作 |

## 範圍界定

### 本提案要做的（In Scope）

- 自使用者專案的 `.claude/skills/doc/doc_system/core/tracking_schema.json` 載入型別表
- 自 `.claude/VERSION` 讀取使用者的框架版本，超出 App 已知範圍時明確警告
- 契約測試：驗證 App 的型別模型與磁碟上的 JSON 雙向一致
- 契約測試：逐一將 JSON 內的 `id_pattern` 在 Dart `RegExp` 編譯並跑過樣本

### 本提案不做的（Out of Scope）

- 呼叫 `doc schema export --json` 取得同內容 → 讀檔即可，多一層子程序無收益
- 支援多個框架版本的型別表並存 → 一次只開一個專案，無此需求
- 型別表的編輯能力 → JSON 為衍生產物，唯一 SSOT 是 `.py`

## 提案方案

### 建議方案

**由上游同時產出機器可讀格式，本 App 讀該檔。**

```
.claude/skills/doc/doc_system/core/
  tracking_schema.py      唯一 SSOT，人寫、供 Python 使用
  tracking_schema.json    衍生產物，隨框架同步，供任何語言消費
```

此方案已由上游實作完成（框架 v2.41.0，ticket `0.2.1-W3-1113`），欄位全帶，
並附雙向一致性測試。

理由：

1. **版本永遠正確** —— JSON 跟隨使用者的框架版本，而非 App 的 build
2. **零執行期依賴** —— 不需要使用者機器上有 Python 或 uv
3. **零解析脆弱性** —— `jsonDecode`，而非自製 Python 子集 parser
4. **比對粒度爭議消失** —— JSON 僅含可消費欄位，註解不在其中；上游曾有一次
   僅修改註解與 `carrier` 說明文字的變更，若比對檔案雜湊會產生無意義紅燈
5. **契約測試由 N 份收斂為 1 份** —— 一致性由上游單一測試守護

第 5 點為選擇上游而非下游的主因。schema 設計本即預期多消費端，未來若出現
其他形態的消費者，沿用同一份 JSON 的成本為零。

### 被否決的方案

**Dart 側靜態解析 `.py`**：實測不可行度高。`ast.literal_eval` 對
`GRAPH_NODE_TYPES` 與 `GRAPH_EDGE_TYPES` 皆失敗，因兩者引用
`GRAPH_LAYER_ESTABLISHED` / `GRAPH_LAYER_PROPOSED` 具名常數
（`tracking_schema.py:122-123`）。要在 Dart 解析等同重寫 Python 子集 parser，
上游變更寫法即碎裂。

## 兩個版本欄位的語意區別

| 判斷 | 來源 |
|------|------|
| 使用者的框架版本是否超出 App 已知範圍 | `.claude/VERSION`（純版本字串） |
| 這份 schema 上次變動的時點 | JSON 的 `schema_generated_at_framework_version` |

兩者可能不同且皆正確：schema 內容自 2.40.3 起未變，而框架已至 2.41.0
（該版推送的是匯出機制本身，非型別表）。若誤將後者當作「當前框架版本」，
會得出與事實相反的結論。

## 驗收條件

- [ ] App 能自使用者專案載入 `tracking_schema.json` 並建立型別模型
- [ ] 契約測試讀取**磁碟上的 JSON**，而非自身模型再序列化（見下方風險）
- [ ] 契約測試為雙向：JSON 有而模型無、模型有而 JSON 無，兩向皆紅
- [ ] 每個 `id_pattern` 皆能在 Dart `RegExp` 編譯，且對已知樣本行為正確
- [ ] `.claude/VERSION` 超出已知範圍時顯示明確警告，而非靜默渲染

## 風險與 Tripwire

**風險一：同源測試恆綠。** 上游第一版一致性測試比對的是即時產出與 `.py`，
兩端同源，恆等式恆成立 —— 突變測試才發現注入型別後 13 個測試仍全綠。
本 App 的等價檢查必須確認兩端不同源。此類測試的失效形態是永遠綠燈，
不會有人發現。

**風險二：`id_pattern` 正則方言。** 那些 pattern 為 Python `re` 方言，
目前語意與 Dart `RegExp` 相同，但具名群組、lookbehind、`\p{}` 有差異。
上游未來若加入這類語法，**失效的是本 App 而上游不會有紅燈**。

**Tripwire**：`0.2.1-W3-1110` 將把達標的 proposed 型別的 `layer` 改為
`established`。僅改值不改鍵名，屬相容變更，但屆時 App 對 proposed 型別的
渲染策略需重新檢視。
