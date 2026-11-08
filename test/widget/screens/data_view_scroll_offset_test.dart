// 資料視圖捲動 offset 由頁面層持有（SPEC-004 §2；0.6.0-W1-193.2）：
// 排序後歸零、切換專案重置、切換導覽項保留。以 Ticket 清單為代表畫面。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/app/workspace_selection.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_state.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/helpers.dart';

final _manyTickets = [
  for (var i = 0; i < 80; i++)
    TicketFixtureItem(
      id: '0.1.0-W1-${i.toString().padLeft(3, '0')}',
      title: 'Ticket $i',
      status: 'pending',
      priority: 'P1',
    ),
];

Finder get _list => AnchorFinder.scroll(Screen.tickets, 'list');

double _offset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _list, matching: find.byType(Scrollable)).first,
    )
    .position
    .pixels;

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(_list, const Offset(0, -600));
  await tester.pumpAndSettle();
}

void main() {
  final overrides = [
    ticketListStateProvider.overrideWithInitial(
      (ref) => TicketsReady(tickets: _manyTickets),
    ),
  ];

  testWidgets('捲動後排序：offset 歸零', (tester) async {
    await pumpHarness(
      tester,
      child: const TicketListScreen(),
      overrides: overrides,
    );
    await _scrollDown(tester);
    expect(_offset(tester), greaterThan(0));

    await tester.tap(AnchorFinder.action(Screen.tickets, 'sort-id'));
    await tester.pumpAndSettle();

    expect(_offset(tester), 0);
  });

  testWidgets('E1 對照：捲動後不排序，offset 不變', (tester) async {
    await pumpHarness(
      tester,
      child: const TicketListScreen(),
      overrides: overrides,
    );
    await _scrollDown(tester);
    final before = _offset(tester);
    expect(before, greaterThan(0));

    await tester.pumpAndSettle();

    expect(_offset(tester), before);
  });

  testWidgets('切換專案：offset 重置', (tester) async {
    final container = await pumpHarness(
      tester,
      child: const TicketListScreen(),
      overrides: overrides,
    );
    await _scrollDown(tester);
    expect(_offset(tester), greaterThan(0));

    container.read(projectGenerationProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(_offset(tester), 0);
  });

  testWidgets('切換導覽項（IndexedStack 不 dispose）：offset 保留', (tester) async {
    final index = ValueNotifier<int>(0);
    addTearDown(index.dispose);
    await pumpHarness(
      tester,
      child: ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (_, value, _) => IndexedStack(
          index: value,
          children: const [TicketListScreen(), SizedBox.shrink()],
        ),
      ),
      overrides: overrides,
    );
    await _scrollDown(tester);
    final before = _offset(tester);
    expect(before, greaterThan(0));

    index.value = 1;
    await tester.pumpAndSettle();
    index.value = 0;
    await tester.pumpAndSettle();

    expect(_offset(tester), before);
  });

  _dataViewGroups();
}

// --- UC Flow / Domain 視圖（0.6.0-W1-199） ---

/// TableView 為 [TwoDimensionalScrollable]（其 key 掛在 TableView 本身，
/// 子孫沒有一維 [Scrollable]），一維清單走 [Scrollable]。
List<double> _offsetsIn(Finder scrollHost) {
  final twoD = find.descendant(
    of: scrollHost,
    matching: find.byType(TwoDimensionalScrollable),
  );
  if (twoD.evaluate().isNotEmpty) {
    final state =
        (twoD.evaluate().first as StatefulElement).state
            as TwoDimensionalScrollableState;
    return [
      state.horizontalScrollable.position.pixels,
      state.verticalScrollable.position.pixels,
    ];
  }
  return [
    for (final e
        in find
            .descendant(of: scrollHost, matching: find.byType(Scrollable))
            .evaluate())
      ((e as StatefulElement).state as ScrollableState).position.pixels,
  ];
}

Future<void> _scrollBoth(WidgetTester tester, Finder host) async {
  await tester.drag(host, const Offset(-400, -600));
  await tester.pumpAndSettle();
}

final _manySteps = [
  for (var i = 0; i < 80; i++)
    UcFlowStepItem(
      id: 'step-$i',
      label: 'Step $i', // i18n-exempt: 測試步驟標籤
      domain: 'workspace',
    ),
];

