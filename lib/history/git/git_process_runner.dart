/// git 程序 driven port（SPEC-008 FR-01）：啟動、逐塊串流 stdout、結束碼、終止。
///
/// 實作以 `dart:io` [Process]；domain 測試以 fake 替換。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次 git 呼叫。工作目錄恆不改變（規則 1），目錄由 `-C <根>` 引數指定。
class GitInvocation {
  const GitInvocation({required this.arguments, required this.environment});

  final List<String> arguments;
  final Map<String, String> environment;
}

/// 一次性呼叫的結果。
class GitCommandResult {
  const GitCommandResult({
    required this.exitCode,
    required this.stdout,
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// 行程無法啟動（不在 PATH 或無執行權限）。
class GitLaunchException implements Exception {
  const GitLaunchException(this.message);

  final String message;

  @override
  String toString() => 'GitLaunchException: $message';
}

/// 長時間執行的掃描行程。
abstract interface class GitScanProcess {
  /// stdout 位元組串流（單訂閱）。
  Stream<List<int>> get stdout;

  /// stderr 文字（行程結束後才完整；僅供摘要，不供判定）。
  Future<String> get stderr;

  /// 結束碼；被訊號終止時為負值。
  Future<int> get exitCode;

  /// 終止行程。
  void kill();
}

/// 程序執行 port。
abstract interface class GitProcessRunner {
  /// 執行並等待結束。無法啟動時拋 [GitLaunchException]。
  Future<GitCommandResult> run(GitInvocation invocation);

  /// 啟動長時間行程。無法啟動時拋 [GitLaunchException]。
  Future<GitScanProcess> start(GitInvocation invocation);
}

/// 以 `dart:io` [Process] 實作。
class IoGitProcessRunner implements GitProcessRunner {
  const IoGitProcessRunner({this.executable = 'git'});

  final String executable;

  @override
  Future<GitCommandResult> run(GitInvocation invocation) async {
    try {
      final result = await Process.run(
        executable,
        invocation.arguments,
        environment: invocation.environment,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return GitCommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout as String,
        stderr: result.stderr as String,
      );
    } on ProcessException catch (error) {
      throw GitLaunchException(error.message);
    }
  }

  @override
  Future<GitScanProcess> start(GitInvocation invocation) async {
    try {
      final process = await Process.start(
        executable,
        invocation.arguments,
        environment: invocation.environment,
      );
      return _IoGitScanProcess(process);
    } on ProcessException catch (error) {
      throw GitLaunchException(error.message);
    }
  }
}

class _IoGitScanProcess implements GitScanProcess {
  _IoGitScanProcess(this._process)
    : stderr = _process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();

  final Process _process;

  @override
  final Future<String> stderr;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void kill() {
    _process.kill();
  }
}
