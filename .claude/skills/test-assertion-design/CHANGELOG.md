# test-assertion-design 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.4.0 — 補齊兩處缺引導（原文無任何約束，讀者須自行發明規則）：〈問題類型表〉類型 3 相對計時比較補二選一判準（被驗證對象承諾同一實例用參考等價，只承諾不重算用命中率）；〈確定性斷言的基礎形態〉功能正確性補預期值出處約束（須取自 spec 條文或 UC 預期結果並依 test-object-catalogue 斷言來源欄格式記錄，取自現有實作執行結果者改標 characterization test）
**Version**: 1.3.0 — 修補原文矛盾與過期描述（用戶簽核）：〈斷言品質三問〉表格後補一句，將類型 5、6 的處置路由至〈判斷軸〉斷言設計族，不套用類型 1–4 的環境隔離做法；〈判斷軸〉節「不同視角」句改寫，明示三問為初篩症狀、分族為最終處置歸類；〈不在範圍聲明〉與〈定位說明〉對 `.claude/rules/core/test-assertion-design-rules.md` 的描述由「本專案 Chrome Extension/JS/Jest 專屬規則」更正為「consumer 專案內的具體規則落地，依語言分節（JS/Jest／Dart/Flutter／跨語言）」，反映該檔已涵蓋 Dart/Flutter D 系列與跨語言 E 系列
**Version**: 1.2.0 — 第 2 輪審查：三問「確定性」對應標籤由「環境依賴」改為「確定性失效」（類型 5-6 屬設計族）。1.1.0：F2-F5 修正（第 1 輪審查）
**Last Updated**: 2026-09-14
