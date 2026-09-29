# Changelog

本檔記錄 graph_project_docs_manager 各版本對使用者可見的變更。
格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號依 `docs/todolist.yaml` 的版本序列。
開發中的版本以 `In Development` 標記，發版時由 `version-release finish` 換為日期。

## [0.3.2] - In Development
**Topic**：提示訊息與外部開啟。0.3.x 第二個 patch。不變式：0.3.0 的 IT-1、IT-2 仍通過。本版全部行為變更以機械方式驗證（測試、日誌），無人工實測時段。

### Fixed

- 四個畫面的外部開啟改經 `ExternalOpener`：存在檢查、呼叫發出與結果日誌、例外攔截在畫面路徑上生效（0.3.2-W1-004）。
- 開檔入口傳給外部開啟的路徑改為以專案根目錄組成的絕對路徑；先前在 .app 內一律落入「找不到檔案」（0.3.2-W1-007）。
- 專案切換浮層選定的資料夾不可讀時，提示不再寫成「無法存取先前的資料夾」，改用 `folderUnavailableMessage`（0.3.2-W1-009）。
- 切換專案時撤回尚未點擊的掃描完成通知；規格早有要求，先前從未實作（0.3.2-W1-010）。
- App 回到前景且可見頁為破洞報告時撤回掃描完成通知，判準與 SPEC-003 §2.13 T1 的「使用者當前可見」一致（0.3.2-W1-005、0.3.2-W1-008，用戶裁決）。
- 使用者按下提示動作而觸發的再顯示，被截斷的舊提示其關閉事件不再記為背景等級（0.3.2-W3-253、0.3.2-W3-549）。
- 英文語系補齊 `gapCategoryMissingFrontmatter`、`gapItemLineLabel` 兩則文案（0.3.2-W3-548）。

### Changed

- 「已在外部開啟」提示保留，並補上具名理由：外部應用冷啟動時約 0.46–0.80 秒後才取得前景，這段期間提示是唯一回饋；目標已開啟時提示不可見（0.3.2-W3-236、0.3.2-W3-550 量測，0.3.2-W3-210，用戶裁決）。
- 規格：`folderPickerUnavailableMessage` 併入既有 `chooseFolderUnavailableMessage`（0.3.2-W3-368）；SPEC-003 §2.14 提示指派表與 lib 全部提示呼叫點差集為零（0.3.2-W3-248）。SPEC-003 v1.46、SPEC-004 v1.50。

### Process

- 版本契約（範圍、預期變更、驗證方式、人工實測時段、結果值日誌）首次於開工前寫定並逐項對照；兩則契約外差異（未覆寫 provider 的測試隱式走真實檔案系統、預期紅燈計數單位混用）記入 `docs/todolist.yaml` 0.3.2 notes。
- 非權限類的前後景行為改以日誌判定：VM service Logging 訂閱或拋棄式 integration_test 探針，搭配正向對照與樣本有效前提。
- ticket 關聯命令支援跨版本 ID（0.3.2-W1-006）；派發位置判準與 worktree 強制修正（0.3.2-W1-011～014，canonical #101）。

---

## [0.3.1] - 2026-09-29
**Topic**：掃描通知與破洞判定。0.3.x 發版後分診的第一個 patch（固定三個：0.3.1／0.3.2／0.3.3）。不變式：0.3.0 的 IT-1、IT-2 仍通過。

### Fixed

- 破洞掃描不再於 App 啟動時觸發，改為首次進入破洞報告頁時才掃描；啟動時不再出現通知授權詢問（0.3.1-W3-122）。
- 掃描完成通知發送失敗時，改以 App 內提示顯示，並延到 App 回到前景才出現；原生層改為回傳發送錯誤，使平台層失敗也走這條路徑（0.3.1-W3-113、0.3.1-W1-096）。
- 點擊掃描完成通知會把已隱藏的 App 帶回前景並導向破洞報告；點擊路徑補上記錄結果值的日誌（0.3.1-W1-097）。
- 子票（如 `X.Y.Z-W1-001.1`）被判為非節點：Ticket 型 `id_pattern` 改為接受子票序號，內嵌型別表同步更新；子票與其 children／parent_id 邊回到圖中（0.3.1-W1-092）。

### Changed

- IT-2 凍結測資：1249 列子票由非節點改為節點。gap 46、failure_unmatched 1252、總列數 7472 不變（預期變更，見 0.3.1-W1-092）。
- 工作區日誌改以事件識別碼區分，測試斷言不再比對中文訊息字面（0.3.1-W3-132）。
- SPEC-003 v1.41（通知實機量測記錄）、SPEC-006 v1.8（carrier 路徑內 id 不符 pattern 的破洞歸類）。

### Process

- 版本規劃模型：minor 完成後依 topic 定固定數量 patch、執行期新發現依 topic 契合度收件、例外閥（契約行為或資料錯誤）、流程工具缺陷列為前置，以及每版的版本契約（預期變更、驗證方式分類）。見 `docs/tech-decisions.md` 2026-09-29 各則補記。
- 0.x 的 minor 清單固定為 0.4～0.7，編輯能力劃為 1.0（PROP-005）。
- ticket skill 本地修正三項（跨版本衍生票判定、ANA 票面的隔離提交、complete 自動提交），已登記 canonical issue #102、#55、#77。

---

## [0.3.0] - 2026-09-25
（待補充）

---

## [0.2.1] - 2026-09-24
（待補充）

---

