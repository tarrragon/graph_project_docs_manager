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
/// （`'spec'` / `'uc'` / `'ticket'`），本節點的 [id] 對應
/// `badge-traceability-broken-<nodeId>` 錨點（SPEC-003 §3.3／§4，
/// `<nodeId>` 為缺下游的父節點，用戶簽核 2026-09-14）。有 [hasGap] 的節點應視為葉節點（呼叫端不傳
/// [children]），trailing 格顯示 `IssueMarker.gap` 而非 `Badge.status`；
/// 此不變式僅由 fixture 撰寫者保證，不可 const-evaluable，故未以 assert
/// 強制。
///
/// **多父節點**（`0.1.0-W3-335.38` S-27，SPEC-003 §3.3〈多父節點〉）：[id]
/// 不要求全樹唯一——同一 [id] 可於不同父節點下各出現一次，各出現位置的
/// [children] 與展開狀態相同（展開集合以 [id] 為鍵，全部出現位置共用，
/// 見 `trace_providers.dart` 的 `expandedTraceNodesProvider`）；缺口標示
/// 則以出現位置為單位各自渲染一個。錨點（`card-traceability-<id>` /
/// `expander-traceability-<id>` / `badge-traceability-broken-<id>`）維持
/// 字面 `<id>` 不變，只需兄弟節點間唯一，不要求全樹唯一。
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
  /// `true` 時必填。錨點以 [id] 產生（`badge-traceability-broken-<id>`），
  /// 本欄僅供缺口分類使用。
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

/// 「專案未就緒」的三個原因（SPEC-001 共用定義，`0.1.0-W3-335.37` R9）。
enum ProjectUnreadyReason {
  /// Domain 視圖尚未選擇專案。
  notSelected,

  /// Domain 視圖圖譜載入中。
  loading,

  /// Domain 視圖處於三個阻擋狀態之一（不是框架專案／無可消費的型別表／
  /// schema 不相容），本畫面不區分三者，統一顯示「此專案不適用本 App」。
  incompatible,
}

/// 專案未就緒：五個非 Domain 畫面共用狀態（SPEC-001 共用定義），取代本
/// 畫面原本依圖判定的三個狀態。
class TraceabilityProjectUnready extends TraceabilityScreenState {
  const TraceabilityProjectUnready(this.reason);

  /// 三選一原因，決定顯示文案。
  final ProjectUnreadyReason reason;
}
