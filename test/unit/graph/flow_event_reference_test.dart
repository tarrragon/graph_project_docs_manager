// SPEC-007-test-design G10E（G10-25～G10-32）：FR-10〈事件引用〉。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _uc = 'UC-01';

RawNode _ucNode(List<Map<String, dynamic>> steps) => RawNode(
  path: 'docs/usecases/$_uc.md',
  frontmatter: {'id': _uc},
  typeName: flowSourceTypeName,
  flowSteps: steps,
);

RawNode _evt(String id, {String? path}) =>
    buildRawNode(id: id, typeName: 'EVT', path: path);

GraphBuiltEvent _build(List<RawNode> nodes) => (buildGraph(
  rawNodes: nodes,
  projectSchemaJson: loadBuiltinSchemaJson(),
  builtinSchemaJson: loadBuiltinSchemaJson(),
) as GraphBuildAvailable).event;

List<FlowGraphDefect> _eventDefects(GraphBuiltEvent e) => e.graphDefects
    .whereType<FlowGraphDefect>()
    .where((d) => d.kind == FlowDefectKind.eventUnresolved)
    .toList();

Map<String, dynamic> _step(String id, {Object? emits, Object? consumes}) => {
  'id': id,
  'traverses': const <String>[],
  'emits': ?emits,
  'consumes': ?consumes,
};

List<(Object?, String, Object?)> _sig(List<FlowGraphDefect> ds) => [
  for (final d in ds) (d.stepId, d.field, d.rawValue),
];

void main() {
  group('G10E 事件引用未解析（FR-10〈事件引用〉）', () {
    test('G10-25 守衛：引用不存在的 EVT id 報一筆，步驟與屬性仍在', () {
      final e = _build([
        _ucNode([
          _step('s', emits: ['EVT-GHOST']),
        ]),
      ]);
      final d = _eventDefects(e).single;
      expect(
        (d.ucId, d.stepId, d.field, d.rawValue),
        (_uc, 's', 'emits', 'EVT-GHOST'),
      );
      final step = e.flowSubgraphs[_uc]!.steps.single;
      expect(step.emits, ['EVT-GHOST']);
    });

    test('G10-26 對照：加上 EVT 節點後零筆（與 G10-25 只差節點有無）', () {
      final e = _build([
        _ucNode([
          _step('s', emits: ['EVT-GHOST']),
        ]),
        _evt('EVT-GHOST'),
      ]);
      expect(_eventDefects(e), isEmpty);
    });

    test('G10-27 consumes 欄位同樣檢查', () {
      final e = _build([
        _ucNode([
          _step('s', consumes: ['EVT-GHOST']),
        ]),
      ]);
      expect(_sig(_eventDefects(e)), [('s', 'consumes', 'EVT-GHOST')]);
    });

    test('G10-28 去重：同步驟同欄位同值一筆；欄位不同各一筆', () {
      final e = _build([
        _ucNode([
          _step('s', emits: ['EVT-X', 'EVT-X']),
          _step('t', emits: ['EVT-X'], consumes: ['EVT-X']),
        ]),
      ]);
      expect(_sig(_eventDefects(e)), [
        ('s', 'emits', 'EVT-X'),
        ('t', 'emits', 'EVT-X'),
        ('t', 'consumes', 'EVT-X'),
      ]);
    });

    test('G10-29 守衛：重複 EVT id 算存在，只有 duplicateId', () {
      final e = _build([
        _evt('EVT-DUP', path: 'docs/events/a/EVT-DUP.md'),
        _evt('EVT-DUP', path: 'docs/events/b/EVT-DUP.md'),
        _ucNode([
          _step('s', consumes: ['EVT-DUP']),
        ]),
      ]);
      expect(_eventDefects(e), isEmpty);
      final dups = e.graphDefects.whereType<DuplicateIdGraphDefect>().toList();
      expect(dups.single.id, 'EVT-DUP');
    });

    test('G10-30 正規化：純量視同單元素；null、缺鍵、空元素略過', () {
      final e = _build([
        _ucNode([
          _step('a', emits: 'EVT-GHOST'),
          _step('b', emits: ['EVT-GHOST']),
          {'id': 'c', 'traverses': const <String>[], 'emits': null},
          _step('d', emits: ['']),
        ]),
      ]);
      expect(_sig(_eventDefects(e)), [
        ('a', 'emits', 'EVT-GHOST'),
        ('b', 'emits', 'EVT-GHOST'),
      ]);
    });

    test('G10-31 非字串元素：記原值；對照組有 id 為 "7" 的 EVT 節點則零筆', () {
      final steps = [
        _step('s', emits: [7]),
      ];
      final miss = _eventDefects(_build([_ucNode(steps)])).single;
      expect(miss.rawValue, isA<int>());
      expect(miss.rawValue, 7);
      expect(_eventDefects(_build([_ucNode(steps), _evt('7')])), isEmpty);
    });

    test('G10-32 守衛：型別與大小寫——非 EVT 節點與大小寫相異皆報', () {
      final e = _build([
        buildRawNode(id: 'SPEC-007', typeName: 'SPEC'),
        _evt('EVT-REAL'),
        _ucNode([
          _step('s', emits: ['SPEC-007', 'evt-real', 'EVT-REAL']),
        ]),
      ]);
      expect(
        [for (final d in _eventDefects(e)) d.rawValue],
        ['SPEC-007', 'evt-real'],
      );
    });
  });
}
