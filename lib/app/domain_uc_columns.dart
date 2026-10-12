/// Domain 視圖矩陣的 UC 欄集合與欄序，以及 flow 解析失敗 UC 的對應
/// （0.5.0-W1-114.14，SPEC-001 v1.47 §1〈矩陣的 UC 欄〉）。
///
/// 純函式：不讀檔、不碰 provider。
library;

import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart'
    show FlowParseFailedEvent;
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart'
    show flowSourceTypeName;
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';

final RegExp _trailingDigits = RegExp(r'(\d+)$');

/// 需求：[SPEC-001 §1 矩陣的 UC 欄] 欄集合取圖上全部 UC 型別節點；欄序依
/// UC id 結尾連續數字的整數值遞增，數值相同依 id 的 code point 序，結尾無數字
/// 者接在最後、彼此依 code point 序。
List<String> orderedUcColumnIds(Iterable<LightNode> nodes) {
  final ids = [
    for (final node in nodes)
      if (node.typeName == flowSourceTypeName) node.id,
  ];
  ids.sort(_compareUcIds);
  return ids;
}

int _compareUcIds(String a, String b) {
  final numberA = _trailingNumber(a);
  final numberB = _trailingNumber(b);
  if (numberA == null && numberB == null) return a.compareTo(b);
  if (numberA == null) return 1;
  if (numberB == null) return -1;
  final byNumber = numberA.compareTo(numberB);
  return byNumber != 0 ? byNumber : a.compareTo(b);
}

/// 結尾連續數字的整數值；以 [BigInt] 比較，避免超長數字溢位。
BigInt? _trailingNumber(String id) {
  final match = _trailingDigits.firstMatch(id);
  return match == null ? null : BigInt.parse(match.group(1)!);
}

/// 需求：[SPEC-001 §1 flow 區塊解析失敗的泳道呈現] 將 EVT-CORPUS-004 的
/// `path` 對應到同路徑的 UC 節點 id；找不到對應節點的事件不列入。
Set<String> flowParseFailedUcIdsOf({
  required Iterable<FlowParseFailedEvent> failedEvents,
  required GraphBuiltEvent event,
}) {
  final paths = {for (final failed in failedEvents) failed.path};
  return {
    for (final node in event.nodes)
      if (node.typeName == flowSourceTypeName && paths.contains(node.path))
        node.id,
  };
}
