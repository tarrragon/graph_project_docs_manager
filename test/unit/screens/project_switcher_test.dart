/// 專案切換浮層三個狀態測試（SPEC-001 §7；SPEC-004 §3.6；SPEC-003 §3.7）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/shell.dart' as app_shell;
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';

import '../../helpers/helpers.dart';

void main() {
  group('收合態', () {
    testWidgets('側欄入口存在，浮層未掛載', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(app_shell.AppShell.projectSwitcherEntryKey), findsOneWidget);
      expect(
        find.byKey(const Key('state-switcher-expanded')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
      expectNoOverflow(tester);
    });

    testWidgets('點擊入口展開浮層', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
    });
  });

  group('展開態', () {
    testWidgets('渲染 fixture 最近專案清單，每項為 RecentProjectItem', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
      expect(find.byType(RecentProjectItem), findsWidgets);
      expect(find.byType(SwitcherOverlay), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('Esc 收合浮層', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
    });

    testWidgets('點外部收合浮層', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      // 點主區內容（浮層外任一處）。
      await tester.tapAt(const Offset(900, 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
    });

    testWidgets('選擇項目後浮層收合且 currentProjectIndexProvider 改變', (
      tester,
    ) async {
      late ProviderContainer container;
      await pumpApp(
        tester,
        overrides: [],
      );
      final element = tester.element(find.byType(app_shell.AppShell));
      container = ProviderScope.containerOf(element);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
      expect(container.read(currentProjectIndexProvider), 1);
    });
  });

  group('無最近專案態', () {
    testWidgets('清單為空時渲染 SwitcherOverlay 零項 + 選擇資料夾按鈕', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
        ],
      );

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsOneWidget,
      );
      expect(find.byType(RecentProjectItem), findsNothing);
      expect(
        find.byKey(const Key('action-switcher-choose-folder')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });

    testWidgets('Esc 收合浮層', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
    });

    testWidgets('選擇資料夾按鈕收合浮層', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
    });
  });
}
