---
id: UC-02
title: "匯出書庫資料"
status: approved
created: "2025-09-19"
updated: "2026-07-16"
primary_actor: "使用者"
platform: "app"
---

# UC-02: 匯出書庫資料

## 基本資訊
- **用例ID**: UC-02
- **用例名稱**: 匯出書庫資料為 JSON/CSV 格式
- **主要行為者**: 使用者
- **前置條件**: 書庫中存在至少一本書籍
- **成功保證**: 產生與Chrome Extension相容的JSON檔案，或Excel可開啟的CSV檔案

## 主要成功場景

1. **啟動匯出**
   - 使用者進入「資料管理」頁面
   - 點擊「匯出資料」按鈕
   - 選擇匯出範圍：「全部書籍」或「指定來源」

2. **匯出設定**
   - 選擇匯出格式：JSON（預設）、CSV
   - 設定檔案名稱：「我的書庫_YYYYMMDD.json」或「我的書庫_YYYYMMDD.csv」
   - 選擇儲存位置
   - （CSV格式）選擇匯出欄位（可選）

3. **資料處理**
   - 系統查詢符合條件的書籍
   - 根據選擇的格式進行資料轉換：
     - JSON: 轉換為Chrome Extension相容格式
     - CSV: 轉換為Excel可讀取的表格格式
   - 產生對應格式檔案

4. **完成匯出**
   - 顯示匯出成功訊息
   - 提供「分享檔案」和「查看位置」選項
   - 記錄匯出歷史

## 替代流程

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

**3b. 匯出執行失敗**
- 3b1. 系統在資料處理或檔案寫入階段發生錯誤（觸發 SYSTEM_ERROR，嚴重程度 MODERATE）
- 3b2. **失敗訊息呈現**：顯示匯出失敗訊息，包含失敗原因（如檔案寫入失敗、權限不足、資料驗證失敗）
- 3b3. **殘留清理**：系統嘗試刪除不完整的匯出檔案，避免殘留無效檔案（對應 SPEC-003 BR-7）
- 3b4. **重試路徑**：提供「重試匯出」入口，使用者可直接重新執行匯出，不需重新完成匯出設定
- 3b5. 記錄匯出失敗事件與原因，用於改善匯出穩定性

## 延伸情境

**E1. 使用者從資料管理頁進入加書流程後返回**
- E1-1. 使用者位於「資料管理」頁面，畫面顯示目前的書籍統計與書庫狀態
- E1-2. 使用者由該頁進入新增書籍流程，完成加書後返回「資料管理」頁面
- E1-3. 返回時書籍統計立即反映新增結果（書籍總數、書庫狀態、最後更新時間），不需回首頁再進入即可看到最新資料（對應 SPEC-003 BR-10 衍生統計 reactive 一致性）
- E1-4. 統計更新由底層書庫資料變更自動觸發，不依賴頁面重進或手動刷新（機制依據見 SPEC-003 BR-10 交叉引用之 App-wide 通則）

## 效能考量

### UI 響應性目標（核心指標）

| 效能指標 | 目標值 | 對應設計 |
|---------|--------|---------|
| **UI 響應延遲** | < 100ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **滾動流暢度** | 60 FPS | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **主執行緒阻塞** | < 16ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **進度回饋** | 100-200ms | [v0.12.2-service-refactor.md](./work-logs/v0.12.2-service-refactor.md) |

### 處理效能目標（次要指標）

| 效能指標 | 參考值 | 對應設計 |
|---------|--------|---------|
| **JSON 序列化** | < 2秒/1000本 | [v0.12.1-domain-interfaces.md](./work-logs/v0.12.1-domain-interfaces.md) |
| **檔案寫入** | < 1秒 | [v0.12.2-service-refactor.md](./work-logs/v0.12.2-service-refactor.md) |
| **1000本書籍總時間** | ~3-5秒（視設備效能） | [v0.12.2-service-refactor.md](./work-logs/v0.12.2-service-refactor.md) |
| **記憶體峰值** | < 100MB | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |

### 關鍵效能點

**JSON 序列化效能**:
- 使用 Isolate 異步序列化避免阻塞 UI
- Stream 分批處理降低記憶體占用
- 參考：v0.12.1-domain-interfaces.md - Value Object 序列化效能

**檔案寫入效能**:
- 異步檔案 I/O 操作
- 大檔案（> 5MB）分段寫入
- 參考：v0.12.2-service-refactor.md - Service 層異步處理

**記憶體管理**:
- Stream 分批處理避免完整載入
- 峰值記憶體控制在 100MB 以內
- 參考：v0.12-A.2-viewmodel-methodology.md - 記憶體管理優化

### 效能監控

```dart
testWidgets('匯出操作不阻塞 UI', (tester) async {
  await tester.pumpWidget(ExportPage());

  // 啟動匯出（1000本書）
  await tester.tap(find.byKey(Key('export_button')));
  await tester.pump();

  // 驗證 UI 仍可響應
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // 驗證滾動流暢度
  await tester.drag(find.byType(ListView), Offset(0, -300));
  await tester.pumpAndSettle();

  // 驗證進度更新
  expect(find.textContaining('%'), findsOneWidget);
});
```
