# BookSupplementPage 介面規格（單書補充頁面）

> **TDD Phase 1 介面設計**（非實作）。本文件定義單書補充流程頁面的 wireframe、狀態流轉與 widget Key 命名契約。
> **來源邊界**：`docs/work-logs/v0/v0.31/v0.31.1/tickets/0.31.1-W8-026.1.md`（SA 審查「實作範圍邊界定義」）
> **Key 一致性基準**：`test/integration/uc04_to_uc08_integration_tests.dart`（單書流程 line 150-200 / 295-410）

---

## 1. Purpose（功能目的）

提供使用者對「資訊不完整書籍」進行單本補充的完整流程頁面：從書庫卡片入口進入 → 搜尋確認 → 候選清單 → 選書 →（衝突偵測 → 解決）→ 更新預覽 → 完成。

| 項目 | 說明 |
|------|------|
| 對應 Use Case | UC-04 單書補充流程 |
| 使用者角色 | 書庫管理者（對缺漏作者/出版社/出版日的書籍補資料） |
| 核心價值 | 以 Google Books 搜尋結果一鍵補全書籍 metadata，並在衝突時提供欄位級選擇 |
| 範圍邊界 | 單書補充頁面本體 + 宿主 ConflictResolutionWidget 的邊界契約 |
| 不在範圍 | 批次補充（BatchSupplementPage / W8-026.3）、ConflictResolutionWidget 內部設計（W8-026.4）、navigation_library 全 app 導航 |

---

## 2. 沿用既有資產（禁止重建）

> 依 W8-026.1 SA 審查邊界。本頁不新建平行 ViewModel / Provider。

| 資產 | 路徑 | 沿用方式 |
|------|------|---------|
| ViewModel | `lib/presentation/search/viewmodels/search_book_view_model.dart` | 擴展「補充模式」context（targetBook + previewDiff），勿新建平行 VM |
| ViewState | `lib/presentation/search/viewmodels/search_book_view_state.dart` | 沿用，補充模式所需欄位以擴展方式新增 |
| 狀態枚舉 | `lib/presentation/search/viewmodels/search_book_state_enum.dart` | 直接沿用（idle/validating/searching/candidatesLoaded/previewing/updating/success/error 已涵蓋本流程） |
| Provider 集合 | `lib/presentation/search/providers/search_providers.dart` | 直接沿用（UseCase/Repository/EventBus DI） |
| Provider（搜尋） | `lib/presentation/search/providers/book_search_providers.dart` | 直接沿用 |
| 候選清單 widget | `lib/presentation/search/widgets/search_candidate_list.dart` | 語意可參考；本頁候選卡片 Key 須對齊本 spec 命名（search_result_card_0 / select_book_button_0） |
| 差異預覽 widget | `lib/presentation/search/widgets/data_diff_preview.dart` | 語意可參考；預覽段沿用，文案「資訊更新預覽」對齊 |
| 搜尋對話框 widget | `lib/presentation/search/widgets/search_dialog.dart` | 語意可參考；本頁採整頁流程，非 dialog |

**狀態枚舉對照（既有 enum 已足夠，無需新增 state）**：

| SearchBookState | 本頁流程段 |
|-----------------|-----------|
| idle | 搜尋確認頁（入口剛進入） |
| validating | 關鍵字驗證（短書名/空白偵測） |
| searching | 呼叫 Google Books API 中 |
| candidatesLoaded | 候選清單展示 |
| previewing | 更新預覽 /（含衝突偵測分支） |
| updating | 寫入更新中 |
| success | 完成（「書籍資訊已更新」） |
| error | 無結果 / 搜尋失敗 / 更新失敗 |

---

## 3. Wireframe（畫面結構）

### 3.1 搜尋確認頁（state = idle / validating）

