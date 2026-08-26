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

### 2026-08-26：`where.layer` 統計的兩層區別，與定位機制的修正

上方 §3.2 記錄的 `where.layer` 填寫率 15.4% 需要補充。上游獨立複驗後，
該數字須分兩層理解：

| 指標 | 數值 |
|------|------|
| 填寫率（欄位有值） | 99.9% |
| 資訊率（扣除預設佔位字串 `待定義`） | 約 14% |

1164 張有值的票中 996 張是 CLI 的預設佔位字串。上游另查到第三層問題：
該欄位的合法值域僅載於 docstring、無任何強制機制，實際出現 20 種以上變體
（含自創詞、以及與 `--where` 參數錯置而貼入的檔案路徑）。

**修正**：PROP-004 原本同時寫了「以 `where.files` 反查 domain」與
「缺 `layer` 的票顯示為無法定位」，兩句互相矛盾——若定位機制是
`where.files`，`layer` 不參與定位。已修正為明確不使用 `where.layer`，
理由是資訊率不足且值域未受強制。

**撤回的假設**：先前推測 `where.layer` 的低資訊率可能是「刻意留白、
由 domain-map 推導」。上游查證後表示無證據支持——沒有任何地方載明
它是推導而非填寫。該假設撤回。

**新增依賴**：上游 `0.2.1-W3-1115`（ANA）正在評估該欄位的三個處置選項，
其中「廢除欄位改由 `where.files` 對照 domain-map 推導」與本專案採用的
路徑一致。定案前不假設 ticket → domain 這條邊有可靠的上游來源。

### 2026-08-26：框架工具鏈的兩個 bug（已回報上游）

建立提案過程中撞到，根因已定位並回報：

1. **`doc update` 的 status bug**（上游 `0.0.2-W1-002`，已更正根因並升 P1）
   —— 當檔案的 status 已等於目標值時，`re.sub` 產生的結果與原文逐字相同，
   `updated == content` 成立而回傳 `False`，呼叫端將其一律解讀為
   「找不到 status 欄位」並 `sys.exit(1)`。該 exit 發生在同步
   `proposals-tracking.yaml` **之前**，因此索引永遠不會被更新。
   繞過方式：先將檔案 status 改回 `draft`，再執行 update。

2. **`doc create --title` 只寫索引不寫檔案**（上游 `0.2.1-W3-1117`）
   —— 標題寫入 `proposals-tracking.yaml`，但檔案內的兩處範本佔位符
   （frontmatter `title` 與內文標題）未被替換。此 bug 靜默完成，
   不看檔案內容不會察覺。

兩者同屬「索引與檔案分歧」族，且第一個與先前發現的
`dispatch-record-hook.py` 誤報同構——**檢查器只有二元輸出，卻要表達三態**
（欄位不存在 / 值已相同 / 已更新）。

### 2026-08-26：Stage 2 完成，domain map 與 event catalog 落檔

七個 domain（Workspace / Schema / Corpus / Graph / TicketDetail / Layout /
Diagnostics）與九個 event，見 `docs/domain-map.md` 與 `docs/events/`。

三項關鍵切分決策：

1. **不照抄上游 schema 的節點型別。** 那是「被觀察物的結構」，不是本 App
   的責任邊界。照抄會切出 `PropManager` 這類以資料表為單位的偽領域。
   實際依據是變更理由的來源。
2. **Ticket 分兩層。** 1295 張 vs 約 12 個其他節點，差兩個數量級且結構不同。
   Graph 持有輕節點，TicketDetail 持有 5W1H 全文。
3. **Corpus 是唯一的解析者。** 三個消費方各自投影，避免容錯規則分歧。

Commodity check（本專案退化為「用套件 vs 自己寫」）：矩陣委派
`two_dimensional_scrollables`（publisher 為 **flutter.dev** 官方），
泳道自建（產品差異化，且無對應套件——`graphview` 等皆為力導向或樹狀）。

