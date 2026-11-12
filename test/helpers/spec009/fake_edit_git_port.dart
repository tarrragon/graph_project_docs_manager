import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/edit/edit_git_port.dart';

/// [FakeEditGitPort] 對一次呼叫的回應。
sealed class FakeGitReply {
  const FakeGitReply();
}

/// 立即以指定結束碼與 stdout 位元組結束。
final class GitExit extends FakeGitReply {
  GitExit(this.code, {Uint8List? stdout, this.stderr = ''})
    : stdout = stdout ?? Uint8List(0);

  GitExit.text(this.code, String text, {this.stderr = ''})
    : stdout = Uint8List.fromList(utf8.encode(text));

  final int code;
  final Uint8List stdout;
  final String stderr;
}

/// 行程無法啟動。
final class GitLaunchFail extends FakeGitReply {
  const GitLaunchFail();
}

/// 永不完成（用於逾時測試）。
final class GitHang extends FakeGitReply {
  const GitHang();
}

/// 由測試手動完成。
final class GitDeferred extends FakeGitReply {
  GitDeferred() : completer = Completer<EditGitResult>();

  final Completer<EditGitResult> completer;
}

/// 需求：[SPEC-009-test-design §1.4] 依引數回應；以位元組回傳 stdout；記錄
/// 引數、標準輸入、環境變數；可設定無法啟動或永不完成，並記錄被終止的呼叫。
class FakeEditGitPort implements EditGitPort {
  FakeEditGitPort(this.respond);

  /// 工作區為 repo 的標準回應：探測回 `true`；`show` 依 [head]（null 表示
  /// 路徑不在 HEAD）；`hash-object` 回傳 [sha]。
  factory FakeEditGitPort.repo({Uint8List? head, String? sha}) {
    final hash = sha ?? defaultSha;
    return FakeEditGitPort((args) {
      switch (subcommandOf(args)) {
        case 'rev-parse':
          return GitExit.text(0, 'true\n');
        case 'show':
          return head == null
              ? GitExit(128, stderr: notInHeadStderr)
              : GitExit(0, stdout: head);
        case 'hash-object':
          return GitExit.text(0, '$hash\n');
        default:
          return GitExit(1);
      }
    });
  }

  static const String defaultSha = '0123456789abcdef0123456789abcdef01234567';
  static const String notInHeadStderr =
      "fatal: path 'x' exists on disk, but not in 'HEAD'";

  /// 取出 `-C <根> <子命令> ...` 的子命令。
  static String subcommandOf(List<String> args) =>
      args.length > 2 && args[0] == '-C' ? args[2] : args.first;

  FakeGitReply Function(List<String> args) respond;
  final List<EditGitInvocation> calls = [];
  final List<List<String>> killed = [];

  List<String> get subcommands => [
    for (final call in calls) subcommandOf(call.arguments),
  ];

  EditGitInvocation callOf(String subcommand) =>
      calls.firstWhere((c) => subcommandOf(c.arguments) == subcommand);

  @override
  Future<EditGitCall> start(EditGitInvocation invocation) async {
    calls.add(invocation);
    final reply = respond(invocation.arguments);
    if (reply is GitLaunchFail) {
      throw const EditGitLaunchException('fake: cannot launch');
    }
    return _FakeCall(this, invocation.arguments, _resultOf(reply));
  }

  Future<EditGitResult> _resultOf(FakeGitReply reply) => switch (reply) {
    GitExit() => Future.value(
      EditGitResult(
        exitCode: reply.code,
        stdout: reply.stdout,
        stderr: reply.stderr,
      ),
    ),
    GitDeferred() => reply.completer.future,
    _ => Completer<EditGitResult>().future,
  };
}

class _FakeCall implements EditGitCall {
  _FakeCall(this._port, this._args, this.result);

  final FakeEditGitPort _port;
  final List<String> _args;

  @override
  final Future<EditGitResult> result;

  @override
  void kill() => _port.killed.add(_args);
}
