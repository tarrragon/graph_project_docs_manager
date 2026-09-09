---
id: SPEC-005
title: "Workspace driven port 回饋契約"
status: draft
source_proposal: null            # 來源非提案：由 0.1.0-W3-139 的 driven port 盤點裁定新建
created: "2026-09-09"
updated: "2026-09-09"
version: "1.1"
owner: star-anise-system-designer

domain: "workspace"
subdomain: driven-ports

related_usecases: [UC-01]
related_specs: [SPEC-003]
implements_requirements: []
depends_on_domains: []
---

# Workspace driven port 回饋契約

## 概述

本規格記載 workspace domain 往外呼叫的 driven port——資料夾選取、偏好設定持久化、
資料夾可用性探測——各自的回饋點由什麼承載、哪些時刻不適用、現況缺口在哪裡。

**與框架方法論的分工線**（依 `0.1.0-W3-139` 裁定）：三個回饋時刻的定義與判準問句、
不變式 `INV-PORT-OBSERVE-001`、回饋消費者投影表、不互相抵扣規則、測試義務表皆為跨專案
通則，全文在 `.claude/methodologies/clean-architecture-implementation-methodology.md`
的〈Port 回饋契約〉一節（含子節〈輸出端回饋層級與判準〉〈不變式：INV-PORT-OBSERVE-001〉
〈回饋消費者與投影關係〉〈時序約束〉〈測試義務〉）。本規格**不重述**上述內容，只寫本專案
事實：有哪些 port、各時刻由什麼承載、哪些不適用及原因、缺口與承接票。

**載體**（以下三條為契約，不是某次搬移的紀錄）：

1. **接縫的落點**：全部五個接縫與其呼叫端位於 `lib/workspace/workspace_repository.dart`
   ——三個 port 介面、其 private `_Default*` adapter、兩個 typedef 皆在該檔。
2. **value types 的落點**：`lib/workspace/workspace_types.dart` 承載九個 value type
   （`WorkspaceState` 與其三個 variant `WorkspaceUnset`／`WorkspaceReady`／
   `WorkspaceUnavailable`；`ChooseFolderResult` 與其四個 variant `ChooseFolderCancelled`／
   `ChooseFolderUnavailable`／`ChooseFolderSelected`／`ChooseFolderNotRemembered`）。
3. **不 re-export**：`workspace_repository.dart` 只 `import 'workspace_types.dart'`，
   **不 `export`** 它（`0.1.0-W3-147` 裁定：僅在檔案系統上分離而主檔仍輸出兩個責任的
   公開介面已被否決）。**對呼叫端的約束**：需要這九個 value type 的程式碼必須直接
   import `workspace_types.dart`，不得靠 import `workspace_repository.dart` 間接取得。

第 3 條是本規格的可否證條款——主檔一旦出現 `export 'workspace_types.dart'`，即為違反，
與檔案如何演進無關。本規格一律以符號名稱引用，不寫行號。

## 一、本專案的接縫清單與三種形態

本 domain 的接縫**不是單一形態，也不只兩種**。形態本身的約定（何時用哪一種）歸
`0.1.0-W3-146`（落點為 `docs/tech-decisions.md`），本規格只描述各形態下回饋點由誰承載。

| 接縫 | 形態 | 生產預設 | 預設實作的歸屬 |
|------|------|---------|--------------|
| `WorkspacePreferencesPort` | `abstract interface class` + private adapter | `_DefaultWorkspacePreferencesPort` | 本專案自撰 |
| `WorkspacePreferencesHandle` | `abstract interface class` + private adapter | `_DefaultWorkspacePreferencesHandle` | 本專案自撰 |
| `WorkspaceDirectoryProbePort` | `abstract interface class` + private adapter | `_DefaultWorkspaceDirectoryProbePort` | 本專案自撰 |
| `DirectoryPathPicker` | `typedef`，預設為第三方 API | `getDirectoryPath`（file_selector 套件函式） | 無自撰程式碼 |
| `WorkspaceLogSink` | `typedef`，預設為本專案自撰實作 | `_defaultLogSink`（private 頂層函式，轉呼 `developer.log`） | 本專案自撰 |

