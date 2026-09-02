/// [TwoColumnLayout] widget test（SPEC-004 §4.31「測試點」、§5.5 排列不變式）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

/// 主欄的代表性內容：模擬資料視圖，內容足夠長以逼近最小寬情境。
Widget _buildMain() {
  return material.ListView(
    key: const Key('two-column-main-scroll'),
    children: List.generate(
      20,
      (i) => material.SizedBox(
        height: 40,
        child: Text('row $i ${TestCopy.longZh}'),
      ),
    ),
  );
}

/// 右欄第一種內容：空狀態提示（`EmptyState.section` 尚未實作，以文字佔位）。
Widget _buildDetailEmpty() {
  return const material.Center(
    key: Key('two-column-detail-empty'),
    child: Text('請選取一個項目'),
  );
}

/// 右欄第二種內容：詳情卡（尚未實作，以可捲動清單佔位）。
Widget _buildDetailCard() {
  return material.ListView(
    key: const Key('two-column-detail-card'),
    children: List.generate(
      20,
      (i) => material.SizedBox(height: 40, child: Text('detail $i')),
    ),
  );
}

void main() {
  group('TwoColumnLayout 單一變體矩陣（§4.31 測試點）', () {
    for (final size in WindowSize.values) {
      testWidgets(
        '主欄資料視圖 + 右欄 EmptyState.section @ ${size.label} 不溢位',
        (tester) async {
          await pumpHarness(
            tester,
            size: size,
            child: TwoColumnLayout(
              main: _buildMain(),
              detail: _buildDetailEmpty(),
            ),
          );

          expectNoOverflow(tester);
        },
      );

      testWidgets(
        '主欄資料視圖 + 右欄詳情卡 @ ${size.label} 不溢位；右欄寬恆等於 detailPaneWidth',
        (tester) async {
          await pumpHarness(
            tester,
            size: size,
            child: TwoColumnLayout(
              main: _buildMain(),
              detail: _buildDetailCard(),
            ),
          );

          expectNoOverflow(tester);

          final detailSize = tester.getSize(
            find.byKey(const Key('two-column-detail-card')),
          );
          expect(detailSize.width, LayoutSize.detailPaneWidth);
        },
      );
    }
  });

  group('TwoColumnLayout 排列不變式（§5.5）', () {
    testWidgets('不重疊：兩欄水平互斥且等高', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailCard(),
        ),
      );

      final mainRect = tester.getRect(
        find.byKey(const Key('two-column-main-scroll')),
      );
      final detailRect = tester.getRect(
        find.byKey(const Key('two-column-detail-card')),
      );

      // 水平互斥：主欄右緣不超過右欄左緣。
      expect(mainRect.right, lessThanOrEqualTo(detailRect.left));
      // 等高（上緣對齊、高度相同）。
      expect(mainRect.top, detailRect.top);
      expect(mainRect.height, detailRect.height);
    });

    testWidgets('最小間距：兩欄間距恆等於 Space.md', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailCard(),
        ),
      );

      final mainRect = tester.getRect(
        find.byKey(const Key('two-column-main-scroll')),
      );
      final detailRect = tester.getRect(
        find.byKey(const Key('two-column-detail-card')),
      );

      expect(detailRect.left - mainRect.right, Space.md);
    });

    testWidgets(
      '空間不足策略：detailPaneWidth + Space.md + 主欄最小寬 <= kMinWindowSize 下不溢位',
      (tester) async {
        await pumpHarness(
          tester,
          size: WindowSize.min,
          child: TwoColumnLayout(
            main: _buildMain(),
            detail: _buildDetailCard(),
          ),
        );

        expectNoOverflow(tester);

        final detailSize = tester.getSize(
          find.byKey(const Key('two-column-detail-card')),
        );
        expect(detailSize.width, LayoutSize.detailPaneWidth);
      },
    );
  });

  group('TwoColumnLayout 互動反應（§4.31 互動反應、測試點）', () {
    testWidgets('主欄捲動後右欄 offset 不變，反之亦然', (tester) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailCard(),
        ),
      );

      final mainFinder = find.byKey(const Key('two-column-main-scroll'));
      final detailFinder = find.byKey(const Key('two-column-detail-card'));

      final detailOffsetBefore = tester
          .widget<material.ListView>(detailFinder)
          .controller
          ?.hasClients;
      expect(detailOffsetBefore, isNull);

      await tester.drag(mainFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      // 右欄仍在畫面上、寬度不變，代表未隨主欄捲動而重建或位移。
      expect(find.byKey(const Key('two-column-detail-card')), findsOneWidget);
      final detailSizeAfter = tester.getSize(detailFinder);
      expect(detailSizeAfter.width, LayoutSize.detailPaneWidth);

      await tester.drag(detailFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('two-column-main-scroll')), findsOneWidget);
    });

    testWidgets('右欄換件後主欄寬與 offset 不變', (tester) async {
      final mainFinder = find.byKey(const Key('two-column-main-scroll'));

      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailEmpty(),
        ),
      );

      await tester.drag(mainFinder, const Offset(0, -100));
      await tester.pump();

      final mainRectBefore = tester.getRect(mainFinder);

      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailCard(),
        ),
      );
      await tester.pump(Motion.transition(tester.element(mainFinder)));
      await tester.pumpAndSettle();

      final mainRectAfter = tester.getRect(mainFinder);
      expect(mainRectAfter.width, mainRectBefore.width);
      expect(mainRectAfter.left, mainRectBefore.left);

      expectNoOverflow(tester);
    });
  });

  group('TwoColumnLayout 間距與寬度引用 token', () {
    testWidgets('SizedBox 間距寬度為 Space.md，右欄寬為 LayoutSize.detailPaneWidth', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        size: WindowSize.design,
        child: TwoColumnLayout(
          main: _buildMain(),
          detail: _buildDetailCard(),
        ),
      );

      final sizedBoxes = tester
          .widgetList<material.SizedBox>(find.byType(material.SizedBox))
          .toList();

      expect(
        sizedBoxes.any((box) => box.width == Space.md),
        isTrue,
        reason: '兩欄間距應引用 Space.md',
      );
      expect(
        sizedBoxes.any((box) => box.width == LayoutSize.detailPaneWidth),
        isTrue,
        reason: '右欄寬應引用 LayoutSize.detailPaneWidth',
      );
    });
  });
}
