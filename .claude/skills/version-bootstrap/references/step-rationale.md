# 各步驟為什麼存在

> **什麼時候讀本檔**：想跳過某一步、或要判斷某一步在本專案是否適用時。SKILL.md 的九步表給的是做什麼與時機，本檔給的是跳過的後果。
>
> 同目錄另有 `version-shift-sop.md`（提案移版時的契約殘留盤點）。

每一節的 Why 說明該步驟填補的是哪一種空隙，Consequence 是跳過它的實測後果——括號標「實證」者為已發生過的案例，非推想。

## Step 2.5：Domain 規劃

**Why**：spec 定義 FR（系統做什麼）、UC 定義使用者場景（誰怎麼用），兩者皆為垂直視角，不界定 domain 的水平聚合邊界——aggregate / kernel / read-model 分類、依賴方向、層測試策略。**Consequence**：跳過本步驟，domain 邊界會在實作階段臨場拍板（退化為「哪個檔案太大就拆」），依賴方向底線無文件可依，易出現 read-model 互相耦合、持久化細節混入 domain；測試設計（Step 5）也無 per-bundle 依據。需事後補 domain map（實證：某個移動應用實作案例中於實作前補建）。**Action**：spec FR 填完後、測試設計前，為每個 domain 產出或更新 domain map。

## Step 2.6：資料契約產出

**Why**：spec FR 定義欄位存在，不定義欄位的值域、狀態責任分層、不變式、交易邊界、錯誤語意與恢復模型；domain map §3 Bundle 界定表的 data/infrastructure 列只標「持久化細節屬 data 層」，未展開細節。**Consequence**：跳過本步驟，資料層設計意圖（為何選這個約束、哪些不變式由 DB 保證）無專屬載體，散落於 DDL 註解與 repository 程式碼各處；Step 5 測試設計對資料層契約條目無盤點依據，覆蓋缺口不可審計（見 `.claude/methodologies/data-layer-contract-methodology.md` 第 6 節）。**Action**：spec FR 與 domain map 完成後、紅燈測試設計前，依兩旗標判準決定是否產出資料契約文件。

## Step 4.5：地基波

**Why**：測試設計（Step 5）需驗 zh/en overflow 與元件互動反應，這些依賴 i18n 系統與元件實體先存在；若 Step 4 後直接進 Step 5，UI 版本會在 i18n / design-system / 元件庫尚未 build 時進測試設計，無可驗對象。**Consequence**：跳過本步驟，測試票會假設不存在的 i18n key 與元件，Phase 3b 才暴露缺地基，需回頭補甚至推翻測試設計（實證：地基波經指正後手動插入）。**Action**：對含 UI 提案的版本，於測試設計前編排地基波實作波。

## Step 2 的 UI 前置檢查

**UI 類提案元件庫前置檢查（強制，元件庫雙向約束方法論落地）**：Why——UI 類提案若跳過 design token 層與元件庫規劃直接進入實作，設計端與工程端會各自決定元件形狀，產生重複造輪與樣式漂移，已上線元件難以回溯套用 token 體系。Consequence——未在本步驟攔截，UI 實作票會在 Step 6 匯總建票時直接開出，等到 Phase 3b 實作階段才發現缺 token 層或元件庫章節，需回頭補規劃甚至推翻已完成的實作。Action——填寫 spec FR 時逐一判別提案是否涉及 UI/頁面/元件（FR 描述含「畫面」「頁面」「元件」「介面」「UI」等關鍵字），判為 UI 類提案者須先確認下列兩項存在，缺則先補齊才可繼續本提案的 UI 實作票規劃：

## Step 2 為什麼多一項 design-system spec

**Why 加 design-system spec 檢查**：doc skill 已提供 `design-system-spec-template`，但 `batch-init` 只產一般功能 spec，UI 版本易漏產 design system 專屬 spec。**Consequence**：漏產則 Step 4.5 地基波的 design-system 實作無契約可依（實證：PM 用 batch-init 產一般功能 spec 卻未產 design-system spec，經指正後才補）。**Action**：UI 版本填 spec 時一併用 design-system-spec-template 產出 design system spec，作為 Step 4.5 design-system 實作的契約。