```
+------------------------------------------------------+
| [<]  補充書籍資訊                                     |  AppBar
+------------------------------------------------------+
|                                                      |
|  將搜尋：《原子習慣》                                 |  確認標題（textContaining 書名）
|                                                      |
|  +------------------------------------------------+  |
|  | search_keyword_field                           |  |  可編輯關鍵字 TextField
|  | [ 原子習慣                              ]       |  |
|  +------------------------------------------------+  |
|                                                      |
|  -- 短書名分支（validating 警告，僅短書名時顯示）--  |
|  ! 書名過短可能影響搜尋精度                          |  警告文字
|  [ search_tips_button ]  [ add_author_to_search ]   |  提示 / 加作者按鈕
|                                                      |
|                          +----------------------+    |
|                          | start_search_button  |    |  主行動：開始搜尋
|                          +----------------------+    |
+------------------------------------------------------+
```

### 3.2 候選清單頁（state = candidatesLoaded）

```
+------------------------------------------------------+
| [<]  搜尋結果                                         |
+------------------------------------------------------+
|  搜尋結果                                             |  區段標題（text '搜尋結果'）
|  +------------------------------------------------+  |
|  | search_result_card_0                           |  |  候選卡片（index 0..n）
|  |  原子習慣                                       |  |
|  |  作者: 詹姆斯．克利爾                           |  |  textContaining 作者
|  |  相似度: 95%                                    |  |  similarity_badge 既有 widget
|  |                       [ select_book_button_0 ]  |  |  選此書（index 對齊卡片）
|  +------------------------------------------------+  |
|  | search_result_card_1 ...                       |  |
|  +------------------------------------------------+  |
+------------------------------------------------------+
```

### 3.3 無結果頁（state = error，空結果分支）

```
+------------------------------------------------------+
|  找不到相關書籍，正在嘗試其他搜尋策略...             |  text 完整字面
|                                                      |
|  建設性選項：                                        |
|  [ adjust_search_keywords ]   調整搜尋關鍵字         |
|  [ manual_edit_info ]         手動編輯資訊           |
|  [ try_later_option ]         稍後再試               |
+------------------------------------------------------+
```

### 3.4 更新預覽頁（state = previewing，無衝突）

```
+------------------------------------------------------+
|  資訊更新預覽                                         |  text '資訊更新預覽'
|  data_diff_preview（既有 widget 語意）               |
|  作者: 詹姆斯．克利爾                                 |  textContaining
|  出版社: 方智                                         |  textContaining
|                          +----------------------+    |
|                          | confirm_update_button|    |  確認更新
|                          +----------------------+    |
+------------------------------------------------------+
```

### 3.5 衝突解決頁（state = previewing，衝突分支 → 宿主 ConflictResolutionWidget）

```
+------------------------------------------------------+
|  發現資訊衝突                                         |  text '發現資訊衝突'（本頁提供）
|  +------------------------------------------------+  |
|  | <<< ConflictResolutionWidget（W8-026.4 設計） >>>|  |  本頁宿主，內部不在本 spec
|  |   conflict_comparison_table                    |  |  （契約見 §5）
|  +------------------------------------------------+  |
+------------------------------------------------------+
```

### 3.6 完成頁（state = success）

```
+------------------------------------------------------+
|  書籍資訊已更新                                       |  text '書籍資訊已更新'
+------------------------------------------------------+
```

---

## 4. 狀態流轉圖

