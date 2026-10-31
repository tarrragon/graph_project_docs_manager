/// 外圈 IT-D1～IT-D3（SPEC-001-test-design §2.1～§2.3；0.5.0-W1-114.13）。
///
/// 本檔刻意不帶 `_test` 後綴：macOS 上一次 `flutter test` 只能啟動一次 app，
/// `integration_test/` 下第二個 `_test.dart` 必定 `Unable to start the app on
/// the device`；測試改由 `app_test.dart` 的 `main()` 呼叫
/// [registerDomainViewV050Tests] 註冊。
///
/// 不 mock 解析與建圖：以凍結快照實體化的工作區驅動真實 Corpus／Graph／
/// Layout，只替換資料夾選擇器（由 [OpenWorkspace] 回呼注入，沿用
/// `app_test.dart` 的 WorkspaceRepository 替身）。
///
/// ITD3-A5（關聯右欄 proposed 邊標記）：節點詳情無現成 UI 入口可直達 DomainBundle，
/// 改經 container 寫 `nodeDetailStateProvider` 並以 `navigateTo` 切到節點詳情；
/// 驗的是關聯右欄的標示，不是入口。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_projection.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';

import '../test/helpers/spec001/corpus_snapshot.dart';

/// 以 [workspace] 為已授權工作區啟動 App 並 settle（由 `app_test.dart` 實作）。
typedef OpenWorkspace = Future<void> Function(
  WidgetTester tester,
  Directory workspace, {
  Locale? locale,
  List<Override> overrides,
  bool settle,
});

const _projectSnapshot = 'graph_project_docs_manager';
const _balanceSnapshot = 'flutter_balance';
const _bundlePrefix = 'DOMAIN-MAP-';
const _cellPrefix = 'cell-domain-$_bundlePrefix';
final _cellKeyPattern = RegExp('^$_cellPrefix(.+)-(UC-\\d+)\$');

/// 本專案快照的 FR-13 列序（SPEC-001-test-design §1.2）。
const _projectDomains = [
  'schema',
  'workspace',
  'corpus',
  'history',
  'diagnostics',
  'graph',
  'ticketdetail',
  'layout',
];

/// UC-02 步驟欄序（SPEC-001 §1〈泳道布局規則〉期望值欄）。
const _uc02Columns = {
  'locate-domain': 0,
  'enter-from-ticket': 1,
  'read-traversal-count': 2,
  'matrix-overview-only': 3,
  'switch-to-swimlane': 4,
  'flow-not-structured': 5,
  'inspect-steps': 6,
};

/// flutter_balance UC-01 步驟欄序（SPEC-001-test-design §1.2 表）。
const _balanceColumns = {
  'create-accounts': 0,
  'backup-restore': 1,
  'first-inventory': 2,
  'reject-invalid-input': 3,
  'view-net-worth': 4,
  'currency-switch': 5,
  'cashflow-runway': 6,
  'assess-leverage': 7,
  'periodic-inventory': 8,
};

/// 單一 pump／settle 步驟的逾時（0.5.0-W1-479.1）。
///
/// pump 要等引擎送來一幀才返回；App 不在前景時 macOS 不送幀，會無限等待，
/// 而 IntegrationTest binding 的 defaultTestTimeout 為 Timeout.none。步驟逾時
/// 讓卡住變成帶步驟名稱的失敗。須小於 [kItTestTimeout]。
const Duration kPumpStepTimeout = Duration(seconds: 12);

/// 外層 Future 逾時相對步驟逾時的寬限（見 [settleGuarded]）。
const Duration kPumpGrace = Duration(seconds: 4);

/// 單一整合測試案例的逾時；案例總數乘此值須小於閘門套件逾時（900 秒）。
const Timeout kItTestTimeout = Timeout(Duration(seconds: 20));

/// 帶逾時的 testWidgets：每個案例都有明確 timeout。
void itWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool skip = false,
}) {
  testWidgets(description, callback, skip: skip, timeout: kItTestTimeout);
}

