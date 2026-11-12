/// SPEC-004 §4.27 / §5.1 `AppShell` 測試點。
library;

import 'package:flutter/material.dart' hide Badge, Divider;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

Widget _placeholderPage(String label) => Center(child: Text(label));

List<NavItem> _buildNavItems({AppDestination? selected}) {
  return [
    for (final destination in AppDestination.values)
      NavItem(
        icon: const AppIcon(icon: Icons.circle),
        label: destination.name,
        isSelected: destination == selected,
        onTap: () {},
        testKey: Key('nav-item-${destination.name}'),
      ),
  ];
}

List<PageColumn> _buildPages({String? longestLabel}) {
  return [
    for (final destination in AppDestination.values)
      PageColumn(
        semanticLabel: destination.name,
        header: SplitRow.header(leading: PageTitle(title: destination.name)),
        content: _placeholderPage(
          destination == AppDestination.values.first && longestLabel != null
              ? longestLabel
              : destination.name,
        ),
      ),
  ];
}

List<NavItem> _buildBottomItems({List<String>? tapLog, int failureCount = 0}) {
  return [
    for (final kind in const ['preferences', 'shortcuts', 'writeLog'])
      NavItem.action(
        icon: const AppIcon(icon: Icons.circle),
        label: kind,
        onTap: () => tapLog?.add(kind),
        testKey: Key('nav-action-$kind'),
        badge: kind == 'writeLog' && failureCount > 0
            ? Badge.count(
                key: const Key('badge-writeLog-failure-count'),
                count: failureCount,
              )
            : null,
      ),
  ];
}

ProjectSwitcherEntry _buildSwitcherEntry() {
  return ProjectSwitcherEntry(
    isExpanded: false,
    onTap: () {},
    testKey: AppShell.projectSwitcherEntryKey,
  );
}

