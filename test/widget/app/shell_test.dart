// SPEC-003 §2.4：返回鍵由 AppShell 單一渲染，六個畫面不各自定義返回錨點。
//
// 驗收對外行為：`returnToProvider` 非 null 時渲染 `action-<screen>-back`
// 且可點擊觸發 [consumeReturnTo]；為 null 時該錨點不存在於元件樹（而非
// disabled）。實際渲染實作（_ReturnToHeader）待元件庫元件到位後會被
// 替換，本測試只鎖定錨點與行為，不鎖定樣式。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/components/attention_level.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/workspace_selection.dart';
import 'package:graph_project_docs_manager/assembly/shell.dart';
// `components.dart` 與 `assembly/shell.dart` 各有一個 `AppShell`（元件庫的殼與
// 應用層的殼），不加前綴會撞名。
import 'package:graph_project_docs_manager/components/components.dart'
    as components;
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/screens/preferences/preferences_panel.dart';
import 'package:graph_project_docs_manager/services/macos_preferences_channel.dart';
import 'package:graph_project_docs_manager/screens/shortcuts/shortcuts_panel.dart';
import 'package:graph_project_docs_manager/screens/write_log/write_log_panel.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/domain_view_fixtures.dart';
import '../../helpers/gap_round_fakes.dart';
import '../../helpers/pump_harness.dart' show lastWinsByProvider;
import '../../helpers/stub_workspace_repository.dart';
import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

