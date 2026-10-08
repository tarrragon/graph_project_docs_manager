/// 泳道列序組裝（SPEC-001 §1〈泳道布局規則〉列集合與列序、
/// 「`traverses` 異常的步驟」、「畫面」列例外）。
///
/// DomainBundle 列序取自 Graph 公開面（SPEC-007 FR-13）的回傳值，由呼叫端
/// 轉成 [BundleOrderEntry] 清單傳入；本檔不推導分層、不判斷環。
library;

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
}

/// 一個 DomainBundle 列，列鍵為 `DomainBundle.domain` 宣告字面。
final class BundleLane extends SwimLane {
  const BundleLane(this.domain);
  final String domain;
}

/// 最末的「未定位」列，只在有缺鍵或值全部未宣告的步驟時出現。
final class UnplacedLane extends SwimLane {
  const UnplacedLane();
}

/// 需求：SPEC-001 §1 列集合與列序。
/// 「畫面」列、FR-13 排序段（照單使用）、必要時「未定位」列。
/// [stepTraverses] 為選定 UC 各步驟的 `traverses`，null 表示鍵缺席。
List<SwimLane> assembleSwimLanes({
  required List<BundleOrderEntry> bundleOrder,
  required List<List<String>?> stepTraverses,
}) {
  final declared = {for (final entry in bundleOrder) entry.domain};
  return [
    const ScreenLane(),
    for (final entry in bundleOrder) BundleLane(entry.domain),
    if (stepTraverses.any((t) => _isUnplaced(t, declared)))
      const UnplacedLane(),
  ];
}

/// 缺鍵，或非空且值全部未宣告者，置於「未定位」列。
bool _isUnplaced(List<String>? traverses, Set<String> declared) {
  if (traverses == null) return true;
  return traverses.isNotEmpty && !traverses.any(declared.contains);
}

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