```
  [入口: 書庫卡片 supplement_info_button]
                 |
                 v
        +------------------+
        | idle 搜尋確認頁  |  顯示「將搜尋：《書名》」+ search_keyword_field
        +------------------+
                 | start_search_button
                 v
        +------------------+   短書名/空白
        |   validating     |--------------> 顯示警告 + search_tips_button / add_author_to_search
        +------------------+                （留在確認頁，可加關鍵字重搜）
                 | 通過
                 v
        +------------------+
        |    searching     |  呼叫 Google Books API
        +------------------+
            |          \  空結果
            | 有結果    \---------> +----------------------------+
            v                       | error（無結果分支）        |
   +-------------------+            | adjust_search_keywords     |
   | candidatesLoaded  |            | manual_edit_info           |
   | search_result_card|            | try_later_option           |
   +-------------------+            +----------------------------+
            | select_book_button_0
            v
     [conflict_detector 偵測欄位衝突？]
        |  無                |  有
        v                    v
+----------------+   +----------------------------+
| previewing     |   | previewing（衝突分支）     |
| 資訊更新預覽   |   | 宿主 ConflictResolutionW.  |
+----------------+   | conflict_comparison_table  |
        |            +----------------------------+
        | confirm_update_button   | 用戶欄位級選擇結果回傳
        v                         v
   +------------+          （回到更新流程）
   | updating   |<----------------+
   +------------+
        |
        v
   +------------+
   | success    |  「書籍資訊已更新」
   +------------+

  錯誤態（任一階段）: error（搜尋失敗 / 更新失敗）
```

---

## 5. 宿主 ConflictResolutionWidget 邊界契約

> ConflictResolutionWidget 內部由 **W8-026.4** 獨立設計。本 spec 僅定義 BookSupplementPage 如何宿主它（觸發 / 呈現 / 資料進出）。

### 5.1 觸發

| 條件 | 動作 |
|------|------|
| 用戶點擊 `select_book_button_0`（選定候選） | BookSupplementPage 呼叫 conflict_detector 比對 targetBook（原值）vs 選定候選（新值） |
| conflict_detector 回報「無衝突」 | 進 §3.4 更新預覽（previewing 無衝突分支） |
| conflict_detector 回報「有欄位衝突」 | 進 §3.5，本頁顯示文字「發現資訊衝突」並呈現 ConflictResolutionWidget |

### 5.2 呈現

| 項目 | 契約 |
|------|------|
| 呈現方式 | inline（嵌入 previewing 頁面區塊）；ConflictResolutionWidget 自帶 `conflict_comparison_table` Key |
| 本頁職責 | 提供標題文字「發現資訊衝突」+ 容器；不繪製比較表內部 |
| Key 歸屬 | `conflict_comparison_table`、`field_level_selection`、`select_new_title`、`keep_original_author`、`confirm_selective_update` 由 ConflictResolutionWidget 提供（W8-026.4），**不在本頁 11 Key 範圍** |

### 5.3 資料進出（介面契約）

```
BookSupplementPage  --(傳入)-->  ConflictResolutionWidget
  conflictData: {
    perField: [ {field, originalValue, newValue}, ... ]   // 原值 vs 新值，欄位級
  }

ConflictResolutionWidget  --(回傳 callback)-->  BookSupplementPage
  onResolved(resolution): {
    perField: [ {field, chosenValue}, ... ]               // 用戶欄位級選擇結果
  }
       |
       v
  BookSupplementPage 以 resolution 組裝最終更新 payload → updating → success
```

| 契約點 | 規格 |
|--------|------|
| 傳入 | 欄位級衝突清單（原值、新值），由 BookSupplementPage 自 targetBook 與選定候選組裝 |
| 回傳 | 欄位級選擇結果（每欄採原值或新值），透過 callback 回傳 |
| 後續 | BookSupplementPage 接收後進入 updating，完成寫入 → success |

---

## 6. Widget Key 命名表（11 Key，逐一對照流程段）

> **強制**：以下 Key 字面必須與 `test/integration/uc04_to_uc08_integration_tests.dart` 完全一致。

