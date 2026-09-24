/// 專案切換浮層三個狀態測試（SPEC-001 §7；SPEC-004 §3.6；SPEC-003 §3.7）。
library;

import 'dart:convert';

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

/// 開啟即拋例外的假偏好設定管道，模擬管道本身不可用（對應
/// [ChooseFolderNotRemembered] 的持久化失敗分支）。
class _FakePreferencesPort implements WorkspacePreferencesPort {
  const _FakePreferencesPort();

  @override
  Future<WorkspacePreferencesHandle> open() async {
    throw StateError('fake: preferences unavailable');
  }
}

/// 一組固定的 [RecentProject] 測試資料（SPEC-005 §2.4），取代先前的
/// fixture（`0.2.1-W1-003`）。
final _testRecentProjects = [
  RecentProject(
    path: '/fake/graph_project_docs_manager',
    lastOpenedAt: DateTime.utc(2026, 9, 24),
  ),
  RecentProject(
    path: '/fake/unipos',
    lastOpenedAt: DateTime.utc(2026, 9, 20),
  ),
];

/// 依 SPEC-005 §2.4 schema 編碼 [projects]，供假偏好設定管道回傳
/// `workspace.recentProjects` key 的值。
String _encodeRecentProjects(List<RecentProject> projects) => jsonEncode([
      for (final project in projects)
        {
          'path': project.path,
          'lastOpenedAt': project.lastOpenedAt.toIso8601String(),
        },
    ]);

/// 固定回傳 [recentProjectsJson] 於 `workspace.recentProjects` key 的假
/// 偏好設定管道，其餘 key 一律回傳 `null`（對應「從未選過資料夾」）。
///
/// `AppShell._restoreWorkspaceAndDetect` 啟動時一定會呼叫一次
/// `loadRecentProjects()` 並覆寫 `recentProjectsProvider`（`0.2.1-W1-003`）
/// ——測試若只用 `recentProjectsProvider.overrideWith(...)` 注入初始值，
/// 會被這次啟動覆寫競態取代（未指定 `workspaceRepositoryProvider` 時預設
/// 建構的 [WorkspaceRepository] 走真實 SharedPreferences，結果不可預期）。
/// 本類別讓假 repository 的 `loadRecentProjects()` 收斂到與測試斷言一致
/// 的清單，避免依賴計時。
class _SeededPreferencesPort implements WorkspacePreferencesPort {
  const _SeededPreferencesPort({this.recentProjectsJson});
  final String? recentProjectsJson;

  @override
  Future<WorkspacePreferencesHandle> open() async =>
      _SeededPreferencesHandle(recentProjectsJson);
}

class _SeededPreferencesHandle implements WorkspacePreferencesHandle {
  const _SeededPreferencesHandle(this.recentProjectsJson);
  final String? recentProjectsJson;

  @override
  String? readString(String key) =>
      key == 'workspace.recentProjects' ? recentProjectsJson : null;

  @override
  Future<bool> writeString(String key, String value) async => true;
}

/// 有狀態的假偏好設定管道：寫入真的被記住（存進 [values]），供需要驗證
/// 「寫入後重讀」語意的測試使用（`_SeededPreferencesPort` 的 `writeString`
/// 是無狀態 no-op，驗證不了 `addRecentProject` 成功後 `loadRecentProjects()`
/// 重排的效果，`0.2.1-W1-054`）。
class _StatefulPreferencesPort implements WorkspacePreferencesPort {
  _StatefulPreferencesPort({Map<String, String?>? seed}) : values = seed ?? {};
  final Map<String, String?> values;

  @override
  Future<WorkspacePreferencesHandle> open() async =>
      _StatefulPreferencesHandle(values);
}

class _StatefulPreferencesHandle implements WorkspacePreferencesHandle {
  _StatefulPreferencesHandle(this.values);
  final Map<String, String?> values;

  @override
  String? readString(String key) => values[key];

