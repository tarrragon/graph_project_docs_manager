/// 節點詳情（SPEC-001 §6）的畫面狀態模型。
///
/// 本票決策：只交狀態渲染與退出路徑，不接真實資料——節點內容來自
/// [NodeDetailFixtures]（`node_detail_fixtures.dart`），非解析
/// `test/fixtures/corpus/` 或使用者工作資料夾（同 `trace_state.dart`
/// 慣例）。「專案未就緒」為 SPEC-001 五個非 Domain 畫面共用定義
/// （`0.1.0-W3-335.37` R9），本票以獨立狀態列舉呈現，不 watch
/// `graphBuiltProvider`（同 `trace_state.dart`／`domain_view_state.dart`
/// 的簡單 `StateProvider` 慣例——`gap_report_provider.dart` 改用 Notifier
/// watch 該 provider 是因其自身有「首次可見自動掃描」的副作用需求，兩者
/// 皆為既有票已核可的合法設計選擇，本票選前者以維持與 trace／domain_view
/// 一致）。
library;

/// 節點詳情的五個畫面狀態（SPEC-001 §6）。
sealed class NodeDetailState {
  const NodeDetailState();
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 共用定義；優先於「未選節點」
/// 判定，SPEC-003 §3.6）。
class NodeDetailProjectUnready extends NodeDetailState {
  const NodeDetailProjectUnready();
}

/// 未選節點：經導覽列直接進入且無選定節點（SPEC-001 §6 v1.3 新增）。
class NodeDetailUnset extends NodeDetailState {
  const NodeDetailUnset();
}

/// 正常／部分損壞共用：節點是否有損壞欄位由 [NodeDetailFixtures] 中該
/// nodeId 的資料決定，畫面依此渲染欄位級 `IssueMarker.damagedDetail`
/// （SPEC-001 §6「部分損壞」非獨立資料形狀，是同一節點資料的疊加呈現，
/// 同 `domain_view_state.dart` `DomainReady.isDegraded` 疊加旗標慣例）。
class NodeDetailReady extends NodeDetailState {
  const NodeDetailReady({required this.nodeId});

  /// 目前顯示的節點 id（[NodeDetailFixtures] 鍵值）。
  final String nodeId;
}

/// 原始檔已消失：訊息 + 最後已知路徑 + 重新整理／返回。
class NodeDetailMissing extends NodeDetailState {
  const NodeDetailMissing({
    required this.nodeId,
    required this.lastKnownPath,
  });

  /// 消失前顯示的節點 id（重新整理成功後據此決定顯示哪個節點）。
  final String nodeId;

  /// 最後已知路徑（`MissingSourceState` 訊息 slot）。
  final String lastKnownPath;
}
