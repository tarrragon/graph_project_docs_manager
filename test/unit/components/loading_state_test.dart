/// LoadingState 元件測試（SPEC-004 §4.24）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

import '../../helpers/helpers.dart';

void main() {
  const testKey = ValueKey('loading-state-test');
  const cancelKey = ValueKey('loading-state-cancel-test');

  group('變體與狀態矩陣：skeleton（matrix/sections）× loading/cancelling', () {
    for (final layout in SkeletonLayout.values) {
      for (final cancelling in [false, true]) {
        testWidgetsAtEachSize(
          'skeleton $layout cancelling=$cancelling 不溢位',
          (tester, size) async {
            await pumpHarness(
              tester,
              size: size,
              settle: false,
              child: LoadingState.skeleton(
                message: 'domainLoading',
                skeletonLayout: layout,
                countText: 'count',
                isCancelling: cancelling,
                onCancel: () {},
                testKey: testKey,
                cancelKey: cancelKey,
              ),
            );
            await tester.pump();

            expectNoOverflow(tester);
            expect(find.byKey(testKey), findsOneWidget);
          },
        );
      }
    }
  });

  group('變體與狀態矩陣：progressBar × loading/cancelling', () {
    for (final cancelling in [false, true]) {
      testWidgetsAtEachSize('progressBar cancelling=$cancelling 不溢位', (
        tester,
        size,
      ) async {
        // cancelling=true 時 progress 改 indeterminate（C3），
        // LinearProgressIndicator 進入連續動畫，settle 永不收斂。
        await pumpHarness(
          tester,
          size: size,
          settle: !cancelling,
          child: LoadingState.progressBar(
            message: 'domainLoading',
            progress: 0.45,
            countText: 'count',
            isCancelling: cancelling,
            onCancel: () {},
            testKey: testKey,
            cancelKey: cancelKey,
          ),
        );
        if (cancelling) {
          await tester.pump();
        }

        expectNoOverflow(tester);
        expect(find.byKey(testKey), findsOneWidget);
      });
    }
  });

  group('最長測試文案：訊息與計數截斷', () {
    testWidgetsAtEachSize('skeleton 最長訊息與計數不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        settle: false,
        child: LoadingState.skeleton(
          message: TestCopy.longZh,
          skeletonLayout: SkeletonLayout.matrix,
          countText: TestCopy.longEn,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      await tester.pump();

      expectNoOverflow(tester);
    });

    testWidgetsAtEachSize('progressBar 最長訊息與計數不溢位', (tester, size) async {
      await pumpHarness(
        tester,
        size: size,
        child: LoadingState.progressBar(
          message: TestCopy.longZh,
          progress: 0.5,
          countText: TestCopy.longEn,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );

      expectNoOverflow(tester);
    });
  });

  group('zh / en 既有 key 不溢位', () {
    for (final locale in kTestLocales) {
      testWidgets('progressBar @ $locale 不溢位', (tester) async {
        await pumpHarness(
          tester,
          locale: locale,
          child: LoadingState.progressBar(
            message: 'domainLoading',
            progress: 0.5,
            isCancelling: false,
            onCancel: () {},
            testKey: testKey,
            cancelKey: cancelKey,
          ),
        );

        expectNoOverflow(tester);
      });
    }
  });

  group('C1-C8：取消契約', () {
    testWidgets('C1：第一幀取消鈕 enabled', (tester) async {
      await pumpHarness(
        tester,
        child: LoadingState.progressBar(
          message: 'domainLoading',
          progress: 0.1,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );

      // AppButton 把 testKey 掛在內層 TextButton（非 AppButton 本身），
      // 定址與 enabled 判斷改以 TextButton.onPressed 是否為 null 為準。
      final button = tester.widget<TextButton>(find.byKey(cancelKey));
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      'C2/C4：按下取消後 Motion.feedback 內取消鈕 disabled 且文字換為取消中',
      (tester) async {
        var isCancelling = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => LoadingState.progressBar(
                  message: 'domainLoading',
                  progress: 0.1,
                  isCancelling: isCancelling,
                  onCancel: () => setState(() => isCancelling = true),
                  testKey: testKey,
                  cancelKey: cancelKey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(cancelKey));
        await tester.pump(Motion.feedback);

        final l10n = AppLocalizations.of(
          tester.element(find.byKey(testKey)),
        );
        final button = tester.widget<TextButton>(find.byKey(cancelKey));
        expect(button.onPressed, isNull);
        expect(find.text(l10n.cancelInProgressAction), findsOneWidget);
      },
    );

    testWidgets('C3：取消進行中骨架根錨點恆存在，無 SnackBar / Dialog', (tester) async {
      await pumpHarness(
        tester,
        settle: false,
        child: LoadingState.skeleton(
          message: 'domainLoading',
          skeletonLayout: SkeletonLayout.matrix,
          isCancelling: true,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byKey(testKey), findsOneWidget);
      }
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('C3：progressBar 取消中進度改 indeterminate', (tester) async {
      await pumpHarness(
        tester,
        settle: false,
        child: LoadingState.progressBar(
          message: 'domainLoading',
          progress: 0.7,
          isCancelling: true,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('C8：連按取消 onCancel 只呼叫一次（disabled 後不再觸發）', (tester) async {
      var callCount = 0;
      var isCancelling = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LoadingState.progressBar(
                message: 'domainLoading',
                progress: 0.1,
                isCancelling: isCancelling,
                onCancel: () {
                  callCount++;
                  setState(() => isCancelling = true);
                },
                testKey: testKey,
                cancelKey: cancelKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(cancelKey));
      await tester.pump(Motion.feedback);
      await tester.tap(find.byKey(cancelKey));
      await tester.pump(Motion.feedback);

      expect(callCount, 1);
    });
  });

  group('indeterminate 誠實性硬規則', () {
    testWidgets('skeleton 畫面無 % 字元、無 LinearProgressIndicator', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        settle: false,
        child: LoadingState.skeleton(
          message: 'domainLoading',
          skeletonLayout: SkeletonLayout.sections,
          countText: 'count',
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      await tester.pump();

      expect(find.textContaining('%'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('progressBar 的 value 等於 parsed / total', (tester) async {
      await pumpHarness(
        tester,
        child: LoadingState.progressBar(
          message: 'domainLoading',
          progress: 0.42,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.42);
    });
  });

  group('最短顯示與 disableAnimations', () {
    testWidgets('pump(Motion.feedback) 後根錨點仍存在（最短顯示）', (tester) async {
      await pumpHarness(
        tester,
        child: LoadingState.progressBar(
          message: 'domainLoading',
          progress: 0.1,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      await tester.pump(Motion.feedback);

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('disableAnimations 為 true 時骨架靜態不溢位', (tester) async {
      await pumpHarness(
        tester,
        settle: false,
        disableAnimations: true,
        child: LoadingState.skeleton(
          message: 'domainLoading',
          skeletonLayout: SkeletonLayout.matrix,
          isCancelling: false,
          onCancel: () {},
          testKey: testKey,
          cancelKey: cancelKey,
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expectNoOverflow(tester);
      expect(find.byKey(testKey), findsOneWidget);
    });
  });

  testWidgets('cancelLabel 覆寫：非取消中時採用覆寫文案（如 cancelScanAction）', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      settle: false,
      child: LoadingState.skeleton(
        message: 'gapReportScanning',
        skeletonLayout: SkeletonLayout.sections,
        isCancelling: false,
        onCancel: () {},
        testKey: testKey,
        cancelKey: cancelKey,
        cancelLabel: 'Cancel',
      ),
    );
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
  });
}
