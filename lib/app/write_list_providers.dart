/// 寫入清單的讀取端 provider（1.0.0-W3-553.17）。
///
/// 清單資料由 Edit domain 的寫入路徑自動追加（`SessionWriteList`，
/// SPEC-009 FR-08），本檔只讀取並在清單變動時重建，不寫入。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/edit/session_write_list.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

/// 本 session 寫入清單的列（發出順序，舊的在前）；工作區未就緒時為空。
/// 清單內容或某列驗證狀態變動時重建，不論面板是否開啟。
final writeListEntriesProvider = Provider<List<WriteListEntry>>((ref) {
  final list = ref.watch(editWorkspaceProvider).value?.writeList;
  if (list == null) return const [];
  final subscription = list.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);
  return list.entries;
});

/// 工作區相對路徑 → 節點 id，取最近完成輪次的建圖結果；建圖不可用或尚無
/// 輪次時為空（列的路徑不渲染為可點，SPEC-003 §3.12）。
final writeListNodeIdByPathProvider = Provider<Map<String, String>>((ref) {
  final graph = ref.watch(lastCompletedRoundProvider)?.graph;
  if (graph is! GraphBuildAvailable) return const {};
  return {for (final node in graph.event.nodes) node.path: node.id};
});

/// 需求：[SPEC-001 §12] 失敗計數：寫入結果是 `blocked`、`ioFailed`，或驗證
/// 狀態為 `failed`、`unavailable` 的列數；寫入中與 `written` 的未失敗列不計。
final writeListFailureCountProvider = Provider<int>((ref) {
  return ref.watch(writeListEntriesProvider).where(_isFailure).length;
});

bool _isFailure(WriteListEntry entry) {
  if (entry.result is Blocked || entry.result is IoFailed) return true;
  return switch (entry.validationStatus) {
    ValidationFailed() || ValidationUnavailable() => true,
    _ => false,
  };
}
