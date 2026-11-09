// SPEC-008 測試設計 §3.1 P 群組（012.5）：前置檢查與掃描指令。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';

import '../../../helpers/history/fake_process_runner.dart';

const String _root = '/work/proj';

GitHistoryPort _port(FakeProcessRunner runner) =>
    GitHistoryPort(runner: runner, logSink: _silent);

void _silent(
  String message, {
  required event,
  required Map<String, Object?> payload,
  int? level,
}) {}

Future<void> _openAndDrain(GitHistoryPort port) async {
  final outcome = await port.open(
    root: _root,
    schema: HistorySchemaReadiness.ready,
  );
  if (outcome is GitOpenScanning) {
    await outcome.scan.stdout.drain<void>();
    await outcome.scan.result;
  }
}

void main() {
  group('P 前置檢查', () {
    test('P-1 呼叫順序、-C 開頭、LC_ALL=C', () async {
      final runner = FakeProcessRunner();
      await _openAndDrain(_port(runner));
      expect(runner.callKinds, [
        'version',
        'workTree',
        'head',
        'mainline',
        'tags',
        'scan',
      ]);
      for (final call in runner.calls) {
        expect(call.arguments.take(2), ['-C', _root]);
        expect(call.environment['LC_ALL'], 'C');
      }
    });

    test('P-2 掃描引數含 FR-01 規則 3 全部選項與 -- docs/', () async {
      final runner = FakeProcessRunner();
      await _openAndDrain(_port(runner));
      final args = runner.scanCalls.single.arguments;
      const required = [
        'core.quotePath=false',
        'log',
        '-p',
        '--reverse',
        '--first-parent',
        '--diff-merges=first-parent',
        '--no-renames',
        '--no-color',
        '--no-ext-diff',
        '--no-textconv',
        '--no-show-signature',
        '--src-prefix=a/',
        '--dst-prefix=b/',
        '--relative',
      ];
      for (final option in required) {
        expect(args, contains(option));
      }
      expect(args.sublist(args.length - 2), ['--', 'docs/']);
      final format = args.singleWhere((a) => a.startsWith('--format='));
      expect(format, '--format=%x1e%H%x00%P%x00%ct%x00%an%x00%s');
    });

    test('P-3 不在工作樹：分類且掃描 0 次', () async {
      final runner = FakeProcessRunner()..workTree = failResponse(128);
      final outcome = await _port(runner).preflight(_root);
      expect(outcome, isA<GitPreflightNotWorkTree>());
      expect(runner.scanStartCount, 0);
    });

    test('P-4 git 無法啟動：分類且掃描 0 次', () async {
      final runner = FakeProcessRunner()
        ..version = const GitLaunchException('no git');
      final outcome = await _port(runner).preflight(_root);
      expect(outcome, isA<GitPreflightGitNotFound>());
      expect(runner.scanStartCount, 0);
    });

    test('P-5 沒有任何 commit：分類且掃描 0 次', () async {
      final runner = FakeProcessRunner()..head = failResponse(1);
      final outcome = await _port(runner).preflight(_root);
      expect(outcome, isA<GitPreflightNoCommit>());
      expect(runner.scanStartCount, 0);
    });

    test('P-6 正向對照：正常回應恰啟動掃描 1 次', () async {
      final runner = FakeProcessRunner();
      await _openAndDrain(_port(runner));
      expect(runner.scanStartCount, 1);
    });

    test('P-7 git 2.30.9 為版本過舊的讀取失敗', () async {
      final runner = FakeProcessRunner()
        ..version = okResponse('git version 2.30.9\n');
      final outcome = await _port(runner).preflight(_root);
      expect(outcome, isA<GitPreflightFailed>());
      expect(
        (outcome as GitPreflightFailed).reason,
        GitFailureReason.gitVersionTooOld,
      );
      expect(runner.scanStartCount, 0);
    });

    test('P-8 2.31.0 與廠商後綴 2.39.3 通過版本檢查', () async {
      for (final text in [
        'git version 2.31.0\n',
        'git version 2.39.3 (Apple Git-145)\n',
      ]) {
        final runner = FakeProcessRunner()..version = okResponse(text);
        final outcome = await _port(runner).preflight(_root);
        expect(outcome, isA<GitPreflightReady>(), reason: text);
      }
    });

    test('P-9 只依結束碼與結構化輸出，不比對 stderr 文字', () async {
      final notTree = FakeProcessRunner()
        ..workTree = failResponse(128, stderr: '嚴重錯誤：不是 git 儲存庫');
      expect(
        await _port(notTree).preflight(_root),
        isA<GitPreflightNotWorkTree>(),
      );
      final ready = FakeProcessRunner()
        ..workTree = const GitCommandResult(
          exitCode: 0,
          stdout: 'true\nfalse\n',
          stderr: 'fatal: something',
        );
      expect(await _port(ready).preflight(_root), isA<GitPreflightReady>());
    });

    test('淺層旗標與 tag（含 annotated 剝殼）取自結構化輸出', () async {
      final runner = FakeProcessRunner()
        ..workTree = okResponse('true\ntrue\n')
        ..tags = okResponse(
          'v1.0.0\u0000${'1' * 40}\u0000\n'
          'v2.0.0\u0000${'2' * 40}\u0000${'3' * 40}\n',
        );
      final outcome = await _port(runner).preflight(_root) as GitPreflightReady;
      expect(outcome.isShallow, isTrue);
      expect(outcome.gitVersion, '2.43.0');
      expect(outcome.mainline, hasLength(2));
      expect(outcome.tags, [
        GitTagRef(name: 'v1.0.0', commitId: '1' * 40),
        GitTagRef(name: 'v2.0.0', commitId: '3' * 40),
      ]);
    });
  });
}
