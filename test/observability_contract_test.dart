import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/attention_arbiter.dart';
import 'package:graph_project_docs_manager/components/app_snack_bar.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/history/git/history_log_event.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';

/// SPEC-010 契約守衛（test-design O3-1、O4-1、O4-3）。
///
/// 靜態守衛的失效方向是放行，故每個守衛皆含正向對照輸入：
/// O4-1 以記憶體樣本證明掃描函式會判紅；O3-1 以 positive/negative 成對 fixture
/// 證明紅燈來自字串值而非 fixture 本身壞掉。
final RegExp _logSinkTypedef = RegExp(
  r'^\s*typedef\s+\w*LogSink\b',
  multiLine: true,
);

int countLogSinkTypedefs(String source) =>
    _logSinkTypedef.allMatches(source).length;

const String _fixtureDir = 'test/fixtures/observability/whitelist';
const String _scratchDir = '.dart_tool/observability_whitelist_guard';
const String _negativeMarker = 'NEGATIVE-LINE';

void main() {
  group('O4-1 LogSink typedef 唯一', () {
    test('掃描函式對含兩處 typedef 的樣本判紅（正向對照）', () {
      const sample = '''
typedef LogSink<E extends Enum> = void Function(E event);
typedef WorkspaceLogSink = void Function(String message);
''';
      expect(countLogSinkTypedefs(sample), 2);
    });

    test('lib/ 內恰一處 typedef ... LogSink', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final count = countLogSinkTypedefs(entity.readAsStringSync());
        for (var i = 0; i < count; i++) {
          hits.add(entity.path);
        }
      }
      expect(hits, ['lib/observability/log_sink.dart']);
    });
  });

  group('O4-3 既有事件 enum 值名稱凍結（test-design §7）', () {
    List<String> names(List<Enum> values) => [for (final v in values) v.name];

    test('WorkspaceLogEvent', () {
      expect(names(WorkspaceLogEvent.values), _frozenWorkspace);
    });
    test('AttentionArbiterLogEvent', () {
      expect(names(AttentionArbiterLogEvent.values), _frozenArbiter);
    });
    test('AppSnackBarLogEvent', () {
      expect(names(AppSnackBarLogEvent.values), _frozenSnackBar);
    });
    test('GraphLogEvent', () {
      expect(names(GraphLogEvent.values), _frozenGraph);
    });
    test('HistoryLogEvent', () {
      expect(names(HistoryLogEvent.values), _frozenHistory);
    });
  });

  group('O3-1 欄位值白名單編譯期守衛', () {
    late List<String> positiveErrors;
    late List<String> negativeErrors;
    late String negativeSource;

    setUpAll(() async {
      final scratch = Directory(_scratchDir)..createSync(recursive: true);
      Future<List<String>> analyzeFixture(String name) async {
        final text = File('$_fixtureDir/$name.dart.txt').readAsStringSync();
        if (name == 'negative') negativeSource = text;
        final target = File('${scratch.path}/$name.dart')
          ..writeAsStringSync(text);
        final ProcessResult result;
        try {
          result = await Process.run('fvm', [
            'dart',
            'analyze',
            '--format=machine',
            target.path,
          ]);
        } on ProcessException catch (e) {
          fail('找不到 fvm，無法執行 O3-1（不得改用 PATH 上的 dart）：$e');
        }
        return [
          for (final line in '${result.stdout}\n${result.stderr}'.split('\n'))
            if (line.startsWith('ERROR|')) line,
        ];
      }

      positiveErrors = await analyzeFixture('positive');
      negativeErrors = await analyzeFixture('negative');
    });

    tearDownAll(() {
      final scratch = Directory(_scratchDir);
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('positive：包裝型別 0 個 error（正向對照）', () {
      expect(positiveErrors, isEmpty);
    });

    test('negative：字串值至少一個 error，且位置在字串值那一行', () {
      expect(negativeErrors, isNotEmpty);
      final markerLine =
          negativeSource
              .split('\n')
              .indexWhere((l) => l.contains(_negativeMarker)) +
          1;
      expect(markerLine, greaterThan(0));
      for (final error in negativeErrors) {
        final fields = error.split('|');
        expect(int.parse(fields[4]), markerLine, reason: error);
      }
    });
  });
}

const _frozenWorkspace = [
  'chooseFolderPanelOpening',
  'chooseFolderPanelUnavailable',
  'chooseFolderCancelled',
  'chooseFolderPathSelected',
  'persistIssuing',
  'persistPreferencesReady',
  'persistCompleted',
  'persistWriteReturnedFalse',
  'persistWriteThrew',
  'openPathIssuing',
  'restoreIssuing',
  'restoreOpenThrew',
  'restorePreferencesReady',
  'restoreMigrated',
  'restoreMigrationFailed',
  'restoreNoStoredPath',
  'restoreCompleted',
  'adapterProbeExistsResult',
  'adapterProbeReadFirstEntryResult',
  'adapterPreferencesOpenResult',
  'adapterPreferencesReadResult',
  'adapterPreferencesWriteResult',
  'recentProjectsLoadIssuing',
  'recentProjectsLoadOpenThrew',
  'recentProjectsAddIssuing',
  'recentProjectsAddOpenThrew',
  'recentProjectsAddWriteSucceeded',
  'recentProjectsAddWriteReturnedFalse',
  'recentProjectsAddWriteThrew',
  'recentProjectsMissing',
  'recentProjectsCorrupted',
  'recentProjectsLoaded',
  'recentProjectsWriteBaseCorrupted',
  'recentProjectCountsInvalid',
  'countsSaveIssuing',
  'countsSaveOpenThrew',
  'countsSaveNoMatchingProject',
  'countsSaveBaseCorrupted',
  'countsSaveWriteSucceeded',
  'countsSaveWriteReturnedFalse',
  'countsSaveWriteThrew',
  'inspectExistsIssuing',
  'inspectReadIssuing',
  'inspectReadFailed',
  'probeRecentProjectTimedOut',
];

const _frozenArbiter = [
  'accepted',
  'preempted',
  'sameLevelReplaced',
  'skipped',
  'rejected',
  'deferred',
  'presented',
  'released',
  'expired',
  'releasedNonHolder',
  'invalidRequest',
  'levelClamped',
];

const _frozenSnackBar = [
  'shown',
  'skippedUnmounted',
  'actionPressed',
  'closed',
  'preempted',
  'yielded',
  'clearedByProjectChange',
];

const _frozenGraph = [
  'buildCompleted',
  'buildUnavailable',
  'adjacencyUnavailable',
  'flowUnavailable',
  'bundleOrderUnavailable',
  'domainUcRelationUnavailable',
];

const _frozenHistory = [
  'preflightEntered',
  'preflightResult',
  'degraded',
  'scanStarted',
  'scanFinished',
  'scanParseReported',
  'scanCancelled',
  'tripwire',
  'processStarted',
  'processExited',
  'processKilled',
  'processLaunchFailed',
];
