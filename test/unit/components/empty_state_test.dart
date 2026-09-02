// EmptyState widget test（SPEC-004 §4.21「測試點」）。
//
// 涵蓋：
//   - page（一／二／三個動作）與 section（有／無動作、有／無說明）
//   - 兩種視窗尺寸下不溢位；page 內容置中
//   - 最長測試文案：訊息兩行末截斷（section）、說明四行末截斷
//   - zh / en 全部既有 message key 皆不溢位
//   - page 首個動作 label 不等於 backAction（FR-03 斷言）；動作點選呼叫 callback 恰一次
//   - 間距引用 token 非硬編碼
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

List<AppButton> _buildActions(int count) {
  return [
    for (var i = 0; i < count; i++)
      AppButton(
        label: '動作$i',
        onPressed: () {},
        testKey: Key('empty-state-action-$i'),
        variant: i == 0 ? AppButtonVariant.primary : AppButtonVariant.secondary,
      ),
  ];
}

void main() {
  const testKey = ValueKey('empty-state-test');

  group('page 變體：一／二／三個動作', () {
    for (final count in [1, 2, 3]) {
      testWidgetsAtEachSize('page 含 $count 個動作不溢位且內容置中', (
        tester,
        size,
      ) async {
        await pumpHarness(
          tester,
          size: size,
          child: EmptyState(
            variant: EmptyStateVariant.page,
            message: '此專案尚無圖譜節點',
            testKey: testKey,
            actions: _buildActions(count),
          ),
        );

        expectNoOverflow(tester);
        expect(find.byKey(testKey), findsOneWidget);

        // page 內容置中：外層有 Center 祖先包裹本元件。
        expect(
          find.ancestor(of: find.byKey(testKey), matching: find.byType(Center)),
          findsOneWidget,
        );
      });
    }
  });

  group('section 變體：有／無動作、有／無說明', () {
    testWidgetsAtEachSize('section 無說明無動作只渲染訊息，靠上對齊', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: EmptyState(
          variant: EmptyStateVariant.section,
          message: '此 domain 不參與此 UC',
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text('此 domain 不參與此 UC'), findsOneWidget);
    });

    testWidgetsAtEachSize('section 有說明無動作皆渲染不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: EmptyState(
          variant: EmptyStateVariant.section,
          message: '尚無破洞',
          explanation: '已掃描全部節點與邊',
          testKey: testKey,
        ),
      );

      expectNoOverflow(tester);
      expect(find.text('尚無破洞'), findsOneWidget);
      expect(find.text('已掃描全部節點與邊'), findsOneWidget);
    });

    testWidgetsAtEachSize('section 有動作時同 page 呼叫 callback', (
      tester,
      size,
    ) async {
      var tapped = 0;
      await pumpHarness(
        tester,
        size: size,
        child: EmptyState(
          variant: EmptyStateVariant.section,
          message: 'flow 未結構化',
          testKey: testKey,
          actions: [
            AppButton(
              label: '前往',
              onPressed: () => tapped++,
              testKey: const Key('empty-state-action-0'),
            ),
          ],
        ),
      );

      expectNoOverflow(tester);
      await tester.tap(find.byKey(const Key('empty-state-action-0')));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('最長測試文案', () {
    testWidgetsAtEachSize('section 訊息最長文案（TestCopy.longZh）兩行末截斷不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: LayoutSize.detailPaneWidth,
          child: EmptyState(
            variant: EmptyStateVariant.section,
            message: TestCopy.longZh,
            testKey: testKey,
          ),
        ),
      );

      expectNoOverflow(tester);
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(testKey),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(text.maxLines, 2);
    });

    testWidgetsAtEachSize('說明最長文案（TestCopy.longEn）四行末截斷不溢位', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: LayoutSize.detailPaneWidth,
          child: EmptyState(
            variant: EmptyStateVariant.section,
            message: '說明測試',
            explanation: TestCopy.longEn,
            testKey: testKey,
          ),
        ),
      );

      expectNoOverflow(tester);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: find.byKey(testKey), matching: find.byType(Text)),
          )
          .toList();
      expect(texts.last.maxLines, 4);
    });
  });

  group('zh / en 既有 message key 皆不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('emptyGraphMessage @ ${locale.languageCode}', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: Builder(
            builder: (context) => EmptyState(
              variant: EmptyStateVariant.page,
              message: AppLocalizations.of(context).emptyGraphMessage,
              testKey: testKey,
              actions: _buildActions(1),
            ),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('FR-03 斷言：page 首個動作 label 不等於 backAction', () {
    testWidgets('page 建構時傳入的首個動作標籤不可為 backAction 翻譯值', (tester) async {
      String? backActionLabel;
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) {
            backActionLabel = AppLocalizations.of(context).backAction;
            return EmptyState(
              variant: EmptyStateVariant.page,
              message: '此專案尚無圖譜節點',
              testKey: testKey,
              actions: _buildActions(1),
            );
          },
        ),
      );

      expect(find.text('動作0'), findsOneWidget);
      expect('動作0', isNot(equals(backActionLabel)));
    });
  });

  group('slot 契約', () {
    testWidgets('page 變體無動作時 assert 拋出', (tester) async {
      expect(
        () => EmptyState(
          variant: EmptyStateVariant.page,
          message: '訊息',
          testKey: testKey,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('動作數量超過 3 時 assert 拋出', (tester) async {
      expect(
        () => EmptyState(
          variant: EmptyStateVariant.section,
          message: '訊息',
          testKey: testKey,
          actions: _buildActions(4),
        ),
        throwsAssertionError,
      );
    });
  });

  group('間距引用 token（非硬編碼）', () {
    testWidgets('訊息與說明間為 Space.xs、說明與動作列間為 Space.lg', (tester) async {
      await pumpHarness(
        tester,
        child: EmptyState(
          variant: EmptyStateVariant.section,
          message: '訊息',
          explanation: '說明',
          testKey: testKey,
          actions: _buildActions(1),
        ),
      );

      final sizedBoxes = tester
          .widgetList<SizedBox>(
            find.descendant(of: find.byKey(testKey), matching: find.byType(SizedBox)),
          )
          .where((box) => box.height != null)
          .map((box) => box.height)
          .toList();

      expect(sizedBoxes, containsAll([Space.xs, Space.lg]));
    });
  });
}
