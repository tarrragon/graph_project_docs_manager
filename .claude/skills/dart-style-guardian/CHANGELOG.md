# dart-style-guardian 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.2.0 — 依一輪低階 model 讀者探針（3 個實例，指令逐字相同）處置四項，其中三項為 3/3 命中。**新增〈起手〉節**：三名探針對「第一個具體動作」給出三個不同答案，其中一名直述「文件沒有明確指定」；對原文 grep `第一|起手|first|開始前|步驟1|workflow` 零命中，確認為文章未寫而非讀者誤讀。現明定第一動作是讀 `.claude/config/dart-style-guardian.json`，並說明不先讀它拿到的建議無法直接照做。**明定產出**：三名探針皆答不出本 skill 要產出什麼，或補一句「文件沒有寫格式」；現於開頭寫明產出是違規清單加改完的程式碼，且清單本身不是交付物。**新增〈五類約束與按需讀取〉表**：`references/i18n-guidelines.md`（1507 tokens）原本在 SKILL.md 與全 repo 的入站引用數皆為 0，對照組另三份各 3 處；三名探針列 references 時無一提及它。缺的不是規則（正文本有 i18n 一節）而是路由，故補的是路由表而非內容。〈Reference Files〉清單改為只列存在、判準指回該表，避免兩處各維護一份。**新增〈與相鄰資產的交界〉表**：探針 Q5 三份皆只找到 `component-contract-design`。四列各寫「這裡掃不到什麼」——例如組合層的重疊與截斷本 skill 掃不到、token 層未建時掃描範圍為空。**description 由 260 字元改為 240** 並補 `Do NOT use for` 路由，同步移除 baseline 中該筆凍結值。**體量**：SKILL.md 4209 tokens。

**Version**: 1.1.1 — 檔頭反向路由句「元件契約的十一欄位」改「元件契約欄位表」，跟隨方法論 1.14.0 欄位表計數去數字化（DOC-GPD-003）
**Version**: 1.1.0 — 檔頭方法論引用句補一句反向路由：本 skill 抓的是禁令（裸值、寫死文字、原生元件直用），正面對應的元件契約由 `component-contract-design` skill 承接。動因：查 UX 設計族 skill 的族內互引，本 skill 只有入度無出度——使用者被本 skill 的違規擋下後，沒有任何訊號指向「正確做法在哪定義」；上游追蹤 `tarrragon/claude#79`／`#82`。
**Last Updated**: 2026-09-07

**Version**: 1.0.0
**Last Updated**: 2026-03-02
