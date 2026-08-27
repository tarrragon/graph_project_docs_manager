---
id: UC-01
title: "匯入 Chrome Extension 書庫資料"
status: approved
source_proposal: PROP-004
created: "2026-03-30"
updated: "2026-03-30"
version: "1.0"

primary_actor: "使用者"
secondary_actors: []

platform: both
extension_status: implemented

related_specs: [SPEC-004, SPEC-002]
related_usecases: [UC-02, UC-05]
ticket_refs: []
---

## UC-01: 匯入Chrome Extension書庫資料

### 基本資訊
- **用例ID**: UC-01
- **用例名稱**: 匯入Chrome Extension書庫資料  
- **主要行為者**: 使用者
- **利益關係人**: 使用者（獲得統一書庫管理）
- **前置條件**: 
  - 使用者已安裝APP版書庫管理系統
  - 使用者擁有Chrome Extension匯出的JSON檔案
- **成功保證**: 所有書籍立即可在簡潔模式書庫中瀏覽，詳細資訊背景補充

### 匯入格式支援 (PROP-007 更新)

系統支援兩種匯入格式，透過自動格式偵測判斷：

| 格式 | 偵測方式 | 說明 |
|------|---------|------|
| Interchange Format v2（tag-based） | 頂層為 Object（含 `version`、`books`、`tag_tree` 等欄位） | PROP-007 新格式，包含 tags 按類別分組和 tag_tree |
| 舊格式（v0.16.x 相容） | 頂層為 Array | Chrome Extension 原始匯出格式，向下相容 |

**格式偵測邏輯**：解析 JSON 後檢查頂層結構——如果是 Object 則視為 v2 格式；如果是 Array 則視為舊格式。

**v2 匯入處理**：
- 讀取 `books` 陣列中的書籍資料
- 依據 `tags` 物件建立 tag 關聯（寫入 `book_tags` 資料表）
- 匯入 `tag_tree` 結構（custom 類別的階層關係）

**舊格式匯入處理**：
- 維持原有匯入邏輯
- 將固定欄位（author, publisher 等）自動轉換為對應的系統 Tag

### 主要成功場景

1. **選擇檔案**
   - 使用者點擊「匯入資料」按鈕
   - 系統開啟檔案選擇器
   - 使用者選擇JSON檔案並確認

2. **檔案驗證與立即匯入**
   - 系統讀取並驗證JSON檔案格式
   - 自動偵測格式版本（v2 Object 或舊版 Array）(PROP-007 更新)
   - 檢查必要欄位：id, title, cover（v2 額外檢查 version 欄位）
   - **立即批量插入資料庫**：設定source_type為`digital`，platform_id為Readmoo
   - v2 格式：同步建立 tag 關聯（book_tags）(PROP-007 更新)
   - 顯示匯入成功訊息：「成功匯入 X 本書籍」

3. **背景資料補充**
   - **異步啟動**：為每本書籍查詢Google Books API
   - 補充作者、出版社、ISBN、描述等詳細資訊
   - 更新封面圖片URL（如果Google Books有更高解析度版本）
   - 使用者在簡潔模式下可看到載入指示器

4. **進入簡潔模式書庫**
   - 自動跳轉到簡潔模式書庫檢視
   - 顯示：封面、書名、Readmoo平台圖標
   - 背景補充資訊時顯示載入動畫
   - 使用者可立即開始瀏覽，無需等待API完成

### 替代流程

**3a. JSON格式錯誤**
- 3a1. 系統偵測到格式不符（觸發 DATA_ERROR 分類）
- 3a2. 自動分析錯誤類型：檔案編碼問題、JSON 語法錯誤、或結構不符合預期
- 3a3. 顯示具體錯誤訊息：「檔案格式不正確，請確認為Chrome Extension匯出的JSON檔案」
- 3a4. **恢復策略**：提供檔案格式檢查工具或示範正確格式
- 3a5. **錯誤學習**：記錄格式錯誤模式以改善未來檔案驗證（參照 UC-08 錯誤學習機制）
- 3a6. 返回檔案選擇步驟，保持使用者資料完整性

**3b. 重複書籍處理**
- 3b1. 系統偵測到重複ID的書籍（觸發 DATA_ERROR 但嚴重程度為 MINOR）
- 3b2. **智慧判斷**：自動分析書籍資訊是否有更新（時間戳、內容完整性）
- 3b3. 詢問使用者處理策略：「跳過重複」、「覆蓋現有」、「合併資訊」、「取消匯入」
- 3b4. 根據使用者選擇執行對應動作，保持資料一致性
- 3b5. **預防性措施**：記錄重複模式，在未來匯入中提前預警

**3c. 匯入中斷**
- 3c1. 使用者點擊取消或APP被中斷（觸發 SYSTEM_ERROR）
- 3c2. **事務完整性保護**：系統立即執行完整回滾操作，確保資料庫一致性
- 3c3. **恢復狀態檢查**：驗證所有已插入的資料完全移除
- 3c4. 顯示「匯入已取消，資料已恢復到原始狀態」訊息
- 3c5. **中斷原因分析**：記錄中斷發生的階段和原因（參照錯誤處理設計的中斷恢復策略）

### 特殊需求
- **效能**: 1000本書籍的匯入時間應少於10秒
- **相容性**: 100%相容Chrome Extension v0.9.x匯出格式
- **錯誤恢復**: 支援匯入失敗自動回滾

---
