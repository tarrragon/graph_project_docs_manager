# CLAUDE.md

本文件為 Claude Code 在此專案中的開發指導規範。

---

## 0. Behavioral Core Principle

This Claude framework passes information through the ticket system. The reader of any
output or conversation is not necessarily a human — it is often the next session or
another agent. Therefore:

- Do not apologize, praise, encourage, or re-confirm information that is already known.
- When writing code or documentation, do not make assumptions beyond the task at hand.
- If something needs further analysis or adjustment, open a ticket and hand it to the
  next session or agent instead of expanding the current scope.
- Avoid reasoning or complexity that exceeds what the ticket requires.

---

## 1. 專案身份

**專案名稱**: graph_project_docs_manager（專案文件流）

**專案目標**: 專案文件的管理與視覺化。定位近似 Jira / Asana / Trello，
但管理對象不是任務看板，而是文件之間的**因果鏈與型別化邊**
（`PROP → SPEC → UC → Ticket`）。核心價值在於把目前散落於 markdown
frontmatter、只能靠 grep 與人工追溯的關係顯性化、可導航、可視覺化。

**專案類型**: Flutter（macOS 桌面應用程式）

| 項目 | 值 |
|------|------|
| **語言** | Flutter 3.47.1 / Dart 3.13.1（由 FVM 釘選，見 `.fvmrc`） |
| **實作代理人** | parsley-flutter-developer |
| **識別特徵** | `pubspec.yaml`、`.fvmrc` |
| **目標平台** | macOS 12.0+（前期僅此平台；ios/android/linux/windows 目錄保留未啟用） |
| **發布通路** | Developer ID + notarization，**不上架 Mac App Store** |

**啟用的 MCP/Plugin**:

- codegraph - 程式碼知識圖譜
- serena - 語意程式碼操作
- context7 - 套件文件查詢
- github - repo 操作
- zhtw-mcp - 繁體中文用字檢查

---

## 2. 核心價值

@.claude/rules/core/quality-baseline.md

---

## 3. 規則系統

@.claude/rules/README.md

---

## 4. Skill 指令

可用 skill 由平台在 session 啟動時列出（含名稱與用途描述）。專案自訂的指令對照表與分類見 `.claude/pm-rules/skill-index.md`，需要依分類查找或確認某指令是否存在時 Read。

---

## 5. 方法論參考

方法論索引見 `.claude/pm-rules/methodology-index.md`（按需 Read）。該檔為查表用途——尋找特定主題的方法論、或確認某方法論是否已存在時才需讀取，非每回合必需。

---

## 6. 技術選型與架構決策

已定案項目（v0.1.0 基礎架構）：

| 面向 | 選擇 | 理由 |
|------|------|------|
| Flutter 版本管理 | FVM 釘選 3.47.1 | 釘具體版號而非 channel，確保跨機器與 CI 行為一致 |
| 尺寸系統 | `flutter_screenutil`，設計基準 1280×800 | 等同預設視窗尺寸，開發時所見即 1:1 |
| 防跑版主力 | macOS `minSize` 960×640 + 約束式佈局 | ScreenUtil 只做等比縮放，**不**阻止 overflow |
| 多語系 | Flutter 官方 ARB，繁中為樣板語系 | 生成產物 `lib/l10n/app_localizations*.dart` 刻意入庫 |
| 檔案存取 | **App Sandbox 關閉** | 開發者工具需執行專案內 doc CLI；實測沙盒下 python3 被 xcrun shim 拒絕、使用者安裝 binary 為 Operation not permitted |
| 測試策略 | 雙層（`test/` 契約 + `integration_test/` 行為） | 內層針對「改錯無編譯期徵兆」的跨語言常數 |

**待決**（由 saas-tech-selection 訪談補完）：

- Dart 端如何消費 `.claude/skills/doc/doc_system/core/tracking_schema.py`
  的圖譜型別常數表。sandbox 關閉後三條路皆可行（呼叫 CLI / 建置期產生
  JSON / Dart 側重建），需在訪談中定案；契約測試的**比對欄位範圍**要
  明寫，整份檔案雜湊會因無關的註解改動而誤報。
- 既有的 security-scoped bookmark 實作（`lib/platform/secure_bookmark.dart`
  與 Swift 端）在非沙盒下已非必要，待決定移除或保留。
- 狀態管理方案、圖譜渲染方案、資料持久化方案。

---

## 7. 專案文件

### 任務追蹤

| 文件 | 用途 |
|------|------|
| `docs/todolist.yaml` | 結構化版本索引（Source of Truth） |
| `docs/work-logs/` | 版本工作日誌 |
| `CHANGELOG.md` | 版本變更記錄 |
| `docs/work-logs/v{version}/tickets/` | Ticket 文件 |

### 專案文件

> 目前 `docs/` 尚未建立。以下為 saas-tech-selection 訪談後預期產出的結構。

| 文件 | 用途 |
|------|------|
| `docs/proposals/` | PROP 節點 |
| `docs/spec/{domain}/` | SPEC 節點與 domain-map |
| `docs/usecases/` | UC 節點（含結構化 flow 區塊） |
| `docs/events/{domain}/` | EVT 節點 |
| `docs/traceability.yaml` | 四軸追溯矩陣 |

### 上游 schema（唯一權威，禁止另建副本）

`.claude/skills/doc/doc_system/core/tracking_schema.py`
— `GRAPH_NODE_TYPES`（7）、`GRAPH_EDGE_TYPES`（16，established 12 / proposed 4）

三項語意約定：

1. `layer` 是穩定性承諾而非開發進度（`established` 可依賴 / `proposed` 形狀可能變動）。
2. `relatedTo` 語意對稱但儲存單向（`reverse_field: None`），消費端**必須**做
   1-hop symmetric union，只讀單向會漏掉一半的邊。
3. `spawned_tickets` / `children` / `blockedBy` / `relatedTo` 語意不同，
   依 `class` 欄位分層渲染，不可合併。

---

## 8. 里程碑


- **v0.1.0（已完成）**: macOS 桌面基礎架構、FVM 釘選、雙層測試、
  多語系、沙盒權限與 security-scoped bookmark
- v0.2.x: 圖譜 schema 消費層、文件解析與圖譜建構
- v0.3.x: 圖譜視覺化與導航
- v1.0.0: 完整功能，準備上架 Mac App Store

---

*專案入口文件 - 詳細規則請參考 .claude/rules/ 目錄*

<!--
使用說明：
1. 將此範本複製到專案根目錄
2. 重命名為 CLAUDE.md
3. 填入專案特定資訊（標記 <!-- --> 的區塊）
4. Section 2-5 使用 @ 引用自動載入通用規則
5. 只需客製化 Section 1/6/7/8
6. 驗證所有連結有效
-->
