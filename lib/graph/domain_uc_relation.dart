/// SPEC-007 FR-12 domain × UC 關係與依賴路徑（Graph 公開面）。
///
/// 判定式權威：SPEC-001 §1〈間接依賴判定式〉〈間接依賴格的詳情卡：依賴路徑〉。
/// 排序依據取自 FR-13（[orderBundlesOf]），不依賴 Layout。
library;

import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

/// 格 (DomainBundle, UC) 的關係種類。
enum DomainUcRelationKind { direct, indirect, unrelated }

/// FR-12 查詢結果：關係（含依賴路徑）或圖不可用，兩者可窮舉區分。
sealed class DomainUcRelationResult {
  const DomainUcRelationResult();
}

class DomainUcRelationAvailable extends DomainUcRelationResult {
  DomainUcRelationAvailable(
    this.kind, [
    List<List<DomainBundleRef>> paths = const [],
  ]) : paths = List<List<DomainBundleRef>>.unmodifiable([
         for (final p in paths) List<DomainBundleRef>.unmodifiable(p),
       ]);

  final DomainUcRelationKind kind;

  /// 間接依賴時的依賴路徑（每條為來源到目標的 DomainBundle 序列）；
  /// 直接貫穿與無關時為空。
  final List<List<DomainBundleRef>> paths;
}

/// 建圖不可用或尚未完成；[reasonCode] 與鄰接查詢的原因碼同義。
class DomainUcRelationGraphUnavailable extends DomainUcRelationResult {
  const DomainUcRelationGraphUnavailable(this.cause, this.reasonCode);

  final AdjacencyUnavailableCause cause;
  final String reasonCode;
}

/// 需求：[SPEC-007 FR-12] Graph 公開面 `relationOf(bundleId, ucId)`。
///
/// DomainBundle 或 UC 的 ID 不在圖上時，回傳無關且路徑為空（NC-5，比照 FR-08）。
class DomainUcRelationQuery {
  const DomainUcRelationQuery({required this.buildResult});

  final GraphBuildResult? buildResult;

  DomainUcRelationResult relationOf(String bundleId, String ucId) =>
      switch (buildResult) {
        GraphBuildAvailable(:final event) => _relation(event, bundleId, ucId),
        GraphBuildUnavailable(:final reason) =>
          DomainUcRelationGraphUnavailable(
            AdjacencyUnavailableCause.buildUnavailable,
            reason.name,
          ),
        null => DomainUcRelationGraphUnavailable(
          AdjacencyUnavailableCause.buildNotCompleted,
          AdjacencyUnavailableCause.buildNotCompleted.name,
        ),
      };
}

DomainUcRelationAvailable _relation(
  GraphBuiltEvent event,
  String bundleId,
  String ucId,
) {
  final known = event.domainResolver.domainOf(bundleId) != null;
  final direct = _directBundles(event, ucId);
  if (!known || direct.isEmpty) {
    return DomainUcRelationAvailable(DomainUcRelationKind.unrelated);
  }
  if (direct.contains(bundleId)) {
    return DomainUcRelationAvailable(DomainUcRelationKind.direct);
  }
  final paths = _dependencyPaths(event, bundleId, direct);
  return DomainUcRelationAvailable(
    paths.isEmpty
        ? DomainUcRelationKind.unrelated
        : DomainUcRelationKind.indirect,
    paths,
  );
}

/// UC 直接貫穿的 DomainBundle：只取 FR-11 解析成功的值。
Set<String> _directBundles(GraphBuiltEvent event, String ucId) => {
  for (final step in event.flowSubgraphs[ucId]?.steps ?? const [])
    for (final r in step.traversesResolution.resolved) r.bundleId,
};

/// 需求：[SPEC-007 FR-12] 每個來源取最短路徑、同長全列、排除經直接 domain 的路徑，
/// 依長度、來源在 FR-13 的先後、中間節點在 FR-13 的先後排序。
List<List<DomainBundleRef>> _dependencyPaths(
  GraphBuiltEvent event,
  String target,
  Set<String> direct,
) {
  final ordered = orderBundlesOf(event);
  final rank = {
    for (var i = 0; i < ordered.length; i++) ordered[i].bundleId: i,
  };
  final byId = {for (final e in ordered) e.bundleId: e};
  final out = <String, List<String>>{};
  final deps = bundleDependenciesOf(event);
  for (final d in deps) {
    out.putIfAbsent(d.from, () => []).add(d.to);
  }
  final distance = _distancesTo(target, deps);
  final paths = <List<String>>[
    for (final source in direct)
      if (distance.containsKey(source))
        ..._shortestPaths(
          source,
          target,
          out,
          distance,
        ).where((p) => !p.sublist(1, p.length - 1).any(direct.contains)),
  ]..sort((a, b) => _comparePaths(a, b, rank));
  return [
    for (final p in paths) [for (final id in p) byId[id]!],
  ];
}

/// 自 [target] 沿依賴邊反向廣度優先，得各節點到 [target] 的最短跳數。
Map<String, int> _distancesTo(String target, List<BundleDependency> deps) {
  final incoming = <String, List<String>>{};
  for (final d in deps) {
    incoming.putIfAbsent(d.to, () => []).add(d.from);
  }
  final distance = {target: 0};
  final queue = [target];
  for (var i = 0; i < queue.length; i++) {
    for (final prev in incoming[queue[i]] ?? const <String>[]) {
      if (!distance.containsKey(prev)) {
        distance[prev] = distance[queue[i]]! + 1;
        queue.add(prev);
      }
    }
  }
  return distance;
}

/// [source] 到 [target] 的全部最短路徑（每步距離恰減 1）。
List<List<String>> _shortestPaths(
  String source,
  String target,
  Map<String, List<String>> out,
  Map<String, int> distance,
) {
  if (source == target) {
    return [
      [target],
    ];
  }
  return [
    for (final next in out[source] ?? const <String>[])
      if (distance[next] == distance[source]! - 1)
        for (final rest in _shortestPaths(next, target, out, distance))
          [source, ...rest],
  ];
}

int _comparePaths(List<String> a, List<String> b, Map<String, int> rank) {
  if (a.length != b.length) return a.length.compareTo(b.length);
  for (var i = 0; i < a.length - 1; i++) {
    final c = rank[a[i]]!.compareTo(rank[b[i]]!);
    if (c != 0) return c;
  }
  return 0;
}
