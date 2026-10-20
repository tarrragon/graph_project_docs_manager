# 第一層決策逐題編碼表（0.5.0-W1-464 第一階段）

本檔在任何逐題編碼之前提交並凍結。凍結後不修改；編碼中遇到定義不足時，編碼者在該列 `coder_note` 寫明採用的解讀，主控研究線另以 `coding_scheme_amendments.md`（附時間）記錄修補，不回改本檔。

## 1. 編碼範圍

| 項目 | 值 |
|---|---|
| 來源 | 主控 session 逐字稿 `d6095ec5-a3fc-45d4-ab46-b9e983313f52.jsonl`（用戶本機資料，不入庫） |
| 範圍 | 第 1 到第 44 次 AskUserQuestion 呼叫，共 63 題；最後一題時間 `2026-10-20T18:17:32Z`。之後的呼叫不納入 |
| 編碼輸入 | `extract_auq.py` 機械抽出的 `.excerpts/auq_questions.jsonl`，一題一列，含題目、選項、用戶答案、前文與之後的用戶訊息 |
| 編碼產出 | `coding.jsonl`，一題一列，共 63 列，欄位見第 3 節 |
| 編碼單位 | 題（一次呼叫可含多題）。題組見第 4 節 |

## 2. 編碼者條件

- 編碼者不得是主控 session，也不得參與過這些決策。
- 編碼者只讀本檔、`.excerpts/auq_questions.jsonl` 與逐字稿原檔。逐字稿可以用行號定位、搜尋關鍵字，以找出後續的查證與最終裁定。
- 編碼者不讀 0.5.0-W1-349、0.5.0-W1-464、0.5.0-W1-465、0.5.0-W1-466 的票面，這些票寫有研究假設，會讓編碼偏向假設。
- 每一個非機械欄位都要附逐字稿證據：行號（`L<n>`）加 80 字以內的原文摘錄。找不到證據時填 `null`，並在 `coder_note` 說明。

## 3. 欄位

機械欄位直接取自抽取結果，不做判讀；判讀欄位由編碼者依定義填寫。

| 欄位 | 類型 | 來源 | 定義 |
|---|---|---|---|
| `call_no`、`q_no` | 整數 | 機械 | 第幾次呼叫、該次呼叫中的第幾題 |
| `first_round_options` | 字串陣列 | 機械 | 該題選項的 label，依原順序 |
| `recommended` | 字串或 null | 判讀 | 提問方在提問當下傾向的選項 label。label 含「Recommended」、「建議」或「推薦」時取該 label。label 沒有標記、但題目文字或 AUQ 前一則訊息明示傾向某選項時，也取該選項，並將 `recommended_source` 記為 `text`。都沒有時填 null |
| `recommended_source` | `label`／`text`／`none` | 判讀 | `recommended` 的出處 |
| `anchored` | 布林 | 判讀 | 題目文字（不含選項 label）寫有提問方對答案的傾向或推論結論，例如「我建議」「主控判斷應」。只有 label 標了 Recommended 不算 |
| `user_answer_raw` | 字串 | 機械 | 用戶答案原文 |
| `answer_in_labels` | 布林 | 機械 | `user_answer_raw` 與某個選項 label 逐字相同（複選題：每個逗號分隔項都與某 label 相同）。只依此判斷，不比對 WRAP／WARP 等字面 |
| `answer_kind` | 列舉 | 判讀 | `option`：選了某選項。`veto_all`：答案不在 label 內，且是在要求重新分析、換個方式思考或提出新方向，本題沒有給出可執行的裁定。`free_ruling`：答案不在 label 內，但本身就是可執行的裁定，例如自行指定做法。`no_answer`：未作答，改以訊息回應 |
| `resolved_by` | 字串或 null | 判讀 | `answer_kind` 為 `veto_all` 或 `no_answer` 時，同一議題後來做出裁定的那一題，格式 `<call_no>.<q_no>`；裁定不是經由 AUQ 做出時填 `L<n>`（做出裁定的用戶訊息行號）。直到範圍結束都沒有裁定時填 `unresolved` |
| `final_ruling` | 字串 | 判讀 | 本題議題的最終裁定，用一句話描述。`option` 與 `free_ruling` 填本題答案；`veto_all`／`no_answer` 填 `resolved_by` 指向的裁定 |
| `final_in_first_round` | 布林 | 判讀 | `final_ruling` 在語意上等於本題第一輪的某個選項。措辭不同但做法相同算是；把兩個選項合併，或加上選項裡沒有的實質條件，算否 |
| `matches_recommended` | 布林或 null | 判讀 | `recommended` 非 null 時，`final_ruling` 是否等於 `recommended`；`recommended` 為 null 時填 null |
| `deviated` | 布林 | 判讀 | 符合下列任一條件即為 true：`matches_recommended` 為 false；`final_in_first_round` 為 false；`answer_kind` 為 `veto_all` |
| `change_reason` | 列舉或 null | 判讀 | `deviated` 為 true 時填第 5 節的五類之一，取主因；為 false 時填 null |
| `change_reason_secondary` | 列舉或 null | 判讀 | 有第二個可辨識的原因時填，否則 null |
| `question_kind` | 列舉 | 判讀 | `decision`：有實質替代方案的決策。`confirm`：只有「是／否」且無實質替代方案。`operation`：與決策無關的操作題，例如選要接手的票號 |
| `post_hoc_correction` | 字串或 null | 判讀 | 用戶事後更正了這題的裁定時，填做出更正的行號與摘錄；否則 null |
| `cluster` | 字串或 null | 判讀 | 這題與其他題屬於同一議題、彼此相依時，填共同的短標籤（例如同一張票的同一子題），否則 null |
| `evidence` | 物件 | 判讀 | 各判讀欄位的證據，鍵為欄位名，值為 `L<n>: 摘錄` |
| `coder_note` | 字串或 null | 判讀 | 解讀上的疑義與採用的解讀 |

