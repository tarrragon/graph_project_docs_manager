/// [RelationItem] widget test（SPEC-004 §4.19「測試點」）。
///
/// `damaged` 不是本元件的內部變體（外包 `IssueMarker.damagedEdge`，
/// SPEC-004 4.6，尚未建立），故以「default 情境的 onTap」與「damaged
/// 情境的 onTap（外包一個模擬虛線框的 DecoratedBox 佔位）」兩組渲染，
/// 驗證本元件在兩種呼叫端情境下外觀與可點性一致（SPEC-004 4.19
/// 「狀態矩陣」default／damaged 同色，差異僅在外包裝與呼叫端傳入語意）。
library;

import 'package:flutter/material.dart' show InkWell;
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

      testWidgets('domain 欄（isMono=false）@ ${size.label} 不溢位', (
        tester,
      ) async {
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
    testWidgets('底色為 surfaceChip、內距為 Space.sm、圓角為 Radius.md', (
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

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surfaceChip);
      expect(
        (decoration.borderRadius! as BorderRadius).topLeft.x,
        Radius.md.r,
      );

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

    testWidgets('祖先鏈存在 decoration 非 null 的 DecoratedBox（焦點裝飾）', (
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

      expect(find.byType(DecoratedBox), findsWidgets);
      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(decoratedBox.decoration, isNotNull);
    });
  });
}
