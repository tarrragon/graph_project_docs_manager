// SPEC-008 測試設計 §2.1 IT-H1：單次 git log -p 的成本量級（FR-01、FR-02、FR-10、NFR-01）。
// 耗時只記錄不作 pass-fail（D1）；斷言為完成、失步計數 0、掃描結束日誌欄位齊全。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/history_fixture_repo.dart';

const String _externalRootEnv = 'HISTORY_IT_FLUTTER_BALANCE_ROOT';
const String _selfRootEnv = 'HISTORY_IT_SELF_ROOT';
const String _reportRelativePath = 'build/history_it_h1_report.json';

/// 找本專案根：環境變數、目前目錄、執行檔所在目錄逐層往上找含 pubspec 的目錄。
Directory? _findProjectRoot() {
  final fromEnv = Platform.environment[_selfRootEnv];
  if (fromEnv != null && Directory(fromEnv).existsSync()) {
    return Directory(fromEnv);
  }
  final starts = [Directory.current, File(Platform.resolvedExecutable).parent];
  for (final start in starts) {
    var dir = start.absolute;
    while (true) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains(
            'name: graph_project_docs_manager',
          )) {
        return dir;
      }
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
  }
  return null;
}

Future<String> _gitVersion() async =>
    ((await Process.run('git', ['--version'])).stdout as String).trim();

Future<String> _machine() async =>
    ((await Process.run('uname', ['-m'])).stdout as String).trim();

Map<String, Object?> _logPayload(
  HistoryPipelineResult result,
  HistoryLogEvent event,
) => result.logs.lastWhere((l) => l.event == event).payload;

Future<Map<String, Object?>> _measure(String root) async {
  final totalWatch = Stopwatch()..start();
  final result = await runHistoryPipeline(
    root,
    PathRestrictedRunner(realPathDirs()),
  );
  totalWatch.stop();
  final completed = result.scanResult;
  expect(completed, isA<GitScanCompleted>(), reason: 'A1 結果型別為完成');
  final scan = completed! as GitScanCompleted;
  final counters = result.counters!;
  // A2：狀態失步計數為 0。
  expect(counters.desyncs, 0, reason: 'A2 失步計數');
  // A3：掃描結束日誌含全部欄位。
  final finished = _logPayload(result, HistoryLogEvent.scanFinished);
  expect(
    finished.keys,
    containsAll([
      HistoryLogKeys.commitCount,
      HistoryLogKeys.outputBytes,
      HistoryLogKeys.gitDurationMs,
    ]),
  );
  final parsed = _logPayload(result, HistoryLogEvent.scanParseReported);
  expect(
    parsed.keys,
    containsAll([
      HistoryLogKeys.parseDurationMs,
      HistoryLogKeys.eventCount,
      HistoryLogKeys.counters,
    ]),
  );
  return _record(result, scan, totalWatch.elapsed);
}

Map<String, Object?> _record(
  HistoryPipelineResult result,
  GitScanCompleted scan,
  Duration total,
) {
  final gitMs = scan.gitDuration.inMilliseconds;
  final parseMs = result.parseDuration.inMilliseconds;
  final counters = result.counters!;
  return {
    'commitCount': scan.commitCount,
    'outputBytes': scan.outputBytes,
    'gitDurationMs': gitMs,
    'parseDurationMs': parseMs,
    'totalDurationMs': total.inMilliseconds,
    'eventCount': result.events.length,
    'peakTrackedChars': result.peakTrackedChars,
    'desyncs': counters.desyncs,
    'undecodableLines': counters.undecodableLines,
    'unparsableVersions': counters.unparsableVersions,
    'filesWithoutId': result.filesWithoutId,
    'nonStringValues': result.nonStringValues,
    // NFR-01：總耗時超過 git 耗時兩倍時停手回報（不作 pass-fail）。
    'nfr01TotalOverTwiceGit': total.inMilliseconds > 2 * gitMs,
  };
}

Future<void> _writeReport(
  Directory projectRoot,
  String target,
  Map<String, Object?> measurement,
) async {
  final file = File('${projectRoot.path}/$_reportRelativePath');
  await file.parent.create(recursive: true);
  final report = file.existsSync()
      ? jsonDecode(await file.readAsString()) as Map<String, Object?>
      : <String, Object?>{};
  report['environment'] = {
    'machine': await _machine(),
    'os': Platform.operatingSystemVersion,
    'git': await _gitVersion(),
    'date': DateTime.now().toIso8601String(),
  };
  report[target] = measurement;
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  // 量測值同時印出，供收尾寫入 ticket。
  // ignore: avoid_print
  print('IT-H1 $target: ${jsonEncode(measurement)}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final projectRoot = _findProjectRoot();
  final externalRoot = Platform.environment[_externalRootEnv];

  test(
    'IT-H1 本專案',
    () async {
      final measurement = await _measure(projectRoot!.path);
      await _writeReport(projectRoot, 'selfProject', measurement);
    },
    skip: projectRoot == null ? '找不到本專案根（可設 $_selfRootEnv）' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'IT-H1 flutter_balance（live）',
    () async {
      final measurement = await _measure(externalRoot!);
      await _writeReport(projectRoot!, 'flutterBalance', measurement);
    },
    tags: ['live'],
    skip: (externalRoot == null || projectRoot == null)
        ? '環境變數 $_externalRootEnv 未設定，外部 repo 缺席；不算通過'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
