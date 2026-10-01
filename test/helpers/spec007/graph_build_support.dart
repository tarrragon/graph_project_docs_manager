/// 建圖測試共用入口（W2-004）。
///
/// 與 `known_distribution_fixture.dart` 分開：後者被 G1～G3 既有測試引用，
/// 不可依賴尚在建構中的建圖入口。
library;

import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import 'known_distribution_fixture.dart';

/// 以型別表 JSON（缺省為內建表）建圖，回傳 EVT-GRAPH-001；圖不可用時測試失敗。
GraphBuiltEvent buildGraphEvent(
  List<RawNode> rawNodes, [
  Map<String, dynamic>? schemaJson,
]) {
  final result = buildGraph(
    rawNodes: rawNodes,
    projectSchemaJson: schemaJson ?? loadBuiltinSchemaJson(),
    builtinSchemaJson: loadBuiltinSchemaJson(),
  );
  return (result as GraphBuildAvailable).event;
}

/// 邊的比對鍵：`type|from|to|宣告來源（排序後逗號串接）`。
Set<String> edgeKeys(GraphBuiltEvent event) => {
  for (final e in event.edges)
    '${e.edgeType}|${e.from}|${e.to}|${(e.declaredBy.toList()..sort()).join(',')}',
};

/// 守恆式：總數 = 解析成功 + 斷邊 + 格式錯誤。
bool conservationHolds({
  required int total,
  required int resolved,
  required int dangling,
  required int malformed,
}) => total == resolved + dangling + malformed;
