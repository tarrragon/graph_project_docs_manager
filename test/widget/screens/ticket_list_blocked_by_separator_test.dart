// Ticket 清單 blockedBy 欄串接符依語系（SPEC-001 §4：zh「、」、en「, 」）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/helpers.dart';

const _tickets = [
  TicketFixtureItem(
    id: 'T-3',
    title: 'Gamma',
    status: 'pending',
    priority: 'P1',
    blockedBy: ['T-1', 'T-2'],
  ),
];

Future<void> _pump(WidgetTester tester, Locale locale) => pumpHarness(
  tester,
  locale: locale,
  child: const TicketListScreen(),
  overrides: [
    ticketListStateProvider.overrideWithInitial(
      (ref) => const TicketsReady(tickets: _tickets),
    ),
  ],
);

void main() {
  testWidgets('zh 以「、」串接', (tester) async {
    await _pump(tester, const Locale('zh'));
    expect(find.text('T-1、T-2'), findsOneWidget);
  });

  testWidgets('en 以「, 」串接', (tester) async {
    await _pump(tester, const Locale('en'));
    expect(find.text('T-1, T-2'), findsOneWidget);
  });
}
