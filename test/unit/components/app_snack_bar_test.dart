/// AppSnackBar 元件測試（SPEC-004 §4.26「測試點」）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

const _triggerPlainKey = Key('trigger-plain');
const _triggerActionKey = Key('trigger-action');
const _snackBarActionKey = Key('snackbar-action');

/// SnackBar 的進出動畫由 Material 內建 [Timer] + [AnimationController] 驅動
/// （SPEC-004 §4.26「Material 預設進出，不覆寫」）；`flutter_test` 的
/// fake clock 需以小步距（<= 100ms）反覆 pump 才能讓 Timer 觸發與動畫逐幀
/// 推進被正確捕捉（單次大跳躍的 pump 只會產生一個 frame，可能落在
/// Timer 觸發之前）。本函式把 [total] 拆成 100ms 一步的 pump 序列。
Future<void> _pumpBy(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    final next = (total - elapsed) < step ? (total - elapsed) : step;
    await tester.pump(next);
    elapsed += next;
  }
}

/// 建構觸發按鈕，點按即呼叫 [AppSnackBar.show]。共用於全部測試組。
Widget _triggerHarness({
  required String message,
  AppSnackBarVariant variant = AppSnackBarVariant.plain,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return Builder(
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          key: variant == AppSnackBarVariant.plain
              ? _triggerPlainKey
              : _triggerActionKey,
          onPressed: () => AppSnackBar.show(
            context,
            message: message,
            variant: variant,
            actionLabel: actionLabel,
            onAction: onAction,
            actionTestKey: _snackBarActionKey,
          ),
          child: const Text('trigger'),
        ),
      ],
    ),
  );
}

void main() {
  group('AppSnackBar 全變體渲染', () {
    testWidgets('plain 觸發後顯示 SnackBar 且文字相符', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: 'plain-message'),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('plain-message'), findsOneWidget);
    });

    testWidgets('withAction 觸發後顯示 SnackBar 與動作', (tester) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('action-message'), findsOneWidget);
      expect(find.text('action-label'), findsOneWidget);
      expect(actionCalled, 0);
    });
  });

  group('尺寸不溢位', () {
    testWidgetsAtEachSize('plain 於兩種視窗尺寸下不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _triggerHarness(message: TestCopy.longZh),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('withAction 於兩種視窗尺寸下不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: _triggerHarness(
          message: TestCopy.longEn,
          variant: AppSnackBarVariant.withAction,
          actionLabel: TestCopy.longToken,
          onAction: () {},
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expectNoOverflow(tester);
    });
  });

  group('最長測試文案：訊息兩行末截斷、動作 label 截斷', () {
    testWidgets('message 用 TestCopy.longZh 兩行截斷不溢位', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: TestCopy.longZh),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(TestCopy.longZh),
        ),
      );
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expectNoOverflow(tester);
    });

    testWidgets('動作 label 用 TestCopy.longToken 單行截斷', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'msg',
          variant: AppSnackBarVariant.withAction,
          actionLabel: TestCopy.longToken,
          onAction: () {},
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();

      expectNoOverflow(tester);
    });
  });

  group('zh / en 五個 key 皆不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('五個既有 key @ ${locale.languageCode}', (tester) async {
        late AppLocalizations l10n;
        await pumpHarness(
          tester,
          locale: locale,
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    key: _triggerPlainKey,
                    onPressed: () => AppSnackBar.show(
                      context,
                      message: l10n.openedExternallyMessage,
                    ),
                    child: const Text('trigger'),
                  ),
                ],
              );
            },
          ),
        );

        for (final message in [
          l10n.openedExternallyMessage,
          l10n.sourceFileNotFoundSnackbarMessage,
          l10n.sourceFileStillMissingMessage,
        ]) {
          AppSnackBar.show(
            tester.element(find.byKey(_triggerPlainKey)),
            message: message,
          );
          await tester.pump();
          expectNoOverflow(tester);
        }

        for (final label in [l10n.refreshAction, l10n.rescanAction]) {
          AppSnackBar.show(
            tester.element(find.byKey(_triggerPlainKey)),
            message: 'x',
            variant: AppSnackBarVariant.withAction,
            actionLabel: label,
            actionTestKey: _snackBarActionKey,
            onAction: () {},
          );
          await tester.pump();
          expectNoOverflow(tester);
        }
      });
    }
  });

  group('停留時間與退出路徑', () {
    // SnackBar 進出動畫為 Flutter Material 內建 250ms transition，非本專案
    // token（SPEC-004 §4.26「Material 預設進出，不覆寫」）；顯示期間長度由
    // AppSnackBar 傳入的 Motion.snackBar / Motion.snackBarWithAction 決定。
    const materialTransition = Duration(milliseconds: 250);

    testWidgets('pump(Motion.snackBar) 後 plain 消失', (tester) async {
      await pumpHarness(
        tester,
        child: _triggerHarness(message: 'plain-message'),
      );

      await tester.tap(find.byKey(_triggerPlainKey));
      await tester.pump();
      await _pumpBy(tester, materialTransition);
      expect(find.byType(SnackBar), findsOneWidget);

      await _pumpBy(
        tester,
        Motion.snackBar + materialTransition + materialTransition,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'withAction 於 Motion.snackBar 後仍存在、Motion.snackBarWithAction 後消失',
      (tester) async {
        await pumpHarness(
          tester,
          child: _triggerHarness(
            message: 'action-message',
            variant: AppSnackBarVariant.withAction,
            actionLabel: 'action-label',
            onAction: () {},
          ),
        );

        await tester.tap(find.byKey(_triggerActionKey));
        await tester.pump();
        await _pumpBy(tester, materialTransition);
        expect(find.byType(SnackBar), findsOneWidget);

        await _pumpBy(tester, Motion.snackBar);
        expect(find.byType(SnackBar), findsOneWidget);

        final remaining = Motion.snackBarWithAction - Motion.snackBar;
        await _pumpBy(
          tester,
          remaining + materialTransition + materialTransition,
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('動作點選呼叫 onAction 恰一次且 SnackBar 即時消失', (tester) async {
      var actionCalled = 0;
      await pumpHarness(
        tester,
        child: _triggerHarness(
          message: 'action-message',
          variant: AppSnackBarVariant.withAction,
          actionLabel: 'action-label',
          onAction: () => actionCalled++,
        ),
      );

      await tester.tap(find.byKey(_triggerActionKey));
      await tester.pump();
      await _pumpBy(tester, materialTransition);

      await tester.tap(find.byKey(_snackBarActionKey));
      await _pumpBy(tester, materialTransition + materialTransition);

      expect(actionCalled, 1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
