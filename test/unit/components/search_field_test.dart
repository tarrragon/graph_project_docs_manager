/// SearchField 元件測試（SPEC-004 4.12）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('search-field-test');

  group('狀態矩陣：empty / filled / focused', () {
    testWidgetsAtEachSize('empty 態渲染搜尋圖示與 placeholder，無清除鈕，不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SearchField(value: '', onChanged: (_) {}, testKey: testKey),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.text('搜尋'), findsOneWidget);

      final box = tester.getSize(find.byKey(testKey));
      expect(box.height, LayoutSize.hitTargetMin);
    });

    testWidgetsAtEachSize('filled 態渲染清除鈕，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SearchField(
          value: 'abc',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      final box = tester.getSize(find.byKey(testKey));
      expect(box.height, LayoutSize.hitTargetMin);
    });

    testWidgets('focused 態邊框改為 accent 色', (tester) async {
      await pumpHarness(
        tester,
        child: SearchField(value: '', onChanged: (_) {}, testKey: testKey),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(testKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.accent);
    });

    testWidgets('未 focused 時邊框為 border 色', (tester) async {
      await pumpHarness(
        tester,
        child: SearchField(value: '', onChanged: (_) {}, testKey: testKey),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(testKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.border);
    });
  });

  group('最長測試文案與雙語系', () {
    testWidgetsAtEachSize('TestCopy.longToken 輸入後無溢位錯誤', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SearchField(value: '', onChanged: (_) {}, testKey: testKey),
      );

      await tester.enterText(find.byType(TextField), TestCopy.longToken);
      await tester.pump();

      expectNoOverflow(tester);
    });

    for (final locale in kTestLocales) {
      testWidgetsAtEachSize('placeholder 於 ${locale.languageCode} 不溢位', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          locale: locale,
          child: SearchField(value: '', onChanged: (_) {}, testKey: testKey),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動反應：防抖動與清除', () {
    testWidgets('輸入後 pump 前 onChanged 零次；pump(searchDebounce) 後恰一次', (
      tester,
    ) async {
      var callCount = 0;
      String? lastValue;
      await pumpHarness(
        tester,
        child: SearchField(
          value: '',
          onChanged: (v) {
            callCount++;
            lastValue = v;
          },
          testKey: testKey,
        ),
      );

      await tester.enterText(find.byType(TextField), 'query');
      await tester.pump();
      expect(callCount, 0);

      await pumpContract(tester, Motion.searchDebounce);
      expect(callCount, 1);
      expect(lastValue, 'query');
    });

    testWidgets('連續輸入只在防抖動結束後呼叫一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SearchField(
          value: '',
          onChanged: (_) => callCount++,
          testKey: testKey,
        ),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'abc');
      await pumpContract(tester, Motion.searchDebounce);

      expect(callCount, 1);
    });

    testWidgets('清除鈕立即呼叫 onChanged("")，不等待防抖動', (tester) async {
      final calls = <String>[];
      await pumpHarness(
        tester,
        child: SearchField(
          value: 'abc',
          onChanged: calls.add,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(calls, ['']);
    });

    testWidgets('刪至空立即呼叫 onChanged("")，不等待防抖動', (tester) async {
      final calls = <String>[];
      await pumpHarness(
        tester,
        child: SearchField(
          value: 'a',
          onChanged: calls.add,
          testKey: testKey,
        ),
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(calls, ['']);
    });
  });

  group('無障礙', () {
    testWidgets('Semantics.textField 有 label 與 value', (tester) async {
      await pumpHarness(
        tester,
        child: SearchField(
          value: 'abc',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final data = tester.getSemantics(find.bySemanticsLabel('搜尋'));
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.value, 'abc');
    });

    testWidgets('清除鈕 Semantics.button 且 label 為 searchClearAction', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SearchField(
          value: 'abc',
          onChanged: (_) {},
          testKey: testKey,
        ),
      );

      final data = tester.getSemantics(find.bySemanticsLabel('清除搜尋'));
      expect(data.flagsCollection.isButton, isTrue);
    });
  });

  group('token 引用', () {
    testWidgets('placeholder 覆寫參數生效', (tester) async {
      await pumpHarness(
        tester,
        child: SearchField(
          value: '',
          onChanged: (_) {},
          testKey: testKey,
          placeholder: '自訂搜尋',
        ),
      );

      expect(find.text('自訂搜尋'), findsOneWidget);
      expect(find.text('搜尋'), findsNothing);
    });
  });
}
