/// ExpanderIcon 元件測試（SPEC-004 4.18）。
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('expander-test');

  group('狀態矩陣：collapsed / expanded / leaf', () {
    testWidgetsAtEachSize('collapsed 渲染右箭頭且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: testKey,
          onToggle: () {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    });

    testWidgetsAtEachSize('expanded 渲染下箭頭且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ExpanderIcon(
          isExpanded: true,
          testKey: testKey,
          onToggle: () {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgetsAtEachSize('leaf 不渲染箭頭但保留寬度', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: ExpanderIcon(isExpanded: false, isLeaf: true, testKey: testKey),
      );

      expectNoOverflow(tester);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      final leafBox = tester.getSize(find.byKey(testKey));
      expect(leafBox.width, LayoutSize.hitTargetMin);
      expect(leafBox.height, LayoutSize.hitTargetMin);
    });

    testWidgets('leaf 寬度等於非 leaf 寬度（對齊）', (tester) async {
      await pumpHarness(
        tester,
        child: ExpanderIcon(isExpanded: false, isLeaf: true, testKey: testKey),
      );
      final leafWidth = tester.getSize(find.byKey(testKey)).width;

      const nonLeafKey = ValueKey('expander-non-leaf');
      await pumpHarness(
        tester,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: nonLeafKey,
          onToggle: () {},
        ),
      );
      final nonLeafWidth = tester.getSize(find.byKey(nonLeafKey)).width;

      expect(leafWidth, nonLeafWidth);
    });
  });

  group('互動與無障礙播報', () {
    testWidgets('點選呼叫 onToggle 恰一次；Semantics.expanded 與 isExpanded 一致', (
      tester,
    ) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: testKey,
          onToggle: () => callCount++,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      expect(callCount, 1);

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);
      expect(data.label, contains('展開或收合'));
    });

    testWidgets('expanded=true 時 Semantics.expanded 反映真值', (tester) async {
      await pumpHarness(
        tester,
        child: ExpanderIcon(
          isExpanded: true,
          testKey: testKey,
          onToggle: () {},
        ),
      );

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
    });

    testWidgets('leaf 無語意節點', (tester) async {
      await pumpHarness(
        tester,
        child: ExpanderIcon(isExpanded: false, isLeaf: true, testKey: testKey),
      );

      // leaf 排除於語意樹：以 label 尋找不應命中（ExcludeSemantics 生效）。
      expect(find.bySemanticsLabel('展開或收合'), findsNothing);
    });

    testWidgets('鍵盤 Enter 觸發 onToggle', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: testKey,
          onToggle: () => callCount++,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      callCount = 0; // 重置 tap 造成的計數，本測試只驗鍵盤路徑

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('鍵盤 Space 觸發 onToggle', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: testKey,
          onToggle: () => callCount++,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      callCount = 0;

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(callCount, 1);
    });
  });

  group('disableAnimations', () {
    testWidgets('disableAnimations 下無動畫，渲染仍成功', (tester) async {
      await pumpHarness(
        tester,
        disableAnimations: true,
        child: ExpanderIcon(
          isExpanded: false,
          testKey: testKey,
          onToggle: () {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });
  });
}
