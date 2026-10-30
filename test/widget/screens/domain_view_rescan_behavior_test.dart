// 需求：0.5.0-W1-205.2.1 acceptance 2／3；SPEC-001 v1.55〈矩陣與泳道同由掃描輪次衍生〉。
// 畫面層行為：只經 scanRoundProvider／selectedUcProvider／domainViewStateProvider
// 驅動（新舊程式碼皆存在的入口），以狀態錨點與元件屬性斷言。
// 「E1」標註對照輸入（test-assertion-design-rules）。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderScope, ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

const _normal = Key('state-domain-swimlane');
const _unset = Key('state-domain-swimlane-uc-unset');

void main() {
  late ScanRoundResult roundA;
  late ScanRoundResult roundB;

  setUpAll(() async {
    final event = await loadSnapshotEvent('graph_project_docs_manager');
    roundA = fakeRound(event: event);
    roundB = fakeRound(
      nodes: const [
        LightNode(
          id: 'UC-02',
          typeName: 'UC',
          status: null,
          title: '新一輪標題',
          path: 'docs/usecases/UC-02-assess-change-impact-by-domain.md',
        ),
      ],
    );
  });

  Future<(FakeScanRound, ProviderContainer)> pumpOnRoundA(
    WidgetTester tester,
  ) async {
    final fake = FakeScanRound(produce: () => roundB, initial: roundA);
    await pumpHarness(
      tester,
      child: const DomainViewScreen(),
      overrides: [
        scanRoundProvider.overrideWith(() => fake),
        domainViewStateProvider.overrideWith(
          (ref) => const DomainReady(mode: DomainMode.swimlane),
        ),
        selectedUcProvider.overrideWith((ref) => 'UC-02'),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DomainViewScreen)),
    );
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/a');
    fake.completeExternally(roundA);
    await tester.pump();
    return (fake, container);
  }

  SwimlaneGrid grid(WidgetTester tester) =>
      tester.widget<SwimlaneGrid>(find.byType(SwimlaneGrid));

  testWidgets('E1 基準：已選定 UC 且有完成輪次 → 正常泳道', (tester) async {
    await pumpOnRoundA(tester);
    expect(find.byKey(_normal), findsOneWidget);
    expect(find.byKey(_unset), findsNothing);
  });

  testWidgets('重掃進入 Running：仍是正常泳道，不顯示需先選定 UC', (tester) async {
    final (fake, _) = await pumpOnRoundA(tester);
    fake.state = const ScanRoundRunning('/ws/a');
    await tester.pump();
    expect(find.byKey(_normal), findsOneWidget);
    expect(find.byKey(_unset), findsNothing);
  });

  testWidgets('取消重掃（Idle）：仍是正常泳道', (tester) async {
    final (fake, _) = await pumpOnRoundA(tester);
    fake.discard('cancel');
    await tester.pump();
    expect(find.byKey(_normal), findsOneWidget);
    expect(find.byKey(_unset), findsNothing);
  });

  testWidgets('新一輪完成：面板標題與高亮名取自新一輪', (tester) async {
    final (fake, container) = await pumpOnRoundA(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DomainViewScreen)),
    );
    final domainLane = grid(tester).lanes
        .firstWhere((l) => l.kind == SwimlaneLaneKind.domain);
    container.read(domainViewStateProvider.notifier).state = DomainReady(
      mode: DomainMode.swimlane,
      selectedDomainId: domainLane.domainId,
    );
    await tester.pump();

    // 舊輪：快照 UC-02 無標題，面板標題僅 UC id；高亮名為該 domain 的列首。
    expect(find.text('UC-02'), findsOneWidget);
    expect(grid(tester).laneHighlight, domainLane.domainId);

    fake.completeExternally(roundB);
    await tester.pump();

    // 新輪的 UC-02 標題不同、且沒有該 domain：標題取新輪，高亮名查無。
    expect(find.text('UC-02'), findsNothing);
    expect(
      find.text(l10n.swimlanePanelTitle('UC-02', '新一輪標題')),
      findsOneWidget,
    );
    // 新輪的 UC-02 無 flow：泳道格線隨新輪消失，不殘留舊輪列與高亮。
    expect(find.byType(SwimlaneGrid), findsNothing);
  });
}
