/// 泳道列序組裝（SPEC-001 §1〈泳道布局規則〉列集合與列序、
/// 「`traverses` 異常的步驟」、「畫面」列例外）。
///
/// DomainBundle 列序取自 Graph 公開面（SPEC-007 FR-13）的回傳值，由呼叫端
/// 轉成 [BundleOrderEntry] 清單傳入；本檔不推導分層、不判斷環。
library;

import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';

/// SPEC-007 FR-13 回傳的單項：排序後的 bundle，附層號（推不出層者為 null）。
typedef BundleOrderEntry = ({String domain, int? layer});

/// `bundle_dependency` 依賴邊（來源依賴目標）。
typedef BundleDependencyEdge = ({String from, String to});

/// 泳道的一列。
sealed class SwimLane {
  const SwimLane();
}

/// 最上方的「畫面」列，承載 `traverses == []` 的步驟。
final class ScreenLane extends SwimLane {
  const ScreenLane();

  @override
  bool operator ==(Object other) => other is ScreenLane;

  @override
  int get hashCode => (ScreenLane).hashCode;
}

/// 一個 DomainBundle 列，列鍵為 `DomainBundle.domain` 宣告字面。
final class BundleLane extends SwimLane {
  const BundleLane(this.domain);
  final String domain;

  @override
  bool operator ==(Object other) =>
      other is BundleLane && other.domain == domain;

  @override
  int get hashCode => Object.hash(BundleLane, domain);
}

/// 最末的「未定位」列，只在有缺鍵或值全部未宣告的步驟時出現。
final class UnplacedLane extends SwimLane {
  const UnplacedLane();

  @override
  bool operator ==(Object other) => other is UnplacedLane;

  @override
  int get hashCode => (UnplacedLane).hashCode;
}

/// 需求：SPEC-001 §1 列集合與列序。
/// 「畫面」列、FR-13 排序段（照單使用）、必要時「未定位」列。
/// [stepResolutions] 為選定 UC 各步驟的 Graph `traverses` 解析結果
/// （`FlowStepNode.traversesResolution`）；重複宣告而被 Graph 排除者不在
/// 其中，Layout 不以字串比對列鍵。
List<SwimLane> assembleSwimLanes({
  required List<BundleOrderEntry> bundleOrder,
  required List<TraversesResolution> stepResolutions,
}) {
  return [
    const ScreenLane(),
    for (final entry in bundleOrder) BundleLane(entry.domain),
    if (stepResolutions.any(isUnplacedResolution)) const UnplacedLane(),
  ];
}

/// 缺鍵，或已宣告值為空而仍有未宣告值者，置於「未定位」列。
/// 只用 Graph 解析結果判定，不比對列鍵字串。列層級（是否出現「未定位」列）
/// 與節點層級（節點落哪一列）共用此判定。
bool isUnplacedResolution(TraversesResolution resolution) =>
    resolution.keyAbsent ||
    (resolution.resolved.isEmpty && resolution.undeclared.isNotEmpty);

/// 需求：SPEC-001 §1 推不出層的 bundle——依賴邊依存在的端點繪製，
/// 指向未宣告者（無對應列）的邊不畫。
List<BundleDependencyEdge> drawableDependencyEdges({
  required List<SwimLane> lanes,
  required List<BundleDependencyEdge> edges,
}) {
  final keys = {
    for (final lane in lanes)
      if (lane is BundleLane) lane.domain,
  };
  return [
    for (final edge in edges)
      if (keys.contains(edge.from) && keys.contains(edge.to)) edge,
  ];
}
