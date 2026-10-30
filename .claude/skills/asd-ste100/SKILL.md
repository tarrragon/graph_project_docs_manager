---
name: asd-ste100
description: "Applies ASD-STE100 controlled-language principles (one term per concept, short sentences, active voice, can/will/must) as a language-agnostic core, then loads the en or zh-TW pack by output language. zh-TW discourse structure: compositional-writing."
metadata:
  version: 1.0.0
---

# ASD-STE100 受控寫作

ASD-STE100（Simplified Technical English，簡化技術英文）是航太維修手冊的受控語言標準。本 skill 只取其中**不依附英文**的原則作為核心，再依輸出語言載入對應的 pack。

## 核心原則（語言無關）

寫完一段文字，逐條對照。規則刻意只留這幾條：規則條數越多，真正重要的幾條越容易被稀釋。

| # | 原則 | 對照問題 |
|---|------|---------|
| 1 | 一事一名 | 同一個概念在全文是否只用同一個詞？ |
| 2 | 一詞一義 | 同一個詞是否只承擔一個意思？ |
| 3 | 短句 | 一句是否只說一件事？太長就拆句，不刪內容 |
| 4 | 主動語態 | 每個動作是否寫出動作者？ |
| 5 | 一句一指令 | 指令句是否一句只下一個指令，條件寫在指令之前？ |
| 6 | 情態詞三級 | 情態詞是否只用「可以／會／必須」（can／will／must）三級？ |
| 7 | 名詞串上限 | 連續堆疊的名詞是否不超過 3 個？ |
| 8 | 只留帶事實的詞 | 誇飾詞與空泛詞是否已刪？術語首次出現是否已定義？ |

## 依輸出語言載入 pack

| 輸出語言 | 讀哪些檔 | 內容 |
|---------|---------|------|
| 英文（英文 description、發佈庫 README、對外英文文件） | `references/en-rules.md` | Issue 9 九節規則目錄（改寫）與官方字典連結 |
| 正體中文（ticket、worklog、規則檔、回覆） | `references/zh-TW-rules.md`，再讀 `references/zh-TW-lexicon.md` | 中文句子規則（句型層）與本專案詞庫（用詞層） |

**正體中文交接文字的篇章結構**（章節安排、段落順序、三明示）不在本 skill 範圍，走 `compositional-writing` skill。本 skill 只管句子與用詞。

## 語言邊界

- **預設寫法**：輸出正體中文時，直接以正體中文套用核心原則與 zh-TW pack。
- **英文 STE 只用於思考過程**：可以先用英文 STE 整理想法，但寫入 ticket、log、回覆的文字必須維持正體中文（`language-constraints` 規則 1 不變）。
- 英文中轉是否成為預設寫法，由實測結論決定。實測完成前維持上述預設。

## 合規的界線

**沒有任何工具能保證 STE 合規。** ASD 不認證任何工具。模型手上沒有完整的 STE 字典，產出只是近似 STE。對照本 skill 的規則只能降低違規，不能宣稱「已符合 ASD-STE100」。

## 範例

【原句】這個問題應該是因為設定被改掉了，或許可以考慮先把快取清掉再重新跑一次測試看看。

【改寫】設定檔已被另一個 session 改寫。先清除快取，再重跑測試。

【對照】原則 6：「應該／或許／考慮」改為直述或指令。原則 4：寫出改寫設定的動作者。原則 5：兩個指令拆成兩句，依執行順序排列。原則 3：一句只說一件事。

## 來源

改寫自三個 MIT 授權的社群 skill（AminBlg/SimpleEnglish、nuelcyoung/asd-ste100、sdsheeks/ste100-skill），署名與連結見 `LICENSE`。ASD-STE100 標準與字典的著作權屬 ASD，本 skill 只連結、不複製也不翻譯字典內容（<https://www.asd-ste100.org/>）。ASD-STE100 是 ASD 的註冊商標。本 skill 非官方，與 ASD 及 STEMG 無隸屬關係。

版本紀錄在同目錄的 `CHANGELOG.md`。
