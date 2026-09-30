/// SPEC-007 FR-03 引用值抽取：依使用中邊型的正反向欄位逐項抽出引用值。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// 單一節點、單一欄位中的單一項。
class ReferenceValue {
  const ReferenceValue({
    required this.sourceId,
    required this.sourcePath,
    required this.edgeTypeName,
    required this.fieldName,
    required this.isReverse,
    required this.value,
    required this.isShapeValid,
  });

  final String sourceId;
  final String sourcePath;
  final String edgeTypeName;
  final String fieldName;

  /// 取自反向欄位（含 map 反向欄位的子鍵清單項）。
  final bool isReverse;

  /// 原始值原樣保留；形狀不合法時可能不是字串。
  final Object? value;

  /// `false` 代表形狀不合法（歸 `invalidShape`）。
  final bool isShapeValid;
}

/// 需求：[SPEC-007 FR-03] 對一個節點抽出全部引用值。
List<ReferenceValue> extractReferenceValues({
  required RawNode node,
  required String sourceId,
  required Iterable<EdgeTypeEntry> edgeTypes,
}) {
  final result = <ReferenceValue>[];
  for (final edge in edgeTypes) {
    _extractField(result, node, sourceId, edge, edge.forwardField, false);
    final reverse = edge.reverseField;
    if (reverse != null) {
      _extractField(result, node, sourceId, edge, reverse, true);
    }
  }
  return result;
}

bool _isAbsent(Object? raw) =>
    raw == null || raw == '' || (raw is List && raw.isEmpty);

void _extractField(
  List<ReferenceValue> out,
  RawNode node,
  String sourceId,
  EdgeTypeEntry edge,
  String field,
  bool isReverse,
) {
  final raw = node.frontmatter[field];
  if (_isAbsent(raw)) {
    return;
  }
  ReferenceValue make(Object? value, bool valid) => ReferenceValue(
    sourceId: sourceId,
    sourcePath: node.path,
    edgeTypeName: edge.name,
    fieldName: field,
    isReverse: isReverse,
    value: value,
    isShapeValid: valid,
  );
  if (raw is Map && isReverse) {
    for (final sub in raw.values) {
      _addSubkeyValues(out, sub, make);
    }
    return;
  }
  _addValues(out, raw, make);
}

/// map 反向欄位的子鍵值必須是清單；非清單（含字串）計為一個 `invalidShape`。
void _addSubkeyValues(
  List<ReferenceValue> out,
  Object? sub,
  ReferenceValue Function(Object? value, bool valid) make,
) {
  if (_isAbsent(sub)) {
    return;
  }
  if (sub is List) {
    _addValues(out, sub, make);
  } else {
    out.add(make(sub, false));
  }
}

void _addValues(
  List<ReferenceValue> out,
  Object? raw,
  ReferenceValue Function(Object? value, bool valid) make,
) {
  if (_isAbsent(raw)) {
    return;
  }
  if (raw is String) {
    out.add(make(raw, true));
  } else if (raw is List) {
    for (final item in raw.where((item) => item != null)) {
      out.add(make(item, item is String));
    }
  } else {
    out.add(make(raw, false));
  }
}
