// UC Flow 視圖接真資料（0.5.0-W1-114.18）：UC 清單、步驟與事件流由共用輪次
// 與 Graph `flowOf` 驅動，不讀 `UcFlowFixtures`；跳轉定位（flow 類步驟、事件類
// 事件列）。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/app/uc_flow_focus.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_state.dart';

import '../../../helpers/gap_round_fakes.dart';
import '../../../helpers/helpers.dart';

const _manyStepCount = 40;

LightNode _uc(String id, String title) => LightNode(
  id: id,
  typeName: 'UC',
  status: null,
  title: title,
  path: 'docs/usecases/$id.md',
);

Map<String, dynamic> _step(String id, {List<String> emits = const []}) => {
  'id': id,
  'name': 'name-$id',
  'emits': emits,
};

/// 兩個 UC：UC-01 有 [_manyStepCount] 步（最後一步發出事件），UC-02 無步驟。
ScanRoundResult _round() {
  final steps = [
    for (var i = 1; i <= _manyStepCount; i++)
      _step('s$i', emits: i == _manyStepCount ? const ['evt.last'] : const []),
  ];
  final nodes = [_uc('UC-01', 'first uc'), _uc('UC-02', 'second uc')];
  final subgraphs = buildFlowSubgraphs(
    [
      RawNode(
        path: nodes[0].path,
        frontmatter: const {'id': 'UC-01'},
        typeName: 'UC',
        flowSteps: steps,
      ),
    ],
    {'UC-01', 'UC-02'},
    DomainNameResolver.empty(),
  ).subgraphs;
  return fakeRound(
    nodes: nodes,
    event: GraphBuiltEvent(
      nodes: nodes,
      edges: const [],
      graphDefects: const [],
      totalReferences: 0,
      resolvedCount: 0,
      flowSubgraphs: subgraphs,
    ),
  );
}

Override _roundOverride() {
  final round = _round();
  return scanRoundProvider.overrideWith(
    () => FakeScanRound(produce: () => round, initial: round),
  );
}

