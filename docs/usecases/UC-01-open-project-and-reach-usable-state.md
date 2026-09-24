---
id: UC-01
title: "開啟專案並抵達可用狀態"
status: draft
source_proposal: PROP-003
created: "2026-08-26"
updated: "2026-09-24"
version: "1.4"

primary_actor: "框架使用者（專案維護者）"
secondary_actors: []

platform: "app"
extension_status: "not-applicable"

runtime_surface: "yes"

related_specs: [SPEC-001, SPEC-006]
related_usecases: []
ticket_refs: []
---

# UC-01: 開啟專案並抵達可用狀態

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-01 |
| 用例名稱 | 開啟專案並抵達可用狀態 |
| 主要行為者 | 框架使用者（專案維護者） |
| 利益關係人 | 維護者：需在變更前掌握影響面與現況，避免遺漏 |
| 前置條件 | App 已安裝；使用者的機器上有至少一個使用本框架的專案 |
| 成功保證 | Domain 視圖顯示該專案的圖譜，或明確說明為何無法顯示 |

## 主要成功場景

1. **選擇資料夾**
   - 使用者自側欄浮層選擇專案資料夾，系統確認其存在且可讀

2. **載入型別表**
   - 系統自該專案的 .claude/ 讀取 tracking_schema.json 與 VERSION

3. **解析節點**
   - 系統掃描 docs/ 下的圖譜節點檔並解析 frontmatter

4. **抵達 Domain 視圖**
   - 系統以矩陣模式呈現 domain × UC 交叉表

## 替代場景

### 資料夾不可用

最近專案清單中的資料夾不存在或無法讀取時，浮層以常駐文字標示該項不可用並附
原因，其餘項仍可選；經選擇器新選的資料夾不存在或無法讀取時，停在原處並以
暫態提示說明原因，不加入最近清單

### 空專案

解析成功但無任何圖譜節點時，顯示說明並提供開啟 docs/ 目錄、導覽至破洞報告與切換專案的動作

## 流程拓撲（結構化 Flow 區塊）

```yaml
flow:
  - id: "select-folder"
    name: "選擇資料夾"
    next: ["load-schema"]
    branch_from: null
    return_to: null
    emits: ["EVT-WORKSPACE-001"]
    consumes: []
    traverses: ["Workspace"]
  - id: "load-schema"
    name: "載入型別表"
    next: ["parse-nodes"]
    branch_from: null
    return_to: null
    emits: ["EVT-SCHEMA-001"]
    consumes: ["EVT-WORKSPACE-001"]
    traverses: ["Schema"]
  - id: "parse-nodes"
    name: "解析節點"
    next: ["reach-domain-view"]
    branch_from: null
    return_to: null
    emits: ["EVT-CORPUS-001"]
    consumes: ["EVT-SCHEMA-001"]
    traverses: ["Corpus"]
  - id: "reach-domain-view"
    name: "抵達 Domain 視圖"
    next: []
    branch_from: null
    return_to: null
    emits: []
    consumes: ["EVT-CORPUS-001"]
    traverses: ["Corpus"]
  - id: "folder-unavailable"
    name: "資料夾不可用"
    next: []
    branch_from: "select-folder"
    return_to: "select-folder"
    emits: []
    consumes: []
    traverses: ["Workspace"]
  - id: "empty-graph"
    name: "空專案"
    next: []
    branch_from: "parse-nodes"
    return_to: null
    emits: []
    consumes: []
    traverses: ["Graph"]
  - id: "schema-rejected"
    name: "版本不符拒絕渲染"
    next: []
    branch_from: "load-schema"
    return_to: "select-folder"
    emits: ["EVT-SCHEMA-002"]
    consumes: []
    traverses: ["Schema"]
    implements: ["FR-04"]
```

## 例外場景

### schema 版本超出已知範圍

顯示兩個版本值與說明，不繪製圖譜；切換專案浮層維持可用

### 部分檔案解析失敗

不中止整輪解析；落在節點 carrier 路徑內的失敗檔案列入破洞報告，其餘（README、
工作日誌等合法非節點檔）不列入；圖譜以可解析部分呈現（SPEC-006 FR-04、FR-06）

### 不是框架專案

`.claude/VERSION` 與 `tracking_schema.json` 皆缺時，顯示「此資料夾缺少本框架
所需的設定檔（`.claude/VERSION` 與型別表皆缺），不是使用本框架的專案」並說明
本 App 需要什麼；僅提供切換專案，浮層維持可用（`0.1.0-W3-335.56` WRAP 裁決
判定條件，`0.1.0-W3-335.58` 回寫）

### 無可消費的型別表

`.claude/VERSION` 存在但 `tracking_schema.json` 檔案不存在時，顯示專案
`.claude/VERSION` 版本值與降級說明；`.claude/VERSION` 不高於 App 內建型別表
的產生版本時，額外提供「以 App 內建型別表檢視」動作（高於時不提供，僅剩
切換專案）

## 驗收條件

- [ ] 選定資料夾後，Domain 視圖在節點數 20 以內時於 1 秒內可用
- [ ] 資料夾不可用時，錯誤訊息指出具體原因而非泛用失敗
- [ ] schema 版本不符時不繪製任何圖譜元素
- [ ] 落在節點 carrier 路徑內的解析失敗檔數量顯示於破洞報告，且不影響其餘節點的呈現

## 變更歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| 1.4 | 2026-09-24 | 0.3.0 規劃波 Step 4：〈部分檔案解析失敗〉與對應驗收改為只有 carrier 路徑內的失敗檔列入破洞報告（SPEC-006 D6）；`related_specs` 補 SPEC-006；不動結構化 flow 區塊 |
| 1.3 | 2026-09-15 | 追修同步稽核裁決議題 P1（`0.1.0-W3-335.59` WRAP，`0.1.0-W3-335.63` 落檔）：〈替代場景〉〈空專案〉動作清單補「導覽至破洞報告」，對齊 SPEC-001 §1 空圖可用操作欄；不動結構化 flow 區塊 |
| 1.2 | 2026-09-14 | 補寫〈例外場景〉兩則（`0.1.0-W3-335.58`，承 `0.1.0-W3-335.53` 範圍外問題 2）：「不是框架專案」「無可消費的型別表」——判定條件、顯示內容、使用者出口與 SPEC-001 §1 對應兩列、FR-07、〈Gate 三問對照〉判定順序段逐字一致；不新增規則，不動結構化 flow 區塊 |
| 1.1 | 2026-09-14 | 追修 V4 第二輪矛盾裁決 D7（`0.1.0-W3-335.47` WRAP，`0.1.0-W3-335.50` 落檔）：〈資料夾不可用〉改兩路——最近專案項常駐標示不可用；經選擇器新選的不可讀資料夾以暫態提示說明、不加入最近清單（落實 `0.1.0-W3-335.38` S-13／S-38 的 UC 回寫） |
| 1.0 | 2026-08-26 | 初版，`saas-tech-selection` Stage 6 產出 |
