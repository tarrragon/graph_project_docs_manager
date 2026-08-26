# 設計決策記錄

本檔為 `saas-tech-selection` 訪談的產出，append-only：中途改變決策時追加補記段，
不回頭改寫既有內容，以保留當時的判斷依據。

**訪談狀態**：Stage 0 定錨完成、Stage 1 操作盤點進行中。
Stage 2（domain / event 切分）、Stage 3（核心問題）、Stage 4（技術維度）、
Stage 5（收斂）尚未執行。

---

## 1. 專案定錨

| 項目 | 值 |
|------|------|
| 產品形態 | 開發者工具（框架配套），非 SaaS |
| 動機 | 解決自己的營運問題：文件關係目前只能靠 grep 與人工追溯 |
| 租戶模型 | 無。本機桌面 app，無後端、無同步 |
| 使用者範圍 | 所有使用此 claude 框架的專案 |
| 團隊 | 一人 |
| 交付形態 gate | **自建成立** —— 產品本身是軟體，且現成平台無對應標準域 |

### 無後端的後果

`state-storage`（資料庫）、`deployment-platform`（部署入口）、多租戶隔離、
`async-queue` 等維度在本專案 **N/A**。資料來源是檔案系統上的 markdown 與 YAML，
多機同步由框架自身的 ticket 系統與 GitHub 承擔，不是本 app 的職責。

---

## 2. 已定技術決策

### 2.1 發布通路：Developer ID + notarization，不上架 Mac App Store

**理由**：能力決策而非偏好。本 App 需執行專案內的 doc CLI 並讀取任意專案資料夾，
沙盒下兩者皆不可行。實測：

| 目標 | 沙盒開啟 | 沙盒關閉 |
|------|---------|---------|
| `/bin/echo` | exit=0 | exit=0 |
| `/usr/bin/python3` | `xcrun: cannot be used within an App Sandbox` | exit=0 |
| 使用者安裝的 `uv` | `ProcessException: Operation not permitted` | exit=0 |
| 讀取任意專案資料夾 | 需 security-scoped bookmark | 直接可讀 |

另有 App Store 審查指南 2.5.2 的獨立阻擋（app 須自包含、不得執行改變功能的
程式碼，明文含直譯式語言）。doc CLI 位於使用者選取的資料夾內，即使打包直譯器仍踩線。

**防護狀態**：`test/entitlements_contract_test.dart` 斷言 sandbox 維持關閉。
**Tripwire**：若未來決定上架 MAS → 回頭重評，屆時 doc CLI 呼叫能力必須放棄。

### 2.2 schema 消費：讀框架隨附的 `tracking_schema.json`

**理由**：版本偏斜。App 會裝在別人機器上、讀他們的 `.claude/`，而該框架版本
不等於編譯 app 時的版本。建置期產生 JSON 會把 schema 烘進 binary，使用者框架
較新時會靜默渲染錯誤的圖 —— 這是下游解不掉的問題（契約測試比對的是 build
當下的兩份，跑不到使用者機器上那一份）。

已由上游實作（ticket `0.2.1-W3-1113`，框架 v2.41.0）：

- `tracking_schema.py` 仍是唯一 SSOT
- `tracking_schema.json` 為衍生產物，隨框架同步，**不可編輯**
- `doc schema export --json` 提供同內容
- 上游測試斷言雙向一致（`.py` 有而 JSON 無、JSON 有而 `.py` 無，兩向皆紅）

**兩個版本欄位讀不同的東西**：

| 判斷 | 來源 |
|------|------|
| 使用者框架版本是否超出 app 已知範圍 | `.claude/VERSION` |
| 這份 schema 上次變動的時點 | JSON 的 `schema_generated_at_framework_version` |

**防護狀態（待實作）**：Dart 側契約測試，須讀磁碟上的 JSON 而非自身模型再序列化
—— 上游第一版測試即因兩端同源而恆綠，突變測試才抓到。
**Tripwire**：`id_pattern` 為 Python `re` 方言，未來若上游加入 lookbehind 或
`\p{}`，失效的是 Dart 側且上游不會有紅燈 → 契約測試須逐一在 Dart `RegExp` 編譯。

### 2.3 工作資料夾：儲存路徑字串

sandbox 關閉後 security-scoped bookmark 已非必要，實作已移除（約 300 行）。
路徑字串會過期（搬移、改名、磁碟未掛載），因此每次取用都實際確認，
不假設存下來就一直有效。

