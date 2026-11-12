// SPEC-008 測試設計 §3.11 L-1～L-6、L-8（012.5）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../../helpers/history/fake_process_runner.dart';

const String _root = '/work/proj';
const int _mib = 1024 * 1024;

class _Recorder {
  final List<(HistoryLogEvent, Map<String, Object?>, LogLevel)> entries = [];

  void sink(
    HistoryLogEvent event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) => entries.add((event, fields.toJson(), level));

  List<(HistoryLogEvent, Map<String, Object?>, LogLevel)> of(
    HistoryLogEvent event,
  ) => [
    for (final e in entries)
      if (e.$1 == event) e,
  ];
}

Future<GitScanResult> _scan(FakeProcessRunner runner, _Recorder log) async {
  final port = GitHistoryPort(runner: runner, logSink: log.sink);
  final open = await port.open(
    root: _root,
    schema: HistorySchemaReadiness.ready,
  ) as GitOpenScanning;
  await open.scan.stdout.drain<void>();
  return open.scan.result;
}

void main() {
  group('L 日誌', () {
    test('L-1 前置檢查入口與結果類別，含 git 版本', () async {
      final log = _Recorder();
      await GitHistoryPort(
        runner: FakeProcessRunner(),
        logSink: log.sink,
      ).preflight(_root);
      expect(log.of(HistoryLogEvent.preflightEntered), hasLength(1));
      final result = log.of(HistoryLogEvent.preflightResult).single;
      // gitVersion 為自由文字，不在 FR-03 白名單內，不記錄。
      expect(result.$2.containsKey('gitVersion'), isFalse);
      expect(result.$2[HistoryLogKeys.category], 'ready');
    });

    test('L-2 掃描開始與結束日誌，耗時欄位為非負整數', () async {
      final log = _Recorder();
      final runner = FakeProcessRunner(
        scanFactory: () => FakeScanScript.complete([
          [0x1e, 0x41, 0x1e, 0x42],
        ]),
      );
      await _scan(runner, log);
      final start = log.of(HistoryLogEvent.scanStarted).single.$2;
      // 工作區根為絕對路徑，不在白名單內，不記錄。
      expect(start.containsKey('root'), isFalse);
      expect(start[HistoryLogKeys.head], 'a' * 40);
      final end = log.of(HistoryLogEvent.scanFinished).single.$2;
      expect(end[HistoryLogKeys.commitCount], 2);
      expect(end[HistoryLogKeys.outputBytes], 4);
      final ms = end[HistoryLogKeys.gitDurationMs] as int;
      expect(ms, greaterThanOrEqualTo(0));
    });

    test('L-2 解析端補報：解析耗時、事件數、計數', () async {
      final log = _Recorder();
      final port = GitHistoryPort(
        runner: FakeProcessRunner(),
        logSink: log.sink,
      );
      final open = await port.open(
        root: _root,
        schema: HistorySchemaReadiness.ready,
      ) as GitOpenScanning;
      await open.scan.stdout.drain<void>();
      await open.scan.result;
      open.scan.reportParse(
        parseDuration: const Duration(milliseconds: 5),
        eventCount: 7,
        counters: const {'undecodableLines': 1},
      );
      final entry = log.of(HistoryLogEvent.scanParseReported).single.$2;
      expect(entry[HistoryLogKeys.parseDurationMs], 5);
      expect(entry[HistoryLogKeys.eventCount], 7);
      // 計數器攤平為整數欄位。
      expect(entry['undecodableLines'], 1);
    });

    test('L-3 取消日誌', () async {
      final log = _Recorder();
      final script = FakeScanScript.manual();
      final port = GitHistoryPort(
        runner: FakeProcessRunner(scanFactory: () => script),
        logSink: log.sink,
      );
      final open = await port.open(
        root: _root,
        schema: HistorySchemaReadiness.ready,
      ) as GitOpenScanning;
      open.scan.cancel();
      expect(log.of(HistoryLogEvent.scanCancelled), hasLength(1));
      expect(log.of(HistoryLogEvent.processKilled), hasLength(1));
    });

    test('L-4 F-1、P-3、P-4 各一筆降級日誌，含結束碼與 stderr 摘要', () async {
      final log = _Recorder();
      await _scan(
        FakeProcessRunner(
          scanFactory: () => FakeScanScript.exit(1, stderr: 'boom'),
        ),
        log,
      );
      final scanFail = log.of(HistoryLogEvent.degraded).single.$2;
      expect(scanFail[HistoryLogKeys.exitCode], 1);
      // stderr 為自由文字，不在 FR-03 白名單內，不記錄。
      expect(scanFail.containsKey('stderrSummary'), isFalse);

      final notTreeLog = _Recorder();
      await GitHistoryPort(
        runner: FakeProcessRunner()..workTree = failResponse(128),
        logSink: notTreeLog.sink,
      ).preflight(_root);
      final notTree = notTreeLog.of(HistoryLogEvent.degraded).single.$2;
      expect(notTree[HistoryLogKeys.exitCode], 128);

      final notFoundLog = _Recorder();
      await GitHistoryPort(
        runner: FakeProcessRunner()
          ..version = const GitLaunchException('missing'),
        logSink: notFoundLog.sink,
      ).preflight(_root);
      expect(notFoundLog.of(HistoryLogEvent.degraded), hasLength(1));
    });

    test('L-5 256 MiB + 1 位元組：tripwire warning 1 筆', () async {
      final log = _Recorder();
      await _scan(
        FakeProcessRunner(
          scanFactory: () => FakeScanScript.counting(256 * _mib + 1),
        ),
        log,
      );
      final trip = log.of(HistoryLogEvent.tripwire).single;
      expect(trip.$3, LogLevel.warning);
      expect(trip.$2[HistoryLogKeys.outputBytes], isA<int>());
      expect(trip.$2.containsKey(HistoryLogKeys.commitCount), isTrue);
    });

    test('L-6 正向對照：恰 256 MiB 與 1 MiB 無 tripwire', () async {
      for (final size in [256 * _mib, _mib]) {
        final log = _Recorder();
        await _scan(
          FakeProcessRunner(scanFactory: () => FakeScanScript.counting(size)),
          log,
        );
        expect(log.of(HistoryLogEvent.tripwire), isEmpty, reason: '$size');
        expect(log.of(HistoryLogEvent.scanFinished), hasLength(1));
      }
    });

    test('L-8 行程啟動、結束、kill 逐點日誌', () async {
      final log = _Recorder();
      await _scan(FakeProcessRunner(), log);
      expect(log.of(HistoryLogEvent.processStarted), isNotEmpty);
      expect(log.of(HistoryLogEvent.processExited), isNotEmpty);

      final launchLog = _Recorder();
      await GitHistoryPort(
        runner: FakeProcessRunner()..version = const GitLaunchException('x'),
        logSink: launchLog.sink,
      ).preflight(_root);
      expect(launchLog.of(HistoryLogEvent.processLaunchFailed), hasLength(1));
    });
  });
}