## 4. 題組

被 `veto_all` 或 `no_answer` 連到後續裁定的題，與後續那一題合成一個題組。題組內各題仍各自一列：

- 第一輪那一列：`answer_kind` 為 `veto_all`，`change_reason` 填 `veto_all`，`change_reason_secondary` 填導致最終裁定偏離的原因（若有）。
- 後續那一列：照常獨立編碼；它的 `recommended` 是後續那一題自己的 Recommended。

計算前提更正型題數 n 時，以題組為單位，每組最多算一次：組內任一列的主因或次因為 `premise_correction` 即計入。

## 5. 改答原因（五類）

| 代碼 | 名稱 | 判定定義 | 與相鄰類別的區分 |
|---|---|---|---|
| `premise_correction` | 前提更正 | 第一輪題目或選項依據的某項事實，在提問後經查證（讀程式碼、規則原文、文件、實測、量測）發現錯誤或不完整；最終裁定依賴這項更正。查證可由提問方或代理人執行，包括用戶要求「用 WRAP 思考」之後才做的查證 | 與 `new_information` 的分別在資訊來源：本類的資訊來自查證行為，不是用戶本人告知 |
| `preference` | 偏好 | 事實前提沒有改變，用戶依價值、風險承受度、分工習慣或節奏，選了非 Recommended 的選項 | 若用戶同時說明了提問方不知道的事實，改判 `new_information` |
| `new_information` | 新資訊 | 用戶提供提問方當時沒有的事實，例如 session 狀態、自己做過的操作、產品方向、外部知識，裁定因此偏離 | 用戶提供的是方向或價值判斷而非事實時，判 `preference` |
| `veto_all` | 否決全部選項 | 第一輪答案不在任一選項 label 內，且是要求重新分析或換框架，本題沒有給出裁定（即 `answer_kind` 為 `veto_all`） | 答案不在 label 內但本身是可執行裁定時，屬 `free_ruling`，原因另依前三類判定 |
| `other` | 其他 | 不屬上述四類，例如未作答改以訊息回應且無法辨識原因、答案與題目無關。必須在 `coder_note` 說明 | 只在前四類都不適用時使用 |

各類一例（取自編碼範圍內的逐字稿；這些例子在編碼前已由本檔作者標定，報告會另列「排除這些例子後」的數字）：

| 代碼 | 例子 |
|---|---|
| `premise_correction` | 第 36 次呼叫（L27372，「458 題 D」）用戶回「用WARP先評估」。之後的查證讀到 `rescan()` 是整輪重新解析，事件歸屬的前提因此改變，最終裁定不同於第一輪四個選項的任何一個。這一題的第一輪列記 `veto_all`，次因記 `premise_correction` |
| `preference` | 第 2 次呼叫第 1 題（L966）：Recommended 是「無需記錄」，理由是單一工具缺陷已有票追蹤；用戶選「記錄錯誤學習」，選項內容與事實都沒有變 |
| `new_information` | 第 9 次呼叫（L5826）：Recommended 是「先開一個接 L7」，用戶回「繼續L7，同一個SESSION 我已經 compact 了，可以交付他繼續完成」。session 已經 compact 是提問方不知道的狀態 |
| `veto_all` | 第 19 次呼叫（L14940）：命名格式三選一，用戶回「用WARP思考」；第 20 次呼叫（L14974）重新提問並得到裁定，`resolved_by` 記 `20.1` |
| `other` | 第 43 次呼叫（L29300）：用戶未作答，改送一則訊息談另一張票的設計；若該訊息無法辨識為本題的裁定原因，記 `other` |

## 6. 報告與決策表（事先登記）

報告 `report.md` 由研究線依 `coding.jsonl` 計算，內容：

1. 63 題的 `question_kind`、`answer_kind`、`recommended_source` 分布。
2. Recommended 基線：`recommended` 非 null 的題中，`matches_recommended` 為 true 的比率；分別列出 `recommended_source` 為 `label` 與 `text` 的比率。
3. 偏離題的 `change_reason` 主因分布與次因分布；`anchored` 為 true 的題另列。
4. `post_hoc_correction` 非 null 的題另列，不改動它們在第 2、3 項中的計數。
5. n：依第 4 節計算的前提更正型題組數，並列出各組的 `cluster`，標出彼此相依的組。
6. 敏感度：排除第 5 節例子所在的題組之後，重算第 2、3、5 項。

決策表（n 依第 5 項）：

| n | 結論 | 後續 |
|---|---|---|
| n < 6 | 不做（題數不足） | 0.5.0-W1-464.2 以 requirement_vanished 關閉 |
| 6 ≤ n < 10 | 不做（證據不足），只做描述 | 同上 |
| n ≥ 10 | 進入第二階段 | 0.5.0-W1-464.2 可開工 |

相依的題組不合併計數，但報告須寫出 n 中有幾組屬於同一 `cluster`；這個資訊供 464.2 設計參考，不改變上表的判定。
