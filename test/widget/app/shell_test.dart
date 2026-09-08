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
// `components.dart` 與 `app/shell.dart` 各有一個 `AppShell`（元件庫的殼與
// 應用層的殼），不加前綴會撞名。
import 'package:graph_project_docs_manager/components/components.dart'
    as components;
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';

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

  // SPEC-004 §4.29「使用 design token」間距列：頁首水平內距 Space.xl。頁首由
  // 六個畫面共用同一個 SplitRow.header，本測試逐頁量標題文字左緣到頁面容器
  // 左緣的距離，鎖定「六個畫面一致」而非只驗單一畫面。
  testWidgets('六個畫面的頁首標題左緣與頁面容器左緣距離皆為 Space.xl', (tester) async {
    await _pumpShell(tester);

    // 逐頁取 AppShell 實際持有的 PageColumn 與其 header slot 實例（而非
    // 按型別搜尋）：型別搜尋會連畫面內容自建的巢狀 PageColumn 一併命中。
    // IndexedStack 只繪製目前頁，其餘五頁在元件樹中已完成佈局，量測有效，
    // 但預設 finder 會跳過，故各處 skipOffstage: false。
    final shell = tester.widget<components.AppShell>(
      find.byType(components.AppShell),
    );
    expect(shell.pages, hasLength(AppDestination.values.length));

    for (final page in shell.pages) {
      final pageRect = tester.getRect(find.byWidget(page, skipOffstage: false));
      final titleFinder = find.descendant(
        of: find.byWidget(page.header, skipOffstage: false),
        matching: find.byType(components.PageTitle, skipOffstage: false),
        skipOffstage: false,
      );
      expect(
        titleFinder,
        findsOneWidget,
        reason: '畫面「${page.semanticLabel}」的頁首沒有唯一的 PageTitle',
      );
      final title = tester.widget<components.PageTitle>(titleFinder).title;
      final textRect = tester.getRect(
        find.descendant(
          of: titleFinder,
          matching: find.text(title, skipOffstage: false),
          skipOffstage: false,
        ),
      );

      expect(
        textRect.left - pageRect.left,
        Space.xl,
        reason: '畫面「${page.semanticLabel}」的頁首標題內距不符',
      );
    }
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
