/// 選定工作區共用流程的成功路徑副作用（0.5.0-W1-206.1）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/workspace_selection.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/app/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

class _SpyScanRound extends ScanRoundNotifier {
  final List<String> reasons = [];

  @override
  void discard([String reason = 'cancel']) {
    reasons.add(reason);
    super.discard(reason);
  }
}

class _SpyGate extends GateDetectionNotifier {
  final List<String> paths = [];

  @override
  Future<void> detect(String workspacePath) async {
    paths.add(workspacePath);
  }
}

class _FakeRepository extends WorkspaceRepository {
  _FakeRepository({required this.addResult, required this.recents});

  final bool addResult;
  final List<RecentProject> recents;
  final List<String> added = [];

  @override
  Future<bool> addRecentProject(String path) async {
    added.add(path);
    return addResult;
  }

  @override
  Future<List<RecentProject>> loadRecentProjects() async => recents;
}

typedef _Run = ({
  ProviderContainer container,
  _SpyScanRound round,
  _SpyGate gate,
  _FakeRepository repo,
});

void main() {
  const path = '/tmp/proj';
  final recents = [
    RecentProject(path: path, lastOpenedAt: DateTime(2026, 1, 1)),
  ];

  Future<_Run> run(WidgetTester tester, {bool addResult = true}) async {
    final round = _SpyScanRound();
    final gate = _SpyGate();
    final repo = _FakeRepository(addResult: addResult, recents: recents);
    final container = ProviderContainer(
      overrides: [
        scanRoundProvider.overrideWith(() => round),
        gateDetectionNotifierProvider.overrideWith(() => gate),
        workspaceRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(degradedSchemaProvider.notifier).state = true;
    container.read(inferredVersionProvider.notifier).state = '9.9.9';
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    await selectWorkspace(captured, const WorkspaceReady(path));
    return (container: container, round: round, gate: gate, repo: repo);
  }

  testWidgets('成功路徑：工作區、旗標重置、輪次丟棄、gate、最近清單', (tester) async {
    final r = await run(tester);
    final c = r.container;
    expect(c.read(currentWorkspaceStateProvider), isA<WorkspaceReady>());
    expect(c.read(degradedSchemaProvider), isFalse);
    expect(c.read(degradedSchemaVersionsProvider), isNull);
    expect(c.read(inferredVersionProvider), isNull);
    expect(r.round.reasons, ['project-reselected']);
    expect(r.gate.paths, [path]);
    expect(r.repo.added, [path]);
    expect(c.read(recentProjectsProvider).single.path, path);
  });

  testWidgets('最近清單寫入失敗：不更新清單，其餘副作用照常', (tester) async {
    final r = await run(tester, addResult: false);
    expect(r.container.read(recentProjectsProvider), isEmpty);
    expect(r.gate.paths, [path]);
  });
}
