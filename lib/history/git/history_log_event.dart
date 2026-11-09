/// SPEC-008 FR-10 日誌事件：事件名是測試斷言綁定的穩定契約，`message` 可自由改寫。
///
/// 形態沿用 `GraphLogEvent` 的注入接縫；生產預設轉呼 `developer.log`。
library;

import 'dart:developer' as developer;

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

  static const String root = 'root';
  static const String head = 'head';
  static const String gitVersion = 'gitVersion';
  static const String category = 'category';
  static const String reason = 'reason';
  static const String exitCode = 'exitCode';
  static const String stderrSummary = 'stderrSummary';
  static const String commitCount = 'commitCount';
  static const String outputBytes = 'outputBytes';
  static const String gitDurationMs = 'gitDurationMs';
  static const String parseDurationMs = 'parseDurationMs';
  static const String eventCount = 'eventCount';
  static const String counters = 'counters';
  static const String arguments = 'arguments';
}

/// 日誌注入接縫。
typedef HistoryLogSink = void Function(
  String message, {
  required HistoryLogEvent event,
  required Map<String, Object?> payload,
  int? level,
});

/// 日誌級別（對應 `package:logging` 數值）。
class HistoryLogLevel {
  HistoryLogLevel._();

  static const int debug = 500;
  static const int info = 800;
  static const int warning = 900;
}

const String _tag = 'HistoryGit';

/// 生產預設：轉呼 `developer.log(name: 'HistoryGit')`。
void defaultHistoryLogSink(
  String message, {
  required HistoryLogEvent event,
  required Map<String, Object?> payload,
  int? level,
}) {
  developer.log(
    '${event.name} $message $payload',
    name: _tag,
    level: level ?? HistoryLogLevel.info,
  );
}
