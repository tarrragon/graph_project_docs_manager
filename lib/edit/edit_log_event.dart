/// edit domain 的日誌事件（SPEC-010 FR-04）。
///
/// 事件名是測試斷言綁定的穩定契約；負載只用 FR-03 白名單型別，例外走
/// `error:`，絕對路徑與例外訊息不入負載。sink 由各 driven port 與協調者的
/// 建構參數注入，未注入時以 [defaultEditLogSink] 取共用 writer。
library;

import 'package:graph_project_docs_manager/observability/log_sink.dart';

/// edit domain 日誌事件（穩定契約）。
enum EditLogEvent {
  /// 開啟工作區並判定編輯模式，負載帶 mode（唯讀時另帶 readonlyReason）。
  editModeDetermined,

  /// 開始編輯讀取目標檔失敗（platform_io，error）。
  beginEditingReadFailed,

  /// 刪除暫存檔失敗（platform_io，warning）。
  tempDeleteFailed,

  /// `git` 無法啟動（external_process，warning）。
  gitLaunchFailed,

  /// `git` 子行程逾時並已終止（external_process，warning）。
  gitTimedOut,

  /// `git` 子行程執行期拋出例外（external_process，warning）。
  gitRunFailed,

  /// 驗證器無法啟動，負載帶 tool（external_process，warning）。
  validatorLaunchFailed,

  /// 驗證器逾時並已終止，負載帶 tool（external_process，warning）。
  validatorTimedOut,

  /// 驗證器執行期拋出例外，負載帶 tool（external_process，warning）。
  validatorRunFailed,

  /// 寫入閘門的檔案操作失敗，負載帶 operation 與 errorCode（platform_io，error）。
  ioFailed,

  /// baseline 量測完成，負載帶 path、measure。
  baselineMeasured,

  /// baseline 量測拋出未預期例外（internal，warning）。
  baselineFailed,

  /// 驗證佇列工作拋出未預期例外（internal，warning）。
  validationJobFailed,

  /// 寫入後驗證有結果，負載帶 path、outcome（Passed 為 info，其餘 warning）。
  ///
  /// 不帶 error_source：失敗已由驗證器事件各記一次，上層不重記（FR-02）。
  validationCompleted,

  /// 改寫隔離檢查拒絕改寫，負載帶 reason（gate_blocked，error）。
  rewriteNotIsolated,
}

/// baseline 量測結果類別。
enum EditMeasureKind { ready, unavailable }

/// 寫入後驗證結果類別。
enum EditValidationOutcome { passed, failed, unavailable }

/// 改寫被拒絕的原因。
enum EditRewriteRejection {
  targetNotRewritable,
  parseLayerFailed,
  byteLayerFailed,
}

/// 事件負載鍵（具名常數，測試以常數比對）。
abstract final class EditLogKeys {
  static const mode = 'mode';
  static const readonlyReason = 'readonlyReason';
  static const errorCode = 'errorCode';
  static const tool = 'tool';
  static const operation = 'operation';
  static const path = 'path';
  static const measure = 'measure';
  static const outcome = 'outcome';
  static const newIssueCount = 'newIssueCount';
  static const unavailableReason = 'unavailableReason';
  static const reason = 'reason';
}

/// edit domain 生產預設 sink 的 domain 名。
const String editLogDomain = 'edit';

/// 生產預設 sink（共用 writer）；每次呼叫新建，不持有模組層狀態。
LogSink<EditLogEvent> defaultEditLogSink() =>
    defaultLogSink<EditLogEvent>(editLogDomain);
