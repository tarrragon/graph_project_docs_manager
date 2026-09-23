# Changelog

本檔記錄 graph_project_docs_manager 各版本對使用者可見的變更。
格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號依 `docs/todolist.yaml` 的版本序列。
開發中的版本以 `In Development` 標記，發版時由 `version-release finish` 換為日期。

## [0.2.0] - In Development
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
