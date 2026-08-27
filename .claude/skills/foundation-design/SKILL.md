---
name: foundation-design
description: "地基工作的單一入口與路由層——把散在方法論、orchestration skill、執法工具中的地基判準串成一條可走的流程，不重新定義判準。維度含 UI／測試／資料庫／DevOps／可觀測性，各指名既有權威並標明權威缺席時的處置。新舊專案一體適用：老專案先盤點萃取再命名固化。觸發詞：地基、地基波、元件庫、design token、fixture、seed、migration、scaffold、腳手架、接手老專案。Do NOT use for 環境安裝（用 project-init）。"
license: MIT
metadata:
  portable: true
  version: 3.0.0
  category: engineering-workflow
---

# Foundation Design

規格說系統**做什麼**；地基工作決定實作用什麼**具名材料**來蓋。本 skill 是那些工作的**單一入口與路由層**。

**具名材料**指「值有單一定義位置、程式碼只引用名字」的那些東西：色票、間距、字級、文案 key、fixture、migration、CI gate 門檻。判別問「這個值改掉時，要改幾個地方」——超過一個就還不是具名材料。

## 本 skill 不做什麼

**不重新定義任何維度的判準。** 五個維度全部已有既有權威——本 skill 的職責是指名它們、定義何時進入、標明權威缺席時的處置、以及交接契約。

會需要這個入口，是因為那些權威**散在四類載體**：

| 載體 | 本框架的實例 | 它承擔什麼 |
|------|------------|-----------|
| 方法論 | `.claude/methodologies/component-library-bidirectional-constraint-methodology.md` | 定判準 |
| orchestration skill | `.claude/skills/version-bootstrap/SKILL.md`（Step 2 / Step 4.5） | 在規劃流程的某一步編排 |
| 執法工具 | CI 的裸值檢查、`.claude/hooks/` 的 PreToolUse guard | 掃描既成違規 |
| 模板 skill | `.claude/skills/doc/` 的 `design-system-spec-template` | 出產出物契約 |

各自完整，但沒有任何一處回答「地基這件事整體從哪開始」。

**症狀可觀測**：主動查重的人（讀過 orchestration skill 的章節標題、確認「不重疊」）仍會判定地基無人承接而重造一份。缺口在可發現性，不在能力。

## 維度路由表

引用一律為自 `.claude/` 起算的完整路徑（依 `.claude/rules/core/document-format-rules.md` 規則 6）。

| 維度 | 何時 N/A | 權威來源（判準在此，本 skill 不複述） | 產物 |
|------|---------|--------------------------------|------|
| **UI** | 產品無任何人眼可見輸出（純 library／純 daemon） | `.claude/methodologies/component-library-bidirectional-constraint-methodology.md`〈地基波 build 順序〉——**四塊依序**：i18n → design-system → UX 審查 → 元件庫。UX 審查那塊的執行方法見 `.claude/skills/ux-design-evaluation/SKILL.md` | 四塊各自的實作票；元件庫 `blockedBy` 前三塊 |
| **測試** | 從不 N/A | `.claude/skills/tdd/references/layered-test-strategy.md`（測試分層）、`.claude/skills/tdd/references/phase2/rules.md` 的 Q9–Q14（六道測試設計檢驗：資料是否碰巧通過、error path 覆蓋、資料工廠版本、防哪種改壞、斷言是否 flaky、資料代表性） | fixture 策略、分層地基 |
| **資料庫** | 無跨執行期存活的結構化狀態 | `.claude/skills/saas-tech-selection/references/dimensions/state-storage.md`（migration 版本化紀律、多租戶資料模型） | migration baseline。**seed 無權威**——見〈權威缺席時〉 |
| **DevOps** | 產物不需建置也不需分發 | `.claude/skills/saas-tech-selection/references/dimensions/reliability.md`（CI gate 構成與起始門檻） | CI gate、部署與還原配方 |
| **可觀測性** | 從不 N/A | `.claude/rules/core/observability-rules.md`（統一 log 入口、catch 區塊要求；屬自動載入層，多半已在 context 中，不需另讀）、`.claude/skills/saas-tech-selection/references/dimensions/observability.md`（錯誤分類） | log 接線點、錯誤分類骨架 |

**本欄是 N/A 條件，不是進入條件。** 前一版寫「進入條件」而兩列填「一律進入」——那兩格不篩任何東西，欄位在該處無作用。改寫為「何時 N/A」後每一格都有內容：兩個「從不 N/A」是誠實的宣告（這兩維度無條件進入），其餘三列給出可判定的排除條件。**判不出來時預設進入**，並在產物記下「因歧義而進入」——多做一次盤點的成本，低於漏掉一個維度後在實作中發現的成本。

### 權威缺席時

