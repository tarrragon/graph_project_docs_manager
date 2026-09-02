/// SPEC-004 §4.30 `Panel` 測試點 + §5.4 排列不變式。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 佔位資料視圖：填色方塊，模擬 §4.30「一個填滿高的資料視圖」。
class _FakeDataView extends StatelessWidget {
  const _FakeDataView();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.surfaceChip),
    );
  }
}

/// 固有高的子件（模擬 `Toolbar` / `AppText` 等非資料視圖 slot）。
class _FixedChild extends StatelessWidget {
  const _FixedChild({this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

void main() {
  group('變體渲染', () {
    testWidgetsAtEachSize('standard：含一個填滿高資料視圖，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: const SizedBox(
          width: 400,
          height: 300,
          child: Panel(
            children: [
              _FixedChild(),
              Expanded(child: _FakeDataView()),
            ],
          ),
        ),
      );
      expectNoOverflow(tester);
      expect(find.byType(_FakeDataView), findsOneWidget);
    });

    testWidgetsAtEachSize('scrollable：子件總高超過面板高時不溢位', (tester, size) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 400,
          height: 200,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: List.generate(20, (i) => const _FixedChild()),
          ),
        ),
      );
      expectNoOverflow(tester);
      expect(find.byKey(scrollKey), findsOneWidget);
    });

    testWidgetsAtEachSize('scrollable：子件總高不足一屏時不溢位', (tester, size) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 400,
          height: 300,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: const [_FixedChild(height: 20)],
          ),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('捲動行為（scrollable）', () {
    testWidgets('子件總高超出時 drag 後 offset 改變', (tester) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 200,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: List.generate(20, (i) => const _FixedChild()),
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, 0);

      await tester.drag(find.byKey(scrollKey), const Offset(0, -300));
      await tester.pump();

      expect(scrollable.position.pixels, greaterThan(0));
      expectNoOverflow(tester);
    });

    testWidgets('子件總高不足一屏時 offset 為 0 且無錯誤', (tester) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: const [_FixedChild(height: 20)],
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, 0);

      await tester.drag(find.byKey(scrollKey), const Offset(0, -100));
      await tester.pump();

      expect(scrollable.position.pixels, 0);
      expectNoOverflow(tester);
    });

    testWidgets('兩個獨立 Panel.scrollable 並排時捲動互不影響', (tester) async {
      final leftKey = UniqueKey();
      final rightKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 800,
          height: 200,
          child: Row(
            children: [
              SizedBox(
                width: 300,
                height: 200,
                child: Panel.scrollable(
                  scrollKey: leftKey,
                  children: List.generate(20, (i) => const _FixedChild()),
                ),
              ),
              SizedBox(
                width: 300,
                height: 200,
                child: Panel.scrollable(
                  scrollKey: rightKey,
                  children: List.generate(20, (i) => const _FixedChild()),
                ),
              ),
            ],
          ),
        ),
      );

      final leftScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(leftKey),
          matching: find.byType(Scrollable),
        ),
      );
      final rightScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(rightKey),
          matching: find.byType(Scrollable),
        ),
      );

      await tester.drag(find.byKey(leftKey), const Offset(0, -300));
      await tester.pump();

      expect(leftScrollable.position.pixels, greaterThan(0));
      expect(rightScrollable.position.pixels, 0);
      expectNoOverflow(tester);
    });
  });

  group('無自有文字', () {
    testWidgets('本項不適用（Panel 無文字 slot）', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(
          width: 300,
          height: 200,
          child: Panel(children: [_FixedChild()]),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('design token', () {
    testWidgets('顏色、內距、圓角引用 token 非硬編碼', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(
          width: 300,
          height: 200,
          child: Panel(children: [_FixedChild()]),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfaceBase);
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.border);
      expect(decoration.borderRadius, BorderRadius.circular(Radius.lg));

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, EdgeInsets.all(Space.md));
    });
  });

  group('排列不變式（§5.4）', () {
    testWidgets('不重疊：子件垂直堆疊、填滿寬，兩兩不相交', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(
          width: 300,
          height: 300,
          child: Panel(
            children: [
              _FixedChild(height: 50),
              _FixedChild(height: 60),
              _FixedChild(height: 70),
            ],
          ),
        ),
      );

      final rects = tester
          .widgetList<_FixedChild>(find.byType(_FixedChild))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();

      expect(rects.length, 3);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '子件 $i 與 $j 不應重疊',
          );
        }
      }
      // 填滿寬：各子件寬度相同（stretch）。
      for (final rect in rects) {
        expect(rect.width, rects.first.width);
      }
      expectNoOverflow(tester);
    });

    testWidgets('最小間距：子件兩兩垂直間距為 Space.sm', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(
          width: 300,
          height: 300,
          child: Panel(
            children: [
              _FixedChild(height: 50),
              _FixedChild(height: 60),
            ],
          ),
        ),
      );

      final rects = tester
          .widgetList<_FixedChild>(find.byType(_FixedChild))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();

      expect(rects[1].top - rects[0].bottom, Space.sm);
    });

    testWidgets('standard：資料視圖吸收剩餘高', (tester) async {
      await pumpHarness(
        tester,
        child: const SizedBox(
          width: 300,
          height: 300,
          child: Panel(
            children: [
              _FixedChild(height: 50),
              Expanded(child: _FakeDataView()),
            ],
          ),
        ),
      );

      final panelRect = tester.getRect(find.byType(Panel));
      final dataViewRect = tester.getRect(find.byType(_FakeDataView));
      final fixedRect = tester.getRect(find.byType(_FixedChild));

      // 資料視圖高度 = 面板內距後可用高 − 固有子件高 − 間距。
      final expectedDataViewHeight =
          panelRect.height - 2 * Space.md - fixedRect.height - Space.sm;
      expect(dataViewRect.height, closeTo(expectedDataViewHeight, 0.5));
      expectNoOverflow(tester);
    });

    testWidgets('scrollable：子件總高超過可用高時觸發捲動', (tester) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 200,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: List.generate(10, (i) => const _FixedChild(height: 40)),
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expectNoOverflow(tester);
    });

    testWidgets('scrollable：子件總高不足可用高時不觸發捲動', (tester) async {
      final scrollKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          height: 300,
          child: Panel.scrollable(
            scrollKey: scrollKey,
            children: const [_FixedChild(height: 20)],
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expectNoOverflow(tester);
    });
  });

  group('最長測試文案', () {
    testWidgetsAtEachSize('依 §4.0.4 TestCopy 渲染子件文字不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 300,
          height: 200,
          child: Panel(
            children: [
              Text(
                TestCopy.longZh,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
      expectNoOverflow(tester);
    });
  });
}