| # | Widget Key | 流程段（§wireframe） | 對應狀態 | 測試行 | 元件類型 |
|---|-----------|---------------------|---------|--------|---------|
| 1 | `supplement_info_button` | 入口（書庫卡片右上角） | — → idle | 161 | IconButton |
| 2 | `search_keyword_field` | 搜尋確認頁（§3.1） | idle/validating | 166 | TextField |
| 3 | `start_search_button` | 搜尋確認頁（§3.1） | idle → searching | 169 | Button（AppButton） |
| 4 | `search_result_card_0` | 候選清單（§3.2） | candidatesLoaded | 182 | Card（index 0） |
| 5 | `select_book_button_0` | 候選卡片內（§3.2） | candidatesLoaded → previewing | 187 | Button（index 0） |
| 6 | `confirm_update_button` | 更新預覽（§3.4） | previewing → updating | 196 | Button |
| 7 | `search_tips_button` | 短書名警告（§3.1 分支） | validating | 302 | Button |
| 8 | `add_author_to_search` | 短書名警告（§3.1 分支） | validating | 303 | Button |
| 9 | `adjust_search_keywords` | 無結果頁（§3.3） | error（空結果） | 350 | Button |
| 10 | `manual_edit_info` | 無結果頁（§3.3） | error（空結果） | 351 | Button |
| 11 | `try_later_option` | 無結果頁（§3.3） | error（空結果） | 352 | Button |

**不在本頁 11 Key 範圍**（歸屬說明）：

| Key | 歸屬 | 理由 |
|-----|------|------|
| `navigation_library` | 全 app 導航 | 跨 UC，非 UC-04 專屬（SA 審查不在範圍） |
| `conflict_comparison_table` | ConflictResolutionWidget（W8-026.4） | 衝突 widget 內部 |
| `field_level_selection` / `select_new_title` / `keep_original_author` / `confirm_selective_update` | ConflictResolutionWidget（W8-026.4） | 衝突 widget 內部欄位級操作 |

**索引化 Key 規則（候選清單）**：`search_result_card_{i}` 與 `select_book_button_{i}` 中 `{i}` 為候選 index（0-based）。測試僅斷言 index 0；實作須對 candidatesLoaded 清單每項套用 `_{i}` 後綴。

---

## 7. 文案契約（測試斷言字面，須完全一致）

| 流程段 | 文案 | 測試斷言方式 | 測試行 |
|--------|------|-------------|--------|
| 搜尋確認 | `將搜尋：《原子習慣》` | text（書名為變數，固定句型「將搜尋：《{title}》」） | 165 |
| 候選清單 | `搜尋結果` | text | 181 |
| 候選相似度 | `相似度: 95%` | textContaining（百分比為變數） | 184 |
| 更新預覽 | `資訊更新預覽` | text | 191 |
| 完成 | `書籍資訊已更新` | text | 199 |
| 短書名警告 | `書名過短可能影響搜尋精度` | textContaining | 301 |
| 無結果 | `找不到相關書籍，正在嘗試其他搜尋策略...` | text | 343 |
| 衝突標題 | `發現資訊衝突` | text（本頁提供） | 395 |

---

## 8. 驗收標準（供 Phase 2 sage-test-architect）

- [ ] BookSupplementPage 渲染後，依狀態流轉可達 §3.1~§3.6 各頁
- [ ] 11 個 widget Key 字面與 uc04_to_uc08 測試完全一致，且各掛在正確流程段
- [ ] 索引化 Key（`search_result_card_{i}` / `select_book_button_{i}`）對候選清單每項生成
- [ ] 沿用 search_book_view_model / search_providers，無平行 VM/Provider
- [ ] 衝突分支正確宿主 ConflictResolutionWidget，依 §5 契約傳入/回傳資料
- [ ] §7 文案字面與測試斷言一致

---

## 9. 與其他 spec 的邊界

| Spec / Ticket | 關係 |
|---------------|------|
| `docs/spec/search/keyword-search-enrichment.md` | 共用 search domain；本頁為補充流程 UI |
| BatchSupplementPage（W8-026.3） | 平行頁面（批次），共用 batch_enrich_view_model |
| ConflictResolutionWidget（W8-026.4） | 本頁宿主之；本 spec 只定義邊界契約（§5） |
| uc04_to_uc08 E2E（P2-4） | UI 存在後重寫為單頁 pump |

## 相關文件

> Domain bundle 界定見 [`domain-map.md`](domain-map.md) §3 / §7。
