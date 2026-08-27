---
id: PROP-011
title: Google Drive 同步技術方案提案
status: rejected
rejected_reason: "Google Drive 是儲存工具而非同步工具，用它模擬同步引擎複雜度過高。決定僅保留 JSON 匯出/匯入（v1.0 已規劃），等有真實需求再考慮自建後端或 BaaS。"
rejected_at: "2026-06-18"
evaluation_level: heavy
created: "2026-06-18"
---

# PROP-011: Google Drive 同步技術方案提案

## 基本資訊

| 項目 | 值 |
|------|------|
| 提案 ID | PROP-011 |
| 狀態 | draft |
| 優先級 | P0 |
| 建立日期 | 2026-06-18 |
| 關聯 UC | UC-07（跨平台同步） |
| 關聯 Spec | SPEC-008（跨平台同步規格） |
| 基礎決策來源 | PROP-007 第 2.2 節 |

---

## 1. 背景與目標

PROP-007 已確定 Google Drive 為 v2.0 的主要同步方式，並做出核心決策（`drive.file` scope、命名資料夾慣例、單一 GCP）。本提案深入展開技術實作方案，提供可直接進入開發的完整藍圖。

**目標**：兩端（Chrome Extension + Flutter App）透過 Google Drive 中的共享 JSON 檔案實現書庫資料同步，使用者每平台只需 OAuth 授權一次，之後全自動。

---

## 2. 架構總覽

```text
+-------------------+        +------------------+        +-------------------+
| Chrome Extension  |        |   Google Drive   |        |   Flutter App     |
|                   |        |                  |        |                   |
| chrome.identity   |------->| BookOverviewSync/|<-------| google_sign_in    |
| getAuthToken()    |        |   manifest.json  |        | googleapis        |
|                   |        |   books.json     |        |                   |
| SyncService       |        |   sync-meta.json |        | SyncService       |
+-------------------+        +------------------+        +-------------------+
```

---

## 3. Google Cloud Project 配置

### 3.1 GCP 專案設定

| 設定項 | 值 | 說明 |
|--------|------|------|
| 專案名稱 | `book-overview-sync` | 單一專案管理兩端 |
| API | Google Drive API | 唯一需啟用的 API |
| OAuth Consent Screen | External | 供所有 Google 帳號使用 |
| Scopes | `https://www.googleapis.com/auth/drive.file` | 最小權限：僅存取 App 建立的檔案 |

### 3.2 OAuth Client 配置

| 平台 | Client 類型 | 需提供 |
|------|------------|--------|
| Chrome Extension | Chrome App | Extension ID |
| Flutter Android | Android | Package name + SHA-1 fingerprint |
| Flutter iOS | iOS | Bundle ID |
| Flutter Web（選用） | Web Application | Redirect URI |

**重要**：所有 Client 屬同一 GCP 專案，`drive.file` scope 下任何 Client 建立的檔案對同專案其他 Client 可見（這是跨平台共享的基礎）。

### 3.3 發布與審查

| 階段 | 使用者限制 | 需要審查 |
|------|-----------|---------|
| Testing | 最多 100 測試帳號 | 否 |
| Production | 無限制 | 是（`drive.file` 為非敏感 scope，審查較快） |

`drive.file` 屬 non-sensitive scope（非 restricted），Google 審查要求：
- 隱私權政策 URL
- App 首頁 URL
- 驗證 domain ownership

---

## 4. OAuth 認證流程

### 4.1 Chrome Extension

```text
使用者點擊「連接 Google Drive」
  → chrome.identity.getAuthToken({ interactive: true })
  → Google OAuth 彈窗（首次需同意 scope）
  → 取得 access_token（Chrome 自動快取和刷新）
  → 完成
```

| 特性 | 說明 |
|------|------|
| Token 管理 | Chrome 內建，自動刷新 |
| 離線支援 | `chrome.identity.getAuthToken()` 在 token 有效期間可離線取得 |
| 登出 | `chrome.identity.removeCachedAuthToken()` |
| 限制 | 無法取得 refresh_token（Chrome 平台限制） |

### 4.2 Flutter App

```text
使用者點擊「連接 Google Drive」
  → GoogleSignIn(scopes: ['drive.file']).signIn()
  → Google OAuth 畫面（首次需同意 scope）
  → 取得 GoogleSignInAccount
  → 從 account.authentication 取得 accessToken
  → 使用 googleapis/drive.v3 操作 Drive
```

