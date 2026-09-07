# 本專案外部資產的實際位置

本 skill 宣告 `metadata.portable: true`，同層 `references/addresses.md` 因此不得指名特定專案的檔案路徑（`.claude/references/reference-stability-rules.md` 規則 8）。但「方法論」與「元件庫規格範本」兩項是本 skill 判準與產物形狀的實際來源，總得有處寫下它們在**本專案**的位置，才不會讓查表者查到一句空話。本目錄依專案既有慣例（`wrap-decision` skill 已建立同名目錄）承接這個位置，並依該慣例排除於 skill-sync push，不隨 skill 本體同步到其他 consumer。

## 依賴方向

**實際方向**：`references/addresses.md` 引用本目錄——方法論、元件庫規格範本、agent 派發範本三列的地址欄皆帶「本專案的實際路徑見 `references/project-integration/README.md`」；本目錄則以 `addresses.md` 的簡稱作為上游定義。方向是雙向，不是單向。這是自 v1.5.3 建立本目錄起即成立的實作（見 CHANGELOG），非本次新增；本節原先宣告的反方向（`addresses.md` 不得引用本目錄，僅本目錄單向引用 `addresses.md`）與三次實作皆相反，從未被實作追上，判定為條文誤、實作對，故改本節而非回改 `addresses.md`。

**為何是條文錯而非實作錯**：地址表要對每個受管詞給出可查的地址，專案專屬路徑總得有處寫——由表指過去比讓讀者自行在專案內搜尋合理。真正需要守住的不變量不是「引用方向必須單向」，而是 `.claude/references/reference-stability-rules.md` 規則 8 禁止的「框架文件引用專案層級識別符」；`addresses.md` 三處引用的文字是本 skill 內部的相對路徑（`references/project-integration/README.md`），不含專案名稱或 ticket ID，規則 8 明列「框架檔案路徑」屬允許引用，不構成違反。回改為條文要求的單向，等於把三個受管詞唯一的地址來源拔掉，換來的是讀者自行摸路，不是可攜性收益——本目錄本身已依 `skill-sync` 慣例排除於 push，可攜性不受這個引用影響。

**是否需要執法層**：不需要。這條方向宣告從建立當下即與實作相反、三次未被任何機制擋下，但成本止於「文件內部敘述失準」——`addresses.md` 三處引用指向的檔案確實存在、讀者仍查得到地址，可攜性的實質不變量（規則 8：不得引用專案層級識別符）由 `reference-stability-rule8-guard-hook.py` 與 `skill-sync push` 的 portability gate 已經守住，且該 gate 確實掃描 `addresses.md`（只是不掃描本目錄，見 `skill-sync` SKILL.md「Consumer-specific passages belong in `references/project-integration/`, which the gate does not scan because sync excludes it」）。本次已把條文改到與實作一致，往後除非再新增受管詞且描述方式偏離現有三例，沒有第四次違反的空間；為一句已經對齊實作的敘述加執法層，防的是「文件描述可能再度寫錯」這種低頻率、低成本、且改一次就長期成立的風險，機制成本高於它能防的錯誤。

## 本專案的實際地址

| 簡稱 | 本專案的實際地址 |
|------|----------------|
| 方法論 | `.claude/methodologies/component-library-bidirectional-constraint-methodology.md` |
| 元件庫規格範本 | 源檔 `.claude/skills/doc/templates/component-library-spec-template.md`；副本在專案 spec 目錄 |
| agent 派發範本 | `.claude/references/agent-dispatch-template.md`（〈骨架（權威版）〉與〈Solution 自檢結果子章節義務〉兩節為 `dispatch-language.md`「派發 prompt 必含」列的權威） |

## 其他專案沿用時

`addresses.md` 的「方法論」「元件庫規格範本」「agent 派發範本」三列地址欄指向本檔。沿用本 skill 的專案若也採用元件庫雙向約束方法論與對應範本、且已有自己的 agent 派發範本，比照上表建立自己的 `project-integration/README.md`，三列內容改指本專案的實際路徑；未採用者，該三列的判準與產物形狀需自行提供等效資產。
