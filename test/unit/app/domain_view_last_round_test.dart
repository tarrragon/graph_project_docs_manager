// 需求：0.5.0-W1-205.2.1；SPEC-001 v1.55 §1〈矩陣與泳道同由掃描輪次衍生〉。
// Domain 矩陣與泳道同讀「同一專案最後一次完成的掃描輪次」：重掃中、取消重掃、
// 輪次失敗保留上一輪；新一輪完成後兩者同輪；切換專案清除。
// 「E1」標註對照輸入（test-assertion-design-rules）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

class _H {
  _H(this.container, this.fake);
  final ProviderContainer container;
  final FakeScanRound fake;

  List<String> get columns => [
    for (final c in container.read(domainMatrixProvider)?.columns ?? const [])
      c.id,
  ];
  DomainSwimlaneView? get swimlane => container.read(domainSwimlaneProvider);
}

void main() {
  late ScanRoundResult roundA;
  late ScanRoundResult roundB;

  setUpAll(() async {
    roundA = fakeRound(
      event: await loadSnapshotEvent('graph_project_docs_manager'),
    );
    roundB = fakeRound();
  });

  _H harness({ScanRoundResult? Function()? produce}) {
    final fake = FakeScanRound(produce: produce ?? () => roundB);
    final container = ProviderContainer(
      overrides: [scanRoundProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    container.read(scanRoundProvider);
    container.read(lastCompletedRoundProvider);
    container.read(selectedUcProvider.notifier).state = 'UC-02';
    fake.completeExternally(roundA);
    return _H(container, fake);
  }

  final colsA = ['UC-01', 'UC-02', 'UC-03', 'UC-04', 'UC-05', 'UC-06'];

  test('E1 基準：完成輪次後矩陣與泳道皆有資料', () {
    final h = harness();
    expect(h.columns, colsA);
    expect(h.swimlane, isA<DomainSwimlane>());
  });

  test('重掃進行中：矩陣與泳道仍顯示上一輪', () {
    final h = harness();
    h.fake.state = const ScanRoundRunning('/ws/a');
    expect(h.columns, colsA);
    expect(h.swimlane, isA<DomainSwimlane>());
  });

  test('取消重掃（輪次回 Idle）：矩陣與泳道仍顯示上一輪', () {
    final h = harness();
    h.fake.discard('cancel');
    expect(h.container.read(scanRoundProvider), isA<ScanRoundIdle>());
    expect(h.columns, colsA);
    expect(h.swimlane, isA<DomainSwimlane>());
  });

  test('輪次失敗：矩陣與泳道仍顯示上一輪', () async {
    final h = harness(produce: () => throw StateError('boom'));
    await expectLater(h.fake.rescan(), throwsStateError);
    expect(h.container.read(scanRoundProvider), isA<ScanRoundIdle>());
    expect(h.columns, colsA);
    expect(h.swimlane, isA<DomainSwimlane>());
  });

  test('新一輪完成：矩陣與泳道同換為新一輪', () {
    final h = harness();
    h.fake.completeExternally(roundB);
    expect(h.columns, isNot(colsA));
    expect(h.columns, ['UC-01']);
    // B 輪沒有 UC-02：泳道隨新輪次重算為無 flow，而非沿用 A 輪。
    expect(h.swimlane, isA<DomainSwimlaneUnstructured>());
  });

  test('切換專案：最後完成輪次清除', () {
    final h = harness();
    h.container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/other');
    expect(h.container.read(lastCompletedRoundProvider), isNull);
    expect(h.container.read(domainMatrixProvider), isNull);
    expect(h.swimlane, isNull);
  });

  test('同專案重設路徑相同的工作區：不清除', () {
    final h = harness();
    h.container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    expect(h.columns, colsA);
  });

  test('未選定 UC 的空泳道列與正常泳道同列序', () {
    final h = harness();
    final empty = h.container.read(domainEmptyLanesProvider);
    h.container.read(selectedUcProvider.notifier).state = 'UC-02';
    final normal = (h.swimlane! as DomainSwimlane).lanes;
    List<String?> ids(List<DomainLane> l) => [
      for (final x in l)
        if (x.kind == DomainLaneKind.domain) x.domainId,
    ];
    expect(empty.first.kind, DomainLaneKind.screen);
    expect(ids(empty), ids(normal));
    expect(empty.every((l) => l.nodes.isEmpty), isTrue);
  });
}
