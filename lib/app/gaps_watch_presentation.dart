/// [SPEC-006 FR-11 規則 8、9；SPEC-003 §3.5〈生命週期〉；SPEC-001 §5]
/// 破洞報告頁對監看輪次的呈現狀態。
///
/// W4（保留舊結果）、D2（監看輪次中手動重掃）、D3（無既有結果時的監看輪次）。
library;

import 'package:graph_project_docs_manager/app/scan_scheduler.dart';

class GapsWatchPresentation {
  bool _scanning = false;
  bool _awaitManual = false;
  Set<String>? _shown;

  /// 是否顯示 `state-gaps-scanning`。
  bool get isScanning => _scanning;

  /// 目前畫面呈現的結果（itemId 集合）；無既有結果為 null。
  Set<String>? get shownItemIds => _shown;

  /// 頁面首次或再次可見時是否應自動掃描（SPEC-001 §5、D3）。
  bool get shouldAutoScanOnVisible => _shown == null;

  void onRoundStarted(ScanTrigger trigger) {
    if (trigger == ScanTrigger.watch) return;
    _scanning = true;
    _awaitManual = true;
  }

  /// 使用者按 `action-gaps-rescan`。
  void onManualRescanRequested() {
    _scanning = true;
    _awaitManual = true;
  }

  /// 一輪完成；[rerunPending] 表示排程尚有待重跑的一輪。
  void onRoundCompleted(
    ScanTrigger trigger,
    Set<String> itemIds, {
    required bool rerunPending,
  }) {
    if (_awaitManual && rerunPending) return;
    _shown = itemIds;
    _scanning = false;
    _awaitManual = false;
  }

  void onCancelled() {
    _scanning = false;
    _awaitManual = false;
  }
}
