/// [ListRow] widget test（SPEC-004 §4.40「測試點」、§5.14 排列不變式）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _treeKey = ValueKey('card-traceability-DOMAIN-MAP-version-management');
const _itemKey = ValueKey('card-gaps-item-1');

/// 建構每個變體的一個代表性實例，供「五變體 × trailing 有無」矩陣展開。
/// `withTrailing` 只影響有 trailing 的變體；leading 依契約固定必填
/// （`item` 恆無 leading）。
ListRow _buildVariant(ListRowVariant variant, {required bool withTrailing}) {
  return switch (variant) {
    ListRowVariant.tree => ListRow.tree(
        leading: const ExpanderIcon(
          isExpanded: false,
          testKey: ValueKey('tree-expander'),
        ),
        primary: AppText(TestCopy.nodeTitle, emphasis: true),
        trailing: withTrailing ? const Badge.status(label: 'completed') : null,
        onTap: () {},
        testKey: _treeKey,
      ),
    ListRowVariant.sectionHeader => ListRow.sectionHeader(
        leading: const ExpanderIcon(
          isExpanded: true,
          testKey: ValueKey('section-expander'),
        ),
        primary: AppText(TestCopy.topicName),
        trailing: withTrailing
            ? const AppText('12 items', variant: AppTextVariant.caption)
            : null,
      ),
    ListRowVariant.item => ListRow.item(
        primary: AppText(TestCopy.gapTitle),
        secondary: AppText(TestCopy.gapDescription, variant: AppTextVariant.caption),
        trailing: withTrailing
            ? const AppIcon(icon: material.Icons.open_in_new)
            : null,
        onTap: () {},
        testKey: _itemKey,
      ),
    ListRowVariant.meta => ListRow.meta(
        leading: const Badge.type(label: 'PROP'),
        primary: AppText(TestCopy.filePath, variant: AppTextVariant.mono),
      ),
    ListRowVariant.numbered => ListRow.numbered(
        leading: const SizedBox(width: 24, height: 24),
        primary: AppText(TestCopy.stepName),
      ),
  };
}

