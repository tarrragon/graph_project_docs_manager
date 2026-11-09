/// fake 程序執行器（SPEC-008 測試設計 §1.4，012.5）。
///
/// 依引數樣式回應；可設「無法啟動」例外、結束碼、分段 stdout（可暫停以測取消）；
/// 記錄每次呼叫的引數、環境變數與 kill。不啟動任何真實程序。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';

/// 一次性呼叫的預設回應：[GitCommandResult] 或會被拋出的 [GitLaunchException]。
typedef FakeResponse = Object;

GitCommandResult okResponse(String stdout) =>
    GitCommandResult(exitCode: 0, stdout: stdout);

GitCommandResult failResponse(int exitCode, {String stderr = ''}) =>
    GitCommandResult(exitCode: exitCode, stdout: '', stderr: stderr);

/// 掃描行程腳本。
class FakeScanScript {
  FakeScanScript._(this._controller, this._autoExit, this.stderrText);

  /// 立即送出 [chunks] 後以 [exitCode] 結束。
  factory FakeScanScript.complete(
    List<List<int>> chunks, {
    int exitCode = 0,
    String stderr = '',
  }) {
    final controller = StreamController<List<int>>();
    final script = FakeScanScript._(controller, exitCode, stderr);
    scheduleMicrotask(() async {
      for (final chunk in chunks) {
        controller.add(chunk);
      }
      await controller.close();
    });
    return script;
  }

  /// 立即以 [exitCode] 結束且無輸出。
  factory FakeScanScript.exit(int exitCode, {String stderr = ''}) =>
      FakeScanScript.complete(const [], exitCode: exitCode, stderr: stderr);

  /// 手動控制：呼叫 [emit] 送出分段輸出，[finish] 結束；未結束前可被取消。
  factory FakeScanScript.manual() =>
      FakeScanScript._(StreamController<List<int>>(), null, '');

  /// 以計數型 stream 產生 [totalBytes] 位元組（不實際配置全量），再以 0 結束。
  factory FakeScanScript.counting(int totalBytes, {int chunkSize = 1 << 20}) {
    final chunk = Uint8List(chunkSize);
    final controller = StreamController<List<int>>();
    final script = FakeScanScript._(controller, 0, '');
    scheduleMicrotask(() async {
      var remaining = totalBytes;
      while (remaining > 0) {
        final size = remaining < chunkSize ? remaining : chunkSize;
        controller.add(
          size == chunkSize ? chunk : Uint8List.sublistView(chunk, 0, size),
        );
        remaining -= size;
        await Future<void>.delayed(Duration.zero);
      }
      await controller.close();
    });
    return script;
  }

  final StreamController<List<int>> _controller;
  final int? _autoExit;
  final String stderrText;

  void emit(List<int> bytes) => _controller.add(bytes);

  void emitText(String text) => _controller.add(utf8.encode(text));

  Future<void> finish({int exitCode = 0}) async {
    _manualExit = exitCode;
    await _controller.close();
  }

  int? _manualExit;
  int? get autoExit => _autoExit;
  int? get manualExit => _manualExit;
}

class _FakeScanProcess implements GitScanProcess {
  _FakeScanProcess(this.script, this.onKill) {
    script._controller.onCancel = null;
    _stdout = script._controller.stream;
    script._controller.done.then((_) => _complete(null));
  }

  final FakeScanScript script;
  final void Function() onKill;
  late final Stream<List<int>> _stdout;
  final Completer<int> _exit = Completer<int>();

  void _complete(int? signalExit) {
    if (_exit.isCompleted) return;
    _exit.complete(signalExit ?? script.autoExit ?? script.manualExit ?? 0);
  }

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Future<String> get stderr => Future.value(script.stderrText);

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void kill() {
    onKill();
    _complete(-15);
    if (!script._controller.isClosed) {
      script._controller.close();
    }
  }
}

/// fake 程序執行器：預設回應為「版本 2.43、在工作樹、非淺層、HEAD 存在」。
class FakeProcessRunner implements GitProcessRunner {
  FakeProcessRunner({FakeScanScript Function()? scanFactory})
    : scanFactory = scanFactory ?? (() => FakeScanScript.complete(const []));

  FakeResponse version = okResponse('git version 2.43.0\n');
  FakeResponse workTree = okResponse('true\nfalse\n');
  FakeResponse head = okResponse('${'a' * 40}\n');
  FakeResponse mainline = okResponse('${'a' * 40}\n${'b' * 40}\n');
  FakeResponse tags = okResponse('');
  FakeScanScript Function() scanFactory;

  final List<GitInvocation> calls = [];
  int scanStartCount = 0;
  int killCount = 0;

  /// 一次性呼叫的類別序列（version、workTree、head、mainline、tags）。
  List<String> get callKinds => [for (final call in calls) _kindOf(call)];

  List<GitInvocation> get scanCalls => [
    for (final call in calls)
      if (_kindOf(call) == 'scan') call,
  ];

  static String _kindOf(GitInvocation call) {
    final args = call.arguments;
    if (args.contains('--version')) return 'version';
    if (args.contains('--is-inside-work-tree')) return 'workTree';
    if (args.contains('--verify')) return 'head';
    if (args.contains('rev-list')) return 'mainline';
    if (args.contains('for-each-ref')) return 'tags';
    if (args.contains('log')) return 'scan';
    return 'unknown';
  }

  FakeResponse _responseFor(String kind) => switch (kind) {
    'version' => version,
    'workTree' => workTree,
    'head' => head,
    'mainline' => mainline,
    'tags' => tags,
    _ => throw StateError('unexpected git call: $kind'),
  };

  @override
  Future<GitCommandResult> run(GitInvocation invocation) async {
    calls.add(invocation);
    final response = _responseFor(_kindOf(invocation));
    if (response is GitLaunchException) throw response;
    return response as GitCommandResult;
  }

  @override
  Future<GitScanProcess> start(GitInvocation invocation) async {
    calls.add(invocation);
    if (version is GitLaunchException) throw version as GitLaunchException;
    scanStartCount++;
    return _FakeScanProcess(scanFactory(), () => killCount++);
  }
}
