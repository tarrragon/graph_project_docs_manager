// Domain 視圖畫面只讀 state 的契約（0.5.0-W1-114.21，期望表 S1–S6）。
//
// 矩陣、詳情卡、泳道皆由 `DomainReady.matrix` 與 `domainSwimlaneProvider`
// 渲染；fixture 自 lib 退場。每組皆含 E1 對照（換資料或不觸發，結果隨之不同）。
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_loader.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_projection.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/domain_view_fixtures.dart' show emptyLanesOfMatrix;
import '../../../helpers/helpers.dart';

DomainUc _uc(
  String id,
  String title, {
  bool hasFlowStep = true,
  String? filePath,
}) => DomainUc(
  id: id,
  title: title,
  hasFlowStep: hasFlowStep,
  filePath: filePath,
);

DomainCell _cell(
  String domainId,
  String ucId,
  DomainRelation relation, {
  List<String> steps = const [],
  List<(String, bool)> events = const [],
  List<String> dependencyPaths = const [],
  String? explanation,
}) => DomainCell(
  explanation: explanation,
  domainId: domainId,
  ucId: ucId,
  relation: relation,
  steps: steps,
  events: events,
  dependencyPaths: dependencyPaths,
);

DomainRow _row(String id, String name, List<DomainCell> cells) => DomainRow(
  domainId: id,
  domainName: name,
  cells: cells,
  subtotal: cells.where((c) => c.relation == DomainRelation.direct).length,
);

/// 矩陣 A：兩列兩欄。
final _matrixA = DomainMatrix(
  columns: [_uc('UC-01', '標題甲'), _uc('UC-02', '標題乙')],
  rows: [
    _row('alpha', 'alpha-name', [
      _cell('alpha', 'UC-01', DomainRelation.direct),
      _cell('alpha', 'UC-02', DomainRelation.none),
    ]),
    _row('beta', 'beta-name', [
      _cell('beta', 'UC-01', DomainRelation.indirect),
      _cell('beta', 'UC-02', DomainRelation.direct),
    ]),
  ],
);

/// 矩陣 B：與 A 完全不同的列、欄與關係。
final _matrixB = DomainMatrix(
  columns: [_uc('UC-06', '標題丙')],
  rows: [
    _row('gamma', 'gamma-name', [_cell('gamma', 'UC-06', DomainRelation.none)]),
  ],
);

List<Override> _stateOverrides(
  DomainMatrix? matrix, {
  DomainMode mode = DomainMode.matrix,
  String? selectedDomainId,
  DomainSwimlaneView? swimlane,
  String? selectedUc,
  (String, String)? selectedCell,
}) => [
  domainViewStateProvider.overrideWith(
    (ref) => DomainReady(
      mode: mode,
      selectedDomainId: selectedDomainId,
      selectedCell: selectedCell,
    ),
  ),
  domainMatrixProvider.overrideWith((ref) => matrix),
  domainEmptyLanesProvider.overrideWith((ref) => emptyLanesOfMatrix(matrix)),
  domainSwimlaneProvider.overrideWith((ref) => swimlane),
  if (selectedUc != null) selectedUcProvider.overrideWith((ref) => selectedUc),
];