路由層的 substance 全在別處，因此「別處不存在」是本 skill 的主要失效模式，必須有處置。三種形態：

| 形態 | 處置 |
|------|------|
| **權威是框架資產但本專案未安裝**（如無 `tdd` skill） | 該維度標記「**無權威**」，**不得宣告 N/A**——「沒有判準」與「不適用」是兩件事。建票補該 skill，或在專案內指定替代權威並記錄 |
| **權威存在但形態不符**（非 SaaS 專案讀 `saas-tech-selection`） | 只取其中與形態無關的部分（如 migration 版本化紀律、錯誤分類），記錄不適用的範圍。**不要因為來源是 SaaS skill 就整條跳過** |
| **框架內確實無承接者** | 記為**缺口**，不假裝已判定。現已知的缺口：**資料庫 seed**（全框架無「種子資料／seed data／seeding」承接者，實測 0 命中） |

**為什麼不允許以 N/A 吸收**：N/A 的語意是「確認後不適用」，記下就結案；「無權威」的語意是「該做但沒有依據」，必須留下未結的痕跡。兩者混用會讓缺口在盤點表上長得跟已完成一樣。

## 與 orchestration 的協作

| 情境 | 誰驅動 | 本 skill 的角色 |
|------|-------|---------------|
| 新專案、已進版本規劃波 | `version-bootstrap`（Step 2 UI 前置檢查、Step 4.5 地基波編排） | **交回，不重跑盤點**。使用者常因說出「地基波」三字被導來此處，本列的作用是把他導回去 |
| 新專案、規劃波之前 | 本 skill | 依路由表逐維度盤點，產物交給 `version-sequencing` 排進首版 |
| **老專案接手** | 本 skill | **既有 orchestration 皆不適用**——它們假設已有規格或已在規劃波中 |
| **以上皆非**（無 `version-bootstrap`／已有規格的老專案／接手他人未完成的規劃波） | 本 skill | 走「規劃波之前」那一列。判不出情境時的預設出口 |

**「規劃波」的定義**：`version-bootstrap` 已對某個版本啟動、其 Step 1 的提案清單已確認。沒有該 skill 的專案不存在此狀態，直接走第二列。

**第一列的邊界**：交回下游不等於下游覆蓋全部五個維度。實查 `version-bootstrap` 的步驟，**DevOps 與可觀測性兩維度無對應步驟**——這兩維度在規劃波情境下仍無人盤點。交回時應明示這兩項未被下游承接。

第三列是本 skill 真正無可替代的部分。

## 老專案模式

老專案常缺文件。**先做地基、後補文件**：

```
1 盤點   grep 既有裸值、既有測試、既有 schema——它們是可觀測的事實
2 命名   逐一給名字，值不變
3 固化   建立單一定義位置 + 機械檢查
4 補文件 此時文件是萃取結果的記錄，不是猜測
```

**為什麼這個順序比直接補文件更可靠**：憑印象寫的文件會與程式碼漂移且無機制發現；萃取自程式碼的值每一步可 grep 驗證。

**萃取的前提**：既有 artifact 可信。三種情形下不成立——量測腳本本身有缺陷（產出的「既有形態」是工具產物而非事實）、artifact 由產生器輸出（其中的數值是產生器的預設而非設計決策，照抄會把雜訊固化成規格）：這兩種**須先驗證來源**。第三種是 artifact 已知過期——此時不必再驗證，**直接排除該 artifact**，改以程式碼現況為盤點對象。

**命名的行為中立性也有前提**：安全性論證掛在「既有測試全程保護」，而老專案缺文件常伴隨缺測試覆蓋。覆蓋不足時先補**特徵測試**（characterization test：不驗「應該是什麼」而是把現況行為原樣鎖住的測試，用途是讓後續改動一旦改變行為就紅燈；寫法見 `.claude/skills/tdd/references/layered-test-strategy.md`）再命名。另有三種情形抽取不是純命名：抽取後共用同一物件實例而下游會 mutate；值位在要求編譯期常數的位置；值位在平台設定檔或內聯樣式，抽取需改機制。

## 工作流

```
1 判定情境（規劃波中 / 規劃波前 / 老專案接手 / 以上皆非）
   → 規劃波中：交回 version-bootstrap（明示 DevOps 與可觀測性未被其承接），本流程結束
   → 以上皆非：走「規劃波前」
2 五個維度逐一判：進入 / N/A（標理由與重評條件）/ 無權威（標缺口，不得記為 N/A）
3 進入的維度：讀其權威來源，依該處判準執行
   老專案先跑「盤點→命名→固化」三步
   多方案取捨（3 個以上候選）委派 .claude/skills/design-decision-framework/SKILL.md
4 產物落為地基票，功能票 blockedBy 它們
5 機械檢查接入 CI
```

