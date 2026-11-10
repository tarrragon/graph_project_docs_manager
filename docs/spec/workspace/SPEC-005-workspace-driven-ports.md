---
id: SPEC-005
title: "Workspace driven port 回饋契約"
status: draft
source_proposal: null            # 來源非提案：由 0.1.0-W3-139 的 driven port 盤點裁定新建
created: "2026-09-09"
updated: "2026-11-10"
version: "1.11"
owner: star-anise-system-designer
has_functional_requirements: false   # 本規格只記 workspace driven port 的專案事實，不含 FR（0.5.0-W1-159 判定）

domain: "workspace"
subdomain: driven-ports

related_usecases: [UC-01]
related_specs: [SPEC-003, SPEC-010]
implements_requirements: []
depends_on_domains: []
---

# Workspace driven port 回饋契約

## 概述

> **日誌**：本規格各 port 的日誌事件（`WorkspaceLogEvent`）只定義事件碼與負載鍵；記錄信封、錯誤來源分類、欄位值白名單與落地位置依 SPEC-010。負載中的 path 依 SPEC-010 FR-03 記工作區相對路徑，工作區外位置只記位置類別。

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
`docs/tech-decisions.md` 補記段「2026-09-09：driven port 接縫形態約定（W3-133／W3-146）」（下稱「形態約定補記段」），本規格只描述各形態下回饋點由誰承載。

| 接縫 | 形態 | 生產預設 | 預設實作的歸屬 |
|------|------|---------|--------------|
| `WorkspacePreferencesPort` | `abstract interface class` + private adapter | `_DefaultWorkspacePreferencesPort` | 本專案自撰 |
| `WorkspacePreferencesHandle` | `abstract interface class` + private adapter | `_DefaultWorkspacePreferencesHandle` | 本專案自撰 |
| `WorkspaceDirectoryProbePort` | `abstract interface class` + private adapter | `_DefaultWorkspaceDirectoryProbePort` | 本專案自撰 |
| `DirectoryPathPicker` | `typedef`，預設為第三方 API | `getDirectoryPath`（file_selector 套件函式） | 無自撰程式碼 |
| `WorkspaceLogSink` | `typedef`，預設為本專案自撰實作 | `_defaultLogSink`（private 頂層函式，轉呼 `developer.log`） | 本專案自撰 |

**上表的列與形態約定補記段對照表的列不是同一種東西**：該補記段的「四個接縫現況對照」表把
`WorkspacePreferencesPort` 與 `WorkspacePreferencesHandle` 放在同一列，上表則分列。兩邊
都不是待修正狀態，因為兩種列定義的是不同的單位：

| | 上表的列 | 形態約定補記段對照表的列 |
|---|---|---|
| 列 = 什麼 | 回饋點承擔者的**歸屬單位** | 形態判準的**計算單位** |
| 為何如此切 | `Handle` 承擔結果時刻、`Port` 承擔受理時刻，兩者須分別記載（見 §2.2） | 判準一算的是「port 方法數 ＋ 其 handle 方法數」的操作總數，兩者的操作數必須合計才得出形態 |

**把形態約定補記段對照表的那一列拆成兩列會使判準給出相反結論**（本段的實質內容，不只是宣告兩者不同）：
併列時的計算是 `open` 1 個 ＋ `readString`／`writeString` 2 個 ＝ 總數 3，落在「總數 >= 2
→ `abstract interface class`」。拆開後 `WorkspacePreferencesPort` 單獨只有 `open` 一個
方法，總數 = 1，落進「typedef 函式型別」那一支——本專案最複雜的接縫會被判成函式型別。
拆列的動機通常是「對齊另一份文件、消除不一致」，看起來正當，實際是拆掉了計數的定義域。
**因此：不得依本規格的粒度去改形態約定補記段的分組，亦不得依該補記段的分組去合併上表的列。**

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

