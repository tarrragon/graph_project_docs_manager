/// SPEC-007 FR-08 鄰接查詢（Graph 公開面）。
library;

import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

/// 查詢方向篩選。
enum AdjacencyDirection { out, incoming, both }

/// 結果項目的方向：出、入或無向。
enum AdjacencyEntryDirection { out, incoming, undirected }

/// 一筆相鄰關係。
class AdjacencyEntry {
  AdjacencyEntry({
    required this.edgeType,
    required this.otherId,
    required this.direction,
    required Set<String> declaredBy,
  }) : declaredBy = Set.unmodifiable(declaredBy);

  final String edgeType;
  final String otherId;
  final AdjacencyEntryDirection direction;
  final Set<String> declaredBy;
}

/// 圖不可用的成因。
enum AdjacencyUnavailableCause { buildNotCompleted, buildUnavailable }

/// 查詢結果：可用（含空清單）或圖不可用，兩者可窮舉區分。
sealed class AdjacencyResult {
  const AdjacencyResult();
}

/// 查過的結果；空清單表示「沒有相鄰節點」。
class AdjacencyAvailable extends AdjacencyResult {
  AdjacencyAvailable(List<AdjacencyEntry> entries)
    : entries = List.unmodifiable(entries);
  final List<AdjacencyEntry> entries;
}

/// 圖不可用；兩個子類各自攜帶成因，不合法的成因組合無法建構。
sealed class AdjacencyUnavailable extends AdjacencyResult {
  const AdjacencyUnavailable();

  /// 成因分類。
  AdjacencyUnavailableCause get cause;

  /// 日誌原因碼。
  String get reasonCode;
}

/// 尚未完成建圖；沒有邊型原因。
class AdjacencyBuildNotCompleted extends AdjacencyUnavailable {
  const AdjacencyBuildNotCompleted();

  @override
  AdjacencyUnavailableCause get cause =>
      AdjacencyUnavailableCause.buildNotCompleted;

  @override
  String get reasonCode => cause.name;
}

/// 建圖不可用；必帶邊型原因。
class AdjacencyBuildUnavailable extends AdjacencyUnavailable {
  const AdjacencyBuildUnavailable(this.edgeTypeReason);
  final EdgeTypeUnavailableReason edgeTypeReason;

  @override
  AdjacencyUnavailableCause get cause =>
      AdjacencyUnavailableCause.buildUnavailable;

  @override
  String get reasonCode => edgeTypeReason.name;
}

/// 需求：[SPEC-007 FR-08] 1 hop 鄰接查詢。
///
/// [buildResult] 為 null 代表尚未完成建圖。圖不可用時，同一 buildResult
/// 只記一次「鄰接查詢圖不可用」日誌（L3）；buildResult 為 null 時以實例為單位。
class AdjacencyQuery {
  AdjacencyQuery({required this.buildResult, GraphLogSink? logSink})
    : _log = logSink ?? defaultGraphLogSink {
    final result = buildResult;
    if (result is GraphBuildAvailable) {
      _index = _indexByEndpoint(result.event.edges);
    }
  }

  final GraphBuildResult? buildResult;
  final GraphLogSink _log;
  Map<String, List<GraphEdge>> _index = const {};
  bool _nullLogged = false;
  static final Expando<bool> _loggedBuilds = Expando<bool>('adjacencyLogged');

  /// 邊型缺省為全部使用中邊型，方向缺省為兩者。
  AdjacencyResult query(
    String nodeId, {
    Set<String>? edgeTypes,
    AdjacencyDirection direction = AdjacencyDirection.both,
  }) {
    return switch (buildResult) {
      GraphBuildAvailable() => AdjacencyAvailable([
        for (final edge in _index[nodeId] ?? const <GraphEdge>[])
          if (edgeTypes == null || edgeTypes.contains(edge.edgeType))
            ..._entriesOf(edge, nodeId, direction),
      ]),
      GraphBuildUnavailable(:final reason) => _unavailable(
        AdjacencyBuildUnavailable(reason),
      ),
      null => _unavailable(const AdjacencyBuildNotCompleted()),
    };
  }

  AdjacencyUnavailable _unavailable(AdjacencyUnavailable unavailable) {
    if (_markLogged(buildResult)) {
      _log(
        'adjacency query unavailable: ${unavailable.reasonCode}', // i18n-exempt: debug log
        event: GraphLogEvent.adjacencyUnavailable,
        payload: {GraphLogKeys.reason: unavailable.reasonCode},
        level: 900,
      );
    }
    return unavailable;
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

/// 依端點建索引；保留邊在原清單的相對順序，自環只入索引一次。
Map<String, List<GraphEdge>> _indexByEndpoint(List<GraphEdge> edges) {
  final index = <String, List<GraphEdge>>{};
  for (final edge in edges) {
    index.putIfAbsent(edge.from, () => []).add(edge);
    if (edge.to != edge.from) {
      index.putIfAbsent(edge.to, () => []).add(edge);
    }
  }
  return index;
}

Iterable<AdjacencyEntry> _entriesOf(
  GraphEdge edge,
  String nodeId,
  AdjacencyDirection direction,
) sync* {
  final isFrom = edge.from == nodeId;
  final isTo = edge.to == nodeId;
  if (edge.isUndirected) {
    if (isFrom || isTo) {
      yield _entry(
        edge,
        isFrom ? edge.to : edge.from,
        AdjacencyEntryDirection.undirected,
      );
    }
    return;
  }
  final wantsOut = direction != AdjacencyDirection.incoming;
  final wantsIncoming = direction != AdjacencyDirection.out;
  if (isFrom && wantsOut) {
    yield _entry(edge, edge.to, AdjacencyEntryDirection.out);
  }
  if (isTo && wantsIncoming) {
    yield _entry(edge, edge.from, AdjacencyEntryDirection.incoming);
  }
}

AdjacencyEntry _entry(
  GraphEdge edge,
  String otherId,
  AdjacencyEntryDirection direction,
) => AdjacencyEntry(
  edgeType: edge.edgeType,
  otherId: otherId,
  direction: direction,
  declaredBy: edge.declaredBy,
);
