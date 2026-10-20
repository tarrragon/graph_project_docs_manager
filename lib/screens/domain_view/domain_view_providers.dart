/// Domain 視圖的 providers。
///
/// [domainViewStateProvider] 為狀態注入點：gate 偵測與資料載入
/// （`app/domain_view_loader.dart`，0.5.0-W1-114.14）寫入真實狀態，測試以
/// `overrideWith` 切換至其餘十個狀態，畫面直接渲染。[domainSwimlaneProvider]
/// 依選定 UC 與共用掃描輪次投影泳道。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/domain_uc_columns.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';

import 'domain_view_projection.dart';
import 'domain_view_state.dart';

/// 目前畫面狀態；預設 `DomainLoading`：App 啟動到 restore 完成前不顯示
/// fixture 矩陣（0.5.0-W3-003），由 shell 啟動流程寫入真實狀態。
final domainViewStateProvider = StateProvider<DomainViewState>(
  (ref) => const DomainLoading(),
);

/// Layout 公開面「給定一列，回傳欄號最小的節點」查詢（SPEC-001 §1 跳轉目標，
/// L9）；測試以 `overrideWith` 注入替身。預設依共用掃描輪次的建圖結果計算。
typedef FirstNodeInLaneQuery = LayoutNode? Function(String ucId, String domain);

final firstNodeInLaneQueryProvider = Provider<FirstNodeInLaneQuery>((ref) {
  return (ucId, domain) {
    final round = ref.read(scanRoundProvider);
    if (round is! ScanRoundCompleted) return null;
    final graph = round.result.graph;
    if (graph is! GraphBuildAvailable) return null;
    return firstNodeInLaneOf(event: graph.event, ucId: ucId, domain: domain);
  };
});

/// 選定 UC 的泳道投影；未選定 UC、輪次尚未完成或建圖不可用時為 `null`
/// （建圖不可用時 Domain 視圖不會進入，見 SPEC-001 §1〈FR-13 回傳「圖不可用」
/// 時 Layout 不另處理〉）。選定 UC 或輪次變更時隨之重算。
final domainSwimlaneProvider = Provider<DomainSwimlaneView?>((ref) {
  final ucId = ref.watch(selectedUcProvider);
  final round = ref.watch(scanRoundProvider);
  if (ucId == null || round is! ScanRoundCompleted) return null;
  final graph = round.result.graph;
  if (graph is! GraphBuildAvailable) return null;
  return projectDomainSwimlane(
    event: graph.event,
    ucId: ucId,
    flowParseFailedUcIds: flowParseFailedUcIdsOf(
      failedEvents: round.result.scan.flowParseFailedEvents,
      event: graph.event,
    ),
  );
});
