/// 破洞報告畫面狀態模型（SPEC-001 §5；SPEC-003 §3.5）。
///
/// 三個狀態密封為 [GapReportState]：掃描中、無破洞、有破洞（依類別分節，
/// 各節帶 N 個 [GapReportItem]）。0.1 不接真實掃描，資料由 provider 層以
/// 真實 repo 快照的缺 frontmatter 樣本驅動（見 gap_report_provider.dart）。
library;

/// 破洞項指向的節點型別（SPEC-001 §5〈破洞項的主操作與次要操作〉，
/// `0.1.0-W3-335.19` 用戶裁示 2026-09-14）。點擊行為依此分派：
/// [ticket]／[otherNode]／[event] 三類跳轉，主操作外另有次要操作
/// `action-gaps-open-source-<itemId>`；[none] 主操作本身即開啟原始檔，
/// 不渲染次要操作。
enum GapItemPointerType {
  /// 指向 Ticket 節點。
  ticket,

  /// 指向其他圖節點（提案、規格、UC 等）。
  otherNode,

  /// 事件類（破洞類別 `orphan-event` 或 `event-declaration-mismatch`）。
  event,

  /// 無法指向任何節點。
  none,
}

/// 單一破洞項：檔案路徑、行號（可缺）與指向節點屬性
/// （SPEC-001 §5「顯示」欄；SPEC-003 §3.5〈破洞項的指向節點〉）。
class GapReportItem {
  const GapReportItem({
    required this.id,
    required this.filePath,
    this.lineNumber,
    this.pointerType = GapItemPointerType.none,
    this.pointerNodeId,
    this.eventUcId,
  });

  /// 穩定識別碼，供 `card-gaps-<itemId>` 錨點使用（SPEC-003 §3.5、§2.9）。
  final String id;

  /// 檔案路徑（相對於工作資料夾），呼叫端以 [AppText.mono] 顯示。
  final String filePath;

  /// 破洞所在行號；`null` 時不顯示（SPEC-001 §5「有值時附」，
  /// `0.1.0-W3-335.37` R11：事件類破洞項無單一行號）。
  final int? lineNumber;

  /// 指向節點型別，預設 [GapItemPointerType.none]（沿用既有「開啟原始檔」
  /// 行為，向後相容既有呼叫端）。
  final GapItemPointerType pointerType;

  /// 指向的圖節點 ID（[GapItemPointerType.ticket]／[otherNode] 使用；
  /// [event] 類指向 EVT 節點 ID）；[GapItemPointerType.none] 時為 `null`。
  final String? pointerNodeId;

  /// 事件類破洞項預先解析出的選定 UC（多條 FlowStep 引用時取編號最小者，
  /// 由破洞分類邏輯決定，見 CLAUDE.md §6 待決；此欄只承接結果）。`null`
  /// 代表無任何 UC 引用該 EVT，跳轉行為改依 [otherNode] 處理
  /// （`0.1.0-W3-335.38` S-31）。僅 [GapItemPointerType.event] 使用。
  final String? eventUcId;

  /// 是否渲染次要操作 `action-gaps-open-source-<itemId>`（SPEC-001 §5：
  /// 有指向節點的前三類另有次要操作；無指向者主操作本身即開啟原始檔，
  /// 不重複提供次要操作）。
  bool get hasSecondaryOpenSource => pointerType != GapItemPointerType.none;
}

/// 依類別分節的破洞群組（SPEC-004 §3.6 §5「有破洞」列）。
class GapReportCategory {
  const GapReportCategory({required this.id, required this.items});

  /// 穩定識別碼，供 `expander-gaps-<category>` 錨點與 l10n 標籤查表使用。
  final String id;

  /// 本類別下的破洞項清單。
  final List<GapReportItem> items;
}

/// 破洞報告的畫面狀態（SPEC-001 §5）。
sealed class GapReportState {
  const GapReportState();
}

/// 專案未就緒：Domain 視圖尚未建立圖（SPEC-001 §5 共用定義，
/// `0.1.0-W3-335.37` R9）。對應 `EmptyState.page` + 前往 Domain 視圖動作。
class GapReportProjectUnready extends GapReportState {
  const GapReportProjectUnready();
}

/// 掃描中：對應 `LoadingState.skeleton`（版位 `sections`）。
class GapReportScanning extends GapReportState {
  const GapReportScanning({this.processedCount = 0, this.isCancelling = false});

  /// 已掃描項目計數（SPEC-003 §2.6 進度文字）。
  final int processedCount;

  /// 取消契約 C2：按下取消後 `Motion.feedback` 內轉為 `true`。
  final bool isCancelling;
}

/// 無破洞：對應 `EmptyState.page`。
class GapReportNoGaps extends GapReportState {
  const GapReportNoGaps();
}

/// 有破洞：對應 `Panel.scrollable`[`Section.collapsible` × N]。
class GapReportFound extends GapReportState {
  const GapReportFound(this.categories);

  final List<GapReportCategory> categories;
}