/// 帶逾時的 pumpAndSettle；逾時或不收斂時以 [step] 指名失敗。
Future<void> settleGuarded(
  WidgetTester tester,
  String step, {
  Duration timeout = kPumpStepTimeout,
}) async {
  try {
    await tester
        .pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          timeout,
        )
        // 外層逾時只是「不送幀」的最後防線，須晚於 pumpAndSettle 自身逾時：
        // 放棄進行中的 pump 會讓 LiveTestWidgetsFlutterBinding 殘留 pending
        // frame，連帶使後續案例失敗；不收斂形態應由內層逾時乾淨收尾。
        .timeout(timeout + kPumpGrace);
  } on TimeoutException {
    throw TestFailure(
      '[$step] settle 逾時 ${(timeout + kPumpGrace).inSeconds} 秒，疑似不送幀',
    );
  } on FlutterError catch (e) {
    throw TestFailure('[$step] ${timeout.inSeconds} 秒內畫面未靜止：${e.message}');
  }
  // framesEnabled 為 false 時 scheduleFrame 不設旗標，pumpAndSettle 一次 pump
  // 即視為已靜止；此時「已靜止」無法判定，改以失敗指名步驟（0.5.0-W1-581.1）。
  if (!tester.binding.framesEnabled) {
    throw TestFailure(
      '[$step] framesEnabled=false，無法判定畫面已靜止'
      '（App lifecycle 非 resumed／inactive，見 0.5.0-W1-581.1）',
    );
  }
}

/// 帶逾時的固定幀數 pump；逾時時以 [step] 指名失敗。
Future<void> pumpFramesGuarded(
  WidgetTester tester,
  String step, {
  int frames = 5,
}) async {
  try {
    for (var i = 0; i < frames; i++) {
      await tester
          .pump(const Duration(milliseconds: 100))
          .timeout(kPumpStepTimeout);
    }
  } on TimeoutException {
    throw TestFailure('[$step] pump 逾時 ${kPumpStepTimeout.inSeconds} 秒，疑似不送幀');
  }
}