**本節的排除與形態約定補記段的形態判定正交**（本段是邊界宣告，不新增結論，作用是阻斷
一個錯誤推論；刪除本段的代價寫在段末）：這裡排除的軸是**可觀測性義務**——把
`WorkspaceLogSink` 列為受盤點 port，會要求「記錄它自己的呼叫發出」，而該記錄的投影載體
仍是它自己，判準因此遞迴。形態約定補記段的判準表所在的軸是**介面形態**：其機械輸入為操作總數，
`WorkspaceLogSink` 的操作總數為 1，正常落在第 3 列（`typedef` ＋ 自撰 private 頂層函式
`_defaultLogSink`），該計數不觸發任何遞迴。兩份文件的結論可並存：本規格排除它於回饋點
盤點之外，形態約定補記段給它一個形態，兩者不是同一個問題的兩種答案。

**本段擋的推論**：讀者見本節排除 `WorkspaceLogSink`，推論形態約定補記段的「四個接縫現況對照」表
也該把它移除（或反向推論本節的排除有誤，因為該補記段收了它）。該推論會刪掉該補記段判準表唯一
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
| 結果（`remove`，清除已存路徑） | `WorkspacePreferencesHandle.remove(String key)` 的 `bool` 回傳與例外 | 契約（`clearStoredPath()` 依序移除 `_schemaVersionKey` 再移除 `_pathKey`；兩者皆回 true 為成功，任一回 false 或拋例外為失敗，失敗時不中止後續移除、以單一失敗結果回報呼叫端） | 契約（成功一筆；回 false 與拋例外各一筆 level 900，含 key 名與原始例外） |

**`remove` 列的來源與現況**：依 `0.2.0-W1-023` S-21 定案方案 A（Handle 新增 `Future<bool> remove(String key)`，與 `writeString` 對稱，不以寫空字串代替）。表中「契約」表示規格已定、實作尚未存在，非 Y／N 判定；實作落地後改記 Y 或 N。觸發來源為 SPEC-003 §3.1「取消載入」（已存路徑清除、最近專案清單不變）——`clearStoredPath()` 不得觸碰 §2.4 的 `workspace.recentProjects`。

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
| 結果（`exists` 回 false） | adapter 回傳值 | Y（`WorkspaceUnavailable` + `_reasonFolderMissing`） | Y（adapter 記 `adapterProbeExistsResult`，G-1 已修） |
| 結果（`readFirstEntry` 拋 `FileSystemException`） | adapter 例外 | Y（`WorkspaceUnavailable` + `_reasonFolderUnreadable`） | Y（level 900，含原始例外） |
| 結果（`readFirstEntry` 拋 `StateError`） | adapter 例外 | Y（`WorkspaceReady`——空資料夾可讀） | N/A |

**受理不適用的原因**：`Directory.exists()` 與 `Directory.list().first` 為 fire-and-wait
的直接 I/O，無受理狀態可觀測，理由同 §2.1。

**`StateError` 分支的日誌不適用**：空資料夾不是失敗，其結果時刻已由呼叫端投影
（回傳 `WorkspaceReady`）完整承載，日誌無診斷對象。此為設計選擇，非缺口。

### 2.4 最近專案清單持久化（`workspace.recentProjects`）

來源：`0.2.0-W1-023` S-36 定案方案 A。本節的接縫已實作（`WorkspaceRepository` 的 `loadRecentProjects`／`addRecentProject`／
`saveRecentProjectCounts`），下列表格的 Y／N 依實作判定（2026-11-05 讀碼）。消費方為切換器（SPEC-003 §3.7，承接票 `0.2.1-W1-003`）。

**載體**：沿用 §2.2 的 `WorkspacePreferencesPort`／`WorkspacePreferencesHandle`，不新增 port。
清單持久化只是同一個偏好設定儲存上的另一個 key，受理時刻因此與 §2.2 相同，不重複定義。

**key 與 value 結構**：