### 2026-08-26：第三個框架工具鏈缺陷（`doc validate-filenames` 對 EVT 誤判）

`doc create event --domain X` 產生的檔名，被 `doc validate-filenames`
判為違規，訊息為「應以 EVT-數字 開頭」。**CLI 產生的檔案被 CLI 自己的
驗證器拒絕。**

四個獨立來源證實驗證器是錯的一方：

| 來源 | 規定 |
|------|------|
| schema `id_pattern` | `^EVT-[A-Z0-9]+-\d{3}$`（要求 DOMAIN 區段） |
| schema `carrier` | `docs/events/{domain}/EVT-{DOMAIN}-NNN-{slug}.md` |
| `event-template.md` | `EVT-{DOMAIN}-{NNN}-{簡短描述}.md` |
| flutter_balance 實際檔案 | `EVT-BALANCE-001-盤點快照已儲存.md` |

根因在 `doc_system/commands/validate.py:279-282`：驗證器套用通用規則
`^{PREFIX}-\d+`，而 EVT 的 ID 格式為 `EVT-{DOMAIN}-{NNN}`，永遠不匹配。

值得注意的是**配號器本身沒有問題** —— 它正確產生了 per-domain 序號
（CORPUS-001/002/003、SCHEMA-001/002），與 flutter_balance 的
BALANCE-001~005 一致。所以「配號器盲區」這個訊息描述的問題並不存在，
盲的是驗證器。

不阻塞：EVT 的 `doc validate` 全部通過（9/9 符合 EVT schema）。
已回報上游。

### 2026-08-26：Stage 3 部分完成，容錯策略經 WRAP 定案

Stage 3 的七個核心問題有一半在本專案退化（無後端、單使用者、本機工具）：

| 問題 | 狀態 |
|------|------|
| 流量形狀 | N/A（本機單使用者） |
| 資料生命週期 | **App 幾乎不擁有任何資料** —— 工作資料夾路徑是唯一真正屬於它的狀態 |
| 安全邊界 | 大幅退化，整個選定資料夾可讀 |
| 失敗代價 | **高度適用，且形態特殊** |

「App 不擁有資料」有兩個後果：消掉備份／遷移／保留政策整個問題族；
但同時劃下硬線——**App 永遠不能是 source of truth，任何快取都純屬最佳化**。
首版唯讀的決定因此比表面上更重要：加入編輯能力等於跨越這條線。

### 失敗代價的 WRAP 分析

**Step 0 判定資料不足**：對「出問題的 case」缺乏實際資料，屬以假設替代資料。
先實測五個框架專案共 7000+ 份文件，再進 W 階段。

**W 階段三類涵蓋與 premortem**：

| 方案 | 類型 | 會怎麼死 |
|------|------|---------|
| 寬容 parser，盡力救 | 新增工具 | 問題被 App 隱藏，130 張壞票永遠沒人發現 |
| 嚴格解析，明確拒絕 | 改造既有 | 10% ticket 消失，App 在最活躍專案上不可用 |
| 要求先修好專案 | 零工具 | 首次開啟看到錯誤而非圖，直接棄用 |

三者皆死，判定框架有誤。使用者提出的反向框架指出方向：
**壞資料是專案的缺陷，App 的職責是讓它被看見，不是修它。**

**R 階段基本率**（實測，非估計）：5648 可解析 / 131 YAML 錯誤 /
366 無 frontmatter（後者含 README 等合法非節點檔）。130 個 YAML 錯誤
全屬同一成因：未閉合的單引號字串。100% 可部分救回，平均 20.3 個欄位。

**採用方案（W 之外的第四項）**：盡力解析 + 損壞依嚴重度分級顯性化 +
破洞報告即修復清單。詳見 `docs/domain-map.md` §7。

**診斷入口不另行設計**——破洞報告即入口。解析失敗與圖結構缺陷本質同類，
分成兩處會讓使用者需要記住兩個入口。

