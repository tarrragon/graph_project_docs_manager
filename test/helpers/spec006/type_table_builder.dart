/// 最小型別表建構器（SPEC-006-test-design.md §1.4「最小型別表建構器」）。
///
/// 以宣告方式建出含指定路徑模式、具體度、完整性集合、`id_pattern` 的
/// [TypeTable]，供 S1～S5、C3、C5、C6 等測試群組各自獨立建構所需 fixture，
/// 不共享 mutable 狀態。
library;

import 'package:graph_project_docs_manager/schema/type_table.dart';

/// 單一路徑模式規格，交給 [TypeTableBuilder.addType] 使用。
class PathPatternSpec {
  const PathPatternSpec({required this.pattern, required this.specificity});

  final String pattern;

  /// `[literalSegmentCount, crossSegmentWildcardCount]`。
  final List<int> specificity;
}

/// 建構最小 [TypeTable] fixture。
class TypeTableBuilder {
  final Map<String, NodeTypeEntry> _entries = <String, NodeTypeEntry>{};

  /// 新增一個型別條目。
  ///
  /// [carrierPathPatterns] 不傳（保持 `null`）代表型別表中不帶
  /// `carrier_path_patterns` 欄位，該型別不參與路徑比對（FR-06 規則 3、
  /// SPEC-006 D9）；傳入空清單則代表欄位存在但沒有任何模式，同樣永遠
  /// 不會命中，但仍計入「有此欄位」的型別集合。
  TypeTableBuilder addType(
    String name, {
    List<PathPatternSpec>? carrierPathPatterns,
    String? idPattern,
    Set<String>? completenessFields,
  }) {
    _entries[name] = NodeTypeEntry(
      name: name,
      carrierPathPatterns: carrierPathPatterns
          ?.map(
            (spec) => CarrierPathPattern(
              pattern: spec.pattern,
              specificity: spec.specificity,
            ),
          )
          .toList(growable: false),
      idPattern: idPattern,
      completenessFields: completenessFields ?? const <String>{},
    );
    return this;
  }

  /// 產出不可變的 [TypeTable]。
  TypeTable build() => TypeTable(Map.unmodifiable(_entries));
}
