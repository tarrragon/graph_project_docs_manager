/// EVT-GRAPH-001 GraphBuilt 與建圖結果型別（SPEC-007 FR-01～FR-06：建圖不可用、缺陷、邊、事件）。
library;

import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

enum DirectedDeclarationShape { fromOnly, toOnly, both }

/// 一條邊。有向邊 `from`→`to`；無向邊（型別表 `direction` 為 `undirected`，FR-05〈無向的判定〉）
/// `from`／`to` 依 `String.compareTo`（UTF-16 碼元序；ID 為 ASCII 時等同
/// 字典序）排序，不代表方向。
class GraphEdge {
  GraphEdge({
    required this.edgeType,
    required this.from,
    required this.to,
    required Set<String> declaredBy,
    required this.isUndirected,
  }) : declaredBy = Set.unmodifiable(declaredBy);

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
  MultiSourceTarget({required this.to, required Set<String> declaredBy})
    : declaredBy = Set.unmodifiable(declaredBy);

  final String to;
  final Set<String> declaredBy;
}

/// EVT-GRAPH-001 `graphDefects` 的一筆缺陷。
sealed class GraphDefect {
  const GraphDefect();
}

/// 斷邊：引用值合乎格式但目標不存在或重複。
class DanglingRefGraphDefect extends GraphDefect {
  const DanglingRefGraphDefect({required this.ref, required this.reason});
  final ReferenceValue ref;
  final DanglingReason reason;
}

/// 格式錯誤的引用值。
class MalformedRefGraphDefect extends GraphDefect {
  const MalformedRefGraphDefect({required this.ref, required this.reason});
  final ReferenceValue ref;
  final MalformedReason reason;
}

/// 同一 `id` 出現在兩個以上 rawNode。
class DuplicateIdGraphDefect extends GraphDefect {
  DuplicateIdGraphDefect({required this.id, required List<String> paths})
    : paths = List.unmodifiable(paths);
  final String id;
  final List<String> paths;
}

/// 正向基數為 `one` 的邊型，一個起點經聯集指向兩個以上不同終點。
class MultiSourceGraphDefect extends GraphDefect {
  MultiSourceGraphDefect({
    required this.from,
    required this.edgeType,
    required List<MultiSourceTarget> targets,
  }) : targets = List.unmodifiable(targets);

  final String from;
  final String edgeType;
  final List<MultiSourceTarget> targets;
}

/// EVT-GRAPH-001：`nodeCount`、`edgeCount`、`graphDefects`，另帶驗證用明細。
///
/// 建構時複製為唯讀集合；計數與分佈在首次讀取時只走訪一次並快取。
class GraphBuiltEvent {
  GraphBuiltEvent({
    required List<LightNode> nodes,
    required List<GraphEdge> edges,
    required List<GraphDefect> graphDefects,
    required this.totalReferences,
    required this.resolvedCount,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       graphDefects = List.unmodifiable(graphDefects);

  final List<LightNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphDefect> graphDefects;
  final int totalReferences;
  final int resolvedCount;

  int get nodeCount => nodes.length;
  int get edgeCount => edges.length;

  late final int danglingRefCount = _countOf<DanglingRefGraphDefect>();
  late final int malformedRefCount = _countOf<MalformedRefGraphDefect>();
  late final int duplicateIdCount = _countOf<DuplicateIdGraphDefect>();
  late final int multiSourceCount = _countOf<MultiSourceGraphDefect>();

  int _countOf<T extends GraphDefect>() => graphDefects.whereType<T>().length;

  /// 各邊型的邊數（唯讀）。
  late final Map<String, int> edgesByType = _countEdgesByType();

  /// 有向邊各宣告來源形態的邊數（唯讀）。
  late final Map<DirectedDeclarationShape, int> directedShapeCounts =
      _countDirectedShapes();

  /// 無向邊：一端。
  late final int undirectedOneEndCount = _countUndirected(1);

  /// 無向邊：兩端。
  late final int undirectedBothCount = _countUndirected(2);

  Map<String, int> _countEdgesByType() {
    final result = <String, int>{};
    for (final edge in edges) {
      result[edge.edgeType] = (result[edge.edgeType] ?? 0) + 1;
    }
    return Map.unmodifiable(result);
  }

  Map<DirectedDeclarationShape, int> _countDirectedShapes() {
    final result = {for (final s in DirectedDeclarationShape.values) s: 0};
    for (final edge in edges) {
      if (edge.isUndirected) continue;
      result[edge.directedShape] = result[edge.directedShape]! + 1;
    }
    return Map.unmodifiable(result);
  }

  int _countUndirected(int endCount) => edges
      .where((e) => e.isUndirected && e.declaredBy.length == endCount)
      .length;
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