### 上游缺陷（第四項，已回報）

flutter_balance 的 130 張 ticket frontmatter 含未閉合的單引號字串，
斷點總落在 `how.strategy`，導致 YAML 解析失敗。成因在 ticket 寫入端，
非本 App 的解析問題。

### 2026-08-26：Stage 4 技術維度定案

多數維度在本專案退化：

| 維度 | 狀態 |
|------|------|
| state-storage | 退化——唯一持久狀態是工作資料夾路徑字串 |
| deployment-platform | 退化為打包與 notarization（見 PROP-001） |
| security | 退化——本機工具，整個選定資料夾可讀 |
| async-queue | N/A——無跨程序訊息 |
| observability | 已於 Stage 3 定案：破洞報告即診斷入口 |
| cache | **不做**——依視圖惰性載入已足夠，不提前最佳化 |
| capacity-performance | 見下方載入策略 |
| verification-surface | 見下 |

#### 狀態管理：Riverpod

理由是**生態一致性而非技術優越性**。框架已綁定 Riverpod：
`dart-provider-architecture` skill 明文為 Riverpod 規範（含必接線 provider
與 wiring test 配對規則）、`parsley-flutter-developer` 代理人假設 Provider
模型、flutter_balance 亦採用。選擇其他方案等於放棄整套現成規範與代理人支援。

#### 載入策略：依視圖惰性，而非依欄位

**原本的「先建圖、ticket 詳情用到才讀」在欄位層級不成立**：5W1H
（`where` / `why` / `how` / `acceptance`）全部位於 frontmatter，
與 Graph 需要的邊（`blockedBy` / `relatedTo` / `parent_id` / `source_ticket`）
在同一個 YAML 區塊。無法只解析半個 block——讀了邊等於讀了詳情。

實測（flutter_balance，Python + PyYAML 為粗略上界）：

| 資料 | 檔案數 | 耗時 |
|------|-------|------|
| 圖譜節點（PROP/SPEC/UC/EVT/DomainBundle） | **16** | ~20 ms |
| Ticket | **1338** | ~1.9 s（11.6 MB） |

**核心場景（domain ↔ UC flow 穿透）完全不需要 ticket**，兩者差兩個數量級。
因此惰性的正確切法是依視圖：

- 開 App → 解析 16 個節點檔 → domain/UC 圖立即可用
- 點進 ticket 清單或「什麼卡住了」→ 才付 1.9 秒，帶進度指示

這個切法成立的原因是 domain map 已把 Graph 與 TicketDetail 分成兩個 domain，
而它們的**資料來源恰好也是分離的**（`docs/` 下的節點檔 vs
`docs/work-logs/**/tickets/`）。切分理由是變更理由不同，結果連載入時機
都能分開——這是第二次出現「為 A 理由畫的邊界在 B 面向也成立」。

ticket 解析需置於 isolate 或分塊執行：1.9 秒即使在 Dart 快一倍，
仍會凍住 UI 約一秒。節點解析（~20ms）可留在主執行緒。

#### verification-surface：自動化為主，0.1 的驗證是設計版型比較

自動化驗證已就位並持續使用：

```
fvm flutter analyze
fvm flutter test test/                        內層契約，~0.3s
fvm flutter test integration_test/ -d macos   外層行為，需編譯
```

已知雜訊：`Failed to foreground app; open returned 1` 為 macOS 上
integration_test 的常態，不影響結果。

環境釘選：Flutter 3.47.1（`.fvmrc`）、macOS 12.0+ 部署目標、
視窗下限 960×640（契約測試守護）。

**0.1 階段不採用「人手動開 App 觀察」作為驗證手段**——該階段無資料可看，
App 本身即展示殼，驗證形式改為**以設計技能生成多種版型配置並比較**。
手動觀察留待有真實資料的階段。

### 2026-08-26：Stage 1.5 畫面狀態矩陣完成（SPEC-001）

