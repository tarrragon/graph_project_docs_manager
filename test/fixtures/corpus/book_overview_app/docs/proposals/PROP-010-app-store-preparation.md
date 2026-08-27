---
id: PROP-010
title: App 上架準備與 CI/CD 部署提案
status: confirmed
evaluation_level: standard
created: "2026-06-24"
---

# PROP-010: App 上架準備與 CI/CD 部署提案

## 基本資訊

| 項目 | 值 |
|------|------|
| 提案 ID | PROP-010 |
| 狀態 | draft |
| 優先級 | P1 |
| 建立日期 | 2026-06-24 |
| 關聯 UC | 全部（上架影響所有功能的交付） |
| 前置完成 | v1.0.0 功能完成 |

---

## 1. 背景

Book Overview App 目前版本為 0.36.0，目標在 v1.0.0 完成核心功能後上架 Apple App Store 和 Google Play Store。上架涉及兩大面向：

1. **商店準備**：非技術性工作（品牌、截圖、文案、政策）
2. **CI/CD 部署**：自動化建置和推送到兩大商店

兩者需同步規劃，避免功能完成後卡在上架流程。

---

## 2. 商店準備

### 2.1 App 品牌與視覺

| 項目 | 說明 | 決策狀態 |
|------|------|---------|
| App Icon | 需設計符合 Apple/Google 規範的 icon（1024x1024 母版） | 待決定 |
| App 名稱 | 商店顯示名稱（中/英文） | 待決定 |
| 品牌色系 | 已有 Design Token 或需重新定義 | 待確認 |

### 2.2 商店截圖與描述

| 平台 | 截圖需求 | 說明 |
|------|---------|------|
| iOS | 6.7" (iPhone 15 Pro Max) + 6.1" (iPhone 15 Pro) | 必要尺寸，最多 10 張 |
| iOS (iPad) | 12.9" iPad Pro | 若支援 iPad |
| Android | 手機 + 7" 平板 + 10" 平板 | Phone 必要，平板建議 |

| 文案項目 | 長度限制 | 說明 |
|---------|---------|------|
| 副標題 (iOS) / 簡短說明 (Android) | 30 / 80 字元 | 商店列表中顯示 |
| 完整描述 | 4000 字元 | 功能介紹、使用情境 |
| 關鍵字 (iOS) | 100 字元 | SEO 用途 |
| 類別 | - | Books / Productivity |

### 2.3 隱私政策

| 考量 | 說明 |
|------|------|
| 資料收集 | App 收集哪些使用者資料？ |
| 資料儲存 | 本地 vs 雲端（Google Drive Sync 涉及） |
| 第三方服務 | ISBN 查詢 API、Google Drive API |
| 隱私政策頁面 | 需提供公開 URL（兩平台皆要求） |
| App Tracking Transparency (iOS) | 是否使用追蹤功能 |

### 2.4 定價策略

| 選項 | 考量 |
|------|------|
| 免費 | 最大觸及率，後續可加 IAP |
| 付費 | 一次性購買，需定價 |
| 免費 + IAP | 基本功能免費，進階功能付費 |
| 訂閱制 | 適合持續服務（如雲端同步） |

### 2.5 平台需求

| 項目 | iOS | Android |
|------|-----|---------|
| 最低版本 | iOS 16.0（建議） | Android API 24 / Android 7.0（建議） |
| 目標版本 | 最新 iOS | 最新 Android API |
| 架構 | arm64 | arm64-v8a, armeabi-v7a |
| 審查時間 | 1-3 天（首次可能更久） | 數小時至數天 |

---

## 3. CI/CD 自動化部署

### 3.1 部署流程概覽

```
git tag v1.0.0
    |
    v
CI 觸發（GitHub Actions）
    |
    +---> Build iOS --> 簽章 --> 上傳 TestFlight --> App Store Connect
    |
    +---> Build Android --> 簽章 --> 上傳 Google Play Console (Internal Track)
```

### 3.2 技術選型

| 面向 | 候選方案 | 說明 |
|------|---------|------|
| CI 平台 | GitHub Actions | 已有 repo，免費額度足夠 |
| CI 平台 | Codemagic | Flutter 原生支援，iOS 建置免 macOS runner |
| CI 平台 | Bitrise | Flutter 支援好，UI 友善 |
| iOS 建置 | GitHub Actions + macOS runner | 需 Apple Developer Account |
| iOS 上傳 | Fastlane (deliver) | 業界標準自動化工具 |
| Android 上傳 | Fastlane (supply) | 同上 |
| 版本管理 | pubspec.yaml version | 已有 version-release skill |
| 程式碼簽章 | GitHub Secrets + Fastlane Match (iOS) | 安全管理憑證 |

