/// bundle 依賴建構器（SPEC-001-test-design.md §1.5）。
///
/// 以 `domain → depends_on_bundles` 宣告出依賴邊集合，供 L1、L2、L7
/// 各自獨立建構 fixture，不共享 mutable 狀態。
library;

import 'package:graph_project_docs_manager/layout/lane_order.dart';

/// 依宣告順序展開為依賴邊清單（來源 → 目標）。
List<BundleDependencyEdge> buildBundleDependencyEdges(
  Map<String, List<String>> dependsOnBundles,
) {
  return [
    for (final entry in dependsOnBundles.entries)
      for (final target in entry.value) (from: entry.key, to: target),
  ];
}
