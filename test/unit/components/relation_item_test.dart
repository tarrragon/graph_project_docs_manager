/// [RelationItem] widget test（SPEC-004 §4.19「測試點」）。
///
/// `damaged` 不是本元件的內部變體（外包 `IssueMarker.damagedEdge`，
/// SPEC-004 4.6，尚未建立），故以「default 情境的 onTap」與「damaged
/// 情境的 onTap（外包一個模擬虛線框的 DecoratedBox 佔位）」兩組渲染，
/// 驗證本元件在兩種呼叫端情境下外觀與可點性一致（SPEC-004 4.19
/// 「狀態矩陣」default／damaged 同色，差異僅在外包裝與呼叫端傳入語意）。
library;

import 'package:flutter/material.dart' show InkWell;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _relationKey = ValueKey('card-nodeDetail-relation-DOMAIN-MAP-x');
const _domainKey = ValueKey('action-ucFlow-goto-domain-x');

/// 模擬 `IssueMarker.damagedEdge` 外包（虛線框佔位，本元件不承載損壞視覺）。
Widget _wrapDamaged(Widget child) {
  return DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.error, style: BorderStyle.solid),
    ),
    child: child,
  );
}

void main() {
  group('default / damaged 情境矩陣（外包 IssueMarker 佔位）', () {
    for (final size in WindowSize.values) {
      testWidgets('default（mono）@ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(
            width: 200,
            child: RelationItem(
              id: TestCopy.nodeId,
              onTap: () {},
              testKey: _relationKey,
            ),
          ),
        );

        expectNoOverflow(tester);
      });

      testWidgets('damaged（外包佔位）@ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(
            width: 200,
            child: _wrapDamaged(
              RelationItem(
                id: TestCopy.nodeId,
                onTap: () {},
                testKey: _relationKey,
              ),
            ),
          ),
        );

        expectNoOverflow(tester);
      });

      testWidgets('domain 欄（isMono=false）@ ${size.label} 不溢位', (tester) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(
            width: 200,
            child: RelationItem(
              id: TestCopy.domainName,
              isMono: false,
              onTap: () {},
              testKey: _domainKey,
            ),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('最長測試文案不溢位', () {
    testWidgets('TestCopy.nodeId（最長節點 ID）不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 150,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: () {},
            testKey: _relationKey,
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('TestCopy.longToken（無斷字機會）截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 150,
          child: RelationItem(
            id: TestCopy.longToken,
            onTap: () {},
            testKey: _relationKey,
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('中文資料值（zh 語系）不溢位', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('zh'),
        child: SizedBox(
          width: 150,
          child: RelationItem(
            id: TestCopy.domainName,
            isMono: false,
            onTap: () {},
            testKey: _domainKey,
          ),
        ),
      );

      expectNoOverflow(tester);
    });

    testWidgets('英文資料值（en 語系）不溢位', (tester) async {
      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: SizedBox(
          width: 150,
          child: RelationItem(
            id: TestCopy.domainName,
            isMono: false,
            onTap: () {},
            testKey: _domainKey,
          ),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('點選行為', () {
    testWidgets('點選呼叫 onTap 恰一次；元件樹被 InkWell 包覆', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 200,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: () => callCount++,
            testKey: _relationKey,
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byKey(_relationKey));
      await tester.pump();

      expect(callCount, 1);
    });
  });

  group('顏色、內距、圓角引用 token', () {
    testWidgets('底色為 surfaceChip、內距為 Space.sm、圓角為 Radius.md', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 200,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: () {},
            testKey: _relationKey,
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surfaceChip);
      expect((decoration.borderRadius! as BorderRadius).topLeft.x, Radius.md.r);

      final padding = container.padding! as EdgeInsets;
      expect(padding.left, Space.sm.w);
      expect(padding.top, Space.sm.h);
    });
  });

  group('無障礙', () {
    testWidgets('Semantics.button 為 true，label 為 relationItemA11yLabel', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 200,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: () {},
            testKey: _relationKey,
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byKey(_relationKey));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.label, contains(TestCopy.nodeId));
    });

    testWidgets('祖先鏈存在 decoration 非 null 的 DecoratedBox（焦點裝飾）', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 200,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: () {},
            testKey: _relationKey,
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsWidgets);
      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(decoratedBox.decoration, isNotNull);
    });
  });

  group('isProposed badge（K3）', () {
    Widget itemOf({required bool proposed, String id = 'DOMAIN-MAP-x'}) =>
        SizedBox(
          width: 200,
          child: RelationItem(
            id: id,
            isProposed: proposed,
            onTap: () {},
            testKey: _relationKey,
          ),
        );

    testWidgets('K3-1（E1）：true 有暫定 badge 與朗讀；false 無', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(tester, child: itemOf(proposed: true));
      expect(find.text('暫定'), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.tone, BadgeTone.warning);
      expect(badge.variant, BadgeVariant.category);
      expect(
        find.bySemanticsLabel('關聯節點 DOMAIN-MAP-x，暫定邊，形狀可能變動'),
        findsOneWidget,
      );

      await pumpHarness(tester, child: itemOf(proposed: false));
      expect(find.byType(Badge), findsNothing);
      expect(find.text('暫定'), findsNothing);
      expect(find.bySemanticsLabel('關聯節點 DOMAIN-MAP-x'), findsOneWidget);

      await pumpHarness(
        tester,
        locale: const Locale('en'),
        child: itemOf(proposed: true),
      );
      expect(find.text('Proposed'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('K3-2：長 id 截斷時 badge 不截斷不換行、不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: itemOf(proposed: true, id: TestCopy.longToken),
      );
      expectNoOverflow(tester);
      expect(find.text('暫定'), findsOneWidget);
      expect(tester.getSize(find.text('暫定')).height, lessThan(30));
      final idText = tester.widget<Text>(find.text(TestCopy.longToken));
      final idSize = tester.getSize(find.text(TestCopy.longToken));
      final painter = TextPainter(
        text: TextSpan(text: TestCopy.longToken, style: idText.style),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(idSize.width, lessThan(painter.width), reason: 'id 被截斷');
      final badgeWidth = tester.getSize(find.byType(Badge)).width;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '暫定',
          style: tester.widget<Text>(find.text('暫定')).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(badgeWidth, greaterThanOrEqualTo(labelPainter.width));
      expect(
        tester.getSize(find.text('暫定')).width,
        closeTo(labelPainter.width, 0.5),
        reason: 'badge 文字未被壓縮',
      );
    });

    testWidgets('K3-3：badge 併入 chip 標籤，不另朗讀', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(tester, child: itemOf(proposed: true));
      expect(find.bySemanticsLabel('暫定'), findsNothing);
      handle.dispose();
    });
  });

  group('isProposed 最小寬（SPEC-004 4.19 尺寸契約）', () {
    Widget itemAt({required double width, required bool proposed}) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: RelationItem(
          id: TestCopy.longToken,
          isProposed: proposed,
          onTap: () {},
          testKey: _relationKey,
        ),
      ),
    );

    // 一字元加省略號的 id slot 固有寬（字級取 id slot 實際樣式）。
    double oneCharWithEllipsisWidth(WidgetTester tester) {
      final style = tester.widget<Text>(find.text(TestCopy.longToken)).style;
      final painter = TextPainter(
        text: TextSpan(text: '${TestCopy.longToken[0]}…', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    testWidgets('true 最小寬 id 剩一字元加省略號、badge 為固有寬；E1 false 不含 badge', (
      tester,
    ) async {
      await pumpHarness(tester, child: itemAt(width: 600, proposed: true));
      final badgeIntrinsic = tester.getSize(find.byType(Badge)).width;
      final idMin = oneCharWithEllipsisWidth(tester);
      final minTrue = idMin + Space.sm.w + badgeIntrinsic + 2 * Space.sm.w;

      await pumpHarness(tester, child: itemAt(width: minTrue, proposed: true));
      expectNoOverflow(tester);
      expect(
        tester.getSize(find.byType(Badge)).width,
        closeTo(badgeIntrinsic, 0.5),
      );
      expect(find.text('暫定'), findsOneWidget);
      expect(
        tester.getSize(find.text(TestCopy.longToken)).width,
        closeTo(idMin, 0.5),
        reason: 'id 只剩一字元加省略號',
      );

      await pumpHarness(tester, child: itemAt(width: 600, proposed: false));
      expect(find.byType(Badge), findsNothing);
      final minFalse = idMin + 2 * Space.sm.w;
      await pumpHarness(
        tester,
        child: itemAt(width: minFalse, proposed: false),
      );
      expectNoOverflow(tester);
      expect(find.byType(Badge), findsNothing);
      expect(
        tester.getSize(find.text(TestCopy.longToken)).width,
        closeTo(idMin, 0.5),
      );
      expect(minTrue - minFalse, closeTo(Space.sm.w + badgeIntrinsic, 0.5));
    });
  });

  group('語意 tap action（輔助技術可觸發）', () {
    Future<void> pumpItem(WidgetTester tester, VoidCallback? onTap) {
      return pumpHarness(
        tester,
        size: WindowSize.values.first,
        child: SizedBox(
          width: 200,
          child: RelationItem(
            id: TestCopy.nodeId,
            onTap: onTap,
            testKey: _relationKey,
          ),
        ),
      );
    }

    testWidgets('有 onTap 帶 tap action，無 onTap 不帶', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpItem(tester, () {});
      final withTap = tester.getSemantics(find.byKey(_relationKey));
      expect(withTap.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await pumpItem(tester, null);
      final noTap = tester.getSemantics(find.byKey(_relationKey));
      expect(noTap.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('語意 tap 呼叫 onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpItem(tester, () => taps++);
      final node = tester.getSemantics(find.byKey(_relationKey));
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
      expect(taps, 1);
      handle.dispose();
    });
  });
}
