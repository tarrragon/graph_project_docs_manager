# multi-session-orchestration 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.0.1（2026-10-19）— `references/wrap-up-and-handoff.md` §3 補「PM 本身換 session 時，總表要能被 handoff 機制讀到」：交接段標題以「下個 Session 接手 Context」開頭、段內列完整票號、以最後完成的票 `--next` 指向第一張接手票、手動跑排程提示 hook 驗證。原流程只要求寫進工作日誌，交接段標題不符解析器時，CLI handoff 與 Stop hook 的同步檢查都看不到。另補建本檔。

**Version**: 1.0.0（2026-10-15）— 初始建立：主控 PM 統籌多條 session 線的操作手冊（分線、每則來訊的處理迴圈、共用資源協調、只送達標題的審查標記查證、階段收尾與交接），三份 reference 分管共用資源、審查標記與驗證、收尾與交接。
