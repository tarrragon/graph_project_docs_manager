/// 專案切換浮層三個狀態測試（SPEC-001 §7；SPEC-004 §3.6；SPEC-003 §3.7）。
library;

import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/shell.dart' as app_shell;
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_overlay.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/helpers.dart';

/// 固定回傳 [handle] 的假偏好設定管道；[handle] 為 `null` 時模擬
/// `open()` 拋例外（對應 [ChooseFolderNotRemembered] 的持久化失敗分支）。
class _FakePreferencesPort implements WorkspacePreferencesPort {
  _FakePreferencesPort({this.handle});
  final WorkspacePreferencesHandle? handle;

  @override
  Future<WorkspacePreferencesHandle> open() async {
    final h = handle;
    if (h == null) {
      throw StateError('fake: preferences unavailable');
    }
    return h;
  }
}

class _FakePreferencesHandle implements WorkspacePreferencesHandle {
  @override
  String? readString(String key) => null;

  @override
  Future<bool> writeString(String key, String value) async => true;
}

/// 固定回傳 [probeExists] 的假資料夾探測；`readFirstEntry` 恆為空資料夾成功路徑。
class _FakeDirectoryProbePort implements WorkspaceDirectoryProbePort {
  _FakeDirectoryProbePort({required bool probeExists}) : _exists = probeExists;
  final bool _exists;

  @override
  Future<bool> exists(String path) async => _exists;

  @override
  Future<void> readFirstEntry(String path) async {
    throw StateError('empty'); // 空資料夾路徑：workspace_repository 吞 StateError
  }
}

/// 固定回傳兩訊號皆缺的假 gate 訊號探測；避免 `_handleChosenState` 的
/// `detect()` 呼叫碰觸真實檔案系統（0.2.0-W1-042：真實 [File] I/O 不受
/// `pumpAndSettle` 的假時鐘控制，曾導致本檔測試 flaky）。
class _FakeSignalProbe implements FrameworkSignalProbePort {
  const _FakeSignalProbe();

  @override
  Future<String?> readVersion(String workspacePath) async => null;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => false;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => null;
}

/// `_handleChosenState` 呼叫 `detect()` 所需的確定性 provider 覆寫
/// （0.2.0-W1-042）：避免碰觸真實檔案系統與內嵌資產。
final _gateDetectionOverrides = <Override>[
  frameworkSignalProbeProvider.overrideWithValue(const _FakeSignalProbe()),
  builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
];

/// 組成一個回傳 [ChooseFolderSelected]／[ChooseFolderNotRemembered]（皆包
/// [WorkspaceReady]）的假 repository：選取固定路徑、探測回報可用。
WorkspaceRepository _fakeRepositoryReady({bool rememberSucceeds = true}) {
  return WorkspaceRepository(
    pickDirectoryPath: () async => '/fake/workspace',
    preferencesPort: rememberSucceeds
        ? _FakePreferencesPort(handle: _FakePreferencesHandle())
        : _FakePreferencesPort(),
    directoryProbe: _FakeDirectoryProbePort(probeExists: true),
  );
}

/// 選取後探測失敗（資料夾不存在）的假 repository。
WorkspaceRepository _fakeRepositoryUnavailable() {
  return WorkspaceRepository(
    pickDirectoryPath: () async => '/fake/missing',
    preferencesPort: _FakePreferencesPort(handle: _FakePreferencesHandle()),
    directoryProbe: _FakeDirectoryProbePort(probeExists: false),
  );
}

/// 使用者取消選取的假 repository（`pickDirectoryPath` 回傳 `null`）。
WorkspaceRepository _fakeRepositoryCancelled() {
  return WorkspaceRepository(pickDirectoryPath: () async => null);
}

/// 選取面板本身開不起來的假 repository（`pickDirectoryPath` 拋例外）。
WorkspaceRepository _fakeRepositoryPickerUnavailable() {
  return WorkspaceRepository(
    pickDirectoryPath: () async => throw PlatformException(code: 'unavailable'),
  );
}