| 項目 | 定義 |
|------|------|
| key | `workspace.recentProjects` |
| value | 以 `writeString` 寫入的 JSON 字串；頂層為陣列 |
| 陣列元素 | 物件，兩欄皆必存在：`path`（string，資料夾絕對路徑）、`lastOpenedAt`（string，ISO 8601 UTC，例 `2026-09-24T01:25:50.000Z`）；另有選填欄 `counts`（見〈計數快照〉） |
| 唯一性 | 以 `path` 字串完全相等判定；同一 `path` 至多一項 |
| 排序 | 依 `lastOpenedAt` 降冪；讀取端不信任儲存順序，載入後自行排序 |
| 上限 | 本版不截斷 |

```json
[
  {"path": "/Users/example/project-a", "lastOpenedAt": "2026-09-24T01:25:50.000Z",
   "counts": {"nodeCount": 237, "ticketCount": 2419, "issueCount": 3}},
  {"path": "/Users/example/project-b", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}
]
```

**型別與方法**（落點依〈載體〉三條契約）：

| 符號 | 落點 | 定義 |
|------|------|------|
| `RecentProject` | `lib/workspace/workspace_types.dart` | value type，欄位 `path`（`String`）、`lastOpenedAt`（`DateTime`，UTC）、`counts`（`RecentProjectCounts?`，無快照為 `null`） |
| `RecentProjectCounts` | 同上 | value type，三欄 `nodeCount`、`ticketCount`、`issueCount`（皆 `int`，≥ 0） |
| `loadRecentProjects()` | `WorkspaceRepository` | 回傳 `Future<List<RecentProject>>`，已依 `lastOpenedAt` 降冪；不拋例外，失敗一律回空清單（分支見下表） |
| `addRecentProject(String path)` | `WorkspaceRepository` | 讀出現有清單，移除同 `path` 項，以當下時刻為 `lastOpenedAt` 插入頂端後整份寫回；同 `path` 舊項的 `counts` 原樣帶入新項（不因重新開啟而清除快照）；回傳 `Future<bool>`（寫入成功與否） |
| `saveRecentProjectCounts(String path, RecentProjectCounts counts)` | `WorkspaceRepository` | 讀出現有清單，以 `counts` 取代同 `path` 項的 `counts` 後整份寫回，不改 `lastOpenedAt` 與排序；清單內無同 `path` 項時不插入、不寫入，回 `false`；回傳 `Future<bool>` |

**寫入時機**：專案**成功載入**後呼叫 `addRecentProject`（SPEC-003 §3.7：成功載入後該項移至頂端）。
選取後載入失敗、取消載入、`clearStoredPath()` 皆不寫入、不刪除清單項。清單項的資料夾
不可用時不從清單移除——可用性由切換器展開時逐項探測（SPEC-003 §3.7〈生命週期〉），
探測的契約見 §2.5，不屬本節。

**回饋點承擔者**：

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出（讀／寫） | 呼叫端 `loadRecentProjects()`／`addRecentProject()` | Y | Y（各一筆入口日誌） |
| 受理 | `WorkspacePreferencesPort.open()` 的回傳型別（同 §2.2） | Y（`open()` 拋例外 → 讀回空清單、寫回 false） | Y（level 900 一筆） |
| 結果（讀，key 不存在） | `readString` 回 null | Y（空清單） | Y（一筆，非錯誤級） |
| 結果（讀，JSON 解析失敗或元素缺欄／型別不符） | 呼叫端解析 | Y（整份視為損壞，回空清單；不部分採用） | N（有 level 900 一筆，但不含原始例外與首個不符元素索引） |
| 結果（讀，成功） | `readString` 回傳值經解析 | Y（排序後清單） | Y（一筆，含項數） |
| 結果（寫） | `writeString` 的 `bool` 回傳與例外 | Y（成功／回 false／拋例外三分支，後兩者回 false） | Y（成功一筆；失敗兩分支各一筆 level 900） |

**計數快照**（`0.6.0-W1-018` 用戶裁決；`0.6.0-W1-018.1` 定案）：切換器各項的摘要（節點數 · 票數）與健康徽章
（問題數）一律讀本欄，不讀即時掃描結果。

