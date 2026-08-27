<!--
UC 白名單 SSOT（Single Source of Truth）。
本檔為所有合法 UC 編號的權威來源，doc uc verify 依此驗證。
每個 UC 以 `## UC-XXX: 標題` 標記，含「### 主要成功場景」區塊。
詳細內容見對應的 docs/usecases/UC-XXX-*.md。
-->

# 應用程式用例總表（UC 白名單 SSOT）

本檔登錄所有合法 UC 編號。新增 UC 時須同步在此註冊，並確保與
`docs/usecases/UC-XXX-*.md` 一致。

產出來源：`saas-tech-selection` Stage 6。行為者統一為框架使用者（專案維護者）——
本 App 為單使用者本機工具，無組織角色分層。

本表使用的三個易混淆詞——**貫穿**（flow 經過某 domain）、**穿透**（兩視圖間
雙向導覽）、**破洞**（四類，見 `docs/events/diagnostics/EVT-DIAGNOSTICS-001-gaps-detected.md`）
——定義見 `docs/domain-map.md` §2.5。

---

## UC-01: 開啟專案並抵達可用狀態

**來源提案**：PROP-003
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-01-open-project-and-reach-usable-state.md`

### 主要成功場景

1. **選擇資料夾** — 自側欄浮層選定專案，系統確認其存在且可讀
2. **載入型別表** — 自該專案的 `.claude/` 讀取 `tracking_schema.json` 與 `VERSION`
3. **解析節點** — 掃描 `docs/` 下的圖譜節點檔並解析 frontmatter
4. **抵達 Domain 視圖** — 以矩陣模式呈現 domain × UC 交叉表

---

## UC-02: 依 domain 盤點變更影響面

**來源提案**：PROP-004
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-02-assess-change-impact-by-domain.md`

### 主要成功場景

1. **定位 domain** — 在矩陣中找到要變更的 domain 列
2. **讀取貫穿數** — 小計欄顯示被幾條 UC flow 直接貫穿
3. **切換至泳道** — 點交叉格，系統定位至該 domain 與該 UC
4. **檢視步驟** — 泳道呈現步驟序列，貫穿該 domain 的步驟高亮

---

## UC-03: 理解一條 flow 貫穿哪些 domain

**來源提案**：PROP-004
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-03-understand-domains-traversed-by-a-flow.md`

### 主要成功場景

1. **選定 UC** — 自 UC Flow 視圖選擇一條 UC
2. **檢視步驟序列** — 垂直步驟表，domain 與發送事件各自成欄
3. **跳轉節點** — 點選步驟開啟該節點詳情
4. **跳回 domain** — 點選 domain 欄切換至 Domain 視圖並定位

---

## UC-04: 追溯一項需求的實現鏈

**來源提案**：PROP-004
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-04-trace-a-requirement-implementation-chain.md`

### 主要成功場景

1. **選定提案** — 在追溯視圖選擇一個 PROP
2. **展開下游** — 樹狀呈現 PROP → SPEC → UC → Ticket
3. **檢視狀態** — 各層顯示 status，缺口層以虛線框標示
4. **跳轉細節** — 點選任一節點開啟詳情

---

## UC-05: 找出被阻擋的工作

**來源提案**：PROP-004
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-05-find-blocked-work.md`

### 主要成功場景

1. **進入 ticket 清單** — 首次進入顯示載入提示與預估耗時（依視圖惰性載入）
2. **觸發載入** — 確認後解析全部 ticket 並顯示進度
3. **切換至主題模式** — 依主題呈現各節與未歸屬節
4. **定位阻擋** — 展開主題，檢視各票的 status 與 `blockedBy`

---

## UC-06: 找出並修復文件破洞

**來源提案**：PROP-004
**對應規格**：SPEC-001
**詳細用例**：`docs/usecases/UC-06-find-and-fix-document-gaps.md`

### 主要成功場景

1. **進入破洞報告** — 系統開始掃描
2. **檢視分類** — 依 `EVT-DIAGNOSTICS-001` 定義的類別分節
3. **定位單項** — 點選任一項顯示檔案路徑與行號
4. **開啟原始檔** — 以外部編輯器開啟並定位至該行
