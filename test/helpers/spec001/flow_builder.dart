/// flow 子圖建構器（SPEC-001-test-design.md §1.5）。
///
/// 以 `(id, next, branch_from, return_to, traverses)` 宣告出 flow 子圖值物件，
/// 保留檔內順序；`traverses` 可宣告為「鍵缺席」，名稱解析結果由已宣告的
/// DomainBundle（經真實 Graph 解析器）決定，不在測試內以字串比對代算。
library;

import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';

/// 本專案快照的 FR-13 列序（SPEC-001 §1 期望值欄；測試設計 §1.2）。
const projectBundleOrder = <BundleOrderEntry>[
  (domain: 'schema', layer: 0),
  (domain: 'workspace', layer: 0),
  (domain: 'corpus', layer: 1),
  (domain: 'history', layer: 1),
  (domain: 'diagnostics', layer: 2),
  (domain: 'graph', layer: 2),
  (domain: 'ticketdetail', layer: 2),
  (domain: 'layout', layer: 3),
];

/// 以給定 domain 依序建 FR-13 清單（全部層 0，供只需列集合的測試）。
List<BundleOrderEntry> orderOf(List<String> domains) => [
  for (final d in domains) (domain: d, layer: 0),
];

/// `traverses` 鍵缺席的標記值。
const Object traversesAbsent = Object();

/// 一個 flow 步驟的宣告列。
Map<String, dynamic> stepRow(
  String id, {
  List<String> next = const [],
  String? branchFrom,
  String? returnTo,
  Object? traverses = const <String>[],
}) => {
  'id': id,
  'next': next,
  'branch_from': branchFrom,
  'return_to': returnTo,
  if (!identical(traverses, traversesAbsent)) 'traverses': traverses,
};

/// 以宣告列與已宣告 domain（每個值對應一個 DomainBundle 節點，可重複以
/// 製造重複宣告）建 flow 子圖。
FlowSubgraph buildFlow(
  List<Map<String, dynamic>> rows, {
  List<String> declaredDomains = const [],
}) {
  final resolver = DomainNameResolver.fromDeclarations([
    for (var i = 0; i < declaredDomains.length; i++)
      ('bundle-$i', declaredDomains[i]),
  ]);
  final idIndex = <String, List<int>>{};
  for (var i = 0; i < rows.length; i++) {
    final key = flowKeyOf(rows[i]['id']);
    if (key != null) idIndex.putIfAbsent(key, () => []).add(i);
  }
  return FlowSubgraph(
    ucId: 'UC-TEST',
    steps: [
      for (var i = 0; i < rows.length; i++)
        FlowStepNode(
          index: i,
          step: rows[i],
          idIndex: idIndex,
          domainResolver: resolver,
        ),
    ],
  );
}

/// 以 [declared] 對應舊式 `traverses` 清單（null 為鍵缺席）建解析結果，
/// 供只關心列集合的測試使用；解析語意與 Graph 一致（未宣告者進 undeclared）。
TraversesResolution resolutionOf(
  List<String>? traverses,
  Set<String> declared,
) {
  if (traverses == null) {
    return TraversesResolution(keyAbsent: true, resolved: [], undeclared: []);
  }
  return TraversesResolution(
    keyAbsent: false,
    resolved: [
      for (final t in traverses)
        if (declared.contains(t)) ResolvedDomain(name: t, bundleId: 'b-$t'),
    ],
    undeclared: [
      for (final t in traverses)
        if (!declared.contains(t)) t,
    ],
  );
}