**上表的列與 `0.1.0-W3-146` 對照表的列不是同一種東西**：`docs/tech-decisions.md` 補記段
「2026-09-09：driven port 接縫形態約定（W3-133／W3-146）」的「四個接縫現況對照」表把
`WorkspacePreferencesPort` 與 `WorkspacePreferencesHandle` 放在同一列，上表則分列。兩邊
都不是待修正狀態，因為兩種列定義的是不同的單位：

| | 上表的列 | 146 對照表的列 |
|---|---|---|
| 列 = 什麼 | 回饋點承擔者的**歸屬單位** | 形態判準的**計算單位** |
| 為何如此切 | `Handle` 承擔結果時刻、`Port` 承擔受理時刻，兩者須分別記載（見 §2.2） | 判準一算的是「port 方法數 ＋ 其 handle 方法數」的操作總數，兩者的操作數必須合計才得出形態 |

**把 146 那一列拆成兩列會使判準給出相反結論**（本段的實質內容，不只是宣告兩者不同）：
併列時的計算是 `open` 1 個 ＋ `readString`／`writeString` 2 個 ＝ 總數 3，落在「總數 >= 2
→ `abstract interface class`」。拆開後 `WorkspacePreferencesPort` 單獨只有 `open` 一個
方法，總數 = 1，落進「typedef 函式型別」那一支——本專案最複雜的接縫會被判成函式型別。
拆列的動機通常是「對齊另一份文件、消除不一致」，看起來正當，實際是拆掉了計數的定義域。
**因此：不得依本規格的粒度去改 146 的分組，亦不得依 146 的分組去合併上表的列。**

同一份說明在 `docs/tech-decisions.md` 補記段「2026-09-09：上節與 SPEC-005 的軸別對照
（W3-157）」有對稱一份，供從該側進入的讀者取用；兩處任一被修改時另一處須同步。

`WorkspaceRepository` 本體只持有這五個接縫中的四個注入欄位（`_pickDirectoryPath` /
`_preferencesPort` / `_directoryProbe` / `_log`），**不直接觸碰任何外部 SDK**：
`SharedPreferences.getInstance()` 在 `_DefaultWorkspacePreferencesPort.open()` 內，
`Directory().exists()` 與 `Directory().list()` 在 `_DefaultWorkspaceDirectoryProbePort` 內。
下列各表的「呼叫端投影」欄因此指的是 repository 對 port 的呼叫，非對 SDK 的呼叫。

**兩種 typedef 不同類**：`DirectoryPathPicker` 的生產預設是第三方套件函式，本專案在該路徑上
沒有任何自撰程式碼可安置記錄；`WorkspaceLogSink` 的生產預設是自撰的 `_defaultLogSink`，
該函式本身即是一個可安置記錄的落點。這使兩者的承擔者結論不同，不可合併敘述。

**三形態的承擔者差異**：

| 形態 | 呼叫發出 | 受理 | 結果 |
|------|---------|------|------|
| `abstract interface class` + private adapter | 呼叫端 | adapter 實作（受理狀態的載體由介面簽章決定） | adapter 的回傳值或例外 |
| `typedef`，預設為第三方 API | 呼叫端 | 無承擔者可指派——三時刻全部回落至呼叫端 | 呼叫端對回傳值／例外的分類 |
| `typedef`，預設為本專案自撰實作 | 呼叫端或自撰預設實作皆可 | 自撰預設實作（若該接縫的外部系統有受理狀態） | 自撰預設實作的回傳值或例外 |

前兩列的差異來源是「有沒有可安置記錄的中間層」：typedef 且預設為第三方 API 時沒有，方法論
承擔者表中的「adapter 實作」在此形態回落為呼叫端自身。這不是違反方法論——`0.1.0-W3-133`
已裁定 adapter 是角色標籤而非組織結構指令，本段是同一判準在 typedef 形態的延伸。第三列的
自撰預設實作即扮演該角色標籤，儘管它不是一個類別。

### 1.1 `WorkspaceLogSink` 是否列為 driven port

**判定：不列入本規格的回饋點盤點對象，但列入上表的接縫清單。**

