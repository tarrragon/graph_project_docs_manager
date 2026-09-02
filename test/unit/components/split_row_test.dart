/// SPEC-004 §4.29 / §5.3 `SplitRow` 測試點。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 模擬 `ButtonRow`（尚未建立）：三個 `AppButton.text` 樣式的簡易按鈕，
/// 驗證 trailing 為多子件容器時的排列（§4.29 測試點第 1 項）。
Widget _fakeButtonRow() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(onPressed: () {}, child: const Text('A')),
      SizedBox(width: Space.xs),
      TextButton(onPressed: () {}, child: const Text('B')),
      SizedBox(width: Space.xs),
      TextButton(onPressed: () {}, child: const Text('C')),
    ],
  );
}

void main() {
  group('SplitRow.header', () {
    testWidgetsAtEachSize('leading + SegmentedControl 型 trailing 不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SplitRow.header(
          leading: const PageTitle(title: 'Domain 視圖'),
          trailing: const AppText('矩陣', variant: AppTextVariant.caption),
        ),
      );
      expect(find.text('Domain 視圖'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('leading + ButtonRow 型 trailing 不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SplitRow.header(
          leading: const PageTitle(title: 'Ticket 清單'),
          trailing: _fakeButtonRow(),
        ),
      );
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('trailing 為空時 leading 仍填滿寬，不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: const SplitRow.header(leading: PageTitle(title: '節點詳情')),
      );
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('最長測試文案 leading 截斷，不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SplitRow.header(
          leading: const AppText(
            TestCopy.longZh,
            variant: AppTextVariant.subtitle,
          ),
          trailing: const AppText('操作', variant: AppTextVariant.caption),
        ),
      );
      expectNoOverflow(tester);
    });

    testWidgets('固定高等於 LayoutSize.headerHeight', (tester) async {
      await pumpHarness(
        tester,
        child: const SplitRow.header(leading: PageTitle(title: '標題')),
      );
      final size = tester.getSize(find.byType(SplitRow));
      expect(size.height, LayoutSize.headerHeight);
    });

    testWidgets('compactHeader 為 true 時不套固定高', (tester) async {
      await pumpHarness(
        tester,
        child: SplitRow.header(
          leading: const AppText('詳情卡標題', variant: AppTextVariant.subtitle),
          compactHeader: true,
        ),
      );
      final size = tester.getSize(find.byType(SplitRow));
      expect(size.height, isNot(LayoutSize.headerHeight));
    });
  });

  group('SplitRow.footer', () {
    testWidgetsAtEachSize('leading + AppText.caption trailing 不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SplitRow.footer(
          leading: const AppText('顯示 1–20 / 共 100', variant: AppTextVariant.body),
          trailing: const AppText('虛擬捲動，不分頁', variant: AppTextVariant.caption),
        ),
      );
      expectNoOverflow(tester);
    });

    testWidgets('固定高等於 LayoutSize.rowHeightRelaxed', (tester) async {
      await pumpHarness(
        tester,
        child: SplitRow.footer(
          leading: const AppText('摘要', variant: AppTextVariant.body),
        ),
      );
      final size = tester.getSize(find.byType(SplitRow));
      expect(size.height, LayoutSize.rowHeightRelaxed);
    });
  });

  group('排列不變式（§5.3）', () {
    testWidgets('不重疊：leading 與 trailing 水平互斥', (tester) async {
      final leadingKey = UniqueKey();
      final trailingKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SplitRow.header(
          leading: SizedBox(key: leadingKey, height: 20, child: const AppText('左')),
          trailing: SizedBox(key: trailingKey, height: 20, child: const AppText('右')),
        ),
      );

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final trailingRect = tester.getRect(find.byKey(trailingKey));
      expect(leadingRect.overlaps(trailingRect), isFalse);
      expect(leadingRect.right, lessThanOrEqualTo(trailingRect.left));
    });

    testWidgets('最小間距：leading 與 trailing 間隔 Space.md', (tester) async {
      final leadingKey = UniqueKey();
      final trailingKey = UniqueKey();
      await pumpHarness(
        tester,
        child: SplitRow.header(
          leading: SizedBox(
            key: leadingKey,
            width: 40,
            height: 20,
            child: const AppText('左'),
          ),
          trailing: SizedBox(
            key: trailingKey,
            height: 20,
            child: const AppText('右'),
          ),
        ),
      );

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final trailingRect = tester.getRect(find.byKey(trailingKey));
      expect(trailingRect.left - leadingRect.right, Space.md);
    });

    testWidgets('空間不足策略：trailing 為 ButtonRow 且 leading 極短時仍不溢位', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        size: WindowSize.min,
        child: SplitRow.header(
          leading: const AppText('短', variant: AppTextVariant.subtitle),
          trailing: _fakeButtonRow(),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('尺寸與顏色 token', () {
    testWidgets('header 底邊框與底色使用 AppColors token', (tester) async {
      await pumpHarness(
        tester,
        child: const SplitRow.header(leading: PageTitle(title: '標題')),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(Row),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfaceBase);
      expect(decoration.border?.bottom.color, AppColors.border);
    });

    testWidgets('footer 頂邊框使用 AppColors.border', (tester) async {
      await pumpHarness(
        tester,
        child: SplitRow.footer(
          leading: const AppText('摘要', variant: AppTextVariant.body),
        ),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(Row),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.border?.top.color, AppColors.border);
    });
  });
}
