/// NavItem 元件測試（SPEC-004 4.7）。
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide Badge;
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

  AppIcon icon() =>
      const AppIcon(icon: Icons.folder_outlined, size: IconSize.lg);

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

  group('action 變體（SPEC-004 4.7）', () {
    testWidgets('點選呼叫 onTap 恰一次；不設 Semantics.selected', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: NavItem.action(
          icon: icon(),
          label: 'label',
          onTap: () => callCount++,
          testKey: testKey,
        ),
      );

      await tester.tap(find.byKey(testKey));
      await tester.pump();
      expect(callCount, 1);

      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.none);
      expect(data.label, 'label');
    });

    testWidgets('恆呈 unselected：圖示色為 textPrimary，無選中底色', (tester) async {
      await pumpHarness(
        tester,
        child: NavItem.action(
          icon: icon(),
          label: 'label',
          onTap: () {},
          testKey: testKey,
        ),
      );

      final renderedIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(renderedIcon.color, AppColors.textPrimary);
      final selectedBg = find.descendant(
        of: find.byKey(testKey),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color ==
                  AppColors.surfaceIconTint,
        ),
      );
      expect(selectedBg, findsNothing);
    });

    testWidgetsAtEachSize('最長文案不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: NavItem.action(
          icon: icon(),
          label: TestCopy.longToken,
          onTap: () {},
          testKey: testKey,
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('action 變體 badge slot（§4.7）', () {
    const badgeKey = ValueKey('badge-writeLog-failure-count');

    Widget item({int? count, String label = 'label'}) => NavItem.action(
      icon: icon(),
      label: label,
      onTap: () {},
      testKey: testKey,
      badge: count == null
          ? null
          : Badge.count(key: badgeKey, count: count, inline: true),
    );

    testWidgets('badge 為 null：無徽章節點', (tester) async {
      await pumpHarness(tester, child: item());
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('非 null：徽章在 label 之後，間距 Space.sm', (tester) async {
      await pumpHarness(tester, child: item(count: 3));
      final labelRect = tester.getRect(find.byType(AppText));
      final badgeRect = tester.getRect(find.byType(Badge));
      expect(badgeRect.left - labelRect.right, closeTo(Space.sm, 0.5));
    });

    testWidgetsAtEachSize('longToken + 三位數徽章：label 截斷、徽章完整、不溢位、列高不變', (
      tester,
      size,
    ) async {
      await pumpHarness(tester, size: size, child: item());
      final baseHeight = tester.getSize(find.byKey(testKey)).height;
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 200,
          child: item(count: 100, label: TestCopy.longToken),
        ),
      );
      expectNoOverflow(tester);
      expect(tester.getSize(find.byKey(testKey)).height, baseHeight);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('朗讀為 writeLogNavA11yLabel，徽章不另成節點', (tester) async {
      await pumpHarness(tester, child: item(count: 3));
      final data = tester.getSemantics(find.byKey(testKey));
      expect(data.label, 'label，3 筆失敗');
      expect(find.semantics.byLabel('3'), findsNothing);
    });

    testWidgets('en 語系朗讀單複數', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: item(count: 1),
      );
      expect(tester.getSemantics(find.byKey(testKey)).label, 'label, 1 failed');
    });
  });

  group('action 變體 focusNode（§4.7）', () {
    testWidgets('呼叫端傳入的 FocusNode 可 requestFocus 且元件不 dispose', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget item() => NavItem.action(
        icon: icon(),
        label: 'x',
        onTap: () {},
        testKey: testKey,
        focusNode: node,
      );
      await pumpHarness(tester, size: WindowSize.min, child: item());
      node.requestFocus();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      // 元件卸載後節點仍可用（由呼叫端 dispose）。
      expect(() => node.requestFocus(), returnsNormally);
    });
  });
}
