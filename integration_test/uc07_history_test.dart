/// UC-07 外圈驗收（測試設計 SPEC-001-history-screen-test-design §2，AT-1～AT-10）。
///
/// pump 真實 app root，只替換 git 程序（fake 程序執行器回應合成 git log）。
/// 與測試設計的偏離（記於 0.7.0-W1-012.12 Solution）：
/// 1. `historyScanInputsProvider` 以含四個邊型的測試輸入覆寫，使合成 log 的
///    事件抽取不依賴 fixture 工作區的型別表；
/// 2. 事件在同 commit 內依邊型鍵名排序，列序以實際排序為準；
/// 3. AT-7 有先前結果時畫面維持結果（無取消鍵），改由 notifier 取消。
///
/// 單獨執行：`fvm flutter test integration_test/uc07_history_test.dart -d macos`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../test/helpers/history/fake_process_runner.dart';
import '../test/helpers/history/history_screen_fixtures.dart';
import '../test/helpers/history/synthetic_git_log.dart';
import '../test/helpers/pump_harness.dart';
import 'domain_view_v050.dart' show ensureItBinding, kItTestTimeout;

final _l10n = AppLocalizationsZh();

Finder _key(String k) => find.byKey(Key(k));

String _hash(int n) => n.toString().padLeft(40, '0');

int _secs(int month, int day) =>
    DateTime.utc(2026, month, day).millisecondsSinceEpoch ~/ 1000;

const _ticket11 = '0.7.0-W1-012.11';
const _ticket9 = '0.7.0-W1-012.9';
const _ticket4 = '0.7.0-W1-012.4';
const _ticket3 = '0.7.0-W1-012.3';

EdgeTypeEntry _edge(String name, String field) => EdgeTypeEntry(
  name: name,
  edgeClass: 'depends',
  forwardField: field,
  reverseField: null,
  forwardCardinality: EdgeCardinality.many,
  layer: 'established',
  direction: EdgeDirection.directed,
  directionSource: DirectionSource.projectTable,
);

HistoryScanInputs _atInputs() => HistoryScanInputs(
  schemaReadiness: HistorySchemaReadiness.ready,
  tableIdentity: 'at-table',
  createBuilder: () => EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: [
        _edge('blockedBy', 'blockedBy'),
        _edge('uc_ticket_refs', 'ticket_refs'),
        _edge('domain_dependency', 'depends_on_domains'),
      ],
      closedByIdPatterns: const [],
    ),
    ticketIdPattern: RegExp(r'^\d+\.\d+\.\d+-W\d+-\d+(\.\d+)*$'),
  ),
);

List<String> _fm(Map<String, Object?> fields) => frontmatterLines(fields);

/// 五個主線 commit（舊到新 h1..h5），tag v0.6.0 在 h3。
/// 預設期間（h3 之後）事件：h5 兩筆、h4 的 domain_dependency；期間外：h2 一筆；
/// h4 另有 ticket 建檔事件。[onlyOld] 時 h4、h5 不產生事件。
SyntheticLogBuilder _log({int? rootTime, bool onlyOld = false}) {
  final b = SyntheticLogBuilder()
    ..commit(
      _hash(1),
      time: rootTime ?? _secs(9, 1),
      files: [
        LogFileEntry.added('docs/t11.md', _fm({'id': _ticket11})),
        LogFileEntry.added('docs/uc07.md', _fm({'id': 'UC-07'})),
      ],
    )
    ..commit(
      _hash(2),
      parents: [_hash(1)],
      time: _secs(10, 1),
      files: [
        LogFileEntry.modified(
          'docs/t11.md',
          before: _fm({'id': _ticket11}),
          after: _fm({
            'id': _ticket11,
            'blockedBy': [_ticket9],
          }),
        ),
      ],
    )
    ..commit(_hash(3), parents: [_hash(2)], time: _secs(10, 20));
  if (onlyOld) {
    b
      ..commit(_hash(4), parents: [_hash(3)], time: _secs(11, 3))
      ..commit(_hash(5), parents: [_hash(4)], time: _secs(11, 5));
    return b;
  }
  b
    ..commit(
      _hash(4),
      parents: [_hash(3)],
      time: _secs(11, 3),
      files: [
        LogFileEntry.added(
          'docs/spec/history/domain-map.md',
          _fm({
            'id': 'history',
            'depends_on_domains': ['schema'],
          }),
        ),
        LogFileEntry.added(
          'docs/t4.md',
          _fm({
            'id': _ticket4,
            'blockedBy': [_ticket3],
          }),
        ),
      ],
    )
    ..commit(
      _hash(5),
      parents: [_hash(4)],
      time: _secs(11, 5),
      files: [
        LogFileEntry.modified(
          'docs/uc07.md',
          before: _fm({'id': 'UC-07'}),
          after: _fm({
            'id': 'UC-07',
            'ticket_refs': [_ticket11],
          }),
        ),
        LogFileEntry.modified(
          'docs/t11.md',
          before: _fm({
            'id': _ticket11,
            'blockedBy': [_ticket9],
          }),
          after: _fm({'id': _ticket11}),
        ),
      ],
    );
  return b;
}

