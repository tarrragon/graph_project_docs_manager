// V3-1～V3-4：間接依賴格「在泳道中檢視」的跳轉目標（SPEC-001 §1）。
// FR-12 的依賴路徑以格資料注入，Layout L9 查詢以替身注入。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/layout/lane_order.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_projection.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';

import '../../../helpers/helpers.dart';
import '../../../helpers/spec001/corpus_snapshot.dart';

const _domains = ['graph', 'ticketdetail', 'corpus', 'schema'];

DomainMatrix _matrix(List<String> paths, DomainRelation schemaRelation) =>
    DomainMatrix(
      columns: const [DomainUc(id: 'UC-04', title: 't', hasFlowStep: true)],
      rows: [
        for (final d in _domains)
          DomainRow(
            domainId: d,
            domainName: d,
            subtotal: 0,
            cells: [
              DomainCell(
                domainId: d,
                ucId: 'UC-04',
                relation: d == 'schema'
                    ? schemaRelation
                    : DomainRelation.direct,
                dependencyPaths: d == 'schema' ? paths : const [],
                indirectSource: d == 'schema'
                    ? paths.first.split(' → ').first
                    : null,
              ),
            ],
          ),
      ],
    );

Future<ProviderContainer> _pumpAndClickGoto(
  WidgetTester tester, {
  required DomainMatrix matrix,
  required String selectedDomain,
  required Map<String, int> nodeColumns,
  required List<String> calls,
}) async {
  final overrides = <Override>[
    domainViewStateProvider.overrideWith(
      (ref) => DomainReady(
        mode: DomainMode.matrix,
        selectedCell: (selectedDomain, 'UC-04'),
      ),
    ),
    domainMatrixProvider.overrideWith((ref) => matrix),
    firstNodeInLaneQueryProvider.overrideWith(
      (ref) => (ucId, domain) {
        calls.add('$ucId/$domain');
        final column = nodeColumns[domain];
        return column == null
            ? null
            : LayoutNode(
                stepIndex: 0,
                column: column,
                lane: BundleLane(domain),
              );
      },
    ),
  ];
  await pumpHarness(
    tester,
    child: const DomainViewScreen(),
    overrides: overrides,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DomainViewScreen)),
  );
  await tester.tap(find.byKey(const Key('action-domain-cell-goto-swimlane')));
  await tester.pump();
  return container;
}

DomainReady _ready(ProviderContainer c) =>
    c.read(domainViewStateProvider) as DomainReady;

void main() {
  const graphFirst = [
    'graph → corpus → schema',
    'ticketdetail → corpus → schema',
  ];
  const ticketFirst = [
    'ticketdetail → corpus → schema',
    'graph → corpus → schema',
  ];

  group('投影的 indirectSource', () {
    test('間接格等於第一條路徑的來源；直接格為 null（E1）', () async {
      final event = await loadSnapshotEvent('graph_project_docs_manager');
      final matrix = projectDomainMatrix(event: event, ucIds: const ['UC-04']);
      DomainCell cellOf(String d) =>
          matrix.rows.firstWhere((r) => r.domainName == d).cells.single;
      final schema = cellOf('schema');
      expect(schema.relation, DomainRelation.indirect);
      expect(
        schema.indirectSource,
        schema.dependencyPaths.first.split(' → ').first,
      );
      expect(schema.indirectSource, 'graph');
      expect(cellOf('graph').relation, DomainRelation.direct);
      expect(cellOf('graph').indirectSource, isNull);
    });
  });

  group('跳轉目標', () {
    testWidgets('V3-1 以第一條路徑來源呼叫 L9 恰一次並落在其節點', (tester) async {
      final calls = <String>[];
      final c = await _pumpAndClickGoto(
        tester,
        matrix: _matrix(graphFirst, DomainRelation.indirect),
        selectedDomain: 'schema',
        nodeColumns: {'graph': 3, 'ticketdetail': 5},
        calls: calls,
      );
      expect(calls, ['UC-04/graph']);
      expect(_ready(c).mode, DomainMode.swimlane);
      expect(
        _ready(c).swimlaneFocus,
        const SwimlaneFocus(domainId: 'graph', column: 3),
      );
    });

    testWidgets('V3-2 路徑順序換過，落點隨第一條路徑來源改變', (tester) async {
      final calls = <String>[];
      final c = await _pumpAndClickGoto(
        tester,
        matrix: _matrix(ticketFirst, DomainRelation.indirect),
        selectedDomain: 'schema',
        nodeColumns: {'graph': 3, 'ticketdetail': 5},
        calls: calls,
      );
      expect(calls, ['UC-04/ticketdetail']);
      expect(
        _ready(c).swimlaneFocus,
        const SwimlaneFocus(domainId: 'ticketdetail', column: 5),
      );
    });

    testWidgets('V3-3 直接貫穿格跳到該格 domain 列，不呼叫 L9', (tester) async {
      final calls = <String>[];
      final c = await _pumpAndClickGoto(
        tester,
        matrix: _matrix(graphFirst, DomainRelation.direct),
        selectedDomain: 'schema',
        nodeColumns: {'graph': 3},
        calls: calls,
      );
      expect(calls, isEmpty);
      expect(_ready(c).swimlaneFocus, const SwimlaneFocus(domainId: 'schema'));
      expect(_ready(c).selectedDomainId, 'schema');
    });

    testWidgets('V3-4 畫面採用 L9 回傳的節點，不自行挑欄號', (tester) async {
      final calls = <String>[];
      final c = await _pumpAndClickGoto(
        tester,
        matrix: _matrix(graphFirst, DomainRelation.indirect),
        selectedDomain: 'schema',
        nodeColumns: {'graph': 9},
        calls: calls,
      );
      expect(_ready(c).swimlaneFocus?.column, 9);
    });
  });
}
