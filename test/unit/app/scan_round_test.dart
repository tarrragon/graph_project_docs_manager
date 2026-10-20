// 需求：0.5.0-W1-114.19 共用掃描輪次（R1～R7）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/spec006/fake_docs_fs.dart';

const _builtinJson = <String, dynamic>{
  'schema_generated_at_framework_version': '1.0.0',
  'node_types': <String, dynamic>{
    'BuiltinType': <String, dynamic>{'id_pattern': r'^B-[0-9]+$'},
  },
};

const _projectJson = <String, dynamic>{
  'schema_generated_at_framework_version': '1.0.0',
  'node_types': <String, dynamic>{
    'ProjectType': <String, dynamic>{'id_pattern': r'^P-[0-9]+$'},
  },
};

const _emptySummary = ScanSummary(
  totalFilesScanned: 0,
  nodeCount: 0,
  nonNodeWithFrontmatterCount: 0,
  failureReasonCounts: <ParseResultKind, int>{},
  hitCarrierCount: 0,
  noHitCount: 0,
  undeterminedCount: 0,
  carrierPathQueryAvailable: false,
);

CorpusScanResult _emptyScan() => const CorpusScanResult(
  rawNodes: <RawNode>[],
  parseErrors: <ParseError>[],
  parseFailureEvents: [],
  schemaAmbiguousNodes: [],
  summary: _emptySummary,
);

/// 計數替身：記錄呼叫次數與 scanCorpus 收到的 table／fileSystem。
class _Counters {
  int scans = 0;
  int builds = 0;
  final List<TypeTable> tables = [];
  final List<TypeTable> builtinTables = [];
  final List<Map<String, dynamic>?> projectJsons = [];
  final List<DocsFileSystem> fileSystems = [];

  /// 為真時每次 scanCorpus 呼叫登記一道閘門，測試依序放行。
  bool holdScans = false;
  final List<Completer<void>> gates = [];

  ScanCorpusFn get scanFn =>
      ({required fileSystem, required table, required builtinTable}) async {
        scans++;
        tables.add(table);
        builtinTables.add(builtinTable);
        fileSystems.add(fileSystem);
        if (holdScans) {
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
        }
        return _emptyScan();
      };

  BuildGraphFn get buildFn =>
      ({
        required rawNodes,
        required projectSchemaJson,
        required builtinSchemaJson,
      }) {
        builds++;
        projectJsons.add(projectSchemaJson);
        return const GraphBuildUnavailable(
          EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
        );
      };
}

FakeDocsFileSystem _projectFs() => FakeDocsFileSystem()
  ..addFile(projectSchemaRelativePath, utf8.encode(jsonEncode(_projectJson)));