| 項目 | 定義 |
|------|------|
| 欄位 | `counts`：物件，三欄皆必存在且為非負整數——`nodeCount`、`ticketCount`、`issueCount` |
| `nodeCount` | 該輪掃描的 `ScanSummary.nodeCount`（`ScanRoundResult.scan.summary`） |
| `ticketCount` | 該輪 `ScanRoundResult.scan.rawNodes` 中 `typeName` 等於 `ticketTypeName` 的節點數；解析失敗的 Ticket 檔不計入（它們已計入 `issueCount`） |
| `issueCount` | 該輪的破洞報告總項數：與破洞報告畫面列出的項數同一定義，即 `GapReportFound`／`GapReportUndeterminable` 各類別 `items` 長度加總、`GapReportNoGaps` 為 0（同 `ScanNotificationController` 送通知時的計數）；以 `gapItemIdsOf(round)` 的集合大小取值，兩者須相等 |
| 寫入時機 | 每輪掃描完成（`scanRoundProvider` 進入 `ScanRoundCompleted`）時，以 `result.workspacePath` 呼叫 `saveRecentProjectCounts`；掃描失敗、取消、未完成的輪次不寫入，快照維持前一輪值。另於 `addRecentProject` 成功後，若最近完成輪次的 `workspacePath` 與該項相同，立即以該輪補寫（首次開啟的專案首輪可能先於加入清單完成） |
| 目前專案項 | 同樣顯示快照，不顯示即時值。理由：單一來源，切換器不需區分兩種資料路徑；輪次完成即寫入，完成後快照與即時值相同，差異只存在於輪次進行中，此時顯示上一輪值屬正確語意 |
| 無快照 | 元素無 `counts` 欄（本欄加入前寫入的舊資料、或從未完成過掃描的項）：切換器不顯示摘要列與健康徽章 |
| `counts` 格式不符 | 缺欄、非整數或為負：該元素視為無快照（`counts` 為 `null`），其餘欄照常採用，記一筆 level 900 日誌（含元素索引）；不判整份損壞。理由：快照可由下一輪掃描重建，整份判損會使 `addRecentProject` 以空清單為基底覆寫、遺失所有最近專案，代價與快照價值不相稱。〈損壞時不覆寫的邊界〉的「不部分採用」只針對 `path`／`lastOpenedAt` |
| schemaVersion | 不新增版本欄位、不升版。理由：`counts` 為選填欄，新讀取端以「欄不存在」判定舊資料，無需版本號；舊版 App 讀到多出的欄位不判損（解析只檢查兩個必存在欄），寫回時會丟棄 `counts`，下一輪掃描完成即重建 |

**計數寫入的回饋點**：

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出 | 呼叫端 `saveRecentProjectCounts()` | Y | Y（入口一筆，含 path 與三個計數） |
| 受理 | `WorkspacePreferencesPort.open()`（同 §2.2） | Y（拋例外 → 回 false） | Y（level 900 一筆） |
| 結果（清單無同 path 項） | 呼叫端 | Y（回 false，不寫入） | Y（一筆，非錯誤級） |
| 結果（讀到損壞清單） | 呼叫端解析 | Y（回 false，不寫入；不以空清單為基底，因本方法不負責插入項） | Y（level 900 一筆） |
| 結果（寫） | `writeString` 的 `bool` 回傳與例外 | Y（成功／回 false／拋例外，後兩者回 false） | Y（成功一筆；失敗兩分支各一筆 level 900） |

寫入失敗不呈現於畫面：快照是輔助資訊，失敗不影響本輪結果的各畫面，下一輪完成時重寫；
失敗只進日誌。呼叫端不重試。

**損壞時不覆寫的邊界**：讀取判為損壞時，`loadRecentProjects()` 不回寫、不清除該 key；
`addRecentProject()` 讀到損壞內容時以空清單為基底寫入新項（損壞內容因此被取代），
該次日誌須記錄「以損壞內容為基底被取代」一筆 level 900，使資料遺失可被觀測。

**不互相抵扣**：讀取失敗分支呼叫端只得空清單（切換器落 `state-switcher-no-recent`），
失敗原因只進日誌；兩投影各自完整，同 §2.2。

### 2.5 最近專案項可用性探測

