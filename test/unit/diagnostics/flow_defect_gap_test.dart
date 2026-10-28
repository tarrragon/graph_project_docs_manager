// SPEC-007-test-design §3.4 D4（flow 四子類）與 D5（domain 重複宣告）。
// 報告分組（D4-2／D5-2 的分組斷言）見
// test/unit/screens/gap_report/gap_report_projection_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/diagnostics/graph_defect_gap.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

FlowGraphDefect _flow(
  FlowDefectKind kind, {
  String ucId = 'UC-01',
  Object? stepId = 's1',
  String field = 'next',
  Object? rawValue = 'x',
}) => FlowGraphDefect(
  kind: kind,
  ucId: ucId,
  stepId: stepId,
  field: field,
  rawValue: rawValue,
);

List<GraphDefect> _flowFour() => [
  _flow(FlowDefectKind.unresolvedReference, stepId: 's1', rawValue: 'nope'),
  _flow(
    FlowDefectKind.duplicateStepId,
    stepId: 's2',
    field: 'id',
    rawValue: 's2',
  ),
  _flow(
    FlowDefectKind.traversesUndeclared,
    stepId: 's3',
    field: 'traverses',
    rawValue: 'ghost',
  ),
  _flow(
    FlowDefectKind.traversesKeyAbsent,
    stepId: 's4',
    field: 'traverses',
    rawValue: null,
  ),
];

List<GraphDefect> _mainFour() => [
  DuplicateIdGraphDefect(id: 'D-1', paths: ['a.md', 'b.md']),
  DuplicateIdGraphDefect(id: 'D-2', paths: ['c.md', 'd.md']),
  DuplicateIdGraphDefect(id: 'D-3', paths: ['e.md', 'f.md']),
  DuplicateIdGraphDefect(id: 'D-4', paths: ['g.md', 'h.md']),
];

DomainDuplicateDeclarationGraphDefect _domainDup() =>
    DomainDuplicateDeclarationGraphDefect(
      domain: 'corpus',
      bundleIds: ['P1', 'P2'],
    );

GraphBuiltEvent _event(List<GraphDefect> defects) => GraphBuiltEvent(
  nodes: const [],
  edges: const [],
  graphDefects: defects,
  totalReferences: 0,
  resolvedCount: 0,
);

List<GraphDefectGap> _detect(List<GraphDefect> defects) =>
    (detectGraphDefectGaps(
      GraphDefectInputAvailable(_event(defects)),
    ) as GraphDefectsDetected).gaps;