void registerDomainViewV050Tests(OpenWorkspace open) {
  group('IT-D1 矩陣三值分布', () {
    itWidgets('ITD1-A1 本專案快照 48 格直接 19／間接 10／無關 19', (tester) async {
      final workspace = await _openProject(tester, open);

      final cells = _matrixCells(tester);

      expect(cells, hasLength(48), reason: '8 列 × 6 UC');
      expect(_countOf(cells, Relation.direct), 19);
      expect(_countOf(cells, Relation.indirect), 10);
      expect(_countOf(cells, Relation.none), 19);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD1-A2 間接格集合與 history 列全無關', (tester) async {
      final workspace = await _openProject(tester, open);

      final cells = _matrixCells(tester);

      final indirectByUc = <String, Set<String>>{};
      for (final entry in cells.entries) {
        if (entry.value != Relation.indirect) continue;
        final (domain, uc) = _parseCellKey(entry.key);
        (indirectByUc[uc] ??= {}).add(domain);
      }
      expect(indirectByUc, {
        'UC-02': {'schema', 'workspace'},
        'UC-03': {'schema', 'workspace'},
        'UC-04': {'corpus', 'schema', 'workspace'},
        'UC-05': {'schema', 'workspace'},
        'UC-06': {'schema'},
      });
      final historyCells = {
        for (final e in cells.entries)
          if (_parseCellKey(e.key).$1 == 'history') e.key: e.value,
      };
      expect(historyCells, hasLength(6));
      expect(historyCells.values.toSet(), {Relation.none});
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD1-A3 列首文字逐字等於 domain 原值，切 en 不變', (tester) async {
      final workspace = await _openProject(tester, open);

      _expectRowHeaders(tester);
      await open(tester, workspace, locale: const Locale('en'));
      _expectRowHeaders(tester);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD1-A4 flutter_balance 間接依賴 0 格（E1 對照）', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_balanceSnapshot);
      await open(tester, workspace);

      final cells = _matrixCells(tester);

      expect(cells, hasLength(1), reason: '1 個 domain × 1 個 UC');
      expect(_countOf(cells, Relation.indirect), 0);
      expect(_countOf(cells, Relation.direct), 0);
      expect(_countOf(cells, Relation.none), 1);
      await workspace.delete(recursive: true);
    });
  });

  group('IT-D2 泳道布局', () {
    itWidgets('ITD2-A1 UC-02 九列列序', (tester) async {
      final workspace = await _openProject(tester, open);

      await _selectUcAndShowSwimlane(tester, 'UC-02');

      final lanes = _swimlane(tester).lanes;
      expect(_laneTitles(lanes), _uc02LaneTitles);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD2-A2 UC-02 節點欄序與列位置', (tester) async {
      final workspace = await _openProject(tester, open);

      await _selectUcAndShowSwimlane(tester, 'UC-02');

      final lanes = _swimlane(tester).lanes;
      final placed = _nodesByStep(lanes);
      expect(
        {
          for (final e in placed.entries)
            e.key: e.value.map((p) => p.$2).toSet(),
        },
        {
          for (final e in _uc02Columns.entries) e.key: {e.value},
        },
      );
      expect(placed['enter-from-ticket']!.map((p) => p.$1).toSet(), {
        'graph',
        'ticketdetail',
      }, reason: 'enter-from-ticket 的 traverses 為 graph、ticketdetail');
      expect(placed['locate-domain']!.map((p) => p.$1), [_screenTitle]);
      for (final empty in ['schema', 'workspace', 'history', 'diagnostics']) {
        final lane = lanes.firstWhere((l) => l.domainName == empty);
        expect(lane.nodes, isEmpty, reason: '$empty 列應為空列');
      }
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD2-A3 回指為弧線、前向為直線', (tester) async {
      final workspace = await _openProject(tester, open);

      await _selectUcAndShowSwimlane(tester, 'UC-02');

      final edges = _swimlane(tester).edges;
      bool has(int from, int to, DomainLaneEdgeShape shape) => edges.any(
        (e) => e.fromColumn == from && e.toColumn == to && e.shape == shape,
      );
      expect(has(5, 0, DomainLaneEdgeShape.arc), isTrue);
      expect(has(1, 2, DomainLaneEdgeShape.straight), isTrue);
      expect(
        find.byKey(const Key('swimlane-edge-arc-5-0')),
        findsOneWidget,
        reason: '畫面上應繪出 flow-not-structured → locate-domain 的弧線',
      );
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD2-A4 改選 UC-04 列序與 UC-02 相同', (tester) async {
      final workspace = await _openProject(tester, open);
      await _selectUcAndShowSwimlane(tester, 'UC-02');
      final uc02Titles = _laneTitles(_swimlane(tester).lanes);

      await tester.tap(find.byKey(const Key('mode-domain-matrix')));
      await settleGuarded(tester, 'pumpAndSettle');
      await _selectUcAndShowSwimlane(tester, 'UC-04');

      expect(_laneTitles(_swimlane(tester).lanes), uc02Titles);
      expect(uc02Titles, _uc02LaneTitles);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD2-A5 flutter_balance 三列含「未定位」（E1 對照）', (tester) async {
      final workspace = await materializeSnapshotWorkspace(_balanceSnapshot);
      await open(tester, workspace);
      final onlyCell = _matrixCells(tester).keys.single;

      await tester.tap(find.byKey(Key(onlyCell)));
      await settleGuarded(tester, 'pumpAndSettle');
      await tester.tap(find.byKey(const Key('mode-domain-swimlane')));
      await settleGuarded(tester, 'pumpAndSettle');

      final swimlane = _swimlane(tester);
      expect(swimlane.lanes.map((l) => l.kind), [
        DomainLaneKind.screen,
        DomainLaneKind.domain,
        DomainLaneKind.unplaced,
      ]);
      expect(swimlane.lanes[1].domainName, 'balance-sheet');
      expect(swimlane.lanes[0].nodes, isEmpty);
      expect(swimlane.lanes[1].nodes, isEmpty);
      final unplaced = swimlane.lanes[2];
      expect(
        {for (final n in unplaced.nodes) n.stepId: n.column},
        {..._balanceColumns},
      );
      expect(
        swimlane.edges.where((e) => e.shape == DomainLaneEdgeShape.arc),
        hasLength(4),
      );
      expect(
        swimlane.edges.where((e) => e.shape == DomainLaneEdgeShape.straight),
        hasLength(8),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('state-domain-swimlane'))),
      );
      expect(find.text(l10n.swimlaneUnplacedLaneName), findsOneWidget);
      await workspace.delete(recursive: true);
    });
  });

  group('IT-D3 間接格詳情卡與跳轉', () {
    itWidgets('ITD3-A1 UC-04 × schema 間接依賴路徑兩行', (tester) async {
      final workspace = await _openProject(tester, open);

      await _tapCell(tester, 'schema', 'UC-04');

      final l10n = _l10n(tester);
      expect(_detailText(l10n.legendIndirect), findsOneWidget);
      final paths = _dependencyPathTexts(tester);
      expect(paths, [
        ['graph', 'corpus', 'schema'].join(dependencyPathSeparator),
        ['ticketdetail', 'corpus', 'schema'].join(dependencyPathSeparator),
      ]);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD3-A2 UC-06 × schema 依賴路徑一行', (tester) async {
      final workspace = await _openProject(tester, open);

      await _tapCell(tester, 'schema', 'UC-06');

      expect(_dependencyPathTexts(tester), [
        ['corpus', 'schema'].join(dependencyPathSeparator),
      ]);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD3-A3 UC-04 × schema 在泳道中檢視定位到 graph 列最小欄節點', (tester) async {
      final workspace = await _openProject(tester, open);
      await _tapCell(tester, 'schema', 'UC-04');

      await tester.tap(
        find.byKey(const Key('action-domain-cell-goto-swimlane')),
      );
      await settleGuarded(tester, 'pumpAndSettle');

      final container = _container(tester);
      expect(container.read(selectedUcProvider), 'UC-04');
      final ready = container.read(domainViewStateProvider) as DomainReady;
      expect(ready.mode, DomainMode.swimlane);
      final graphLane = _swimlane(tester).lanes
          .firstWhere((l) => l.domainName == 'graph');
      final expected = graphLane.nodes
          .where((n) => n.stepTraverses.contains('${_bundlePrefix}graph'))
          .map((n) => n.column)
          .reduce((a, b) => a < b ? a : b);
      expect(ready.swimlaneFocus?.domainId, '${_bundlePrefix}graph');
      expect(ready.swimlaneFocus?.column, expected);
      await workspace.delete(recursive: true);
    });

    itWidgets('ITD3-A4 直接貫穿與無關格無依賴路徑（E1 對照）', (tester) async {
      final workspace = await _openProject(tester, open);

      await _tapCell(tester, 'graph', 'UC-04');
      expect(_dependencyPathTexts(tester), isEmpty);
      await tester.tap(
        find.byKey(const Key('action-domain-cell-goto-swimlane')),
      );
      await settleGuarded(tester, 'pumpAndSettle');
      final ready = _container(tester).read(domainViewStateProvider);
      expect(
        (ready as DomainReady).swimlaneFocus?.domainId,
        '${_bundlePrefix}graph',
      );
      expect(ready.swimlaneFocus?.column, isNull, reason: '直接貫穿格只落在該列');

      await tester.tap(find.byKey(const Key('mode-domain-matrix')));
      await settleGuarded(tester, 'pumpAndSettle');
      await _tapCell(tester, 'history', 'UC-04');
      expect(_dependencyPathTexts(tester), isEmpty);
      await workspace.delete(recursive: true);
    });

    itWidgets(
      'ITD3-A5 節點詳情 bundle_dependency 關聯有「暫定」、established 邊型沒有（E1 對照）',
      (tester) async {
        final workspace = await _openProject(tester, open);
        const nodeId = '${_bundlePrefix}ticketdetail';
        final container = _container(tester);
        expect(
          container.read(nodeDetailNodesProvider),
          contains(nodeId),
          reason: '真實語料建圖應含 $nodeId 節點',
        );

        container.read(nodeDetailStateProvider.notifier).state =
            const NodeDetailReady(nodeId: nodeId);
        navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);
        await settleGuarded(tester, 'pumpAndSettle');

        final label = AppLocalizations.of(
          tester.element(find.byKey(const Key('state-nodeDetail-normal'))),
        ).relationProposedLabel;
        Finder sectionOf(String type) =>
            find.byKey(Key('panel-nodeDetail-relations-$type'));
        Finder badgesIn(String type) =>
            find.descendant(of: sectionOf(type), matching: find.text(label));
        final items = find.descendant(
          of: sectionOf('bundle_dependency'),
          matching: find.byType(RelationItem),
        );
        expect(items, findsWidgets, reason: 'depends_on_bundles 應產生關聯項');
        expect(
          badgesIn('bundle_dependency'),
          findsNWidgets(items.evaluate().length),
        );
        const prefix = 'panel-nodeDetail-relations-';
        final others = tester
            .widgetList<Section>(find.byType(Section))
            .map((s) => (s.testKey as ValueKey<String>).value)
            .where((k) => k.startsWith(prefix))
            .map((k) => k.substring(prefix.length))
            .where((t) => t != 'bundle_dependency')
            .toList();
        expect(others, isNotEmpty, reason: '同一詳情應另有 established 邊型分節作對照');
        for (final type in others) {
          expect(
            badgesIn(type),
            findsNothing,
            reason: '$type 非 proposed，不應有暫定標記',
          );
        }
        await workspace.delete(recursive: true);
      },
    );
  });
}