void main() {
  group('AppShell', () {
    testWidgetsAtEachSize('建構參數驅動：選中頁與徽章取自參數而非 provider（0.5.0-W1-213.3）', (
      tester,
      size,
    ) async {
      var backTapped = false;
      await pumpHarness(
        tester,
        size: size,
        // provider 預設選中 domain；參數傳 tickets，畫面必須顯示參數值。
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.tickets),
          pages: _buildPages(),
          selectedIndex: AppDestination.tickets.index,
          screenName: AppDestination.tickets.name,
          hasBackAction: true,
          onBack: () => backTapped = true,
          inferredVersion: '9.9.9',
        ),
      );
      expectNoOverflow(tester);

      expect(find.byKey(const Key('action-tickets-back')), findsOneWidget);
      expect(find.byKey(const Key('action-domain-back')), findsNothing);
      expect(
        find.byKey(const Key('badge-tickets-inferred-version')),
        findsOneWidget,
      );
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, AppDestination.tickets.index);
      await tester.tap(find.byKey(const Key('action-tickets-back')));
      expect(backTapped, isTrue);
    });

    testWidgetsAtEachSize('default 態渲染，六格導覽項與六頁不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );

      expect(find.byKey(AppShell.shellKey), findsOneWidget);
      expect(find.byKey(AppShell.projectSwitcherEntryKey), findsOneWidget);
      for (final destination in AppDestination.values) {
        expect(find.byKey(Key('nav-item-${destination.name}')), findsOneWidget);
      }
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('overlayOpen 態渲染 overlay slot，不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
          overlay: SwitcherOverlay(
            items: const [],
            chooseOther: AppButton(
              label: 'choose other',
              onPressed: () {},
              testKey: const Key('action-switcher-choose-other'),
              variant: AppButtonVariant.text,
            ),
            onDismiss: () {},
            testKey: const ValueKey('switcher-overlay'),
            scrollKey: const Key('scroll-switcher-overlay-test'),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('switcher-overlay')), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize(
      'overlayOpen 態點擊背景導覽項：吸收收合、不觸發原 onTap（0.1.0-W3-335.47 D13）',
      (tester, size) async {
        var navTapped = false;
        var dismissed = false;
        await pumpHarness(
          tester,
          size: size,
          child: AppShell(
            switcherEntry: _buildSwitcherEntry(),
            navItems: [
              for (final destination in AppDestination.values)
                NavItem(
                  icon: const AppIcon(icon: Icons.circle),
                  label: destination.name,
                  isSelected: destination == AppDestination.domain,
                  onTap: () => navTapped = true,
                  testKey: Key('nav-item-${destination.name}'),
                ),
            ],
            pages: _buildPages(),
            overlay: SwitcherOverlay(
              items: const [],
              chooseOther: AppButton(
                label: 'choose other',
                onPressed: () {},
                testKey: const Key('action-switcher-choose-other'),
                variant: AppButtonVariant.text,
              ),
              onDismiss: () => dismissed = true,
              testKey: const ValueKey('switcher-overlay'),
              scrollKey: const Key('scroll-switcher-overlay-test'),
            ),
          ),
        );

        await tester.tap(
          find.byKey(Key('nav-item-${AppDestination.tickets.name}')),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(navTapped, isFalse);
        expect(dismissed, isTrue);
      },
    );

    testWidgetsAtEachSize('側欄寬等於 LayoutSize.sidebarWidth', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      final sidebarSize = tester.getSize(
        find.byKey(AppShell.projectSwitcherEntryKey),
      );
      // 入口寬受側欄寬與內距共同決定，量測其父層 SizedBox 寬更直接。
      final shellRenderSize = tester.getSize(find.byKey(AppShell.shellKey));
      expect(shellRenderSize.width, greaterThan(sidebarSize.width));
    });

    for (final locale in kTestLocales) {
      testWidgetsAtEachSize('標題最長測試文案（${locale.languageCode}）不溢位並截斷', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          locale: locale,
          child: AppShell(
            title: TestCopy.longToken,
            switcherEntry: _buildSwitcherEntry(),
            navItems: _buildNavItems(selected: AppDestination.domain),
            pages: _buildPages(),
          ),
        );
        expectNoOverflow(tester);

        final text = tester.widget<Text>(find.text(TestCopy.longToken));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      });
    }

    testWidgetsAtEachSize('title 為 null 時顯示預設 appTitle', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);
      expect(find.text('專案文件流'), findsOneWidget);
    });

    testWidgetsAtEachSize(
      'returnTo 非 null 時 action-<screen>-back 存在，null 時不存在',
      (tester, size) async {
        var hasBack = true;
        late StateSetter rebuild;
        await pumpHarness(
          tester,
          size: size,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AppShell(
                switcherEntry: _buildSwitcherEntry(),
                navItems: _buildNavItems(selected: AppDestination.tickets),
                pages: _buildPages(),
                selectedIndex: AppDestination.tickets.index,
                screenName: AppDestination.tickets.name,
                hasBackAction: hasBack,
                onBack: () => rebuild(() => hasBack = false),
              );
            },
          ),
        );
        expectNoOverflow(tester);

        expect(find.byKey(const Key('action-tickets-back')), findsOneWidget);

        await tester.tap(find.byKey(const Key('action-tickets-back')));
        await tester.pumpAndSettle();

        expect(hasBack, isFalse);
        expect(find.byKey(const Key('action-tickets-back')), findsNothing);
      },
    );

    testWidgetsAtEachSize(
      '真實 TicketListScreen（無 ticket 態、returnTo 非 null）經 AppShell：action-tickets-back 只出現一顆（0.4.1-W1-008）',
      (tester, size) async {
        await pumpHarness(
          tester,
          size: size,
          overrides: [
            ticketListStateProvider.overrideWithInitial(
              (ref) => const TicketsEmpty(),
            ),
          ],
          child: AppShell(
            switcherEntry: _buildSwitcherEntry(),
            navItems: _buildNavItems(selected: AppDestination.tickets),
            selectedIndex: AppDestination.tickets.index,
            screenName: AppDestination.tickets.name,
            hasBackAction: true,
            onBack: () {},
            pages: [
              for (final destination in AppDestination.values)
                PageColumn(
                  semanticLabel: destination.name,
                  header: SplitRow.header(
                    leading: PageTitle(title: destination.name),
                  ),
                  content: destination == AppDestination.tickets
                      ? const TicketListScreen()
                      : _placeholderPage(destination.name),
                ),
            ],
          ),
        );
        expectNoOverflow(tester);

        expect(find.byType(TicketListScreen), findsOneWidget);
        expect(find.byKey(const Key('action-tickets-back')), findsOneWidget);
      },
    );

    testWidgetsAtEachSize('returnTo 為 null 時不渲染返回鍵', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppButton && widget.label == '返回',
        ),
        findsNothing,
      );
    });

    // --- SPEC-001 §1〈降級型別表〉疊加旗標；SPEC-004 §4.27 state-change 列 ---

    for (final destination in AppDestination.values) {
      testWidgetsAtEachSize(
        '降級旗標為真時 badge-${destination.name}-degraded-schema 常駐可見'
        '（returnTo 為 null 亦然）',
        (tester, size) async {
          await pumpHarness(
            tester,
            size: size,
            child: AppShell(
              switcherEntry: _buildSwitcherEntry(),
              navItems: _buildNavItems(selected: destination),
              pages: _buildPages(),
              selectedIndex: destination.index,
              screenName: destination.name,
              isDegraded: true,
              degradedBuiltinVersion: '1.0',
              degradedProjectVersion: '2.0',
            ),
          );
          expectNoOverflow(tester);

          expect(
            find.byKey(Key('badge-${destination.name}-degraded-schema')),
            findsOneWidget,
          );
          // 未觸發返回動作時該畫面無來源記錄，返回鍵不與徽章並存。
          expect(
            find.byKey(Key('action-${destination.name}-back')),
            findsNothing,
          );
        },
      );
    }

    testWidgetsAtEachSize('降級旗標為假時徽章不渲染', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      expect(
        find.byKey(const Key('badge-domain-degraded-schema')),
        findsNothing,
      );
    });

    testWidgetsAtEachSize('降級旗標為真且 returnTo 非 null 時，徽章與返回鍵同列並存', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.tickets),
          pages: _buildPages(),
          selectedIndex: AppDestination.tickets.index,
          screenName: AppDestination.tickets.name,
          hasBackAction: true,
          onBack: () {},
          isDegraded: true,
          degradedBuiltinVersion: '1.0',
          degradedProjectVersion: '2.0',
        ),
      );
      expectNoOverflow(tester);

      expect(
        find.byKey(const Key('badge-tickets-degraded-schema')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('action-tickets-back')), findsOneWidget);

      final badgeRect = tester.getRect(
        find.byKey(const Key('badge-tickets-degraded-schema')),
      );
      final backRect = tester.getRect(
        find.byKey(const Key('action-tickets-back')),
      );
      // 徽章（左）與返回鍵（右）同一列不重疊。
      expect(badgeRect.right, lessThanOrEqualTo(backRect.left));
    });

    // --- SPEC-004 §5.1 排列不變式 ---

    testWidgetsAtEachSize('不重疊：標題列、側欄、主區三格互斥', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      final titleBarBottom = tester.getRect(find.text('專案文件流')).bottom;
      final sidebarRect = tester.getRect(
        find.byKey(AppShell.projectSwitcherEntryKey),
      );
      final navItemRect = tester.getRect(
        find.byKey(Key('nav-item-${AppDestination.domain.name}')),
      );

      // 標題列在側欄之上（標題文字底端不晚於側欄頂端）。
      expect(titleBarBottom, lessThanOrEqualTo(sidebarRect.top));
      // 側欄內子件垂直堆疊不相交：入口底端不晚於第一個導覽項頂端。
      expect(sidebarRect.bottom, lessThanOrEqualTo(navItemRect.top));
    });

    testWidgetsAtEachSize('最小間距：入口與導覽項間 Space.sm，導覽項間 Space.xxs', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      final entryRect = tester.getRect(
        find.byKey(AppShell.projectSwitcherEntryKey),
      );
      final firstNavRect = tester.getRect(
        find.byKey(Key('nav-item-${AppDestination.values[0].name}')),
      );
      final secondNavRect = tester.getRect(
        find.byKey(Key('nav-item-${AppDestination.values[1].name}')),
      );

      expect(firstNavRect.top - entryRect.bottom, moreOrLessEquals(Space.sm));
      expect(
        secondNavRect.top - firstNavRect.bottom,
        moreOrLessEquals(Space.xxs),
      );
    });

    testWidgetsAtEachSize('空間不足策略不觸發：六格導覽項於 kMinWindowSize 下不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      for (final destination in AppDestination.values) {
        expect(find.byKey(Key('nav-item-${destination.name}')), findsOneWidget);
      }
    });

    testWidgetsAtEachSize('尺寸與顏色引用 token 非硬編碼：側欄寬取 LayoutSize.sidebarWidth', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      final sidebarBox = tester.widget<SizedBox>(
        find
            .byWidgetPredicate(
              (widget) => widget is SizedBox && widget.width != null,
            )
            .first,
      );
      expect(sidebarBox.width, LayoutSize.sidebarWidth);
    });
  });

  group('AppShell 側欄底部 slot（SPEC-004 4.27）', () {
    testWidgetsAtEachSize('三項依序渲染於導覽項之下、貼齊側欄底部，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          bottomItems: _buildBottomItems(),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      final prefs = tester.getRect(
        find.byKey(const Key('nav-action-preferences')),
      );
      final shortcuts = tester.getRect(
        find.byKey(const Key('nav-action-shortcuts')),
      );
      final writeLog = tester.getRect(
        find.byKey(const Key('nav-action-writeLog')),
      );
      final lastNav = tester.getRect(
        find.byKey(Key('nav-item-${AppDestination.values.last.name}')),
      );
      expect(lastNav.bottom, lessThan(prefs.top));
      expect(prefs.bottom, lessThanOrEqualTo(shortcuts.top));
      expect(shortcuts.bottom, lessThanOrEqualTo(writeLog.top));
      final shell = tester.getRect(find.byKey(AppShell.shellKey));
      expect(writeLog.bottom, shell.bottom - Space.md);
    });

    testWidgetsAtEachSize('底部區上方有一條 Divider，與三項間隔 Space.sm', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(),
          bottomItems: _buildBottomItems(),
          pages: _buildPages(),
        ),
      );
      final divider = tester.getRect(find.byType(Divider));
      final prefs = tester.getRect(
        find.byKey(const Key('nav-action-preferences')),
      );
      expect(divider.bottom + Space.sm, prefs.top);
    });

    testWidgetsAtEachSize('點三項呼叫各自 onTap，且不改變導覽選取', (tester, size) async {
      final log = <String>[];
      await pumpHarness(
        tester,
        size: size,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          bottomItems: _buildBottomItems(tapLog: log),
          pages: _buildPages(),
        ),
      );
      await tester.tap(find.byKey(const Key('nav-action-preferences')));
      await tester.tap(find.byKey(const Key('nav-action-shortcuts')));
      await tester.tap(find.byKey(const Key('nav-action-writeLog')));
      expect(log, ['preferences', 'shortcuts', 'writeLog']);
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 0);
    });

    testWidgets('Tab 順序：七導覽項之後依序進入底部三項', (tester) async {
      await pumpHarness(
        tester,
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.domain),
          bottomItems: _buildBottomItems(),
          pages: _buildPages(),
        ),
      );
      final order = <Key>[
        AppShell.projectSwitcherEntryKey,
        for (final d in AppDestination.values) Key('nav-item-${d.name}'),
        const Key('nav-action-preferences'),
        const Key('nav-action-shortcuts'),
        const Key('nav-action-writeLog'),
      ];
      for (final key in order) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focusedContext = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byElementPredicate((e) => e == focusedContext),
          ),
          findsOneWidget,
          reason: '焦點應在 $key',
        );
      }
    });

    testWidgetsAtEachSize('失敗計數 0 無 badge、1 有 badge', (tester, size) async {
      for (final count in [0, 1]) {
        await pumpHarness(
          tester,
          size: size,
          child: AppShell(
            switcherEntry: _buildSwitcherEntry(),
            navItems: _buildNavItems(),
            bottomItems: _buildBottomItems(failureCount: count),
            pages: _buildPages(),
          ),
        );
        expect(
          find.byKey(const Key('badge-writeLog-failure-count')),
          count == 0 ? findsNothing : findsOneWidget,
        );
        expectNoOverflow(tester);
      }
    });

    // 暫時性：組裝層尚傳 2 項，此案由 1.0.0-W3-553.17 刪除。
    test('暫時：傳 2 項不觸發 assert', () {
      expect(
        () => AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(),
          bottomItems: _buildBottomItems().take(2).toList(),
          pages: _buildPages(),
        ),
        returnsNormally,
      );
    });

    test('bottomItems 不接受 1 項', () {
      expect(
        () => AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(),
          bottomItems: _buildBottomItems().take(1).toList(),
          pages: _buildPages(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('AppShell 唯讀降級徽章（SPEC-004 4.27）', () {
    AppShell build({
      ReadonlyWorkspaceReason? reason,
      bool isDegraded = false,
      String? inferred,
      AppDestination dest = AppDestination.domain,
    }) => AppShell(
      switcherEntry: _buildSwitcherEntry(),
      navItems: _buildNavItems(selected: dest),
      pages: _buildPages(),
      selectedIndex: dest.index,
      screenName: dest.name,
      readonlyWorkspaceReason: reason,
      isDegraded: isDegraded,
      degradedBuiltinVersion: '1.0.0',
      degradedProjectVersion: '0.9.0',
      inferredVersion: inferred,
    );

    testWidgetsAtEachSize('七畫面皆渲染兩種原因對應文字', (tester, size) async {
      for (final dest in AppDestination.values) {
        for (final (reason, text) in [
          (ReadonlyWorkspaceReason.notGit, '此資料夾不是 git repo，無法在 App 內編輯'),
          (ReadonlyWorkspaceReason.gitMissing, '找不到 git，無法在 App 內編輯'),
        ]) {
          await pumpHarness(
            tester,
            size: size,
            child: build(reason: reason, dest: dest),
          );
          final key = Key('badge-${dest.name}-readonly-workspace');
          expect(find.byKey(key), findsOneWidget);
          expect(
            find.descendant(of: find.byKey(key), matching: find.text(text)),
            findsOneWidget,
          );
          expectNoOverflow(tester);
        }
      }
    });

    testWidgetsAtEachSize('旗標為假時不存在', (tester, size) async {
      await pumpHarness(tester, size: size, child: build());
      expect(
        find.byKey(const Key('badge-domain-readonly-workspace')),
        findsNothing,
      );
    });

    testWidgetsAtEachSize('可與降級、推定版本徽章同列', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: build(reason: ReadonlyWorkspaceReason.notGit, isDegraded: true),
      );
      expect(
        find.byKey(const Key('badge-domain-readonly-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('badge-domain-degraded-schema')),
        findsOneWidget,
      );
      await pumpHarness(
        tester,
        size: size,
        child: build(
          reason: ReadonlyWorkspaceReason.gitMissing,
          inferred: '1.2.3',
        ),
      );
      expect(
        find.byKey(const Key('badge-domain-readonly-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('badge-domain-inferred-version')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });
  });
}
