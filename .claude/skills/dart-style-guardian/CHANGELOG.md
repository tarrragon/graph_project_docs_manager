# dart-style-guardian 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.3.0 — 修補一輪原文矛盾審查發現的四項。**間距 20 對應階（C05）**：`references/spacing-system.md`〈Common Replacements〉刪除非標準值 `20` 的重複列——該值已在同檔〈Non-Standard Values〉以「兩候選」誠實列出模糊性，前者卻宣稱單一答案，兩處互斥；4dp 網格本身（〈Spacing Scale〉）不含 20，刪除後兩表不再互斥，20 的實際取捨仍待另一份缺引導修補判定。**`.rsp` 正誤標示（C06）**：`SKILL.md`〈Responsive Font Sizes〉補上 `14.rsp` 為正確手動寫法的範例並說明理由——原文只列 `14`、`14.sp` 為錯誤示例、隻字未提 `.rsp` 手動寫法是否合法，讀者無法判斷 `references/typography-system.md`〈Manual Responsive Text〉標為「Correct」的 `14.rsp` 是否仍算違規；現與該份完整規範對齊。**錯誤訊息 i18n 呼叫層級（C04）**：`references/i18n-guidelines.md`〈Violation 2〉與 `SKILL.md`〈Violation 6〉原本分別示範「例外拋出處直接呼叫 `context.l10n!`」與「ViewModel 內並列 `context.l10n!` 與 `ErrorHandler` 兩種對等寫法」，未說明何時用哪一種；經裁決採「呈現層翻譯」，兩處統一改為非 widget 層只丟錯誤碼，翻譯留給持有 `BuildContext` 的呈現層以 `ErrorHandler` 轉譯。**垂直間距命名（C07）**：`references/spacing-system.md`〈UISpacing Constants〉原本並存「水平不加字首＋`.w`」與「垂直另立 `verticalXx` 字首＋`.h`」兩組命名，且〈SizedBox Usage〉〈EdgeInsets Usage〉範例又用第三種「不加字首不加尾綴」的寫法，`SKILL.md`〈SizedBox Spacing〉表格則只在文字註記尾綴、範例程式碼未寫出；經查證本專案既有間距 token 實作為單一命名組＋外部尾綴（無 `vertical*` 常數），三份文件已統一改為此形態，`verticalXx` 命名全數刪除。
**Version**: 1.2.0 — 依一輪低階 model 讀者探針（3 個實例，指令逐字相同）處置四項，其中三項為 3/3 命中。**新增〈起手〉節**：三名探針對「第一個具體動作」給出三個不同答案，其中一名直述「文件沒有明確指定」；對原文 grep `第一|起手|first|開始前|步驟1|workflow` 零命中，確認為文章未寫而非讀者誤讀。現明定第一動作是讀 `.claude/config/dart-style-guardian.json`，並說明不先讀它拿到的建議無法直接照做。**明定產出**：三名探針皆答不出本 skill 要產出什麼，或補一句「文件沒有寫格式」；現於開頭寫明產出是違規清單加改完的程式碼，且清單本身不是交付物。**新增〈五類約束與按需讀取〉表**：`references/i18n-guidelines.md`（1507 tokens）原本在 SKILL.md 與全 repo 的入站引用數皆為 0，對照組另三份各 3 處；三名探針列 references 時無一提及它。缺的不是規則（正文本有 i18n 一節）而是路由，故補的是路由表而非內容。〈Reference Files〉清單改為只列存在、判準指回該表，避免兩處各維護一份。**新增〈與相鄰資產的交界〉表**：探針 Q5 三份皆只找到 `component-contract-design`。四列各寫「這裡掃不到什麼」——例如組合層的重疊與截斷本 skill 掃不到、token 層未建時掃描範圍為空。**description 由 260 字元改為 240** 並補 `Do NOT use for` 路由，同步移除 baseline 中該筆凍結值。**體量**：SKILL.md 4209 tokens。

**Version**: 1.1.1 — 檔頭反向路由句「元件契約的十一欄位」改「元件契約欄位表」，跟隨方法論 1.14.0 欄位表計數去數字化（DOC-GPD-003）
**Version**: 1.1.0 — 檔頭方法論引用句補一句反向路由：本 skill 抓的是禁令（裸值、寫死文字、原生元件直用），正面對應的元件契約由 `component-contract-design` skill 承接。動因：查 UX 設計族 skill 的族內互引，本 skill 只有入度無出度——使用者被本 skill 的違規擋下後，沒有任何訊號指向「正確做法在哪定義」；上游追蹤 `tarrragon/claude#79`／`#82`。
**Last Updated**: 2026-09-07

**Version**: 1.0.0
**Last Updated**: 2026-03-02