來源：`0.6.0-W1-019` 用戶裁決。本節的接縫已實作（`WorkspaceRepository.probeRecentProject`），下列表格的 Y／N 依實作判定（2026-11-05 讀碼）。
消費方為切換器展開時的逐項探測（SPEC-003 §3.7〈生命週期〉「展開時」列）。

**載體**：沿用 §2.3 `WorkspaceDirectoryProbePort`，不新增 port。判定邏輯沿用
`WorkspaceRepository._inspect()`：資料夾存在與可讀的判準、兩種不可用原因常數，與點選後
開啟該路徑的判定相同，探測與點選對同一資料夾的結論因此一致。

**逾時值**：每項探測 **2 秒**。計時自該項探測呼叫發出起算，各項獨立計時、互不阻塞。

**型別與方法**：

| 符號 | 落點 | 定義 |
|------|------|------|
| `RecentProjectAvailability` | `lib/workspace/workspace_types.dart` | sealed，三個子型別：`RecentProjectAvailable`、`RecentProjectUnavailable`（欄位 `reason`：`String`，取 `_inspect()` 回傳的 `WorkspaceUnavailable.reason`）、`RecentProjectProbeTimedOut`（無欄位） |
| `probeRecentProject(String path)` | `WorkspaceRepository` | 回傳 `Future<RecentProjectAvailability>`；以 2 秒為上限等待 `_inspect(path)`，`WorkspaceReady` → `RecentProjectAvailable`，`WorkspaceUnavailable` → `RecentProjectUnavailable`，逾時 → `RecentProjectProbeTimedOut`；不拋例外 |

**回饋點承擔者**：

| 時刻 | 承擔者 | 呼叫端投影 | 日誌投影 |
|------|--------|-----------|---------|
| 呼叫發出 | 呼叫端 `_inspect()` | Y | 既有（§2.3 兩列），不另加入口日誌 |
| 受理 | 無（理由同 §2.3） | N/A | N/A |
| 結果（可用／不可用） | `_inspect()` 回傳值 | Y（`RecentProjectAvailable`／`RecentProjectUnavailable`） | 沿用 §2.3 各結果列（G-1 已修） |
| 結果（逾時） | `probeRecentProject` 的計時 | Y（`RecentProjectProbeTimedOut`） | Y（level 900 一筆，含 path 與逾時值；事件 `WorkspaceLogEvent.probeRecentProjectTimedOut`） |

**畫面上的原因文字**：`RecentProjectProbeTimedOut` 以
`projectUnavailableReasonLabel(probeTimeoutReason)` 呈現；`RecentProjectUnavailable` 以
`projectUnavailableReasonLabel(reason)` 呈現，與點選失敗相同（SPEC-004 4.9 disabled 列）。

**設計點與理由**：

| 設計點 | 定案 | 理由 |
|--------|------|------|
| 逾時實作位置 | repository（`probeRecentProject`） | 逾時值屬 workspace domain（SPEC-003 §3.7 原已如此劃分）；放在呼叫端會讓 UI 層持有領域常數，且逾時日誌無法與 §2.3 的探測日誌同處 |
| 逾時與失敗是否分型別 | 分，用 `RecentProjectAvailability` 三型 | `WorkspaceUnavailable.reason` 是固定中文常數，`probeTimeoutReason` 是 l10n key，兩者來源不同；若把逾時塞進 `WorkspaceUnavailable` 須新增一個非 l10n 的逾時常數，與 key 重複且不隨語系切換 |
| 不沿用 `WorkspaceState` 作回傳 | 不沿用 | `WorkspaceState` 描述目前專案的狀態（含 `WorkspaceUnset`），探測結果沒有「未設定」這個值 |
| 逾時後底層 I/O | 不取消，結果丟棄 | `dart:io` 的 `exists`／`list` 無取消介面；逾時後晚到的結果不改變已回傳的 `RecentProjectProbeTimedOut` |
| 探測進行中收合浮層 | 結果丟棄，不寫入任何狀態 | 可用性只在單次展開內有效，下次展開重新探測（SPEC-003 §3.7「最近專案項失敗後的可用性」列）；保留舊結果會讓下次展開先顯示過期狀態 |

