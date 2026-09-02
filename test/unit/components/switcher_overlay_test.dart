/// SwitcherOverlay 元件測試（SPEC-004 4.42、5.16）。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const expandedKey = ValueKey('state-switcher-expanded');
  const noRecentKey = ValueKey('state-switcher-no-recent');
  const scrollKey = ValueKey('scroll-switcher-recent');

  List<RecentProjectItem> buildItems(int count) => List.generate(
    count,
    (i) => RecentProjectItem(
      name: 'project-$i',
      summary: '1 節點 · 1 票',
      enabled: true,
      isCurrent: false,
      onTap: () {},
      testKey: ValueKey('card-switcher-recent-$i'),
    ),
  );

  AppButton buildChooseOther({String label = '選擇其他'}) => AppButton(
    label: label,
    onPressed: () {},
    variant: AppButtonVariant.text,
    testKey: const ValueKey('action-switcher-choose-other'),
  );

  group('狀態矩陣：expanded（1/5/50 項）與 noRecent', () {
    for (final count in [1, 5, 50]) {
      testWidgetsAtEachSize('expanded 渲染標題、$count 項與選擇其他，不溢位', (
        tester,
        size,
      ) async {
        var dismissed = false;
        await pumpHarness(
          tester,
          size: size,
          child: Align(
            alignment: Alignment.topLeft,
            child: SwitcherOverlay(
              items: buildItems(count),
              chooseOther: buildChooseOther(),
              onDismiss: () => dismissed = true,
              testKey: expandedKey,
              scrollKey: scrollKey,
              maxHeight: size.size.height - LayoutSize.headerHeight,
            ),
          ),
        );

        expectNoOverflow(tester);
        expect(find.byKey(expandedKey), findsOneWidget);
        expect(find.byKey(ValueKey('card-switcher-recent-0')), findsOneWidget);
        expect(dismissed, isFalse);
      });
    }

    testWidgetsAtEachSize('noRecent 只渲染標題與選擇其他（0 項、無 Divider）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SwitcherOverlay(
          items: const [],
          chooseOther: buildChooseOther(label: '選擇資料夾…'),
          onDismiss: () {},
          testKey: noRecentKey,
          scrollKey: scrollKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(noRecentKey), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(
        find.byKey(const ValueKey('scroll-switcher-recent')),
        findsNothing,
      );
    });

    testWidgetsAtEachSize('50 項於 kMinWindowSize 高度內可捲動且高不超過上限', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: Align(
          alignment: Alignment.topLeft,
          child: SwitcherOverlay(
            items: buildItems(50),
            chooseOther: buildChooseOther(),
            onDismiss: () {},
            testKey: expandedKey,
            scrollKey: scrollKey,
            maxHeight: 300,
          ),
        ),
      );

      expectNoOverflow(tester);
      final box = tester.getSize(find.byKey(expandedKey));
      expect(box.height, lessThanOrEqualTo(300));

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('card-switcher-recent-49')),
        find.byKey(scrollKey),
        const Offset(0, -300),
      );
      expectNoOverflow(tester);
      expect(
        find.byKey(const ValueKey('card-switcher-recent-49')),
        findsOneWidget,
      );
    });
  });

  group('內容政策：標題最長測試文案與語系', () {
    for (final copy in TestCopy.longCopies) {
      testWidgetsAtEachSize('標題最長測試文案不溢位（${copy.substring(0, 4)}…）', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          child: SwitcherOverlay(
            title: copy,
            items: buildItems(1),
            chooseOther: buildChooseOther(),
            onDismiss: () {},
            testKey: expandedKey,
            scrollKey: scrollKey,
            maxHeight: size.size.height,
          ),
        );

        expectNoOverflow(tester);
      });
    }

    for (final locale in kTestLocales) {
      testWidgetsAtEachSize('${locale.languageCode} 語系元件預設標題不溢位', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          locale: locale,
          child: SwitcherOverlay(
            items: buildItems(1),
            chooseOther: buildChooseOther(),
            onDismiss: () {},
            testKey: expandedKey,
            scrollKey: scrollKey,
            maxHeight: size.size.height,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動反應：Esc、點外部、Tab、焦點', () {
    testWidgets('Esc 呼叫 onDismiss 且卸載後焦點回到掛載前的持有者', (tester) async {
      final entryFocus = FocusNode(debugLabel: 'entry');
      addTearDown(entryFocus.dispose);

      await pumpHarness(
        tester,
        child: _EscHarness(
          entryFocus: entryFocus,
          builder: (dismiss) => SwitcherOverlay(
            items: buildItems(2),
            chooseOther: buildChooseOther(),
            onDismiss: dismiss,
            testKey: expandedKey,
            scrollKey: scrollKey,
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      // 呼叫端收到 onDismiss 後卸載浮層，卸載時焦點交還掛載前的持有者。
      expect(find.byKey(expandedKey), findsNothing);
      expect(entryFocus.hasFocus, isTrue);
    });

    testWidgets('點外部呼叫 onDismiss；點內部不觸發', (tester) async {
      var dismissed = false;
      await pumpHarness(
        tester,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('outside'),
                onTap: () {},
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: SwitcherOverlay(
                items: buildItems(1),
                chooseOther: buildChooseOther(),
                onDismiss: () => dismissed = true,
                testKey: expandedKey,
                scrollKey: scrollKey,
              ),
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(expandedKey));
      await tester.pump();
      expect(dismissed, isFalse);

      // 浮層錨定左上角，故只需點在浮層之外的任何座標（此處取 'outside'
      // 元件中心；`warnIfMissed` 對此案例非致命，浮層自身的 `TapRegion`
      // 才是斷言依據）。
      await tester.tap(
        find.byKey(const ValueKey('outside')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Tab 序列不含浮層外元件', (tester) async {
      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(2),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
        ),
      );

      final overlayElement = tester.element(find.byType(SwitcherOverlay));
      bool isInsideOverlay(BuildContext? context) {
        if (context == null) return false;
        var inside = false;
        context.visitAncestorElements((ancestor) {
          if (ancestor == overlayElement) {
            inside = true;
            return false;
          }
          return true;
        });
        return inside;
      }

      // 連續 Tab（`nextFocus`）3 次，每次焦點所在 context 都必須是浮層
      // Container 的子孫（浮層以外無其他可聚焦元件，元件樹中不存在洩漏
      // 對象，故本斷言足以代表「Tab 序列不含浮層外元件」）。
      for (var i = 0; i < 3; i++) {
        final primary = FocusManager.instance.primaryFocus;
        expect(isInsideOverlay(primary?.context), isTrue, reason: '第 $i 次 Tab');
        primary?.nextFocus();
        await tester.pump();
      }
    });

    testWidgets('收合再展開 offset 為 0（重新掛載為新捲動實例）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(30),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
          maxHeight: 200,
        ),
      );

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('card-switcher-recent-29')),
        find.byKey(scrollKey),
        const Offset(0, -300),
      );

      final scrollableBefore = tester.widget<Scrollable>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      final offsetBefore = scrollableBefore.controller?.hasClients == true
          ? scrollableBefore.controller!.offset
          : Scrollable.of(
              tester.element(
                find.byKey(const ValueKey('card-switcher-recent-29')),
              ),
            ).position.pixels;
      expect(offsetBefore, greaterThan(0));

      // 收合：卸載本容器（呼叫端行為，非本容器狀態）。
      await pumpHarness(tester, child: const SizedBox.shrink());

      // 重新展開：全新實例，捲動位置從頂端起算。
      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(30),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
          maxHeight: 200,
        ),
      );

      final newOffset = Scrollable.of(
        tester.element(find.byKey(const ValueKey('card-switcher-recent-0'))),
      ).position.pixels;
      expect(newOffset, 0);
    });
  });

  group('token 引用（非硬編碼）', () {
    testWidgets('寬引用 LayoutSize.overlayWidth', (tester) async {
      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(1),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
        ),
      );

      final box = tester.getSize(find.byKey(expandedKey));
      expect(box.width, LayoutSize.overlayWidth);
    });
  });

  group('排列不變式（SPEC-004 5.16）：不重疊、最小間距、空間不足策略', () {
    testWidgets('標題、項目、Divider、按鈕依序垂直堆疊，不重疊', (tester) async {
      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(2),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
        ),
      );

      final titleBottom = tester.getBottomLeft(find.text('切換專案')).dy;
      final firstItemTop = tester
          .getTopLeft(find.byKey(const ValueKey('card-switcher-recent-0')))
          .dy;
      final lastItemBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('card-switcher-recent-1')))
          .dy;
      final dividerTop = tester.getTopLeft(find.byType(Divider)).dy;
      final buttonTop = tester
          .getTopLeft(
            find.byKey(const ValueKey('action-switcher-choose-other')),
          )
          .dy;

      expect(firstItemTop, greaterThanOrEqualTo(titleBottom));
      expect(dividerTop, greaterThanOrEqualTo(lastItemBottom));
      expect(buttonTop, greaterThanOrEqualTo(dividerTop));
    });

    testWidgets('項目之間最小間距為 Space.xxs', (tester) async {
      await pumpHarness(
        tester,
        child: SwitcherOverlay(
          items: buildItems(2),
          chooseOther: buildChooseOther(),
          onDismiss: () {},
          testKey: expandedKey,
          scrollKey: scrollKey,
        ),
      );

      final item0Bottom = tester
          .getBottomLeft(find.byKey(const ValueKey('card-switcher-recent-0')))
          .dy;
      final item1Top = tester
          .getTopLeft(find.byKey(const ValueKey('card-switcher-recent-1')))
          .dy;

      expect(item1Top - item0Bottom, Space.xxs);
    });

    testWidgetsAtEachSize('空間不足時：50 項置於捲動區可捲至末端不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: Align(
          alignment: Alignment.topLeft,
          child: SwitcherOverlay(
            items: buildItems(50),
            chooseOther: buildChooseOther(),
            onDismiss: () {},
            testKey: expandedKey,
            scrollKey: scrollKey,
            maxHeight: 250,
          ),
        ),
      );

      expectNoOverflow(tester);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('card-switcher-recent-49')),
        find.byKey(scrollKey),
        const Offset(0, -300),
      );

      expectNoOverflow(tester);
      expect(
        find.byKey(const ValueKey('card-switcher-recent-49')),
        findsOneWidget,
      );
    });
  });
}

/// 供 Esc 測試建立「掛載前已有焦點持有者、onDismiss 卸載浮層」情境的容器
/// （呼叫端真實行為：本容器只負責 Esc 通知，卸載時機由呼叫端決定）。
class _EscHarness extends StatefulWidget {
  const _EscHarness({required this.entryFocus, required this.builder});

  final FocusNode entryFocus;
  final Widget Function(VoidCallback dismiss) builder;

  @override
  State<_EscHarness> createState() => _EscHarnessState();
}

class _EscHarnessState extends State<_EscHarness> {
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.entryFocus.requestFocus();
      setState(() => _showOverlay = true);
    });
  }

  void _dismiss() => setState(() => _showOverlay = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Focus(
          focusNode: widget.entryFocus,
          child: const SizedBox(width: 1, height: 1),
        ),
        if (_showOverlay) widget.builder(_dismiss),
      ],
    );
  }
}
