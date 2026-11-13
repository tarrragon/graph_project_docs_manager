/// app 編排層（掃描輪次、排程、監看、歷史等待）的日誌事件（SPEC-010 FR-04）。
///
/// 事件名是測試斷言綁定的穩定契約；負載只用 FR-03 白名單型別，例外走
/// `error:`，絕對路徑不入負載。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// app 編排層日誌事件（穩定契約）。
enum AppLogEvent {
  /// 掃描輪次開始。
  scanRoundStarted,

  /// 掃描輪次完成，負載帶 [AppLogKeys.degraded]。
  scanRoundCompleted,

  /// 掃描輪次失敗（例外走 `error:`）。
  scanRoundFailed,

  /// 輪次被丟棄，負載帶 [AppLogKeys.reason]（呼叫端給的短識別字，經欄位名驗證）。
  scanRoundDiscarded,

  /// 等待監看就緒期間輪次已失效，不開輪。
  scanRoundSkippedStale,

  /// 過期輪次的結果被丟棄。
  scanRoundStaleResultDropped,

  /// 專案型別表讀取失敗，視為缺席。
  projectSchemaReadFailed,

  /// 專案型別表 JSON 解析失敗。
  projectSchemaParseFailed,

  /// 排程器執行的輪次拋出例外。
  schedulerRoundFailed,

  /// 監看輪次完成後撤回前一則通知失敗。
  watchNotificationWithdrawFailed,

  /// 監看流程取得掃描輪次失敗。
  watchRoundFetchFailed,

  /// Domain 視圖載入取得掃描輪次失敗。
  domainViewRoundFetchFailed,

  /// 建圖不可用而判為無法判定，負載帶 [AppLogKeys.reason]。
  graphUnavailableUndetermined,

  /// 最近專案計數快照已同步（debug）。
  recentProjectCountsSynced,

  /// 歷史流程沿用上一輪已完成輪次（debug）。
  historyReusedLastRound,

  /// 歷史流程開始等待第一輪（debug）。
  historyWaitStarted,

  /// 歷史流程等待結束，負載帶 outcome 與 waitedMs。
  historyWaitEnded,

  /// 歷史流程找不到啟用的邊型別，負載帶原因。
  historyNoActiveEdgeTypes,

  /// 歷史掃描未產生結果，負載帶 [AppLogKeys.failed]。
  historyScanEndedWithoutResult,
}

/// 歷史等待結果。
enum HistoryWaitOutcome { completed, unavailable }

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class AppLogKeys {
  static const degraded = 'degraded';
  static const reason = 'reason';
  static const outcome = 'outcome';
  static const waitedMs = 'waitedMs';
  static const resolutionMissing = 'resolutionMissing';
  static const failed = 'failed';
}

/// app 層生產預設 sink 的 domain 名。
const String appLogDomain = 'app';

/// app 層共用 sink；預設經共用 writer 輸出，測試可替換後於 tearDown 還原。
LogSink<AppLogEvent> appLogSink = defaultLogSink<AppLogEvent>(appLogDomain);