## 三、現況缺口

| 編號 | 缺口 | 據實描述 | 承接票 |
|------|------|---------|--------|
| G-1（已修，2026-11-05） | `_DefaultWorkspaceDirectoryProbePort` **全無日誌**（修前現況；現已於 `exists`／`readFirstEntry` 記 `adapterProbeExistsResult`／`adapterProbeReadFirstEntryResult`，測試 `test/unit/workspace/workspace_adapter_logging_test.dart`） | 該 adapter 的 `exists` 與 `readFirstEntry` 皆為單行直呼 `dart:io`，類別內無任何 `developer.log` 呼叫（實讀 `lib/workspace/workspace_repository.dart` 確認）。`0.1.0-W3-139` 記為「`exists()=false` 日誌缺失」，實際範圍比該描述更廣——缺的不只是呼叫端 `_inspect()` 中 false 分支那一筆，adapter 端本身零日誌。後果：日誌消費者無法區分「探測過但資料夾不存在」與「根本沒探測」 | `0.6.0-W1-192`（2026-11-05 讀碼確認仍未修；原承接票 `0.1.0-W3-135` 已不在票庫） |
| G-2（已修，2026-11-05） | 日誌投影集中於呼叫端 sink，adapter 端零日誌（修前現況；現三個 adapter 建構時接收 `WorkspaceLogSink`，記 `adapterPreferencesOpenResult`／`ReadResult`／`WriteResult`，日誌隨 adapter 實作移動；測試同 G-1） | 全檔僅 `_defaultLogSink`（§1 第三形態的自撰預設實作）一處呼叫 `developer.log`；`_DefaultWorkspacePreferencesPort`、`_DefaultWorkspacePreferencesHandle`、`_DefaultWorkspaceDirectoryProbePort` 三個 adapter 內部皆無日誌。目前 Preferences 兩個接縫的日誌覆蓋完整，是因為呼叫端在 port 呼叫前後各記一筆；此覆蓋依附於呼叫端而非 adapter，替換 adapter 實作時日誌不隨之移動 | 形態層面的約定歸形態約定補記段（§一）；日誌位置的修補歸 `0.6.0-W1-192`（2026-11-05 讀碼確認仍未修） |

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

