# graph_project_docs_manager

建立專案管理的文件流。

macOS 桌面應用程式，用於管理本機專案文件。目前僅針對 macOS 開發與測試。

---

## 系統需求

| 項目 | 版本 | 說明 |
|---|---|---|
| Flutter | **3.47.1** (stable) | 由 FVM 釘住，見 `.fvmrc` |
| Dart | 3.13.1 | 隨 Flutter SDK |
| FVM | 4.x | 管理 Flutter 版本，`brew install fvm` |
| Xcode | 26.6 以上 | macOS 建置與簽署 |
| macOS | 12.0 以上 | 部署目標 |

## 環境設定

### 1. 安裝 FVM

```bash
brew install fvm
```

FVM 已收錄於 homebrew-core，不需額外 tap。

### 2. 安裝專案指定的 Flutter 版本

```bash
git clone https://github.com/tarrragon/graph_project_docs_manager.git
cd graph_project_docs_manager
fvm install          # 依 .fvmrc 下載 Flutter 3.47.1
fvm flutter pub get
```

> **重要：所有 Flutter 指令都必須加 `fvm` 前綴。**
>
> 直接執行 `flutter` 會使用系統全域版本，與專案釘住的 3.47.1 不同，
> 可能導致分析結果、建置產物與 CI 不一致。
>
> ```bash
> flutter --version       # ❌ 全域版本
> fvm flutter --version   # ✅ 3.47.1
> ```

### 3. IDE 設定

**VS Code** — `.vscode/settings.json` 已納入版控，開啟專案即生效：

```json
{ "dart.flutterSdkPath": ".fvm/flutter_sdk" }
```

**Android Studio / IntelliJ** — 需手動設定：
`Settings → Languages & Frameworks → Flutter → Flutter SDK path`
指向專案內的 `.fvm/flutter_sdk`。

## 常用指令

```bash
fvm flutter run -d macos            # 啟動 App
fvm flutter analyze                 # 靜態分析
fvm flutter test test/              # 內層測試（快，不需編譯原生）
fvm flutter test integration_test/ -d macos   # 外層測試（需編譯 macOS app）
fvm flutter gen-l10n                # 重新生成多語系程式碼
```

> 執行整合測試時出現 `Failed to foreground app; open returned 1` 屬正常現象，
> 是 macOS 上 integration_test 的已知行為，不影響測試結果。

## 專案結構

```
lib/
├── main.dart                       App 進入點、ScreenUtil 設定、首頁
├── l10n/                           多語系（.arb 原始檔 + 生成的 .dart）
├── platform/
│   └── secure_bookmark.dart        macOS security-scoped bookmark 封裝
└── workspace/
    └── workspace_repository.dart   工作資料夾的選取、保存、還原

macos/Runner/
├── MainFlutterWindow.swift         視窗尺寸設定 + bookmark 原生實作
├── DebugProfile.entitlements       Debug 權限
└── Release.entitlements            Release 權限

test/                               內層測試
integration_test/                   外層測試
```

## 測試策略

採雙層測試：

| 層級 | 位置 | 特性 | 涵蓋範圍 |
|---|---|---|---|
| 內層 | `test/` | 純 Dart，約 0.3 秒 | 跨語言常數契約 |
| 外層 | `integration_test/` | 需編譯 macOS app | 啟動、版面、語系、原生通道 |

**內層**是契約測試，針對「改了不會有編譯錯誤、但會在執行期壞掉」的設定：

- `window_size_contract_test.dart` — Swift 的 `minSize` 與 Dart 的 `kMinWindowSize` 必須一致，否則整合測試涵蓋不到實機可達的最窄視窗。
- `entitlements_contract_test.dart` — 必要權限必須存在。少一項不會有任何編譯期徵兆，但會在打包後炸開。

**外層**驗證 App 實際跑起來的行為：

- 啟動後抵達首頁，且無任何 framework 錯誤
- 四種視窗尺寸下版面不溢位（960×640 / 1280×800 / 1512×982 / 1920×1080）
- 兩種語系下文案正確且不溢位
- 三種工作資料夾狀態下不溢位
- 原生 bookmark 通道已註冊，且可完成建立 → 解析 → 釋放的往返

### 尺寸與版面

使用 `flutter_screenutil` 做等比縮放，設計稿基準 **1280×800**（等同預設視窗尺寸，
開發時所見即 1:1）。

但**防止跑版的主力不是 ScreenUtil**，而是兩件事：

1. macOS 的 `minSize` 設為 960×640，杜絕視窗被拉到任意小。
2. 版面使用 `Expanded` / `Flexible` / `TextOverflow.ellipsis` 等約束式佈局。

ScreenUtil 只負責讓 UI 在不同尺寸下維持比例，它**不會**阻止 overflow。

## macOS 權限與發布

App Sandbox **關閉**。發布通路為 Developer ID 簽署 + notarization，不上架
Mac App Store。

這是能力決策而非偏好：本 App 是框架的配套開發者工具，需要執行專案內的
doc CLI 並讀取使用者指定的任意專案資料夾。實測沙盒下兩者皆不可行 ——

| 目標 | 沙盒開啟 | 沙盒關閉 |
|---|---|---|
| `/bin/echo` | ✅ | ✅ |
| `/usr/bin/python3` | ❌ `xcrun: error: cannot be used within an App Sandbox.` | ✅ Python 3.9.6 |
| 使用者安裝的 `uv` | ❌ `ProcessException: Operation not permitted` | ✅ uv 0.8.13 |
| 讀取任意專案資料夾 | 需 security-scoped bookmark | ✅ 直接可讀 |

另有 App Store 審查指南 2.5.2 的獨立阻擋：app 須自包含，不得執行改變功能的
程式碼（明文含 Python 等直譯式語言）。doc CLI 位於使用者選取的資料夾內，
即使打包直譯器仍踩線。

### entitlements

| 權限 | Debug | Release | 用途 |
|---|:---:|:---:|---|
| `app-sandbox` | `false` | `false` | 明確關閉，契約測試守著不被重新打開 |
| `cs.allow-jit` | ✅ | — | Dart VM JIT（Hardened Runtime 下必要） |
| `network.server` | ✅ | — | hot reload / VM service |

Release 走 AOT 不需 JIT。契約測試 `test/entitlements_contract_test.dart`
斷言 sandbox 維持關閉 —— 一旦被重新開啟，`Process.run` 會靜默失去執行
CLI 的能力，且沒有任何編譯期徵兆。

## 多語系

使用 Flutter 官方 ARB 方案。主語系為繁體中文（`zh`），另有英文（`en`）。

- 原始檔：`lib/l10n/app_zh.arb`（樣板）、`lib/l10n/app_en.arb`
- 生成產物：`lib/l10n/app_localizations*.dart` — **刻意納入版控**，
  clone 後無需先執行生成即可開啟 IDE，語系變更也會出現在 diff 中可供審閱

新增文案的流程：

1. 在 `app_zh.arb` 加入 key 與 `@key` 說明
2. 在 `app_en.arb` 加入對應翻譯
3. `fvm flutter gen-l10n`
4. 於程式碼中使用 `AppLocalizations.of(context).yourKey`

要新增語系時，於 `lib/l10n/` 加入 `app_<code>.arb` 即可，
`supportedLocales` 會自動包含它。

### 未來支援簡體中文

新增 `app_zh_Hans.arb`。屆時 `zh` 仍作為繁中的 fallback。
