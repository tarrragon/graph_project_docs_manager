# 本專案 WRAP 整合層

本目錄存放 WRAP 決策框架**在本專案的落地實作**。通用規則在 SKILL.md 與同層 `references/`，本目錄只放與本專案系統組件（YAML / Hook / CLI / pm-rules）耦合的部分。

> **本目錄的建立經過**：本專案原本沒有這一層。2026-09-03 隨框架 2.50.2 拉入的 `wrap-skill-yaml-consistency` guard 要求 `triggers-alignment.yaml` 存在，才自另一個 consumer 取得可適用的部分。該 consumer 的整合層另有五份檔案（案例集、簡化三問規格、個人化建議銜接、pm-rules 索引、觸發對應表），因內文密集引用該專案的 ticket 編號而未取——框架檔案引用專案層級識別符會在 sync 後變成死連結，見 `.claude/references/reference-stability-rules.md` 規則 8。下方「尚未建立」一節列出本專案還缺的部分。

---

## 依賴方向（關鍵架構）

```
通用 WRAP 規則                   本專案落地                     本專案系統組件
─────────────                    ─────────                      ──────────────
SKILL.md                    ←    本目錄                    ←    YAML / Hook
detailed-techniques.md                                           CLI / pm-rules
pm-checklist.md                                                  methodologies
tripwire-catalog.md                                              error-patterns
```

**規則**：

- 通用規則（SKILL 本體 + 同層 references）**不得引用本目錄或本專案任何組件**
- 本專案系統組件（YAML / Hook / CLI / pm-rules）引用本目錄，**不直接引用 SKILL**
- 本目錄可引用 SKILL 作為上游原理；可引用本專案系統組件作為下游落地

此方向允許 SKILL 跨專案複用：只需複製 SKILL.md + 同層 references，本專案特定內容（本目錄）留給各專案自行建立。

---

## 目錄清單

| 檔案 | 內容 |
|------|------|
| [triggers-alignment.yaml](./triggers-alignment.yaml) | `wrap-triggers.yaml` ↔ SKILL.md 的雙向映射表。消費者為 `hooks/wrap-skill-yaml-consistency-hook.py`，該 hook 用它驗證 YAML 的每個 signal 都對應到 SKILL 的觸發情境、每個 keyword 都歸屬得到 description 的 Triggers 類別 |
| [premortem-framework-constraints.md](./premortem-framework-constraints.md) | `references/premortem-workflow.md` 的通用流程在本框架的接線位置：派發約束（prompt 骨架、並行上限）與產出約束（格式、落檔位置、延後綁票） |

**在正規 references 層（不在本目錄，內容通用）**：

| 檔案 | 內容 |
|------|------|
| [../pseudo-widen-guard.md](../pseudo-widen-guard.md) | 偽擴增選項與真擴增選項的假設層級檢查規格：三層質疑步驟、警告信號、執行時機 |
| [../source-verification.md](../source-verification.md) | 來源核對：清單類答案的幻覺模式、逐項核對流程、反模式 |

---

## 尚未建立

以下是整合層應有但本專案還沒有的部分。需要時逐一建立，不從其他 consumer 整份複製——那些檔案的內文綁著該專案的編號與流程。

| 缺的部分 | 何時該建 | 建立方式 |
|---------|---------|---------|
| 觸發條件三層對應表 | 新增或修改 `wrap-triggers.yaml` 的 signal 時 | 記錄 YAML ↔ SKILL ↔ Hook 三層的對應與失敗判定，本專案的 signal 為準 |
| 簡化三問規格 | ticket claim 的三問輸出需要調整時 | 以本專案 ticket CLI 的實際輸出為 SSOT，記 W/A/P 範本與各 ticket 類型的差異 |
| 個人化建議銜接 | 本專案建立對應的 pm-rules 之後 | 銜接 SKILL 的 Step 0 與本專案規則 |
| pm-rules 索引 | 需要從 WRAP 導航到本專案 pm-rules 時 | 列本專案 `pm-rules/` 下與 WRAP 銜接的檔案 |
| 本專案案例集 | 本專案首次出現 WRAP 補強或缺口案例時 | 一案一節，指向本專案 `docs/work-logs/` 與 `.claude/error-patterns/` 的正式紀錄 |

---

## 新增內容時的維護原則

### 新增觸發訊號

1. 設計訊號（對應 SKILL 的抽象類別）
2. 更新 `.claude/config/wrap-triggers.yaml`
3. 更新 `triggers-alignment.yaml` 的兩張映射表，否則一致性 hook 會擋
4. 更新 Hook 實作（從 YAML 讀取）
5. 更新 SKILL description（如需新關鍵字）

### 新增本專案防護機制

1. 確認是否為本專案特定（若通用則放 SKILL）
2. 建立新檔於本目錄
3. 更新本檔的目錄清單

### 禁止操作

- **禁止修改 SKILL.md 引入本專案特定術語**（Ticket / Wave / CLAUDE.md / slash command 等）
- **禁止把本目錄內容往 SKILL 上搬**（即使看起來通用，先確認其他專案是否適用）
- **禁止在本目錄以外的框架檔案複述觸發條件或關鍵字清單**（指向 YAML 或 SKILL description）
- **禁止引用其他 consumer 的 ticket 編號**（規則 8；跨專案 sync 後成為死連結）

---

## 跨專案複用 checklist

若要在其他專案使用本 wrap-decision skill：

1. 複製 `.claude/skills/wrap-decision/SKILL.md`
2. 複製 `references/` 下的 `detailed-techniques.md`、`pm-checklist.md`、`tripwire-catalog.md`、`pseudo-widen-guard.md`、`source-verification.md`、`premortem-workflow.md`
3. **跳過** `references/project-integration/` 整個目錄
4. 新專案自行建立 `references/project-integration/`，對應該專案的任務管理系統（不必是 Ticket / Wave）、決策諮詢規則（不必是 pm-rules）、自動觸發機制（不必是 YAML / Hook）與案例集

---

**Last Updated**: 2026-09-03
**Version**: 2.0.0 — 本專案版本。目錄清單縮為實際存在的兩檔（`triggers-alignment.yaml`、`premortem-framework-constraints.md`），新增「尚未建立」一節列出還缺的五項與各自的建立時機；維護原則移除指向不存在檔案的步驟，禁止操作新增「禁止引用其他 consumer 的 ticket 編號」。上一版承襲自另一個 consumer，其目錄清單與六個讀取場景指向本專案沒有的檔案