本規格的唯一合法變更理由為**資料夾存取方式改變**（`docs/spec/workspace/domain-map.md` §3 對 Workspace
bundle 的界定）。與 UI 互動方式改變而生的 port 契約（`ScanNotifier`、`ExternalOpener`）
不屬本規格，其落點為 SPEC-003 §2.2（承接票 `0.1.0-W3-149`）。

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.11 | 2026-11-10 | 〈概述〉補一段：日誌事件的記錄信封、錯誤來源分類、欄位值白名單與落地位置依 SPEC-010；負載中的 path 改記工作區相對路徑（`1.0.0-W3-553.2.1`） |
| 1.10 | 2026-11-09 | `0.6.0-W1-194.1`（依 `0.6.0-W1-194` 查證）：更正 v1.8 列「原承接票 `0.1.0-W3-135` 已不在票庫」——該票是改號，不是刪除，現為 `1.0.0-W3-135`（pending），內容是 `WorkspaceDirectoryProbePort` 的例外契約；§三 G-1、G-2 的日誌已由 `0.6.0-W1-192` 修畢。v1.8 列保留原文。不改契約 |
| 1.9 | 2026-11-05 | `0.6.0-W1-192`：§三 G-1、G-2 改記為已修並附測試；§2.3 `exists` 回 false 結果列 adapter 欄 N 改 Y，§2.5 對應列同步 |
| 1.8 | 2026-11-05 | `0.6.0-W1-191.2`（依 `0.6.0-W1-191` 時效型註記盤點，讀碼查證）：§2.4、§2.5 原寫「實作尚未存在」，實作已落地，改為依實作判定的 Y／N，共 14 列；唯一 N 為 §2.4 讀取損壞的日誌（實作有 level 900 一筆，但不含原始例外與首個不符元素索引）。§2.2 `remove` 仍未實作，維持「契約」。§三 G-1、G-2 確認仍未修，原承接票 `0.1.0-W3-135` 已不在票庫，承接改為 `0.6.0-W1-192` |
| 1.7 | 2026-11-05 | `0.6.0-W1-086.1`（依 `0.6.0-W1-086` 規則 7 盤點）：§一與 §1.1 原以票號 `0.1.0-W3-146` 指稱接縫形態約定，改為指稱 `docs/tech-decisions.md` 補記段「2026-09-09：driven port 接縫形態約定（W3-133／W3-146）」（下稱「形態約定補記段」），內文各處「146」同步改寫；不改結論 |
| 1.6 | 2026-11-04 | §2.4〈計數快照〉寫入時機補一句：`addRecentProject` 成功後，若最近完成輪次的 `workspacePath` 與該項相同，立即補寫（首次開啟的專案首輪先於加入清單完成時不再落空）；不改 `addRecentProject` 的「成功載入後」時機。來源 `0.6.0-W1-145` |
| 1.5 | 2026-11-04 | 新增 §2.5 最近專案項可用性探測：每項逾時 2 秒、沿用 `_inspect()` 判定、`RecentProjectAvailability` 三型與 `probeRecentProject`、回饋點表（逾時 level 900 日誌）、原因文字來源、五項設計點與理由；§2.4 寫入時機段改引 §2.5。來源 `0.6.0-W1-019` 用戶裁決，承接票 `0.6.0-W1-019.1` |
| 1.4 | 2026-11-03 | §2.4 新增〈計數快照〉：陣列元素選填欄 `counts`（`nodeCount`／`ticketCount`／`issueCount`）、三計數來源、寫入時機（每輪掃描完成）、目前專案項亦讀快照、無快照不顯示摘要與徽章、`counts` 格式不符只降為無快照、不新增 schemaVersion；新增 `RecentProjectCounts`、`saveRecentProjectCounts` 與其回饋點表；`addRecentProject` 帶入同 path 舊項的 `counts`。來源 `0.6.0-W1-018` 用戶裁決，承接票 `0.6.0-W1-018.1` |
| 1.3 | 2026-10-13 | frontmatter 新增 `has_functional_requirements: false`：本規格不含 FR 為設計（通則在方法論〈Port 回饋契約〉，本規格只記專案事實），覆蓋檢查據此不執行 FR 比對。條文無變更。來源 `0.5.0-W1-159`，承接票 `0.5.0-W1-159.1` |
| 1.2 | 2026-09-24 | §2.2 回饋點表新增 `remove` 結果時刻列（`clearStoredPath()` 清除已存路徑，S-21）；新增 §2.4 最近專案清單持久化：key `workspace.recentProjects`、JSON 陣列 schema（`path` + `lastOpenedAt`）、`RecentProject` 與兩個 repository 方法、寫入時機、回饋點承擔者表、損壞處理邊界（S-36）。來源 `0.2.0-W1-023`，承接票 `0.2.1-W1-043` |
| 1.1 | 2026-09-09 | 對齊 `0.1.0-W3-146`／`0.1.0-W3-147` 落地後的現況：載體段由遷移事件敘述改寫為三條契約（接縫落點／value types 落點／不 re-export 與呼叫端 import 約束），時態問題隨之消解；§1 補與 146 對照表的列定義差異（歸屬單位 vs 計算單位）並寫出拆列會使判準把 `WorkspacePreferencesPort` 判成 typedef 的失效機制；§1.1 補軸別釐清並寫明所擋的推論與刪除代價。`docs/tech-decisions.md` 補記段有對稱一份（`0.1.0-W3-157`） |
| 1.0 | 2026-09-09 | 初始版本：workspace 五個接縫與三種形態、受盤點的四個 port 的回饋點承擔者、`WorkspaceLogSink` 排除判定與理由（§1.1）、兩項現況缺口、測試替身紀律（`0.1.0-W3-148`） |
