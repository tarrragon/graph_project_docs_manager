---
id: UC-11
title: "標籤管理"
status: approved
created: "2026-07-16"
updated: "2026-07-16"
primary_actor: "使用者"
platform: "app"
---

# UC-11: 標籤管理

## 基本資訊

- **用例ID**: UC-11
- **用例名稱**: 標籤管理（custom tag 建立/重命名/刪除、批次操作、書籍 tag 編輯、CCL 選擇）
- **主要行為者**: 使用者
- **前置條件**:
  - 已開啟應用程式
  - 書庫首頁處於管理模式（簡潔模式下標籤管理入口不可見，見替代流程 0a）
- **成功保證**: 標籤變更持久化並即時反映於標籤樹；書籍 tag 指派變更即時反映於編輯介面
- **對應 spec**: SPEC-013（`docs/spec/library/tag-management.md`），各步驟引用 FR-013 編號

## 主要成功場景（custom tag CRUD）

1. **進入標籤管理**
   - 使用者於書庫首頁（管理模式）點擊 AppBar 標籤入口（`navigation_tag_management`，`lib/presentation/library/home_page.dart`）
   - 系統開啟標籤管理頁面並載入 custom 分類的標籤樹（FR-013-01）
   - 載入中顯示骨架畫面；標籤以樹狀清單呈現，最大深度 3 層，每項含色塊（16 色盤名稱 hash 映射）與展開/收合切換（FR-013-05/06/07）

2. **建立標籤**
   - 使用者點擊新增入口（FAB），開啟建立對話框（FR-013-02）
   - 輸入名稱，並可從下拉清單選擇父標籤（選項深度受「最大深度 - 1」限制）或維持無父節點
   - 確認後系統建立標籤並重新載入標籤樹

3. **重命名標籤**
   - 使用者對指定標籤觸發重命名對話框，輸入新名稱（FR-013-03）
   - 確認後系統更新名稱並重新載入標籤樹

4. **刪除標籤**
   - 使用者對指定標籤觸發刪除對話框
   - 系統呈現三種子節點處置策略：reparent / orphan / cascade（FR-013-04）
   - 使用者選定策略並確認，系統執行刪除並重新載入標籤樹

## 替代流程

**0a. 簡潔模式下入口不可見**
- 0a1. 書庫首頁處於簡潔模式時，標籤管理入口不顯示
- 0a2. 使用者須先以模式切換按鈕切換至管理模式，入口才可見（前置條件反向展開）

**1a. 標籤清單為空**
- 1a1. 載入成功但無任何標籤時，顯示空狀態提示與引導文字
- 1a2. 新增入口（FAB）仍可見，使用者可直接建立第一個標籤（空狀態下本 UC 入口可用）

**1b. 載入失敗**
- 1b1. 顯示錯誤訊息（頁面錯誤狀態）
- 1b2. 使用者可重新觸發載入（切換分類）

**2a/3a/4a. CRUD 操作失敗**
- 系統保留列表現況並呈現錯誤訊息，不改變頁面主狀態（SPEC-013 第 4.1 節）

**替代路徑 A：批次選取與合併/刪除/移動**
- A1. 使用者進入批次模式，以觸發的標籤為初始選取（FR-013-13）
- A2. 點選其他標籤切換選取；選取集合變空時自動退出批次模式（FR-013-14）
- A3. 批次工具列依選取數啟用操作：合併（恰好 2 個）、刪除（至少 1 個）、移動（至少 1 個）（FR-013-15/16/17）
- A4. 合併：指定目標標籤，另一標籤併入；成功後退出批次模式
- A5. 批次刪除/移動：逐一執行；全部成功退出批次模式，部分失敗保留批次模式並回報「失敗數 / 總數」供重試（FR-013-16/17）
- **接線現況**：已接線（0.38.1-W1-110）。長按標籤觸發「批次選取」進入批次模式（`tag_list_tile.dart` 長按選單），底部顯示 TagBatchActionsBar（`tag_management_page.dart`）；接線測試見 `test/widget/presentation/tag_management/tag_management_production_wiring_test.dart`

**替代路徑 B：書籍 tag 編輯（指派/移除/建立並指派）**
- B1. 以指定書籍為對象開啟 tag 編輯 bottom sheet，載入「已指派」與「可用」兩清單（FR-013-08）
- B2. 使用者以關鍵字過濾可用標籤（不分大小寫、名稱包含比對；已指派標籤不出現於可用清單）（FR-013-09）
- B3. 點選可用標籤即指派給書籍；於已指派清單移除標籤（FR-013-10/11）
- B4. 關鍵字與所有既有標籤名稱皆不同（不分大小寫）時，出現「建立並指派」入口；確認後建立新標籤並立即指派（FR-013-12）
- **接線現況**：已接線（0.38.1-W1-110）。書庫項目（`library_display_extensions.dart` `_buildBookItem` 標籤按鈕 `book_tag_edit_button`）呼叫 `showTagEditBottomSheet`；接線測試見 `test/widget/app/tag_management_book_wiring_test.dart`