| 特性 | 說明 |
|------|------|
| 套件 | `google_sign_in` + `googleapis` |
| Token 刷新 | `GoogleSignIn` 自動處理 |
| 離線 access | 首次可請求 offline access 取得 refresh_token |
| Silent sign-in | `GoogleSignIn.signInSilently()` 自動恢復登入狀態 |

### 4.3 Token 生命週期管理

| 事件 | 處理方式 |
|------|---------|
| Access token 過期（1 小時） | 自動刷新（兩端套件都內建） |
| 使用者撤銷授權 | 偵測 401 → 提示重新授權 |
| Google 帳號切換 | 清除本地 token → 重新 OAuth |
| App 重新安裝 | 重新 OAuth（token 不遷移） |

---

## 5. Drive 資料夾與檔案結構

### 5.1 資料夾慣例

```text
Google Drive (My Drive)/
  └── BookOverviewSync/           ← App 建立，drive.file scope 內
        ├── manifest.json         ← 同步元資料
        ├── books.json            ← 完整書庫資料（canonical JSON 格式）
        └── sync-meta.json        ← 同步狀態追蹤
```

### 5.2 manifest.json

記錄同步系統的基本資訊，兩端都可讀取以確認相容性。

```json
{
  "version": "1.0",
  "format": "book-interchange-v1",
  "created_by": "chrome-extension",
  "created_at": "2026-06-18T12:00:00Z",
  "last_sync": {
    "timestamp": "2026-06-18T14:30:00Z",
    "source": "flutter-app",
    "device_id": "device_abc123"
  }
}
```

### 5.3 books.json

完整書庫資料，遵循 `book-interchange-v1` canonical 格式（SPEC-008 對齊）。

```json
{
  "format_version": "1.0",
  "exported_at": "2026-06-18T14:30:00Z",
  "source_app": "flutter-app",
  "books": [
    {
      "id": "book_1718700000",
      "title": "挪威的森林",
      "tags": { "author": ["村上春樹"], "publisher": ["時報出版"] },
      "updated_at": "2026-06-18T12:00:00Z",
      "_passthrough": {},
      "extensions": {}
    }
  ]
}
```

### 5.4 sync-meta.json

追蹤各端的同步狀態，供增量同步使用（詳細設計見 PROP-012）。

```json
{
  "endpoints": {
    "chrome-extension": {
      "last_sync_at": "2026-06-18T14:00:00Z",
      "device_id": "ext_xyz",
      "book_count": 150
    },
    "flutter-app": {
      "last_sync_at": "2026-06-18T14:30:00Z",
      "device_id": "app_abc",
      "book_count": 155
    }
  },
  "conflicts_pending": 2
}
```

### 5.5 資料夾發現機制

```text
首次同步流程：
  1. 搜尋 Drive 中名為 "BookOverviewSync" 且 mimeType = folder 的資料夾
     → API: files.list(q="name='BookOverviewSync' and mimeType='application/vnd.google-apps.folder'")
  2-a. 找到 → 讀取 manifest.json 確認相容性 → 使用既有資料夾
  2-b. 未找到 → 建立 BookOverviewSync/ → 寫入 manifest.json → 上傳初始 books.json
```

---

## 6. API 操作與配額

### 6.1 核心 API 呼叫

| 操作 | API | 頻率 |
|------|-----|------|
| 搜尋資料夾 | `files.list` | 首次 / 重連時 |
| 建立資料夾 | `files.create` | 首次一次 |
| 上傳 JSON | `files.create` (media) | 每次完整同步 |
| 更新 JSON | `files.update` (media) | 每次增量同步 |
| 下載 JSON | `files.get` (media) | 每次同步讀取 |
| 讀取元資料 | `files.get` | 檢查 modifiedTime |

### 6.2 配額限制

| 限制 | 值 | 影響 |
|------|------|------|
| 每日查詢 | 20,000 次 / 天 / 專案 | 正常使用不會超過（每次同步 ~5 次 API 呼叫） |
| 每 100 秒 | 100 次 / 100 秒 / 使用者 | 批量操作需注意 |
| 檔案大小 | 5 TB | 書庫 JSON 通常 < 10 MB，無需擔心 |
| 上傳速率 | 750 GB / 天 | 無需擔心 |

### 6.3 配額超限處理

| 錯誤碼 | 含義 | 處理 |
|--------|------|------|
| 403 `userRateLimitExceeded` | 使用者級限流 | 指數退避重試（1s → 2s → 4s → 最大 32s） |
| 403 `rateLimitExceeded` | 專案級限流 | 同上 + 通知使用者稍後再試 |
| 429 | Too Many Requests | 同上 |