六個畫面與專案切換浮層，共 26 個狀態，各以四欄描述
（顯示／可用操作／進入條件／退出路徑）。三個 gate 的三問皆有對應行，
無「失敗欄為空」的情形。

展開過程發現三項在版型階段看不出來的缺口：

1. **長時操作若不可取消即為死胡同。** Ticket 載入實測約 1.9 秒，
   惰性載入把成本集中在單次觸發；載入期間若無法取消或離開，該狀態
   就是死胡同，且專案越大越嚴重。已列為 FR-02（P0）。
2. **`flow 未結構化` 是預設狀態，不是例外。** `FlowStep` 屬 `proposed`
   layer，實例僅存在於 flutter_balance 且覆蓋 1/1，因此絕大多數 UC
   會落在此狀態。把它當例外處理，UC Flow 視圖在真實專案上就是空殼。
   已列為 FR-06。
3. **schema 不相容狀態原本沒有退出路徑。** 若僅顯示「版本不符」而無動作，
   使用者被困住。已補：切換專案浮層維持可用。

### 2026-08-26：第五個框架工具鏈缺陷（`doc create spec` 不建立雙向關聯）

`doc create spec --domain ui --title ...` 建立了檔案，但：

- `proposals-tracking.yaml` 的頂層 `specs` 仍為 `[]`
- 來源提案的 `outputs.spec_refs` 未被更新

`doc list specs` 讀檔案因此看得到，`doc status` 讀索引因此看不到。
與 `0.0.2-W1-002`（status 不同步）、`0.2.1-W3-1117`（title 不寫入檔案）
同屬「索引與檔案分歧」族。

本次以手動補齊雙向關聯（SPEC 的 `source_proposal` 正向邊由範本帶入，
PROP 的 `spec_refs` 反向邊與索引項為手動補）。已回報上游。

---

## Stage 5：收斂

### 防護底線總表

依 `baseline-protections.md` 六類逐項過。多數 N/A（無後端、無網路服務、
無資料庫、單使用者本機工具），但下列各項確實適用。
**未逐項確認即略過是不允許的**，故 N/A 亦逐條標明理由。

#### 一、Secret 與憑證

| 底線 | 狀態 | 說明 |
|------|------|------|
| Secret 不進 repo | **已納入** | 框架 `sync_exclude_manifest` 的 `CREDENTIAL_PATTERNS` 已涵蓋 `.env` / `id_rsa` / `secrets.*` 等；`.gitignore` 已套用 |
| Secret 單一管理位置 | 不適用 | 本 App 無任何執行期 secret |
| TLS 全程 | 不適用 | 無網路服務 |
| **Operator 帳號 MFA** | **待確認** | 見下方 §發現一 |

#### 二、入口與輸入

| 底線 | 狀態 | 說明 |
|------|------|------|
| 對外 endpoint 認證邊界 | 不適用 | 無對外 endpoint |
| 物件層級授權檢查 | 不適用 | 單使用者、本機、唯讀 |
| **輸入驗證** | **待實作** | 見下方 §發現二 |
| **資源上限** | **待實作** | 見下方 §發現二 |

#### 三、資料

| 底線 | 狀態 | 說明 |
|------|------|------|
| Schema migration 版本化 | 不適用 | 無資料庫 |
| 自動備份 + 還原驗證 | 不適用 | App 不擁有任何資料，全部衍生自它不擁有的檔案 |
| 租戶隔離邊界 | 不適用 | 無多租戶 |
| PII 盤點 + log 遮罩 | **延後** | Stage 3 已定「破洞報告即診斷入口」，目前不寫執行期 log。**重評條件**：若日後加入 log，使用者的文件內容（可能含敏感資訊）會進 log，屆時須先做遮罩設計 |

> 「App 不擁有資料」同時是一項安全紅利：首版唯讀，因此不存在破壞使用者
> 資料的路徑。加入編輯能力即跨越這條線——見 tripwire 總表。

#### 四、部署與變更

