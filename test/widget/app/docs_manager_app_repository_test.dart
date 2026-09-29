import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

/// 0.3.3-W3-379：DocsManagerApp.repository 注入點必須生效。
class _SpyRepository implements WorkspaceRepository {
  _SpyRepository(this.state);

  final WorkspaceState state;
  int restoreCalls = 0;

  @override
  Future<WorkspaceState> restore() async {
    restoreCalls++;
    return state;
  }

  @override
  Future<List<RecentProject>> loadRecentProjects() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  testWidgets('注入替身時 restore 被呼叫且 state 為替身 state', (tester) async {
    tester.view.physicalSize = kMinWindowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const injected = WorkspaceUnavailable(
      lastKnownPath: '/injected/stub',
      reason: 'stub',
    );
    final spy = _SpyRepository(injected);

    await tester.pumpWidget(
      ProviderScope(child: DocsManagerApp(repository: spy)),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(spy.restoreCalls, 1);
    expect(container.read(currentWorkspaceStateProvider), same(injected));
  });
}