## [0.2.0] - 2026-09-23
**Gate**：Workspace + Schema 三路 gate。使用者選取的真實資料夾依兩個訊號（`.claude/VERSION` 值、`.claude/skills/doc/doc_system/core/tracking_schema.json` 存在與其產生版本）進入正確分支（PROP-005 §0.2、SPEC-001 FR-04／FR-07）。整合測試：本機 17 個有 `.claude/` 的專案各自進入正確 gate 分支（凍結 manifest 逐專案斷言，6／9／2）；實機以三個真實資料夾各進一個分支。

### Added

- gate 偵測：filesystem 探測 port（可 mock）與 `GateDetectionNotifier`，依 SPEC-001〈Gate 三問對照〉判定順序路由 DomainViewState 四個子類別；「App 已知範圍」定為 JSON 產生版本不高於 App 內建版本。
- 啟動時 `WorkspaceRepository.restore()` 讀回選定路徑並接 gate 偵測；切換／選擇資料夾成功後重置降級與推定旗標再偵測。
- 專案切換器「選擇其他」接線至真實資料夾選取器，`ChooseFolderResult` 四變體依 SPEC-003 回饋。
- 推定版本旗標（`.claude/VERSION` 缺、JSON 有）：既有狀態疊加 `inferredVersion`，返回列徽章與降級徽章互斥。
- shared_preferences key 版本化與遷移（`workspace.schemaVersion`），遷移失敗降級為未選定、不阻擋啟動。
- 17 列凍結 manifest 整合測試與兩個邊界案例（推定版本、JSON 版本高於內建）。

### Changed

- 「不是框架專案」說明文字改為 PROP-002 全路徑，與 SPEC-001 §1 字面一致。
- SPEC-001 1.18／1.19、SPEC-004 1.45、PROP-005 §0.2（判準對齊兩訊號、計數 6／9／2、status confirmed）。

### Process

- 版本 scope 凍結模型首次完整走完：Batch 0 決策後凍結，7 張契約票帶 `scope_blocker`，溢出票由 `finish` 前移；規格領先實作的票由凍結閘門擋下並路由至新登記的 0.2.1。

---

## [0.1.1] - 2026-09-24（結案，未發版）
**Runoff**：0.1.0 發版時前移票的凍結容器。79 張經分流後 27 張關閉（框架問題移交 canonical issue、規劃前置收束進 domain-map）、42 張前移至 0.3.0，無產品變更；不打 tag。

---

## [0.1.0] - 2026-09-23
**Shell**：展示介面。七個畫面與浮層的全部狀態皆可渲染，不串真實資料（PROP-004、PROP-005）。整合測試：SPEC-001 §1-7 全部狀態渲染且不溢位；捲動、換頁、拖拉皆可操作。

### Added

- 六個畫面的全部狀態列，依 SPEC-001 §1-7 與 SPEC-004 的元件組合契約實作：Domain 視圖（矩陣／泳道／降級）、UC Flow 視圖、追溯視圖、Ticket 清單、破洞報告、節點詳情，以及專案切換浮層。狀態由真實 repo 快照的 fixture 驅動，不用生成器。
- 元件庫（SPEC-004）：統一自 `lib/components/components.dart` 匯出，頁面層不直接組合原生佈局原語；元件內零裸值（色碼、尺寸、字級、Duration 皆走 tokens）。
- 路由殼與六項導覽（SPEC-001 §1-7 對應 PROP-004 畫面清單），側欄頂端專案名與浮層入口。
- 降級型別表完整鏈（SPEC-001 §1、SPEC-003 §3.1／§5）：`tracking_schema.json` 缺席時提供「以 App 內建型別表檢視」入口；內建型別表版本讀自實際內嵌資產並與框架 VERSION 做漂移偵測；降級旗標於觸發時設真、切換專案時重置；六畫面任一狀態常駐降級徽章，徽章文字含內建版本與專案版本。
- `ExternalOpener` 抽象與 macOS `open` 實作（SPEC-003 §2.2）：三值結果（opened／notFound／failed）、呼叫發出與結果兩個回饋點皆有日誌、`FakeExternalOpener` 供畫面測試注入。實機以 debug `.app` 內的 macOS integration test 量測檔案與目錄開啟皆成功。
- 專案切換浮層展開態的健康徽章文案（SPEC-001 §7）：以問題計數分兩類呈現，英文朗讀依單複數。
- Ticket 清單：blockedBy 欄、目標列定位高亮、跳轉帶篩選時的清除動作。
- macOS integration test 探針併入 `app_test.dart`，單次啟動即覆蓋整批（含帶開關的變體）。

### Changed

- 移除 `main.dart` 的 `HomePage` 及其助手 widget：W1-005 元件庫完成後無可回收部分；其 `ChooseFolderResult` 四變體處理由後續版本接線至專案切換器。
- SPEC-001 推進至 1.17、SPEC-003 至 1.37、SPEC-004 至 1.44，皆為實作期回填的狀態列與元件契約修訂；SPEC-004 三處「0.1 不渲染純檔案模式」引用改為引用 SPEC-001 v1.5 §1 降級條款。
- 「不是框架專案」訊息（zh／en）對齊 SPEC-001 v1.14 的兩訊號判準；message 與 explanation 互補不重複。

### Fixed

- `IssueMarker.child` 巢狀時命中區互相遮蔽，以 `IgnorePointer` 隔離。
- 追溯視圖同一 `nodeId` 出現在多個父節點下時，各出現位置共用展開狀態、缺口標示各自獨立。
- `AppSnackBar` 事件流小表與 UC 選擇入口的元件缺件（`ListRow.option`、`TableRow.eventFlow`、`AppDataTable.appendix`）補齊後，UC Flow 三個原本以佔位渲染的狀態改為完整組成。

---
