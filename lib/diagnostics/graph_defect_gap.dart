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

/// 一筆 `graphDefect` 破洞：直接承載 Graph 的缺陷（原因碼與原始值，
/// 不含顯示文字；顯示由畫面經 l10n 投影）。
class GraphDefectGap {
  const GraphDefectGap(this.defect);

  final GraphDefect defect;

  /// 破洞類別，恆為 [GapCategory.graphDefect]。
  GapCategory get category => GapCategory.graphDefect;

  /// 由 sealed [GraphDefect] 窮舉推導；新增缺陷子類時此 switch 編譯期報錯。
  GraphDefectKind get kind => switch (defect) {
    DanglingRefGraphDefect() => GraphDefectKind.danglingRef,
    MalformedRefGraphDefect() => GraphDefectKind.malformedRef,
    DuplicateIdGraphDefect() => GraphDefectKind.duplicateId,
    MultiSourceGraphDefect() => GraphDefectKind.multiSource,
  };
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
        for (final defect in event.graphDefects) GraphDefectGap(defect),
      ]),
    };
