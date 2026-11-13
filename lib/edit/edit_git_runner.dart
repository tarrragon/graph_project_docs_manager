import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

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
    this._logSink,
  });

  static const Duration timeout = Duration(seconds: gitTimeoutSeconds);
  static const Map<String, String> _environment = {'LC_ALL': 'C'};

  final EditGitPort port;
  final EditTimer timer;
  final String root;
  final LogSink<EditLogEvent>? _logSink;

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
    return call == null ? null : _awaitOrKill(call);
  }

  Future<EditGitCall?> _start(EditGitInvocation invocation) async {
    try {
      return await port.start(invocation);
    } on EditGitLaunchException catch (error) {
      _log(EditLogEvent.gitLaunchFailed, error);
      return null;
    }
  }

  Future<EditGitResult?> _awaitOrKill(EditGitCall call) async {
    call.result.ignore();
    final expired = timer(timeout).then<EditGitResult?>((_) => null);
    try {
      final result = await Future.any<EditGitResult?>([call.result, expired]);
      if (result == null) {
        call.kill();
        _log(EditLogEvent.gitTimedOut);
      }
      return result;
    } on Object catch (error) {
      _log(EditLogEvent.gitRunFailed, error);
      return null;
    }
  }

  void _log(EditLogEvent event, [Object? error]) =>
      (_logSink ?? defaultEditLogSink())(
        event,
        LogFields.empty,
        level: LogLevel.warning,
        source: ErrorSource.externalProcess,
        error: error,
      );
}
