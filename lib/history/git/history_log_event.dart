/// SPEC-008 FR-10 日誌事件：事件名是測試斷言綁定的穩定契約，`message` 可自由改寫。
///
/// 形態沿用 `GraphLogEvent` 的注入接縫；生產預設經共用 writer 輸出。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// History git 程序日誌事件（穩定契約）。
enum HistoryLogEvent {
  /// 前置檢查入口。
  preflightEntered,

  /// 前置檢查結果類別（負載含 git 版本，若已取得）。
  preflightResult,

  /// 降級或失敗（負載含結束碼與 stderr 摘要，若有）。
  degraded,

  /// 掃描開始（負載含工作區根、HEAD）。
  scanStarted,

  /// 掃描結束（負載含 commit 數、輸出位元組數、git 耗時等）。
  scanFinished,

  /// 解析端補報（解析耗時、事件數、各項計數）。
  scanParseReported,

  /// 掃描被取消。
  scanCancelled,

  /// 輸出位元組數超過 tripwire 閾值。
  tripwire,

  /// 行程啟動（平台互動，observability 規則 5）。
  processStarted,

  /// 行程結束。
  processExited,

  /// 行程被終止。
  processKilled,

  /// 行程無法啟動。
  processLaunchFailed,
}

/// 負載鍵。
class HistoryLogKeys {
  HistoryLogKeys._();

  static const String head = 'head';
  static const String category = 'category';
  static const String reason = 'reason';
  static const String exitCode = 'exitCode';
  static const String argumentCount = 'argumentCount';
  static const String commitCount = 'commitCount';
  static const String outputBytes = 'outputBytes';
  static const String gitDurationMs = 'gitDurationMs';
  static const String parseDurationMs = 'parseDurationMs';
  static const String eventCount = 'eventCount';
}

/// 前置檢查結果類別（`category` 欄位的值）。
enum HistoryLogCategory { ready, notWorkTree, gitNotFound, noCommit, failed }

/// 降級原因（`reason` 欄位的值）。
enum HistoryDegradeReason { schemaBlocked, streamError }

/// 生產預設：經共用 writer 輸出，domain 為 `history`。
final LogSink<HistoryLogEvent> defaultHistoryLogSink =
    defaultLogSink<HistoryLogEvent>('history');