const _screenTitle = 'screen';

/// UC-02 九列列首：「畫面」以 [_screenTitle] 代表，其餘為 domain 原值。
const _uc02LaneTitles = [_screenTitle, ..._projectDomains];

Future<Directory> _openProject(WidgetTester tester, OpenWorkspace open) async {
  final workspace = await materializeSnapshotWorkspace(_projectSnapshot);
  await open(tester, workspace);
  return workspace;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DocsManagerApp)));

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byKey(const Key('state-domain-matrix'))),
);

Map<String, Relation> _matrixCells(WidgetTester tester) => {
  for (final cell in tester.widgetList<MatrixCell>(find.byType(MatrixCell)))
    (cell.testKey as ValueKey<String>).value: cell.relation,
};

int _countOf(Map<String, Relation> cells, Relation relation) =>
    cells.values.where((r) => r == relation).length;

(String domain, String uc) _parseCellKey(String key) {
  final match = _cellKeyPattern.firstMatch(key);
  if (match == null) {
    throw StateError('格 key 格式不符：$key'); // i18n-exempt: 測試診斷訊息
  }
  return (match.group(1)!, match.group(2)!);
}

void _expectRowHeaders(WidgetTester tester) {
  for (final domain in _projectDomains) {
    expect(
      find.byKey(Key('action-domain-select-$_bundlePrefix$domain')),
      findsOneWidget,
      reason: '$domain 列首',
    );
    expect(find.text(domain), findsOneWidget, reason: '列首文字應為原值 $domain');
  }
}