  @override
  Future<bool> writeString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

/// 供最近專案清單測試使用的假 repository：`loadRecentProjects()` 固定回傳
/// [recents]，`directoryProbe` 固定回報可用（`0.2.1-W1-054` 起，點擊最近
/// 專案項會經 [WorkspaceRepository.openPath] 走與「選擇其他資料夾」相同的
/// 探測路徑，故預設須可用，測試才能斷言成功載入）。
WorkspaceRepository _fakeRepositoryWithRecents(
  List<RecentProject> recents, {
  bool directoryProbeExists = true,
}) {
  return WorkspaceRepository(
    preferencesPort: _SeededPreferencesPort(
      recentProjectsJson: _encodeRecentProjects(recents),
    ),
    directoryProbe: _FakeDirectoryProbePort(probeExists: directoryProbeExists),
  );
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
/// [WorkspaceReady]）的假 repository：選取固定路徑、探測回報可用；
/// `loadRecentProjects()` 回傳 [recentProjects]（預設空清單，見
/// `_SeededPreferencesPort` 文件的競態說明）。
WorkspaceRepository _fakeRepositoryReady({
  bool rememberSucceeds = true,
  List<RecentProject> recentProjects = const [],
}) {
  return WorkspaceRepository(
    pickDirectoryPath: () async => '/fake/workspace',
    preferencesPort: rememberSucceeds
        ? _SeededPreferencesPort(
            recentProjectsJson: _encodeRecentProjects(recentProjects),
          )
        : _FakePreferencesPort(),
    directoryProbe: _FakeDirectoryProbePort(probeExists: true),
  );
}

/// 選取後探測失敗（資料夾不存在）的假 repository。
WorkspaceRepository _fakeRepositoryUnavailable({
  List<RecentProject> recentProjects = const [],
}) {
  return WorkspaceRepository(
    pickDirectoryPath: () async => '/fake/missing',
    preferencesPort: _SeededPreferencesPort(
      recentProjectsJson: _encodeRecentProjects(recentProjects),
    ),
    directoryProbe: _FakeDirectoryProbePort(probeExists: false),
  );
}

/// 使用者取消選取的假 repository（`pickDirectoryPath` 回傳 `null`）。
WorkspaceRepository _fakeRepositoryCancelled({
  List<RecentProject> recentProjects = const [],
}) {
  return WorkspaceRepository(
    pickDirectoryPath: () async => null,
    preferencesPort: _SeededPreferencesPort(
      recentProjectsJson: _encodeRecentProjects(recentProjects),
    ),
  );
}

/// 選取面板本身開不起來的假 repository（`pickDirectoryPath` 拋例外）。
WorkspaceRepository _fakeRepositoryPickerUnavailable({
  List<RecentProject> recentProjects = const [],
}) {
  return WorkspaceRepository(
    pickDirectoryPath: () async => throw PlatformException(code: 'unavailable'),
    preferencesPort: _SeededPreferencesPort(
      recentProjectsJson: _encodeRecentProjects(recentProjects),
    ),
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
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryWithRecents(_testRecentProjects),
          ),
        ],
      );

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
    });
  });

  group('展開態', () {
    testWidgets('渲染持久化最近專案清單，每項為 RecentProjectItem', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryWithRecents(_testRecentProjects),
          ),
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsOneWidget);
      expect(find.byType(RecentProjectItem), findsWidgets);
      expect(find.byType(SwitcherOverlay), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('Esc 收合浮層', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryWithRecents(_testRecentProjects),
          ),
        ],
      );
      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
    });

    testWidgets('點外部收合浮層', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryWithRecents(_testRecentProjects),
          ),
        ],
      );
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
        overrides: [recentProjectsProvider.overrideWith((ref) => const [])],
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

    testWidgets('選擇項目後浮層收合且 currentWorkspaceStateProvider 改變為該項路徑', (
      tester,
    ) async {
      late ProviderContainer container;
      await pumpApp(
        tester,
        overrides: [
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryWithRecents(_testRecentProjects),
          ),
          ..._gateDetectionOverrides,
        ],
      );
      final element = tester.element(find.byType(app_shell.AppShell));
      container = ProviderScope.containerOf(element);

      await tester.tap(find.byKey(app_shell.AppShell.projectSwitcherEntryKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('state-switcher-expanded')), findsNothing);
      final state = container.read(currentWorkspaceStateProvider);
      expect(state, isA<WorkspaceReady>());
      expect(
        (state as WorkspaceReady).path,
        _testRecentProjects[1].path,
      );
    });

    testWidgets(
      '點擊最近專案項走真實載入路徑：實際開啟該路徑、寫已存路徑、成功後'
      '該項移至清單頂端（SPEC-003 §3.7；SPEC-005 §2.4；0.2.1-W1-054 契約 C3）',
      (tester) async {
        late ProviderContainer container;
        // 有狀態偏好設定：驗證「移至頂端」須讓 addRecentProject 的寫入真的
        // 被 loadRecentProjects() 重讀到（_SeededPreferencesPort 是
        // no-op，驗證不了這一步）。
        final preferences = _StatefulPreferencesPort(
          seed: {
            'workspace.recentProjects': _encodeRecentProjects(
              _testRecentProjects,
            ),
          },
        );
        final repository = WorkspaceRepository(
          preferencesPort: preferences,
          directoryProbe: _FakeDirectoryProbePort(probeExists: true),
        );
        await pumpApp(
          tester,
          overrides: [
            recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
            workspaceRepositoryProvider.overrideWithValue(repository),
            ..._gateDetectionOverrides,
          ],
        );
        final element = tester.element(find.byType(app_shell.AppShell));
        container = ProviderScope.containerOf(element);

        await tester.tap(
          find.byKey(app_shell.AppShell.projectSwitcherEntryKey),
        );
        await tester.pumpAndSettle();

        // 點擊非頂端項（index 1，非目前排序第一的項，即 unipos）。
        await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
        await tester.pumpAndSettle();

        // 實際載入：目前工作狀態改為該路徑（非僅標籤變更）。
        final state = container.read(currentWorkspaceStateProvider);
        expect(state, isA<WorkspaceReady>());
        expect((state as WorkspaceReady).path, _testRecentProjects[1].path);

        // 已存路徑改為該 path（下次啟動可讀回）。
        expect(
          preferences.values['workspace.path'],
          _testRecentProjects[1].path,
        );

        // 成功後該項移至清單頂端（addRecentProject 依 lastOpenedAt 降冪）。
        final updatedList = container.read(recentProjectsProvider);
        expect(updatedList.first.path, _testRecentProjects[1].path);
      },
    );

    testWidgets(
      '點擊最近專案項但該路徑不可讀或不存在：依選擇其他失敗列回饋，不轉'
      '狀態、不寫已存路徑、清單不變（SPEC-003 §3.7；0.2.1-W1-054）',
      (tester) async {
        late ProviderContainer container;
        final repository = WorkspaceRepository(
          preferencesPort: _SeededPreferencesPort(
            recentProjectsJson: _encodeRecentProjects(_testRecentProjects),
          ),
          directoryProbe: _FakeDirectoryProbePort(probeExists: false),
        );
        await pumpApp(
          tester,
          overrides: [
            recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
            workspaceRepositoryProvider.overrideWithValue(repository),
          ],
          settle: false,
        );
        final element = tester.element(find.byType(app_shell.AppShell));
        container = ProviderScope.containerOf(element);
        final before = container.read(currentWorkspaceStateProvider);

        await tester.tap(
          find.byKey(app_shell.AppShell.projectSwitcherEntryKey),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('card-switcher-recent-1')));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // 浮層維持展開，不轉狀態，顯示 AppSnackBar。
        expect(
          find.byKey(const Key('state-switcher-expanded')),
          findsOneWidget,
        );
        expect(container.read(currentWorkspaceStateProvider), before);
        expect(find.byType(SnackBar), findsOneWidget);

        // 清單不變（未觸發 addRecentProject 重排；RecentProject 無值相等，
        // 比對 path 順序，非物件實例）。
        expect(
          container.read(recentProjectsProvider).map((p) => p.path).toList(),
          _testRecentProjects.map((p) => p.path).toList(),
        );
      },
    );

    testWidgets(
      '選擇項目後降級與推定版本旗標重置（0.1.0-W2-014／0.2.0-W1-042 寫入端接線）',
      (tester) async {
        late ProviderContainer container;
        await pumpApp(
          tester,
          overrides: [
            recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
            workspaceRepositoryProvider.overrideWithValue(
              _fakeRepositoryWithRecents(_testRecentProjects),
            ),
            ..._gateDetectionOverrides,
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
          recentProjectsProvider.overrideWith((ref) => const []),
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
          recentProjectsProvider.overrideWith((ref) => const []),
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
          recentProjectsProvider.overrideWith((ref) => const []),
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
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryCancelled(recentProjects: _testRecentProjects),
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
          recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
          workspaceRepositoryProvider.overrideWithValue(
            _fakeRepositoryPickerUnavailable(
              recentProjects: _testRecentProjects,
            ),
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
            recentProjectsProvider.overrideWith((ref) => _testRecentProjects),
            workspaceRepositoryProvider.overrideWithValue(
              _fakeRepositoryUnavailable(recentProjects: _testRecentProjects),
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
