# ux-design-evaluation 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.5.0 — 依一輪低階 model 讀者探針（3 個實例，指令逐字相同）處置三項。**description 由 989 字元收斂至 242**（門檻 250）：原值為門檻近四倍，且已被凍結於 `.claude/hooks/skill-description-baseline.json`，本次修正後同步移除該 baseline 條目——凍結值留著等於替回退預先簽名。收斂捨棄的觸發詞見下段。**排除項補轉介地址**：原文「不涵蓋視覺風格設計與使用者研究方法」為明示排除但無去向，兩名探針在無提示下各自指出不知道該找誰；改為視覺風格走 `foundation-design` 的 UI 維度（執法層在 Dart 專案為 `dart-style-guardian`）、使用者研究本框架無承接者需自行取用外部方法，並明寫 WCAG 對比是例外仍屬本 skill。**新增〈與相鄰資產的交界〉表**：探針 Q5 三份皆只找到 `component-contract-design` 一個。四列各自寫出「交界處讀者會踩到什麼」而非只寫職責分界——例如本 skill 判定的時間門檻是元件契約〈回饋契約〉欄的輸入，所以產出必須是可被引用的具體值。**description 捨棄的觸發詞**：死胡同以外的同義詞、`initializing`、`hash 路由`、`tab bar`、`service worker`、`Bottom Sheet`、`debounce`、`防連點`、`佔位`、`placeholder`、`ellipsis`、`省略號`、`截斷`、`完成宣告`、`可點性`。捨棄判準為「保留的上位詞已能命中同一情境」，其中`完成宣告`與`防連點`為唯一兩個無上位詞可代者，兩者仍留在正文〈跨維度快速自檢〉可被全文檢索命中，但**skill 選用階段的匹配力確有下降**，此為 250 字元預算下的取捨，不宣稱無損。

**Version**: 1.4.5 — 讓號並補記本地兩項變更：其一，「十一欄位齊全」改「元件契約欄位表齊全」，並於 `references/interaction-feedback.md` 六種按鈕狀態表下補與元件契約〈回饋契約〉欄的分工句——時間門檻與通知形式仍由本 skill 產出，每形態的回饋通道與狀態來源由 `component-contract-design` skill 承接；其二，評估流程補一句反向路由：畫面狀態矩陣填完、進入元件級實作前，元件契約由該 skill 承接。動因是本 skill 對該 skill 只有入度無出度，使用者做完畫面級狀態設計後沒有訊號接上元件層契約。兩項原標 1.4.4 與 1.4.3，其中後者與上游同日獨立標記的 1.4.3 撞號；兩側內容皆在本 skill，本地兩項合併讓號至本版。

**Version**: 1.4.3 — 清理 2 處 language-constraints.md 規則 2 禁用詞基線債務（`代碼` → 程式碼，`references/input-mechanism.md`），純用語修正，內容與判準未改。

**Version**: 1.4.2 — 版本紀錄搬到同目錄的 `CHANGELOG.md`。skill 是 runtime 整份載入的檔案，而沒有任何規則要求任何人讀版本紀錄，留在 SKILL.md 等於每次叫用都付一次無效讀取。SKILL.md 末尾留一行指過去，版號的兩個住址改成「CHANGELOG.md 最上面那一條 + frontmatter 的 metadata.version」。skill 的指令內容一個字都沒改。

**Version**: 1.4.1 — 術語校正：判準全數改為判斷標準（動作修飾語縮為「X 標準」、狀態義改為「X 條件」）。判準的語域在哲學與教育評量、工程讀者解析不了——五份低階模型探針一致回報非通用

**Version**: 1.4.0 — 三輪 agent 審查（compliance / cadence 冷讀對齊 / self-application steelman outbound）修正：宣告層與內容層對齊（description / Triggers / 路由表症狀欄補 v1.2-1.3 新增檢查的入口、「不涵蓋」聲明修正為視覺風格 — WCAG 對比屬檢查範圍、元件語意段主標去半套）；steelman 修正（WCAG AA 分字級 4.5:1 / 3:1、觸控底線標派系 44pt HIG / 48dp Material、選中態補主題成對機制條件、溢出手段補捲軸指示、toggle 消歧補動詞標籤選項、完成證據補 API cursor + 全量場景邊界、debounce 慣例值去門檻化、跨平台適配補系統行為 / 視覺風格判斷標準、navigation 補參考來源）；快速自檢 3-in-1 拆分、佔位掃描補操作提示
**Version**: 1.3.0 — 元件語意與版面檢查加第六項「sizing 套件不驗證空間分配」（換算工具在常數層、空間分配在 layout 協商層，兩層獨立；版面擠壓先分換算錯 vs 分配錯、引入套件時記錄它不保證的層）；檢查標題去計數化（五個檢查 → 元件語意與版面檢查）；檢查清單同步
**Version**: 1.2.0 — 從一次 mobile app 驗收的六個實際發現補「元件語意與版面」檢查層（互動回饋 reference 加五項：切換元件標籤的現態 / 動作歧義、非互動指示與動作按鈕同形、選中態底色文字色成對設計、水平溢出捲動 affordance、關鍵回饋文字版面保障；反模式表加四行含佔位 handler 掃描）；快速自檢同步擴充
**Version**: 1.1.0 — 從一個 Chrome extension 專案的實際事故補 web / 多 context 維度（原案例庫全為 mobile app、系統性缺這一面）：狀態矩陣加 initializing 狀態（查詢對象獨立生命週期）、互動回饋加結果通知鏈路前提與完成宣告窮盡證據、gate 加破壞性操作確認與 fail-safe 預設、錯誤恢復加行動層級對位、導航加 hash SPA 路由辨識；跨維度快速自檢同步擴充
**Version**: 1.0.0 — 從單一模組的簡略版（ux-interaction-feedback：按鈕級 + 畫面級回饋）擴充為全維度 UX 設計評估 skill：新增畫面狀態矩陣、gate fallback、輸入機制、錯誤恢復、導航模式五份 reference，互動回饋 reference 併入通知模式選擇與延遲分布判讀；建立四支柱與事前 / 事後兩條評估流程
