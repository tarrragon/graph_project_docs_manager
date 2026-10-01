import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';

ReferenceValue _ref({Object? value, String sourceId = 'A-1'}) => ReferenceValue(
  sourceId: sourceId,
  sourcePath: 'docs/$sourceId.md',
  edgeTypeName: 'spawn',
  fieldName: 'spawned_tickets',
  isReverse: false,
  value: value,
  isShapeValid: value is String,
);

GraphBuiltEvent _event(List<GraphDefect> defects) => GraphBuiltEvent(
  nodes: const [],
  edges: const [],
  graphDefects: defects,
  totalReferences: 0,
  resolvedCount: 0,
);

List<GraphDefect> _fourKinds() => [
  DanglingRefGraphDefect(
    ref: _ref(value: ' X-9 '),
    reason: DanglingReason.targetMissing,
  ),
  MalformedRefGraphDefect(
    ref: _ref(value: 42),
    reason: MalformedReason.invalidShape,
  ),
  const DuplicateIdGraphDefect(id: 'D-1', paths: ['a.md', 'b.md']),
  const MultiSourceGraphDefect(
    from: 'T-1',
    edgeType: 'spawn',
    targets: [
      MultiSourceTarget(to: 'T-2', declaredBy: {'T-1'}),
      MultiSourceTarget(to: 'T-3', declaredBy: {'T-3'}),
    ],
  ),
];

List<GraphDefectGap> _gapsOf(GraphDefectGapResult result) =>
    (result as GraphDefectsDetected).gaps;

void main() {
  group('detectGraphDefectGaps（SPEC-007-test-design §3.4 D3，FR-09）', () {
    test('D3-1 四子類各一 → 四筆 graphDefect，欄位逐一相符且原值原樣', () {
      final gaps = _gapsOf(
        detectGraphDefectGaps(GraphDefectInputAvailable(_event(_fourKinds()))),
      );

      expect(gaps, hasLength(4));
      expect(gaps.every((g) => g.category == GapCategory.graphDefect), isTrue);
      final dangling = gaps[0].defect as DanglingRefGraphDefect;
      expect(gaps[0].kind, GraphDefectKind.danglingRef);
      expect(dangling.ref.sourceId, 'A-1');
      expect(dangling.ref.sourcePath, 'docs/A-1.md');
      expect(dangling.ref.fieldName, 'spawned_tickets');
      expect(dangling.ref.value, ' X-9 ');
      expect(dangling.ref.edgeTypeName, 'spawn');
      expect(dangling.reason.name, 'targetMissing');
      final malformed = gaps[1].defect as MalformedRefGraphDefect;
      expect(gaps[1].kind, GraphDefectKind.malformedRef);
      expect(malformed.ref.value, 42);
      expect(malformed.reason.name, 'invalidShape');
      final dup = gaps[2].defect as DuplicateIdGraphDefect;
      expect(gaps[2].kind, GraphDefectKind.duplicateId);
      expect(dup.id, 'D-1');
      expect(dup.paths, ['a.md', 'b.md']);
      final multi = gaps[3].defect as MultiSourceGraphDefect;
      expect(gaps[3].kind, GraphDefectKind.multiSource);
      expect(multi.from, 'T-1');
      expect(multi.edgeType, 'spawn');
      expect(multi.targets.map((t) => t.to), ['T-2', 'T-3']);
      expect(multi.targets[0].declaredBy, {'T-1'});
      expect(multi.targets[1].declaredBy, {'T-3'});
    });

    test('D3-2 零筆缺陷 → 零筆破洞，非無法判定', () {
      final result = detectGraphDefectGaps(
        GraphDefectInputAvailable(_event(const [])),
      );

      expect(result, isA<GraphDefectsDetected>());
      expect(_gapsOf(result), isEmpty);
    });

    test('D3-3 破洞負載只含原因碼與原值，不含顯示文字', () {
      final gaps = _gapsOf(
        detectGraphDefectGaps(GraphDefectInputAvailable(_event(_fourKinds()))),
      );

      final dangling = gaps[0].defect as DanglingRefGraphDefect;
      expect(dangling.reason.name, matches(RegExp(r'^[A-Za-z]+$')));
      expect(GraphDefectKind.values.map((k) => k.name), [
        'danglingRef',
        'malformedRef',
        'duplicateId',
        'multiSource',
      ]);
    });

    test('D3-4（守衛）建圖不可用 → 零筆 graphDefect，回報無法判定並帶原因', () {
      final result = detectGraphDefectGaps(
        const GraphDefectInputUnavailable(
          UndeterminedGapReason.projectVersionOutOfKnownRange,
        ),
      );

      expect(result, isA<GraphDefectUndetermined>());
      expect(
        (result as GraphDefectUndetermined).reason,
        UndeterminedGapReason.projectVersionOutOfKnownRange,
      );
      // 正向對照：可用且有缺陷時確實產生破洞（D3-1）
      expect(
        _gapsOf(
          detectGraphDefectGaps(
            GraphDefectInputAvailable(_event(_fourKinds())),
          ),
        ),
        isNotEmpty,
      );
    });

    test('D3-5 同時輸入 EVT-CORPUS-003 → parseFailure 與 graphDefect 各自產生', () {
      final parseResult = detectParseFailureGaps(
        events: const [
          ParseFailureEvent(
            path: 'docs/x.md',
            reason: 'YAML 語法錯誤',
            nodeType: 'Ticket',
            candidateTypes: ['Ticket'],
            schemaAmbiguous: false,
            salvagedFields: [],
            lostFields: ['title'],
            severity: ParseFailureSeverity.edgeAffecting,
          ),
        ],
        undeterminedCount: 0,
        unavailableReason: null,
      );
      final graphResult = detectGraphDefectGaps(
        GraphDefectInputAvailable(_event(_fourKinds())),
      );

      final parseGaps = (parseResult as GapsDetected).gaps;
      expect(parseGaps, hasLength(1));
      expect(parseGaps.single.category, GapCategory.parseFailure);
      expect(_gapsOf(graphResult), hasLength(4));
    });
  });
}