---

## 3. 操作盤點（Stage 1，進行中）

操作主體依開發者工具結構：**開發者 owner**（部署 + 設定 + 使用三角色合一）
與**機器角色**（解析器、檔案監看）。無終端使用者與組織角色分層。

### 3.1 核心場景

需求變更時的雙向穿透：

- **domain → UC**：找出負責的 domain，看有哪些 UC flow 貫穿它
- **UC → domain**：從 UC 頭尾看這條 flow 貫穿哪些 domain

這是需要圖形介面而非文字介面的理由。改功能／加功能／改介面 model 時，
在對應的 SPEC / UC / EVT 對應的測試掛上 ticket，依 BDD / TDD 先開紅燈。

### 3.2 WRAP 決策：不做獨立的 ticket 進入點畫面

**問題**：維護者接到 ticket 後從哪裡開始查程式脈絡？

**反向框架**：反面是「ticket 應該自帶足夠脈絡，讓維護者不需要查」。

**基本率**（flutter_balance 全量 1295 張 ticket 實測）：

| 欄位 | 填寫率 |
|------|--------|
| `where.files` | 99.5% |
| `why` | 99.5% |
| `how.strategy` | 98.1% |
| `acceptance` | 89.8% |
| `source_ticket` | 70.3% |
| `blockedBy` | 18.1% |
| **`where.layer`** | **15.4%** |
| `relatedTo` | 13.4% |

**結論**：「從哪裡開始」在 99.5% 的情況下已由 ticket 的 5W1H 結構回答，
獨立畫面是在解 0.5% 的問題。premortem：該畫面會因「只是把同樣的 YAML
換個字體顯示」而在使用兩次後被棄用。

但資料同時暴露真正的缺口 —— `where.layer` 僅 15.4%。ticket 說「改 `lib/domain`」，
卻沒說那屬於哪個 DDD domain、被哪些 UC flow 貫穿。

**採用方案**：在既有 Domain / UC Flow 視圖上加「以 ticket 切入」模式，
用 `where.files` 反查涵蓋的 domain 並高亮。缺 `layer` 的票顯示為「無法定位」，
該狀態本身即為破洞報告的一項。

### 3.3 畫面清單（草案）

| 畫面 | 回答的問題 |
|------|-----------|
| 專案選擇／切換 | —— |
| Domain 視圖 | 哪些 UC flow 貫穿這個 domain |
| UC Flow 視圖 | 這個 flow 貫穿哪些 domain |
| 追溯視圖 | 需求長出什麼／為什麼存在 |
| Ticket 清單 | 什麼卡住了 |
| 破洞報告 | 哪裡有破洞 |
| 節點詳情 | —— |

### 3.4 Domain 視圖版型：泳道 + 矩陣雙模式

矩陣負責**發現**（domain × UC 交叉表，一眼看完全貌），
泳道負責**理解**（flow 橫向穿過 domain 泳道）。點矩陣格子自動切換到泳道。

兩者是不同的認知任務，用單一視圖同時服務會兩邊都不好。

---

## 4. 資料來源

| 來源 | 用途 | 狀態 |
|------|------|------|
| `docs/` 圖譜節點 frontmatter | PROP / SPEC / UC / EVT / DomainBundle | 納入 |
| `docs/work-logs/**/tickets/*.md` | 進度與狀態 | 納入 |
| `docs/traceability.yaml` | 四軸追溯矩陣，已結構化 | 納入 |
| git 歷史（邊的變更歷史） | 「這條邊何時被加上」 | **延後**，非核心價值 |

外部改動處理：**自動偵測並重新載入**（file watcher）。

### 語料規模

flutter_balance 全量 **1295 張 ticket**（非 190，那是 pending 數）。
另有 book_overview_app、book_overview_v1（框架版本較舊、文件缺欄位）、
monitor、screen_clock（擱置中）可作參考語料。

---

## 5. 待決事項

- Stage 2：domain / event 切分（本 app 自身的領域模型）
- Stage 3：核心問題（需求類型、失敗代價、成本模型）
- Stage 4：技術維度（狀態管理、圖形渲染方案、解析器架構、
  `verification-surface`、`observability` 底線）
- 搜尋與全域導覽是否納入畫面清單
- 圖譜總覽（鳥瞰起手畫面）是否需要

---

## 補記

（決策變更追加於此，不回改上方內容）
