// app root 對 historyScanInputsProvider 的接線（測試設計 §3.9，WR-1～WR-5）。
//
// 不 override historyScanInputsProvider：預設實作須取自實際 Schema 狀態。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';

import '../../helpers/history/fake_process_runner.dart';
import '../../helpers/history/history_screen_fixtures.dart';
import '../../helpers/history/synthetic_git_log.dart';
import '../../helpers/pump_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

ScanRoundResult? _builtinRound;

/// 以內建 tracking_schema 解析出型別表與邊型決議的完成輪次（含 Ticket id_pattern）。
ScanRoundResult _realRound() {
  final json = jsonDecode(
    File(builtinTrackingSchemaAssetPath).readAsStringSync(),
  ) as Map<String, dynamic>;
  return fakeRound(
    typeTable: resolveSchemaSource(
      projectSchemaJson: json,
      builtinSchemaJson: json,
    ).typeTable,
    edgeResolution: resolveEdgeTypes(
      projectSchemaJson: json,
      builtinSchemaJson: json,
    ),
  );
}

Override _roundOverride() => scanRoundProvider.overrideWith(
  () => FakeScanRound(produce: () => _builtinRound),
);

const _parentPath = 'docs/work-logs/v0.1.0/tickets/0.1.0-W1-001.md';
const _childPath = 'docs/work-logs/v0.1.0/tickets/0.1.0-W1-002.md';

/// 新增子 ticket（含 parent_id）並同批在父票補 children 的合成 git log。
SyntheticLogBuilder _ticketCreationLog() {
  const parentBefore = {'id': '0.1.0-W1-001'};
  return SyntheticLogBuilder()
    ..commit(
      'a',
      files: [LogFileEntry.added(_parentPath, frontmatterLines(parentBefore))],
    )
    ..commit(
      'b',
      parents: ['a'],
      files: [
        LogFileEntry.modified(
          _parentPath,
          before: frontmatterLines(parentBefore),
          after: frontmatterLines({
            'id': '0.1.0-W1-001',
            'children': ['0.1.0-W1-002'],
          }),
        ),
        LogFileEntry.added(
          _childPath,
          frontmatterLines({'id': '0.1.0-W1-002', 'parent_id': '0.1.0-W1-001'}),
        ),
      ],
    );
}

/// 不覆寫 historyScanInputsProvider 的最小容器：只替身 git port 與輪次。
(ProviderContainer, FakeScanRound, FakeProcessRunner) _container({
  ScanRoundResult? initial,
}) {
  final runner = FakeProcessRunner(
    scanFactory: () =>
        FakeScanScript.complete([_ticketCreationLog().toBytes()]),
  );
  late final FakeScanRound fake;
  fake = FakeScanRound(produce: _realRound, initial: initial);
  final container = ProviderContainer(
    overrides: [
      historyScanInputsWiredProvider.overrideWithInitial((_) => true),
      currentWorkspaceStateProvider.overrideWithInitial(
        (_) => const WorkspaceReady('/ws'),
      ),
      domainViewStateProvider.overrideWithInitial(
        (_) => const DomainReady(mode: DomainMode.matrix),
      ),
      scanRoundProvider.overrideWith(() => fake),
      historyProcessRunnerProvider.overrideWithValue(runner),
    ],
  );
  addTearDown(container.dispose);
  // 與 app root 一致：lastCompletedRoundProvider 由畫面層常駐（此處保活）。
  container.listen(lastCompletedRoundProvider, (_, _) {});
  container.listen(historyProvider, (_, _) {});
  return (container, fake, runner);
}

HistoryScanSnapshot _loaded(ProviderContainer c) {
  final state = c.read(historyProvider);
  expect(state, isA<HistoryLoaded>());
  return (state as HistoryLoaded).snapshot;
}

