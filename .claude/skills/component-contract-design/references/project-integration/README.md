# 本專案外部資產的實際位置

本 skill 宣告 `metadata.portable: true`，同層 `references/addresses.md` 因此不得指名特定專案的檔案路徑（`.claude/references/reference-stability-rules.md` 規則 8）。但「方法論」與「元件庫規格範本」兩項是本 skill 判準與產物形狀的實際來源，總得有處寫下它們在**本專案**的位置，才不會讓查表者查到一句空話。本目錄依專案既有慣例（`wrap-decision` skill 已建立同名目錄）承接這個位置，並依該慣例排除於 skill-sync push，不隨 skill 本體同步到其他 consumer。

## 依賴方向

`references/addresses.md` 不得引用本目錄（那會讓通用地址表反過來綁死單一專案）；本目錄引用 `addresses.md` 的簡稱作為上游定義，方向單向。

## 本專案的實際地址

| 簡稱 | 本專案的實際地址 |
|------|----------------|
| 方法論 | `.claude/methodologies/component-library-bidirectional-constraint-methodology.md` |
| 元件庫規格範本 | 源檔 `.claude/skills/doc/templates/component-library-spec-template.md`；副本在專案 spec 目錄 |

## 其他專案沿用時

`addresses.md` 的「方法論」「元件庫規格範本」兩列地址欄指向本檔。沿用本 skill 的專案若也採用元件庫雙向約束方法論與對應範本，比照上表建立自己的 `project-integration/README.md`，兩列內容改指本專案的實際路徑；未採用者，該兩列的判準與產物形狀需自行提供等效資產。