void main() {
  group('收合態', () {
    testWidgets('側欄入口存在，浮層未掛載', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(app_shell.AppShell.projectSwitcherEntryKey), findsOneWidget);
      expect(
        find.byKey(const Key('state-switcher-expanded')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
      expectNoOverflow(tester);
    });

    testWidgets('點擊入口展開浮層', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
    });
  });

  group('展開態', () {
    testWidgets('渲染 fixture 最近專案清單，每項為 RecentProjectItem', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
      expect(find.byType(RecentProjectItem), findsWidgets);
      expect(find.byType(SwitcherOverlay), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('Esc 收合浮層', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
    });

    testWidgets('點外部收合浮層', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      // 點主區內容（浮層外任一處）。
      await tester.tapAt(const Offset(900, 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
    });

    testWidgets('點背景導覽項：浮層收合、不切換頁面（0.1.0-W3-335.47 D13）', (
      tester,
    ) async {
      // 用「無最近專案」清單將浮層高度收到最小（僅標題＋按鈕），確保浮層
      // 不會視覺覆蓋到最後一個導覽項，本測試才能斷言「點在浮層外的導覽
      // 項」而非「點在浮層自身空白區」。
      await pumpApp(
        tester,
        overrides: [recentProjectsProvider.overrideWithValue(const [])],
      );
      final element = tester.element(find.byType(app_shell.AppShell));
      final container = ProviderScope.containerOf(element);
      final before = container.read(selectedDestinationProvider);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('nav-item-nodeDetail')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-no-recent')), findsNothing);
      expect(container.read(selectedDestinationProvider), before);
    });

    testWidgets('選擇項目後浮層收合且 currentProjectIndexProvider 改變', (
      tester,
    ) async {
      late ProviderContainer container;
      await pumpApp(
        tester,
        overrides: [],
      );
      final element = tester.element(find.byType(app_shell.AppShell));
      container = ProviderScope.containerOf(element);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
      expect(container.read(currentProjectIndexProvider), 1);
    });

    testWidgets(
      '選擇項目後降級與推定版本旗標重置（0.1.0-W2-014／0.2.0-W1-042 寫入端接線）',
      (tester) async {
        late ProviderContainer container;
        await pumpApp(
          tester,
          overrides: [
            degradedSchemaProvider.overrideWith((ref) => true),
            degradedSchemaVersionsProvider.overrideWith(
              (ref) => const DegradedSchemaVersions(
                builtinVersion: '0.0.1',
                projectVersion: '0.0.1',
              ),
            ),
            inferredVersionProvider.overrideWith((ref) => '0.0.1'),
          ],
        );
        final element = tester.element(find.byType(app_shell.AppShell));
        container = ProviderScope.containerOf(element);

        // 本斷言在寫入端未接線時應翻紅——切換前旗標為真，若重置端未接線，
        // 選擇專案後旗標仍維持真。
        expect(container.read(degradedSchemaProvider), isTrue);
        expect(container.read(inferredVersionProvider), isNotNull);

        await tester.tap(
          find.byKey(app_shell.AppShell.projectSwitcherEntryKey),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
        await tester.pumpAndSettle();

        expect(container.read(degradedSchemaProvider), isFalse);
        expect(container.read(degradedSchemaVersionsProvider), isNull);
        expect(container.read(inferredVersionProvider), isNull);
      },
    );
  });

  group('無最近專案態', () {
    testWidgets('清單為空時渲染 SwitcherOverlay 零項 + 選擇資料夾按鈕', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
        ],
      );

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsOneWidget,
      );
      expect(find.byType(RecentProjectItem), findsNothing);
      expect(
        find.byKey(const Key('action-switcher-choose-folder')),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });

    testWidgets('Esc 收合浮層', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
    });

    testWidgets('選擇資料夾按鈕接線 WorkspaceRepository，選定可用資料夾後收合浮層', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWithValue(const []),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryReady(),
          ),
          ..._gateDetectionOverrides,
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('state-switcher-no-recent')),
        findsNothing,
      );
    });
  });

  group('選擇其他資料夾（ChooseFolderResult 四變體，SPEC-003 §3.7）', () {
    testWidgets('ChooseFolderCancelled：浮層維持展開，不顯示 AppSnackBar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryCancelled(),
          ),
        ],
        settle: false,
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('ChooseFolderUnavailable：浮層維持展開，顯示 AppSnackBar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryPickerUnavailable(),
          ),
        ],
        settle: false,
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('ChooseFolderSelected(WorkspaceReady)：浮層收合，不顯示 AppSnackBar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryReady(),
          ),
          ..._gateDetectionOverrides,
        ],
        settle: false,
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'ChooseFolderSelected(WorkspaceReady)：detect() 被呼叫，domainViewStateProvider '
      '與 inferredVersionProvider 反映結果（0.2.0-W1-042）',
      (tester) async {
        late ProviderContainer container;
        await pumpApp(
          tester,
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(
              _fakeRepositoryReady(),
            ),
            frameworkSignalProbeProvider.overrideWithValue(
              const _FakeSignalProbe(),
            ),
          ],
          settle: false,
        );
        final element = tester.element(find.byType(app_shell.AppShell));
        container = ProviderScope.containerOf(element);

        await tester.tap(
          find.byKey(app_shell.AppShell.projectSwitcherEntryKey),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('action-switcher-choose-folder')),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // `_FakeSignalProbe` 回傳兩訊號皆缺 → DomainNotFramework，證明
        // `_handleChosenState` 確實呼叫了 `detect()`（而非只重置旗標）。
        expect(
          container.read(domainViewStateProvider),
          isA<DomainNotFramework>(),
        );
        expect(container.read(inferredVersionProvider), isNull);
      },
    );

    testWidgets(
      'ChooseFolderSelected(WorkspaceUnavailable)：浮層維持展開，顯示 AppSnackBar',
      (tester) async {
        await pumpApp(
          tester,
          overrides: [
            workspaceRepositoryProvider.overrideWithValue(
              _fakeRepositoryUnavailable(),
            ),
          ],
          settle: false,
        );
        await tester.tap(
          find.byKey(app_shell.AppShell.projectSwitcherEntryKey),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('action-switcher-choose-folder')),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const Key('state-switcher-expanded')),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets('ChooseFolderNotRemembered：浮層收合，顯示 AppSnackBar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryReady(rememberSucceeds: false),
          ),
          ..._gateDetectionOverrides,
        ],
        settle: false,
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('action-switcher-choose-folder')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