void main() {
  _registerFocusTests();
  _registerBottomItemTests();
  _registerWriteLogTests();
  testWidgets('啟動首幀（restore 未完成）不顯示 fixture 矩陣', (tester) async {
    final pending = Completer<WorkspaceState>();
    addTearDown(() => pending.complete(const WorkspaceUnset()));
    await _pumpShell(
      tester,
      injectDomainState: false,
      settle: false,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(
          _PendingRestoreRepository(pending.future),
        ),
      ],
    );

    expect(find.byKey(const Key('state-domain-matrix')), findsNothing);
  });
  testWidgets('專案改變（select）時 AppShell 清除顯示中的 SnackBar（0.5.0-W1-168.2.1）', (
    tester,
  ) async {
    late ProviderContainer container;
    await _pumpShell(
      tester,
      overrides: _readyOverrides(),
      onReady: (c) => container = c,
    );
    components.AppSnackBar.show(
      tester.element(find.byType(Scaffold).first),
      message: 'shell-wiring-message',
      level: AttentionLevel.discardable,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('shell-wiring-message'), findsOneWidget);

    await container
        .read(workspaceSelectionProvider.notifier)
        .select(const WorkspaceReady('/ws'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('shell-wiring-message'), findsNothing);
  });

  testWidgets('returnTo 為 null 時 action-<screen>-back 不存在於元件樹', (tester) async {
    await _pumpShell(tester);

    expect(find.byKey(const Key('action-domain-back')), findsNothing);
  });

  testWidgets('jump 後 returnTo 非 null，渲染來源畫面的返回錨點；點擊後消費並清空', (tester) async {
    late ProviderContainer container;
    await _pumpShell(tester, onReady: (c) => container = c);

    // 模擬畫面內 jump：domain → nodeDetail，returnTo 應變為 domain。
    navigateTo(container.read, AppDestination.nodeDetail, NavIntent.jump);
    await tester.pump();

    expect(find.byKey(const Key('action-nodeDetail-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('action-nodeDetail-back')));
    await tester.pump();

    expect(container.read(selectedDestinationProvider), AppDestination.domain);
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
  testWidgets('App 啟動 restore() 回 WorkspaceReady 後 detect() 被呼叫，'
      'domainViewStateProvider 反映結果', (tester) async {
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

    expect(container.read(domainViewStateProvider), isA<DomainNotFramework>());
  });

  // 0.3.3-W3-398：SPEC-003 §3.1〈生命週期〉——無已存路徑或還原失敗時
  // Domain 視圖進入 state-domain-unset，不停在預設 fixture 矩陣。
  testWidgets('啟動 restore() 回 WorkspaceUnset → state-domain-unset', (
    tester,
  ) async {
    late ProviderContainer container;
    await _pumpShell(
      tester,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(
          StubWorkspaceRepository(const WorkspaceUnset()),
        ),
      ],
      onReady: (c) => container = c,
    );

    expect(container.read(domainViewStateProvider), isA<DomainUnset>());
    expect(find.byKey(const Key('state-domain-unset')), findsOneWidget);
    expect(find.byKey(const Key('state-domain-matrix')), findsNothing);
  });

  testWidgets('啟動 restore() 回 WorkspaceUnavailable → state-domain-unset', (
    tester,
  ) async {
    late ProviderContainer container;
    await _pumpShell(
      tester,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(
          StubWorkspaceRepository(
            const WorkspaceUnavailable(
              lastKnownPath: '/gone',
              reason: 'missing',
            ),
          ),
        ),
      ],
      onReady: (c) => container = c,
    );

    expect(container.read(domainViewStateProvider), isA<DomainUnset>());
    expect(find.byKey(const Key('state-domain-unset')), findsOneWidget);
    expect(find.byKey(const Key('state-domain-matrix')), findsNothing);
  });

  // 0.3.3-W3-400：還原失敗原因常駐於未選專案畫面（SPEC-001 v1.24 §1）。
  testWidgets('啟動 Unavailable：未選專案畫面顯示 workspaceUnavailable(reason)', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      overrides: [_unavailableRepoOverride()],
      onReady: (_) {},
    );
    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.workspaceUnavailable('missing')), findsOneWidget);
    expect(find.text(l10n.folderAccessRationale), findsNothing);
  });

  testWidgets('啟動 Unset：顯示 folderAccessRationale，無原因文字（對照）', (tester) async {
    await _pumpShell(
      tester,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(
          StubWorkspaceRepository(const WorkspaceUnset()),
        ),
      ],
      onReady: (_) {},
    );
    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.folderAccessRationale), findsOneWidget);
    expect(find.text(l10n.workspaceUnavailable('missing')), findsNothing);
  });

  // 0.5.0-W1-206.2：選到仍不可讀的資料夾，以 SnackBar 回饋、畫面維持未選專案。
  testWidgets('Unavailable 降級後選到不可讀資料夾：SnackBar 出現，仍為未選專案', (tester) async {
    await _pumpShell(
      tester,
      overrides: [_unavailableRepoOverride()],
      onReady: (_) {},
    );
    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.workspaceUnavailable('missing')), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.folderUnavailableMessage('missing')), findsOneWidget);
    expect(find.byKey(const Key('state-domain-unset')), findsOneWidget);
  });

  testWidgets('啟動 restore() 回 WorkspaceReady → 不改寫為 Unset，由 gate 判定（對照）', (
    tester,
  ) async {
    late ProviderContainer container;
    await _pumpShell(
      tester,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(
          StubWorkspaceRepository(const WorkspaceReady('/ws')),
        ),
        frameworkSignalProbeProvider.overrideWithValue(
          const StubFrameworkSignalProbe(version: null, schemaJson: false),
        ),
      ],
      onReady: (c) => container = c,
    );
    expect(container.read(domainViewStateProvider), isA<DomainNotFramework>());
  });

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
      overrides: [
        inferredVersionProvider.overrideWithInitial((ref) => '2.40.3'),
      ],
    );

    expect(
      find.byKey(const Key('badge-domain-inferred-version')),
      findsOneWidget,
    );
  });

  // 0.5.0-W1-213.3：components.AppShell 改由參數驅動後，組裝根必須把
  // provider 值傳到畫面（降級旗標與版本文字）。
  testWidgets('degradedSchemaProvider 為真時組裝根傳入降級徽章，版本文字取自 provider', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      overrides: [
        degradedSchemaProvider.overrideWithInitial((ref) => true),
        degradedSchemaVersionsProvider.overrideWithInitial(
          (ref) => const DegradedSchemaVersions(
            builtinVersion: '1.2.3',
            projectVersion: '4.5.6',
          ),
        ),
      ],
    );

    final badge = find.byKey(const Key('badge-domain-degraded-schema'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.textContaining('1.2.3')),
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

// 0.7.0-W1-007.4：側欄底部兩項（SPEC-003 §3.8、§3.10）。
void _registerBottomItemTests() {
  group('側欄底部項', () {
    testWidgets('點「設定」開啟偏好設定面板，與 ⌘, 同一開合狀態', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);

      await tester.tap(find.byKey(const Key('nav-action-preferences')));
      await tester.pump();

      expect(container.read(preferencesOpenProvider), isTrue);
      expect(find.byKey(const Key('action-preferences-close')), findsOneWidget);
    });

    testWidgets('點「鍵盤快捷鍵」開啟快捷鍵面板', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);

      await tester.tap(find.byKey(const Key('nav-action-shortcuts')));
      await tester.pump();

      expect(container.read(shortcutsOpenProvider), isTrue);
      expect(find.byKey(const Key('state-shortcuts-list')), findsOneWidget);
    });

    testWidgets('兩面板互斥：開一個先關另一個', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);

      container.read(preferencesOpenProvider.notifier).state = true;
      await tester.pump();
      container.read(shortcutsOpenProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(preferencesOpenProvider), isFalse);
      expect(container.read(shortcutsOpenProvider), isTrue);

      container.read(preferencesOpenProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(shortcutsOpenProvider), isFalse);
      expect(container.read(preferencesOpenProvider), isTrue);
    });

    testWidgets('收到 openKeyboardShortcuts：快捷鍵面板開啟，偏好設定面板關閉', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);
      container.read(preferencesOpenProvider.notifier).state = true;
      await tester.pump();

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        preferencesChannelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openKeyboardShortcuts'),
        ),
        (_) {},
      );
      await tester.pump();

      expect(container.read(shortcutsOpenProvider), isTrue);
      expect(container.read(preferencesOpenProvider), isFalse);
    });

    testWidgets('底部項開啟的面板關閉後焦點回到該項（設定、快捷鍵）', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);

      for (final entry in [
        ('nav-action-preferences', preferencesOpenProvider),
        ('nav-action-shortcuts', shortcutsOpenProvider),
      ]) {
        await tester.tap(find.byKey(Key(entry.$1)));
        await tester.pump();
        container.read(entry.$2.notifier).state = false;
        await tester.pump();
        await tester.pump();
        expect(_itemNode(tester, entry.$1).hasFocus, isTrue, reason: entry.$1);
      }
    });

    testWidgets('選單開啟後關閉：焦點回開啟前持有者；無持有者不預設焦點', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);
      Future<void> sendMenu() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          preferencesChannelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('openKeyboardShortcuts'),
          ),
          (_) {},
        );
        await tester.pump();
      }

      // 開啟前持有者：設定項。
      _itemNode(tester, 'nav-action-preferences').requestFocus();
      await tester.pump();
      await sendMenu();
      container.read(shortcutsOpenProvider.notifier).state = false;
      await tester.pump();
      await tester.pump();
      expect(_itemNode(tester, 'nav-action-preferences').hasFocus, isTrue);

      // 無持有者：不歸還到底部項。
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await sendMenu();
      container.read(shortcutsOpenProvider.notifier).state = false;
      await tester.pump();
      await tester.pump();
      expect(_itemNode(tester, 'nav-action-shortcuts').hasFocus, isFalse);
    });

    testWidgets('底部項不改變導覽狀態', (tester) async {
      late ProviderContainer container;
      await _pumpShell(tester, onReady: (c) => container = c);

      await tester.tap(find.byKey(const Key('nav-action-shortcuts')));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), isNull);
    });
  });
}