### 3.3 iOS 部署前置需求

| 需求 | 說明 | 狀態 |
|------|------|------|
| Apple Developer Account | 年費 USD 99 | 待確認 |
| App ID 註冊 | Bundle ID: `com.xxx.bookoverview`（待定） | 待建立 |
| 發布憑證 | Distribution Certificate | 待建立 |
| Provisioning Profile | App Store Distribution | 待建立 |
| App Store Connect App | 建立 App 記錄 | 待建立 |

### 3.4 Android 部署前置需求

| 需求 | 說明 | 狀態 |
|------|------|------|
| Google Play Developer Account | 一次性 USD 25 | 待確認 |
| 簽章金鑰 | Upload Key + Keystore | 待建立 |
| Google Play Console App | 建立 App 記錄 | 待建立 |
| Play App Signing | Google 託管 App Signing Key | 建議啟用 |
| Service Account | CI 自動上傳用 | 待建立 |

### 3.5 CI/CD Pipeline 設計

#### 3.5.1 觸發條件

| 觸發 | 動作 |
|------|------|
| Push to `main` | 跑測試 + 靜態分析（不部署） |
| Tag `v*.*.*` | 完整建置 + 簽章 + 上傳到測試軌道 |
| 手動觸發 | 選擇性部署到正式軌道 |

#### 3.5.2 Pipeline 階段

| 階段 | 說明 |
|------|------|
| 1. Test | `flutter test` + `dart analyze` |
| 2. Build iOS | `flutter build ipa --release` |
| 3. Build Android | `flutter build appbundle --release` |
| 4. Sign | 使用 CI secrets 中的憑證簽章 |
| 5. Upload | Fastlane 上傳到 TestFlight / Internal Track |
| 6. Notify | 通知部署結果（Slack / Email） |

### 3.6 機密管理（API Keys / 憑證）

目前 Google API Key 存在本機端，上架後必須改為 CI/CD 注入，避免洩漏。

| 機密項目 | 目前狀態 | 上架後做法 |
|---------|---------|-----------|
| Google API Key（ISBN 查詢、Drive Sync） | 本機端 | CI/CD Secrets 注入，建置時寫入 |
| Apple 發布憑證 / Provisioning Profile | 不存在 | Fastlane Match + CI Secrets |
| Android Upload Keystore | 不存在 | CI Secrets（base64 編碼儲存） |
| Google Play Service Account JSON | 不存在 | CI Secrets |

**注入機制建議**：

| 方案 | 說明 |
|------|------|
| `--dart-define` | `flutter build --dart-define=GOOGLE_API_KEY=${{ secrets.GOOGLE_API_KEY }}`，編譯時注入，不進 repo |
| `.env` + `flutter_dotenv` | CI 產生 `.env` 檔，runtime 讀取；需 `.gitignore` 排除 |
| `--dart-define-from-file` | Flutter 3.7+ 支援，從 JSON 檔批次注入 |

**建議**：使用 `--dart-define-from-file` 搭配 CI 動態產生的 JSON 檔案，一次注入所有 key，本機開發時使用 `.env.local`（已 gitignore）。

**本機開發流程**：
- 開發者從安全管道（如團隊密碼管理器）取得 API Key
- 放入本地 `.env.local` 或 `dart_defines.json`（已 gitignore）
- CI/CD 從 GitHub Secrets / Codemagic 環境變數注入同一份 key

---

## 4. 決策結果

| 編號 | 決策項目 | 決定 |
|------|---------|------|
| D-1 | App 名稱 | **Book Overview** |
| D-2 | 定價策略 | **免費 + IAP**（基本功能免費，進階功能付費） |
| D-3 | 隱私政策託管 | **GitHub Pages** |
| D-4 | Apple Developer Account | **尚未註冊**，需新建（年費 USD 99） |
| D-5 | Google Play Developer Account | **需重新註冊個人帳戶**（舊帳戶 QI DIAGNOSTICS LIMITED 已於 2024-04-08 關閉，不可復活；需再付 USD 25） |
| D-6 | Bundle ID / Package Name | **`com.tarragonstop.bookoverview`** |
| D-7 | CI 平台 | **GitHub Actions（測試）+ Codemagic（建置/部署）** |
| D-8 | 最低支援 OS 版本 | **iOS 16.0 / Android 7.0 (API 24)**（用戶裝置 Samsung A70 + iPad mini 5 皆在範圍內） |
| D-9 | iPad 支援 | **支援** |
| D-10 | API Key 注入方式 | **`--dart-define-from-file`**（編譯時從 JSON 注入，不進 repo） |

---

## 5. 執行順序

