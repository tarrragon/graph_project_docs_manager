/// 外圈 B11：外部修改 docs/ 後自動重新解析、破洞報告更新
/// （0.6.0-W1-080；SPEC-006 FR-11）。
///
/// 以輪詢版 [PollingWatchSource] 取代原生監看，不依賴 FSEvents。
/// 同 `gap_report_declaration_line.dart`：由 `app_test.dart` 註冊。
/// 時間判定以 pump 輪詢加逾時等待條件，不用固定 sleep 猜時間。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watcher_provider.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_item_ids.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/services/polling_watch_source.dart';

import '../test/helpers/spec001/corpus_snapshot.dart';
import 'domain_view_v050.dart' show OpenWorkspace, settleGuarded;

/// 等待型案例的逾時：涵蓋輪詢、去抖與掃描，高於一般案例的 20 秒。
const Timeout _watchTestTimeout = Timeout(Duration(seconds: 90));

void _itWatch(String description, WidgetTesterCallback callback) =>
    testWidgets(description, callback, timeout: _watchTestTimeout);

const _snapshot = 'flutter_balance';
const _pollInterval = Duration(milliseconds: 100);
const _step = Duration(milliseconds: 200);
const _waitLimit = Duration(seconds: 30);
// 負向觀察窗：需涵蓋輪詢間隔加去抖靜默窗（500ms）加掃描時間，並留餘裕。
const _quietWindow = Duration(seconds: 4);
// 須落在載體路徑（docs/usecases/）才會成為 parseFailure（FR-06 載體命中）。
const _brokenPath = 'docs/usecases/UC-99-b11-broken.md';
const _brokenContent = '---\nid: [unclosed\n---\n內文\n';

void registerWatchPollingRescanTests(OpenWorkspace open) {
  group('B11 輪詢版監看端對端', () {
    _itWatch('B11-A1 外部新增壞 frontmatter 檔：自動重掃並出現 parseFailure', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_snapshot);
      final scans = _ScanCounter();
      await _openWatched(open, tester, workspace, scans);
      final before = scans.count;
      expect(_parseFailurePaths(tester), isNot(contains(_brokenPath)));

      File('${workspace.path}/$_brokenPath')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(_brokenContent);

      await _waitUntil(
        tester,
        () => _parseFailurePaths(tester).contains(_brokenPath),
        '破洞報告未出現 $_brokenPath 的 parseFailure', // i18n-exempt: 測試診斷訊息
      );
      expect(scans.count, greaterThan(before), reason: '不經使用者操作即發生新一輪掃描');
      await workspace.delete(recursive: true);
    });

    _itWatch('B11-A2 docs/ 外的檔案與 *.swp 不觸發掃描（E1/E2 對照）', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_snapshot);
      final scans = _ScanCounter();
      await _openWatched(open, tester, workspace, scans);
      final before = scans.count;

      File('${workspace.path}/outside-docs.md')
          .writeAsStringSync(_brokenContent);
      File('${workspace.path}/docs/note.md.swp').writeAsStringSync('x');
      await _pumpFor(tester, _quietWindow);

      expect(scans.count, before, reason: '無關變動不應觸發掃描');
      // 對照：同一 fixture 下相關變動確實觸發（證明監看在運作，非恆真）。
      File('${workspace.path}/$_brokenPath').writeAsStringSync(_brokenContent);
      await _waitUntil(
        tester,
        () => scans.count > before,
        '相關變動未觸發掃描', // i18n-exempt: 測試診斷訊息
      );
      await workspace.delete(recursive: true);
    });
  });
}

class _ScanCounter {
  int count = 0;
}

Future<void> _openWatched(
  OpenWorkspace open,
  WidgetTester tester,
  Directory workspace,
  _ScanCounter scans,
) async {
  await open(
    tester,
    workspace,
    overrides: [
      watchSourceProvider.overrideWithValue(
        PollingWatchSource(pollingInterval: _pollInterval),
      ),
      scanCorpusFnProvider.overrideWithValue(({
        required fileSystem,
        required table,
        required builtinTable,
      }) {
        scans.count++;
        return scanCorpus(
          fileSystem: fileSystem,
          table: table,
          builtinTable: builtinTable,
        );
      }),
    ],
  );
  await tester.tap(find.byKey(const Key('nav-item-gaps')));
  await settleGuarded(tester, 'pumpAndSettle');
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += _step) {
    await tester.pump(_step);
  }
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  for (var t = Duration.zero; t < _waitLimit; t += _step) {
    if (condition()) return;
    await tester.pump(_step);
  }
  if (!condition()) fail(reason);
}

List<String> _parseFailurePaths(WidgetTester tester) {
  final state = ProviderScope.containerOf(
    tester.element(find.byType(DocsManagerApp)),
  ).read(gapReportProvider);
  final categories = switch (state) {
    GapReportFound(:final categories) => categories,
    GapReportUndeterminable(:final categories) => categories,
    _ => const <GapReportCategory>[],
  };
  return [
    for (final c in categories)
      if (c.id == gapCategoryIdParseFailure) ...c.items.map((i) => i.filePath),
  ];
}
