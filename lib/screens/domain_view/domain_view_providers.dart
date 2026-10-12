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

import 'domain_view_projection.dart';
import 'domain_view_state.dart';

/// 目前畫面狀態；預設 `DomainReady`（矩陣模式，無選格、無降級旗標）。
final domainViewStateProvider = StateProvider<DomainViewState>(
  (ref) => const DomainReady(mode: DomainMode.matrix),
);

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
