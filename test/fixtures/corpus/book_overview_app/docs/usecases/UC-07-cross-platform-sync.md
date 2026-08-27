---
id: UC-07
title: "跨平台資料同步準備"
status: approved
created: "2025-09-19"
updated: "2026-07-26"
primary_actor: "使用者"
platform: "app"
---

# UC-07: 跨平台資料同步準備

## 基本資訊
- **用例ID**: UC-07
- **用例名稱**: 準備跨裝置資料同步機制
- **主要行為者**: 系統（自動）
- **利益關係人**: 使用者（未來獲得多裝置同步）
- **前置條件**: 本地資料庫已建立且包含書籍和借閱資料
- **成功保證**: 資料同步準備就緒，包含借閱記錄同步

## 主要成功場景

1. **資料同步狀態管理**
   - 每本書籍記錄同步狀態：`local`, `synced`, `conflict`
   - 自動維護時間戳：`created_at`, `updated_at`, `last_sync_at`
   - 追蹤本地變更，標記需要同步的記錄

2. **增量變更追蹤**
   - 資料庫觸發器自動更新`updated_at`
   - 識別自上次同步後的變更記錄
   - 生成變更摘要供同步使用

3. **衝突預防機制**
   - 本地優先策略：離線變更優先於雲端
   - 時間戳比較確定數據新舊
   - 為複雜衝突預留手動解決介面

4. **同步準備檢查**
   - 系統定期檢查資料一致性
   - 驗證關鍵欄位完整性
   - 預先標記可能的同步問題

## 設計考量

**資料一致性保證**
- 使用UUID作為跨裝置唯一識別
- 保留原始Chrome Extension的ID映射
- 變更日誌記錄所有修改操作

**網路適應性**
- 支援間歇性網路連接
- 批次同步減少API呼叫
- 智慧重試機制處理網路失敗

**隱私和安全**
- 本地資料加密存儲
- 為未來端到端加密預留架構
- 使用者可控制同步範圍和頻率

## 未來擴展準備

**雲端同步API介面設計**
```text
POST /api/sync/books
GET /api/sync/books?since={timestamp}
PUT /api/sync/books/{id}
```

**衝突解決策略**
- Last-Write-Wins（簡單場景）
- User-Choose（複雜場景）
- Field-Level-Merge（進階功能）

## 替代流程

**7a. 本地資料不一致**
- 7a1. 系統在準備同步時發現資料不一致（觸發 DATA_ERROR，嚴重程度 SEVERE）
- 7a2. **完整性檢查機制**：
  - 驗證關鍵欄位的邏輯一致性（如借閱狀態與日期）
  - 檢查外鍵約束和關聯資料完整性
  - 識別孤立記錄或重複資料
- 7a3. **自動修復策略**：
  - 嘗試從備份或歷史記錄重建缺失資料
  - 使用啟發式規則修復明顯的邏輯錯誤
  - 標記無法自動修復的問題記錄
- 7a4. **使用者介入**：對於無法自動修復的問題，提供詳細的錯誤報告和建議修復方案
- 7a5. **預防機制**：強化資料驗證規則，防止未來出現類似不一致問題

**7b. 同步狀態衝突**
- 7b1. 多個裝置同時修改同一記錄（觸發 DATA_ERROR，嚴重程度 MODERATE）
- 7b2. **衝突偵測算法**：
  - 比較時間戳確定修改順序
  - 分析變更內容的重疊程度
  - 評估衝突的嚴重性和影響範圍
- 7b3. **智慧合併策略**：
  - 非衝突欄位：自動合併最新變更
  - 輕微衝突：使用預設規則（如最新優先）
  - 重大衝突：保留所有版本，等待使用者決策
- 7b4. **衝突解決介面**：提供視覺化的版本比較和選擇工具
- 7b5. **學習機制**：記錄使用者的衝突解決偏好，改善未來自動合併策略

**7c. 網路連接不穩定**
- 7c1. 同步過程中網路中斷或不穩定（觸發 NETWORK_ERROR，嚴重程度 MODERATE）
- 7c2. **斷點續傳機制**：
  - 記錄同步進度，支援從中斷點繼續
  - 使用增量同步減少重複傳輸
  - 實施智慧重試和指數退避策略
- 7c3. **網路狀態監控**：
  - 持續監控網路品質和穩定性
  - 根據網路狀態調整同步策略（批次大小、頻率）
  - 在網路條件改善時自動恢復同步
- 7c4. **離線優先設計**：確保所有功能在離線狀態下正常運作，待網路恢復時自動同步
- 7c5. **使用者通知**：提供清楚的同步狀態指示和預估完成時間

**7d. 儲存空間不足**
- 7d1. 同步資料超過裝置可用空間（觸發 SYSTEM_ERROR，嚴重程度 SEVERE）
- 7d2. **空間需求預估**：
  - 計算同步所需的最小空間
  - 分析可清理的快取和暫存檔案
  - 提供詳細的空間使用分析
- 7d3. **智慧清理機制**：
  - 自動清理過期的快取檔案
  - 壓縮非關鍵資料（如縮略圖）
  - 提供選擇性同步選項（僅同步重要資料）
