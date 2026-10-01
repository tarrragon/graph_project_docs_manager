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

/// 圖不可用；[edgeTypeReason] 僅在建圖不可用時有值。
class AdjacencyUnavailable extends AdjacencyResult {
  const AdjacencyUnavailable({required this.cause, this.edgeTypeReason});
  final AdjacencyUnavailableCause cause;
  final EdgeTypeUnavailableReason? edgeTypeReason;

  /// 日誌原因碼。
  String get reasonCode => edgeTypeReason?.name ?? cause.name;
}

/// 需求：[SPEC-007 FR-08] 1 hop 鄰接查詢。
///
/// [buildResult] 為 null 代表尚未完成建圖。圖不可用時，同一實例只記一次
/// 「鄰接查詢圖不可用」日誌（L3）。
class AdjacencyQuery {
  AdjacencyQuery({required this.buildResult, GraphLogSink? logSink})
    : _log = logSink ?? defaultGraphLogSink;

  final GraphBuildResult? buildResult;
  final GraphLogSink _log;
  bool _unavailableLogged = false;

  /// 邊型缺省為全部使用中邊型，方向缺省為兩者。
  AdjacencyResult query(
    String nodeId, {
    Set<String>? edgeTypes,
    AdjacencyDirection direction = AdjacencyDirection.both,
  }) {
    final result = buildResult;
    if (result is! GraphBuildAvailable) {
      return _unavailable(result);
    }
    return AdjacencyAvailable([
      for (final edge in result.event.edges)
        if (edgeTypes == null || edgeTypes.contains(edge.edgeType))
          ..._entriesOf(edge, nodeId, direction),
    ]);
  }

  AdjacencyUnavailable _unavailable(GraphBuildResult? result) {
    final unavailable = AdjacencyUnavailable(
      cause: result == null
          ? AdjacencyUnavailableCause.buildNotCompleted
          : AdjacencyUnavailableCause.buildUnavailable,
      edgeTypeReason: result is GraphBuildUnavailable ? result.reason : null,
    );
    if (!_unavailableLogged) {
      _unavailableLogged = true;
      _log(
        'adjacency query unavailable: ${unavailable.reasonCode}', // i18n-exempt: debug log
        event: GraphLogEvent.adjacencyUnavailable,
        payload: {GraphLogKeys.reason: unavailable.reasonCode},
        level: 900,
      );
    }
    return unavailable;
  }
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
