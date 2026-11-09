/// SPEC-008 FR-01、FR-08 結果型別：前置檢查四類、掃描三態、Schema 就緒度。
///
/// 三種定案降級（非 git 專案、找不到 git、淺層 clone）與「讀取失敗」各有獨立型別，
/// 判定只依結束碼與結構化輸出（FR-08 規則 7）。
library;

/// 附帶於 `refs/tags` 的一個 tag。
class GitTagRef {
  const GitTagRef({required this.name, required this.commitId});

  final String name;

  /// annotated tag 為其指向的 commit（已剝殼），輕量 tag 為自身目標。
  final String commitId;

  @override
  bool operator ==(Object other) =>
      other is GitTagRef && other.name == name && other.commitId == commitId;

  @override
  int get hashCode => Object.hash(name, commitId);
}

/// 「讀取失敗」的原因碼。
enum GitFailureReason {
  /// git 版本低於 2.31。
  gitVersionTooOld,

  /// `git --version` 輸出無法解析。
  gitVersionUnreadable,

  /// 前置檢查中的 rev-list／for-each-ref 非 0 結束。
  preflightCommandFailed,

  /// 掃描程序非 0 結束。
  scanNonZeroExit,

  /// 掃描程序被訊號終止（結束碼為負值）。
  processTerminated,

  /// 前置檢查通過後掃描行程仍無法啟動。
  scanLaunchFailed,
}

/// 前置檢查結果（四類加「讀取失敗」）。
sealed class GitPreflightOutcome {
  const GitPreflightOutcome();
}

/// 正常（含淺層與否）。
final class GitPreflightReady extends GitPreflightOutcome {
  const GitPreflightReady({
    required this.gitVersion,
    required this.isShallow,
    required this.head,
    required this.mainline,
    required this.tags,
  });

  final String gitVersion;
  final bool isShallow;
  final String head;

  /// `git rev-list --first-parent HEAD` 的輸出（由新到舊）。
  final List<String> mainline;
  final List<GitTagRef> tags;
}

/// 不是 git 工作樹。
final class GitPreflightNotWorkTree extends GitPreflightOutcome {
  const GitPreflightNotWorkTree();
}

/// git 無法啟動（不在 PATH 或無執行權限）。
final class GitPreflightGitNotFound extends GitPreflightOutcome {
  const GitPreflightGitNotFound();
}

/// 工作樹存在但沒有任何 commit。
final class GitPreflightNoCommit extends GitPreflightOutcome {
  const GitPreflightNoCommit({required this.gitVersion});

  final String gitVersion;
}

/// 讀取失敗（可重試）。
final class GitPreflightFailed extends GitPreflightOutcome {
  const GitPreflightFailed({
    required this.reason,
    this.exitCode,
    this.stderrSummary = '',
  });

  final GitFailureReason reason;
  final int? exitCode;
  final String stderrSummary;
}

/// 掃描結束結果。
sealed class GitScanResult {
  const GitScanResult();
}

final class GitScanCompleted extends GitScanResult {
  const GitScanCompleted({
    required this.outputBytes,
    required this.commitCount,
    required this.gitDuration,
  });

  final int outputBytes;
  final int commitCount;
  final Duration gitDuration;
}

final class GitScanFailed extends GitScanResult {
  const GitScanFailed({
    required this.reason,
    required this.exitCode,
    required this.stderrSummary,
  });

  final GitFailureReason reason;
  final int exitCode;
  final String stderrSummary;
}

final class GitScanCancelled extends GitScanResult {
  const GitScanCancelled();
}

/// Schema 對 History 的就緒度（FR-08 規則 6），由組裝端自 Schema 狀態對應而來。
enum HistorySchemaReadiness {
  /// 專案型別表可用。
  ready,

  /// 以內建型別表降級：照常掃描，結果帶降級標記。
  degradedBuiltinTable,

  /// 無可消費的型別表或版本不符等阻擋狀態：不掃描、不呼叫任何 git。
  blocked,
}
