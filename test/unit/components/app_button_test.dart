/// AppButton 元件測試（SPEC-004 §4.4「測試點」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppButton 全變體 × 全狀態渲染', () {
    for (final size in WindowSize.values) {
      for (final locale in kTestLocales) {
        testWidgets(
          '三變體 enabled/disabled 皆可渲染不拋例外 @ ${size.label} @ '
          '${locale.languageCode}',
          (tester) async {
            await pumpHarness(
              tester,
              size: size,
              locale: locale,
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final variant in AppButtonVariant.values) ...[
                          AppButton(
                            testKey: Anchor.action(
                              Screen.domain,
                              'button-${variant.name}-enabled',
                            ),
                            label: l10n.backAction,
                            variant: variant,
                            onPressed: () {},
                          ),
                          AppButton(
                            testKey: Anchor.action(
                              Screen.domain,
                              'button-${variant.name}-disabled',
                            ),
                            label: l10n.backAction,
                            variant: variant,
                            enabled: false,
                            disabledReason: l10n.probeTimeoutReason,
                            onPressed: () {},
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );

            expectNoOverflow(tester);
          },
        );
      }
    }
  });

  group('高度契約', () {
    testWidgets('高恰為 LayoutSize.hitTargetMin', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-height');
      await pumpHarness(
        tester,
        child: Builder(
          builder: (context) => AppButton(
            testKey: key,
            label: AppLocalizations.of(context).backAction,
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byKey(key));
      expect(size.height, LayoutSize.hitTargetMin);
    });
  });

  group('最長測試文案', () {
    testWidgets('label 使用 TestCopy.longToken 不溢位（截斷）', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-long-label');
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 200,
          child: AppButton(
            testKey: key,
            label: TestCopy.longToken,
            onPressed: () {},
          ),
        ),
      );

      expectNoOverflow(tester);
      final text = tester.widget<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      );
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });

    testWidgets('disabledReason 使用 TestCopy.longZh 不溢位（截斷）', (
      tester,
    ) async {
      final key = Anchor.action(Screen.domain, 'button-long-reason');
      await pumpHarness(
        tester,
        child: SizedBox(
          width: 260,
          child: AppButton(
            testKey: key,
            label: 'x',
            enabled: false,
            disabledReason: TestCopy.longZh,
            onPressed: () {},
          ),
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('互動反應', () {
    testWidgets('enabled 點擊呼叫 onPressed 恰一次', (tester) async {
      var callCount = 0;
      final key = Anchor.action(Screen.domain, 'button-tap');
      await pumpHarness(
        tester,
        child: AppButton(testKey: key, label: 'x', onPressed: () => callCount++),
      );

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('disabled 點擊零次且無 SnackBar', (tester) async {
      var callCount = 0;
      final key = Anchor.action(Screen.domain, 'button-disabled-tap');
      await pumpHarness(
        tester,
        child: AppButton(
          testKey: key,
          label: 'x',
          enabled: false,
          disabledReason: 'reason',
          onPressed: () => callCount++,
        ),
      );

      await tester.tap(find.byKey(key), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Space / Enter 觸發等價於點選', (tester) async {
      var callCount = 0;
      final key = Anchor.action(Screen.domain, 'button-key-trigger');
      await pumpHarness(
        tester,
        child: AppButton(testKey: key, label: 'x', onPressed: () => callCount++),
      );

      final textFinder = find.descendant(
        of: find.byKey(key),
        matching: find.byType(Text),
      );
      final focusNode = Focus.of(tester.element(textFinder.first));
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });
  });

  group('元件樹結構', () {
    testWidgets('被 ButtonStyleButton 包覆', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-wrapper');
      await pumpHarness(
        tester,
        child: AppButton(testKey: key, label: 'x', onPressed: () {}),
      );

      expect(
        find.ancestor(
          of: find.byKey(key),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing, // key 掛在 ButtonStyleButton 本身，非其祖先
      );
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton && w.key == key),
        findsOneWidget,
      );
    });
  });

  group('無障礙', () {
    testWidgets('朗讀標籤等於 label', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-semantics');
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: AppButton(testKey: key, label: TestCopy.nodeTitle, onPressed: () {}),
      );

      final semantics = tester.getSemantics(find.byKey(key));
      expect(semantics.label, TestCopy.nodeTitle);
      expect(semantics.flagsCollection.isEnabled.toString(), contains('True'));

      handle.dispose();
    });

    testWidgets('disabled 時 enabled 旗標為 false，hint 附 disabledReason', (
      tester,
    ) async {
      final key = Anchor.action(Screen.domain, 'button-semantics-disabled');
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: AppButton(
          testKey: key,
          label: 'x',
          enabled: false,
          disabledReason: TestCopy.gapDescription,
          onPressed: () {},
        ),
      );

      final semantics = tester.getSemantics(find.byKey(key));
      expect(semantics.flagsCollection.isEnabled.toString(), contains('False'));

      handle.dispose();
    });

    testWidgets('semanticExpanded 為 null 時不附加 expanded 旗標', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-semantics-no-expanded');
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: AppButton(testKey: key, label: 'x', onPressed: () {}),
      );

      final semantics = tester.getSemantics(find.byKey(key));
      expect(semantics.flagsCollection.isExpanded.toBoolOrNull(), isNull);

      handle.dispose();
    });

    testWidgets('semanticExpanded 附加於同一節點，值等於傳入值', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-semantics-expanded');
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: AppButton(
          testKey: key,
          label: 'x',
          onPressed: () {},
          semanticExpanded: true,
        ),
      );

      final semantics = tester.getSemantics(find.byKey(key));
      expect(semantics.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
      expect(semantics.label, 'x');

      handle.dispose();
    });
  });

  group('slot 契約', () {
    testWidgets('disabled 時未提供 disabledReason 觸發 assert', (tester) async {
      expect(
        () => AppButton(
          testKey: Anchor.action(Screen.domain, 'button-invalid'),
          label: 'x',
          enabled: false,
          onPressed: () {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('secondary/primary 變體帶 leading 觸發 assert', (tester) async {
      expect(
        () => AppButton(
          testKey: Anchor.action(Screen.domain, 'button-invalid-leading'),
          label: 'x',
          variant: AppButtonVariant.primary,
          leading: const AppIcon(icon: Icons.close),
          onPressed: () {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('text 變體帶 leading 圖示不拋例外且圖示排除語意樹', (tester) async {
      final key = Anchor.action(Screen.domain, 'button-with-leading');
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: AppButton(
          testKey: key,
          label: 'x',
          variant: AppButtonVariant.text,
          leading: const AppIcon(icon: Icons.close),
          onPressed: () {},
        ),
      );

      expectNoOverflow(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
      handle.dispose();
    });
  });
}
