---
id: SPEC-005
title: "Collector Rule Engine（最小驗證）"
status: draft
source_proposal: PROP-001
created: "2026-06-21"
updated: "2026-06-21"
version: "1.0"
owner: ""

domain: collector
subdomain: rule-engine

related_usecases: [UC-02]
related_specs: [SPEC-002, SPEC-004]
implements_requirements: []
depends_on_domains: [core]
---

# Collector Rule Engine（最小驗證）

## 概述

Collector 五段處理鏈路的第五段：事件寫入後觸發規則評估。MVP 只需驗證「rule engine 機制可運作」——至少一條 rule 能觸發並產生動作。

教學依據：[模組四：Rule engine 設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/rule-engine.md)

## 功能需求

### FR-01: 基於計數的 rule

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-02 |

**描述**：支援一種 rule 類型——「特定 type 的事件在時間窗口內超過 N 筆時觸發」。MVP rule：`type=error` 在過去 1 小時超過 10 筆時寫檔案通知。

**約束條件**：

- Rule 定義用 YAML/JSON 設定檔
- 觸發動作 MVP 只支援「寫檔案」（寫入指定路徑的 `.alert` 檔案）
- 評估頻率：每分鐘一次（批次掃描）。教學設計支援即時評估（事件寫入後逐筆評估）和批次評估兩種模式（見 [Rule engine 設計](https://github.com/tarrragon/blog/blob/main/content/monitoring/04-collector/rule-engine.md)），MVP 因唯一的 rule 為聚合類（count > N in window），只實作批次評估

**驗收標準**：

- [ ] 送入 > 10 筆 error 事件後，`.alert` 檔案被產生
- [ ] `.alert` 檔案含觸發時間、rule 名稱、匹配事件數

### FR-02: Rule 設定格式

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 |
| 對應用例 | UC-02 |

**描述**：Rule 定義為 YAML 格式，collector 啟動時載入。

```yaml
rules:
  - name: "high-error-rate"
    condition:
      type: "error"
      window: "1h"
      threshold: 10
    action:
      type: "file"
      path: "./alerts/"
```

**驗收標準**：

- [ ] collector 啟動時讀取 rules 設定
- [ ] 設定格式錯誤時 collector 啟動失敗並報錯

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| MVP 只支援計數 rule | 不含 rate rule / pattern rule | 後續版本擴充 |
| 觸發動作只支援寫檔案 | 不含 webhook / email / slack | 後續版本擴充 |
| MVP 只實作批次評估 | 每分鐘掃描一次，延遲最多 1 分鐘 | 後續版本可加即時評估（逐筆觸發） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-21 | 初始版本，最小驗證範圍 |