**替代路徑 C：CCL picker 三步驟選擇**
- C1. 系統以對話框呈現 CCL「大類 → 中類 → 小類」三步驟選擇器，初始載入大類（根節點）（FR-013-18）
- C2. 使用者選定當前步驟節點後前進下一層；至少選到小類（或搜尋直接選中）產生選擇結果
- C3. 使用者可返回上一步驟（下游選擇被清除），並可於每一步以關鍵字過濾當前層節點（FR-013-19）
- **接線現況**：已接線（0.38.1-W1-110）。tag 編輯 bottom sheet（`tag_edit_bottom_sheet.dart` 搜尋欄 `ccl_picker_entry_button`）呼叫 `showCclPickerDialog`，選定節點後直接指派給書籍；接線測試見 `test/widget/presentation/tag_management/tag_management_production_wiring_test.dart`

## 檢核四問紀錄（docs/app-use-cases.md「UC 撰寫檢核四問」）

| 檢核問句 | 結果 | 紀錄 |
|---------|------|------|
| 1. 名詞可定位 | 通過 | 標籤管理頁面 = `TagManagementPage`（`lib/presentation/tag_management/tag_management_page.dart`）；服務由 `tagManagementServiceProvider`（`tag_management_providers.dart`）供給；bottom sheet / 批次工具列 / CCL 對話框皆有具名 widget（`widgets/`） |
| 2. 路徑連通 | 通過 | 主場景入口連通：APP 啟動 → 書庫首頁（管理模式）→ AppBar `navigation_tag_management` → TagManagementPage。替代路徑 A/B/C 的 UI 元件（TagBatchActionsBar / showTagEditBottomSheet / showCclPickerDialog）已完成 production 接線（0.38.1-W1-110）：A 掛於 TagManagementPage 批次模式；B 掛於書庫項目標籤按鈕；C 掛於 tag 編輯 bottom sheet 內，各路徑「接線現況」已更新 |
| 3. 狀態完備 | 通過 | 空狀態：入口（FAB）可見且可建立（替代流程 1a）；錯誤狀態：錯誤訊息 + 可重載（1b）；正常狀態：全操作可用。前置條件反向展開：簡潔模式下入口不可見已列 0a 分支。批次模式正交狀態機見 SPEC-013 第 4.2 節 |
| 4. 環境差異 | 通過 | 標籤持久化經本地資料庫（平台 SQL 語意差異敏感）：主場景步驟 2~4 與批次刪除/移動標注「需實機驗證」（納入發版前實機冒煙清單）；其餘為純 UI 狀態轉換，測試環境與實機一致 |

## CCL Picker 歸屬判斷（W1-096 留白項）

**結論**：CCL picker 併入 UC-11 作替代路徑 C，不獨立為 UC-12。

**理由**：
1. 底層共用 `TagManagementService`，與 custom tag 屬同一功能域（W1-096 已確認）
2. CCL picker 目前無獨立入口路由（無 production 呼叫端），無法通過檢核第 2 問「從啟動畫面一路追到」；不具備獨立 UC 的旅程完整性
3. 行為僅為「選擇一個分類節點」的單一互動，無獨立狀態機生命週期；待未來接線至具體業務流程（如書籍分類指派）時，再評估是否隨該流程升格

## 對應實作

- **頁面**: `lib/presentation/tag_management/tag_management_page.dart`
- **狀態**: `tag_management_viewmodel.dart`（CRUD）、`tag_batch_viewmodel.dart`（批次）、`tag_edit_viewmodel.dart`（書籍編輯）、`ccl_picker_viewmodel.dart`（CCL）
- **Widgets**: `widgets/tag_tree_widget.dart`、`tag_list_tile.dart`、`tag_batch_actions_bar.dart`、`tag_edit_bottom_sheet.dart`、`ccl_picker_dialog.dart`
- **入口**: `lib/presentation/library/home_page.dart`（`navigation_tag_management`，管理模式限定）
- **相關 spec**: SPEC-013；domain API 契約見 SPEC-006 FR-7

---

**Last Updated**: 2026-07-16
**Version**: 1.1 — 替代路徑 A/B/C 完成 production 接線，「接線現況」與檢核四問第 2 問更新為通過（0.38.1-W1-110）。
**Version**: 1.0 — 初版：依 SPEC-013 與 0.38.1-W1-096 盤點建立（0.38.1-W1-109）。
