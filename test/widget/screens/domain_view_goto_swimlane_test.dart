// 需求：0.5.0-W1-205.2.3；SPEC-001 v1.56〈矩陣與泳道同由掃描輪次衍生〉。
// 路徑 B：詳情卡「在泳道中檢視」於輪次 Running／Idle 時進入泳道，
// 須為正常泳道且定位欄可用（firstNodeInLaneQueryProvider 非 null 的畫面表現）。
// 一律經真實 tap action-domain-cell-goto-swimlane 進入，不直接改 provider。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderScope, ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

const _normal = Key('state-domain-swimlane');
const _unset = Key('state-domain-swimlane-uc-unset');
const _goto = Key('action-domain-cell-goto-swimlane');

void main() {
  late ScanRoundResult roundA;

  setUpAll(() async {
    final event = await loadSnapshotEvent('graph_project_docs_manager');
    roundA = fakeRound(event: event);
  });

  /// 已有完成輪次、矩陣選中間接依賴格（UC-04 × schema）後，詳情卡已顯示。
  Future<(FakeScanRound, ProviderContainer)> pumpWithIndirectCell(
    WidgetTester tester,
  ) async {
    final fake = FakeScanRound(produce: () => roundA, initial: roundA);
    await pumpHarness(
      tester,
      child: const DomainViewScreen(),
      overrides: [
        scanRoundProvider.overrideWith(() => fake),
        domainViewStateProvider.overrideWith(
          (ref) => const DomainReady(mode: DomainMode.matrix),
        ),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DomainViewScreen)),
    );
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    fake.completeExternally(roundA);
    await tester.pump();
    // 選中間接依賴格（UC-04 × schema），詳情卡顯示；進入泳道仍經真實 tap。
    final matrix = container.read(domainMatrixProvider)!;
    final row = matrix.rows.firstWhere((r) => r.domainName == 'schema');
    container.read(domainViewStateProvider.notifier).state = DomainReady(
      mode: DomainMode.matrix,
      selectedCell: (row.domainId, 'UC-04'),
    );
    await tester.pump();
    return (fake, container);
  }

  Future<void> expectGotoIntoUsableSwimlane(WidgetTester tester) async {
    await tester.tap(find.byKey(_goto));
    await tester.pump();
    expect(find.byKey(_normal), findsOneWidget);
    expect(find.byKey(_unset), findsNothing);
    final grid = tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid));
    // 定位欄可用：間接格以來源 domain 查得節點，定位到其欄號與列。
    expect(grid.locateColumn, isNotNull);
    final graphLane = grid.lanes.firstWhere((l) => l.name == 'graph');
    expect(grid.laneHighlight, graphLane.domainId);
  }

  testWidgets('E1 基準：無輪次進行時 tap 進入 → 正常泳道且定位欄可用', (tester) async {
    await pumpWithIndirectCell(tester);
    await expectGotoIntoUsableSwimlane(tester);
  });

  testWidgets('重掃 Running 時 tap 在泳道中檢視 → 正常泳道且定位欄可用', (tester) async {
    final (fake, _) = await pumpWithIndirectCell(tester);
    fake.state = const ScanRoundRunning('/ws/a');
    await tester.pump();
    await expectGotoIntoUsableSwimlane(tester);
  });

  testWidgets('取消重掃（Idle）時 tap 在泳道中檢視 → 正常泳道且定位欄可用', (tester) async {
    final (fake, _) = await pumpWithIndirectCell(tester);
    fake.discard('cancel');
    await tester.pump();
    await expectGotoIntoUsableSwimlane(tester);
  });
}
