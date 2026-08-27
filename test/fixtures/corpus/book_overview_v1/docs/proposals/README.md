# 提案（Proposals）

需求統一入口。無論需求來自原始規劃、開發中發現、bug 衍生或用戶回饋，都先建立提案。

## 使用方式

建立新提案時，從 Skill 模板複製：

```bash
cp .claude/skills/doc/templates/proposal-template.md docs/proposals/PROP-{NNN}-{簡短描述}.md
```

> 模板規範和欄位說明見 `.claude/skills/doc/references/proposals.md`

### 模板欄位說明

| frontmatter 欄位 | 用途 |
|-----------------|------|
| `id` | 提案 ID（PROP-NNN） |
| `title` | 提案標題 |
| `status` | draft / discussing / confirmed / implemented / withdrawn |
| `source` | 需求來源類型 |
| `target_version` | 目標版本 |
| `outputs.spec_refs` | 轉化的規格文件 |
| `outputs.usecase_refs` | 轉化的用例文件 |
| `outputs.ticket_refs` | 開立的 ticket |

### 正文結構

| 章節 | 必填 | 說明 |
|------|------|------|
| 需求來源 | 是 | 需求的來源和背景 |
| 問題描述 | 是 | 要解決的核心問題 |
| 範圍界定 | 是 | **要做**和**不做**的明確清單（核心欄位） |
| 影響範圍 | 是 | 受影響的模組和檔案 |
| 提案方案 | 是 | 解決方案（含方案比較） |
| 驗收條件 | 是 | 具體可驗證的條件（對應「要做」清單） |
| 風險與權衡 | 否 | 已知的風險和緩解措施 |
| 討論記錄 | 否 | 討論過程中的決策記錄 |
| 轉化記錄 | 否 | 確認後的 spec/usecase/ticket 轉化追蹤 |

### 範圍界定原則

> **一個提案 = 一個版本的明確功能範圍**

- 提案必須綁定具體版本（`target_version`），禁止跨大版本設計
- 必須列出「要做」（In Scope）和「不做」（Out of Scope）
- 「不做」項目如果未來需要 → 建立獨立提案，綁定到未來版本
- 驗收條件必須與「要做」項目一一對應

### 狀態流轉

```
draft → discussing → confirmed → implemented
                  ↘ withdrawn
```

### 與 ticket 的關係

提案是 ticket 的上游。提案確認後才開立 ticket：

1. 提案 confirmed → 開立 ticket，ticket.why 引用 PROP-NNN
2. ticket 完成 → 更新 `proposals-tracking.yaml` checklist
3. 所有 checklist 完成 → 提案 status 改為 implemented

## 提案索引

| 提案 ID | 標題 | 狀態 | 目標版本 |
|---------|------|------|---------|
| PROP-000 | 提案驅動需求追蹤機制設計 | discussing | v0.16.2 |
| PROP-001 | 多平台隔離與跨平台路由 | draft | v2.0+ |
| PROP-002 | 跨設備同步機制完善 | discussing | v0.16.2 |
| PROP-003 | 資料備份與恢復機制 | draft | v0.16.3 |
| PROP-004 | UseCase 與測試覆蓋率差距分析 | discussing | v0.16.2 |
| PROP-005 | 外部依賴邊界防護驗證 | discussing | v0.16.2 |

## 追蹤

全局追蹤索引見 `../proposals-tracking.yaml`