void main() {
  group('五變體 × trailing 有無矩陣', () {
    for (final size in WindowSize.values) {
      for (final variant in ListRowVariant.values) {
        for (final withTrailing in [false, true]) {
          testWidgets(
            '${variant.name} / trailing=$withTrailing @ ${size.label} 不溢位',
            (tester) async {
              await pumpHarness(
                tester,
                size: size,
                child: SizedBox(
                  width: 300,
                  child: _buildVariant(variant, withTrailing: withTrailing),
                ),
              );

              expectNoOverflow(tester);
            },
          );
        }
      }
    }
  });

  group('最長測試文案不溢位', () {
    for (final variant in ListRowVariant.values) {
      testWidgets('${variant.name} 以最長測試文案渲染不溢位', (tester) async {
        await pumpHarness(
          tester,
          child: SizedBox(
            width: 300,
            child: _buildVariant(variant, withTrailing: true),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('點選行為（tree / item）', () {
    testWidgets('tree 列點選呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.tree(
            leading: const ExpanderIcon(
              isExpanded: false,
              testKey: ValueKey('tree-expander-tap'),
              onToggle: null,
            ),
            primary: AppText(TestCopy.nodeTitle),
            onTap: () => callCount++,
            testKey: _treeKey,
          ),
        ),
      );

      await tester.tap(find.byKey(_treeKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('item 列點選呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.item(
            primary: AppText(TestCopy.gapTitle),
            secondary: AppText(
              TestCopy.gapDescription,
              variant: AppTextVariant.caption,
            ),
            onTap: () => callCount++,
            testKey: _itemKey,
          ),
        ),
      );

      await tester.tap(find.byKey(_itemKey));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('點 leading 展開器不觸發列 onTap', (tester) async {
      var rowTapCount = 0;
      var expanderToggleCount = 0;
      const expanderKey = ValueKey('tree-expander-nested');

      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.tree(
            leading: ExpanderIcon(
              isExpanded: false,
              testKey: expanderKey,
              onToggle: () => expanderToggleCount++,
            ),
            primary: AppText(TestCopy.nodeTitle),
            onTap: () => rowTapCount++,
            testKey: _treeKey,
          ),
        ),
      );

      await tester.tap(find.byKey(expanderKey));
      await tester.pump();

      expect(expanderToggleCount, 1);
      expect(rowTapCount, 0);
    });
  });

  group('排列不變式（SPEC-004 §5.14）', () {
    testWidgets('不重疊：leading / 文字塊 / trailing 兩兩邊界盒不相交', (tester) async {
      const leadingKey = ValueKey('row-leading');
      const trailingKey = ValueKey('row-trailing');
      const primaryKey = ValueKey('row-primary');

      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.tree(
            leading: const SizedBox(
              key: leadingKey,
              width: 24,
              height: 24,
            ),
            primary: const AppText(
              key: primaryKey,
              'primary text',
            ),
            trailing: const SizedBox(key: trailingKey, width: 24, height: 24),
            onTap: () {},
            testKey: _treeKey,
          ),
        ),
      );

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final primaryRect = tester.getRect(find.byKey(primaryKey));
      final trailingRect = tester.getRect(find.byKey(trailingKey));

      expect(leadingRect.overlaps(primaryRect), isFalse);
      expect(primaryRect.overlaps(trailingRect), isFalse);
      expect(leadingRect.overlaps(trailingRect), isFalse);
      expect(leadingRect.right, lessThanOrEqualTo(primaryRect.left));
      expect(primaryRect.right, lessThanOrEqualTo(trailingRect.left));
    });

    testWidgets('最小間距：leading／trailing 與文字塊間距為 Space.sm', (tester) async {
      const leadingKey = ValueKey('row-leading-gap');
      const trailingKey = ValueKey('row-trailing-gap');
      const primaryKey = ValueKey('row-primary-gap');

      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.tree(
            leading: const SizedBox(key: leadingKey, width: 24, height: 24),
            primary: const AppText(key: primaryKey, 'p'),
            trailing: const SizedBox(key: trailingKey, width: 24, height: 24),
            onTap: () {},
            testKey: _treeKey,
          ),
        ),
      );

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final primaryRect = tester.getRect(find.byKey(primaryKey));
      final trailingRect = tester.getRect(find.byKey(trailingKey));

      expect(primaryRect.left - leadingRect.right, Space.sm.w);
      expect(trailingRect.left - primaryRect.right, Space.sm.w);
    });

    testWidgets('空間不足策略：leading + trailing + 最小主文字寬在最小視窗下不觸發溢位', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: SizedBox(
          width: 200,
          child: ListRow.tree(
            leading: const SizedBox(width: 24, height: 24),
            primary: AppText(TestCopy.longToken),
            trailing: const SizedBox(width: 24, height: 24),
            onTap: () {},
            testKey: _treeKey,
          ),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('尺寸與顏色引用 token', () {
    testWidgets('tree / sectionHeader / meta / numbered 高為 rowHeightDense', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.meta(
            leading: const Badge.type(label: 'PROP'),
            primary: const AppText('a', variant: AppTextVariant.mono),
          ),
        ),
      );

      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
        (box) => box.height == LayoutSize.rowHeightDense.h,
      );
      expect(sizedBox.height, LayoutSize.rowHeightDense.h);
    });

    testWidgets('item 上緣邊框色為 AppColors.border', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.item(
            primary: AppText(TestCopy.gapTitle),
            secondary: AppText(
              TestCopy.gapDescription,
              variant: AppTextVariant.caption,
            ),
            onTap: () {},
            testKey: _itemKey,
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.border!.top.color, AppColors.border);
    });

    testWidgets('sectionHeader 主文字色為 accentStrong', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.sectionHeader(
            leading: const ExpanderIcon(
              isExpanded: true,
              testKey: ValueKey('section-color-expander'),
            ),
            primary: AppText(TestCopy.topicName),
          ),
        ),
      );

      final textWidget = tester.widget<material.Text>(
        find.text(TestCopy.topicName),
      );
      expect(textWidget.style?.color, AppColors.accentStrong);
    });
  });

  group('無障礙', () {
    testWidgets('sectionHeader 為 Semantics.header', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.sectionHeader(
            leading: const ExpanderIcon(
              isExpanded: true,
              testKey: ValueKey('section-a11y-expander'),
            ),
            primary: AppText(TestCopy.topicName),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.text(TestCopy.topicName));
      expect(semantics.flagsCollection.isHeader, isTrue);
    });

    testWidgets('tree 列為 Semantics.button', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 300,
          child: ListRow.tree(
            leading: const ExpanderIcon(
              isExpanded: false,
              testKey: ValueKey('tree-a11y-expander'),
              onToggle: null,
            ),
            primary: AppText(TestCopy.nodeTitle),
            onTap: () {},
            testKey: _treeKey,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byKey(_treeKey));
      expect(semantics.flagsCollection.isButton, isTrue);
    });
  });
}
