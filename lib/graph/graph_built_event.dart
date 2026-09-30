/// EVT-GRAPH-001 GraphBuilt 與建圖結果型別（SPEC-007 FR-01～FR-06：建圖不可用、缺陷、邊、事件）。
library;

import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

enum DirectedDeclarationShape { fromOnly, toOnly, both }

/// 一條邊。有向邊 `from`→`to`；無向邊（`association`，FR-05〈無向的判定〉）
/// `from`／`to` 依 `String.compareTo`（UTF-16 碼元序；ID 為 ASCII 時等同
/// 字典序）排序，不代表方向。
class GraphEdge {
  const GraphEdge({
    required this.edgeType,
    required this.from,
    required this.to,
    required this.declaredBy,
    required this.isUndirected,
  });

  final String edgeType;
  final String from;
  final String to;

  /// 宣告來源：端點 ID 集合。
  final Set<String> declaredBy;
  final bool isUndirected;

  /// 有向邊的宣告來源形態。
  DirectedDeclarationShape get directedShape {
    final fromDeclared = declaredBy.contains(from);
    final toDeclared = declaredBy.contains(to);
    if (fromDeclared && toDeclared) return DirectedDeclarationShape.both;
    return fromDeclared
        ? DirectedDeclarationShape.fromOnly
        : DirectedDeclarationShape.toOnly;
  }
}

/// `multiSource` 的一個終點與其宣告來源。
class MultiSourceTarget {
  const MultiSourceTarget({required this.to, required this.declaredBy});

  final String to;
  final Set<String> declaredBy;
}

/// EVT-GRAPH-001 `graphDefects` 的一筆缺陷。
sealed class GraphDefect {
  const GraphDefect();
}

class DanglingRefGraphDefect extends GraphDefect {
  const DanglingRefGraphDefect(this.detail);
  final DanglingRef detail;
}

class MalformedRefGraphDefect extends GraphDefect {
  const MalformedRefGraphDefect(this.detail);
  final MalformedRef detail;
}

class DuplicateIdGraphDefect extends GraphDefect {
  const DuplicateIdGraphDefect(this.detail);
  final DuplicateIdDefect detail;
}

/// 正向基數為 `one` 的邊型，一個起點經聯集指向兩個以上不同終點。
class MultiSourceGraphDefect extends GraphDefect {
  const MultiSourceGraphDefect({
    required this.from,
    required this.edgeType,
    required this.targets,
  });

  final String from;
  final String edgeType;
  final List<MultiSourceTarget> targets;
}

/// EVT-GRAPH-001：`nodeCount`、`edgeCount`、`graphDefects`，另帶驗證用明細。
class GraphBuiltEvent {
  const GraphBuiltEvent({
    required this.nodes,
    required this.edges,
    required this.graphDefects,
    required this.totalReferences,
    required this.resolvedCount,
  });

  final List<LightNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphDefect> graphDefects;
  final int totalReferences;
  final int resolvedCount;

  int get nodeCount => nodes.length;
  int get edgeCount => edges.length;

  int _countOf<T extends GraphDefect>() => graphDefects.whereType<T>().length;

  int get danglingRefCount => _countOf<DanglingRefGraphDefect>();
  int get malformedRefCount => _countOf<MalformedRefGraphDefect>();
  int get duplicateIdCount => _countOf<DuplicateIdGraphDefect>();
  int get multiSourceCount => _countOf<MultiSourceGraphDefect>();

  /// 各邊型的邊數。
  Map<String, int> get edgesByType {
    final result = <String, int>{};
    for (final edge in edges) {
      result[edge.edgeType] = (result[edge.edgeType] ?? 0) + 1;
    }
    return result;
  }

  /// 有向邊各宣告來源形態的邊數。
  Map<DirectedDeclarationShape, int> get directedShapeCounts => {
    for (final shape in DirectedDeclarationShape.values)
      shape: edges
          .where((e) => !e.isUndirected && e.directedShape == shape)
          .length,
  };

  /// 無向邊：一端。
  int get undirectedOneEndCount =>
      edges.where((e) => e.isUndirected && e.declaredBy.length == 1).length;

  /// 無向邊：兩端。
  int get undirectedBothCount =>
      edges.where((e) => e.isUndirected && e.declaredBy.length == 2).length;
}

/// 建圖入口結果：可用（帶事件）或不可用（帶原因碼，不產生 `graphDefect`）。
sealed class GraphBuildResult {
  const GraphBuildResult();
}

class GraphBuildAvailable extends GraphBuildResult {
  const GraphBuildAvailable(this.event);
  final GraphBuiltEvent event;
}

class GraphBuildUnavailable extends GraphBuildResult {
  const GraphBuildUnavailable(this.reason);
  final EdgeTypeUnavailableReason reason;
}
