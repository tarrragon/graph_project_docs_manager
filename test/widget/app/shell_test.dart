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
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_overlay.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';

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

  // SPEC-004 §4.28 slot 契約：content 不接受 PageColumn，頁首恰由
  // AppShell 為每個導覽項建一個 PageColumn 單一渲染。以數量鎖定而非鎖定
  // 某一畫面的外觀——畫面自建巢狀 PageColumn 時，元件樹下的 PageColumn
  // 數量會多於導覽項數（0.1.0-W3-127：追溯視圖曾自建一個，命中 7 而非 6）。
  testWidgets('AppShell 元件樹下 PageColumn 數量等於導覽項數', (tester) async {
    await _pumpShell(tester);

    expect(
      find.byType(components.PageColumn, skipOffstage: false),
      findsNWidgets(AppDestination.values.length),
      reason: '畫面若自建巢狀 PageColumn，會使數量多於導覽項數（頁首重複渲染）',
    );
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

  // 0.2.0-W1-042：App 啟動 restore() 回 WorkspaceReady 後，detect() 應被
  // 呼叫且 domainViewStateProvider 反映結果——證明 initState 的接線確實
  // 執行到底，不只是呼叫 restore() 而已。
  testWidgets(
    'App 啟動 restore() 回 WorkspaceReady 後 detect() 被呼叫，'
    'domainViewStateProvider 反映結果',
    (tester) async {
      late ProviderContainer container;
      await _pumpShell(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            WorkspaceRepository(
              preferencesPort: _FakeReadyPreferencesPort(),
              directoryProbe: _FakeDirectoryProbePort(),
            ),
          ),
          frameworkSignalProbeProvider.overrideWithValue(
            const _FakeSignalProbe(),
          ),
        ],
        onReady: (c) => container = c,
      );

      expect(
        container.read(domainViewStateProvider),
        isA<DomainNotFramework>(),
      );
    },
  );

  // 0.2.0-W1-042：推定版本旗標非 null 時，AppShell 返回列常駐渲染
  // `badge-<screen>-inferred-version`；null 時不渲染（SPEC-001 v1.19
  // 〈推定版本〉註記）。
  testWidgets('inferredVersionProvider 非 null 時渲染推定版本徽章，null 時不渲染', (
    tester,
  ) async {
    await _pumpShell(tester);

    expect(
      find.byKey(const Key('badge-domain-inferred-version')),
      findsNothing,
    );
  });

  testWidgets('inferredVersionProvider 非 null 時渲染推定版本徽章', (tester) async {
    await _pumpShell(
      tester,
      overrides: [inferredVersionProvider.overrideWith((ref) => '2.40.3')],
    );

    expect(
      find.byKey(const Key('badge-domain-inferred-version')),
      findsOneWidget,
    );
  });
}

/// 固定回傳已記住路徑 `/fake/workspace` 的假偏好設定管道，模擬
/// `restore()` 找到先前選定的資料夾（0.2.0-W1-042）。
class _FakeReadyPreferencesPort implements WorkspacePreferencesPort {
  @override
  Future<WorkspacePreferencesHandle> open() async =>
      _FakeReadyPreferencesHandle();
}

class _FakeReadyPreferencesHandle implements WorkspacePreferencesHandle {
  @override
  String? readString(String key) {
    if (key == 'workspace.path') return '/fake/workspace';
    if (key == 'workspace.schemaVersion') return '1';
    return null;
  }

  @override
  Future<bool> writeString(String key, String value) async => true;
}

/// 固定回報資料夾可用的假探測；`readFirstEntry` 走空資料夾成功路徑
/// （`workspace_repository.dart` 吞 [StateError]）。
class _FakeDirectoryProbePort implements WorkspaceDirectoryProbePort {
  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<void> readFirstEntry(String path) async {
    throw StateError('empty');
  }
}

/// 固定回傳兩訊號皆缺的假 gate 訊號探測；避免 `detect()` 呼叫碰觸真實
/// 檔案系統（0.2.0-W1-042）。
class _FakeSignalProbe implements FrameworkSignalProbePort {
  const _FakeSignalProbe();

  @override
  Future<String?> readVersion(String workspacePath) async => null;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => false;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => null;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  void Function(ProviderContainer container)? onReady,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  onReady?.call(ProviderScope.containerOf(capturedContext));
}
