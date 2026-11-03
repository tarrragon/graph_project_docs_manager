// 需求：0.6.0-W1-109；SPEC-003 §3.6 掃描輪次更新列、SPEC-006 FR-11。
// 節點詳情資料讀最後完成輪次：重掃中保留上一輪，新輪次完成後替換，切換專案清除。
// 「E1」標註對照輸入。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

void main() {
  late ScanRoundResult roundA;
  late ScanRoundResult roundB;

  setUpAll(() async {
    roundA = fakeRound(
      event: await loadSnapshotEvent('graph_project_docs_manager'),
    );
    roundB = fakeRound();
  });

  (ProviderContainer, FakeScanRound) harness({bool completed = true}) {
    final fake = FakeScanRound(produce: () => roundB);
    final container = ProviderContainer(
      overrides: [scanRoundProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    container.read(scanRoundProvider);
    container.read(lastCompletedRoundProvider);
    if (completed) fake.completeExternally(roundA);
    return (container, fake);
  }

  test('E1 對照：從未完成過輪次，節點為空', () {
    final (c, _) = harness(completed: false);
    expect(c.read(nodeDetailNodesProvider), isEmpty);
  });

  test('輪次完成後有節點', () {
    final (c, _) = harness();
    expect(c.read(nodeDetailNodesProvider), isNotEmpty);
  });

  test('重掃進行中：仍保留上一輪節點', () {
    final (c, fake) = harness();
    final before = c.read(nodeDetailNodesProvider).keys.toSet();
    fake.state = const ScanRoundRunning('/ws/a');
    expect(c.read(nodeDetailNodesProvider).keys.toSet(), before);
    expect(before, isNotEmpty);
  });

  test('新輪次完成：換成新結果', () {
    final (c, fake) = harness();
    final before = c.read(nodeDetailNodesProvider).keys.toSet();
    fake.completeExternally(roundB);
    // roundB 只有 UC-01，與上一輪不同。
    expect(c.read(nodeDetailNodesProvider).keys.toSet(), {'UC-01'});
    expect(before, isNot({'UC-01'}));
  });

  test('切換專案：清除', () {
    final (c, _) = harness();
    c.read(currentWorkspaceStateProvider.notifier).state = const WorkspaceReady(
      '/ws/other',
    );
    expect(c.read(nodeDetailNodesProvider), isEmpty);
  });
}
