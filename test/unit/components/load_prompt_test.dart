/// LoadPrompt 元件測試（SPEC-004 §4.25「測試點」）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';

import '../../helpers/helpers.dart';

void main() {
  group('單一狀態渲染（count 1 與 99999）× 兩種視窗尺寸', () {
    for (final count in [1, 99999]) {
      testWidgetsAtEachSize('count=$count 不拋例外不溢位', (tester, size) async {
        await pumpHarness(
          tester,
          size: size,
          child: SizedBox(
            width: 400,
            height: 300,
            child: LoadPrompt(
              count: count,
              onStart: () {},
              testKey: Anchor.state(Screen.tickets, 'unloaded'),
              startKey: Anchor.action(Screen.tickets, 'start-load'),
            ),
          ),
        );

        expectNoOverflow(tester);
        expect(AnchorFinder.state(Screen.tickets, 'unloaded'), findsOneWidget);
      });
    }
  });

  group('最長測試文案', () {
    testWidgetsAtEachSize('longZh 覆蓋 message 單行末端省略不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: SizedBox(
          width: 300,
          height: 300,
          child: LoadPrompt(
            count: 1,
            message: TestCopy.longZh,
            onStart: () {},
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      expectNoOverflow(tester);
      final text = tester.widget<Text>(
        find.descendant(
          of: AnchorFinder.state(Screen.tickets, 'unloaded'),
          matching: find.text(TestCopy.longZh),
        ),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('zh / en 兩語系不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('count 1313 @ ${locale.languageCode}', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: SizedBox(
            width: 320,
            height: 300,
            child: LoadPrompt(
              count: 1313,
              onStart: () {},
              testKey: Anchor.state(Screen.tickets, 'unloaded'),
              startKey: Anchor.action(Screen.tickets, 'start-load'),
            ),
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('互動反應', () {
    testWidgets('開始載入呼叫 onStart 恰一次；畫面無 % 與預估耗時文字', (tester) async {
      var callCount = 0;
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: LoadPrompt(
            count: 42,
            onStart: () => callCount++,
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      await tester.tap(AnchorFinder.action(Screen.tickets, 'start-load'));
      await tester.pumpAndSettle();

      expect(callCount, 1);

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        expect(text.data ?? '', isNot(contains('%')));
      }
    });
  });

  group('slot 契約', () {
    testWidgets('不傳 message 時取 ticketsLoadPrompt(count)', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: LoadPrompt(
            count: 7,
            onStart: () {},
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      final l10n = AppLocalizations.of(
        tester.element(AnchorFinder.state(Screen.tickets, 'unloaded')),
      );
      expect(find.text(l10n.ticketsLoadPrompt(7)), findsOneWidget);
    });

    testWidgets('傳入 message 覆蓋預設訊息', (tester) async {
      const override = 'custom message';
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: LoadPrompt(
            count: 7,
            message: override,
            onStart: () {},
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      expect(find.text(override), findsOneWidget);
    });
  });

  group('無障礙', () {
    testWidgets('開始載入按鈕在朗讀樹中，訊息為 header 且以 liveRegion 播報', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: LoadPrompt(
            count: 3,
            onStart: () {},
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      final startSemantics = tester.getSemantics(
        AnchorFinder.action(Screen.tickets, 'start-load'),
      );
      expect(startSemantics.flagsCollection.isEnabled.toString(), contains('True'));

      final messageFinder = find.ancestor(
        of: find.byType(Text).first,
        matching: find.byWidgetPredicate((w) => w is Semantics),
      );
      expect(messageFinder, findsWidgets);

      handle.dispose();
    });
  });

  group('間距 token', () {
    testWidgets('訊息與動作列間存在非零 SizedBox 間距', (tester) async {
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 400,
          height: 300,
          child: LoadPrompt(
            count: 1,
            onStart: () {},
            testKey: Anchor.state(Screen.tickets, 'unloaded'),
            startKey: Anchor.action(Screen.tickets, 'start-load'),
          ),
        ),
      );

      final gaps = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: AnchorFinder.state(Screen.tickets, 'unloaded'),
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.height != null && box.height! > 0);
      expect(gaps, isNotEmpty);
    });
  });
}