`WorkspaceLogSink` 符合方法論〈輸出端回饋層級與判準〉對 driven port 的字面定義——它往外
呼叫 `dart:developer`，是應用層對外部系統的出口。判定排除的理由有二，兩者獨立成立：

1. **判準遞迴**。本規格其餘四個接縫的日誌投影，全部經由 `WorkspaceLogSink` 產生。把它列為
   受盤點的 port，等於要求「記錄呼叫發出」這個動作本身也要有可觀測的呼叫發出事件；該事件
   同樣須經日誌投影產生，投影載體仍是 `WorkspaceLogSink`。`INV-PORT-OBSERVE-001` 在此形成
   無停止條件的自指，不變式因此不可判定，不是覆蓋與否的問題。
2. **它是投影載體而非被投影對象**。方法論〈回饋消費者與投影關係〉把日誌列為三個消費者投影
   之一；`WorkspaceLogSink` 是該投影在本專案的實體接縫。盤點對象是「呼叫被投影到哪裡」，
   投影管道自身不是同一層次的盤點對象——如同不會為「回傳值」這個機制盤點它的回傳值。

**本節的排除與 `0.1.0-W3-146` 的形態判定正交**（本段是邊界宣告，不新增結論，作用是阻斷
一個錯誤推論；刪除本段的代價寫在段末）：這裡排除的軸是**可觀測性義務**——把
`WorkspaceLogSink` 列為受盤點 port，會要求「記錄它自己的呼叫發出」，而該記錄的投影載體
仍是它自己，判準因此遞迴。146 的判準表所在的軸是**介面形態**：其機械輸入為操作總數，
`WorkspaceLogSink` 的操作總數為 1，正常落在第 3 列（`typedef` ＋ 自撰 private 頂層函式
`_defaultLogSink`），該計數不觸發任何遞迴。兩份文件的結論可並存：本規格排除它於回饋點
盤點之外，146 給它一個形態，兩者不是同一個問題的兩種答案。

**本段擋的推論**：讀者見本節排除 `WorkspaceLogSink`，推論 146 的「四個接縫現況對照」表
也該把它移除（或反向推論本節的排除有誤，因為 146 收了它）。該推論會刪掉 146 判準表唯一
的第 3 列實例，使「`typedef` ＋ 自撰 private 頂層函式」這個形態失去現況對照，下游三票
（`0.1.0-W1-068`／`0.1.0-W3-112`／`0.1.0-W1-014`）套用判準時無例可循。刪除本段前請先
確認該推論已由別處擋住。

**排除的代價與其承接**：排除意味著日誌管道自身故障（`developer.log` 拋例外、輸出被丟棄）
在本 domain 內無可觀測事件。此為已知取捨，其消費者是進程層的全域錯誤攔截（`0.1.0-W1-016`
定案的三層攔截，見 `docs/tech-decisions.md` 補記段「2026-08-27」），不由本規格承擔。

**測試上的處理**：`WorkspaceLogSink` 在測試中以 `_LogRecorder` 替換，其角色是**觀測手段**
（承載其餘四個接縫的日誌斷言），不是受測對象——與 §4 表中其餘記錄器的角色不同。

## 二、逐接縫的回饋點承擔者

本章的對象是 §1 五個接縫中受盤點的四個（`WorkspaceLogSink` 的排除理由見 §1.1）。

**圖例**：Y = 已承載、N = 缺口、N/A = 不適用（附原因）。
**監控追蹤欄**：依 `docs/tech-decisions.md` 補記段「2026-08-27：執行期 log 的裁決」，
structured log 於 0.1 **維持延後**，重評條件為「出現無法由破洞報告解釋的故障」；該條在
tripwire 總表有對應一列（「出現無法由破洞報告解釋的故障 → 重評 structured log 的延後
決定」，偵測者欄現為待指名）。此為已定策略、有觸發條件，**不是不適用**，故本規格不以 N/A
記載此欄；下列各表因此欄全 domain 同一結論而不逐列重複，僅列呼叫端與日誌兩個投影。

### 2.1 `DirectoryPathPicker`（typedef 且預設為第三方 API，file_selector 平台通道）