Future<void> _tapCell(WidgetTester tester, String domain, String uc) async {
  final key = Key('$_cellPrefix$domain-$uc');
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await settleGuarded(tester, 'pumpAndSettle');
}

Future<void> _selectUcAndShowSwimlane(WidgetTester tester, String uc) async {
  await _tapCell(tester, _firstDomainOf(tester), uc);
  await tester.tap(find.byKey(const Key('mode-domain-swimlane')));
  await settleGuarded(tester, 'pumpAndSettle');
}

String _firstDomainOf(WidgetTester tester) =>
    _parseCellKey(_matrixCells(tester).keys.first).$1;

DomainSwimlane _swimlane(WidgetTester tester) {
  final view = _container(tester).read(domainSwimlaneProvider);
  expect(view, isA<DomainSwimlane>(), reason: '應已建出選定 UC 的泳道');
  return view! as DomainSwimlane;
}

List<String> _laneTitles(List<DomainLane> lanes) => [
  for (final lane in lanes)
    switch (lane.kind) {
      DomainLaneKind.screen => _screenTitle,
      DomainLaneKind.unplaced => 'unplaced',
      DomainLaneKind.domain => lane.domainName!,
    },
];

/// stepId → 其節點所在（列標題, 欄號）清單。
Map<String, List<(String, int)>> _nodesByStep(List<DomainLane> lanes) {
  final result = <String, List<(String, int)>>{};
  final titles = _laneTitles(lanes);
  for (var i = 0; i < lanes.length; i++) {
    for (final node in lanes[i].nodes) {
      (result[node.stepId!] ??= []).add((titles[i], node.column));
    }
  }
  return result;
}

Finder _detailText(String text) => find.descendant(
  of: find.byKey(const Key('panel-domain-cell-detail')),
  matching: find.text(text),
);

/// 詳情卡內含依賴路徑分隔符的文字，依畫面由上而下排序。
List<String> _dependencyPathTexts(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byKey(const Key('panel-domain-cell-detail')),
    matching: find.textContaining(dependencyPathSeparator),
  );
  final texts = finder.evaluate().map((e) => e.widget as Text).toList();
  final tops = {
    for (final t in texts) t: tester.getTopLeft(find.byWidget(t)).dy,
  };
  texts.sort((a, b) => tops[a]!.compareTo(tops[b]!));
  return [for (final t in texts) t.data ?? ''];
}
