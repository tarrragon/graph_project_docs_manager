---
id: UC-02
title: "匯出書庫資料"
status: approved
source_proposal: PROP-004
created: "2026-03-30"
updated: "2026-03-30"
version: "1.0"

primary_actor: "使用者"
secondary_actors: []

platform: both
extension_status: implemented

related_specs: [SPEC-004]
related_usecases: [UC-01, UC-05]
ticket_refs: []
---

## UC-02: 匯出書庫資料

### 基本資訊
- **用例ID**: UC-02
- **用例名稱**: 匯出書庫資料為JSON格式
- **主要行為者**: 使用者
- **前置條件**: 書庫中存在至少一本書籍
- **成功保證**: 產生與Chrome Extension相容的JSON檔案

### 主要成功場景

1. **啟動匯出**
   - 使用者進入「資料管理」頁面
   - 點擊「匯出資料」按鈕
   - 選擇匯出範圍：「全部書籍」或「指定來源」

2. **匯出設定**
   - 選擇匯出格式：JSON（預設）
   - 設定檔案名稱：「我的書庫_YYYYMMDD.json」
   - 選擇儲存位置

3. **資料處理** (PROP-007 更新)
   - 系統查詢符合條件的書籍
   - 匯出為 **Interchange Format v2**（tag-based 格式）
   - 頂層為 Object，包含 `version`、`exported_at`、`books` 陣列
   - 每本書籍的 `tags` 按類別分組（author、publisher、platform 等 12 類）
   - 包含 `tag_tree`（custom 類別的階層結構）
   - 產生JSON檔案

4. **完成匯出**
   - 顯示匯出成功訊息
   - 提供「分享檔案」和「查看位置」選項
   - 記錄匯出歷史

### 替代流程

**1a. 空書庫**
- 1a1. 系統偵測書庫為空（觸發 DATA_ERROR，嚴重程度 MINOR）
- 1a2. **狀態確認**：額外檢查是否有隱藏或軟刪除的書籍記錄
- 1a3. 顯示提示：「書庫中沒有書籍，無法匯出」
- 1a4. **建設性引導**：提供「匯入資料」快速連結和「開始新增書籍」引導
- 1a5. **使用者體驗考量**：記錄空書庫匯出嘗試，用於改善新使用者引導流程

**3a. 儲存空間不足**
- 3a1. 系統檢測到儲存空間不足（觸發 SYSTEM_ERROR，嚴重程度 MODERATE）
- 3a2. **智慧分析**：計算所需空間大小，與可用空間對比，提供具體數據
- 3a3. **多重解決方案**：
  - 提示使用者清理空間（顯示可清理的快取大小）
  - 建議選擇其他儲存位置（雲端、外部儲存）
  - 提供分批匯出選項（減少單次檔案大小）
- 3a4. **恢復策略**：暫時壓縮匯出格式或移除非必要的中繼資料
- 3a5. 使用者確認後重新執行匯出，並記錄儲存問題發生頻率

---
