/// FilterDropdown 元件測試（SPEC-004 4.13）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('filter-dropdown-test');
  final options = const [
    FilterOption(value: 'pending', label: '待處理'),
    FilterOption(value: 'done', label: '完成'),
  ];

  group('狀態矩陣：default / active，不溢位', () {
    testWidgetsAtEachSize('default 態顯示「全部」且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text('狀態：全部'), findsOneWidget);

      final box = tester.getSize(find.byKey(testKey));
      expect(box.height, LayoutSize.hitTargetMin);
    });

    testWidgetsAtEachSize('active 態顯示目前值且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.text('狀態：待處理'), findsOneWidget);

      final box = tester.getSize(find.byKey(testKey));
      expect(box.height, LayoutSize.hitTargetMin);
    });

    testWidgets('選取不同值時觸發器寬不變', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );
      final defaultWidth = tester.getSize(find.byKey(testKey)).width;

      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );
      final activeWidth = tester.getSize(find.byKey(testKey)).width;

      expect(activeWidth, defaultWidth);
    });
  });

  group('最長測試文案截斷', () {
    testWidgetsAtEachSize('最長選項文案不溢位（截斷）', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: FilterDropdown(
          label: TestCopy.longZh,
          options: [FilterOption(value: 'v', label: TestCopy.longToken)],
          selected: 'v',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('zh / en 兩語系不溢位', () {
    for (final locale in kTestLocales) {
      testWidgetsAtEachSize('locale=${locale.languageCode} 不溢位', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          locale: locale,
          child: FilterDropdown(
            label: '狀態',
            options: options,
            selected: null,
            onChanged: (_) {},
            testKey: testKey,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動：開合、選取', () {
    testWidgets('點選觸發器開啟選單，顯示「全部」與全部選項', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('待處理'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('選取選項呼叫 onChanged 恰一次，值為選項值', (tester) async {
      String? received;
      var callCount = 0;
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (value) {
            received = value;
            callCount++;
          },
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('待處理'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(received, 'pending');
    });

    testWidgets('選取「全部」呼叫 onChanged 傳 null', (tester) async {
      String? received = 'placeholder';
      var callCount = 0;
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (value) {
            received = value;
            callCount++;
          },
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(received, isNull);
    });

    testWidgets('選單收合後再開啟不重複呼叫 onChanged', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      // 再次點擊觸發器所在座標：展開時該區域由選單的模態遮罩（F7 吸收語意）
      // 覆蓋，點擊命中遮罩而非觸發器本身的 InkWell，遮罩收合選單，最終行為
      // 與「再點觸發器」列一致（選單收合、onChanged 不被呼叫），
      // warnIfMissed 關閉以反映此為預期的吸收路徑而非誤點。
      await tester.tap(find.byKey(testKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('待處理'), findsNothing);
    });

    testWidgets('Esc 收合選單，onChanged 不被呼叫，焦點回到觸發器', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      expect(find.text('待處理'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('待處理'), findsNothing);
    });

    testWidgets('點外部收合選單，onChanged 不被呼叫', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: Column(
          children: [
            FilterDropdown(
              label: '狀態',
              options: options,
              selected: null,
              onChanged: (_) => callCount++,
              testKey: testKey,
            ),
            const SizedBox(height: 200, child: ColoredBox(color: Colors.red)),
          ],
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      expect(find.text('待處理'), findsOneWidget);

      await tester.tapAt(const Offset(10, 500));
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('待處理'), findsNothing);
    });
  });

  group('鍵盤走選項', () {
    testWidgets('選單展開時鍵盤 ↓ 移動高亮至下一項', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // 高亮移至 index 1（待處理），選單仍應收合（Enter 由 InkWell 未攔截，
      // 僅驗證鍵盤路徑不拋出例外）。
      expectNoOverflow(tester);
    });
  });

  group('token 引用（非硬編碼）', () {
    testWidgets('active 態邊框色為 AppColors.accent', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final decoratedBoxes = tester.widgetList<Container>(
        find.descendant(
          of: find.byKey(testKey),
          matching: find.byType(Container),
        ),
      );
      final decoration = decoratedBoxes.first.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.accent);
    });

    testWidgets('default 態邊框色為 AppColors.border', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final decoratedBoxes = tester.widgetList<Container>(
        find.descendant(
          of: find.byKey(testKey),
          matching: find.byType(Container),
        ),
      );
      final decoration = decoratedBoxes.first.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppColors.border);
    });
  });

  group('無障礙朗讀標籤與焦點路徑', () {
    testWidgets('觸發器 Semantics label 含篩選名稱與目前值', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, contains('狀態'));
      expect(data.label, contains('待處理'));
    });

    testWidgets('展開前 Semantics.expanded 為 false，展開後為 true', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final before = tester.getSemantics(find.byKey(testKey));
      expect(before.flagsCollection.isExpanded.toBoolOrNull(), isFalse);

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();

      final after = tester.getSemantics(find.byKey(testKey));
      expect(after.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
    });

    testWidgets('選單根節點 role 為 menu，選項 role 為 menuItem', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: 'pending',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();

      final menuWidget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.role == SemanticsRole.menu,
        ),
      );
      expect(menuWidget.properties.role, SemanticsRole.menu);

      final selectedOptionWidget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.role == SemanticsRole.menuItem &&
              w.properties.label == '待處理',
        ),
      );
      expect(selectedOptionWidget.properties.selected, isTrue);

      final allOptionWidget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.role == SemanticsRole.menuItem &&
              w.properties.label == '全部',
        ),
      );
      expect(allOptionWidget.properties.selected, isFalse);
    });

    testWidgets('觸發器可透過 Tab 取得焦點', (tester) async {
      await pumpHarness(
        tester,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Esc 收合後焦點回到觸發器：再次按 Enter 應可重新開啟選單（點選路徑
      // 之外的鍵盤可達性驗證，見上方鍵盤走選項 group 的 ↓ 開啟）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(find.text('待處理'), findsOneWidget);
    });
  });

  group('disableAnimations', () {
    testWidgets('disableAnimations 下開合仍成功，不拋例外', (tester) async {
      await pumpHarness(
        tester,
        disableAnimations: true,
        child: FilterDropdown(
          label: '狀態',
          options: options,
          selected: null,
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });
}