void main() {
  group('flow 四子類（D4）', () {
    test('D4-1 四子類各一 → 四筆 graphDefect，子類與負載逐一相符', () {
      final gaps = _detect(_flowFour());

      expect(gaps, hasLength(4));
      expect(gaps.every((g) => g.category == GapCategory.graphDefect), isTrue);
      expect(gaps.map((g) => g.kind), [
        GraphDefectKind.flowUnresolvedRef,
        GraphDefectKind.flowDuplicateStepId,
        GraphDefectKind.flowTraversesUndeclared,
        GraphDefectKind.flowTraversesKeyAbsent,
      ]);
      final d = gaps.map((g) => g.defect as FlowGraphDefect).toList();
      expect(d.map((x) => x.ucId), everyElement('UC-01'));
      expect(d.map((x) => x.stepId), ['s1', 's2', 's3', 's4']);
      expect(d.map((x) => x.field), ['next', 'id', 'traverses', 'traverses']);
      expect(d.map((x) => x.rawValue), ['nope', 's2', 'ghost', null]);
    });

    test('D4-2 主圖四子類與 flow 四子類混入 → 八筆，破洞大類不增加', () {
      final gaps = _detect([..._mainFour(), ..._flowFour()]);

      expect(gaps, hasLength(8));
      expect(gaps.map((g) => g.category).toSet(), {GapCategory.graphDefect});
      // 主圖組／flow 小組的分組由 projection 測試的 D4-2 驗。
    });

    // 偵測層原樣傳遞；建圖層的不修剪由 test/unit/graph/
    // domain_name_resolution_test.dart 的 G11-3（' corpus' 原值保留）負責。
    test('D4-3 偵測層原樣傳遞：原始值帶前後空白不修剪', () {
      final gaps = _detect([
        _flow(FlowDefectKind.unresolvedReference, rawValue: '  s9 '),
        _flow(FlowDefectKind.duplicateStepId, stepId: ' s1 ', field: 'id'),
      ]);

      final a = gaps[0].defect as FlowGraphDefect;
      final b = gaps[1].defect as FlowGraphDefect;
      expect(a.rawValue, '  s9 ');
      expect(b.stepId, ' s1 ');
    });

    test('D4-4（守衛）建圖不可用 → 零筆 flow 破洞並回報無法判定', () {
      final result = detectGraphDefectGaps(
        const GraphDefectInputUnavailable(
          UndeterminedGapReason.projectVersionOutOfKnownRange,
        ),
      );

      expect(result, isA<GraphDefectUndetermined>());
      expect(result, isNot(isA<GraphDefectsDetected>()));
      // 正向對照：可用時確實產生 flow 破洞（D4-1）
      expect(_detect(_flowFour()), hasLength(4));
    });

    test('D4-5 破洞負載不含在地化字串', () {
      final gaps = _detect(_flowFour());

      for (final g in gaps) {
        final d = g.defect as FlowGraphDefect;
        expect(d.kind.name, matches(RegExp(r'^[A-Za-z]+$')));
        expect(d.field, matches(RegExp(r'^[a-z_]+$')));
        expect(
          [d.ucId, d.stepId, d.rawValue].whereType<String>().join(),
          isNot(matches(RegExp(r'[一-鿿]'))),
        );
      }
    });

    // 偵測層原樣傳遞；建圖層 null 與 "" 的區分由
    // domain_name_resolution_test.dart 的 G11-13（缺鍵 rawValue null）與
    // 「空字串 domain 不入索引」（rawValue ""）、「traverses: null 視同空」負責。
    test('D4-6（E1）偵測層原樣傳遞：null 不轉空字串，對照 "" 的名稱未宣告', () {
      final gaps = _detect([
        _flow(
          FlowDefectKind.traversesKeyAbsent,
          field: 'traverses',
          rawValue: null,
        ),
        _flow(
          FlowDefectKind.traversesUndeclared,
          field: 'traverses',
          rawValue: '',
        ),
      ]);

      final absent = gaps[0].defect as FlowGraphDefect;
      final empty = gaps[1].defect as FlowGraphDefect;
      expect(absent.rawValue, isNull);
      expect(empty.rawValue, '');
      expect(gaps[0].kind, isNot(gaps[1].kind));
    });

    test('D4-7 事件引用未解析與 flow 參照未解析並列 → 兩筆，子類與負載相符', () {
      final gaps = _detect([
        _flow(
          FlowDefectKind.eventUnresolved,
          field: 'consumes',
          rawValue: 'EVT-GHOST',
        ),
        _flow(FlowDefectKind.unresolvedReference, rawValue: 'nope'),
      ]);

      expect(gaps.map((g) => g.kind), [
        GraphDefectKind.flowEventUnresolved,
        GraphDefectKind.flowUnresolvedRef,
      ]);
      expect(gaps.every((g) => g.category == GapCategory.graphDefect), isTrue);
      final d = gaps.first.defect as FlowGraphDefect;
      expect(
        (d.ucId, d.stepId, d.field, d.rawValue),
        ('UC-01', 's1', 'consumes', 'EVT-GHOST'),
      );
    });
  });

  group('domain 重複宣告（D5）', () {
    test('D5-1 一筆重複宣告 → 一筆 graphDefect，domain 與衝突 ID 清單原樣', () {
      final gaps = _detect([_domainDup()]);

      expect(gaps, hasLength(1));
      expect(gaps.single.category, GapCategory.graphDefect);
      expect(gaps.single.kind, GraphDefectKind.domainDuplicateDeclaration);
      final d = gaps.single.defect as DomainDuplicateDeclarationGraphDefect;
      expect(d.domain, 'corpus');
      expect(d.bundleIds, ['P1', 'P2']);
    });

    test('D5-2 與 flow 四子類、主圖四子類同輪 → 九筆 graphDefect', () {
      final gaps = _detect([..._mainFour(), ..._flowFour(), _domainDup()]);

      expect(gaps, hasLength(9));
      expect(gaps.map((g) => g.category).toSet(), {GapCategory.graphDefect});
      // 重複宣告歸主圖組（五筆）、flow 小組四筆，由 projection 測試的 D5-2 驗。
    });

    test('D5-3 負載不含在地化字串，亦不含 UC ID、step id 欄', () {
      final d =
          _detect([_domainDup()]).single.defect
              as DomainDuplicateDeclarationGraphDefect;

      expect(d, isNot(isA<FlowGraphDefect>()));
      expect(
        [d.domain, ...d.bundleIds].join(),
        isNot(matches(RegExp(r'[一-鿿]'))),
      );
    });
  });
}
