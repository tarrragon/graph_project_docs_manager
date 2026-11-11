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
