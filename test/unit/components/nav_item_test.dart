/// NavItem 元件測試（SPEC-004 4.7）。
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 側欄六項導覽的 `nav*` key（SPEC-004 4.7 內容政策「最長測試文案」）。
const _navKeys = [
  'navDomain',
  'navUcFlow',
  'navTraceability',
  'navTickets',
  'navGaps',
  'navNodeDetail',
];

/// zh 取值，順序對齊 [_navKeys]。
const _zhNavLabels = [
  'Domain 視圖',
  'UC Flow',
  '追溯視圖',
  'Ticket 清單',
  '破洞報告',
  '節點詳情',
];

/// en 取值，順序對齊 [_navKeys]。
const _enNavLabels = [
  'Domain',
  'UC Flow',
  'Traceability',
  'Tickets',
  'Gaps',
  'Node Detail',
];

void main() {
  const testKey = ValueKey('nav-item-test');

  AppIcon icon() => const AppIcon(icon: Icons.folder_outlined, size: IconSize.lg);

  group('狀態矩陣：unselected / selected', () {
    testWidgetsAtEachSize('unselected 渲染且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: NavItem(
          icon: icon(),
          label: TestCopy.longToken,
          isSelected: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgetsAtEachSize('selected 渲染且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: NavItem(
          icon: icon(),
          label: TestCopy.longToken,
          isSelected: true,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('高不小於 hitTargetMin', (tester) async {
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: 'label',
          isSelected: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final size = tester.getSize(find.byKey(testKey));
      expect(size.height, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
    });

    // hitTargetMin 是命中區下界，不是文字容器高度上界。把它當固定高度用會讓
    // 內容（圖示 iconLg + 內距 2 × Space.sm）被壓進 28 邏輯像素內靜默裁切，
    // 實機上表現為中文字形上下緣被切。上面的「高不小於 hitTargetMin」與所有
    // expectNoOverflow 對此形態皆恆成立，故另立本組（W3-094）。
    testWidgetsAtEachSize('內容不被固定高度裁切（zh 六個 nav key）', (tester, size) async {
      for (final label in _zhNavLabels) {
        await pumpHarness(
          tester,
          size: size,
          locale: const Locale('zh'),
          child: NavItem(
            icon: icon(),
            label: label,
            isSelected: false,
            onTap: () {},
            testKey: testKey,
          ),
        );

        expectNoVerticalClip(
          tester,
          find.descendant(of: find.byKey(testKey), matching: find.byType(Row)),
        );
      }
    });

    testWidgetsAtEachSize('內容不被固定高度裁切（en 六個 nav key）', (tester, size) async {
      for (final label in _enNavLabels) {
        await pumpHarness(
          tester,
          size: size,
          locale: const Locale('en'),
          child: NavItem(
            icon: icon(),
            label: label,
            isSelected: false,
            onTap: () {},
            testKey: testKey,
          ),
        );

        expectNoVerticalClip(
          tester,
          find.descendant(of: find.byKey(testKey), matching: find.byType(Row)),
        );
      }
    });
  });

  group('最長測試文案截斷', () {
    testWidgets('longToken 截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: TestCopy.longToken,
          isSelected: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      final textWidget = tester.widget<Text>(find.text(TestCopy.longToken));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('zh / en 六個 key 不溢位', () {
    const labels = _navKeys;
    const zhValues = _zhNavLabels;
    const enValues = _enNavLabels;

    for (var i = 0; i < labels.length; i++) {
      testWidgets('${labels[i]} zh 不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: const Locale('zh'),
          child: NavItem(
            icon: icon(),
            label: zhValues[i],
            isSelected: false,
            onTap: () {},
            testKey: testKey,
          ),
        );
        expectNoOverflow(tester);
      });

      testWidgets('${labels[i]} en 不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: const Locale('en'),
          child: NavItem(
            icon: icon(),
            label: enValues[i],
            isSelected: false,
            onTap: () {},
            testKey: testKey,
          ),
        );
        expectNoOverflow(tester);
      });
    }
  });

  group('互動與無障礙', () {
    testWidgets('點選呼叫 onTap 恰一次；Semantics.selected 與 isSelected 一致', (
      tester,
    ) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: 'label',
          isSelected: true,
          onTap: () => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      expect(callCount, 1);

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.label, 'label');
    });

    testWidgets('unselected 時 Semantics.selected 為 false', (tester) async {
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: 'label',
          isSelected: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isSelected, isNot(Tristate.isTrue));
    });
  });

  group('token 引用', () {
    testWidgets('selected 底色引用 surfaceIconTint，圖示與字色引用 accentStrong', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: 'label',
          isSelected: true,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(testKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfaceIconTint);

      expect(find.byType(AppText), findsOneWidget);
      final text = tester.widget<Text>(find.text('label'));
      expect(text.style?.color, AppColors.accentStrong);
      expect(text.style?.fontWeight, FontWeight.bold);

      final renderedIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(renderedIcon.color, AppColors.accentStrong);
    });

    testWidgets('unselected 底色為 null，字與圖示引用 textPrimary', (tester) async {
      await pumpHarness(
        tester,
        child: NavItem(
          icon: icon(),
          label: 'label',
          isSelected: false,
          onTap: () {},
          testKey: testKey,
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(testKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, isNull);

      expect(find.byType(AppText), findsOneWidget);
      final text = tester.widget<Text>(find.text('label'));
      expect(text.style?.color, AppColors.textPrimary);
      expect(text.style?.fontWeight, FontWeight.normal);

      final renderedIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(renderedIcon.color, AppColors.textPrimary);
    });
  });
}