// 1.0.0-W3-553.17：側欄底部第三項「寫入清單」與面板（SPEC-003 §3.12）。
void _registerWriteLogTests() {
  Future<(ProviderContainer, EditSession)> pump(
    WidgetTester tester, {
    FakeValidatorPort? validator,
  }) async {
    final h = (await tester.runAsync(
      () => EditHarness.create(validator: validator ?? FakeValidatorPort()),
    ))!;
    final session = (await tester.runAsync(h.begin))!;
    late ProviderContainer container;
    await _pumpShell(
      tester,
      overrides: [
        editWorkspaceProvider.overrideWith((ref) async => h.workspace),
      ],
      onReady: (c) => container = c,
    );
    await tester.runAsync(() => container.read(editWorkspaceProvider.future));
    await tester.pump();
    return (container, session);
  }

  group('寫入清單項與面板', () {
    testWidgets('底部三項；失敗計數為 0 時無徽章', (tester) async {
      await pump(tester);

      for (final key in [
        'nav-action-preferences',
        'nav-action-shortcuts',
        'nav-action-writeLog',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(
        find.byKey(const Key('badge-writeLog-failure-count')),
        findsNothing,
      );
    });

    testWidgets('點寫入清單項開啟面板（無寫入態），不改導覽狀態', (tester) async {
      final (container, _) = await pump(tester);

      await tester.tap(find.byKey(const Key('nav-action-writeLog')));
      await tester.pump();

      expect(container.read(writeLogOpenProvider), isTrue);
      expect(find.byKey(const Key('state-writeLog-empty')), findsOneWidget);
      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), isNull);
    });

    testWidgets('已有寫入時開啟為清單態', (tester) async {
      final (container, session) = await pump(tester);
      await tester.runAsync(() async {
        await session.writeField(field: 'title', newValue: 'a');
        await session.validationIdle;
      });
      await tester.pump();

      await tester.tap(find.byKey(const Key('nav-action-writeLog')));
      await tester.pump();

      expect(find.byKey(const Key('state-writeLog-list')), findsOneWidget);
      expect(container.read(writeLogOpenProvider), isTrue);
    });

    testWidgets('三面板互斥：開寫入清單先關另兩個，反向亦然', (tester) async {
      final (container, _) = await pump(tester);
      container.read(preferencesOpenProvider.notifier).state = true;
      await tester.pump();
      container.read(writeLogOpenProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(preferencesOpenProvider), isFalse);

      container.read(shortcutsOpenProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(writeLogOpenProvider), isFalse);
      expect(container.read(shortcutsOpenProvider), isTrue);

      container.read(writeLogOpenProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(shortcutsOpenProvider), isFalse);
      expect(container.read(writeLogOpenProvider), isTrue);
    });

    testWidgets('面板關閉後焦點回到寫入清單項', (tester) async {
      final (container, _) = await pump(tester);
      await tester.tap(find.byKey(const Key('nav-action-writeLog')));
      await tester.pump();

      container.read(writeLogOpenProvider.notifier).state = false;
      await tester.pump();
      await tester.pump();

      expect(_itemNode(tester, 'nav-action-writeLog').hasFocus, isTrue);
    });

    testWidgets('驗證失敗回來：徽章出現並顯示計數，面板未開啟也更新', (tester) async {
      final (container, session) = await pump(
        tester,
        validator: FakeValidatorPort(
          ucVerify: [
            validatorOk,
            ValidatorExit(1, ucViolationOutput(unregisteredUc, 1)),
          ],
        ),
      );
      expect(container.read(writeLogOpenProvider), isFalse);

      await tester.runAsync(() async {
        await session.baselineIdle;
        await session.writeField(field: 'title', newValue: 'a');
        await session.validationIdle;
      });
      await tester.pump();

      final badge = find.byKey(const Key('badge-writeLog-failure-count'));
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('1')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  void Function(ProviderContainer container)? onReady,
  List<Override> overrides = const [],
  bool settle = true,
  bool injectDomainState = true,
}) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    ProviderScope(
      overrides: lastWinsByProvider([
        if (injectDomainState)
          domainViewStateProvider.overrideWithInitial(
            (ref) => const DomainReady(mode: DomainMode.matrix),
          ),
        // 殼讀寫入清單（553.17）會間接 watch editWorkspaceProvider；預設不碰
        // 真實 git，需要寫入清單資料的測試自行覆寫。
        editWorkspaceProvider.overrideWith((ref) async => null),
        ...overrides,
      ]),
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

/// primaryFocus 祖先鏈上第一個 `nav-item-*` key 的名稱；不在導覽項內回 null。
String? _focusedNavKey() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  String? found;
  ctx.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && k.value.startsWith('nav-item-')) {
      found = k.value;
      return false;
    }
    return true;
  });
  return found;
}

