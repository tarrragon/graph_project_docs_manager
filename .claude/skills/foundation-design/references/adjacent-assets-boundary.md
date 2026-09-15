# 與相鄰資產的交界

> 何時讀：不確定某件事該由 `foundation-design` skill 還是相鄰資產處理時讀本檔。執行 `foundation-design` 入口檔 `SKILL.md` 的正文流程時不需要先讀本檔。
>
> 同目錄：維度與產物欄位填法的延伸細則見 `dimension-product-notes.md`；接手他人專案的盤點流程見 `handoff-mode.md`；判準的真實案例見 `examples.md`；流程層面的案例見 `examples-process.md`；症狀查表見 `troubleshooting.md`。
>
> 溯源：`foundation-design` SKILL.md 全檔量測超出 skill-design-guide 第 2 層 5000 tokens 門檻時外移（2026-09-15），原文為入口檔〈與相鄰資產的交界〉整節，內容逐字未改。

本表只列**交界本身需要判斷**的資產。維度表已逐列指名的權威（`tdd`、`saas-tech-selection`、事件流仲裁方法論）與開頭已給判別句的 `project-init` 不重列——交界說明若只是重述維度表，讀者會多讀一次而不多知道一件事。

| 相鄰資產 | 它管什麼 | 交界落在哪 |
|---------|---------|-----------|
| `version-bootstrap` skill | 規劃波 pipeline 的編排 | 情境判定命中「規劃波進行中」時交回它，**但它的全文對 DevOps 與可觀測性 0 命中**——交回前先為這兩個維度各建盤點票。規劃波之後仍由本 skill 驅動，不是收手 |
| `version-sequencing` skill | 版本序列與首版開票 | 本 skill 產出票的**內容**（哪幾張、依賴），它決定票**屬於哪一版**。同一批票不是兩批 |
| `ux-design-evaluation` skill | UI 維度第 3 塊（UX 審查）的執行方法 | 本 skill 只界定「UX 審查是地基的一塊」，畫面級狀態矩陣、gate、回饋門檻全在該處 |
| `component-contract-design` skill | UI 維度第 4 塊（元件庫）實作前的契約程序 | 本 skill 只界定「元件庫是地基的一塊」，元件契約欄位表與容器排列不變式在該處。它的〈契約齊全的定義〉是元件庫實作票的前置 checkpoint |
| `dart-style-guardian` skill（Dart／Flutter 專案的執法工具實例） | 掃裸色碼、裸間距、裸字級、寫死文字 | 本 skill 工作流步驟 5 說的「機械檢查接入執法載體」，在 Dart 專案就是接它。**其他語言的專案沒有現成實例，需自行設計**——這是步驟 5 已知的不完整處 |