- 7d4. **使用者引導**：提供具體的空間清理建議和操作指引
- 7d5. **降級方案**：當空間嚴重不足時，提供最小化同步選項保持核心功能

**7e. 同步服務不可用**
- 7e1. 雲端同步服務暫時無法使用（觸發 NETWORK_ERROR，嚴重程度 MODERATE）
- 7e2. **服務狀態監控**：
  - 定期檢測同步服務的可用性
  - 區分暫時性故障和長期維護
  - 記錄服務中斷的模式和頻率
- 7e3. **優雅降級**：
  - 繼續本地功能的正常運作
  - 將待同步變更加入本地佇列
  - 提供明確的服務狀態說明
- 7e4. **自動恢復**：服務恢復後自動重新啟動同步程序
- 7e5. **備用策略**：在長期服務中斷時，提供手動匯出入選項作為暫時解決方案

**7f. QR 離線同步（v1.1.0 新增，PROP-014）**

零網路依賴的跨裝置快速同步。Web 端螢幕顯示 QR 動畫，App 端相機掃描接收。

- 7f1. **Web→App 同步（QR 動畫掃描）**
  - 使用者在 Chrome Extension Popup 點擊「同步到 App」
  - Extension 將書庫 JSON（含 sync_meta）gzip 壓縮 → 依 SPEC-017 frame 格式切塊
  - 每塊前置 15 bytes header（magic 0x5152 / version / total_frames / frame_index / total_size / crc32）
  - Canvas 繪製 QR Code 動畫輪播（~8fps，無限循環）
  - App 使用者點擊「從 Web 掃描同步」→ 開啟 mobile_scanner streaming 模式
  - 逐幀解碼 → magic 驗證 → CRC32 一致性確認 → frame_index 去重累積
  - 進度 UI 顯示「已收到 M / N 幀」
  - 收齊所有幀 → 拼接 payload → CRC32 校驗 → gzip 解壓 → JSON parse
  - 智慧合併（SPEC-008 FR-3：updatedAt last-write-wins）→ 顯示匯入結果

- 7f2. **App→Web 同步（JSON 匯出/匯入）**
  - App 匯出書庫 JSON（含 sync_meta：exported_at / source_app / book_count）
  - 透過分享或檔案傳輸傳到電腦
  - Chrome Extension 匯入 JSON → 智慧合併

- 7f3. **防舊蓋新機制**
  - 接收端比較 sync_meta.exported_at 與本機 last_imported_at
  - exported_at 較舊時顯示警告「此份資料較舊」讓使用者確認
  - 書級別新舊判斷仍以每本書的 updatedAt 為準（SPEC-008 FR-3）

- 7f4. **適用場景與限制**
  - 適用：壓縮後 < 100 KB（書庫 500 本約 25 KB 壓縮）
  - 超過 100 KB 建議改用 JSON 匯出/匯入（7f2）
  - QR 與 JSON 匯出/匯入互補：QR = 快速日常同步，JSON = 完整備份/還原

- 7f5. **技術規格引用**
  - Frame 格式：SPEC-017（QR 離線同步 Frame 二進位格式規格 v1）
  - 合併規則：SPEC-008 FR-3（updatedAt last-write-wins）
  - 提案來源：PROP-014（QR Code 動畫離線同步方案）

## 效能考量

### UI 響應性目標（核心指標）

| 效能指標 | 目標值 | 對應設計 |
|---------|--------|---------|
| **UI 響應延遲** | < 100ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **變更追蹤** | < 10ms | Repository 層級優化（待補充） |
| **狀態更新** | < 100ms | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |
| **滾動流暢度** | 60 FPS | [v0.12-A.2-viewmodel-methodology.md](./work-logs/v0.12-A.2-viewmodel-methodology.md) |

### 處理效能目標（次要指標）

| 效能指標 | 參考值 | 對應設計 |
|---------|--------|---------|
| **衝突檢測** | < 100ms | 同步機制設計（待補充） |
| **增量同步** | ~5秒/100筆（視網路狀況） | 同步機制設計（待補充） |
| **變更佇列處理** | < 50ms | Repository 層級優化（待補充） |

### 關鍵效能點

**變更追蹤效能**:
- 資料庫觸發器自動處理時間戳和變更標記
- 避免每次變更都執行應用層邏輯
- 目標：< 10ms 不影響正常資料操作

**衝突檢測效能**:
- 欄位級別的時間戳比對
- 只比對變更的欄位而非全部欄位
- 使用差異演算法加速檢測
- 目標：< 100ms 完成衝突分析

**增量同步效能**:
- 只同步有變更的資料
- 批次處理降低網路開銷
- 背景執行不阻塞 UI
- 參考值：100 筆變更約 5 秒（視網路狀況）

### 效能監控

```dart
group('UC-07 同步準備效能', () {
  test('變更追蹤 < 10ms', () async {
    final stopwatch = Stopwatch()..start();

    await repository.updateBook(book.copyWith(title: 'New Title'));

    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(10));
  });

  test('衝突檢測 < 100ms', () async {
    final stopwatch = Stopwatch()..start();

    final conflicts = await syncService.detectConflicts(localBook, remoteBook);

    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
});
```
