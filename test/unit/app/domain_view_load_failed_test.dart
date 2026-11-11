// 需求：0.5.0-W1-114.14.2 F1～F6；SPEC-001 v1.49 §1「載入失敗」、
// SPEC-004 v1.86 §4.0.6／4.23。
// 「E1」「E2」標註對照輸入／正向對照輸入（test-assertion-design-rules）。
// F7 回歸（schema／analyze／全量）由命令列驗證。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/domain_view_loader.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec_first_marker.dart';

ProviderContainer _container({
  required ScanRoundResult? Function() produce,
  List<(String, int)>? logs,
}) {
  late final FakeScanRound fake;
  final container = ProviderContainer(
    overrides: [
      scanRoundProvider.overrideWith(() {
        fake = FakeScanRound(produce: produce);
        return fake;
      }),
      domainViewLogSinkProvider.overrideWithValue(
        (message, {level = 500}) => logs?.add((message, level)),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(scanRoundProvider);
  return container;
}

ProviderContainer _slowThrowingContainer() {
  final container = ProviderContainer(
    overrides: [
      scanRoundProvider.overrideWith(
        () => FakeScanRound(
          produce: _throwing,
          latency: const Duration(milliseconds: 30),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(scanRoundProvider);
  return container;
}

void _expectArbMatches(
  Map<String, dynamic> zh,
  Map<String, dynamic> en,
  Map<String, (String, String)> expected,
) {
  expected.forEach((key, value) {
    expect(zh[key], value.$1, reason: key);
    expect(en[key], value.$2, reason: key);
  });
}

/// 帶「規格先行」標記的列跳過比對並回傳 true；ARB 已與該列一致則判紅
/// （1.1.0-W1-108）。無標記回傳 false。
bool _skipSpecFirstRow(
  String key,
  String row,
  Map<String, dynamic> zh,
  Map<String, dynamic> en,
) {
  final ticket = specFirstTicketOf(row);
  if (ticket == null) return false;
  final cells = splitSpecRow(row);
  expect(
    arbAlreadyMatchesSpecRow(key, cells[2], cells[3], zh, en),
    isFalse,
    reason: staleSpecFirstMessage(key, ticket),
  );
  return true;
}

ScanRoundResult _throwing() => throw StateError('scan boom');

void main() {
  group('F1 例外落點', () {
    test('一般載入拋例外 → DomainLoadFailed，load 不外拋', () async {
      final c = _container(produce: _throwing);
      await c.read(domainViewLoaderProvider.notifier).load();
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
    });

    test('E1 對照：正常完成為 DomainReady，不是 DomainLoadFailed', () async {
      final c = _container(produce: () => fakeRound());
      await c.read(domainViewLoaderProvider.notifier).load();
      expect(c.read(domainViewStateProvider), isA<DomainReady>());
      expect(c.read(domainViewStateProvider), isNot(isA<DomainLoadFailed>()));
    });

    test('降級入口拋例外 → DomainLoadFailed，降級旗標保留', () async {
      final c = _container(produce: _throwing);
      await c
          .read(domainViewLoaderProvider.notifier)
          .enterDegradedView(
            builtinVersion: '2.40.3',
            projectVersion: '2.22.1',
          );
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
      expect(c.read(degradedSchemaProvider), isTrue);
    });
  });

  group('世代守衛：晚到例外', () {
    test('載入中被 gate 阻擋作廢，舊輪次晚到例外不覆寫阻擋態', () async {
      final c = _slowThrowingContainer();
      final loader = c.read(domainViewLoaderProvider.notifier);
      final pending = loader.load();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      loader.applyGateBlock(const DomainNotFramework());
      await pending;
      expect(c.read(domainViewStateProvider), isA<DomainNotFramework>());
    });

    test('E1 對照：未被作廢的同一載入，晚到例外落 DomainLoadFailed', () async {
      final c = _slowThrowingContainer();
      await c.read(domainViewLoaderProvider.notifier).load();
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
    });
  });

  group('F2 無未處理錯誤', () {
    test('E2 降級入口以 unawaited 呼叫、輪次拋例外：zone 無未處理錯誤', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final c = _container(produce: _throwing);
        unawaited(
          c
              .read(domainViewLoaderProvider.notifier)
              .enterDegradedView(
                builtinVersion: '2.40.3',
                projectVersion: '2.22.1',
              ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
      }, (e, _) => uncaught.add(e));
      expect(uncaught, isEmpty);
    });

    test('E2 正向對照：未處理的 unawaited 例外會被 zone 收集（收集器有效）', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        unawaited(Future<void>.error(StateError('x')));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }, (e, _) => uncaught.add(e));
      expect(uncaught, hasLength(1));
    });

    test('沿用 level 900 錯誤日誌（開發者 log 以 developer.log，不經 sink）', () async {
      final logs = <(String, int)>[];
      final c = _container(produce: _throwing, logs: logs);
      await c.read(domainViewLoaderProvider.notifier).load();
      // 例外路徑不觸發不變式 sink；level 900 由 developer.log 輸出。
      expect(logs, isEmpty);
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
    });
  });

  group('F3 重新載入', () {
    testWidgets('按 action-domain-reload → 回載入中；成功後為 Ready', (tester) async {
      var shouldFail = true;
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          scanRoundProvider.overrideWith(
            () => FakeScanRound(
              produce: () => shouldFail ? _throwing() : fakeRound(),
            ),
          ),
          domainViewStateProvider.overrideWithInitial(
            (ref) => const DomainLoadFailed(),
          ),
        ],
      );
      shouldFail = false;
      final seen = <Type>[];
      container.listen<DomainViewState>(
        domainViewStateProvider,
        (_, next) => seen.add(next.runtimeType),
      );

      await tester.tap(find.byKey(const Key('action-domain-reload')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(seen.first, DomainLoading);
      expect(container.read(domainViewStateProvider), isA<DomainReady>());
    });

    test('降級檢視失敗後重試仍為降級；推定版本沿用', () async {
      var shouldFail = true;
      final c = _container(
        produce: () => shouldFail ? _throwing() : fakeRound(isDegraded: true),
      );
      final loader = c.read(domainViewLoaderProvider.notifier);
      c.read(degradedSchemaProvider.notifier).state = true;
      await loader.load(inferredVersion: '2.40.3');
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());

      shouldFail = false;
      await loader.reload();

      final ready = c.read(domainViewStateProvider) as DomainReady;
      expect(ready.isDegraded, isTrue);
      expect(ready.inferredVersion, '2.40.3');
    });

    test('E1 對照：重試仍失敗則維持 DomainLoadFailed', () async {
      final c = _container(produce: _throwing);
      final loader = c.read(domainViewLoaderProvider.notifier);
      await loader.load();
      await loader.reload();
      expect(c.read(domainViewStateProvider), isA<DomainLoadFailed>());
    });
  });

  group('F4 切換專案與渲染', () {
    testWidgets('載入失敗渲染 BlockedState、reload、switch-project 與訊息', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWithInitial(
            (ref) => const DomainLoadFailed(),
          ),
        ],
      );

      expect(AnchorFinder.state(Screen.domain, 'load-failed'), findsOneWidget);
      expect(find.byType(BlockedState), findsOneWidget);
      expect(find.byKey(const Key('action-domain-reload')), findsOneWidget);
      await tester.tap(find.byKey(const Key('action-domain-switch-project')));
      await tester.pump();
      expect(container.read(switcherOpenProvider), isTrue);
    });

    testWidgets('E1 對照：既有三個阻擋狀態皆渲染 switch-project，且不渲染 reload', (tester) async {
      for (final state in const <DomainViewState>[
        DomainNotFramework(),
        DomainSchemaUnconsumable(version: '0.0.3'),
        DomainSchemaIncompatible(appVersion: '1', projectVersion: '2'),
      ]) {
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            domainViewStateProvider.overrideWithInitial((ref) => state),
          ],
        );
        expect(
          find.byKey(const Key('action-domain-switch-project')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('action-domain-reload')), findsNothing);
      }
    });
  });

  group('F6 ARB 與 SPEC-004 v1.86 §4.0.6 逐字一致', () {
    final expected = {
      'domainLoadFailedMessage': (
        '掃描此專案時發生非預期錯誤，無法載入圖譜',
        'An unexpected error occurred while scanning this project, '
            'so the graph could not be loaded.',
      ),
      'reloadAction': ('重新載入', 'Reload'),
      'projectUnreadyReasonLoadFailed': ('圖譜載入失敗', 'Graph failed to load'),
      'ucSelectorTitle': ('選擇 UC', 'Select a UC'),
      'swimlaneUcUnsetPrompt': (
        '尚未選定 UC：請在矩陣點選一格，或至 UC Flow 視圖選擇一條 UC',
        'No UC selected: select a cell in the matrix, '
            'or choose a UC in UC Flow',
      ),
      'swimlaneProjectionPendingPrompt': (
        '泳道投影準備中：掃描完成後即顯示此 UC 的步驟',
        "Preparing swimlane: this UC's steps appear when the scan completes",
      ),
      'nodeDetailGraphUnavailableMessage': (
        '此專案的型別表版本不在 App 已知範圍內（不高於 {appVersion}），'
            '最近一次掃描無法建立圖譜，節點詳情暫無法顯示；可至 Domain 視圖重新掃描',
        "This project's schema version is outside the range this app knows "
            '(up to {appVersion}), so the latest scan could not build the '
            'graph and node details are unavailable. '
            'You can rescan from the Domain view',
      ),
      'nodeDetailNodeAbsentMessage': (
        '節點 {nodeId} 不在目前的圖上',
        'Node {nodeId} is not in the current graph',
      ),
      'nodeDetailNodeAbsentHint': (
        '可能已被刪除、改了 ID，或因 ID 重複而被排除',
        'It may have been deleted, renamed to another ID, '
            'or excluded because of a duplicate ID',
      ),
      'degradedSchemaBadgeLabel': (
        '降級型別表（內建 {builtinVersion} / 專案 {projectVersion}）',
        'Degraded schema (builtin {builtinVersion} / project {projectVersion})',
      ),
    };

    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name.arb').readAsStringSync())
            as Map<String, dynamic>;

    test('三個 key 的 zh／en 與規格一致', () {
      _expectArbMatches(arb('app_zh'), arb('app_en'), expected);
    });

    test('E2 正向對照：竄改過的 ARB map 經同一段比對邏輯會失敗', () {
      final tampered = arb('app_zh')..['reloadAction'] = '重新整理';
      expect(
        () => _expectArbMatches(tampered, arb('app_en'), expected),
        throwsA(isA<TestFailure>()),
      );
    });

    test('文案與 SPEC-004 §4.0.6 表格逐字一致', () {
      final spec = File('docs/spec/ui/SPEC-004-component-library.md')
          .readAsStringSync();
      expected.forEach((key, value) {
        final row = spec
            .split('\n')
            .firstWhere((l) => l.startsWith('| `$key` |'));
        if (_skipSpecFirstRow(key, row, arb('app_zh'), arb('app_en'))) return;
        expect(row, contains(value.$1), reason: key);
        expect(row, contains(value.$2), reason: key);
      });
    });

    test('規格先行標記：帶標記的列跳過比對；ARB 已一致則判紅（E2）', () {
      final zh = arb('app_zh');
      final en = arb('app_en');
      final row =
          '| `reloadAction` | ${zh['reloadAction']} | '
          "${en['reloadAction']} | 備註 |";
      expect(_skipSpecFirstRow('reloadAction', row, zh, en), isFalse);
      expect(
        () =>
            _skipSpecFirstRow('reloadAction', '$row（規格先行：1.1.0-W9-1）', zh, en),
        throwsA(isA<TestFailure>()),
      );
      expect(
        _skipSpecFirstRow(
          'reloadAction',
          '| `reloadAction` | 改過 | Changed | 備註（規格先行：1.1.0-W9-1） |',
          zh,
          en,
        ),
        isTrue,
      );
    });
  });
}