void _expectTicketCreationFlagged(HistoryScanSnapshot snap) {
  final created = snap.events.where((e) => e.isTicketCreation);
  expect(created, isNotEmpty, reason: '新建 ticket 的事件須帶建檔旗標');
  final query = snap.query(clock: () => DateTime.utc(2026, 11, 9));
  const all = PeriodChoice.allHistory;
  final excluded = query.run(period: all);
  final included = query.run(period: all, includeTicketCreation: true);
  expect(excluded.any((v) => v.event.isTicketCreation), isFalse);
  expect(included.length, greaterThan(excluded.length));
}

Future<void> _pumpWired(
  WidgetTester tester,
  FakeProcessRunner runner, {
  bool schemaJson = true,
}) => pumpApp(
  tester,
  overrides: [
    ...historyGateOverrides(schemaJson: schemaJson),
    historyProcessRunnerProvider.overrideWithValue(runner),
  ],
);

void main() {
  testWidgets('WR-1 真實 app root：進入第七畫面不拋 UnimplementedError', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner);
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_key('state-history-project-unready'), findsNothing);
    expect(runner.callKinds, contains('version'));
    expect(
      historyContainer(tester).read(historyProvider),
      isA<HistoryLoaded>(),
    );
  });

  testWidgets('WR-2 內建型別表降級：降級徽章可見（Schema 就緒度取自實際狀態）', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner, schemaJson: false);
    await tester.tap(_key('action-domain-degraded-view'));
    await tester.pumpAndSettle();
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_key('badge-history-degraded-schema'), findsOneWidget);
    expect(runner.callKinds, contains('version'));
  });

  testWidgets('WR-3 無可消費的型別表：專案未就緒，git 0 次', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner, schemaJson: false);
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(_key('state-history-project-unready'), findsOneWidget);
    expect(runner.calls, isEmpty);
  });

  test('WR-4（對照）不含 history override 的最小容器讀取必接線 provider 拋錯', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(historyScanInputsProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  testWidgets('WR-6 真實接線：合成 git log 的 blockedBy 增補產生事件（E2 正向對照）', (
    tester,
  ) async {
    const path = 'docs/work-logs/v0.1.0/tickets/0.1.0-W1-001.md';
    const before = {'id': '0.1.0-W1-001'};
    final log = SyntheticLogBuilder()
      ..commit('a', files: [LogFileEntry.added(path, frontmatterLines(before))])
      ..commit(
        'b',
        parents: ['a'],
        files: [
          LogFileEntry.modified(
            path,
            before: frontmatterLines(before),
            after: frontmatterLines({
              'id': '0.1.0-W1-001',
              'blockedBy': ['0.1.0-W1-002'],
            }),
          ),
        ],
      );
    final runner = FakeProcessRunner(
      scanFactory: () => FakeScanScript.complete([log.toBytes()]),
    );
    // 輪次替身須帶型別表與邊型決議（History 取自完成的輪次，不再自備 fallback）。
    await tester.runAsync(() async => _builtinRound = _realRound());
    await pumpApp(
      tester,
      overrides: [
        ...historyGateOverrides(),
        _roundOverride(),
        historyProcessRunnerProvider.overrideWithValue(runner),
      ],
    );
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    final state = historyContainer(tester).read(historyProvider);
    expect(state, isA<HistoryLoaded>());
    final events = (state as HistoryLoaded).snapshot.events;
    expect(events, isNotEmpty);
  });

  test('WR-7 輪次進行中進入：等輪次完成後才掃描，ticket 建檔事件有旗標', () async {
    final (c, round, runner) = _container();
    final gate = Completer<void>();
    round.hold = gate.future;
    final entering = c.read(historyProvider.notifier).enter();
    await pumpEventQueue();
    expect(runner.calls, isEmpty, reason: '輪次未完成前不啟動任何 git');
    expect(c.read(historyProvider), isA<HistoryLoading>());
    gate.complete();
    await entering;
    expect(runner.scanStartCount, 1);
    _expectTicketCreationFlagged(_loaded(c));
  });

  test('WR-8 輪次完成後進入：ticket 建檔事件有旗標', () async {
    final (c, round, runner) = _container();
    await round.ensureRound();
    await c.read(historyProvider.notifier).enter();
    expect(runner.scanStartCount, 1);
    _expectTicketCreationFlagged(_loaded(c));
  });

  test('WR-9 已有完成輪次、重掃進行中進入：不等待，用上一輪型別表', () async {
    final (c, round, runner) = _container(initial: _realRound());
    final gate = Completer<void>();
    round.hold = gate.future;
    unawaited(round.rescan());
    await pumpEventQueue();
    expect(c.read(scanRoundProvider), isA<ScanRoundRunning>());
    await c.read(historyProvider.notifier).enter();
    expect(runner.scanStartCount, 1);
    _expectTicketCreationFlagged(_loaded(c));
    gate.complete();
  });

  test('WR-10 等待中的輪次被重掃取代：接續等新輪次後掃描', () async {
    final (c, round, runner) = _container();
    final gate = Completer<void>();
    round.hold = gate.future;
    final entering = c.read(historyProvider.notifier).enter();
    await pumpEventQueue();
    unawaited(round.rescan());
    await pumpEventQueue();
    expect(runner.calls, isEmpty);
    gate.complete();
    await entering;
    expect(runner.scanStartCount, 1);
    _expectTicketCreationFlagged(_loaded(c));
  });

  test('WR-11 等待中取消：結果為已取消，輪次完成後不啟動掃描', () async {
    final (c, round, runner) = _container();
    final gate = Completer<void>();
    round.hold = gate.future;
    final entering = c.read(historyProvider.notifier).enter();
    await pumpEventQueue();
    c.read(historyProvider.notifier).cancel();
    expect(c.read(historyProvider), isA<HistoryCancelled>());
    gate.complete();
    await entering;
    await pumpEventQueue();
    expect(c.read(historyProvider), isA<HistoryCancelled>());
    expect(runner.calls, isEmpty);
  });

  test('WR-12 型別表識別：尚無完成輪次與空邊型表的識別不同', () async {
    final (c, round, _) = _container();
    final none = c.read(historyScanInputsProvider).tableIdentity;
    await round.ensureRound();
    final real = c.read(historyScanInputsProvider).tableIdentity;
    expect(real, isNot(none));
    round.completeExternally(fakeRound());
    await pumpEventQueue();
    final empty = c.read(historyScanInputsProvider).tableIdentity;
    expect(empty, isNot(none), reason: '空邊型表不得與尚無輪次同識別');
  });

  test('WR-13 型別表換了：同 HEAD 再次進入重新掃描（FR-09 規則 2、3）', () async {
    final (c, round, runner) = _container(initial: _realRound());
    await c.read(historyProvider.notifier).enter();
    expect(runner.scanStartCount, 1);
    round.completeExternally(fakeRound());
    await pumpEventQueue();
    await c.read(historyProvider.notifier).enter();
    expect(runner.scanStartCount, 2);
  });

  test('WR-14 輪次不可用（失敗且無後續輪次）：結果為輪次不可用，git 0 次', () async {
    final (c, round, runner) = _container();
    round.produce = () => null;
    await c.read(historyProvider.notifier).enter();
    expect(c.read(historyProvider), isA<HistoryScanRoundUnavailable>());
    expect(runner.calls, isEmpty);
  });

  testWidgets('WR-5 導覽列七項，變更記錄為第七項', (tester) async {
    await _pumpWired(tester, FakeProcessRunner());
    for (final d in AppDestination.values) {
      expect(_key('nav-item-${d.name}'), findsOneWidget);
    }
    expect(AppDestination.values.last, AppDestination.history);
    expect(AppDestination.values, hasLength(7));
    final ys = [
      for (final d in AppDestination.values)
        tester.getTopLeft(_key('nav-item-${d.name}')).dy,
    ];
    expect(ys, [...ys]..sort());
    expect(ys.last, greaterThan(ys[ys.length - 2]));
  });
}
