/// 需求：[SPEC-007 FR-09；test-design §3.4 D3]
/// Diagnostics 由 `EVT-GRAPH-001` 的 `graphDefects` 產生 `graphDefect` 破洞。
///
/// 只依賴 `lib/graph/` 的事件型別與 Diagnostics 自有型別，不得 import
/// `lib/schema/`（test-design §1.3）。
library;

import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import 'parse_failure_gap.dart';

/// `graphDefect` 破洞的子類（子類清單以 SPEC-007 FR-09〈子類〉為準）。
enum GraphDefectKind { danglingRef, malformedRef, duplicateId, multiSource }

/// 一筆 `graphDefect` 破洞的共同基底；負載只含原因碼與原始值，
/// 不含顯示文字（顯示由畫面經 l10n 投影）。
sealed class GraphDefectGap {
  const GraphDefectGap();

  /// 破洞類別，恆為 [GapCategory.graphDefect]。
  GapCategory get category => GapCategory.graphDefect;

  GraphDefectKind get kind;
}

/// `danglingRef`／`malformedRef`：來源節點、路徑、欄位、原始值、邊型、原因碼。
class RefGraphDefectGap extends GraphDefectGap {
  const RefGraphDefectGap({
    required this.kind,
    required this.sourceId,
    required this.path,
    required this.fieldName,
    required this.rawValue,
    required this.edgeType,
    required this.reason,
  });

  @override
  final GraphDefectKind kind;
  final String sourceId;
  final String path;
  final String fieldName;

  /// 原始值原樣，不正規化。
  final Object? rawValue;
  final String edgeType;

  /// 原因碼（資料值）。
  final String reason;
}

/// `duplicateId`：ID 與全部路徑。
class DuplicateIdGraphDefectGap extends GraphDefectGap {
  const DuplicateIdGraphDefectGap({required this.id, required this.paths});

  @override
  GraphDefectKind get kind => GraphDefectKind.duplicateId;
  final String id;
  final List<String> paths;
}

/// `multiSource`：起點、邊型、全部終點與各自的宣告來源。
class MultiSourceGraphDefectGap extends GraphDefectGap {
  const MultiSourceGraphDefectGap({
    required this.from,
    required this.edgeType,
    required this.targets,
  });

  @override
  GraphDefectKind get kind => GraphDefectKind.multiSource;
  final String from;
  final String edgeType;
  final List<MultiSourceTarget> targets;
}

/// 一輪 `graphDefect` 偵測結果（sealed）：可用為 [GraphDefectsDetected]，
/// 建圖不可用為 [GraphDefectUndetermined]。
sealed class GraphDefectGapResult {
  const GraphDefectGapResult();
}

class GraphDefectsDetected extends GraphDefectGapResult {
  const GraphDefectsDetected(this.gaps);

  /// 可為空清單（零筆缺陷）。
  final List<GraphDefectGap> gaps;
}

/// 建圖不可用時的「無法判定破洞」回報，不產生任何 `graphDefect`。
class GraphDefectUndetermined extends GraphDefectGapResult {
  const GraphDefectUndetermined({required this.reason});

  final UndeterminedGapReason reason;
}

/// `graphDefect` 偵測的輸入（sealed）：建圖可用帶事件、不可用帶原因，
/// 兩種狀態互斥，非法組合（兩者皆無）在型別上不可表達。
///
/// 由 Diagnostics 自有；schema 原因碼轉換屬編排層。
sealed class GraphDefectInput {
  const GraphDefectInput();
}

class GraphDefectInputAvailable extends GraphDefectInput {
  const GraphDefectInputAvailable(this.event);

  final GraphBuiltEvent event;
}

class GraphDefectInputUnavailable extends GraphDefectInput {
  const GraphDefectInputUnavailable(this.reason);

  final UndeterminedGapReason reason;
}

/// 需求：[SPEC-007 FR-09〈規則〉] 一筆缺陷一筆破洞。
///
/// 不可用輸入回傳 [GraphDefectUndetermined]，不產生任何 `graphDefect`。
GraphDefectGapResult detectGraphDefectGaps(GraphDefectInput input) =>
    switch (input) {
      GraphDefectInputUnavailable(:final reason) => GraphDefectUndetermined(
        reason: reason,
      ),
      GraphDefectInputAvailable(:final event) => GraphDefectsDetected([
        for (final defect in event.graphDefects) _toGap(defect),
      ]),
    };

GraphDefectGap _toGap(GraphDefect defect) => switch (defect) {
  DanglingRefGraphDefect(:final detail) => RefGraphDefectGap(
    kind: GraphDefectKind.danglingRef,
    sourceId: detail.ref.sourceId,
    path: detail.ref.sourcePath,
    fieldName: detail.ref.fieldName,
    rawValue: detail.ref.value,
    edgeType: detail.ref.edgeTypeName,
    reason: detail.reason.name,
  ),
  MalformedRefGraphDefect(:final detail) => RefGraphDefectGap(
    kind: GraphDefectKind.malformedRef,
    sourceId: detail.ref.sourceId,
    path: detail.ref.sourcePath,
    fieldName: detail.ref.fieldName,
    rawValue: detail.ref.value,
    edgeType: detail.ref.edgeTypeName,
    reason: detail.reason.name,
  ),
  DuplicateIdGraphDefect(:final detail) => DuplicateIdGraphDefectGap(
    id: detail.id,
    paths: detail.paths,
  ),
  MultiSourceGraphDefect(:final from, :final edgeType, :final targets) =>
    MultiSourceGraphDefectGap(from: from, edgeType: edgeType, targets: targets),
};
