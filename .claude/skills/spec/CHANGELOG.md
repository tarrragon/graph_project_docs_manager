# spec 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.9.5 — 本地變更：`scripts/check_domain_coverage.py` 補強宣告讀取與宣告矛盾比對。(1) `has_functional_requirements` 在 frontmatter 重複出現時報錯（原取第一個，`false` 在前 `true` 在後會放行）；引號多行字串續行內的同名鍵不算宣告（原頂格續行會被讀成宣告）；非法值訊息列出合法寫法 `true`、`false`。(2) 矛盾比對與漏抓提醒改共用單一「形似 FR 定義的行」判定（`fr_like_lines`），涵蓋 ATX 標題、行首粗體、setext 標題，可帶編號前綴、粗體、方括號、反引號、全形字母、1 至 3 格縮排；須含編號，故「FR：不適用」「FR 與 NFR 的界線」不再誤判，`#FR-01`（井號後無空白）不是標題亦不算；圍欄與 HTML 註解內的行不算（抽取端同遮註解），遮蔽先於切除 frontmatter、訊息列出行號。清單項與表格列刻意不算定義。判定結果改變：原漏放的寫法現在報矛盾；原誤判的寫法現在通過。遮蔽註解時行內程式碼片段內的註解符號不作邊界（原行內程式碼寫出註解開頭符號會吞掉其後的 FR 標題且無警告）；被圍欄或註解遮掉的區段內若有抽取樣式或形似 FR 的行，於 stderr 輸出「位於被略過的區段」WARNING 與行號，不改 exit code；編號前綴實際只認數字加點與「需求 」兩種，`#` 後須有空白，縮排 0 至 3 格算標題。本專案七份 SPEC 修改前後 exit code 不變

**Version**: 1.9.4 — 本地變更：`scripts/check_domain_coverage.py` 的 FR 抽取補兩項。(1) 略過圍欄程式碼區塊（三個反引號或三個波浪號）內的行，原先區塊內的範例標題會被當成真的 FR 進入比對。(2) 抽出大於 0 個時，行首為標題或粗體且緊接 FR 編號、而編號不在抽出集合內的行，逐行於 stderr 輸出 WARNING 與行號；原先同一份 SPEC 混用支援與未支援的標題寫法時，漏掉的 FR 靜默不計而檢核照樣通過。提醒不改變 exit code（本專案的 SPEC 實跑無任何一則，尚無誤報樣本可供決定是否升為非 0）；NFR 標題與帶 SPEC 前綴的引用不觸發。另補全形冒號經主流程的端到端測試。圍欄判定補強：閉合行須同字元、長度不小於開行且其後無文字，反引號開行的標示含反引號者不視為圍欄；輸入結束仍在圍欄內時檢核以 exit code 1 結束並指出開圍欄行號（原先其後內容被靜默遮掉而照樣通過）。遮蔽只對抽取與漏抓提醒成立，宣告矛盾比對與事件流標定的切段不遮。SKILL.md 覆蓋檢核段同步補述

**Version**: 1.9.3 — 本地變更：`scripts/check_domain_coverage.py` 定位函式回報找不到 map 的成因，訊息依成因輸出（無任何 map／有 map 但未列入／spec id 無法辨識／source_specs 格式無法解析）；`source_specs` 新增 YAML 區塊清單寫法（原只認行內清單，區塊清單被讀成空集合並誤報請補值）；刪除無呼叫端的 `locate_domain_map` 相容入口。層級模式（以系統層判定）下覆蓋失敗標題行與事件流提醒尾行改稱系統層，非層級模式逐字不變。行內清單的三種非法寫法（右括號後緊接井號無空白、右括號後有多餘文字、括號內含註解）由原本接受改為報格式無法解析；其餘合法寫法判定結果不變，區塊清單項目尾端註解會剝除、鍵行註解與清單間的空行或註解行會跳過、flow 清單可寫在鍵的下一行

**Version**: 1.9.2 — 本地變更：`scripts/check_domain_coverage.py` 新增層級 SPEC 判定（原定位鏈無 map、未帶旗標、`domain` 欄非已宣告 domain 三者同時成立時以系統層判定，輸出印出 domain 欄值與已宣告集合；層級模式只認該 SPEC 在系統層的歸屬、不走相容比對；`--domain-map ""` 報錯）。SKILL.md 定位鏈段補述

**Version**: 1.9.1 — 〈定位與分工〉補 system-design 一列：它在寫規格之前決定這一版的範圍與時機，/spec 檢查範圍內的需求清晰度

**Version**: 1.9.0 — 本地變更，指向 tarrragon/claude#107：`scripts/check_domain_coverage.py` 的 FR 比對鍵由 FR 編號改為（spec 識別, FR 編號）。spec 識別取 frontmatter id，缺時取檔名 SPEC-NNN；domain map 的每個 FR token 依序歸屬到同行在它之前最近的 SPEC-NNN、最近含 SPEC-NNN 的祖先標題，兩者皆無為未歸屬，map 有任一已歸屬 token 時未歸屬 token 不計入覆蓋。修前同一份 map 覆蓋兩份以上 spec 時，同號 FR 互相遮蔽而被誤判為已覆蓋（守衛放行方向失效）。整份 map 無歸屬或 spec 識別取不到時走相容模式（舊的不分 spec 比對），stderr 說明。判定結果改變：原被遮蔽的 FR 現在會被報為未覆蓋。frontmatter id 只在收尾 `---` 之前的區塊內讀取，且只接受 SPEC-NNN 形式；其他形式（如 SPEC-UI-001）在 map 端的歸屬鍵永遠對不上，改走相容模式並警告，不把該 spec 全部 FR 報成未覆蓋。tests 新增 10 案例（合計 48 綠）。

