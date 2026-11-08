// 資料視圖捲動 offset 由頁面層持有（SPEC-004 §2；0.6.0-W1-193.2）：
// 排序後歸零、切換專案重置、切換導覽項保留。以 Ticket 清單為代表畫面。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/workspace_selection.dart';
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
}