| 階段 | 工作項目 | 前置條件 | 狀態 |
|------|---------|---------|------|
| 1 | 決策確認 D-1 ~ D-10 | 本提案 | 已完成 |
| 2 | 註冊 Apple Developer Account + Google Play 個人帳戶 | 用戶操作 | 待執行 |
| 3 | 建立 App 記錄（App Store Connect + Google Play Console） | 帳號就緒 | 待執行 |
| 4 | API Key 遷移（`--dart-define-from-file` 整合） | 確認現有 Key 位置 | 待執行 |
| 5 | 設計 App Icon + 準備截圖（手機 + iPad） | App 名稱已定 | 待執行 |
| 6 | 撰寫隱私政策（GitHub Pages）+ 商店描述文案 | - | 待執行 |
| 7 | 設定 CI/CD Pipeline（GitHub Actions 測試 + Codemagic 建置） | 帳號 + 憑證就緒 | 待執行 |
| 8 | 內部測試（TestFlight + Google Play Internal Track） | Pipeline 就緒 | 待執行 |
| 9 | Google Play 封閉測試（20 人 x 14 天） | Internal Track 通過 | 待執行 |
| 10 | 正式提交審查 | v1.0.0 功能完成 + 全部素材就緒 | 待執行 |

---

## 6. iPad 佈局適配策略

iPad 版面採用**內容置中 + 兩側留白**策略，不為平板另做獨立佈局。

### 6.1 設計原則

| 原則 | 說明 |
|------|------|
| 統一比例 | 手機和 iPad 使用相同的 UI 元件比例 |
| 內容置中 | 畫面內容居中顯示，不拉伸填滿寬螢幕 |
| 兩側留白 | 超過手機寬度的部分以背景色留白 |
| 最大內容寬度 | 設定 `maxWidth`（建議 600-700dp），超過即留白 |

### 6.2 實作方式

```dart
// 概念範例：ConstrainedBox 限制最大寬度
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600),
    child: actualContent,
  ),
)
```

### 6.3 截圖考量

| 平台 | 截圖處理 |
|------|---------|
| iPhone 截圖 | 直接截取，內容填滿 |
| iPad 截圖 | 截取時內容居中 + 兩側留白，與實際使用體驗一致 |

---

## 7. 風險與考量

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Apple 審查被拒 | 上架延遲 | 提前研讀 App Review Guidelines |
| iOS 憑證管理複雜 | CI/CD 設定困難 | 使用 Fastlane Match 統一管理 |
| 商店截圖製作耗時 | 非技術瓶頸 | 可用 screenshots 自動化工具 |
| 隱私政策不完整 | 審查不通過 | 參考同類 App 範本 |
| Google Play 20 人測試要求 | 正式發布前需 20 人封測 14 天 | 提早安排內測 |

---

## 8. 失敗防護

| 失敗場景 | 偵測方式 | 應對措施 |
|---------|---------|---------|
| Apple 審查拒絕（隱私政策不完整） | 審查結果通知 | 預先參考同類 App 政策範本，確保覆蓋資料收集/儲存/第三方服務 |
| Codemagic 建置失敗（iOS 簽章問題） | CI pipeline 紅燈 | 先在本機驗證 `flutter build ipa` 成功後再設定 CI |
| API Key 洩漏（誤 commit 到 repo） | GitHub secret scanning + `.gitignore` | `dart_defines.json` 加入 `.gitignore`；CI 從 secrets 動態產生 |
| Google Play 封測人數不足 | Console 封測狀態檢查 | 提前 2 個月招募測試者（同事/朋友/社群） |
| iPad 佈局在特定尺寸破版 | Widget 測試 + 實機測試（iPad mini 5） | `ConstrainedBox` maxWidth 搭配 `MediaQuery` 斷點驗證 |

---

## 9. Reality Test

| 檢查項目 | 回答 |
|---------|------|
| 是否有同類 App 成功上架的先例？ | 有，書籍管理類 App（如 Bookly、Handy Library）已在雙平台上架 |
| 用戶是否具備完成此提案的資源？ | 需額外投入：Apple Developer USD 99/年 + Google Play USD 25 一次性 + App Icon 設計 |
| 時程是否合理？ | 帳號註冊 ~1 週、CI/CD 設定 ~2 週、截圖/文案 ~1 週、Google 封測 14 天；總計約 6-8 週（不含功能開發） |
| 最大阻礙是什麼？ | Google Play 20 人封測 14 天的人數門檻；Apple 首次審查的不確定性 |
| 若失敗，退出成本是什麼？ | 金錢成本低（USD 124）；時間成本主要在 CI/CD 設定（可復用於其他專案） |

---

*提案建立日期: 2026-06-24*
*決策完成日期: 2026-06-24*
*狀態: confirmed - 所有決策已確認，待執行*
