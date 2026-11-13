import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_git_port.dart';

/// SPEC-009 FR-01：`git` 子行程各自計時，自啟動起算的逾時秒數。
const int gitTimeoutSeconds = 5; // magic-exempt

/// 逾時計時器：回傳在 [duration] 之後完成的 Future。測試注入虛擬時間版本。
typedef EditTimer = Future<void> Function(Duration duration);

/// 一次 git 呼叫的結局（SPEC-009 FR-07 v1.14：失敗細節交回呼叫端，由語意層
/// 事件記錄，本層不記事件）。
sealed class EditGitOutcome {
  const EditGitOutcome();
}

/// 行程已結束，帶結束碼與輸出。
final class EditGitCompleted extends EditGitOutcome {
  const EditGitCompleted(this.result);

  final EditGitResult result;
}

/// 行程無法啟動。
final class EditGitLaunchFailed extends EditGitOutcome {
  const EditGitLaunchFailed();
}

/// 行程逾時並已終止。
final class EditGitTimedOut extends EditGitOutcome {
  const EditGitTimedOut();
}

/// 等待結果時拋出執行期例外。
final class EditGitRunFailed extends EditGitOutcome {
  const EditGitRunFailed();
}

/// 需求：[SPEC-009 FR-01] 本 domain 的 git 呼叫統一入口：一律 `-C <工作區根>`，
/// 環境設 `LC_ALL=C`，各呼叫自啟動起算 5 秒逾時，逾時即終止子行程。
///
/// 不自行記事件：無法啟動、逾時、行程錯誤以 [EditGitOutcome] 交回呼叫端，
/// 由呼叫端歸入既有結果（`git show` 視同 H 無法判定，`hash-object` 歸
/// `snapshotFailed`，`rev-parse` 歸唯讀 `gitMissing`）。
class EditGitRunner {
  const EditGitRunner({
    required this.port,
    required this.timer,
    required this.root,
  });

  static const Duration timeout = Duration(seconds: gitTimeoutSeconds);
  static const Map<String, String> _environment = {'LC_ALL': 'C'};

  final EditGitPort port;
  final EditTimer timer;
  final String root;

  Future<EditGitOutcome> run(
    List<String> subcommand, {
    Uint8List? stdin,
  }) async {
    final invocation = EditGitInvocation(
      arguments: ['-C', root, ...subcommand],
      environment: _environment,
      stdin: stdin,
    );
    final call = await _start(invocation);
    return call == null ? const EditGitLaunchFailed() : _awaitOrKill(call);
  }

  Future<EditGitCall?> _start(EditGitInvocation invocation) async {
    try {
      return await port.start(invocation);
    } on EditGitLaunchException {
      return null;
    }
  }

  Future<EditGitOutcome> _awaitOrKill(EditGitCall call) async {
    call.result.ignore();
    final expired = timer(timeout).then<EditGitResult?>((_) => null);
    try {
      final result = await Future.any<EditGitResult?>([call.result, expired]);
      if (result != null) return EditGitCompleted(result);
      call.kill();
      return const EditGitTimedOut();
    } on Object {
      // 執行期例外歸 EditGitRunFailed：細節（含例外訊息）不進日誌，
      // 呼叫端依 FR-07 歸入 executableMissing 或 gitMissing。
      return const EditGitRunFailed();
    }
  }
}
