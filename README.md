# graph_project_docs_manager

**把專案文件之間的因果鏈與型別化邊變成可導航、可視覺化的圖。**

使用 claude 框架的專案，其需求以 `PROP → SPEC → UC → Ticket` 的鏈條散落在
數百到數千份 markdown 的 frontmatter 裡。目前要追一條需求長出了什麼、
或反問某段程式碼為何存在，只能靠 grep 與人工追溯。本 App 把那些關係讀出來，
畫成可以點的圖。

定位近似 Jira / Asana / Trello，但管理對象不是任務看板，而是文件之間的
型別化關係（上游 schema 定義 7 種節點、16 條邊）。

macOS 桌面應用程式，讀取本機專案資料夾，唯讀為主。目前僅針對 macOS
開發與測試。規格文件見下方〈規格文件〉一節。

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
> flutter --version       # 全域版本，不使用
> fvm flutter --version   # 3.47.1，專案指定
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

## 規格文件

程式碼以外的規格全數落在 `docs/`，寫程式前先讀：

| 入口 | 內容 |
|---|---|
| `docs/tech-decisions.md` | 設計決策記錄（append-only，**以最後的補記為準**） |
| `docs/domain-map.md` | 8 個 domain 的邊界、依賴方向、容錯策略、待決事項 |
| `docs/proposals/` | PROP-001~004：交付形態、schema 消費、資料來源、展示介面 |
| `docs/spec/ui/SPEC-001-*.md` | 六個畫面加浮層的狀態矩陣與 FR-01~06 |
| `docs/usecases/` | UC-01~06，含結構化 flow 區塊 |
| `docs/events/` | 9 個 EVT 節點 |
| `design/` | 設計畫布：9 個 artboard 與產生器 |

## 專案結構

```
lib/
├── main.dart                       App 進入點、ScreenUtil 設定、首頁
├── l10n/                           多語系（.arb 原始檔 + 生成的 .dart）
└── workspace/
    └── workspace_repository.dart   工作資料夾的選取、保存、還原

macos/Runner/
├── MainFlutterWindow.swift         視窗尺寸下限與預設尺寸
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
- 工作資料夾的三種狀態（未設定／可用／不可用）皆能渲染且不溢位

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
| `/bin/echo` | 可 | 可 |
| `/usr/bin/python3` | 不可 —— `xcrun: error: cannot be used within an App Sandbox.` | 可 —— Python 3.9.6 |
| 使用者安裝的 `uv` | 不可 —— `ProcessException: Operation not permitted` | 可 —— uv 0.8.13 |
| 讀取任意專案資料夾 | 需 security-scoped bookmark | 可 —— 直接可讀 |

另有 App Store 審查指南 2.5.2 的獨立阻擋：app 須自包含，不得執行改變功能的
程式碼（明文含 Python 等直譯式語言）。doc CLI 位於使用者選取的資料夾內，
即使打包直譯器仍踩線。

### entitlements

| 權限 | Debug | Release | 用途 |
|---|:---:|:---:|---|
| `app-sandbox` | `false` | `false` | 明確關閉，契約測試守著不被重新打開 |
| `cs.allow-jit` | 是 | — | Dart VM JIT（Hardened Runtime 下必要） |
| `network.server` | 是 | — | hot reload / VM service |

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

新增語系的流程：

1. 於 `lib/l10n/` 加入 `app_<code>.arb`
2. `fvm flutter gen-l10n`

`supportedLocales` 讀的是 `AppLocalizations.supportedLocales`
（`lib/main.dart`），那是生成產物——**不重跑第 2 步，新語系不會出現**。

### 未來支援簡體中文

新增 `app_zh_Hans.arb`。屆時 `zh` 仍作為繁中的 fallback。
