// Ticket 清單（SPEC-001 §4；SPEC-003 §3.4；SPEC-004 §3.6）七個狀態列
// （含「含損壞」疊加態）的渲染與退出路徑測試。
//
// 涵蓋：
//   專案未就緒          state-tickets-project-unready   EmptyState.page
//   未載入              state-tickets-unloaded          LoadPrompt
//   載入中              state-tickets-loading           LoadingState.progressBar
//   正常 · 列表          state-tickets-list              Panel[Toolbar,AppDataTable,SplitRow.footer]
//   正常 · 主題          state-tickets-topic             Panel.scrollable[Section.collapsible...]
//   無 ticket           state-tickets-empty             EmptyState.page
//   含損壞（疊加）        badge-tickets-corrupted         IssueMarker.damagedDetail
import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';

import '../../helpers/helpers.dart';

const _readyTickets = [
  TicketFixtureItem(
    id: '0.1.0-W1-001',
    title: 'Alpha ticket',
    status: 'completed',
    priority: 'P0',
    topic: 'shell',
  ),
  TicketFixtureItem(
    id: '0.1.0-W1-002',
    title: 'Beta ticket',
    status: 'pending',
    priority: 'P1',
    topic: 'screens',
  ),
  TicketFixtureItem(
    id: 'broken-file',
    title: 'broken-file.md',
    corrupted: true,
  ),
];

