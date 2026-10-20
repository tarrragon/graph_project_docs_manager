/// 節點詳情的資料來源與狀態注入點（0.5.0-W1-114.25）。
///
/// 節點資料預設由共用掃描輪次（`scanRoundProvider`）的建圖結果投影；
/// [NodeDetailFixtures] 只供測試以 `overrideWithValue` 注入。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/scan_round.dart';
import '../../graph/graph_built_event.dart';
import '../../workspace/current_workspace_provider.dart';
import '../../workspace/open_path_resolver.dart';
import 'node_detail_fixtures.dart';
import 'node_detail_state.dart';

/// 目前畫面狀態；預設 `NodeDetailReady`（正常態，
/// [NodeDetailFixtures.normalNodeId]）。測試以 `overrideWith` 切換至其餘
/// 四個狀態。
final nodeDetailStateProvider = StateProvider<NodeDetailState>(
  (ref) => const NodeDetailReady(nodeId: NodeDetailFixtures.normalNodeId),
);

/// 節點 id → 詳情資料（不含內文）；輪次未完成或建圖不可用時為空。
final nodeDetailNodesProvider = Provider<Map<String, NodeDetailFixture>>((ref) {
  final round = ref.watch(scanRoundProvider);
  if (round is! ScanRoundCompleted) return const {};
  final graph = round.result.graph;
  if (graph is! GraphBuildAvailable) return const {};
  return projectNodeDetails(graph.event);
});

/// 選定節點的內文：fixture 自帶內文優先；否則只讀該節點一個檔案，
/// 讀不到退回 `# 標題`。
final nodeDetailBodyProvider = Provider.family<String, String>((ref, nodeId) {
  final node = ref.watch(nodeDetailNodesProvider)[nodeId];
  if (node == null) return '';
  if (node.markdown.isNotEmpty) return node.markdown;
  final path = resolveOpenPath(
    ref.watch(currentWorkspaceStateProvider),
    node.filePath,
  );
  final file = path == null ? null : File(path);
  if (file != null && file.existsSync()) return file.readAsStringSync();
  return '# ${node.title}';
});

/// 需求：[SPEC-001 §6] 由建圖結果投影節點詳情；關聯依邊型分節（語意約定
/// 3：不同邊型不合併），每節 `isProposed` 取該邊型 layer。內文延遲讀取。
Map<String, NodeDetailFixture> projectNodeDetails(GraphBuiltEvent event) {
  final related = <String, Map<(String, String), Set<String>>>{};
  void add(String node, GraphEdge edge, String other) {
    related
        .putIfAbsent(node, () => {})
        .putIfAbsent((edge.edgeType, edge.layer), () => {})
        .add(other);
  }

  for (final edge in event.edges) {
    add(edge.from, edge, edge.to);
    add(edge.to, edge, edge.from);
  }
  return {
    for (final node in event.nodes)
      node.id: NodeDetailFixture(
        id: node.id,
        type: node.typeName,
        status: node.status ?? '',
        title: node.displayTitle,
        filePath: node.path,
        markdown: '',
        relations: _categoriesOf(related[node.id] ?? const {}),
      ),
  };
}

List<NodeRelationCategory> _categoriesOf(
  Map<(String, String), Set<String>> byType,
) {
  final keys = byType.keys.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [
    for (final key in keys)
      NodeRelationCategory(
        label: key.$1,
        nodeIds: byType[key]!.toList()..sort(),
        isProposed: key.$2 == 'proposed',
      ),
  ];
}