**Version**: 1.8.1 — 術語校正：「判準」全數改為「判斷標準」（「停止判準」改「停止條件」）。上一輪全站替換之後這個縮寫又回流，詞面在工程讀者端讀不出來

**Version**: 1.8.0 — Layer 1 新增事件流標定檢核：`scripts/check_domain_coverage.py` 加可選 `--check-event-flow-labeling`，掃 FR 段落的事件流訊號詞（常數 `EVENT_FLOW_SIGNAL_WORDS`，與維度 5 的清單逐字一致、單一來源），命中的 FR 須在 domain-map「通道與協調圖」節的「到達類別與級別實例」子表有對應引用，缺者列提醒不阻擋；節以標題文字定位不依編號（實測有專案的 §2.5 已被他節佔用）。tests 新增 18 案例（合計 38 綠）。試水溫：對一份含 17 個 FR 的 UI spec 執行，3 個命中、誤判 0，訊號詞清單未收窄。

**Version**: 1.7.0 — Layer 2 新增維度 5「資源競爭」（Lite + Full，條件式觸發）：掃描維度表補一列，核心問題問事件流的到達類別／級別是否標定、與誰共用通道、卸載時本功能行為是否定義；新增「維度 5 資源競爭掃描說明」小節（訊號詞清單一行列舉供 Layer 1 腳本共用、無訊號時跳過並標註 skipped、判準以標題引用〈事件流負載仲裁方法論〉的〈到達類別〉〈級別〉〈讓步與卸載順序〉三節不重述）；語義推演輸出格式範例補維度 5 區塊；相關文件補該方法論條目。「Lite 模式只掃描維度 1-3」句同步改列維度 5。動機：既有維度 1-4 都未問事件流資源競爭，級別若延後到實作期由工程師憑印象補標，會違反該方法論「級別在邊界標定、仲裁器不推導」的原則。

**Version**: 1.6.2 — 版本紀錄搬到同目錄的 `CHANGELOG.md`。skill 是 runtime 整份載入的檔案，而沒有任何規則要求任何人讀版本紀錄，留在 SKILL.md 等於每次叫用都付一次無效讀取。SKILL.md 末尾留一行指過去，版號的兩個住址改成「CHANGELOG.md 最上面那一條 + frontmatter 的 metadata.version」。skill 的指令內容一個字都沒改。

**Version**: 1.6.1
**Last Updated**: 2026-08-08
**Source**: Phase 3b context 耗盡案例 → 需求完善度品質閘門
**Changes**: v1.6.1 - 審查修正兩處：(1) 生命週期段對 tdd skill 的引用改為條件式選讀——原寫法是跨 skill 硬路徑、單獨安裝 spec 的專案是死鏈、且抵觸本檔「/spec 不呼叫 /tdd、兩者完全解耦」的定位宣告；段內原則已自足、引用降為「同專案若也安裝 tdd 時的延伸閱讀」。(2) 「維度 4 skipped」示例塊的語言標從閉合 fence 移回開啟 fence（v1.6.0 誤打在閉合線上）。v1.6.0 - /spec init 輸出節新增 feature-spec 生命週期（scaffold 文件）：消費者是 Phase 2 測試設計、Phase 3 綠燈後權威轉移到測試與程式碼、文件標記 `status: archived (superseded by tests)`；引用 domain spec 用指涉不整段複寫、只有本 ticket 的增量決策是固有資訊。動機：feature-spec 原無生命週期定義、實作完成後長得像權威規格、實際從 Phase 3 起每個實作決策都讓它漂移——依《人月神話》多文件必漂移論點與文件分級原則（tdd skill `references/document-coherence.md`）明示降級、消滅同步期待。v1.5.0 - 定位與分工節新增「適用範圍限制（防誤用聲明）」：`subdomain: data-contract` 文件（A/B 兩區結構）不適用 `/spec validate`，機械驗證改由 `doc validate` 承接 落地前人工檢查）；維度 4 補降級條款：CLAUDE.md 無「教學模組對應表」時跳過並標註「維度 4 skipped：無教學模組對應表」，不視為失敗，動機：/spec validate 對 SPEC-002 誤報結構失敗 + flutter_balance 專案無教學模組對應表）。v1.4.0 - Layer 1 新增 domain-map 覆蓋檢核（`scripts/check_domain_coverage.py` + `tests/test_check_domain_coverage.py`，11 測試綠）：驗證 domain map 覆蓋 spec 全部 FR，FR token 支援逗號續列/範圍展開，落地 ANA domain 規劃整合；動機 domain map 曾漏 FR-25/26）。v1.3.0 - Layer 1 新增 API surface 完整性檢查（Full only），`scripts/check_api_surface.py` 機械掃描 FR 段落 API 行為訊號與 endpoint 路徑定義的對應性，動機：SPEC-014 FR-04 analytics endpoint 路徑缺口）。v1.2.0 - 新增維度 4 教學一致性（Full 模式），比對 spec 設計決策與教學對應模組（防護教學×實作偏移）。v1.1.0 - 三人組共識簡化：刪除核心抽象/反向提問策略、原維度 4-7 降級為提示、精簡迭代機制、init 條件簡化為 2 個