**步驟 4 與 `version-sequencing` 的分界**：本 skill 產出的是**票的內容**（哪幾張、各自的依賴），`version-sequencing` 步驟 5 決定它們**排進哪一版**。同一批票，不是兩批——兩邊都建會建出兩套地基票。規劃波前先跑本 skill 時，票可以先建、待版本序列定案後再掛版本。

**步驟 5 的機械檢查目前只有 UI 維度有現成形態**（裸值 grep）。其餘四維度的檢查需自行設計，這是本 skill 已知的不完整處，非讀者漏讀。

**步驟 5 的老專案首次接入必然大量失敗**：設 baseline 凍結既有違規、只擋新增，再逐批收斂。一次要求全綠會導致檢查被停用。

**驗收訊息須指名判準所在的層**。「grep 不到裸色碼」讀的是原始碼層；若排除清單或 gitignore 使某些檔案不在掃描範圍，訊息應寫「掃描範圍內未命中」而非「專案中不存在」。**層次錯置的訊息會把讀者的正確觀察推翻**——讀者在檔案系統看到那個值，訊息說不存在，最自然的推論是自己看錯了。

## 移植前置條件

本 skill 標記 `portable: true`，但它路由到的權威不隨它一起移動。搬進新專案前先確認：

- [ ] 五個權威來源各自存在？不存在的走〈權威缺席時〉，**不要靜默略過**
- [ ] 專案有具 `blockedBy` 語意的 ticket 系統？步驟 4 的產物形態依賴它
- [ ] 專案有 CI？步驟 5 依賴它

三項皆缺時本 skill 仍可用於「盤點與命名」（老專案模式的前三步），但步驟 4、5 無載體。

## Examples

**重造已存在的地基（本 skill v1.0 自身的失效）**：一份 skill 宣稱「UI 的 token 與元件庫沒有承接者」而重新設計了一套，實際上該對象已有四層鏈路（見上表四類載體）。實測 v1.0 原文：`i18n` 0 次、`UX 審查` 0 次——四塊中只涵蓋兩塊。錯誤的缺口宣告比漏報更貴：它誘發重複建置，而重複的那份還不完整。**查重須讀 orchestration skill 的內文而非章節標題，並搜尋 `.claude/methodologies/`。**

**路由表本身也會漏**（v2.0 的失效）：改為路由層後，UI 列指了方法論卻漏掉 `ux-design-evaluation` skill，資料庫列則反向出錯——宣稱 seed 由 `state-storage.md` 承接，實測該檔 seed 出現 0 次。**兩次都是查重粒度不足**：v1.0 讀章節標題就下結論，v2.0 讀檔名就下結論。路由表的格子比散文整齊，因此更容易讓人不再懷疑內容。

**萃取揭露規格漂移**：規格散文記「圓角 10/12、字級 12–22」，量測設計畫布實得圓角 5/7/8、字級 10–19——兩邊各寫各的、無機制發現。處置：以畫布實測值建 token、規格改為指向 token 不再複述數值。

**萃取不等於照抄**：同一份畫布的間距實測出七種值，那是產生器輸出而非設計過的尺度。token 化時歸納為離散具名階並記錄映射；照抄會把雜訊固化成規格。

## Common Issues

症狀欄寫的是**症狀承受者當下看得到的東西**，不是旁觀者的判斷。

| 症狀 | 原因 | 處置 |
|------|------|------|
| 你正要開始設計一套 token／元件庫／fixture 規範，而尚未搜過 `.claude/methodologies/` | 查重只讀了 orchestration skill 的章節標題 | 先搜方法論目錄；本 skill 的路由表即為查重結果 |
| 路由表某列的權威檔案打不開 | 該權威未安裝，或形態不符本專案 | 走〈權威缺席時〉三形態；**不得逕記 N/A** |
| token 表建了，功能票還是各寫各的值 | 地基票與功能票無 blockedBy 依賴 | 功能票一律 blockedBy 地基票；CI 加裸值檢查 |
| 出現次數最多的顏色被命名為「主色」 | 出現次數是觀察不是語意 | 逐色確認實際承擔的角色；次數只是線索 |
| 老專案命名後測試全綠，但畫面某處顏色變了 | 命名時順手統一了值，混入行為變更；缺覆蓋使紅燈不會出現 | 嚴格分兩步：先命名（值不變），統一值另開票。覆蓋不足時先補特徵測試 |
| CI 首次接入滿江紅而被停用 | 要求既有程式碼一次全綠 | 設 baseline 凍結既有違規、只擋新增 |
| 盤點表五個維度都填了，但實作中仍撞到沒人想過的地基問題 | 某維度被記為 N/A，實際是「無權威」 | 逐項回查 N/A 的理由是「確認不適用」還是「找不到依據」 |
