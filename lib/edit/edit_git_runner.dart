import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_git_port.dart';

const String _tag = 'edit.git';
const int _warningLevel = 900;

/// SPEC-009 FR-01：`git` 子行程各自計時，自啟動起算的逾時秒數。
const int gitTimeoutSeconds = 5; // magic-exempt

/// 逾時計時器：回傳在 [duration] 之後完成的 Future。測試注入虛擬時間版本。
typedef EditTimer = Future<void> Function(Duration duration);

/// 需求：[SPEC-009 FR-01] 本 domain 的 git 呼叫統一入口：一律 `-C <工作區根>`，
/// 環境設 `LC_ALL=C`，各呼叫自啟動起算 5 秒逾時，逾時即終止子行程。
///
/// 無法啟動、逾時、行程錯誤一律回傳 null，由呼叫端歸入既有結果（`git show`
/// 視同 H 無法判定，`hash-object` 歸 `snapshotFailed`）。
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

  Future<EditGitResult?> run(
    List<String> subcommand, {
    Uint8List? stdin,
  }) async {
    final invocation = EditGitInvocation(
      arguments: ['-C', root, ...subcommand],
      environment: _environment,
      stdin: stdin,
    );
    final call = await _start(invocation);
    return call == null ? null : _awaitOrKill(call, subcommand.first);
  }

  Future<EditGitCall?> _start(EditGitInvocation invocation) async {
    try {
      return await port.start(invocation);
    } on EditGitLaunchException catch (error) {
      _log('git launch failed: ${error.message}'); // i18n-exempt
      return null;
    }
  }

  Future<EditGitResult?> _awaitOrKill(EditGitCall call, String name) async {
    call.result.ignore();
    final expired = timer(timeout).then<EditGitResult?>((_) => null);
    try {
      final result = await Future.any<EditGitResult?>([call.result, expired]);
      if (result == null) {
        call.kill();
        _log('git $name timed out, process killed'); // i18n-exempt
      }
      return result;
    } on Object catch (error) {
      _log('git $name failed: ${error.runtimeType}'); // i18n-exempt
      return null;
    }
  }

  void _log(String message) =>
      developer.log(message, name: _tag, level: _warningLevel);
}
