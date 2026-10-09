/// 邊型表建構器（SPEC-007-test-design.md §1.4）。
///
/// 以宣告方式建出含指定邊型與版本的型別表 JSON（頂層 `Map`），供 S6、
/// G1～G9 各自獨立建構 fixture，不共享 mutable 狀態。
library;

/// 單一邊型宣告。[forwardCardinality] 為 `null` 時 JSON 不帶該欄位。
class EdgeSpec {
  const EdgeSpec({
    required this.forwardField,
    this.edgeClass = 'see-also',
    this.reverseField,
    this.forwardCardinality = 'many',
    this.layer = 'established',
    this.direction,
  });

  final String forwardField;
  final String edgeClass;
  final String? reverseField;
  final String? forwardCardinality;
  final String layer;

  /// `directed`／`undirected`；`null` 時 JSON 不帶 `direction` 欄。
  final String? direction;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'class': edgeClass,
    'forward_field': forwardField,
    'reverse_field': reverseField,
    'layer': layer,
    'forward_cardinality': ?forwardCardinality,
    'direction': ?direction,
  };
}

/// 建出型別表 JSON。[edges] 為 `null` 時不帶 `edge_types` 鍵（缺席）；
/// 恆帶只含 `SPEC` 的 `node_types`，使表可被節點解碼消費。
Map<String, dynamic> buildEdgeTableJson({
  String? version,
  Map<String, EdgeSpec>? edges,
}) {
  return <String, dynamic>{
    'schema_generated_at_framework_version': ?version,
    'node_types': <String, dynamic>{
      'SPEC': <String, dynamic>{'id_pattern': r'^SPEC-\d+$'},
    },
    if (edges != null)
      'edge_types': <String, dynamic>{
        for (final entry in edges.entries) entry.key: entry.value.toJson(),
      },
  };
}
