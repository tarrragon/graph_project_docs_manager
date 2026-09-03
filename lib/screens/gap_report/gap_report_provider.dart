/// 破洞報告狀態機（SPEC-001 §5；SPEC-003 §3.5 生命週期、§2.5 取消契約）。
///
/// 首次可見即自動掃描；0.1 不接真實圖建置，掃描結果固定由真實 repo
/// 快照（`test/fixtures/corpus/book_overview_v1`）的缺 frontmatter 樣本
/// 驅動——決策已記於本票 `decision_tree_path`：「只交狀態渲染與退出路徑，
/// 不接真實資料」。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../tokens/motion.dart';
import 'gap_report_models.dart';

/// 真實 repo 快照驗證出的缺 frontmatter 樣本（見
/// `test/fixtures/corpus/book_overview_v1/meta.yaml`）。0.1 以此驅動
/// 「有破洞」狀態，不接真實掃描邏輯。
const _missingFrontmatterItems = [
  GapReportItem(
    id: 'csv-export-spec',
    filePath: 'docs/spec/csv-export-spec.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'cross-project-verification-protocol',
    filePath: 'docs/spec/cross-project-verification-protocol.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'spec-readme',
    filePath: 'docs/spec/README.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'book-interchange-v1',
    filePath: 'docs/spec/book-interchange-v1.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'usecases-readme',
    filePath: 'docs/usecases/README.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'proposals-readme',
    filePath: 'docs/proposals/README.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'synchronization-qr-frame-format',
    filePath: 'docs/spec/synchronization/SPEC-009-qr-frame-format.md',
    lineNumber: 1,
  ),
  GapReportItem(
    id: 'synchronization-test-fixtures-readme',
    filePath: 'docs/spec/synchronization/test-fixtures/README.md',
    lineNumber: 1,
  ),
];

/// 破洞報告畫面狀態機。
///
/// 生命週期（SPEC-003 §3.5）：首次可見自動進入掃描中，完成後轉無破洞或
/// 有破洞；再次可見不重新掃描；`rescan()` 對應 `action-gaps-rescan`，
/// 重新掃描時現有結果立即被骨架取代（不做兩段淡出淡入）。
class GapReportNotifier extends Notifier<GapReportState> {
  @override
  GapReportState build() {
    _scheduleScan();
    return const GapReportScanning();
  }

  /// `action-gaps-rescan`：現有結果立即被骨架取代，重新掃描。
  void rescan() {
    state = const GapReportScanning();
    _scheduleScan();
  }

  /// `action-gaps-cancel-scan`（取消契約 C2、C4，SPEC-003 §2.5）。
  ///
  /// 按下後立即轉 `isCancelling`；`Motion.cancelDeadline` 內抵達
  /// `returnTo` 指定畫面，`returnTo` 為 `null` 時抵達 Domain 視圖
  /// （SPEC-001 §5「掃描中」列「取消 → 返回」）。C8 冪等：非掃描中或
  /// 已在取消中時不重複觸發。
  void cancelScan() {
    final current = state;
    if (current is! GapReportScanning || current.isCancelling) {
      return;
    }
    state = const GapReportScanning(isCancelling: true);
    Future<void>.delayed(Motion.cancelDeadline, () {
      final returnTo = ref.read(returnToProvider);
      if (returnTo != null) {
        consumeReturnTo(ref.read);
      } else {
        navigateTo(ref.read, AppDestination.domain, NavIntent.rail);
      }
    });
  }

  /// 延後到 microtask 完成掃描，避免在 [build] 同步過程中改寫自身狀態
  /// （與 `router.dart` `firstVisibleProvider` 同一慣例）。
  void _scheduleScan() {
    Future.microtask(_completeScan);
  }

  void _completeScan() {
    if (state is! GapReportScanning) {
      // 掃描期間已被 rescan() 或 cancelScan() 改變狀態，本次結果作廢。
      return;
    }
    if (_missingFrontmatterItems.isEmpty) {
      state = const GapReportNoGaps();
      return;
    }
    state = const GapReportFound([
      GapReportCategory(
        id: 'missing-frontmatter',
        items: _missingFrontmatterItems,
      ),
    ]);
  }
}

/// 破洞報告畫面狀態 provider。
final gapReportProvider =
    NotifierProvider<GapReportNotifier, GapReportState>(
  GapReportNotifier.new,
);