| 底線 | 狀態 | 說明 |
|------|------|------|
| **部署可回滾** | **待設計** | 發布形式為 dmg，使用者如何降級到前一版尚未設計 |
| Health check | 不適用 | 非常駐服務 |
| **依賴鎖定 + CI gate** | **待決** | 見下方 §發現三 |
| **依賴漏洞掃描** | **待納入** | Dart 套件的已知漏洞掃描尚未設定 |

#### 五、觀測與追溯

| 底線 | 狀態 | 說明 |
|------|------|------|
| Structured log + 錯誤分類 | **延後** | 同上，破洞報告承擔診斷職責。**重評條件**：出現無法由破洞報告解釋的故障 |
| 掛了有人知道 | 不適用 | 本機 App，使用者即時可見 |
| Production 操作可追溯 | 不適用 | 無 production 環境 |

#### 六、金流分帳

全項不適用——不涉及金流。

---

### 發現一：Developer ID 憑證是本專案唯一真正的憑證

PROP-001 決定走 Developer ID + notarization。該憑證外洩的後果是**他人可以
簽發看起來出自你的 App**，而使用者的 Gatekeeper 會放行。這是本專案唯一
一項「防護成本接近零、缺了損失極大」的憑證。

**待確認**：Apple Developer 帳號與 GitHub 帳號是否已開啟 MFA。
本記錄無法代為確認，列為待辦。

### 發現二：「整個資料夾可讀」使輸入驗證與資源上限成為必要

Stage 3 裁示安全邊界為「整個選定資料夾都可讀」（而非限定 `docs/` 與
`.claude/` 的已知路徑）。該選擇換得彈性，但同時產生兩個必須補的防護：

1. **誤選大目錄的資源上限。** 使用者若誤選 home 目錄或磁碟根目錄，
   遞迴掃描會失控。須有掃描檔案數上限、單檔大小上限與逾時，
   並在超限時明確回報而非靜默截斷或當掉。
2. **畸形 YAML 的解析防護。** App 解析使用者專案的任意 YAML。
   YAML 解析器對深層巢狀或錨點展開（billion laughs 類）可能耗盡記憶體。
   須確認所用套件的行為並設限。

兩者皆非理論風險：實測語料中 `book_overview_v1` 有 2419 個 ticket
與 237 個節點檔，已是萬檔級掃描；誤選上層目錄只會更大。

### 發現三：`pubspec.lock` 不入庫的取捨因發布決定而改變

專案初期沿用既有 `.gitignore` 將 `pubspec.lock` 排除，當時判斷為
「依使用者原有規則」。但 PROP-004 之後的發布決定改變了這個取捨的權重：

App 要發布給其他框架使用者，lock 檔不入庫意味著**不同機器建出的 binary
可能鎖到不同的依賴版本**，而使用者拿到的是 binary 而非原始碼，無從察覺。
Flutter 官方對 application（非 library）的建議本即為 commit lock 檔。

**列為待決事項**，需使用者裁示是否改為入庫。CI gate 亦尚未建立。

---

### 規模與變更 tripwire 總表

| 觸發條件 | 影響 | 動作 |
|---------|------|------|
| 決定上架 Mac App Store | 沙盒必須開啟，`Process.run` 失去執行 CLI 能力 | 回頭重評 PROP-001，重新引入 security-scoped bookmark |
| **加入編輯能力** | 跨越「App 不擁有資料」的界線 | 備份、衝突、還原、PII 全部重評；等同新的架構決策 |
| 上游 `0.2.1-W3-1110` 定案 | 部分 `proposed` 型別升為 `established` | 重評 proposed 型別的渲染策略；`flow 未結構化` 的出現率下降（SPEC-001 FR-06） |
| 上游 `0.2.1-W3-1115` 定案 | `where.layer` 的處置方式確定 | 重評 ticket → domain 的定位機制（PROP-004） |
| 上游 `id_pattern` 加入 lookbehind 或 `\p{}` | Dart `RegExp` 語意不符 | 契約測試會紅燈；須調整解析或請上游改寫 |
| 專案檔案數超過萬檔級 | 依視圖惰性載入的假設仍成立，但單次載入時間拉長 | 重評是否需要持久化快取（目前明確不做） |
| 出現無法由破洞報告解釋的故障 | 診斷入口不足 | 重評 structured log 的延後決定 |
| 使用者回報誤選大目錄導致當機 | 資源上限缺失 | 見發現二，該防護應在此之前完成 |

