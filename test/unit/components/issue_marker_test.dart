/// IssueMarker 元件測試（SPEC-004 4.6）。
library;

import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const damagedEdgeKey = ValueKey('issue-marker-damaged-edge-test');
  const damagedDetailKey = ValueKey('issue-marker-damaged-detail-test');
  const gapKey = ValueKey('issue-marker-gap-test');

  group('三變體渲染', () {
    testWidgetsAtEachSize('damagedEdge 渲染 child 且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: IssueMarker.damagedEdge(
          testKey: damagedEdgeKey,
          onTap: () {},
          child: const Text('relation-item'),
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(damagedEdgeKey), findsOneWidget);
      expect(find.text('relation-item'), findsOneWidget);
    });

    testWidgetsAtEachSize('damagedDetail 計數形態不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () {},
          count: 2419,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(damagedDetailKey), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgetsAtEachSize('damagedDetail 說明形態不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () {},
          explanation: TestCopy.longEn,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(damagedDetailKey), findsOneWidget);
    });

    testWidgetsAtEachSize('damagedDetail 純圖示形態不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: IssueMarker.damagedDetail(testKey: damagedDetailKey, onTap: () {}),
      );

      expectNoOverflow(tester);
      expect(find.byKey(damagedDetailKey), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgetsAtEachSize('gap 渲染 gapMarkerLabel 且不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
      );

      expectNoOverflow(tester);
      expect(find.byKey(gapKey), findsOneWidget);
      expect(find.text('缺口'), findsOneWidget);
    });
  });

  group('最長測試文案', () {
    testWidgets('gap 文字截斷不溢位（longToken）', (tester) async {
      // gap 的可見文字固定為 gapMarkerLabel，不接受呼叫端文字；
      // 改以 damagedDetail 的 explanation slot 驗證最長文案截斷。
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () {},
          explanation: TestCopy.longToken,
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('explanation 截斷不溢位（longZh）', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () {},
          explanation: TestCopy.longZh,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('zh / en 兩語系', () {
    for (final locale in kTestLocales) {
      testWidgets('locale=$locale 下 gap 不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動與命中區', () {
    testWidgets('點擊 damagedEdge 呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: IssueMarker.damagedEdge(
          testKey: damagedEdgeKey,
          onTap: () => callCount++,
          child: const Text('relation-item'),
        ),
      );

      await tester.tap(find.byKey(damagedEdgeKey));
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('點擊 damagedDetail 呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () => callCount++,
          count: 3,
        ),
      );

      await tester.tap(find.byKey(damagedDetailKey));
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('點擊 gap 呼叫 onTap 恰一次', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: IssueMarker.gap(testKey: gapKey, onTap: () => callCount++),
      );

      await tester.tap(find.byKey(gapKey));
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('元件樹被 InkWell 包覆', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
      );

      expect(find.byType(material.InkWell), findsOneWidget);
    });

    testWidgets('damagedDetail 純圖示形態命中區不小於 hitTargetMin', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(testKey: damagedDetailKey, onTap: () {}),
      );

      final box = tester.getSize(find.byKey(damagedDetailKey));
      expect(box.width, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
      expect(box.height, greaterThanOrEqualTo(LayoutSize.hitTargetMin));
    });
  });

  group('靜態顯示：無入場動畫', () {
    testWidgets('渲染後 pump(Motion.feedback) 期間外觀不變', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
      );
      final before = tester.getSize(find.byKey(gapKey));

      await pumpContract(tester, Motion.feedback);

      final after = tester.getSize(find.byKey(gapKey));
      expect(after, before);
    });
  });

  group('無障礙', () {
    testWidgets('damagedEdge：Semantics.button 為 true，label 含 damagedEdgeMarkerLabel', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: IssueMarker.damagedEdge(
          testKey: damagedEdgeKey,
          onTap: () {},
          child: const Text('relation-item'),
        ),
      );

      final data = tester.getSemantics(find.byKey(damagedEdgeKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, contains('邊損壞'));
    });

    testWidgets('damagedDetail：label 含 damagedDetailMarkerLabel 與計數', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(
          testKey: damagedDetailKey,
          onTap: () {},
          count: 2419,
        ),
      );

      final data = tester.getSemantics(find.byKey(damagedDetailKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, contains('詳情損壞'));
      expect(data.label, contains('2419'));
    });

    testWidgets('damagedDetail 純圖示形態：label 只含 damagedDetailMarkerLabel', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: IssueMarker.damagedDetail(testKey: damagedDetailKey, onTap: () {}),
      );

      final data = tester.getSemantics(find.byKey(damagedDetailKey));
      expect(data.label, '詳情損壞');
    });

    testWidgets('gap：label 為 gapMarkerLabel', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
      );

      final data = tester.getSemantics(find.byKey(gapKey));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, '缺口');
    });
  });

  group('顏色引用 token', () {
    testWidgets('gap 文字色使用 AppColors.error', (tester) async {
      await pumpHarness(
        tester,
        child: IssueMarker.gap(testKey: gapKey, onTap: () {}),
      );

      final textWidget = tester.widget<Text>(
        find.descendant(of: find.byKey(gapKey), matching: find.byType(Text)),
      );
      expect(textWidget.style?.color, AppColors.error);
    });
  });
}
