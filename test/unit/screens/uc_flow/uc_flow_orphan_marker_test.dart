// UC Flow 事件流小表孤立事件標記（0.5.0-W1-451，SPEC-003 §3.2）：判準由
// Diagnostics 偵測端決定，畫面只查詢；輪次未完成或建圖不可用時零標記。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/diagnostics/event_gap.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';

import '../../../helpers/gap_round_fakes.dart';
import '../../../helpers/helpers.dart';

const _orphanKey = Key('badge-ucFlow-event-orphan-evt.a');
const _otherKey = Key('badge-ucFlow-event-orphan-evt.b');

ScanRoundResult _round({EdgeTypeUnavailableReason? unavailable}) {
  const node = LightNode(
    id: 'UC-01',
    typeName: 'UC',
    status: null,
    title: 'uc',
    path: 'docs/usecases/UC-01-open-project-and-reach-usable-state.md',
  );
  final subgraphs = buildFlowSubgraphs(
    [
      RawNode(
        path: node.path,
        frontmatter: const {'id': 'UC-01'},
        typeName: 'UC',
        flowSteps: const [
          {
            'id': 's1',
            'name': 'n1',
            'emits': ['evt.a', 'evt.b'],
          },
        ],
      ),
    ],
    {'UC-01'},
    DomainNameResolver.empty(),
  ).subgraphs;
  return fakeRound(
    nodes: const [node],
    graphUnavailable: unavailable,
    event: GraphBuiltEvent(
      nodes: const [node],
      edges: const [],
      graphDefects: const [],
      totalReferences: 0,
      resolvedCount: 0,
      flowSubgraphs: subgraphs,
    ),
  );
}

Override _roundOverride(ScanRoundResult round) => scanRoundProvider
    .overrideWith(() => FakeScanRound(produce: () => round, initial: round));

Future<void> _pump(WidgetTester tester, List<Override> overrides) =>
    pumpHarness(
      tester,
      child: const UcFlowScreen(),
      overrides: [
        selectedUcProvider.overrideWith((ref) => 'UC-01'),
        ...overrides,
      ],
    );

void main() {
  testWidgets('E2：孤立事件有標記，同表非孤立事件無標記', (tester) async {
    await _pump(tester, [
      _roundOverride(_round()),
      ucFlowEventGapsProvider.overrideWithValue(
        EventGapReport(
          orphanEvents: [
            OrphanEventGap(
              evtId: 'evt.a',
              shape: OrphanEventShape.emittedNotConsumed,
              ucIds: const ['UC-01'],
            ),
          ],
          mismatches: const [],
        ),
      ),
    ]);

    expect(find.byKey(const Key('row-ucFlow-event-evt.a')), findsOneWidget);
    expect(find.byKey(const Key('row-ucFlow-event-evt.b')), findsOneWidget);
    expect(find.byKey(_orphanKey), findsOneWidget);
    expect(find.byKey(_otherKey), findsNothing);
  });

  testWidgets('E2：輪次完成但偵測零筆 → 無任何標記', (tester) async {
    await _pump(tester, [_roundOverride(_round())]);

    expect(find.byKey(const Key('row-ucFlow-event-evt.a')), findsOneWidget);
    expect(find.byKey(_orphanKey), findsNothing);
    expect(find.byKey(_otherKey), findsNothing);
  });

  test('E2：輪次未完成 → provider 回零筆', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(ucFlowEventGapsProvider).orphanEvents, isEmpty);
  });

  test('E2：建圖不可用 → provider 回零筆', () {
    final round = _round(unavailable: EdgeTypeUnavailableReason.values.first);
    final container = ProviderContainer(overrides: [_roundOverride(round)]);
    addTearDown(container.dispose);
    container.read(scanRoundProvider);

    expect(container.read(ucFlowEventGapsProvider).isOrphan('evt.a'), isFalse);
  });
}
