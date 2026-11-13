/// edit domain 的日誌事件（SPEC-010 FR-04）。
///
/// 事件名是測試斷言綁定的穩定契約；負載只用 FR-03 白名單型別，例外走
/// `error:`，絕對路徑與例外訊息不入負載。sink 由各 driven port 與協調者的
/// 建構參數注入，未注入時以 [defaultEditLogSink] 取共用 writer。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

/// edit domain 日誌事件（穩定契約）。
enum EditLogEvent {
  /// 開啟工作區並判定編輯模式，負載帶 mode（唯讀時另帶 readonlyReason）。
  editModeDetermined,

  /// 刪除暫存檔失敗，負載帶 path（目標檔）、errorCode（platform_io，warning）。
  tempDeleteFailed,

  /// baseline 量測完成，負載帶 path、measure；unavailable 另帶 exitCode 或
  /// unavailableReason 二擇一（unavailable 為 warning／external_process）。
  baselineMeasured,

  /// baseline 量測拋出未預期例外，負載帶 path（internal，warning）。
  baselineFailed,

  /// 驗證佇列工作拋出未預期例外，負載帶 path（internal，warning）。
  validationJobFailed,

  /// 寫入後驗證有結果，負載帶 path、nodeId（可得時）、outcome（Passed 為
  /// info，其餘 warning）；unavailable 另帶 exitCode 或 unavailableReason 二擇一。
  ///
  /// error_source 只有寫入後量測本身失敗的 unavailable 為 external_process；
  /// 沿用 baseline 原因與 baselineNotReady 不帶（FR-07 v1.14）。
  validationCompleted,

  /// 寫入發出：閘門通過、寫入呼叫發出，負載帶 path、field（info）。
  writeIssued,

  /// 寫入受理：位元組已落檔，負載帶 path、field（info）。
  writeAccepted,

  /// 取得快照，負載帶 path、blob_sha（info）。
  snapshotTaken,

  /// 閘門阻擋，負載帶 path、reason；`snapshotFailed` 另帶 exitCode、
  /// executableMissing、timedOut 三擇一（externallyModified、rewriteNotIsolated
  /// 為 warning／gate_blocked；snapshotFailed 為 error／external_process）。
  writeBlocked,

  /// 讀取目標檔失敗，負載帶 path、operation、errorCode（platform_io，error）。
  readIoFailed,

  /// 寫暫存檔、fsync、設定權限或 rename 失敗，負載同 [readIoFailed]。
  writeIoFailed,
}

/// baseline 量測結果類別。
enum EditMeasureKind { ready, unavailable }

/// 寫入後驗證結果類別。
enum EditValidationOutcome { passed, failed, unavailable }

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class EditLogKeys {
  static const mode = 'mode';
  static const readonlyReason = 'readonlyReason';
  static const errorCode = 'errorCode';
  static const nodeId = 'nodeId';
  static const operation = 'operation';
  static const path = 'path';
  static const measure = 'measure';
  static const outcome = 'outcome';
  static const newIssueCount = 'newIssueCount';
  static const unavailableReason = 'unavailableReason';
  static const reason = 'reason';
  static const field = 'field';
  static const blobSha = 'blob_sha';
  static const exitCode = 'exitCode';
  static const executableMissing = 'executableMissing';
  static const timedOut = 'timedOut';
}

/// 以已驗證的工作區相對路徑（[WorkspaceRelativePath.relative]）建立日誌路徑值。
///
/// 以 `/` 為根包成絕對路徑再交給 [LogValue.path]，避免工作區根的 symlink
/// 差異使路徑落入 [LogLocation.other]。
LogValue editLogPath(String relative) => LogValue.path('/', '/$relative');

/// edit domain 生產預設 sink 的 domain 名。
const String editLogDomain = 'edit';

/// 生產預設 sink（共用 writer）；每次呼叫新建，不持有模組層狀態。
LogSink<EditLogEvent> defaultEditLogSink() =>
    defaultLogSink<EditLogEvent>(editLogDomain);