String _ucId(int c) => 'col-$c';

final _bigMatrix = DomainMatrix(
  columns: [
    for (var c = 0; c < 14; c++)
      DomainUc(
        id: _ucId(c),
        title: 'uc $c', // i18n-exempt: 測試 UC 標題
        hasFlowStep: true,
      ),
  ],
  rows: [
    for (var r = 0; r < 40; r++)
      DomainRow(
        domainId: 'dom-$r',
        domainName: 'Dom $r', // i18n-exempt: 測試 domain 名
        cells: [
          for (var c = 0; c < 14; c++)
            DomainCell(
              domainId: 'dom-$r',
              ucId: _ucId(c),
              relation: DomainRelation.none,
            ),
        ],
        subtotal: 0,
      ),
  ],
);

final _bigLanes = [
  for (var r = 0; r < 40; r++)
    DomainLane(
      domainId: 'dom-$r',
      domainName: 'Dom $r', // i18n-exempt: 測試 domain 名
      nodes: [
        for (var c = 0; c < 20; c++)
          DomainLaneNode(
            stepLabel: 'S$r-$c', // i18n-exempt: 測試步驟標籤
            column: c,
            stepTraverses: ['dom-$r'],
          ),
      ],
    ),
];

void _dataViewGroups() {
  group('UC Flow 步驟表', () {
    final host = AnchorFinder.scroll(Screen.ucFlow, 'steps');
    final overrides = [
      ucFlowUcListProvider.overrideWithValue([
        UcFlowUcItem(
          id: 'big',
          title: 'big-uc', // i18n-exempt: 測試 UC 標題
          filePath: 'docs/usecases/big.md', // i18n-exempt: 測試路徑
          steps: _manySteps,
        ),
      ]),
      selectedUcProvider.overrideWithInitial((ref) => 'big'),
    ];

    testWidgets('切換專案：offset 重置', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: overrides,
      );
      await _scrollBoth(tester, host);
      expect(_offsetsIn(host).any((o) => o > 0), isTrue);

      container.read(projectGenerationProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(_offsetsIn(host).every((o) => o == 0), isTrue);
    });

    testWidgets('E1 對照：不切換專案，offset 不變', (tester) async {
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: overrides,
      );
      await _scrollBoth(tester, host);
      final before = _offsetsIn(host);
      expect(before.any((o) => o > 0), isTrue);

      await tester.pumpAndSettle();

      expect(_offsetsIn(host), before);
    });
  });

  group('Domain 視圖', () {
    List<Override> overridesFor(DomainMode mode) => [
      domainViewStateProvider.overrideWithInitial(
        (ref) => DomainReady(mode: mode),
      ),
      domainMatrixProvider.overrideWith((ref) => _bigMatrix),
      domainEmptyLanesProvider.overrideWith((ref) => _bigLanes),
      domainSwimlaneProvider.overrideWith(
        (ref) => DomainSwimlane(lanes: _bigLanes, edges: const []),
      ),
      selectedUcProvider.overrideWithInitial((ref) => 'col-0'),
    ];

    for (final (name, mode, area) in [
      ('矩陣', DomainMode.matrix, 'matrix'),
      ('泳道', DomainMode.swimlane, 'swimlane'),
    ]) {
      final host = AnchorFinder.scroll(Screen.domain, area);

      testWidgets('$name：切換專案 offset 重置', (tester) async {
        final container = await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: overridesFor(mode),
        );
        await _scrollBoth(tester, host);
        expect(_offsetsIn(host).any((o) => o > 0), isTrue);

        container.read(projectGenerationProvider.notifier).state++;
        await tester.pumpAndSettle();

        expect(_offsetsIn(host).every((o) => o == 0), isTrue);
      });

      testWidgets('$name E1 對照：不切換專案，offset 不變', (tester) async {
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: overridesFor(mode),
        );
        await _scrollBoth(tester, host);
        final before = _offsetsIn(host);
        expect(before.any((o) => o > 0), isTrue);

        await tester.pumpAndSettle();

        expect(_offsetsIn(host), before);
      });
    }
  });
}
