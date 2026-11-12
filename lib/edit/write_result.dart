/// 寫入結果型別（SPEC-009 FR-05 `WriteResult`）。
///
/// 封閉型別：呼叫端以窮舉 switch 區分三種結果，不以日誌抵扣。
library;

/// 閘門阻擋的原因（SPEC-009 FR-01）。
enum BlockedReason { externallyModified, snapshotFailed, rewriteNotIsolated }

/// IO 失敗發生的操作。
enum IoOperation {
  readTarget,
  readBeforeRename,
  writeTemp,
  syncTemp,
  setMode,
  rename,
}

/// IO 失敗分類：只含操作與作業系統錯誤碼，不含路徑以外的訊息，更不含
/// 檔案內容或欄位值（SPEC-009 FR-05、FR-07 C-2）。
final class IoFailure {
  const IoFailure(this.operation, {this.errorCode});

  final IoOperation operation;
  final int? errorCode;

  @override
  String toString() => 'IoFailure(${operation.name}, errorCode: $errorCode)';
}

/// 一次寫入的受理結果。
sealed class WriteResult {
  const WriteResult();
}

/// 位元組已落檔；有快照時帶 [snapshotSha]。
final class Written extends WriteResult {
  const Written({this.snapshotSha});

  final String? snapshotSha;

  @override
  String toString() => 'Written(snapshot: ${snapshotSha ?? '-'})';
}

/// 閘門阻擋，檔案未動。
final class Blocked extends WriteResult {
  const Blocked(this.reason);

  final BlockedReason reason;

  @override
  String toString() => 'Blocked(${reason.name})';
}

/// 讀取、寫入或 rename 失敗，檔案未動。
final class IoFailed extends WriteResult {
  const IoFailed(this.failure);

  final IoFailure failure;

  @override
  String toString() => 'IoFailed($failure)';
}

/// `unavailable` 的原因（SPEC-009 FR-05）。
enum UnavailableReason {
  executableMissing,
  unexpectedExitCode,
  unparsableOutput,
  timedOut,
  baselineNotReady,
}

/// 寫入後驗證的結果（SPEC-009 FR-05 `ValidationStatus`）。
sealed class ValidationStatus {
  const ValidationStatus();
}

/// 驗證進行中。
final class ValidationRunning extends ValidationStatus {
  const ValidationRunning();

  @override
  String toString() => 'ValidationRunning';
}

/// 寫入後的問題集合減去 baseline 為空。
final class ValidationPassed extends ValidationStatus {
  const ValidationPassed();

  @override
  String toString() => 'ValidationPassed';
}

/// 差集非空；[newIssueCount] 為差集大小。檔案不回滾。
final class ValidationFailed extends ValidationStatus {
  const ValidationFailed(this.newIssueCount);

  final int newIssueCount;

  @override
  String toString() => 'ValidationFailed($newIssueCount)';
}

/// 無法判定；不得視為 [ValidationPassed]。
final class ValidationUnavailable extends ValidationStatus {
  const ValidationUnavailable(this.reason);

  final UnavailableReason reason;

  @override
  String toString() => 'ValidationUnavailable(${reason.name})';
}

/// 一次寫入的三個可觀測時刻（SPEC-009 FR-05）：發出、受理、結果。
sealed class WriteObservation {
  const WriteObservation();
}

/// 發出：閘門通過、寫入呼叫發出（寫入進行中）。
final class WriteInProgress extends WriteObservation {
  const WriteInProgress();
}

/// 受理：寫入呼叫回傳。
final class WriteAccepted extends WriteObservation {
  const WriteAccepted(this.result);

  final WriteResult result;
}

/// 結果：寫入後驗證的狀態變化（先 `running`，再終態）。
final class ValidationObserved extends WriteObservation {
  const ValidationObserved(this.status);

  final ValidationStatus status;
}
