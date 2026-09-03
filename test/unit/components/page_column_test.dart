/// SPEC-004 §4.28 / §5.2 `PageColumn` 測試點。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/layout.dart';
import 'package:graph_project_docs_manager/tokens/spacing.dart';

import '../../helpers/helpers.dart';

/// 8 種內容 slot 型別的佔位 widget（§4.28 slot 契約；實際型別尚未實作，
/// 以具名佔位件模擬各型別一次渲染）。
const _kContentSlotKinds = [
  'panel',
  'panelScrollable',
  'twoColumnLayout',
  'emptyStatePage',
  'blockedState',
  'loadingState',
  'loadPrompt',
  'missingSourceState',
];

Widget _placeholderContent(String kind, {double? height}) {
  return SizedBox(
    key: ValueKey('content-$kind'),
    width: double.infinity,
    height: height ?? double.infinity,
    child: const ColoredBox(color: Color(0xFFFFFFFF)),
  );
}

SplitRow _placeholderHeader() => const SplitRow.header(
  key: ValueKey('header'),
  leading: PageTitle(title: 'placeholder'),
);

void main() {
  group('PageColumn', () {
    for (final kind in _kContentSlotKinds) {
      testWidgetsAtEachSize('內容 slot=$kind 渲染，不溢位', (tester, size) async {
        await pumpHarness(
          tester,
          size: size,
          child: PageColumn(
            semanticLabel: 'Domain 視圖',
            header: _placeholderHeader(),
            content: _placeholderContent(kind),
          ),
        );
        expect(find.byKey(ValueKey('content-$kind')), findsOneWidget);
        expectNoOverflow(tester);
      });
    }

    testWidgetsAtEachSize('內容 slot 高等於本容器高 − 頁首高 − 2 × Space.xl', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: PageColumn(
          semanticLabel: 'Ticket 清單',
          header: _placeholderHeader(),
          content: _placeholderContent('panel'),
        ),
      );
      expectNoOverflow(tester);

      final pageColumnSize = tester.getSize(find.byType(PageColumn));
      final contentSize = tester.getSize(
        find.byKey(const ValueKey('content-panel')),
      );

      expect(
        contentSize.height,
        moreOrLessEquals(
          pageColumnSize.height - LayoutSize.headerHeight - 2 * Space.xl,
        ),
      );
    });

    testWidgetsAtEachSize('頁首與內容不重疊，間距為 Space.xl', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: PageColumn(
          semanticLabel: 'Domain 視圖',
          header: _placeholderHeader(),
          content: _placeholderContent('panel'),
        ),
      );
      expectNoOverflow(tester);

      final headerRect = tester.getRect(
        find.byKey(const ValueKey('header')),
      );
      final contentRect = tester.getRect(
        find.byKey(const ValueKey('content-panel')),
      );

      // 不重疊：內容區頂端不早於頁首底端。
      expect(contentRect.top, greaterThanOrEqualTo(headerRect.bottom));
      // 最小間距：頁首底端到內容頂端恰為 Space.xl（內容區內距）。
      expect(contentRect.top - headerRect.bottom, moreOrLessEquals(Space.xl));
    });

    testWidgetsAtEachSize('空間不足策略不觸發：最小內容高度下不溢位', (tester, size) async {
      // Panel 最小高（§5.2）＝ 2 × Space.md + LayoutSize.rowHeightRelaxed。
      const panelMinHeight = 2 * Space.md + LayoutSize.rowHeightRelaxed;
      await pumpHarness(
        tester,
        size: size,
        child: PageColumn(
          semanticLabel: 'Domain 視圖',
          header: _placeholderHeader(),
          content: _placeholderContent('panel', height: panelMinHeight),
        ),
      );
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('disableAnimations 時內容換件一幀抵達', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        disableAnimations: true,
        settle: false,
        child: PageColumn(
          semanticLabel: 'Domain 視圖',
          header: _placeholderHeader(),
          content: _placeholderContent('panel'),
        ),
      );
      expect(find.byKey(const ValueKey('content-panel')), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('間距使用 Space.xl token（非硬編碼）', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: PageColumn(
          semanticLabel: 'Domain 視圖',
          header: _placeholderHeader(),
          content: _placeholderContent('panel'),
        ),
      );
      expectNoOverflow(tester);

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(PageColumn),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, EdgeInsets.all(Space.xl));
    });

    testWidgetsAtEachSize('朗讀標籤為呼叫端傳入的頁名', (tester, size) async {
      final semanticsHandle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        size: size,
        child: PageColumn(
          semanticLabel: 'Domain 視圖',
          header: _placeholderHeader(),
          content: _placeholderContent('panel'),
        ),
      );
      expectNoOverflow(tester);

      // 頁首 slot 收窄為 SplitRow 後，其子文字語意會與本容器的
      // Semantics(container: true) 合併為單一節點（label 以換行相接），
      // 故用 contains 而非精確相等比對頁名是否出現。
      expect(find.bySemanticsLabel(RegExp('Domain 視圖')), findsOneWidget);
      semanticsHandle.dispose();
    });
  });
}
