/// SPEC-007 FR-12 domain × UC 關係與依賴路徑（Graph 公開面）。
///
/// 判定式權威：SPEC-001 §1〈間接依賴判定式〉〈間接依賴格的詳情卡：依賴路徑〉。
/// 排序依據取自 FR-13（[orderBundlesOf]），不依賴 Layout。
library;

import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/bundle_layer_order.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';

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
///
/// 圖不可用時，與 FR-08 同形：同一 buildResult 只記一次
/// [GraphLogEvent.domainUcRelationUnavailable]；buildResult 為 null 時以實例為單位。
class DomainUcRelationQuery {
  DomainUcRelationQuery({required this.buildResult, GraphLogSink? logSink})
    : _log = logSink ?? defaultGraphLogSink;

  final GraphBuildResult? buildResult;
  final GraphLogSink _log;
  final _once = UnavailableLogOnce(_loggedBuilds);
  static final Expando<bool> _loggedBuilds = Expando<bool>(
    'domainUcRelationLogged',
  );

  /// FR-13 排序、依賴索引只算一次；各目標的反向距離在首次查詢時快取。
  late final _BundleIndex? _index = switch (buildResult) {
    GraphBuildAvailable(:final event) => _BundleIndex(event),
    _ => null,
  };

  DomainUcRelationResult relationOf(String bundleId, String ucId) =>
      switch (buildResult) {
        GraphBuildAvailable() => _relation(_index!, bundleId, ucId),
        GraphBuildUnavailable(:final reason) => _unavailable(
          DomainUcRelationGraphUnavailable(
            AdjacencyUnavailableCause.buildUnavailable,
            reason.name,
          ),
        ),
        null => _unavailable(
          DomainUcRelationGraphUnavailable(
            AdjacencyUnavailableCause.buildNotCompleted,
            AdjacencyUnavailableCause.buildNotCompleted.name,
          ),
        ),
      };

  DomainUcRelationGraphUnavailable _unavailable(
    DomainUcRelationGraphUnavailable r,
  ) {
    if (_once.mark(buildResult)) {
      _log(
        'domain uc relation query unavailable: ${r.reasonCode}', // i18n-exempt: debug log
        event: GraphLogEvent.domainUcRelationUnavailable,
        payload: {GraphLogKeys.reason: r.reasonCode},
        level: 900,
      );
    }
    return r;
  }
}

/// 一次建好的 FR-13 排序與依賴鄰接表。
class _BundleIndex {
  _BundleIndex(this.event) {
    final ordered = orderBundlesOf(event);
    for (var i = 0; i < ordered.length; i++) {
      rank[ordered[i].bundleId] = i;
      byId[ordered[i].bundleId] = ordered[i];
    }
    for (final d in bundleDependenciesOf(event)) {
      out.putIfAbsent(d.from, () => []).add(d.to);
      incoming.putIfAbsent(d.to, () => []).add(d.from);
    }
  }

  final GraphBuiltEvent event;
  final rank = <String, int>{};
  final byId = <String, BundleLayerEntry>{};
  final out = <String, List<String>>{};
  final incoming = <String, List<String>>{};
}

DomainUcRelationAvailable _relation(
  _BundleIndex index,
  String bundleId,
  String ucId,
) {
  final event = index.event;
  final known = index.byId.containsKey(bundleId);
  final direct = _directBundles(event, ucId);
  if (!known || direct.isEmpty) {
    return DomainUcRelationAvailable(DomainUcRelationKind.unrelated);
  }
  if (direct.contains(bundleId)) {
    return DomainUcRelationAvailable(DomainUcRelationKind.direct);
  }
  final paths = _dependencyPaths(index, bundleId, direct);
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

/// 需求：[SPEC-007 FR-12] 每個來源在「中間節點不為直接 domain」的路徑中取最短（E-B：
/// 排除在取最短之前套用）、同長全列，依長度、來源在 FR-13 的先後、中間節點在 FR-13 的先後排序。
List<List<DomainBundleRef>> _dependencyPaths(
  _BundleIndex index,
  String target,
  Set<String> direct,
) {
  final distance = _distancesTo(target, index.incoming, direct);
  final paths = <List<String>>[
    for (final source in direct)
      if (distance.containsKey(source))
        ..._shortestPaths(source, target, index.out, distance, direct),
  ]..sort((a, b) => _comparePaths(a, b, index.rank));
  return [
    for (final p in paths) [for (final id in p) index.byId[id]!],
  ];
}

/// 自 [target] 沿依賴邊反向廣度優先，得各節點到 [target] 的最短跳數。
///
/// [direct] 內的節點只能作為路徑起點：取得距離但不再往上游展開（不得當中間節點）。
Map<String, int> _distancesTo(
  String target,
  Map<String, List<String>> incoming,
  Set<String> direct,
) {
  final distance = {target: 0};
  final queue = [target];
  for (var i = 0; i < queue.length; i++) {
    if (queue[i] != target && direct.contains(queue[i])) continue;
    for (final prev in incoming[queue[i]] ?? const <String>[]) {
      if (!distance.containsKey(prev)) {
        distance[prev] = distance[queue[i]]! + 1;
        queue.add(prev);
      }
    }
  }
  return distance;
}

/// [source] 到 [target] 的全部最短路徑（每步距離恰減 1，中間節點不得在 [direct] 內）。
List<List<String>> _shortestPaths(
  String source,
  String target,
  Map<String, List<String>> out,
  Map<String, int> distance,
  Set<String> direct,
) {
  if (source == target) {
    return [
      [target],
    ];
  }
  return [
    for (final next in out[source] ?? const <String>[])
      if (distance[next] == distance[source]! - 1 &&
          (next == target || !direct.contains(next)))
        for (final rest in _shortestPaths(next, target, out, distance, direct))
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
