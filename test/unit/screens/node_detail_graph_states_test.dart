// 需求：0.6.0-W1-155；SPEC-001 §6 判定順序 2、4，SPEC-004 §3.6 兩列。
// 節點詳情「圖不可用」「節點不在目前的圖上」兩狀態。「E1」標註對照輸入。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

const _unavailable = GraphBuildUnavailable(
  EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
);

GraphBuildResult get _available => GraphBuildAvailable(
  GraphBuiltEvent(
    nodes: const [fakeUcNode],
    edges: const [],
    graphDefects: const [],
    totalReferences: 0,
    resolvedCount: 0,
  ),
);

Future<dynamic> _pump(
  WidgetTester tester, {
  required ScanRoundResult round,
  required String nodeId,
}) async {
  final fake = FakeScanRound(produce: () => round);
  final container = await pumpHarness(
    tester,
    child: const NodeDetailScreen(),
    overrides: [
      scanRoundProvider.overrideWith(() => fake),
      builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
      // 正常態的編輯入口會讀唯讀降級旗標；此檔不測編輯，隔離真實 git 探測。
      readonlyWorkspaceReasonProvider.overrideWithValue(null),
      nodeDetailStateProvider.overrideWithInitial(
        (ref) => NodeDetailReady(nodeId: nodeId),
      ),
      selectedDestinationProvider.overrideWithInitial(
        (ref) => AppDestination.nodeDetail,
      ),
    ],
  );
  container.read(currentWorkspaceStateProvider.notifier).state =
      const WorkspaceReady('/ws/fake');
  container.read(scanRoundProvider);
  container.read(lastCompletedRoundProvider);
  fake.completeExternally(round);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const base = NodeDetailReady(nodeId: 'UC-01');

  group('狀態衍生（deriveNodeDetailState）', () {
    test('建圖不可用 -> NodeDetailGraphUnavailable', () {
      final s = deriveNodeDetailState(
        base: base,
        graph: _unavailable,
        nodeIds: const [],
      );
      expect(s, isA<NodeDetailGraphUnavailable>());
    });

    test('建圖不可用且未選節點：順序 2 優先於未選節點', () {
      final s = deriveNodeDetailState(
        base: const NodeDetailUnset(),
        graph: _unavailable,
        nodeIds: const [],
      );
      expect(s, isA<NodeDetailGraphUnavailable>());
    });

    test('建圖可用但 id 不在圖上 -> NodeDetailNodeAbsent', () {
      final s = deriveNodeDetailState(
        base: const NodeDetailReady(nodeId: 'GONE-1'),
        graph: _available,
        nodeIds: const ['UC-01'],
      );
      expect(s, isA<NodeDetailNodeAbsent>());
      expect((s as NodeDetailNodeAbsent).nodeId, 'GONE-1');
    });

    test('E1 對照：id 在圖上 -> Ready', () {
      final s = deriveNodeDetailState(
        base: base,
        graph: _available,
        nodeIds: const ['UC-01'],
      );
      expect(s, isA<NodeDetailReady>());
    });

    test('專案未就緒優先於圖不可用', () {
      final s = deriveNodeDetailState(
        base: const NodeDetailProjectUnready(ProjectUnreadyReason.notSelected),
        graph: _unavailable,
        nodeIds: const [],
      );
      expect(s, isA<NodeDetailProjectUnready>());
    });
  });

  group('畫面', () {
    testWidgets('圖不可用：錨點、訊息、前往 Domain 視圖', (tester) async {
      final container = await _pump(
        tester,
        round: fakeRound(
          graphUnavailable:
              EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
        ),
        nodeId: 'UC-01',
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(EmptyState)));
      expect(
        find.byKey(const Key('state-nodeDetail-graph-unavailable')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.nodeDetailGraphUnavailableMessage('0.0.1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('action-nodeDetail-goto-domain')));
      await tester.pump();
      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
    });

    testWidgets('節點不在圖上：錨點、訊息、說明、前往追溯視圖', (tester) async {
      final container = await _pump(
        tester,
        round: fakeRound(),
        nodeId: 'GONE-1',
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(EmptyState)));
      expect(
        find.byKey(const Key('state-nodeDetail-node-absent')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.nodeDetailNodeAbsentMessage('GONE-1')),
        findsOneWidget,
      );
      expect(find.text(l10n.nodeDetailNodeAbsentHint), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('action-nodeDetail-goto-traceability')),
      );
      await tester.pump();
      expect(
        container.read(selectedDestinationProvider),
        AppDestination.traceability,
      );
    });

    testWidgets('E1 對照：id 在圖上不出現兩個新錨點', (tester) async {
      await _pump(tester, round: fakeRound(), nodeId: 'UC-01');
      expect(
        find.byKey(const Key('state-nodeDetail-node-absent')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('state-nodeDetail-graph-unavailable')),
        findsNothing,
      );
    });
  });
}
