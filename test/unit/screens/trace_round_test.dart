// 需求：0.6.0-W1-114；SPEC-001 §3〈四層樹由掃描輪次衍生〉五步判定順序與
// 三跳取法。追溯視圖讀最後完成輪次的圖，不讀 trace_fixtures.dart 預設。
// 「E1」標註對照輸入。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_screen.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

LightNode _light(String id, String type) => LightNode(
  id: id,
  typeName: type,
  status: 'draft',
  title: '$id title',
  path: 'docs/$id.md',
);

RawNode _raw(String id, String type, [Map<String, dynamic> extra = const {}]) =>
    RawNode(
      path: 'docs/$id.md',
      frontmatter: {'id': id, ...extra},
      typeName: type,
    );

/// 以 [raws] 為欄位來源、[lights] 為圖節點的一輪（建圖可用）。
ScanRoundResult _round(List<LightNode> lights, List<RawNode> raws) => fakeRound(
  nodes: const [],
  extraRawNodes: raws,
  graphOverride: GraphBuildAvailable(
    GraphBuiltEvent(
      nodes: lights,
      edges: const [],
      graphDefects: const [],
      totalReferences: 0,
      resolvedCount: 0,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, ScanRoundResult? round) async {
  final fake = FakeScanRound(produce: () => round);
  final container = await pumpHarness(
    tester,
    child: const TraceabilityScreen(),
    overrides: [
      scanRoundProvider.overrideWith(() => fake),
      builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
    ],
  );
  container.read(currentWorkspaceStateProvider.notifier).state =
      const WorkspaceReady('/ws/fake');
  container.read(scanRoundProvider);
  container.read(lastCompletedRoundProvider);
  if (round != null) fake.completeExternally(round);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('順序 1：尚無完成輪次 -> 專案未就緒', (tester) async {
    await _pump(tester, null);
    expect(
      find.byKey(const Key('state-traceability-project-unready')),
      findsOneWidget,
    );
  });

  testWidgets('順序 2：建圖不可用 -> 圖不可用（非無提案）', (tester) async {
    await _pump(
      tester,
      fakeRound(
        graphUnavailable:
            EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
      ),
    );
    expect(
      find.byKey(const Key('state-traceability-graph-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('state-traceability-empty')), findsNothing);
    expect(
      find.byKey(const Key('action-traceability-goto-domain')),
      findsOneWidget,
    );
  });

  testWidgets('順序 3：圖上無 PROP -> 無提案', (tester) async {
    await _pump(
      tester,
      _round([_light('SPEC-001', 'SPEC')], [_raw('SPEC-001', 'SPEC')]),
    );
    expect(find.byKey(const Key('state-traceability-empty')), findsOneWidget);
  });

  testWidgets('E1 第四層：UC 的 ticket_refs 為空 -> 缺口列與鏈路斷裂', (tester) async {
    await _pump(
      tester,
      _round(
        [
          _light('PROP-001', 'PROP'),
          _light('SPEC-001', 'SPEC'),
          _light('UC-01', 'UC'),
        ],
        [
          _raw('PROP-001', 'PROP'),
          _raw('SPEC-001', 'SPEC', {'source_proposal': 'PROP-001'}),
          _raw('UC-01', 'UC', {
            'related_specs': ['SPEC-001'],
            'ticket_refs': <String>[],
          }),
        ],
      ),
    );
    expect(find.byKey(const Key('state-traceability-broken')), findsOneWidget);
    expect(
      find.byKey(const Key('badge-traceability-broken-UC-01')),
      findsOneWidget,
    );
  });

  testWidgets('E1 第二跳：只取 UC 的 related_specs，SPEC 的 related_usecases 不成子節點', (
    tester,
  ) async {
    await _pump(
      tester,
      _round(
        [
          _light('PROP-001', 'PROP'),
          _light('SPEC-001', 'SPEC'),
          _light('UC-01', 'UC'),
        ],
        [
          _raw('PROP-001', 'PROP'),
          _raw('SPEC-001', 'SPEC', {
            'source_proposal': 'PROP-001',
            'related_usecases': ['UC-01'],
          }),
          _raw('UC-01', 'UC', {
            'ticket_refs': ['T-1'],
          }),
        ],
      ),
    );
    expect(find.byKey(const Key('card-traceability-UC-01')), findsNothing);
    expect(
      find.byKey(const Key('badge-traceability-broken-SPEC-001')),
      findsOneWidget,
    );
  });

  testWidgets('順序 5：三跳俱全且 Ticket 存在 -> 正常', (tester) async {
    await _pump(
      tester,
      _round(
        [
          _light('PROP-001', 'PROP'),
          _light('SPEC-001', 'SPEC'),
          _light('UC-01', 'UC'),
          _light('T-1', 'Ticket'),
        ],
        [
          _raw('PROP-001', 'PROP'),
          _raw('SPEC-001', 'SPEC', {'source_proposal': 'PROP-001'}),
          _raw('UC-01', 'UC', {
            'related_specs': ['SPEC-001'],
            'ticket_refs': ['T-1', 'T-dangling'],
          }),
          _raw('T-1', 'Ticket'),
        ],
      ),
    );
    expect(find.byKey(const Key('state-traceability-normal')), findsOneWidget);
  });
}
