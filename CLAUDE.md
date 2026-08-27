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

**已補完的原待決項**：schema 消費方式定為讀 `tracking_schema.json`（PROP-002）；
security-scoped bookmark 實作已移除（PROP-001）；狀態管理定為 Riverpod、
矩陣渲染委派 `two_dimensional_scrollables`、持久化為路徑字串
（`docs/tech-decisions.md` 的補記段「2026-08-26：Stage 4 技術維度定案」；
注意該檔另有一個編號不同的 `## 4. 資料來源`，兩者不是同一處）。

**現行待決**（每一項都是版本規劃的前置，見 `docs/domain-map.md` §9）：

- **UC → Ticket 在上游 16 條語意邊中無對應邊**。追溯視圖（UC-04）承諾的
  四層鏈，第三跳沒有資料來源
- **Domain 視圖的列與格無來源**：個別 domain 不是圖節點（`DomainBundle`
  的 carrier 是整份 domain-map.md），`FlowStep` 亦無 `domain` 欄位
- **`tracking_schema.json` 只在框架 v2.41.0 以上存在**。實測四個語料專案
  沒有此檔（本專案已於 2026-08-27 sync-pull 至 2.42.1 取得），
  PROP-002 未涵蓋「檔案不存在」此狀態——SPEC-001 的「無可消費的型別表」
  狀態與 FR-07 已承接畫面行為，但 gate 的下界策略（拒絕／降級）仍待實作定案
- 五項空殼判準：「App 已知範圍」「間接依賴」「破洞分類」「預估耗時」「資源上限」
- 泳道布局演算法（唯一的差異化元件）
- **是否寫執行期 log**：`.claude/rules/core/observability-rules.md` 要求
  啟動／異常／關閉 log，`docs/tech-decisions.md` Stage 5 明示不寫，兩者衝突
- 編輯能力與 git 邊層級歷史已定案但未落為提案與規格
- 0.1 之後的版號規則與 wave 切法

---

## 7. 專案文件

### 任務追蹤

| 文件 | 用途 |
|------|------|
| `docs/todolist.yaml` | 結構化版本索引（Source of Truth） |
| `docs/work-logs/` | 版本工作日誌 |
| `CHANGELOG.md` | 版本變更記錄（**尚未建立**） |
| `docs/work-logs/v{version}/tickets/` | Ticket 文件 |

### 專案文件

> **與 README.md 的分工**：README 面向人類維護者（環境設定、常用指令、
> 專案結構），本檔面向 AI（行為規範、決策脈絡、規則路由）。目的與格式
> 不同，內容重疊屬正常，**不需要對齊或互相涵蓋**。審查時若被報為
> 「兩份索引不對稱」，那是誤判。

| 文件 | 用途 | 現況 |
|------|------|------|
| `docs/proposals/` | PROP 節點 | PROP-001~004，皆 confirmed |
| `docs/spec/{domain}/` | SPEC 節點 | SPEC-001（ui domain） |
| `docs/domain-map.md` | DomainBundle 節點，8 個 domain 的邊界與依賴 | 已建立 |
| `docs/usecases/` | UC 節點（含結構化 flow 區塊） | UC-01~06，共 39 個 FlowStep |
| `docs/events/{domain}/` | EVT 節點 | 9 個 |
| `docs/app-use-cases.md` | UC 白名單 SSOT（`doc uc verify` 依此驗證） | 已建立 |
| `docs/proposals-tracking.yaml` | 提案索引 | 已建立 |
| `docs/tech-decisions.md` | 設計決策記錄（append-only，以最後的補記為準） | 已建立 |
| `docs/traceability.yaml` | 四軸追溯矩陣（FR → UC 場景 → tests） | **尚未建立** |

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


版本以 `docs/todolist.yaml` 為準，該檔只登記已發生與進行中的版本。
**本專案不預先劃分未來版本**——所有應做的功能先討論清楚並文件化，
再依序安排實作順序。

| 版本 | 內容 | 狀態 |
|------|------|------|
| 0.0.1 Foundation | macOS 桌面基礎架構、FVM 釘選、雙層測試、多語系 | 完成 |
| 0.0.2 Intake | 設計與選型訪談，產出 PROP×4 / SPEC-001 / UC×6 / 8 domain / EVT×9 | 完成 |
| 0.0.3 Toolkit | markdown 渲染、編輯模型、git 變更記錄三項選型 | ticket 全完成 |

發布通路為 **Developer ID + notarization，不上架 Mac App Store**（PROP-001，
能力決策：沙盒下無法執行 doc CLI 亦無法讀取任意資料夾）。

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