bool _navHasAccentBorder(WidgetTester tester, String key) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.ancestor(
      of: find.byKey(Key(key)),
      matching: find.byType(DecoratedBox),
    ),
  );
  return boxes.any((b) {
    final d = b.decoration;
    return d is BoxDecoration &&
        d.border is Border &&
        (d.border! as Border).top.color == AppColors.accent;
  });
}

String? _navKeyOf(FocusNode? node) {
  for (final k in _ancestorKeys(node)) {
    if (k is ValueKey<String> && k.value.startsWith('nav-item-')) {
      return k.value;
    }
  }
  return null;
}

List<Key> _ancestorKeys(FocusNode? node) {
  final keys = <Key>[];
  node?.context?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k != null) keys.add(k);
    return true;
  });
  return keys;
}

/// 將焦點放到專案切換入口（SPEC-003 §2.10 Tab 序列的起點）。
/// 底部項（以 testKey 定位）內部持有的焦點節點。
FocusNode _itemNode(WidgetTester tester, String key) {
  final inner = find
      .descendant(of: find.byKey(Key(key)), matching: find.byType(Padding))
      .first;
  return Focus.of(tester.element(inner));
}

Future<void> _focusSwitcherEntry(WidgetTester tester) async {
  final inner = find
      .descendant(
        of: find.byKey(AppShell.projectSwitcherEntryKey),
        matching: find.byType(Padding),
      )
      .first;
  Focus.of(tester.element(inner)).requestFocus();
  await tester.pump();
}

Override _unavailableRepoOverride() =>
    workspaceRepositoryProvider.overrideWithValue(
      StubWorkspaceRepository(
        const WorkspaceUnavailable(lastKnownPath: '/gone', reason: 'missing'),
      ),
    );