void main() {
  testWidgets('UC 清單取自輪次的 UC 節點，不含 fixture 的 UC', (tester) async {
    await pumpHarness(
      tester,
      child: const UcFlowScreen(),
      overrides: [_roundOverride()],
    );

    expect(find.byKey(const Key('action-ucFlow-select-uc-UC-01')), findsOne);
    expect(find.byKey(const Key('action-ucFlow-select-uc-UC-02')), findsOne);
    expect(
      find.byKey(const Key('action-ucFlow-select-uc-UC-04')),
      findsNothing,
    );
    expect(find.text('UC-01 first uc'), findsOneWidget);
  });

  testWidgets('選定 UC 的步驟取自 flowOf', (tester) async {
    await pumpHarness(
      tester,
      child: const UcFlowScreen(),
      overrides: [
        _roundOverride(),
        selectedUcProvider.overrideWith((ref) => 'UC-01'),
      ],
    );

    expect(AnchorFinder.state(Screen.ucFlow, 'normal'), findsOneWidget);
    expect(find.text('name-s1'), findsOneWidget);
  });

  testWidgets('無步驟的 UC 落入未結構化態', (tester) async {
    await pumpHarness(
      tester,
      child: const UcFlowScreen(),
      overrides: [
        _roundOverride(),
        selectedUcProvider.overrideWith((ref) => 'UC-02'),
      ],
    );

    expect(AnchorFinder.state(Screen.ucFlow, 'unstructured'), findsOneWidget);
  });

  testWidgets('輪次未完成 → 無 UC 態', (tester) async {
    await pumpHarness(tester, child: const UcFlowScreen());

    expect(AnchorFinder.state(Screen.ucFlow, 'empty'), findsOneWidget);
  });

  group('跳轉定位', () {
    const lastStepKey = Key('card-ucFlow-step-UC-01-$_manyStepCount');

    testWidgets('E1 對照：無定位目標時最後一步不在可見範圍', (tester) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _roundOverride(),
          selectedUcProvider.overrideWith((ref) => 'UC-01'),
        ],
      );

      expect(find.byKey(lastStepKey), findsNothing);
    });

    testWidgets('flow 類：step id 定位到對應步驟', (tester) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _roundOverride(),
          selectedUcProvider.overrideWith((ref) => 'UC-01'),
          ucFlowFocusProvider.overrideWith(
            (ref) =>
                const UcFlowFocus(ucId: 'UC-01', stepId: 's$_manyStepCount'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(lastStepKey), findsOneWidget);
    });

    testWidgets('flow 類：步驟列高亮，指標按下後取消', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _roundOverride(),
          selectedUcProvider.overrideWith((ref) => 'UC-01'),
          ucFlowFocusProvider.overrideWith(
            (ref) =>
                const UcFlowFocus(ucId: 'UC-01', stepId: 's$_manyStepCount'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final stepRow = find.ancestor(
        of: find.byKey(lastStepKey),
        matching: find.byType(AppTableRow),
      );
      expect(tester.widget<AppTableRow>(stepRow.first).isLocated, isTrue);

      await tester.tap(find.text('name-s$_manyStepCount'));
      await tester.pumpAndSettle();

      expect(container.read(ucFlowFocusProvider), isNull);
    });

    testWidgets('E1 對照：無 stepId 的焦點時無列高亮', (tester) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _roundOverride(),
          selectedUcProvider.overrideWith((ref) => 'UC-01'),
          ucFlowFocusProvider.overrideWith(
            (ref) => const UcFlowFocus(ucId: 'UC-01'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final anyLocated = tester
          .widgetList<AppTableRow>(find.byType(AppTableRow))
          .any((r) => r.isLocated);
      expect(anyLocated, isFalse);
    });

    testWidgets('事件類：定位到事件流小表的該事件列並高亮，指標按下後取消', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          _roundOverride(),
          selectedUcProvider.overrideWith((ref) => 'UC-01'),
          ucFlowFocusProvider.overrideWith(
            (ref) => const UcFlowFocus(ucId: 'UC-01', eventId: 'evt.last'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      const rowKey = Key('row-ucFlow-event-evt.last');
      expect(find.byKey(rowKey), findsOneWidget);
      expect(tester.widget<AppTableRow>(find.byKey(rowKey)).isLocated, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byKey(rowKey),
          matching: find.text('evt.last'),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(ucFlowFocusProvider), isNull);
    });
  });

  group('projectUcFlowItems 的 rawNodes 對側宣告', () {
    final ucNode = _uc('UC-01', 'first uc');
    final event = GraphBuiltEvent(
      nodes: [ucNode],
      edges: const [],
      graphDefects: const [],
      totalReferences: 0,
      resolvedCount: 0,
      flowSubgraphs: const {},
    );

    RawNode evt(String id, String type, List<String> p, List<String> c) =>
        RawNode(
          path: 'docs/events/x/$id.md',
          frontmatter: {'id': id, 'producers': p, 'consumers': c},
          typeName: type,
        );

    Map<String, UcFlowEventSides> sidesOf(Iterable<RawNode>? rawNodes) {
      final items = rawNodes == null
          ? projectUcFlowItems(event: event, failedEvents: const [])
          : projectUcFlowItems(
              event: event,
              failedEvents: const [],
              rawNodes: rawNodes,
            );
      return items.single.eventSides;
    }

    test('E1 對照：不傳 rawNodes 為空，傳入後取到對側宣告', () {
      final raws = [
        evt('EVT-A', 'EVT', ['d-prod'], ['d-cons']),
      ];

      final without = sidesOf(null);
      final withRaw = sidesOf(raws);

      expect(without, isEmpty);
      expect(withRaw, isNot(equals(without)));
      expect(withRaw['EVT-A']!.producers, ['d-prod']);
      expect(withRaw['EVT-A']!.consumers, ['d-cons']);
    });

    test('非 EVT 型別不納入', () {
      final sides = sidesOf([
        evt('EVT-NOT-EVENT', 'SPEC', ['x'], ['y']),
        evt('EVT-B', 'EVT', ['p'], []),
      ]);

      expect(sides.keys, ['EVT-B']);
    });

    test('同 id 兩筆先出現者勝', () {
      final sides = sidesOf([
        evt('EVT-C', 'EVT', ['first'], ['first-c']),
        evt('EVT-C', 'EVT', ['second'], ['second-c']),
      ]);

      expect(sides['EVT-C']!.producers, ['first']);
      expect(sides['EVT-C']!.consumers, ['first-c']);
    });

    test('id 缺漏的 EVT 節點不納入', () {
      final sides = sidesOf([
        const RawNode(
          path: 'docs/events/x/none.md',
          frontmatter: {
            'producers': ['p'],
          },
          typeName: 'EVT',
        ),
      ]);

      expect(sides, isEmpty);
    });

    test('ucFlowUcListProvider 傳入 scan.rawNodes', () {
      final round = fakeRound(
        nodes: [ucNode],
        event: event,
        extraRawNodes: [
          evt('EVT-D', 'EVT', ['prod-d'], ['cons-d']),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          scanRoundProvider.overrideWith(
            () => FakeScanRound(produce: () => round, initial: round),
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = container.read(ucFlowUcListProvider);

      expect(items.single.eventSides['EVT-D']!.producers, ['prod-d']);
      expect(items.single.eventSides['EVT-D']!.consumers, ['cons-d']);
    });
  });
}