呼叫端：`WorkspaceRepository.chooseFolder()`。

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出 | 呼叫端 `chooseFolder()` | Y（呼叫 `_pickDirectoryPath()` 前已進入函式） | Y（`_log('開啟資料夾選取面板')`） |
| 受理 | 無 | N/A | N/A |
| 結果 | 呼叫端 `chooseFolder()` | Y（三分支各對應一個 `ChooseFolderResult` variant） | Y（例外／取消／已選取三分支各一筆） |

**受理不適用的原因**：系統選取面板為 fire-and-wait——面板開啟後直到使用者操作結束才回傳，
其間無 acknowledged 狀態、無 progress callback，`Future<String?>` 的簽章亦不承載中間狀態。
沒有可觀測的受理事件存在，不是有事件而未記錄。

### 2.2 `WorkspacePreferencesPort` 與 `WorkspacePreferencesHandle`（兩步 API）

呼叫端：`WorkspaceRepository._persistAndInspect()` 與 `WorkspaceRepository.restore()`。

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出 | 呼叫端 | Y（呼叫 `_preferencesPort.open()`） | Y（持久化路徑與還原路徑各一筆入口日誌） |
| 受理 | `WorkspacePreferencesPort.open()` 的回傳型別 | Y（取得 `WorkspacePreferencesHandle` 即代表管道已可用；`open()` 拋例外代表未受理） | Y（成功時「偏好設定儲存已就緒」；失敗時 level 900 一筆） |
| 結果 | `WorkspacePreferencesHandle.writeString` 的 `bool` 回傳與例外 | Y（成功／回報 false／拋例外三分支，對應 `ChooseFolderSelected`／`ChooseFolderNotRemembered`） | Y（三分支各一筆） |

**受理時刻的載體是介面切分本身**：把「取得儲存管道」與「寫入」拆成兩個型別（Port 與
Handle），使受理成為一個有回傳值、可被呼叫端與日誌分別消費的時刻。若合併為單一
`writeString(key, value)` 方法，受理與結果將塌縮成同一個事件，管道開不起來與寫入失敗
在呼叫端無從區分。此為方法論〈時序約束〉所述「簽章決定受理時刻能否被消費」的本專案實例。

**不互相抵扣在本專案的落地**：`restore()` 的 `open()` 失敗分支中，例外細節只進日誌，
`WorkspaceUnavailable.reason` 固定為文案常數 `_reasonPreferencesUnavailable`。兩個投影
載不同內容且各自完整——日誌承擔診斷，呼叫端承擔決策與使用者可見文字，任一方缺席不由
另一方補足。

### 2.3 `WorkspaceDirectoryProbePort`（單步 API，dart:io）

呼叫端：`WorkspaceRepository._inspect()`。

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出（`exists`） | 呼叫端 `_inspect()` | Y | Y（「探測資料夾是否存在」） |
| 呼叫發出（`readFirstEntry`） | 呼叫端 `_inspect()` | Y | Y（「讀取資料夾內容」） |
| 受理 | 無 | N/A | N/A |
| 結果（`exists` 回 false） | adapter 回傳值 | Y（`WorkspaceUnavailable` + `_reasonFolderMissing`） | **N**（見 §3 缺口 G-1） |
| 結果（`readFirstEntry` 拋 `FileSystemException`） | adapter 例外 | Y（`WorkspaceUnavailable` + `_reasonFolderUnreadable`） | Y（level 900，含原始例外） |
| 結果（`readFirstEntry` 拋 `StateError`） | adapter 例外 | Y（`WorkspaceReady`——空資料夾可讀） | N/A |

**受理不適用的原因**：`Directory.exists()` 與 `Directory.list().first` 為 fire-and-wait
的直接 I/O，無受理狀態可觀測，理由同 §2.1。

**`StateError` 分支的日誌不適用**：空資料夾不是失敗，其結果時刻已由呼叫端投影
（回傳 `WorkspaceReady`）完整承載，日誌無診斷對象。此為設計選擇，非缺口。

## 三、現況缺口

