import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/workspace/framework_signal_probe.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:integration_test/integration_test.dart';

/// 0.6.0-W1-193.3：Ticket 清單捲動與排序的 Profiler 探針（SPEC-004 §2）。
///
/// 執行（profile 模式，量測由 PM 實機跑）：
/// `fvm flutter drive --profile -d macos --driver=test_driver/perf_driver.dart
///  --target=integration_test/perf/ticket_list_perf_test.dart`
/// 專案路徑以 `--dart-define=PERF_PROJECT_PATH=<path>` 覆寫。
const String _projectPath = String.fromEnvironment(
  'PERF_PROJECT_PATH',
  defaultValue: '/Users/mac-eric/project/graph_project_docs_manager',
);

/// 為 true 時，量測區段內開啟 widget build / layout 的 Timeline 事件，
/// 供定位熱點 widget；預設 false，量測行為不變。
/// 啟用：`--dart-define=PERF_PROFILE_WIDGETS=true`
const bool _profileWidgets = bool.fromEnvironment('PERF_PROFILE_WIDGETS');

const Duration _scanTimeout = Duration(minutes: 3);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ticket 清單捲動與排序效能探針', (tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(1920, 1080) * 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final builtinVersion = await _readBuiltinSchemaVersion();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          frameworkSignalProbeProvider.overrideWithValue(
            _ReadyProbe(builtinVersion),
          ),
        ],
        child: DocsManagerApp(
          repository: _FixedWorkspaceRepository(WorkspaceReady(_projectPath)),
        ),
      ),
    );
    await _settleLong(tester);

    await tester.tap(find.byKey(const Key('nav-item-tickets')));
    await _settleLong(tester);
    final listFinder = find.byKey(const Key('scroll-tickets-list'));
    expect(listFinder, findsOneWidget, reason: '應已導至 Ticket 清單列表模式');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DocsManagerApp)),
    );
    final listState = container.read(ticketListStateProvider);
    expect(listState, isA<TicketsReady>(), reason: '清單應為載入完成態');
    final rowCount = (listState as TicketsReady).tickets.length;
    binding.reportData = <String, dynamic>{'ticket_list_row_count': rowCount};
    expect(rowCount, greaterThan(0));

    final restoreProfiling = _enableWidgetProfiling();
    addTearDown(restoreProfiling);
    await binding.traceAction(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(listFinder, const Offset(0, -2000), 4000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(listFinder, const Offset(0, 2000), 4000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'ticket_list_scroll');

    await binding.traceAction(() async {
      for (final key in const ['id', 'title', 'status', 'priority']) {
        await tester.tap(find.byKey(Key('action-tickets-sort-$key')));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'ticket_list_sort');
    restoreProfiling();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// 依 [_profileWidgets] 開啟 widget 級 profiling，回傳還原函式（可重複呼叫）。
VoidCallback _enableWidgetProfiling() {
  if (!_profileWidgets) return () {};
  final builds = debugProfileBuildsEnabled;
  final userBuilds = debugProfileBuildsEnabledUserWidgets;
  final layouts = debugProfileLayoutsEnabled;
  debugProfileBuildsEnabled = true;
  debugProfileBuildsEnabledUserWidgets = true;
  debugProfileLayoutsEnabled = true;
  return () {
    debugProfileBuildsEnabled = builds;
    debugProfileBuildsEnabledUserWidgets = userBuilds;
    debugProfileLayoutsEnabled = layouts;
  };
}

Future<void> _settleLong(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  _scanTimeout,
);

Future<String> _readBuiltinSchemaVersion() async {
  final container = ProviderContainer();
  try {
    return await container.read(builtinSchemaVersionProvider.future);
  } finally {
    container.dispose();
  }
}

class _ReadyProbe implements FrameworkSignalProbePort {
  const _ReadyProbe(this._version);

  final String _version;

  @override
  Future<String?> readVersion(String workspacePath) async => _version;

  @override
  Future<bool> schemaJsonExists(String workspacePath) async => true;

  @override
  Future<String?> readSchemaJsonVersion(String workspacePath) async => _version;
}

/// 固定回傳指定工作區，避免讀寫使用者 UserDefaults。
class _FixedWorkspaceRepository implements WorkspaceRepository {
  _FixedWorkspaceRepository(this._state);

  final WorkspaceState _state;

  @override
  Future<WorkspaceState> restore() async => _state;

  @override
  Future<ChooseFolderResult> chooseFolder() async =>
      ChooseFolderSelected(_state);

  @override
  Future<ChooseFolderResult> openPath(String path) async =>
      ChooseFolderSelected(_state);

  @override
  Future<List<RecentProject>> loadRecentProjects() async => const [];

  @override
  Future<bool> addRecentProject(String path) async => true;

  @override
  Future<RecentProjectAvailability> probeRecentProject(String path) async =>
      const RecentProjectAvailable();

  @override
  Future<bool> saveRecentProjectCounts(
    String path,
    RecentProjectCounts counts,
  ) async => false;
}
