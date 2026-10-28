/// Domain 視圖的 providers。
///
/// [domainViewStateProvider] 為狀態注入點：gate 偵測與資料載入
/// （`app/domain_view_loader.dart`，0.5.0-W1-114.14）寫入真實狀態，測試以
/// `overrideWith` 切換至其餘十個狀態，畫面直接渲染。矩陣
/// （[domainMatrixProvider]）與泳道（[domainSwimlaneProvider]）同讀
/// `lastCompletedRoundProvider`（同一專案最後完成的掃描輪次，0.5.0-W1-205.2.1）。
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

/// 最後完成輪次的建圖事件；無完成輪次或建圖不可用時為 `null`。
GraphBuiltEvent? _eventOf(ScanRoundResult? round) {
  final graph = round?.graph;
  return graph is GraphBuildAvailable ? graph.event : null;
}

/// 最後完成輪次建圖不可用（SPEC-001 §1「圖不可用」列，`0.5.0-W1-486.2`）：
/// 有完成輪次且其建圖結果為 [GraphBuildUnavailable] 時為真；無完成輪次為假
/// （該情況走泳道投影準備中）。矩陣與泳道兩模式共用此判定。
final domainGraphUnavailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(lastCompletedRoundProvider)?.graph is GraphBuildUnavailable,
);

/// 矩陣投影（SPEC-001 §1〈矩陣與泳道同由掃描輪次衍生〉）：讀同一專案最後完成
/// 的輪次；無輪次、建圖不可用或無節點時為 `null`。
final domainMatrixProvider = Provider<DomainMatrix?>((ref) {
  final event = _eventOf(ref.watch(lastCompletedRoundProvider));
  if (event == null || event.nodes.isEmpty) return null;
  return projectDomainMatrix(
    event: event,
    ucIds: orderedUcColumnIds(event.nodes),
  );
});

/// 未選定 UC 的空泳道列結構；無完成輪次時僅有「畫面」列。
final domainEmptyLanesProvider = Provider<List<DomainLane>>((ref) {
  final event = _eventOf(ref.watch(lastCompletedRoundProvider));
  if (event == null) {
    return const [
      DomainLane(domainId: null, kind: DomainLaneKind.screen, nodes: []),
    ];
  }
  return projectEmptyLanes(event);
});

/// Layout 公開面「給定一列，回傳欄號最小的節點」查詢（SPEC-001 §1 跳轉目標，
/// L9）；測試以 `overrideWith` 注入替身。預設依最後完成輪次的建圖結果計算。
typedef FirstNodeInLaneQuery = LayoutNode? Function(String ucId, String domain);

final firstNodeInLaneQueryProvider = Provider<FirstNodeInLaneQuery>((ref) {
  return (ucId, domain) {
    final event = _eventOf(ref.read(lastCompletedRoundProvider));
    if (event == null) return null;
    return firstNodeInLaneOf(event: event, ucId: ucId, domain: domain);
  };
});

/// 選定 UC 的泳道投影；未選定 UC、尚無完成輪次或建圖不可用時為 `null`。
/// 建圖不可用時畫面不讀本 provider，改落「圖不可用」列（見
/// [domainGraphUnavailableProvider]、SPEC-001 §1〈FR-13 回傳「圖不可用」時的
/// Domain 視圖呈現〉）。讀最後完成輪次，故重掃期間照常顯示上一輪。
final domainSwimlaneProvider = Provider<DomainSwimlaneView?>((ref) {
  final ucId = ref.watch(selectedUcProvider);
  final round = ref.watch(lastCompletedRoundProvider);
  final event = _eventOf(round);
  if (ucId == null || round == null || event == null) return null;
  return projectDomainSwimlane(
    event: event,
    ucId: ucId,
    flowParseFailedUcIds: flowParseFailedUcIdsOf(
      failedEvents: round.scan.flowParseFailedEvents,
      event: event,
    ),
  );
});
