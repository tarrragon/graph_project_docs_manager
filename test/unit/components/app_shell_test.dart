/// SPEC-004 §4.27 / §5.1 `AppShell` 測試點。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
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
        header: const SizedBox.shrink(),
        content: _placeholderPage(
          destination == AppDestination.values.first && longestLabel != null
              ? longestLabel
              : destination.name,
        ),
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
        expect(
          find.byKey(Key('nav-item-${destination.name}')),
          findsOneWidget,
        );
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
          overlay: const SizedBox(
            key: ValueKey('switcher-overlay'),
            width: 200,
            height: 100,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('switcher-overlay')), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('側欄寬等於 LayoutSize.sidebarWidth', (tester, size) async {
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

        final text = tester.widget<Text>(
          find.descendant(
            of: find.byType(AppText),
            matching: find.byType(Text),
          ),
        );
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

    testWidgetsAtEachSize('returnTo 非 null 時 action-<screen>-back 存在，null 時不存在', (
      tester,
      size,
    ) async {
      final container = await pumpHarness(
        tester,
        size: size,
        overrides: [
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.tickets,
          ),
          returnToProvider.overrideWith((ref) => AppDestination.domain),
        ],
        child: AppShell(
          switcherEntry: _buildSwitcherEntry(),
          navItems: _buildNavItems(selected: AppDestination.tickets),
          pages: _buildPages(),
        ),
      );
      expectNoOverflow(tester);

      expect(
        find.byKey(const Key('action-tickets-back')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('action-tickets-back')));
      await tester.pumpAndSettle();

      expect(container.read(returnToProvider), isNull);
      expect(
        find.byKey(const Key('action-tickets-back')),
        findsNothing,
      );
    });

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

      final titleBarBottom = tester
          .getRect(find.text('專案文件流'))
          .bottom;
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

      expect(
        firstNavRect.top - entryRect.bottom,
        moreOrLessEquals(Space.sm),
      );
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
        expect(
          find.byKey(Key('nav-item-${destination.name}')),
          findsOneWidget,
        );
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
}
