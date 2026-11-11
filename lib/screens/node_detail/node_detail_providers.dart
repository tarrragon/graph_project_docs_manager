/// 節點詳情的資料來源與狀態注入點（0.5.0-W1-114.25）。
///
/// 節點資料預設由共用掃描輪次（`scanRoundProvider`）的建圖結果投影；
/// [NodeDetailFixtures] 只供測試以 `overrideWithValue` 注入。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:graph_project_docs_manager/corpus/frontmatter_classifier.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/jump_targets.dart';
import '../../app/scan_round.dart';
import '../../graph/adjacency_query.dart';
import '../../graph/graph_built_event.dart';
import '../../workspace/current_workspace_provider.dart';
import '../../workspace/open_path_resolver.dart';
import 'node_detail_fixtures.dart';
import 'node_detail_state.dart';

/// 目前畫面狀態；預設 `NodeDetailUnset`（未選節點）。測試以 `overrideWith`
/// 切換至其餘狀態。
final NotifierProvider<StateHolder<NodeDetailState>, NodeDetailState>
nodeDetailStateProvider = stateHolderProvider<NodeDetailState>((ref) {
  ref.read(nodeDetailTargetSyncProvider);
  return const NodeDetailUnset();
});

/// 需求：[SPEC-003 §3.5] 消費跳轉意圖（`nodeDetailTargetProvider`）：有目標即
/// 轉為 [NodeDetailReady] 並清空意圖。由 [nodeDetailStateProvider] 初始化時
/// 啟動；測試覆寫狀態 provider 時可直接讀本 provider。
final nodeDetailTargetSyncProvider = Provider<void>((ref) {
  void apply() {
    final id = ref.read(nodeDetailTargetProvider);
    if (id == null) return;
    ref.read(nodeDetailStateProvider.notifier).state = NodeDetailReady(
      nodeId: id,
    );
    ref.read(nodeDetailTargetProvider.notifier).state = null;
  }

  ref.listen<String?>(nodeDetailTargetProvider, (_, _) => apply());
  Future.microtask(() {
    if (ref.mounted) apply();
  });
});

/// 需求：[SPEC-001 §6] 判定順序 2、4：在 [nodeDetailStateProvider] 之上衍生
/// 「圖不可用」「節點不在目前的圖上」。無完成輪次時不判定（沿用原狀態）。
final nodeDetailEffectiveStateProvider = Provider<NodeDetailState>((ref) {
  return deriveNodeDetailState(
    base: ref.watch(nodeDetailStateProvider),
    graph: ref.watch(lastCompletedRoundProvider)?.graph,
    nodeIds: ref.watch(nodeDetailNodesProvider).keys,
  );
});

/// [nodeDetailEffectiveStateProvider] 的純函式本體。
NodeDetailState deriveNodeDetailState({
  required NodeDetailState base,
  required GraphBuildResult? graph,
  required Iterable<String> nodeIds,
}) {
  if (base is NodeDetailProjectUnready || graph == null) return base;
  if (graph is GraphBuildUnavailable) return const NodeDetailGraphUnavailable();
  if (base is NodeDetailReady && !nodeIds.contains(base.nodeId)) {
    return NodeDetailNodeAbsent(nodeId: base.nodeId);
  }
  return base;
}

/// 節點 id → 詳情資料（不含內文）；讀同一專案最後完成的輪次（0.6.0-W1-109，
/// SPEC-003 §3.6 掃描輪次更新列），重掃期間保留上一輪，新輪次完成後替換，
/// 切換專案時清除。無完成輪次或建圖不可用時為空。
final nodeDetailNodesProvider = Provider<Map<String, NodeDetailFixture>>((ref) {
  final round = ref.watch(lastCompletedRoundProvider);
  if (round == null) return const {};
  final graph = round.graph;
  if (graph is! GraphBuildAvailable) return const {};
  return projectNodeDetails(graph.event);
});

/// 需求：[SPEC-001 §6 主欄分隔線上下的內容] 選定節點的本文：fixture 自帶內文
/// 優先；否則只讀該節點一個檔案，取 frontmatter 結尾分隔線之後的內容
/// （切分委由 Corpus 的 [bodyLinesAfterFrontmatter]，本層不另寫切分）。
/// 讀取或切分失敗回傳 `null`，由畫面層改放 `nodeDetailBodyUnavailableMessage`。
final nodeDetailBodyProvider = Provider.family<String?, String>((ref, nodeId) {
  final node = ref.watch(nodeDetailNodesProvider)[nodeId];
  if (node == null) return '';
  if (node.markdown.isNotEmpty) return node.markdown;
  final path = resolveOpenPath(
    ref.watch(currentWorkspaceStateProvider),
    node.filePath,
  );
  return path == null ? null : _readBodyOrNull(path);
});

String? _readBodyOrNull(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return bodyLinesAfterFrontmatter(file.readAsBytesSync())?.join('\n');
  } on FileSystemException catch (error) {
    developer.log(
      '節點本文讀取失敗：$path（$error）', // i18n-exempt: 開發者診斷 log
      name: 'node_detail',
      level: 900,
    );
    return null;
  }
}

/// 需求：[SPEC-001 §6] 由建圖結果投影節點詳情；關聯依邊型分節（語意約定
/// 3：不同邊型不合併），每節 `isProposed` 取該邊型 layer。內文延遲讀取。
Map<String, NodeDetailFixture> projectNodeDetails(GraphBuiltEvent event) {
  final query = AdjacencyQuery(buildResult: GraphBuildAvailable(event));
  return {
    for (final node in event.nodes)
      node.id: NodeDetailFixture(
        id: node.id,
        type: node.typeName,
        status: node.status ?? '',
        title: node.displayTitle,
        filePath: node.path,
        markdown: '',
        relations: _categoriesOf(_relatedOf(query, node.id)),
      ),
  };
}

/// 由鄰接查詢取該節點的相鄰節點，依 (邊型, layer) 分組並去重。
Map<(String, String), Set<String>> _relatedOf(
  AdjacencyQuery query,
  String nodeId,
) {
  final byType = <(String, String), Set<String>>{};
  final result = query.query(nodeId);
  if (result is! AdjacencyAvailable) return byType;
  for (final entry in result.entries) {
    byType
        .putIfAbsent((entry.edgeType, entry.layer), () => {})
        .add(entry.otherId);
  }
  return byType;
}

List<NodeRelationCategory> _categoriesOf(
  Map<(String, String), Set<String>> byType,
) {
  final keys = byType.keys.toList()
    ..sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
  return [
    for (final key in keys)
      NodeRelationCategory(
        label: key.$1,
        nodeIds: byType[key]!.toList()..sort(),
        isProposed: key.$2 == 'proposed',
      ),
  ];
}
