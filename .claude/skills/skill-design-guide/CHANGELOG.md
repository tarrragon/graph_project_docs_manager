# skill-design-guide 版本紀錄

新到舊。版號規則與兩個住址（本檔與 `SKILL.md` frontmatter 的 `metadata.version`）見專案的 skill 同步規範。

**Version**: 1.3.0 — §1.2 第 2 層體量判準由行數改為字元數。原表列兩個判準「< 5k tokens（< 500 行）」而 Action 只綁行數，於是實際生效的是括號裡那個代理指標。查證官方 spec：Level 2 逐字為 "Under 5k tokens"，全篇未給任何行數限制——「< 500 行」是本地自創且未標出處的代理指標。行數對繁中散文失效，因每行字元數無上界：一份實測 skill 為 245 行（通過行數門檻）但 15,015 字元（超標 2.31 倍），最長單行 548 字。新門檻 6,500 字元 = 5k tokens × 框架既有校準係數 1.3 chars/token（`file-size-guardian-hook.py` 的 `CHARS_PER_TOKEN`，2026-06-12 以 `/context` 實測校準，非自創公式）。條文另載明本層零執法的事實（`SCAN_CONFIG` 涵蓋 pm-rules / rules / references，不含 skills；`skill-description-length-check-hook.py` 只查第 1 層 description），執法層建置與存量收斂已於消費端各建票承接。以新門檻量測一個 58 檔的 skill 庫：29 檔超標，本檔自身 15,237 字元亦在其中（2.34 倍）
**Last Updated**: 2026-09-04

**Version**: 1.2.0 — 新增 §6.4「外部引用：指名身分，不用檔案路徑」（skill 用名字走 Skill 工具載入、方法論與規則用標題檢索），含判別問句「讀者是要去讀它學東西，還是要寫進它讓別的東西動起來」與兩類正當例外（框架綁定工具講自己的主題、介面規格）。§6.3 補一行界定其適用範圍為 skill 目錄內的相對路徑。§12 Body 檢查清單補對應機械檢查。實證：框架改版移動 hook 位置使舊路徑註冊全數失效；skill-sync 可攜性閘門把兩份 skill 的 25 處路徑判為指名他專案的檔案而中止 push
**Last Updated**: 2026-04-30

**Version**: 1.1.0 — §1.4 新增 Opinionated Defaults 設計心法（通用原則路由 `rules/core/opinionated-default-design.md`）

**Source**: Anthropic 官方 skill-creator（`~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/`）+ 官方平台文件 + Claude Code 擴展規範 + 本專案實踐
