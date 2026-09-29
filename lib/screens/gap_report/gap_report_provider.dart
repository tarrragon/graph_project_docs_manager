/// 破洞報告狀態機（SPEC-001 §5；SPEC-003 §3.5 生命週期、§2.5 取消契約）。
///
/// 首次可見即自動掃描；0.1 不接真實圖建置，掃描結果固定由真實 repo
/// 快照（`test/fixtures/corpus/book_overview_v1`）的缺 frontmatter 樣本
/// 驅動——決策已記於本票 `decision_tree_path`：「只交狀態渲染與退出路徑，
/// 不接真實資料」。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/graph_status.dart';
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
  /// 目前這一輪掃描的世代號。`_scheduleScan()` 每次呼叫遞增；延遲完成
  /// 回呼觸發時比對世代號，避免 `rescan()` 疊代排程時較舊一輪蓋過較新
  /// 一輪的結果（見 [_completeScan]）。
  int _scanGeneration = 0;

  /// 掃描是否已被觸發過一次（0.3.1-W3-122：觸發時機改為消費
  /// [firstVisibleProvider]）。`firstVisibleProvider` 本身對重複讀取已
  /// 冪等（讀到 `true` 後即透過 microtask 寫回已見集合），本欄位額外
  /// 防止「已見集合更新」觸發的重建 rebuild build() 時，因
  /// `firstVisibleProvider` 短暫仍可能與前次同為 `true`（同一次事件迴圈
  /// 內的中間態）而重複呼叫 [_scheduleScan]。
  bool _hasTriggeredScan = false;

  /// build() 上一次回傳的結果，供本次 rebuild 在「未觸發新一輪掃描」時
  /// 原樣回傳（不可讀取 [Notifier.state]：首次 build() 呼叫時該 getter
  /// 尚未初始化）。
  GapReportState _lastResult = const GapReportScanning();

  @override
  GapReportState build() {
    // SPEC-003 §3.5〈生命週期〉「首次可見但圖未建立」：不自動掃描，渲染
    // 共用「專案未就緒」定義；watch 使圖建立完成時 build() 重跑，依「首次
    // 可見且圖已建立」列重新判定（SPEC-001 §5 共用定義，`0.1.0-W3-335.37`
    // R9）。
    if (!ref.watch(graphBuiltProvider)) {
      _lastResult = const GapReportProjectUnready();
      return _lastResult;
    }
    // 0.3.1-W3-122：掃描觸發改掛在「首次可見 nav-page-gaps」，不再掛在
    // provider 的 build()（原本一經 ScanNotificationController.start() 於
    // App 啟動時掛上監聽即觸發，早於使用者看過破洞報告頁）。
    final isFirstVisible = ref.watch(firstVisibleProvider(AppDestination.gaps));
    if (isFirstVisible && !_hasTriggeredScan) {
      _hasTriggeredScan = true;
      _scheduleScan();
      _lastResult = const GapReportScanning();
      return _lastResult;
    }
    if (!_hasTriggeredScan) {
      // 圖已建立但尚未首次造訪 nav-page-gaps：不掃描，維持骨架佔位
      // （畫面未渲染本狀態，因該畫面本身尚未被選取）。
      _lastResult = const GapReportScanning();
      return _lastResult;
    }
    // 已觸發過掃描：保留目前結果，不因 firstVisibleProvider 的後續讀值
    // （例如已見集合寫回導致的 rebuild）重置狀態。
    return _lastResult;
  }

  /// `action-gaps-rescan`：現有結果立即被骨架取代，重新掃描。
  void rescan() {
    state = const GapReportScanning();
    _lastResult = state;
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
    _lastResult = state;
    Future<void>.delayed(Motion.cancelDeadline, () {
      final returnTo = ref.read(returnToProvider);
      if (returnTo != null) {
        consumeReturnTo(ref.read);
      } else {
        navigateTo(ref.read, AppDestination.domain, NavIntent.rail);
      }
    });
  }

  /// 延後至少 `Motion.spinnerMinVisible` 後完成掃描（SPEC-003 §2.6「最短
  /// 顯示時間適用」）。`state-gaps-scanning` 一旦渲染，即使掃描本身
  /// （現階段由 [_missingFrontmatterItems] 常數驅動，耗時趨近於零）更快
  /// 完成，也至少存續此契約時長——這同時是骨架可被觀測、以及取消／重新
  /// 掃描可在完成前介入的最短視窗。真實掃描串接後，此處應改為與真實耗時
  /// 取兩者較長者（而非疊加），不在本票範圍。
  void _scheduleScan() {
    final generation = ++_scanGeneration;
    Future<void>.delayed(
      Motion.spinnerMinVisible,
      () => _completeScan(generation),
    );
  }

  void _completeScan(int generation) {
    if (generation != _scanGeneration) {
      // 已被更新一輪的 rescan() 取代，本次（較舊）結果作廢。
      return;
    }
    final current = state;
    if (current is! GapReportScanning || current.isCancelling) {
      // 掃描期間已被 rescan() 改變狀態，或正在取消中，本次結果作廢。
      return;
    }
    if (_missingFrontmatterItems.isEmpty) {
      state = const GapReportNoGaps();
      _lastResult = state;
      return;
    }
    state = const GapReportFound([
      GapReportCategory(
        id: 'missing-frontmatter',
        items: _missingFrontmatterItems,
      ),
    ]);
    _lastResult = state;
  }
}

/// 破洞報告畫面狀態 provider。
final gapReportProvider = NotifierProvider<GapReportNotifier, GapReportState>(
  GapReportNotifier.new,
);
