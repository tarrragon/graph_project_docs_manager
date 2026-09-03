/// 追溯視圖（SPEC-001 §3）的三個畫面狀態與樹節點資料模型。
///
/// 本票決策：只交狀態渲染與退出路徑，不接真實資料——節點內容來自
/// [TraceabilityFixtures]（`trace_fixtures.dart`），非解析
/// `test/fixtures/corpus/` 或使用者工作資料夾。UC → Ticket 在上游 16 條
/// 語意邊中無對應邊（CLAUDE.md §6「現行待決」），故樹狀資料填至 UC 層。
library;

/// 追溯樹的一個節點（PROP／SPEC／UC 三層之一）。
///
/// [hasGap] 為 `true` 時，[gapLayer] 必填——標示本節點缺少的下游層級
/// （`'spec'` / `'uc'` / `'ticket'`），對應 `badge-traceability-broken-<layer>`
/// 錨點（SPEC-003 §3.3）。有 [hasGap] 的節點應視為葉節點（呼叫端不傳
/// [children]），trailing 格顯示 `IssueMarker.gap` 而非 `Badge.status`；
/// 此不變式僅由 fixture 撰寫者保證，不可 const-evaluable，故未以 assert
/// 強制。
class TraceNode {
  const TraceNode({
    required this.id,
    required this.label,
    required this.status,
    this.hasGap = false,
    this.gapLayer,
    this.children = const [],
  }) : assert(
         !hasGap || gapLayer != null,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'hasGap 為 true 時 gapLayer 必填',
       );

  /// 節點識別碼（`PROP-001` 等），對應 `card-traceability-<id>` /
  /// `expander-traceability-<id>` 錨點。
  final String id;

  /// 列主文字（`AppText.body`，PROP 層另加 `emphasis`）。
  final String label;

  /// 節點狀態（`draft` / `confirmed` 等），經 `Badge.status` 顯示；
  /// [hasGap] 為 `true` 時不使用。
  final String status;

  /// 是否為缺口節點（本層存在，但下一層無任何子節點）。
  final bool hasGap;

  /// 缺口所在的下游層級（`'spec'` / `'uc'` / `'ticket'`）；[hasGap] 為
  /// `true` 時必填，對應 `badge-traceability-broken-<gapLayer>`。
  final String? gapLayer;

  /// 子節點（PROP 的 SPEC、SPEC 的 UC）；[hasGap] 節點恆為空。
  final List<TraceNode> children;
}

/// 追溯視圖的畫面狀態（SPEC-001 §3 三列）。
sealed class TraceabilityScreenState {
  const TraceabilityScreenState();
}

/// 正常：至少一個 PROP 節點，樹狀可展開收合、點節點跳轉詳情。
class TraceabilityNormal extends TraceabilityScreenState {
  const TraceabilityNormal(this.roots);

  /// PROP 層節點清單（樹根）。
  final List<TraceNode> roots;
}

/// 鏈路斷裂：某層無下游節點，缺口列 trailing 格顯示 `IssueMarker.gap`。
class TraceabilityBroken extends TraceabilityScreenState {
  const TraceabilityBroken(this.roots);

  /// PROP 層節點清單（樹根），至少一個節點含 [TraceNode.hasGap]。
  final List<TraceNode> roots;
}

/// 無提案：專案無任何 PROP 節點。
class TraceabilityNoProposal extends TraceabilityScreenState {
  const TraceabilityNoProposal();
}