---

### Stage 5 完成度

| 產出 | 位置 |
|------|------|
| 操作風險表（BDD） | PROP-004 §範圍界定、SPEC-001 |
| domain map | `docs/domain-map.md` |
| event catalog | `docs/events/`（9 個 EVT） |
| 技術選型（理由／防護狀態／tripwire） | 本檔各補記段 |
| 防護底線總表 | 本節 |
| 規模 tripwire 總表 | 本節 |
| 驗證環境節 | 本檔 Stage 4「verification-surface」 |

---

## Stage 6：移交 doc 系統

訪談產物已轉為 doc 系統的三類文件：

| 訪談產物 | 移交去向 |
|---------|---------|
| 定錨 + 交付形態 gate + 技術決策 | PROP-001 ~ PROP-004（皆 `confirmed`） |
| 畫面狀態矩陣（Stage 1.5） | SPEC-001 |
| 操作盤點（BDD） | UC-01 ~ UC-06 |
| domain map + event catalog | `docs/domain-map.md`、`docs/events/` |

六個 UC 皆填寫**結構化 flow 區塊**（`FlowStep`）。這不只是完整性——
`FlowStep` 升為 `established` 的判準要求「兩個以上互相獨立的 consumer
專案語料中有實例」，目前僅 flutter_balance 有且覆蓋 1/1。本專案填寫後
即為第二份獨立語料。

### 第六個框架缺陷：UC 編號格式在框架內部自相矛盾

| 來源 | 規定 |
|------|------|
| `tracking_schema.py`（宣告的 SSOT） | `^UC-\d{2,}$`（兩位以上） |
| `uc_registry.py:19,38` | `^UC-\d{2}$`（恰好兩位） |
| `create.py:_next_id` 實際配號 | `{prefix}-{NNN}`（三位） |

`doc create usecase` 配出 `UC-001`，`doc uc verify` 拒絕它。
**兩個指令在同一專案上永遠無法同時成功。**

`uc_registry.py` 未引用 `tracking_schema`，而是自帶 inline 正則——
那正是 `tracking_schema.py` 檔頭明文禁止的做法（「消費端一律引用本模組
常數，禁止 inline 猜測欄位名」）。

**本專案處置**：改用兩位數（`UC-01` ~ `UC-06`），與 flutter_balance 一致，
且滿足較嚴格的 `uc_registry`（該定義可掛 CI）。已回報上游。

### 實作注意：不可假設 UC 編號為兩位數

graph schema 允許 `\d{2,}`，因此其他 consumer 專案可能存在三位數 UC。
本 App 的解析須容納兩者，不可硬編碼位數。

---

## 0.0.3：選型評估

### markdown 渲染：`flutter_markdown_plus`（票 `0.0.3-W1-001`）

`flutter_markdown` 已被 Flutter 官方標記 `discontinued`，pub.dev metadata
直接指定接替者為 `flutter_markdown_plus`。候選為該接替者與 `gpt_markdown`
（更新最頻繁，2026-08-23）。

以本專案 `docs/` 的真實內容實測（表格、YAML flow block、程式碼區塊、
行內程式碼、中文長段落、巢狀清單、引用區塊），並另做標題階層隔離測試：

