/// SPEC-007 FR-10 Graph 公開面 `flowOf(ucId)`。
library;

import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';

/// `flowOf` 結果：子圖、不存在、圖不可用三者可窮舉區分。
sealed class FlowOfResult {
  const FlowOfResult();
}

class FlowOfAvailable extends FlowOfResult {
  const FlowOfAvailable(this.subgraph);
  final FlowSubgraph subgraph;
}

/// UC ID 不在圖上、或不是 UC。
class FlowOfNotFound extends FlowOfResult {
  const FlowOfNotFound();
}

/// 建圖不可用或尚未完成；[reasonCode] 與鄰接查詢的日誌原因碼同義。
class FlowOfGraphUnavailable extends FlowOfResult {
  const FlowOfGraphUnavailable(this.cause, this.reasonCode);
  final AdjacencyUnavailableCause cause;
  final String reasonCode;
}

/// 需求：[SPEC-007 FR-10] Graph 公開面 `flowOf(ucId)`。
///
/// [buildResult] 為 null 代表尚未完成建圖。圖不可用時，與 FR-08 同形：同一
/// buildResult 只記一次 [GraphLogEvent.flowUnavailable]；buildResult 為 null
/// 時以實例為單位。
class FlowQuery {
  FlowQuery({required this.buildResult, GraphLogSink? logSink})
    : _log = logSink ?? defaultGraphLogSink;

  final GraphBuildResult? buildResult;
  final GraphLogSink _log;
  bool _nullLogged = false;
  static final Expando<bool> _loggedBuilds = Expando<bool>('flowLogged');

  FlowOfResult flowOf(String ucId) => switch (buildResult) {
    GraphBuildAvailable(:final event) => _lookup(event, ucId),
    GraphBuildUnavailable(:final reason) => _unavailable(
      FlowOfGraphUnavailable(
        AdjacencyUnavailableCause.buildUnavailable,
        reason.name,
      ),
    ),
    null => _unavailable(
      FlowOfGraphUnavailable(
        AdjacencyUnavailableCause.buildNotCompleted,
        AdjacencyUnavailableCause.buildNotCompleted.name,
      ),
    ),
  };

  FlowOfResult _lookup(GraphBuiltEvent event, String ucId) {
    final subgraph = event.flowSubgraphs[ucId];
    return subgraph == null
        ? const FlowOfNotFound()
        : FlowOfAvailable(subgraph);
  }

  FlowOfGraphUnavailable _unavailable(FlowOfGraphUnavailable result) {
    if (_markLogged(buildResult)) {
      _log(
        'flow query unavailable: ${result.reasonCode}', // i18n-exempt: debug log
        event: GraphLogEvent.flowUnavailable,
        payload: {GraphLogKeys.reason: result.reasonCode},
        level: 900,
      );
    }
    return result;
  }

  /// 回傳 true 代表此單位尚未記過，並登記為已記。
  bool _markLogged(GraphBuildResult? result) {
    if (result == null) {
      final first = !_nullLogged;
      _nullLogged = true;
      return first;
    }
    if (_loggedBuilds[result] == true) return false;
    _loggedBuilds[result] = true;
    return true;
  }
}
