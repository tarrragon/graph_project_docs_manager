/// 最近專案計數快照的寫入者（SPEC-005 §2.4〈計數快照〉）。
///
/// 每輪掃描完成（[scanRoundProvider] 進入 [ScanRoundCompleted]）時，以
/// `result.workspacePath` 寫入該專案的 `counts`，並同步
/// [recentProjectsProvider]；失敗、取消、進行中的輪次不寫入。寫入失敗不呈現
/// 於畫面，只進日誌（level 900），呼叫端不重試。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/app_log_event.dart';
import 'package:graph_project_docs_manager/app/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/app/round_gaps.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/node_type_names.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// 需求：[SPEC-005 §2.4 計數快照] 輪次結果 → 三個計數。
///
/// `issueCount` 取 [gapItemIdsOf] 的集合大小，與破洞報告畫面項數同一定義。
RecentProjectCounts recentProjectCountsOf(ScanRoundResult round) =>
    RecentProjectCounts(
      nodeCount: round.scan.summary.nodeCount,
      ticketCount: round.scan.rawNodes
          .where((node) => node.typeName == ticketTypeName)
          .length,
      issueCount: gapItemIdsOf(round).length,
    );

/// 掛載後監聽輪次完成並寫入快照；由 `AppShell` 於啟動時 `read` 一次。
final recentProjectCountsWriterProvider = Provider<void>((ref) {
  ref.listen<ScanRoundState>(scanRoundProvider, (_, next) {
    if (next is ScanRoundCompleted) {
      unawaited(_persistCounts(ref, next.result));
    }
  });
});

/// 需求：[SPEC-005 §2.4 計數快照] 加入清單後補寫最近完成輪次。
///
/// 首次開啟的專案首輪可能先於 `addRecentProject` 完成而落空；加入成功後由
/// 呼叫端呼叫本函式，最近完成輪次的 `workspacePath` 與 [path] 相同才補寫。
Future<void> backfillRecentProjectCounts(Ref ref, String path) async {
  final round = ref.read(lastCompletedRoundProvider);
  if (round == null || round.workspacePath != path) return;
  await _persistCounts(ref, round);
}

Future<void> _persistCounts(Ref ref, ScanRoundResult round) async {
  final counts = recentProjectCountsOf(round);
  final repository = ref.read(workspaceRepositoryProvider);
  final saved = await repository.saveRecentProjectCounts(
    round.workspacePath,
    counts,
  );
  if (!saved || !ref.mounted) return;
  _syncProvider(ref, round.workspacePath, counts);
}

void _syncProvider(Ref ref, String path, RecentProjectCounts counts) {
  final notifier = ref.read(recentProjectsProvider.notifier);
  notifier.state = [
    for (final project in notifier.state)
      project.path == path ? project.withCounts(counts) : project,
  ];
  appLogSink(
    AppLogEvent.recentProjectCountsSynced,
    LogFields.empty,
    level: LogLevel.debug,
  );
}
