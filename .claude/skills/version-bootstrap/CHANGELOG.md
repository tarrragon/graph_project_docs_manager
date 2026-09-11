# version-bootstrap 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.6.0 — 依一輪低階 model 讀者探針（3 個實例，指令逐字相同）處置四項，並解消體量超標。**「全自動」一詞在同一份文件內兩義，改詞消解**：行 32 寫「不是全自動 pipeline」（指整條不會自己跑完），六行後 Step 1 標題寫「（全自動）」（指這一步不需人工填內容），三名探針中兩名主動提問這兩個標籤是什麼意思。各步標籤改為「無需人工填內容」／「需人工填內容」，與 pipeline 層的敘述字面不再共用同一個詞；〈使用方式〉補一段把兩件事分開講明，並寫死「沒有任何一步會自動進入下一步」。此處刻意不採「加一句註解說明兩者不同」——歧義出在詞的成分層，註解出在段落層，`DOC-GPD-009` 記的正是這種修法無效。**新增〈全程〉表**：九步一覽含產出與適用範圍，並明寫帶小數的編號是後來插入既有序列之間、不是選配。原文九步散在 200 餘行且無總覽，探針對「Step 4.5 含 3.5 元件契約」一份漏答。**移版硬耦合盤點 SOP 外移**至 `references/version-shift-sop.md`：該 SOP 觸發條件與六步 pipeline 完全不同（決定移版時才走），原本卻與〈反應式工作〉並列於 Step 6 之後，三名探針中兩名未察覺它存在、第三名明問何時該執行它。Step 1 的依賴檢查處補就地路由，並補一句「選移版時不得整包搬走」。**新增〈按需讀取〉與〈與相鄰資產的交界〉表**：探針 Q5 三份皆只列被本 skill 呼叫的工具（`doc`／`spec validate`／`tdd`／`ticket`），無一提及 `foundation-design`／`ux-design-evaluation`／`dart-style-guardian`／`version-sequencing`。交界表特別寫明 `foundation-design` 會把 DevOps 與可觀測性的盤點票交過來，而本 skill 的九步對這兩個維度沒有承接段落——收到這類票時不該以為它們會在某一步被吸收。**體量**：原 5132 tokens 超過 L2 的 5000 上限且零 references。處置**不是刪判斷條件**：Step 2／2.5／2.6／4.5 的 Why 與 Consequence 論證外移至新建 `references/step-rationale.md`（跳過該步的後果），各步保留時機句與全部操作內容；Step 2 的 UI 判別關鍵字（「畫面」「頁面」「元件」「介面」「UI」）屬判斷條件，原樣留在正文。〈與早期手動流程的對照〉為純歷史、無操作用途，移入本 CHANGELOG 摺疊區。結果 4651 tokens，references 由 0 增為 2。**description 改寫**：原文寫「6 步 pipeline」而實際為九步，改為列出各步名稱不寫死數量（規則 10 可變計數不實例化），並補 `Do NOT use for` 路由至 `version-sequencing` 與 `foundation-design`；`metadata` 補 `category`。**標題**「6 步流程」改「各步驟細節」，同因。

<details>
<summary>與早期手動流程的對照（本 skill 出現前的做法，1.6.0 由 SKILL.md 移入）</summary>

| 早期手動流程 | /version-bootstrap |
|----------------|-------------------|
| 手動 cp 模板建 spec | Step 2 `/doc batch-init` |
| 手動讀 blog 比對 | Step 3 `/spec validate --dim 4` |
| 手動 cp 模板建 UC | Step 2 `/doc batch-init`（同步建立） |
| 手動編輯 traceability | Step 2 自動佔位 + Step 4 填寫 |
| 逐一派 sage | Step 5 批量並行派發 |
| 手動建票 | Step 6 依產出匯總 |

</details>

**Version**: 1.5.1 — 兩處「十一欄位契約」改「元件契約欄位表」，跟隨方法論 1.14.0 欄位表計數去數字化（DOC-GPD-003）
**Version**: 1.5.0 — Step 2 的 L3 元件庫章節檢查項對齊方法論 1.9.0（明示本步驟得先只到清單，契約於地基波補齊，並指名 doc 範本）；Step 4.5 四塊表插入 3.5「元件契約」（程序見 `component-contract-design` skill，checkpoint 為契約齊全），PM 工作補元件契約 DOC 票與依賴。動因：多輪審查發現本 skill 對「第四塊之前的契約產出」無承接段落
**Version**: 1.4.0 — 新增 Step 2.6「資料契約產出」於 Step 2.5 與 Step 3 間：依兩旗標判準（引用 `data-layer-contract-methodology.md` 第 2 節，不複寫）決定是否 cp 模板產出資料契約文件；契約條目登錄 traceability 第三軸 `data_contract_tests` 供 Step 5 測試設計盤點缺口
**Version**: 1.3.0 — 新增 Step 2.5「Domain 規劃」於 Step 2 與 Step 3 間：spec FR 填完後、測試設計前產出/更新 domain map（doc domain-map-template），含 saas / standalone 調和語意（domain 規劃是所有規劃波通用步驟，非 saas 專屬）；Step 5 補「消費 domain map 逐 bundle 定測試層」、Step 6 建票來源補「domain map bundle 分層 → domain/data/presentation 切分」（落地 ANA domain 規劃整合結論）
**Version**: 1.2.0 — 新增 Step 4.5「地基波（僅含 UI 提案版本）」於 Step 4 與 Step 5 間：測試設計前依 component-library 方法論〈地基波 build 順序〉編排 i18n / design-system / UX 審查 / 元件庫四塊實作（Why：測試需驗 zh/en overflow 與元件反應，依賴 i18n/元件先存在；實證地基波經指正後手動插入）；Step 2 UI 前置檢查補「design-system spec（用 design-system-spec-template）」檢查項。非 UI 版本略過
**Version**: 1.1.0 — Step 2 新增「UI 類提案元件庫前置檢查」小節：判別提案是否涉及 UI/頁面/元件，涉及則須先確認 design token 層與 L3 元件庫章節存在（缺則先補齊），才可繼續 UI 實作票規劃，落地元件庫雙向約束方法論流程整合點 1
**Last Updated**: 2026-07-21
