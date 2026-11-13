/// SPEC-010 破洞報告與通知日誌事件；事件名為測試斷言綁定的穩定契約。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// 破洞報告 domain 事件。
enum GapReportLogEvent {
  /// 投影查不到節點（降級為不可開檔項目），warning、`internal`。
  nodeNotFound,

  /// unreadable 破洞缺子原因（建構期 assert 在 release 下失效），
  /// warning、`internal`。
  unreadableGapWithoutSubReason,

  /// 專案與內建型別表都沒有 `non_domain_paths_key`，warning、`internal`。
  nonDomainPathsKeyMissing,

  /// 系統通知發送失敗，改走 SnackBar，warning、`platform_io`。
  notificationDeliveryFailed,

  /// 監看輪次系統通知發送失敗，warning、`platform_io`。
  watchNotificationDeliveryFailed,

  /// SnackBar fallback 因 context 已卸載而略過，warning、`internal`。
  snackbarFallbackSkipped,

  /// 點擊通知路徑（SPEC-003 §2.2）：活化，負載 `state_found`。
  clickActivated,

  /// 點擊通知路徑：導向完成，負載 `destination`、`return_to`。
  clickNavigate,

  /// 點擊通知路徑：已設定待定位項。
  clickLocateSet,

  /// 點擊通知路徑：無可定位項而略過。
  clickLocateSkip,

  /// 點擊通知路徑：捲動完成，負載 `mounted`、`visible`。
  clickLocateScroll,

  /// 點擊通知路徑：焦點請求完成，負載 `mounted`、`has_focus`。
  clickLocateFocus,

  /// 撤回通知，負載 `trigger`（撤回條件 enum）。
  withdrawTriggered,
}

/// 事件負載鍵。
abstract final class GapReportLogKeys {
  static const stateFound = 'state_found';
  static const destination = 'destination';
  static const returnTo = 'return_to';
  static const mounted = 'mounted';
  static const visible = 'visible';
  static const hasFocus = 'has_focus';
  static const trigger = 'trigger';
}

/// 生產預設：經共用 writer 輸出，domain 為 `gap_report`。
final LogSink<GapReportLogEvent> defaultGapReportLogSink =
    defaultLogSink<GapReportLogEvent>('gap_report');

/// 破洞報告 sink；測試以 override 注入記錄器。
final gapReportLogSinkProvider = Provider<LogSink<GapReportLogEvent>>(
  (ref) => defaultGapReportLogSink,
);