ProviderContainer _container(_Counters counters, {String root = '/ws/a'}) {
  final container = ProviderContainer(
    overrides: [
      scanCorpusFnProvider.overrideWithValue(counters.scanFn),
      buildGraphFnProvider.overrideWithValue(counters.buildFn),
      docsFileSystemFactoryProvider.overrideWithValue((_) => _projectFs()),
      builtinTrackingSchemaJsonProvider.overrideWith((ref) => _builtinJson),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentWorkspaceStateProvider.notifier).state = WorkspaceReady(
    root,
  );
  container.listen(scanRoundProvider, (_, _) {});
  return container;
}

ScanRoundNotifier _round(ProviderContainer c) =>
    c.read(scanRoundProvider.notifier);

/// 於指定路徑的讀取處等待閘門，把舊輪次停在掃描中途。
class _GatedFs extends FakeDocsFileSystem {
  _GatedFs(this.gatePath, this.gate);
  final String gatePath;
  final Completer<void> gate;

  @override
  Future<DocsReadResult> readBytes(String relativePath) async {
    if (relativePath == gatePath) await gate.future;
    return super.readBytes(relativePath);
  }
}

FakeDocsFileSystem _bigFs(FakeDocsFileSystem fs, int n) {
  fs.addFile(projectSchemaRelativePath, utf8.encode(jsonEncode(_projectJson)));
  for (var i = 0; i < n; i++) {
    fs.addFile('docs/f${i.toString().padLeft(3, '0')}.md', utf8.encode('x'));
  }
  return fs;
}

ProviderContainer _realScanContainer(
  DocsFileSystem Function(String) factory,
  List<int> seen,
) {
  final container = ProviderContainer(
    overrides: [
      buildGraphFnProvider.overrideWithValue(_Counters().buildFn),
      docsFileSystemFactoryProvider.overrideWithValue(factory),
      builtinTrackingSchemaJsonProvider.overrideWith((ref) => _builtinJson),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentWorkspaceStateProvider.notifier).state =
      const WorkspaceReady('/ws/a');
  container.listen<ScanRoundState>(scanRoundProvider, (_, next) {
    if (next is ScanRoundRunning) seen.add(next.processedCount);
  });
  return container;
}

void main() {
  test('E2：預設掃描函式接線，processedCount 隨批次遞增', () async {
    final seen = <int>[];
    final container = _realScanContainer(
      (_) => _bigFs(FakeDocsFileSystem(), 70),
      seen,
    );

    await container.read(scanRoundProvider.notifier).ensureRound();

    expect(seen, [0, 32, 64, 70]);
  });

  test('E2：被取代輪次的回報不寫入新輪次', () async {
    final seen = <int>[];
    final gate = Completer<void>();
    var call = 0;
    final container = _realScanContainer((_) {
      call++;
      // 第一輪卡在第 40 個檔（第二批內），第二輪不卡。
      return call == 1
          ? _bigFs(_GatedFs('docs/f040.md', gate), 70)
          : _bigFs(FakeDocsFileSystem(), 10);
    }, seen);
    final notifier = container.read(scanRoundProvider.notifier);

    final first = notifier.ensureRound();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final afterFirstBatch = List<int>.of(seen);
    await notifier.rescan();
    final afterSecond = List<int>.of(seen);
    gate.complete();
    await first;

    expect(afterFirstBatch, [0, 32]);
    expect(afterSecond, [0, 32, 0, 10]);
    expect(seen, afterSecond);
    expect(container.read(scanRoundProvider), isA<ScanRoundCompleted>());
  });

  test('R1（E1）：兩個消費者與一個消費者，scan／build 次數相同', () async {
    final one = _Counters();
    await _round(_container(one)).ensureRound();

    final two = _Counters();
    final notifier = _round(_container(two));
    await Future.wait([notifier.ensureRound(), notifier.ensureRound()]);

    expect([one.scans, one.builds], [1, 1]);
    expect([two.scans, two.builds], [one.scans, one.builds]);
  });

  test('R2：已有完成輪次再次讀取不重掃，回傳同一結果', () async {
    final counters = _Counters();
    final notifier = _round(_container(counters));
    final first = await notifier.ensureRound();
    final second = await notifier.ensureRound();

    expect(identical(first, second), isTrue);
    expect([counters.scans, counters.builds], [1, 1]);
    expect(first!.workspacePath, '/ws/a');
  });

  test('R3：切換工作區使舊輪次失效並開新輪，結果屬新工作區', () async {
    final counters = _Counters();
    final container = _container(counters);
    await _round(container).ensureRound();

    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/b');
    expect(container.read(scanRoundProvider), isA<ScanRoundIdle>());
    final next = await _round(container).ensureRound();

    expect([counters.scans, counters.builds], [2, 2]);
    expect(next!.workspacePath, '/ws/b');
  });

  test('R3 對照：同一路徑重設不使輪次失效', () async {
    final counters = _Counters();
    final container = _container(counters);
    await _round(container).ensureRound();

    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    await _round(container).ensureRound();

    expect(counters.scans, 1);
  });

  test('R4：手動重掃開新輪', () async {
    final counters = _Counters();
    final notifier = _round(_container(counters));
    final first = await notifier.ensureRound();
    final second = await notifier.rescan();

    expect(counters.scans, 2);
    expect(identical(first, second), isFalse);
    expect(await notifier.ensureRound(), same(second));
  });

  test('R5（E1）：降級旗標真／假，scanCorpus 收到的 table 不同', () async {
    final normal = _Counters();
    final normalResult = await _round(_container(normal)).ensureRound();

    final degraded = _Counters();
    final degradedContainer = _container(degraded);
    degradedContainer.read(degradedSchemaProvider.notifier).state = true;
    final degradedResult = await _round(degradedContainer).ensureRound();

    expect(normal.tables.single.nodeTypes.keys, contains('ProjectType'));
    expect(degraded.tables.single.nodeTypes.keys, contains('BuiltinType'));
    expect(
      degraded.tables.single.nodeTypes.keys,
      isNot(contains('ProjectType')),
    );
    expect(normalResult!.isDegraded, isFalse);
    expect(degradedResult!.isDegraded, isTrue);
  });

  test('R5（E1）建圖端：projectSchemaJson 與 builtinTable 在降級／正常兩組各自斷言', () async {
    final normal = _Counters();
    await _round(_container(normal)).ensureRound();

    final degraded = _Counters();
    final degradedContainer = _container(degraded);
    degradedContainer.read(degradedSchemaProvider.notifier).state = true;
    await _round(degradedContainer).ensureRound();

    expect(normal.projectJsons.single, _projectJson);
    expect(degraded.projectJsons.single, _builtinJson);
    expect(normal.projectJsons.single, isNot(degraded.projectJsons.single));
    for (final c in [normal, degraded]) {
      expect(c.builtinTables.single.nodeTypes.keys, ['BuiltinType']);
    }
  });

  test('R6：取消丟棄該輪結果，不寫入 provider，之後讀取開新輪', () async {
    final counters = _Counters()..holdScans = true;
    final container = _container(counters);
    final notifier = _round(container);

    final pending = notifier.ensureRound();
    await pumpEventQueue();
    notifier.discard();
    counters.gates.single.complete();

    expect(await pending, isNull);
    expect(container.read(scanRoundProvider), isA<ScanRoundIdle>());

    counters.holdScans = false;
    final fresh = await notifier.ensureRound();
    expect(fresh, isNotNull);
    expect(counters.scans, 2);
  });

  test('R6 競態：第一輪被擋住時 rescan，先放行第二輪再放行第一輪，最終為第二輪結果', () async {
    final counters = _Counters()..holdScans = true;
    final container = _container(counters);
    final notifier = _round(container);

    final first = notifier.ensureRound();
    await pumpEventQueue();
    final second = notifier.rescan();
    await pumpEventQueue();
    expect(counters.gates, hasLength(2));

    counters.gates[1].complete();
    final secondResult = await second;
    counters.gates[0].complete();

    expect(await first, isNull);
    expect(secondResult, isNotNull);
    final state = container.read(scanRoundProvider);
    expect(state, isA<ScanRoundCompleted>());
    expect((state as ScanRoundCompleted).result, same(secondResult));
  });

  test('R6 競態（工作區切換）：舊工作區的輪次晚完成不覆蓋新工作區結果', () async {
    final counters = _Counters()..holdScans = true;
    final container = _container(counters);
    final notifier = _round(container);

    final first = notifier.ensureRound();
    await pumpEventQueue();
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/b');
    final second = notifier.ensureRound();
    await pumpEventQueue();
    expect(counters.gates, hasLength(2));

    counters.gates[1].complete();
    final secondResult = await second;
    counters.gates[0].complete();

    expect(await first, isNull);
    expect(secondResult!.workspacePath, '/ws/b');
    final state = container.read(scanRoundProvider) as ScanRoundCompleted;
    expect(state.result, same(secondResult));
  });

  test('過期輪次失敗：回傳 null 不往外拋，不影響新輪', () async {
    final counters = _Counters();
    final failing = Completer<void>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        scanCorpusFnProvider.overrideWithValue(({
          required fileSystem,
          required table,
          required builtinTable,
        }) async {
          calls++;
          if (calls == 1) {
            await failing.future;
            throw StateError('boom');
          }
          return _emptyScan();
        }),
        buildGraphFnProvider.overrideWithValue(counters.buildFn),
        docsFileSystemFactoryProvider.overrideWithValue((_) => _projectFs()),
        builtinTrackingSchemaJsonProvider.overrideWith((ref) => _builtinJson),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    container.listen(scanRoundProvider, (_, _) {});
    final notifier = _round(container);

    final first = notifier.ensureRound();
    await pumpEventQueue();
    final second = await notifier.rescan();
    failing.complete();

    expect(await first, isNull);
    expect(second, isNotNull);
  });

  test('非 WorkspaceReady：不開輪，回傳 null', () async {
    final counters = _Counters();
    final container = _container(counters);
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceUnset();

    expect(await _round(container).ensureRound(), isNull);
    expect(counters.scans, 0);
  });

  group('R7 import 方向守衛', () {
    final importPattern = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    );
    final forbidden = RegExp(
      r'^(?:package:graph_project_docs_manager/|(?:\.\./)+)(?:app|screens)/',
    );

    List<String> forbiddenImportsIn(String source) => [
      for (final line in source.split('\n'))
        if (importPattern.firstMatch(line)?.group(1) case final t?
            when forbidden.hasMatch(t))
          t,
    ];

    List<File> dartFilesUnder(Directory root) => root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    Map<String, List<String>> violationsUnder(Directory root) => {
      for (final file in dartFilesUnder(root))
        if (forbiddenImportsIn(file.readAsStringSync()) case final bad
            when bad.isNotEmpty)
          file.path: bad,
    };

    test('E2 正向對照：違規樣本被攔下，合法 import 放行', () {
      const sample =
          "import 'package:graph_project_docs_manager/app/scan_round.dart';\n"
          "import 'package:graph_project_docs_manager/screens/home.dart' as h;\n"
          "export '../app/shell.dart';\n"
          "import 'package:graph_project_docs_manager/schema/type_table.dart';\n";
      expect(forbiddenImportsIn(sample), [
        'package:graph_project_docs_manager/app/scan_round.dart',
        'package:graph_project_docs_manager/screens/home.dart',
        '../app/shell.dart',
      ]);
    });

    test('E2 正向對照：子目錄中的違規檔案被遞迴掃描攔下', () {
      final temp = Directory.systemTemp.createTempSync('scan_round_dir_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final nested = Directory('${temp.path}/sub/deeper')
        ..createSync(recursive: true);
      File('${nested.path}/bad.dart').writeAsStringSync(
        "import 'package:graph_project_docs_manager/app/scan_round.dart';\n",
      );
      File('${temp.path}/ok.dart').writeAsStringSync(
        "import 'package:graph_project_docs_manager/schema/type_table.dart';\n",
      );
      expect(violationsUnder(temp), {
        '${nested.path}/bad.dart': [
          'package:graph_project_docs_manager/app/scan_round.dart',
        ],
      });
    });

    final screensImport = RegExp(
      r'^(?:package:graph_project_docs_manager/|(?:\.\./)+)screens/',
    );

    List<String> screensImportsIn(String source) => [
      for (final line in source.split('\n'))
        if (importPattern.firstMatch(line)?.group(1) case final t?
            when screensImport.hasMatch(t))
          t,
    ];

    test('E2 正向對照：lib/app 守衛的違規樣本（screens import）被攔下', () {
      const sample =
          "import 'package:graph_project_docs_manager/screens/project_switcher/x.dart';\n"
          "import '../screens/home.dart';\n"
          "import 'package:graph_project_docs_manager/workspace/workspace_types.dart';\n";
      expect(screensImportsIn(sample), [
        'package:graph_project_docs_manager/screens/project_switcher/x.dart',
        '../screens/home.dart',
      ]);
    });

    test('scan_round.dart 不 import screens（lib/app 不得反向依賴 screens）', () {
      final source = File('lib/app/scan_round.dart').readAsStringSync();
      expect(screensImportsIn(source), isEmpty);
    });

    for (final dir in ['corpus', 'graph', 'diagnostics', 'schema', 'layout']) {
      test('lib/$dir（含子目錄）不 import app／screens', () {
        expect(dartFilesUnder(Directory('lib/$dir')), isNotEmpty);
        expect(violationsUnder(Directory('lib/$dir')), isEmpty);
      });
    }
  });
}