void main() {
  group('專案未就緒 state-tickets-project-unready', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsProjectUnready(ProjectUnreadyReason.notSelected),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.tickets, 'project-unready'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-tickets-goto-domain → jump 至 Domain 視圖', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsProjectUnready(ProjectUnreadyReason.loading),
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'goto-domain'));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.domain);
    });
  });

  group('未載入 state-tickets-unloaded', () {
    testWidgetsAtEachSize('渲染 LoadPrompt', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsUnloaded(count: 7),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.tickets, 'unloaded'), findsOneWidget);
      expect(find.byType(LoadPrompt), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-tickets-start-load → 進入載入中', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsUnloaded(count: 3),
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'start-load'));
      await tester.pump();

      expect(container.read(ticketListStateProvider), isA<TicketsLoading>());
    });

    testWidgets('returnTo 非 null 時渲染 action-tickets-back 並可返回', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsUnloaded(count: 3),
          ),
          returnToProvider.overrideWith((ref) => AppDestination.gaps),
        ],
      );

      expect(AnchorFinder.action(Screen.tickets, 'back'), findsOneWidget);

      await tester.tap(AnchorFinder.action(Screen.tickets, 'back'));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), isNull);
    });

    testWidgets('returnTo 為 null 時不渲染 action-tickets-back', (tester) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsUnloaded(count: 3),
          ),
        ],
      );

      expect(AnchorFinder.action(Screen.tickets, 'back'), findsNothing);
    });
  });

  group('載入中 state-tickets-loading', () {
    testWidgetsAtEachSize('渲染 LoadingState.progressBar', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsLoading(total: 5, processedCount: 2),
          ),
        ],
        size: size,
        settle: false,
      );

      expect(AnchorFinder.state(Screen.tickets, 'loading'), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-tickets-cancel-load → 回到未載入', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsLoading(total: 5, processedCount: 2),
          ),
        ],
        settle: false,
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'cancel-load'));
      await tester.pump();

      final state = container.read(ticketListStateProvider);
      expect(state, isA<TicketsUnloaded>());
      expect((state as TicketsUnloaded).count, 5);
    });
  });

  group('無 ticket state-tickets-empty', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith((ref) => const TicketsEmpty()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.tickets, 'empty'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-tickets-goto-gaps → jump 至破洞報告', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith((ref) => const TicketsEmpty()),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'goto-gaps'));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
    });
  });

  group('正常 · 列表 state-tickets-list', () {
    testWidgetsAtEachSize(
      '渲染 Panel[Toolbar,AppDataTable[TableRow.header,TableRow.ticket],SplitRow.footer]',
      (tester, size) async {
        await pumpHarness(
          tester,
          child: const TicketListScreen(),
          overrides: [
            ticketListStateProvider.overrideWith(
              (ref) => const TicketsReady(tickets: _readyTickets),
            ),
          ],
          size: size,
        );

        expect(AnchorFinder.state(Screen.tickets, 'list'), findsOneWidget);
        expect(find.byType(Toolbar), findsOneWidget);
        expect(find.byType(AppDataTable), findsOneWidget);
        expect(find.byType(AppTableRow), findsNWidgets(1 + _readyTickets.length));
        expect(find.byType(SplitRow), findsOneWidget);
        expectNoOverflow(tester);
      },
    );

    testWidgets('搜尋標題子字串 → 清單筆數縮小', (tester) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      await tester.enterText(
        find.byKey(const Key('input-tickets-search')),
        'Alpha',
      );
      await tester.pump();

      expect(find.byKey(const Key('card-tickets-0.1.0-W1-001')), findsOneWidget);
      expect(find.byKey(const Key('card-tickets-0.1.0-W1-002')), findsNothing);
    });

    testWidgets('action-tickets-filter-status 選狀態 → 清單依狀態過濾', (
      tester,
    ) async {
      // SPEC-003 §3.4 F3 的 `menu-tickets-filter-<key>` /
      // `option-tickets-filter-<key>-<value>` 測試錨點已由
      // `0.1.0-W1-077` 補齊（見 `lib/components/filter_dropdown.dart`），
      // 改以錨點定位選項（取代先前的 Semantics.menuItem label 定位）。
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'filter-status'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('option-tickets-filter-status-pending')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card-tickets-0.1.0-W1-002')), findsOneWidget);
      expect(find.byKey(const Key('card-tickets-0.1.0-W1-001')), findsNothing);
    });

    testWidgets('action-tickets-sort-id 三態循環：asc → desc → none', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'sort-id'));
      await tester.pump();
      var state = container.read(ticketListStateProvider) as TicketsReady;
      expect(state.sortKey, TicketSortKey.id);
      expect(state.sortOrder, TicketSortOrder.asc);

      await tester.tap(AnchorFinder.action(Screen.tickets, 'sort-id'));
      await tester.pump();
      state = container.read(ticketListStateProvider) as TicketsReady;
      expect(state.sortOrder, TicketSortOrder.desc);

      await tester.tap(AnchorFinder.action(Screen.tickets, 'sort-id'));
      await tester.pump();
      state = container.read(ticketListStateProvider) as TicketsReady;
      expect(state.sortKey, isNull);
      expect(state.sortOrder, TicketSortOrder.none);
    });

    testWidgets('card-tickets-<id> → jump 至節點詳情', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('card-tickets-0.1.0-W1-001')));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.nodeDetail,
      );
    });

    testWidgets(
      '帶目標跳入（SPEC-003 §3.4）且目標被篩選隱藏 → 清除篩選並顯示 AppSnackBar.withAction',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const TicketListScreen(),
          overrides: [
            ticketListStateProvider.overrideWith(
              (ref) => const TicketsReady(
                tickets: _readyTickets,
                statusFilter: 'pending',
                targetTicketId: '0.1.0-W1-001',
              ),
            ),
          ],
          settle: false,
        );

        // postFrameCallback 排程的清除與 AppSnackBar.show 需額外幾次
        // pump 才落地（狀態更新 → 重建 → SnackBar 進場動畫）；不用
        // pumpAndSettle 是因為 SnackBar 停留時間到會自動消失，settle
        // 會推進假時鐘直到它消失後才回傳，斷言時已找不到。
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final state = container.read(ticketListStateProvider) as TicketsReady;
        expect(state.statusFilter, isNull);
        expect(state.searchQuery, isEmpty);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.byKey(const Key('undoAction')), findsOneWidget);

        // 篩選已清除，目標列（原被 statusFilter 隱藏）重新可見。
        expect(
          find.byKey(const Key('card-tickets-0.1.0-W1-001')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '帶目標跳入按 undoAction → 還原清除前的搜尋詞與篩選（不撤銷定位）',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const TicketListScreen(),
          overrides: [
            ticketListStateProvider.overrideWith(
              (ref) => const TicketsReady(
                tickets: _readyTickets,
                statusFilter: 'pending',
                targetTicketId: '0.1.0-W1-001',
              ),
            ),
          ],
          settle: false,
          size: WindowSize.design,
        );

        await tester.pump();
        await tester.pump();
        // 讓 SnackBar 進場動畫完全落地，避免動作按鈕仍在位移中導致命中
        // 測試失準（不用 pumpAndSettle：停留計時到會自動消失）。
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byKey(const Key('undoAction')));
        await tester.pump();

        final state = container.read(ticketListStateProvider) as TicketsReady;
        expect(state.statusFilter, 'pending');
      },
    );
  });

  group('頁首模式切換（SplitRow.header 右格，lib/app/shell.dart 接線）', () {
    testWidgets('mode-tickets-topic → 切至正常 · 主題；mode-tickets-list → 切回列表', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.tickets,
          ),
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      expect(find.byKey(const Key('mode-tickets-list')), findsOneWidget);
      expect(find.byKey(const Key('mode-tickets-topic')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-tickets-topic')));
      await tester.pumpAndSettle();
      expect(AnchorFinder.state(Screen.tickets, 'topic'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-tickets-list')));
      await tester.pumpAndSettle();
      expect(AnchorFinder.state(Screen.tickets, 'list'), findsOneWidget);
    });

    testWidgets('未載入等非 TicketsReady 狀態不渲染頁首模式切換（正向對照）', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.tickets,
          ),
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsUnloaded(count: 3),
          ),
        ],
      );

      expect(find.byKey(const Key('mode-tickets-list')), findsNothing);
      expect(find.byKey(const Key('mode-tickets-topic')), findsNothing);
    });
  });

  group('含損壞（疊加） badge-tickets-corrupted', () {
    testWidgetsAtEachSize(
      '工具列與損壞列皆渲染 IssueMarker.damagedDetail',
      (tester, size) async {
        await pumpHarness(
          tester,
          child: const TicketListScreen(),
          overrides: [
            ticketListStateProvider.overrideWith(
              (ref) => const TicketsReady(tickets: _readyTickets),
            ),
          ],
          size: size,
        );

        expect(AnchorFinder.state(Screen.tickets, 'list'), findsOneWidget);
        expect(find.byKey(const Key('badge-tickets-corrupted')), findsOneWidget);
        expect(
          find.byKey(const Key('badge-tickets-corrupted-broken-file')),
          findsOneWidget,
        );
        expect(find.byType(IssueMarker), findsNWidgets(2));
        expectNoOverflow(tester);
      },
    );

    testWidgets('badge-tickets-corrupted → jump 至破洞報告', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(tickets: _readyTickets),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('badge-tickets-corrupted')));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
    });
  });

  group('正常 · 主題 state-tickets-topic', () {
    testWidgetsAtEachSize('渲染 Panel.scrollable[Section.collapsible × N]', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(
              tickets: _readyTickets,
              mode: TicketListMode.topic,
            ),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.tickets, 'topic'), findsOneWidget);
      expect(find.byType(Section), findsNWidgets(3)); // shell, screens, 未歸屬
      expectNoOverflow(tester);
    });

    testWidgets('expander-tickets-topic-<name> → 展開節內票列', (tester) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(
              tickets: _readyTickets,
              mode: TicketListMode.topic,
            ),
          ),
        ],
      );

      expect(find.byKey(const Key('card-tickets-0.1.0-W1-001')), findsNothing);

      await tester.tap(find.byKey(const Key('expander-tickets-topic-shell')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('card-tickets-0.1.0-W1-001')),
        findsOneWidget,
      );
    });

    testWidgets('expander-tickets-unassigned → 展開未歸屬節', (tester) async {
      await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [
          ticketListStateProvider.overrideWith(
            (ref) => const TicketsReady(
              tickets: _readyTickets,
              mode: TicketListMode.topic,
            ),
          ),
        ],
      );

      expect(find.byKey(const Key('card-tickets-broken-file')), findsNothing);

      await tester.tap(find.byKey(const Key('expander-tickets-unassigned')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card-tickets-broken-file')), findsOneWidget);
    });
  });
}
