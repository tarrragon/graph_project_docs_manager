/// UC 本文建構器（SPEC-006-test-design.md §1.4「UC 本文建構器」）：以宣告
/// 方式組出「合法 UC frontmatter＋本文」位元組，依序放入任意個 fenced yaml
/// 區塊。供 C10-6、C10-7、C12、C13 使用。
///
/// 本檔的字串皆為測試 fixture 的 YAML 內容，非使用者可見字串。
library;

import 'dart:convert';

/// 合法 flow 區塊：步驟 id 依序為 [stepIds]。
String validFlowBlock(List<String> stepIds) {
  // i18n-exempt: 測試 fixture YAML
  final steps = [for (final id in stepIds) '  - id: $id\n    name: step $id']
      .join('\n');
  return 'flow:\n$steps'; // i18n-exempt: 測試 fixture YAML
}

/// 壞掉的 flow：頂層 `flow:` 行＋YAML 語法錯誤（未閉合引號）。
// i18n-exempt: 測試 fixture YAML
const String malformedFlowBlock = 'flow:\n  - id: "unterminated';

/// 壞掉的 flow（C13-6）：頂層 `flow:` 行在，其下步驟項縮排錯誤。
// i18n-exempt: 測試 fixture YAML
const String badIndentUnderFlowBlock =
    // i18n-exempt: 測試 fixture YAML
    'flow:\n  - id: s1\n   name: x\n  - id: s2';

/// 與 [badIndentUnderFlowBlock] 相同內容，只有第一行 `flow:` 多縮排兩格
/// （C13-7 已知限制的對照組）。
// i18n-exempt: 測試 fixture YAML
const String indentedFlowKeyBlock = '  $badIndentUnderFlowBlock';

/// 無 `flow` 鍵的合法 yaml。
// i18n-exempt: 測試 fixture YAML
const String noFlowKeyBlock = 'title: x\nitems:\n  - a';

/// YAML 語法錯誤、但沒有頂層 `flow:` 行（C13-4）。
// i18n-exempt: 測試 fixture YAML
const String malformedNonFlowBlock = 'steps:\n  - id: "unterminated';

/// 組出一份 UC 檔位元組：frontmatter `id: [id]`，本文依序放入 [blocks]
/// （每個為 fenced yaml 區塊內容）。
List<int> ucBytes({String id = 'UC-01', List<String> blocks = const []}) {
  // i18n-exempt: 測試 fixture markdown
  final body = [for (final block in blocks) '```yaml\n$block\n```']
      .join('\n\n');
  // i18n-exempt: 測試 fixture markdown
  return utf8.encode('---\nid: $id\n---\n\n# title\n\n$body\n');
}