---

## 7. 錯誤處理

### 7.1 錯誤分類與處理策略

| 錯誤類型 | 範例 | 策略 | 使用者可見 |
|---------|------|------|-----------|
| 網路中斷 | 無網路、DNS 失敗 | 記錄待同步，上線後重試 | 狀態圖示變灰 |
| Token 過期 | 401 Unauthorized | 自動刷新 token | 通常不可見 |
| 授權撤銷 | 401 + invalid_grant | 提示重新授權 | 彈窗「請重新連接 Google Drive」 |
| 配額超限 | 403 / 429 | 指數退避重試 | 超過 3 次重試後通知 |
| 檔案衝突 | 同時寫入 | 讀取最新版本 → 合併 → 重新上傳 | 若需手動解決 → PROP-013 UI |
| 資料夾被刪 | 404 on folder | 重新建立資料夾和檔案 | 通知「已重新建立同步資料夾」 |
| JSON 解析錯誤 | 檔案損壞 | 保留本機版本，上傳覆蓋 | 警告「雲端資料異常，已使用本機版本」|

### 7.2 重試策略

```text
失敗 → 等待 1s → 重試
  → 失敗 → 等待 2s → 重試
    → 失敗 → 等待 4s → 重試
      → 失敗 → 標記為「稍後重試」→ 下次同步時機再嘗試
```

最大重試次數：3 次（單次同步內）。超過後放入離線佇列，等下次觸發。

### 7.3 衝突偵測

利用 Drive API 的 `modifiedTime` 做樂觀鎖：

```text
下載 books.json（記錄 modifiedTime = T1）
  → 本機處理合併
  → 上傳時帶 If-Match: T1
    → 成功（T1 未變）→ 完成
    → 失敗（412 Precondition Failed）→ 有人在此期間修改了
      → 重新下載最新版本 → 重新合併 → 重試上傳
```

---

## 8. 安全性考量

| 面向 | 措施 |
|------|------|
| 傳輸加密 | HTTPS（Google API 強制） |
| 存取控制 | `drive.file` 僅存取 App 建���的檔案 |
| Token 儲存 | Extension: Chrome 內建 / App: Secure Storage |
| 資料隱私 | 資料存在使用者自己的 Drive，App 不接觸 |
| 最小權限 | 不使用 `drive` (全存取) 或 `drive.readonly` |

---

## 9. 待討論事項

| 編號 | 問題 | 選項 | 影響 |
|------|------|------|------|
| D-1 | 同步檔案數量：單一 books.json 或拆分多檔？ | 單一（簡單）/ 拆分（效能） | 大書庫 > 1000 本時上傳時間 |
| D-2 | 是否需要版本歷史（Drive revision）？ | 是（可回復）/ 否（省空間） | 誤操作恢復能力 |
| D-3 | 多裝置同帳號（如兩台手機）如何處理？ | 支援（device_id 區分）/ 不支援 | 複雜度大幅增加 |
| D-4 | 是否需要「同步暫停」功能？ | 是 / 否 | 使用者控制力 |
| D-5 | books.json 壓縮方式？ | 無壓縮 / gzip | 傳輸速度 vs 可讀性 |

---

## 10. 實作路線圖

| 階段 | 內容 | 前置 |
|------|------|------|
| Phase 1 | GCP 設定 + OAuth 整合（兩端） | 無 |
| Phase 2 | 資料夾發現 + 首次完整上傳/下載 | Phase 1 |
| Phase 3 | 合併邏輯（SPEC-008 FR-3 last-write-wins） | Phase 2 |
| Phase 4 | 錯誤處理 + 離線佇列 | Phase 3 |
| Phase 5 | 增量同步（→ PROP-012） | Phase 4 |
| Phase 6 | 衝突解決 UI（→ PROP-013） | Phase 5 |

---

## 11. 評估結論

本提案基於 PROP-007 已確認的架構決策，展開完整的 Google Drive 同步技術方案。核心設計以「簡單可靠」為目標：單一 JSON 檔案、`drive.file` 最小權限、兩端套件原生 OAuth 管理。

**下一步**：
- 用戶確認 D-1 至 D-5 的技術選項
- 確認後可進入 GCP 專案配置和 OAuth 整合開發

---

*提案作者: rosemary-project-manager*
*最後更新: 2026-06-18*