| 編號 | 缺口 | 據實描述 | 承接票 |
|------|------|---------|--------|
| G-1 | `_DefaultWorkspaceDirectoryProbePort` **全無日誌** | 該 adapter 的 `exists` 與 `readFirstEntry` 皆為單行直呼 `dart:io`，類別內無任何 `developer.log` 呼叫（實讀 `lib/workspace/workspace_repository.dart` 確認）。`0.1.0-W3-139` 記為「`exists()=false` 日誌缺失」，實際範圍比該描述更廣——缺的不只是呼叫端 `_inspect()` 中 false 分支那一筆，adapter 端本身零日誌。後果：日誌消費者無法區分「探測過但資料夾不存在」與「根本沒探測」 | `0.1.0-W3-135` |
| G-2 | 日誌投影集中於呼叫端 sink，adapter 端零日誌 | 全檔僅 `_defaultLogSink`（§1 第三形態的自撰預設實作）一處呼叫 `developer.log`；`_DefaultWorkspacePreferencesPort`、`_DefaultWorkspacePreferencesHandle`、`_DefaultWorkspaceDirectoryProbePort` 三個 adapter 內部皆無日誌。目前 Preferences 兩個接縫的日誌覆蓋完整，是因為呼叫端在 port 呼叫前後各記一筆；此覆蓋依附於呼叫端而非 adapter，替換 adapter 實作時日誌不隨之移動 | 未指派——形態層面的約定歸 `0.1.0-W3-146`，日誌位置的修補歸 `0.1.0-W3-135` |

缺口的修補不在本規格範圍；本規格的職責是使缺口有可否證的書面對象。

## 四、測試義務的本專案落地

方法論〈測試義務〉表（哪些時刻需要外部系統替身）不重述。本專案的替身紀律如下，
實作在 `test/unit/workspace/workspace_repository_test.dart`：

| 替身類別 | 角色 | 本專案實例 |
|---------|------|-----------|
| 記錄器（spy） | 只記錄「方法被呼叫了、參數是什麼」，不模擬行為；用於呼叫發出時刻 | `_PickerRecorder`、`_PreferencesRecorder`、`_HandleRecorder`、`_DirectoryProbeRecorder` |
| 觀測手段 | 承載其餘接縫的日誌斷言，本身不是受測對象（見 §1.1） | `_LogRecorder`（替換 `WorkspaceLogSink`） |
| 行為替身（fake） | 模擬外部系統的受理與結局；用於受理與結果時刻 | `_FakePicker`、`_FakePreferencesPort`、`_FakePreferencesHandle`、`_FakeDirectoryProbe` |

測試群組與時刻的對應：G1 對應呼叫發出（`INV-PORT-OBSERVE-001` 覆蓋）、G4 對應受理、
G2／G3／G6 對應各呼叫路徑的結局。不互相抵扣規則在測試層的落地形式為：同一分支的日誌
斷言與回傳值斷言分開撰寫，不以其中一項替代另一項。

## 五、變更理由邊界

本規格的唯一合法變更理由為**資料夾存取方式改變**（`docs/domain-map.md` §3 對 Workspace
bundle 的界定）。與 UI 互動方式改變而生的 port 契約（`ScanNotifier`、`ExternalOpener`）
不屬本規格，其落點為 SPEC-003 §2.2（承接票 `0.1.0-W3-149`）。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.1 | 2026-09-09 | 對齊 `0.1.0-W3-146`／`0.1.0-W3-147` 落地後的現況：載體段由遷移事件敘述改寫為三條契約（接縫落點／value types 落點／不 re-export 與呼叫端 import 約束），時態問題隨之消解；§1 補與 146 對照表的列定義差異（歸屬單位 vs 計算單位）並寫出拆列會使判準把 `WorkspacePreferencesPort` 判成 typedef 的失效機制；§1.1 補軸別釐清並寫明所擋的推論與刪除代價。`docs/tech-decisions.md` 補記段有對稱一份（`0.1.0-W3-157`） |
| 1.0 | 2026-09-09 | 初始版本：workspace 五個接縫與三種形態、受盤點的四個 port 的回饋點承擔者、`WorkspaceLogSink` 排除判定與理由（§1.1）、兩項現況缺口、測試替身紀律（`0.1.0-W3-148`） |
