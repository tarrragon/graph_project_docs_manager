---
id: UC-01
title: "匯入Chrome Extension書庫資料"
status: approved
created: "2025-09-19"
updated: "2025-12-29"
primary_actor: "使用者"
platform: "app"
---

# UC-01: 匯入Chrome Extension書庫資料

## 基本資訊
- **用例ID**: UC-01
- **用例名稱**: 匯入Chrome Extension書庫資料
- **主要行為者**: 使用者
- **利益關係人**: 使用者（獲得統一書庫管理）
- **前置條件**:
  - 使用者已安裝APP版書庫管理系統
  - 使用者擁有Chrome Extension匯出的JSON檔案
- **成功保證**: 所有書籍立即可在簡潔模式書庫中瀏覽，使用者可選擇手動補充詳細資訊（v0.12.7 調整）

## 主要成功場景

1. **選擇檔案**
   - 使用者點擊「匯入資料」按鈕
   - 系統開啟檔案選擇器
   - 使用者選擇JSON檔案並確認

2. **檔案驗證與立即匯入**
   - 系統讀取並驗證JSON檔案格式
   - 檢查必要欄位：id, title, cover
   - **批量寫入資料庫**：
     - 使用 `BookRepository.saveBatch()` 批量插入書籍
     - 設定 `source_type` 為 `digital`
     - 設定 `platform_id` 為 Readmoo
     - 在資料庫事務中執行，確保完整性
     - 失敗時自動回滾，不會部分寫入
   - 顯示匯入成功訊息：「成功匯入 X 本書籍」

3. **進入簡潔模式書庫（v0.12.7 調整）**
   - 自動跳轉到簡潔模式書庫檢視
   - 顯示：封面、書名、Readmoo平台圖標
   - **v0.12.7 變更**: 移除自動背景補充機制
   - 使用者可立即開始瀏覽，選擇是否補充詳細資訊

4. **書庫列表項目選擇互動（v0.12.7 新增）**
   - **視覺回饋設計**（方案C-1基礎版）：
     - **未選擇狀態**：凸起刻痕（標準卡片陰影）
     - **已選擇狀態**：凹陷刻痕（內陰影效果）
     - **過渡動畫**：AnimatedContainer 200ms 平滑過渡
     - **極簡設計**：無背景色變化、無邊框、無選中指示器
   - **互動手勢**：
     - **點擊書籍卡片任意位置**：切換選擇狀態
       - 選擇時：視覺從凸起 → 凹陷，HapticFeedback.selectionClick()
       - 取消時：視覺從凹陷 → 凸起，HapticFeedback.lightImpact()
     - **點擊右下角「詳情」按鈕**：導航到書籍詳情頁面
       - 獨立 IconButton（Icons.info_outline）
       - 位置：卡片右下角（bottom: 8, right: 8）
       - 不觸發選擇狀態切換
   - **批次操作支援**：
     - 可選擇最多 50 本書籍進行批次更新
     - 選擇數量即時顯示（如「已選擇 15 本」）
   - **無障礙支援**：
     - 選擇狀態語音播報（「已選擇」、「已取消選擇」）
     - 詳情按鈕語音標註（「查看書籍詳情」）
     - WCAG AA 顏色對比度標準

5. **手動更新書籍資訊（v0.12.7 新增）**
   - **單本更新**：
     - 使用者點擊書籍右上角「更新資訊」按鈕
     - 系統檢查 `api_enriched` 欄位避免重複查詢
     - 透過 ApiRequestQueue 控制頻率（每秒最多 5 個請求）
     - 補充作者、出版社、ISBN、描述等詳細資訊
     - 更新封面圖片URL（如果Google Books有更高解析度版本）
     - 完成後標記 `api_enriched = 1`
   - **批次更新**：
     - 透過步驟4的多選機制選擇書籍
     - 點擊「批次更新」按鈕
     - 系統透過 BookEnrichmentService 處理：
       - 顯示進度回饋（X/50 本已完成）
       - 自動跳過已更新過的書籍
       - 透過 ApiRequestQueue 控制頻率
       - 完成後顯示統計：「已更新 X 本，跳過 Y 本」

## 替代流程

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

## 特殊需求
- **相容性**: 100%相容Chrome Extension v0.9.x匯出格式
- **錯誤恢復**: 支援匯入失敗自動回滾

## 效能考量

### UI 響應性目標（核心指標）

| 效能指標 | 目標值 | 對應設計 |
|---------|--------|---------|
| **UI 響應延遲** | < 100ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **滾動流暢度** | 60 FPS | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **主執行緒阻塞** | < 16ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **進度更新頻率** | 100-200ms | [v0.12.3-api-enrichment-preparation.md](./work-logs/v0.12.3-api-enrichment-preparation.md) |

### 處理效能目標（次要指標）

| 效能指標 | 參考值 | 對應設計 |
|---------|--------|---------|
| **單批次處理** | < 1秒/10本書 | [v0.12.2-service-refactor.md](./work-logs/v0.12.2-service-refactor.md) |
| **JSON 解析** | < 1 秒 | [v0.12.1-domain-interfaces.md](./work-logs/v0.12.1-domain-interfaces.md) |
| **1000本書籍總時間** | ~2分鐘（視網路狀況） | [v0.12.0-main.md](./work-logs/v0.12.0-main.md) |
| **API 併發控制** | 5 requests/second | [v0.11.7-rate-limiting.md](./work-logs/v0.11.7-rate-limiting.md) |
| **記憶體峰值** | < 50MB (Infrastructure) | [v0.11.0-main.md](./work-logs/v0.11.0-main.md) |

### 關鍵效能點

**批次處理效能** (步驟 2):
- **瓶頸識別**: 單筆插入效率低，1000 本書可能超過 30 秒
- **優化策略**:
  - 使用 `BookRepository.saveBatch()` 批次插入
  - 批次大小 100-500 本
  - 資料庫事務優化
- **預期效果**: 總時間縮短至 < 10 秒

**JSON 解析效能** (步驟 2):
- **瓶頸識別**: 大檔案 (1000 本書 > 5MB) 解析可能阻塞 UI
- **優化策略**: 使用 Isolate 異步解析
- **預期效果**: 解析時間 < 1 秒，不阻塞 UI

**異步 API 補充** (步驟 3):
- **瓶頸識別**: Google Books API 速率限制（1000 請求/100 秒）
- **優化策略**:
  - Request Queue + 速率控制（10 請求/秒）
  - 本地快取機制（命中率 > 60%）
  - 優先級排序
- **預期效果**: 不阻塞 UI，背景補充 1000 本約 200 秒

### 效能監控

```dart
// 效能測試範例
testWidgets('1000 本書籍匯入 < 10 秒', (tester) async {
  final stopwatch = Stopwatch()..start();

  await importService.importFromJson(json1000Books);

  stopwatch.stop();
  expect(stopwatch.elapsedSeconds, lessThan(10));
});
```
