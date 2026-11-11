// SPEC-008 測試設計 §3.9 F 群組（012.5）與取消（C-8 的 port 層）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../../helpers/history/fake_process_runner.dart';

const String _root = '/work/proj';

void _silent(
  HistoryLogEvent event,
  LogFields fields, {
  LogLevel level = LogLevel.info,
  ErrorSource? source,
  Object? error,
}) {}

GitHistoryPort _port(FakeProcessRunner runner) =>
    GitHistoryPort(runner: runner, logSink: _silent);

Future<GitOpenScanning> _scanning(
  GitHistoryPort port, {
  HistorySchemaReadiness schema = HistorySchemaReadiness.ready,
}) async => await port.open(root: _root, schema: schema) as GitOpenScanning;

void main() {
  group('F 降級與失敗', () {
    test('F-1 / F-4 結束碼 1：讀取失敗，摘要截斷', () async {
      final runner = FakeProcessRunner(
        scanFactory: () => FakeScanScript.exit(1, stderr: 'x' * 2048),
      );
      final open = await _scanning(_port(runner));
      final result = await open.scan.result;
      expect(result, isA<GitScanFailed>());
      final failed = result as GitScanFailed;
      expect(failed.reason, GitFailureReason.scanNonZeroExit);
      expect(failed.exitCode, 1);
      expect(failed.stderrSummary.length, lessThan(2048));
      expect(failed.stderrSummary, isNotEmpty);
    });

    test('F-2 被訊號終止：原因碼程序異常終止', () async {
      final runner = FakeProcessRunner(
        scanFactory: () => FakeScanScript.exit(-9),
      );
      final open = await _scanning(_port(runner));
      final failed = await open.scan.result as GitScanFailed;
      expect(failed.reason, GitFailureReason.processTerminated);
    });

    test('F-3 非 git 專案與找不到 git 皆不是讀取失敗', () async {
      final notTree = FakeProcessRunner()..workTree = failResponse(128);
      final notFound = FakeProcessRunner()
        ..version = const GitLaunchException('missing');
      final a = await _port(notTree).preflight(_root);
      final b = await _port(notFound).preflight(_root);
      expect(a, isA<GitPreflightNotWorkTree>());
      expect(b, isA<GitPreflightGitNotFound>());
      expect(a, isNot(isA<GitPreflightFailed>()));
      expect(b, isNot(isA<GitPreflightFailed>()));
      expect(a.runtimeType, isNot(b.runtimeType));
    });

    test('F-5 Schema 阻擋：不呼叫任何 git', () async {
      final runner = FakeProcessRunner();
      final outcome = await _port(runner)
          .open(root: _root, schema: HistorySchemaReadiness.blocked);
      expect(outcome, isA<GitOpenBlocked>());
      expect(runner.calls, isEmpty);
    });

    test('F-6 內建型別表降級：照常掃描並帶降級標記', () async {
      final runner = FakeProcessRunner();
      final open = await _scanning(
        _port(runner),
        schema: HistorySchemaReadiness.degradedBuiltinTable,
      );
      expect(open.isBuiltinTableDegraded, isTrue);
      expect(runner.scanStartCount, 1);
      final ready = await _scanning(_port(FakeProcessRunner()));
      expect(ready.isBuiltinTableDegraded, isFalse);
    });

    test('F-7 單行無法解碼且結束碼 0：完成', () async {
      final runner = FakeProcessRunner(
        scanFactory: () => FakeScanScript.complete([
          [0xff, 0xfe, 0x0a],
        ]),
      );
      final open = await _scanning(_port(runner));
      await open.scan.stdout.drain<void>();
      expect(await open.scan.result, isA<GitScanCompleted>());
    });

    test('前置檢查停止類別以 GitOpenStopped 回報且不掃描', () async {
      final runner = FakeProcessRunner()..head = failResponse(1);
      final outcome = await _port(runner)
          .open(root: _root, schema: HistorySchemaReadiness.ready);
      expect(outcome, isA<GitOpenStopped>());
      expect(runner.scanStartCount, 0);
    });
  });

  group('取消', () {
    test('取消終止掃描程序並回報已取消', () async {
      final script = FakeScanScript.manual();
      final runner = FakeProcessRunner(scanFactory: () => script);
      final open = await _scanning(_port(runner));
      script.emitText('partial');
      await Future<void>.delayed(Duration.zero);
      open.scan.cancel();
      expect(runner.killCount, 1);
      expect(await open.scan.result, isA<GitScanCancelled>());
      open.scan.cancel();
      expect(runner.killCount, 1, reason: '重複取消不重複終止');
    });

    test('正向對照：未取消則不 kill 並完成', () async {
      final script = FakeScanScript.manual();
      final runner = FakeProcessRunner(scanFactory: () => script);
      final open = await _scanning(_port(runner));
      script.emitText('data');
      await script.finish();
      await open.scan.stdout.drain<void>();
      expect(await open.scan.result, isA<GitScanCompleted>());
      expect(runner.killCount, 0);
    });
  });
}
