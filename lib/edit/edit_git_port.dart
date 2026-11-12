/// Edit 的 git 程序 port（SPEC-009 FR-01、FR-02）。
///
/// 不沿用 History 的 `GitProcessRunner`：Edit 不依賴 History（edit
/// domain-map §2），且該介面的 stdout 為 `String`，而本 domain 需要位元組
/// stdout（H 的比對）與位元組標準輸入（快照）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 一次 git 呼叫：引數、附加環境變數與標準輸入位元組。
class EditGitInvocation {
  const EditGitInvocation({
    required this.arguments,
    required this.environment,
    this.stdin,
  });

  final List<String> arguments;
  final Map<String, String> environment;
  final Uint8List? stdin;
}

/// 一次 git 呼叫的結果；stdout 為位元組。
class EditGitResult {
  const EditGitResult({
    required this.exitCode,
    required this.stdout,
    this.stderr = '',
  });

  final int exitCode;
  final Uint8List stdout;
  final String stderr;
}

/// 行程無法啟動（不在 PATH 或無執行權限）。
class EditGitLaunchException implements Exception {
  const EditGitLaunchException(this.message);

  final String message;

  @override
  String toString() => 'EditGitLaunchException: $message';
}

/// 已啟動的 git 行程：可等待結果，或在逾時時終止。
abstract interface class EditGitCall {
  Future<EditGitResult> get result;

  void kill();
}

/// git 程序 driven port。
abstract interface class EditGitPort {
  /// 啟動行程；無法啟動時拋 [EditGitLaunchException]。
  Future<EditGitCall> start(EditGitInvocation invocation);
}

/// 以 `dart:io` [Process] 實作；環境變數為繼承的環境加上 invocation 的附加值。
class IoEditGitPort implements EditGitPort {
  const IoEditGitPort({
    this.executable = 'git',
    this.baseEnvironment = const {},
  });

  final String executable;

  /// 每次呼叫都附加的環境（例：測試 fixture 隔離使用者 git 設定）。
  final Map<String, String> baseEnvironment;

  @override
  Future<EditGitCall> start(EditGitInvocation invocation) async {
    try {
      final process = await Process.start(
        executable,
        invocation.arguments,
        environment: {...baseEnvironment, ...invocation.environment},
      );
      return _IoEditGitCall(process, invocation.stdin);
    } on ProcessException catch (error) {
      throw EditGitLaunchException(error.message);
    }
  }
}

class _IoEditGitCall implements EditGitCall {
  _IoEditGitCall(this._process, Uint8List? stdin) {
    result = _collect(stdin);
  }

  final Process _process;

  @override
  late final Future<EditGitResult> result;

  Future<EditGitResult> _collect(Uint8List? stdin) async {
    final out = _process.stdout.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (b, chunk) => b..add(chunk),
    );
    final err = _process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    await _feed(stdin);
    final exitCode = await _process.exitCode;
    return EditGitResult(
      exitCode: exitCode,
      stdout: (await out).takeBytes(),
      stderr: await err,
    );
  }

  /// git 提早結束時寫入標準輸入會 EPIPE；結束碼才是判定依據，故忽略。
  Future<void> _feed(Uint8List? stdin) async {
    try {
      if (stdin != null) _process.stdin.add(stdin);
      await _process.stdin.close();
    } on Object {
      // 靜默原因：寫入被已結束的行程拒絕，失敗由結束碼與 stderr 表達。
    }
  }

  @override
  void kill() {
    _process.kill();
  }
}