void _registerFocusTests() {
  // 0.3.3-W3-397：SPEC-003 §2.10「App 啟動」列——不預設焦點，首次 Tab
  // 落在 project-switcher-entry。
  testWidgets('DomainReady 矩陣啟動後首次 Tab 焦點為 project-switcher-entry', (
    tester,
  ) async {
    await _pumpShell(tester, overrides: _readyOverrides());
    expect(find.byKey(const Key('state-domain-matrix')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      _ancestorKeys(FocusManager.instance.primaryFocus),
      contains(AppShell.projectSwitcherEntryKey),
    );
  });

  testWidgets('點選矩陣格後按 Esc 清除選取，焦點停在原格', (tester) async {
    await _pumpShell(
      tester,
      overrides: [..._readyOverrides(), ...domainFixtureLoaderOverrides()],
    );
    const cellKey = Key('cell-domain-workspace-UC-02');
    await tester.tap(find.byKey(cellKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('panel-domain-cell-detail-empty')),
      findsOneWidget,
    );
    expect(
      _ancestorKeys(FocusManager.instance.primaryFocus),
      contains(cellKey),
    );
  });

  testWidgets('Tab 依序走過六個導覽項（SPEC-003 §2.10）', (tester) async {
    await _pumpShell(tester);
    await _focusSwitcherEntry(tester);
    final seen = <String>[];
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final k = _focusedNavKey();
      if (k != null && !seen.contains(k)) seen.add(k);
    }
    expect(seen, [for (final d in AppDestination.values) 'nav-item-${d.name}']);
  });

  testWidgets('導覽項取得焦點時有 accent 外框，未取得時無（對照）', (tester) async {
    await _pumpShell(tester);
    await _focusSwitcherEntry(tester);
    const first = 'nav-item-domain';
    expect(_navHasAccentBorder(tester, first), isFalse);
    for (var i = 0; i < 12 && _focusedNavKey() != first; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_focusedNavKey(), first);
    expect(_navHasAccentBorder(tester, first), isTrue);
    expect(_navHasAccentBorder(tester, 'nav-item-ucFlow'), isFalse);
  });

  testWidgets('Tab 從專案切換入口依序經七個導覽項、底部三項後進入內容區（SPEC-003 §2.10）', (tester) async {
    await _pumpShell(tester);
    await _focusSwitcherEntry(tester);
    final stops = <FocusNode?>[];
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      stops.add(FocusManager.instance.primaryFocus);
    }
    expect(
      [for (var i = 0; i < 7; i++) _navKeyOf(stops[i])],
      [for (final d in AppDestination.values) 'nav-item-${d.name}'],
    );
    for (final (i, key) in [
      (7, 'nav-action-preferences'),
      (8, 'nav-action-shortcuts'),
      (9, 'nav-action-writeLog'),
    ]) {
      expect(_ancestorKeys(stops[i]), contains(Key(key)));
    }
    for (final stop in [stops[10], stops[11]]) {
      _expectInMainArea(stop);
    }
  });
}

/// 內容區判定：祖先不含 nav-item-* 與入口 key，且全域左緣位於主區。
void _expectInMainArea(FocusNode? node) {
  final ancestors = _ancestorKeys(node);
  expect(ancestors, isNot(contains(AppShell.projectSwitcherEntryKey)));
  expect(
    ancestors.whereType<ValueKey<String>>().where(
      (k) => k.value.startsWith('nav-item-'),
    ),
    isEmpty,
  );
  final box = node!.context!.findRenderObject()! as RenderBox;
  expect(
    box.localToGlobal(Offset.zero).dx,
    greaterThanOrEqualTo(LayoutSize.sidebarWidth),
  );
}

/// `restore()` 回傳外部控制的 Future，模擬 restore 尚未完成的啟動首幀。
class _PendingRestoreRepository extends StubWorkspaceRepository {
  _PendingRestoreRepository(this._pending) : super(const WorkspaceUnset());

  final Future<WorkspaceState> _pending;

  @override
  Future<WorkspaceState> restore() => _pending;
}

/// 經 shell 啟動並判為 DomainReady 的注入（0.3.3-W3-398 起的標準做法）。
List<Override> _readyOverrides() => [
  workspaceRepositoryProvider.overrideWithValue(
    StubWorkspaceRepository(const WorkspaceReady('/ws')),
  ),
  frameworkSignalProbeProvider.overrideWithValue(
    const StubFrameworkSignalProbe(version: '0.0.1', schemaJson: true),
  ),
  builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
  fakeScanRoundOverride(),
];