FakeProcessRunner _runner({FakeScanScript Function()? script, int? rootTime}) {
  final log = _log(rootTime: rootTime);
  return FakeProcessRunner(
      scanFactory: script ?? () => FakeScanScript.complete(log.toChunks(4096)),
    )
    ..head = okResponse('${_hash(5)}\n')
    ..mainline = okResponse(
      '${[for (var i = 5; i >= 1; i--) _hash(i)].join('\n')}\n',
    )
    ..tags = okResponse('v0.6.0\u0000${_hash(3)}\u0000\n');
}

Future<ProviderContainer> _pumpAt(
  WidgetTester tester,
  FakeProcessRunner runner, {
  bool settle = true,
}) async {
  await tester.pumpWidget(const SizedBox());
  await pumpApp(
    tester,
    settle: settle,
    overrides: [
      ...historyGateOverrides(),
      historyProcessRunnerProvider.overrideWithValue(runner),
      historyScanInputsProvider.overrideWithInitial((ref) => _atInputs()),
      historyClockProvider.overrideWithValue(historyTestClock),
      historyGraphNodes(['UC-07', _ticket11, _ticket9, _ticket4, _ticket3]),
    ],
  );
  return historyContainer(tester);
}

Future<void> _enterHistory(WidgetTester tester) async {
  await tester.tap(_key('nav-item-history'));
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

int _rows(WidgetTester tester) =>
    tester.widgetList(find.byType(AppTableRow)).length - 1;

int _versionChecks(FakeProcessRunner r) =>
    r.callKinds.where((k) => k == 'version').length;

String _summary(WidgetTester tester) =>
    tester.widget<AppText>(_key('text-history-period-summary')).text;

void main() {
  ensureItBinding();

  void at(String name, WidgetTesterCallback body) =>
      testWidgets(name, body, timeout: kItTestTimeout);

  at('AT-1 主線：讀取、預設期間、開啟節點並返回', (tester) async {
    final script = FakeScanScript.manual();
    final runner = _runner(script: () => script);
    final c = await _pumpAt(tester, runner);
    await tester.tap(_key('nav-item-history'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    expect(find.text(_l10n.historyLoadingProcessedCount(0)), findsOneWidget);
    for (final chunk in _log().toChunks(4096)) {
      script.emit(chunk);
    }
    await script.finish();
    await tester.pumpAndSettle();
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_summary(tester), 'v0.6.0 之後 · 3 筆事件');
    expect(_rows(tester), 3);
    final declarer = tester
        .widget<RelationItem>(
          find.ancestor(
            of: _key('action-history-open-0-declarer'),
            matching: find.byType(RelationItem),
          ),
        )
        .id;
    await _tapAndSettle(tester, 'action-history-open-0-declarer');
    expect(c.read(selectedDestinationProvider), AppDestination.nodeDetail);
    await _tapAndSettle(tester, 'action-nodeDetail-back');
    expect(c.read(selectedDestinationProvider), AppDestination.history);
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_summary(tester), 'v0.6.0 之後 · 3 筆事件');
    expect(declarer, _ticket11);
  });

  at('AT-2 再次進入沿用快取：不重新掃描', (tester) async {
    final runner = _runner();
    await _pumpAt(tester, runner);
    await _enterHistory(tester);
    await _tapAndSettle(tester, 'nav-item-domain');
    await tester.tap(_key('nav-item-history'));
    await tester.pump();
    expect(_key('state-history-loading'), findsNothing);
    await tester.pumpAndSettle();
    expect(runner.scanStartCount, 1);
    expect(_versionChecks(runner), 2);
  });

  at('AT-3 切換期間：事件數更新且不重新掃描', (tester) async {
    final runner = _runner();
    await _pumpAt(tester, runner);
    await _enterHistory(tester);
    await _tapAndSettle(tester, 'option-history-period-all');
    expect(_rows(tester), 4);
    await _tapAndSettle(tester, 'option-history-period-recent30');
    expect(_rows(tester), 3);
    expect(runner.scanStartCount, 1);
  });

  at('AT-4 包含 ticket 建檔：事件數加一且不重新掃描', (tester) async {
    final runner = _runner();
    await _pumpAt(tester, runner);
    await _enterHistory(tester);
    expect(find.text(_ticket3), findsNothing);
    await _tapAndSettle(tester, 'action-history-include-ticket-created');
    expect(_rows(tester), 4);
    expect(find.text(_ticket3), findsOneWidget);
    expect(runner.scanStartCount, 1);
  });

  at('AT-5 期間內無事件：顯示全部歷史可前進', (tester) async {
    final log = _log(onlyOld: true);
    final runner = _runner(
      script: () => FakeScanScript.complete(log.toChunks(4096)),
    );
    await _pumpAt(tester, runner);
    await _enterHistory(tester);
    expect(_key('state-history-empty'), findsOneWidget);
    expect(find.text(_l10n.historyEmptyMessage), findsOneWidget);
    await _tapAndSettle(tester, 'action-history-show-all');
    expect(
      tester
          .widget<Semantics>(_key('option-history-period-all'))
          .properties
          .selected,
      isTrue,
    );
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_rows(tester), 1);
  });

  at('AT-6 取消（無結果）後重新讀取，計數自 0 起算', (tester) async {
    final scripts = <FakeScanScript>[];
    final runner = _runner(
      script: () {
        final s = FakeScanScript.manual();
        scripts.add(s);
        return s;
      },
    );
    await _pumpAt(tester, runner);
    await tester.tap(_key('nav-item-history'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(_key('action-history-cancel'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(runner.killCount, 1);
    expect(_key('state-history-cancelled'), findsOneWidget);
    expect(find.byType(AppTableRow), findsNothing);
    await tester.tap(_key('action-history-reload'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    expect(find.text(_l10n.historyLoadingProcessedCount(0)), findsOneWidget);
    for (final chunk in _log().toChunks(4096)) {
      scripts.last.emit(chunk);
    }
    await scripts.last.finish();
    await tester.pumpAndSettle();
    expect(_key('state-history-normal'), findsOneWidget);
  });

  at('AT-7 有結果時 HEAD 改變的重掃被取消：結果同先前', (tester) async {
    final runner = _runner();
    final c = await _pumpAt(tester, runner);
    await _enterHistory(tester);
    final first = (c.read(historyProvider) as HistoryLoaded).snapshot;
    final script = FakeScanScript.manual();
    runner
      ..head = okResponse('${_hash(6)}\n')
      ..scanFactory = () => script;
    await _tapAndSettle(tester, 'nav-item-domain');
    await tester.tap(_key('nav-item-history'));
    await tester.pump(const Duration(milliseconds: 300));
    c.read(historyProvider.notifier).cancel();
    await tester.pumpAndSettle();
    expect(_key('state-history-normal'), findsOneWidget);
    expect((c.read(historyProvider) as HistoryLoaded).snapshot, same(first));
    expect(_rows(tester), 3);
    await script.finish();
  });

  group('AT-8 無法讀取的三種呈現', () {
    at('非 git 專案', (tester) async {
      final runner = _runner()..workTree = okResponse('false\n');
      await _pumpAt(tester, runner);
      await _enterHistory(tester);
      expect(_key('state-history-not-git'), findsOneWidget);
      final before = _versionChecks(runner);
      await _tapAndSettle(tester, 'action-history-recheck');
      expect(_versionChecks(runner), before + 1);
    });

    at('找不到 git', (tester) async {
      final runner = _runner()..version = const GitLaunchException('no git');
      await _pumpAt(tester, runner);
      await _enterHistory(tester);
      expect(_key('state-history-git-missing'), findsOneWidget);
      expect(_key('action-history-recheck'), findsOneWidget);
    });

    at('讀取失敗（stderr 摘要）', (tester) async {
      final runner = _runner(
        script: () => FakeScanScript.exit(1, stderr: 'fatal: bad object h3'),
      );
      await _pumpAt(tester, runner);
      await _enterHistory(tester);
      expect(_key('state-history-load-failed'), findsOneWidget);
      expect(find.textContaining('fatal: bad object h3'), findsOneWidget);
      expect(_key('action-history-retry'), findsOneWidget);
    });
  });

  at('AT-9 淺層 clone：標示含邊界日期，事件照常列出', (tester) async {
    final runner = _runner(rootTime: _secs(10, 1))
      ..workTree = okResponse('true\ntrue\n');
    await _pumpAt(tester, runner);
    await _enterHistory(tester);
    expect(_key('state-history-normal'), findsOneWidget);
    expect(_key('badge-history-shallow-clone'), findsOneWidget);
    expect(find.textContaining('2026-10-01'), findsOneWidget);
    expect(_rows(tester), greaterThan(0));
  });

  at('AT-10 讀取中導覽離開不取消，回來即見結果', (tester) async {
    final script = FakeScanScript.manual();
    final runner = _runner(script: () => script);
    await _pumpAt(tester, runner);
    await tester.tap(_key('nav-item-history'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_key('state-history-loading'), findsOneWidget);
    await tester.tap(_key('nav-item-domain'));
    await tester.pump(const Duration(milliseconds: 300));
    for (final chunk in _log().toChunks(4096)) {
      script.emit(chunk);
    }
    await script.finish();
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, 'nav-item-history');
    expect(runner.killCount, 0);
    expect(_key('state-history-normal'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
