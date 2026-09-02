// SPEC-003 §2.4：返回鍵由 AppShell 單一渲染，六個畫面不各自定義返回錨點。
//
// 驗收對外行為：`returnToProvider` 非 null 時渲染 `action-<screen>-back`
// 且可點擊觸發 [consumeReturnTo]；為 null 時該錨點不存在於元件樹（而非
// disabled）。實際渲染實作（_ReturnToHeader）待元件庫元件到位後會被
// 替換，本測試只鎖定錨點與行為，不鎖定樣式。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/shell.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';

void main() {
  testWidgets('returnTo 為 null 時 action-<screen>-back 不存在於元件樹', (
    tester,
  ) async {
    await _pumpShell(tester);

    expect(find.byKey(const Key('action-domain-back')), findsNothing);
  });

  testWidgets('jump 後 returnTo 非 null，渲染來源畫面的返回錨點；點擊後消費並清空', (
    tester,
  ) async {
    late ProviderContainer container;
    await _pumpShell(
      tester,
      onReady: (c) => container = c,
    );

    // 模擬畫面內 jump：domain → nodeDetail，returnTo 應變為 domain。
    navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);
    await tester.pump();

    expect(find.byKey(const Key('action-nodeDetail-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('action-nodeDetail-back')));
    await tester.pump();

    expect(
      container.read(selectedDestinationProvider),
      AppDestination.domain,
    );
    expect(container.read(returnToProvider), isNull);
    expect(find.byKey(const Key('action-domain-back')), findsNothing);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  void Function(ProviderContainer container)? onReady,
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1280, 800),
        builder: (context, child) => MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const AppShell();
            },
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  onReady?.call(ProviderScope.containerOf(capturedContext));
}