Relation? _relationOf(WidgetTester tester, String key) {
  final finder = find.byWidgetPredicate(
    (w) => w is MatrixCell && w.testKey == Key(key),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<MatrixCell>(finder).relation;
}

class _CountingLoader extends DomainViewLoader {
  int cancelCalls = 0;

  @override
  void cancelLoading() => cancelCalls++;
}

SwimlaneLane _laneOf(WidgetTester tester, SwimlaneLaneKind kind) => tester
    .widget<SwimlaneGrid>(find.byType(SwimlaneGrid))
    .lanes
    .firstWhere((l) => l.kind == kind);

void main() {
  group('S1 矩陣來自 state', () {
    testWidgets('矩陣 A：列首、欄首、格關係取自 state', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(_matrixA),
      );

      expect(find.byKey(const Key('action-domain-select-alpha')), findsOne);
      expect(find.text('alpha-name'), findsOneWidget);
      // 限定在矩陣欄首：UC id 只出現在欄首一處（原 findsWidgets 恆真）。
      expect(
        find.descendant(
          of: find.byType(MatrixGrid),
          matching: find.text('UC-01'),
        ),
        findsOneWidget,
      );
      expect(find.text('標題乙'), findsOneWidget);
      expect(_relationOf(tester, 'cell-domain-alpha-UC-01'), Relation.direct);
      expect(_relationOf(tester, 'cell-domain-alpha-UC-02'), Relation.none);
      expect(_relationOf(tester, 'cell-domain-beta-UC-01'), Relation.indirect);
    });

    testWidgets('E1 對照：換成矩陣 B，A 的列、欄、格全數消失，B 的出現', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(_matrixB),
      );

      expect(find.byKey(const Key('action-domain-select-gamma')), findsOne);
      expect(find.byKey(const Key('action-domain-select-alpha')), findsNothing);
      expect(find.text('標題乙'), findsNothing);
      expect(find.text('標題丙'), findsOneWidget);
      expect(_relationOf(tester, 'cell-domain-gamma-UC-06'), Relation.none);
      expect(_relationOf(tester, 'cell-domain-alpha-UC-01'), isNull);
    });

    testWidgets('matrix 為 null：不渲染矩陣格', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(null),
      );

      expect(find.byType(MatrixCell), findsNothing);
      expect(find.byType(MatrixGrid), findsOneWidget);
    });
  });

  group('S2 詳情卡', () {
    final matrix = DomainMatrix(
      columns: [_uc('UC-04', '解析')],
      rows: [
        _row('schema', 'schema', [
          _cell(
            'schema',
            'UC-04',
            DomainRelation.indirect,
            dependencyPaths: [
              ['graph', 'corpus', 'schema'].join(dependencyPathSeparator),
              [
                'ticketdetail',
                'corpus',
                'schema',
              ].join(dependencyPathSeparator),
            ],
          ),
        ]),
        _row('graph', 'graph', [
          _cell(
            'graph',
            'UC-04',
            DomainRelation.direct,
            steps: ['步驟甲', '步驟乙'],
            events: [('graph.index.rebuilt', true), ('graph.sync', false)],
            dependencyPaths: ['不應出現 → 於直接格'],
          ),
        ]),
        _row('corpus', 'corpus', [
          _cell('corpus', 'UC-04', DomainRelation.none),
        ]),
      ],
    );

    Future<void> select(WidgetTester tester, String domain) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(matrix),
      );
      await tester.tap(find.byKey(Key('cell-domain-$domain-UC-04')));
      await tester.pumpAndSettle();
    }

    testWidgets('間接依賴格：每條依賴路徑各顯示為一行文字（路徑字串由資料提供）', (tester) async {
      await select(tester, 'schema');

      expect(find.text('graph → corpus → schema'), findsOneWidget);
      expect(find.text('ticketdetail → corpus → schema'), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
    });

    testWidgets('直接格：步驟與事件標籤，不顯示該格自身的依賴路徑（E1 對照：間接格測試顯示其路徑）', (tester) async {
      await select(tester, 'graph');

      expect(find.byType(ListRow), findsNWidgets(2));
      expect(find.text('步驟甲'), findsOneWidget);
      expect(find.text('emits graph.index.rebuilt'), findsOneWidget);
      expect(find.text('consumes graph.sync'), findsOneWidget);
      expect(find.text('不應出現 → 於直接格'), findsNothing);
    });

    testWidgets('詳情卡說明長文真的換行（非單行省略號）', (tester) async {
      final longText = List.filled(60, '很長的說明文字').join();
      final data = DomainMatrix(
        columns: [_uc('UC-09', '標題')],
        rows: [
          _row('delta', 'delta-name', [
            _cell(
              'delta',
              'UC-09',
              DomainRelation.direct,
              explanation: longText,
            ),
          ]),
        ],
      );
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(data),
      );
      await tester.tap(find.byKey(const Key('cell-domain-delta-UC-09')));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text(longText));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('說明、標題與在泳道中檢視取自詳情卡資料', (tester) async {
      final data = DomainMatrix(
        columns: [_uc('UC-09', '新標題')],
        rows: [
          _row('delta', 'delta-name', [
            _cell(
              'delta',
              'UC-09',
              DomainRelation.direct,
              explanation: '新說明文字',
            ),
          ]),
        ],
      );
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(data),
      );
      await tester.tap(find.byKey(const Key('cell-domain-delta-UC-09')));
      await tester.pumpAndSettle();
      expect(find.text('新說明文字'), findsOneWidget);
      expect(find.text('delta-name × UC-09'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DomainViewScreen)),
      );
      await tester.tap(
        find.byKey(const Key('action-domain-cell-goto-swimlane')),
      );
      await tester.pump();
      final ready = container.read(domainViewStateProvider) as DomainReady;
      expect(ready.mode, DomainMode.swimlane);
      expect(ready.selectedDomainId, 'delta');
      expect(container.read(selectedUcProvider), 'UC-09');
    });

    testWidgets('關閉詳情卡：回到未選格提示（E1：關閉前詳情卡存在）', (tester) async {
      await select(tester, 'graph');
      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);

      await tester.tap(find.byKey(const Key('action-domain-cell-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsNothing);
      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
    });

    testWidgets('無關格：顯示「此 domain 不參與此 UC」', (tester) async {
      await select(tester, 'corpus');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DomainViewScreen)),
      );
      expect(find.text(l10n.cellDetailNotInvolved), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
    });
  });

  group('S3 泳道列首依 kind', () {
    final lanes = [
      const DomainLane(domainId: null, kind: DomainLaneKind.screen, nodes: []),
      const DomainLane(
        domainId: 'bundle-zeta',
        domainName: 'zeta-core',
        nodes: [],
      ),
      const DomainLane(
        domainId: null,
        kind: DomainLaneKind.unplaced,
        nodes: [],
      ),
    ];

    Future<AppLocalizations> pumpLanes(
      WidgetTester tester, {
      String? selectedDomainId,
      DomainMatrix? matrix,
    }) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(
          matrix ?? _matrixA,
          mode: DomainMode.swimlane,
          selectedDomainId: selectedDomainId,
          swimlane: DomainSwimlane(lanes: lanes, edges: const []),
          selectedUc: 'UC-01',
        ),
      );
      return AppLocalizations.of(tester.element(find.byType(DomainViewScreen)));
    }

    testWidgets('畫面列：列首走 i18n，傳入元件的 domainId 為 null', (tester) async {
      final l10n = await pumpLanes(tester);

      expect(find.text(l10n.swimlaneScreenLaneName), findsOneWidget);
      expect(_laneOf(tester, SwimlaneLaneKind.screen).domainId, isNull);
    });

    testWidgets('未定位列：列首走 i18n，傳入元件的 domainId 為 null', (tester) async {
      final l10n = await pumpLanes(tester);

      expect(find.text(l10n.swimlaneUnplacedLaneName), findsOneWidget);
      expect(_laneOf(tester, SwimlaneLaneKind.unplaced).domainId, isNull);
    });

    testWidgets('domain 列：列首為 domainName 原值，且矩陣無該 domain 時不崩', (tester) async {
      await pumpLanes(tester);

      expect(find.text('zeta-core'), findsOneWidget);
      expect(
        find.byKey(const Key('action-domain-select-bundle-zeta')),
        findsOne,
      );
      expect(_laneOf(tester, SwimlaneLaneKind.domain).name, 'zeta-core');
    });

    testWidgets('高亮值為選中 domain 的 domainId', (tester) async {
      await pumpLanes(tester, selectedDomainId: 'beta');
      expect(
        tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid)).laneHighlight,
        'beta',
      );
    });

    testWidgets('E1 對照：未選 domain 時無高亮', (tester) async {
      await pumpLanes(tester);
      expect(
        tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid)).laneHighlight,
        isNull,
      );
    });
  });

  group('S4 泳道邊', () {
    Future<void> pumpEdges(
      WidgetTester tester,
      List<DomainLaneEdge> edges,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          swimlane: DomainSwimlane(
            lanes: const [
              DomainLane(
                domainId: 'alpha',
                domainName: 'alpha-name',
                nodes: [],
              ),
            ],
            edges: edges,
          ),
          selectedUc: 'UC-01',
        ),
      );
    }

    testWidgets('兩條邊：SwimlaneGrid 收到對應形狀與欄號', (tester) async {
      await pumpEdges(tester, const [
        DomainLaneEdge(
          fromColumn: 0,
          toColumn: 1,
          fromLane: 0,
          toLane: 0,
          shape: DomainLaneEdgeShape.straight,
        ),
        DomainLaneEdge(
          fromColumn: 2,
          toColumn: 1,
          fromLane: 0,
          toLane: 0,
          shape: DomainLaneEdgeShape.arc,
        ),
      ]);

      final edges = tester
          .widget<SwimlaneGrid>(find.byType(SwimlaneGrid))
          .edges;
      expect(
        [for (final e in edges) (e.fromColumn, e.toColumn, e.shape)],
        [(0, 1, SwimlaneEdgeShape.straight), (2, 1, SwimlaneEdgeShape.arc)],
      );
    });

    testWidgets('E1 對照：無邊時 edges 為空', (tester) async {
      await pumpEdges(tester, const []);

      expect(
        tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid)).edges,
        isEmpty,
      );
    });
  });

  group('S7 讀 state 的退路與泳道分支', () {
    Future<AppLocalizations> pumpScreen(
      WidgetTester tester,
      List<Override> overrides,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides,
      );
      return AppLocalizations.of(tester.element(find.byType(DomainViewScreen)));
    }

    testWidgets('退路一：未選定 UC 的列結構含畫面列與矩陣各列，皆無節點', (tester) async {
      final l10n = await pumpScreen(
        tester,
        _stateOverrides(_matrixA, mode: DomainMode.swimlane),
      );

      expect(
        find.byKey(const Key('state-domain-swimlane-uc-unset')),
        findsOneWidget,
      );
      expect(find.text(l10n.swimlaneScreenLaneName), findsOneWidget);
      final lanes = tester
          .widget<SwimlaneGrid>(find.byType(SwimlaneGrid))
          .lanes;
      expect(
        [for (final l in lanes) (l.kind, l.name)],
        [
          (SwimlaneLaneKind.screen, ''),
          (SwimlaneLaneKind.domain, 'alpha-name'),
          (SwimlaneLaneKind.domain, 'beta-name'),
        ],
      );
      expect(lanes.every((l) => l.nodes.isEmpty), isTrue);
    });

    testWidgets('退路二：已選定 UC 而尚無完成輪次，呈現投影準備中（0.5.0-W1-205.2.2）', (tester) async {
      await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedUc: 'UC-01',
        ),
      );

      expect(
        find.byKey(const Key('state-domain-swimlane-projection-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('state-domain-swimlane-uc-unset')),
        findsNothing,
      );
      expect(find.byKey(const Key('state-domain-swimlane')), findsNothing);
      expect(_laneOf(tester, SwimlaneLaneKind.screen).nodes, isEmpty);
    });

    testWidgets('退路三：UC 標題為空字串時面板標題只顯示 UC id', (tester) async {
      final matrix = DomainMatrix(
        columns: [_uc('UC-01', '')],
        rows: _matrixA.rows,
      );
      await pumpScreen(
        tester,
        _stateOverrides(
          matrix,
          mode: DomainMode.swimlane,
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlaneUnstructured(),
        ),
      );

      expect(find.text('UC-01'), findsOneWidget);
    });

    testWidgets('退路三 E1：UC 標題非空時面板標題為 id 與標題組合', (tester) async {
      final l10n = await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlaneUnstructured(),
        ),
      );

      expect(
        find.text(l10n.swimlanePanelTitle('UC-01', '標題甲')),
        findsOneWidget,
      );
      expect(find.text('UC-01'), findsNothing);
    });

    testWidgets('退路四：選中的格不在矩陣時退回未選格提示', (tester) async {
      await pumpScreen(
        tester,
        _stateOverrides(_matrixA, selectedCell: ('alpha', 'UC-99')),
      );

      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('panel-domain-cell-detail')), findsNothing);
    });

    testWidgets('退路四 E1：選中的格在矩陣內時顯示詳情卡', (tester) async {
      await pumpScreen(
        tester,
        _stateOverrides(_matrixA, selectedCell: ('alpha', 'UC-01')),
      );

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);
    });

    testWidgets('泳道未結構化：面板標題、說明文案與開啟原始檔動作', (tester) async {
      final l10n = await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlaneUnstructured(),
        ),
      );

      expect(
        find.byKey(const Key('state-domain-swimlane-unstructured')),
        findsOneWidget,
      );
      expect(find.text(l10n.flowUnstructuredMessage), findsOneWidget);
      expect(find.text(l10n.flowParseFailedMessage), findsNothing);
      expect(
        find.byKey(const Key('action-domain-open-source')),
        findsOneWidget,
      );
      expect(find.byType(SwimlaneGrid), findsNothing);
    });

    testWidgets('泳道未結構化 E1：解析失敗改用解析失敗文案', (tester) async {
      final l10n = await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlaneUnstructured(isFlowParseFailed: true),
        ),
      );

      expect(find.text(l10n.flowParseFailedMessage), findsOneWidget);
      expect(find.text(l10n.flowUnstructuredMessage), findsNothing);
    });

    testWidgets('高亮值為 domainId：矩陣無該 domain 時仍傳該 id', (tester) async {
      await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedDomainId: 'bundle-zeta',
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlane(
            lanes: [
              DomainLane(
                domainId: 'bundle-zeta',
                domainName: 'zeta-core',
                nodes: [],
              ),
            ],
            edges: [],
          ),
        ),
      );

      expect(
        tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid)).laneHighlight,
        'bundle-zeta',
      );
    });

    testWidgets('高亮值 E1：不查名稱，泳道列無該 domain 時仍傳選中 id', (tester) async {
      await pumpScreen(
        tester,
        _stateOverrides(
          _matrixA,
          mode: DomainMode.swimlane,
          selectedDomainId: 'nowhere',
          selectedUc: 'UC-01',
          swimlane: const DomainSwimlane(lanes: [], edges: []),
        ),
      );

      expect(
        tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid)).laneHighlight,
        'nowhere',
      );
    });
  });

  group('S5 載入中取消', () {
    Future<_CountingLoader> pumpLoading(WidgetTester tester) async {
      final loader = _CountingLoader();
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainLoading()),
          domainViewLoaderProvider.overrideWith(() => loader),
        ],
        settle: false,
      );
      return loader;
    }

    testWidgets('按取消呼叫 cancelLoading，畫面自身不直接寫狀態', (tester) async {
      final loader = await pumpLoading(tester);

      await tester.tap(find.byKey(const Key('action-domain-cancel-load')));
      await tester.pump();

      expect(loader.cancelCalls, 1);
      final element = tester.element(find.byType(DomainViewScreen));
      expect(
        ProviderScope.containerOf(element).read(domainViewStateProvider),
        isA<DomainLoading>(),
      );
    });

    testWidgets('E1 對照：未按取消則不呼叫', (tester) async {
      final loader = await pumpLoading(tester);

      expect(loader.cancelCalls, 0);
    });
  });

  group('S6 fixture 退場', () {
    final importPattern = RegExp(
      r'''^\s*(?:import|export)\s+['"][^'"]*domain_view_fixtures\.dart['"]''',
    );

    /// 命中 domain_view_fixtures 的 import／export 行。
    List<String> fixtureImportsIn(String source) => [
      for (final line in source.split('\n'))
        if (importPattern.hasMatch(line)) line.trim(),
    ];

    test('E2 正向對照：違規樣本被攔下，合法與註解提及放行', () {
      const sample =
          "import 'package:graph_project_docs_manager/screens/domain_view/domain_view_fixtures.dart';\n"
          "import 'domain_view_fixtures.dart';\n"
          "export '../domain_view/domain_view_fixtures.dart';\n"
          "import 'domain_view_state.dart';\n"
          '/// 見 domain_view_fixtures.dart 的歷史說明\n';
      expect(fixtureImportsIn(sample), hasLength(3));
    });

    test(
      'lib 內無單行 import／export domain_view_fixtures（多行寫法不在守衛涵蓋），且檔案不在 lib',
      () {
        final offenders = <String>[
          for (final entity in Directory('lib').listSync(recursive: true))
            if (entity is File &&
                entity.path.endsWith('.dart') &&
                fixtureImportsIn(entity.readAsStringSync()).isNotEmpty)
              entity.path,
        ];
        expect(offenders, isEmpty);
        expect(
          File('lib/screens/domain_view/domain_view_fixtures.dart')
              .existsSync(),
          isFalse,
        );
      },
    );
  });

  group('泳道未結構化態開啟原始檔取自 UC 節點路徑（0.5.0-W1-212）', () {
    const realPath = 'docs/usecases/UC-02-assess-change-impact-by-domain.md';

    Future<FakeExternalOpener> tapOpenSource(
      WidgetTester tester, {
      String? filePath,
    }) async {
      final fake = FakeExternalOpener(defaultResult: ExternalOpenResult.opened);
      final matrix = DomainMatrix(
        columns: [_uc('UC-02', '標題乙', filePath: filePath)],
        rows: const [],
      );
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          ..._stateOverrides(
            matrix,
            mode: DomainMode.swimlane,
            swimlane: const DomainSwimlaneUnstructured(),
            selectedUc: 'UC-02',
          ),
          externalOpenerProvider.overrideWithValue(fake),
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('action-domain-open-source')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('開啟呼叫收到節點 path（檔名帶描述字尾，與 UC id 不等）', (tester) async {
      final fake = await tapOpenSource(tester, filePath: realPath);
      expect(fake.calls, ['/ws/proj/$realPath']);
    });

    testWidgets('對照：不會傳出舊的寫死樣式路徑', (tester) async {
      final fake = await tapOpenSource(tester, filePath: realPath);
      expect(fake.calls, isNot(contains('/ws/proj/docs/usecases/UC-02.md')));
      expect(fake.calls, hasLength(1));
    });

    testWidgets('filePath 為 null：不呼叫 opener，提示找不到檔案', (tester) async {
      final fake = await tapOpenSource(tester);
      expect(fake.calls, isEmpty);
      expect(find.text('找不到檔案'), findsOneWidget);
    });
  });
}
