/// 破洞報告畫面狀態模型（SPEC-001 §5；SPEC-003 §3.5）。
///
/// 三個狀態密封為 [GapReportState]：掃描中、無破洞、有破洞（依類別分節，
/// 各節帶 N 個 [GapReportItem]）。0.1 不接真實掃描，資料由 provider 層以
/// 真實 repo 快照的缺 frontmatter 樣本驅動（見 gap_report_provider.dart）。
library;

/// 單一破洞項：檔案路徑與行號（SPEC-001 §5「顯示」欄「各項帶檔案與行號」）。
class GapReportItem {
  const GapReportItem({
    required this.id,
    required this.filePath,
    required this.lineNumber,
  });

  /// 穩定識別碼，供 `card-gaps-<itemId>` 錨點使用（SPEC-003 §3.5）。
  final String id;

  /// 檔案路徑（相對於工作資料夾），呼叫端以 [AppText.mono] 顯示。
  final String filePath;

  /// 破洞所在行號。
  final int lineNumber;
}

/// 依類別分節的破洞群組（SPEC-004 §3.6 §5「有破洞」列）。
class GapReportCategory {
  const GapReportCategory({
    required this.id,
    required this.items,
  });

  /// 穩定識別碼，供 `expander-gaps-<category>` 錨點與 l10n 標籤查表使用。
  final String id;

  /// 本類別下的破洞項清單。
  final List<GapReportItem> items;
}

/// 破洞報告的三個畫面狀態（SPEC-001 §5）。
sealed class GapReportState {
  const GapReportState();
}

/// 掃描中：對應 `LoadingState.skeleton`（版位 `sections`）。
class GapReportScanning extends GapReportState {
  const GapReportScanning({
    this.processedCount = 0,
    this.isCancelling = false,
  });

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