| 面向 | flutter_markdown_plus | gpt_markdown |
|------|----------------------|--------------|
| 依賴足跡 | 1（`markdown`） | 8（含 `flutter_math_fork`、`flutter_svg`） |
| 樣式覆寫 | 宣告式樣式表，27 個可覆寫欄位 | 命令式 builder 回呼，9 個 |
| 文字可選取 | 內建 `selectable` 參數 | 需自行包 `SelectionArea` |
| 標題階層 | H3/H4/H5 差異小 | 五階分明，H1 下有分隔線 |
| 行內程式碼 | 僅換字型 | 有底色框 |
| 程式碼區塊 | 淡底色 | 語言標籤 + Copy code 按鈕 |
| 表格 | 完整框線、儲存格換行 | 內容寬度、表頭底色 |

**採用 `flutter_markdown_plus`。**

決定理由不是「現在誰看起來好」，而是**誰的缺點改得動**：
`flutter_markdown_plus` 的兩個缺點（標題階層扁平、行內程式碼無底色）
正好落在它那 27 個樣式欄位能修的範圍內；`gpt_markdown` 的缺點
（8 個依賴，含本專案用不到的 LaTeX 與 SVG 渲染器）不能修。

`gpt_markdown` 的 Copy code 按鈕與語言標籤是 LLM 對話場景的介面家具，
對本專案非必要；其較佳的標題階層可透過樣式表在採用方案上複製。

**實測方法留記**：以 `RepaintBoundary.toImage` 在 macOS 整合測試中截圖比較。
首次以單一混合文件目視比較時，誤判 `gpt_markdown` 的標題階層有缺陷；
隔離測試後發現剛好相反。**混合文件的目視比較不足以下結論。**

### 更正：先前以版本切範圍的框法

專案早期將 git 變更記錄記為「延後，非核心價值」、編輯能力記為
「首版唯讀，另立提案」。該框法以版本劃分範圍，與本專案方法論衝突——
**所有應做的功能先討論清楚再排順序，不預先劃分到 v1 / v2**。

正確狀態為**尚未討論**。兩者已納入 0.0.3 的選型議題。

### git 變更記錄：成本實測（尚未定案）

先前估計「精確版為 O(commits × files)，成本高」是錯的。實測
（flutter_balance，9409 commits）：

| 做法 | 耗時 |
|------|------|
| 逐檔 `git log`（1346 檔） | 0.21 秒 × 1346 = 約 4.5 分鐘 |
| 單次 `git log --name-only -- docs/` | **1.04 秒**，輸出 1.64 MB |

**文件層級的變更記錄很便宜**；昂貴的是每條**邊**的變更歷史
（需逐 commit diff 檔案內容）。兩者應分開決策。

### git 變更記錄：邊層級（票 `0.0.3-W1-003`）

**實測推翻了自己的推估，而且錯了兩次、錯法相同**——把天真實作的成本
當成問題的固有成本。

| 做法 | 耗時 |
|------|------|
| 文件層級（`git log --name-only` 單次） | 1.04 秒 |
| 邊層級（逐 commit `git show`，52000 對） | 18.3 分鐘 |
| **邊層級（單次 `git log -p` + 解析 31.2 MB）** | **2.28 秒** |

差距 523 倍，而問題本身未變。若照原推估直接放棄邊層級，會失去一個
2.28 秒就能做到的功能。

**採用邊層級**，依視圖惰性載入。不實作增量更新——全量重掃已夠快，
增量需維護狀態且正確性風險高。

**新增 History domain**（第八個），不併入 Corpus。理由見 `domain-map.md` §4.3。

降級行為已實測：非 git 目錄 `exit=128` 且 stderr 明確；git 不在 PATH 為
`ProcessException`，與解析失敗等其他形態可區分。

**Tripwire**：diff 輸出量隨 repo 規模成長（9409 commits 產生 31.2 MB，
十倍規模即 312 MB）。早期警訊為輸出位元組數超過閾值；緩解手段為
`--since` 或路徑範圍收窄。淺層 clone 會使「首次出現」時點錯誤，
須以 `git rev-parse --is-shallow-repository` 偵測並標示。
