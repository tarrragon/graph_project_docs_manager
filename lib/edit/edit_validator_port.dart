/// Edit 的驗證器 port（SPEC-009 FR-05）：執行 `doc validate`、`doc uc verify`。
///
/// 與 git port 分開：驗證器的 stdout 以文字解讀，且逾時為 30 秒、不是 5 秒。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:graph_project_docs_manager/edit/edit_git_runner.dart'
    show EditTimer;
import 'package:graph_project_docs_manager/edit/validation_baseline.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

/// SPEC-009 FR-05：每個驗證子行程各自計時，自啟動起算的逾時秒數。
const int validatorTimeoutSeconds = 30; // magic-exempt

/// 一次驗證器呼叫：驗證器與目標（`doc validate` 為節點 ID，`doc uc verify`
/// 為工作區相對路徑）。
class EditValidatorInvocation {
  const EditValidatorInvocation({required this.tool, required this.target});

  final ValidatorTool tool;
  final String target;
}

/// 一次驗證器呼叫的結果。
class EditValidatorResult {
  const EditValidatorResult({required this.exitCode, required this.stdout});

  final int exitCode;
  final String stdout;
}

/// 行程無法啟動（`uv` 或 doc CLI 不存在、無執行權限）。
class EditValidatorLaunchException implements Exception {
  const EditValidatorLaunchException(this.message);

  final String message;

  @override
  String toString() => 'EditValidatorLaunchException: $message';
}

/// 已啟動的驗證子行程：可等待結果，或在逾時時終止。
abstract interface class EditValidatorCall {
  Future<EditValidatorResult> get result;

  void kill();
}

/// 驗證器 driven port。
abstract interface class EditValidatorPort {
  /// 啟動行程；無法啟動時拋 [EditValidatorLaunchException]。
  Future<EditValidatorCall> start(EditValidatorInvocation invocation);
}

/// 以 `dart:io` [Process] 實作：在工作區根執行 `doc validate <id>` 或
/// `doc uc verify <路徑>`。
class IoEditValidatorPort implements EditValidatorPort {
  const IoEditValidatorPort({
    required this.workingDirectory,
    this.executable = 'doc',
  });

  final String workingDirectory;
  final String executable;

  @override
  Future<EditValidatorCall> start(EditValidatorInvocation invocation) async {
    final arguments = switch (invocation.tool) {
      ValidatorTool.docValidate => ['validate', invocation.target],
      ValidatorTool.ucVerify => ['uc', 'verify', invocation.target],
    };
    try {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );
      return _IoValidatorCall(process);
    } on ProcessException catch (error) {
      throw EditValidatorLaunchException(error.message);
    }
  }
}

class _IoValidatorCall implements EditValidatorCall {
  _IoValidatorCall(this._process) {
    result = _collect();
  }

  final Process _process;

  @override
  late final Future<EditValidatorResult> result;

  Future<EditValidatorResult> _collect() async {
    final out = _process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    unawaited(_process.stderr.drain<void>());
    final exitCode = await _process.exitCode;
    return EditValidatorResult(exitCode: exitCode, stdout: await out);
  }

  @override
  void kill() {
    _process.kill();
  }
}

/// 需求：[SPEC-009 FR-05] 驗證子行程的統一入口：各子行程自啟動起算 30 秒
/// 逾時，逾時即終止並回報 `timedOut`；無法啟動回報 `executableMissing`；
/// 其餘依結束碼與輸出解讀為 [ToolOutcome]。失敗細節（結束碼、原因）交回呼叫端，
/// 本類別不記日誌（FR-07 v1.14：由語意層記錄，下層不重記）。
class EditValidatorRunner {
  const EditValidatorRunner({required this.port, required this.timer});

  static const Duration timeout = Duration(seconds: validatorTimeoutSeconds);

  final EditValidatorPort port;
  final EditTimer timer;

  Future<ToolOutcome> run(ValidatorTool tool, String target) async {
    final invocation = EditValidatorInvocation(tool: tool, target: target);
    final EditValidatorCall call;
    try {
      call = await port.start(invocation);
    } on EditValidatorLaunchException {
      return const ToolUnavailable(UnavailableReason.executableMissing);
    }
    return _awaitOrKill(call, tool);
  }

  Future<ToolOutcome> _awaitOrKill(
    EditValidatorCall call,
    ValidatorTool tool,
  ) async {
    call.result.ignore();
    final expired = timer(timeout).then<EditValidatorResult?>((_) => null);
    try {
      final result = await Future.any<EditValidatorResult?>([
        call.result,
        expired,
      ]);
      if (result == null) {
        call.kill();
        return const ToolUnavailable(UnavailableReason.timedOut);
      }
      return interpretToolOutput(tool, result.exitCode, result.stdout);
    } on Object {
      // 執行期例外歸入 executableMissing；失敗細節由呼叫端的語意層事件記錄。
      return const ToolUnavailable(UnavailableReason.executableMissing);
    }
  }
}
