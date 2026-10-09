/// SPEC-007 FR-13 DomainBundle 分層與層內排序（Graph 公開面）。
///
/// Layout 的泳道列序與 FR-12 的依賴路徑排序共用這一份。依賴方向：只依賴
/// Graph 自身的建圖結果，不依賴 layout／screens／components。
library;

import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

/// 依賴邊的邊型名（型別表 `bundle_dependency`）。
const bundleDependencyEdgeType = 'bundle_dependency';

/// 一個 DomainBundle：節點 ID 與 `domain` 宣告字面（供取回原值，Graph 不產生顯示字串）。
class DomainBundleRef {
  const DomainBundleRef({required this.bundleId, required this.domain});

  final String bundleId;
  final String domain;
}

/// FR-13 回傳的單項：排序後的 bundle，附層號（推不出層者為 null）。
///
/// 呼叫端以 `(domain: e.domain, layer: e.layer)` 無損轉成 Layout 使用的
/// `({String domain, int? layer})`。
class BundleLayerEntry extends DomainBundleRef {
  const BundleLayerEntry({
    required super.bundleId,
    required super.domain,
    required this.layer,
  });

  final int? layer;
}

/// `bundle_dependency` 依賴邊（依賴者 → 被依賴者），端點皆為 DomainBundle 節點 ID。
typedef BundleDependency = ({String from, String to});

/// FR-13 查詢結果：排序清單或圖不可用，兩者可窮舉區分。
sealed class BundleOrderResult {
  const BundleOrderResult();
}

class BundleOrderAvailable extends BundleOrderResult {
  BundleOrderAvailable(List<BundleLayerEntry> entries)
    : entries = List.unmodifiable(entries);

  /// 依層遞增、同層依 `domain` code point 序；推不出層者（層號 null）接在最後。
  final List<BundleLayerEntry> entries;
}

/// 建圖不可用或尚未完成；[reasonCode] 與鄰接查詢的原因碼同義。
class BundleOrderGraphUnavailable extends BundleOrderResult {
  const BundleOrderGraphUnavailable(this.cause, this.reasonCode);

  final AdjacencyUnavailableCause cause;
  final String reasonCode;
}

/// 需求：[SPEC-007 FR-13] Graph 公開面 `orderedBundles()`。
///
/// [buildResult] 為 null 代表尚未完成建圖。
class BundleLayerQuery {
  const BundleLayerQuery({required this.buildResult});

  final GraphBuildResult? buildResult;

  BundleOrderResult orderedBundles() => switch (buildResult) {
    GraphBuildAvailable(:final event) => BundleOrderAvailable(
      orderBundlesOf(event),
    ),
    GraphBuildUnavailable(:final reason) => BundleOrderGraphUnavailable(
      AdjacencyUnavailableCause.buildUnavailable,
      reason.name,
    ),
    null => BundleOrderGraphUnavailable(
      AdjacencyUnavailableCause.buildNotCompleted,
      AdjacencyUnavailableCause.buildNotCompleted.name,
    ),
  };
}

/// 以 Unicode code point 逐字元比較（不依 locale，也不是 UTF-16 碼元序）。
int compareCodePoints(String a, String b) {
  final ra = a.runes.iterator;
  final rb = b.runes.iterator;
  while (true) {
    final hasA = ra.moveNext();
    final hasB = rb.moveNext();
    if (!hasA || !hasB) return hasA == hasB ? 0 : (hasA ? 1 : -1);
    if (ra.current != rb.current) return ra.current.compareTo(rb.current);
  }
}

/// 全部有字串 `domain` 的 DomainBundle（重複宣告者各自成列）。
List<DomainBundleRef> bundleRefsOf(GraphBuiltEvent event) => [
  for (final id in event.domainResolver.bundleIds)
    DomainBundleRef(bundleId: id, domain: event.domainResolver.domainOf(id)!),
];

/// 兩端皆為 DomainBundle 的 `bundle_dependency` 邊。
List<BundleDependency> bundleDependenciesOf(GraphBuiltEvent event) {
  final ids = event.domainResolver.bundleIds.toSet();
  return [
    for (final e in event.edges)
      if (e.edgeType == bundleDependencyEdgeType &&
          ids.contains(e.from) &&
          ids.contains(e.to))
        (from: e.from, to: e.to),
  ];
}

/// 依賴推不出層的 bundle 起點：依賴指向未宣告的節點（斷邊，或邊的終點不是 DomainBundle）。
Set<String> _brokenDependents(GraphBuiltEvent event) {
  final ids = event.domainResolver.bundleIds.toSet();
  return {
    for (final d in event.graphDefects.whereType<DanglingRefGraphDefect>())
      if (d.ref.edgeTypeName == bundleDependencyEdgeType) d.ref.sourceId,
    for (final e in event.edges)
      if (e.edgeType == bundleDependencyEdgeType &&
          ids.contains(e.from) &&
          !ids.contains(e.to))
        e.from,
  };
}

/// 分層 1a：無出邊為 L0，其餘為所依賴 bundle 的最大層 + 1；
/// 環、依賴指向未宣告、依賴推不出層者皆無層（不在回傳 map 內）。
Map<String, int> _layersOf(
  Set<String> bundleIds,
  List<BundleDependency> deps,
  Set<String> broken,
) {
  final targets = <String, Set<String>>{
    for (final id in bundleIds) id: <String>{},
  };
  for (final d in deps) {
    targets[d.from]!.add(d.to);
  }
  final layers = <String, int>{};
  var progressed = true;
  while (progressed) {
    progressed = false;
    for (final id in bundleIds) {
      final layer = layers.containsKey(id) || broken.contains(id)
          ? null
          : _layerIfReady(targets[id]!, layers);
      if (layer != null) {
        layers[id] = layer;
        progressed = true;
      }
    }
  }
  return layers;
}

/// 所依賴者全部已有層才算得出本身的層；否則 null。
int? _layerIfReady(Set<String> targets, Map<String, int> layers) {
  if (!targets.every(layers.containsKey)) return null;
  return targets.isEmpty
      ? 0
      : targets.map((t) => layers[t]!).reduce((a, b) => a > b ? a : b) + 1;
}

int _compareEntries(BundleLayerEntry a, BundleLayerEntry b) {
  final la = a.layer;
  final lb = b.layer;
  if (la != lb) {
    if (la == null) return 1;
    if (lb == null) return -1;
    return la.compareTo(lb);
  }
  final byDomain = compareCodePoints(a.domain, b.domain);
  return byDomain != 0 ? byDomain : a.bundleId.compareTo(b.bundleId);
}

/// 需求：[SPEC-007 FR-13] 由已完成的建圖事件算出分層與排序。
List<BundleLayerEntry> orderBundlesOf(GraphBuiltEvent event) {
  final refs = bundleRefsOf(event);
  final layers = _layersOf(
    {for (final r in refs) r.bundleId},
    bundleDependenciesOf(event),
    _brokenDependents(event),
  );
  return [
    for (final r in refs)
      BundleLayerEntry(
        bundleId: r.bundleId,
        domain: r.domain,
        layer: layers[r.bundleId],
      ),
  ]..sort(_compareEntries);
}
