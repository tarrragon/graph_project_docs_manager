import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/flow_query.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';

import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _uc = 'UC-01';

RawNode _uc01(List<Map<String, dynamic>> steps, {String id = _uc}) => RawNode(
  path: 'docs/usecases/$id.md',
  frontmatter: {'id': id},
  typeName: flowSourceTypeName,
  flowSteps: steps,
);

Map<String, dynamic> _s(String id, [Map<String, dynamic> extra = const {}]) => {
  'id': id,
  ...extra,
};

({GraphBuiltEvent event, FlowQuery query}) _build(List<RawNode> nodes) {
  final result = buildGraph(
    rawNodes: nodes,
    projectSchemaJson: loadBuiltinSchemaJson(),
    builtinSchemaJson: loadBuiltinSchemaJson(),
  );
  return (
    event: (result as GraphBuildAvailable).event,
    query: FlowQuery(buildResult: result),
  );
}

FlowSubgraph _flow(List<Map<String, dynamic>> steps) {
  final r = _build([_uc01(steps)]).query.flowOf(_uc);
  return (r as FlowOfAvailable).subgraph;
}

List<FlowGraphDefect> _flowDefects(GraphBuiltEvent e) =>
    e.graphDefects.whereType<FlowGraphDefect>().toList();

(FlowDefectKind, Object?, String, Object?) _sig(FlowGraphDefect d) =>
    (d.kind, d.stepId, d.field, d.rawValue);

List<Object?> _ids(List<FlowStepNode> nodes) => [for (final n in nodes) n.id];

void main() {
  group('G10 flowOf 主線、分支、回指', () {
    test('G10-1 三種空值皆判主線，分支帶指向', () {
      final g = _flow([
        _s('s1'),
        _s('s2'),
        _s('s3', {'branch_from': null}),
        _s('s4', {'branch_from': ''}),
        _s('b1', {'branch_from': 's1'}),
      ]);
      expect(_ids(g.mainline), ['s1', 's2', 's3', 's4']);
      expect(_ids(g.branches), ['b1']);
      expect(g.targetOf(g.branches.single.branchFrom!)!.id, 's1');
    });

    test('G10-2 主線順序取清單順序，主線 next 不解析、無缺陷', () {
      final nodes = [
        _uc01([
          _s('a', {'next': 'c'}),
          _s('b'),
          _s('c'),
        ]),
      ];
      final built = _build(nodes);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(_ids(g.mainline), ['a', 'b', 'c']);
      expect(_flowDefects(built.event), isEmpty);
    });

    test('G10-3 E1 鑑別：next 只在分支步解析', () {
      final mainOnly = _build([
        _uc01([
          _s('a', {'next': 'c'}),
          _s('b'),
          _s('c'),
          _s('m', {'next': 'zzz'}),
        ]),
      ]);
      expect(_flowDefects(mainOnly.event), isEmpty);
      final branch = _build([
        _uc01([
          _s('a'),
          _s('b2', {'branch_from': 'a', 'next': 'zzz'}),
        ]),
      ]);
      final d = _flowDefects(branch.event).single;
      expect(d.kind, FlowDefectKind.unresolvedReference);
      expect(d.field, FlowFields.next);
      expect(d.rawValue, 'zzz');
    });

    test('G10-4 守衛：未解析 branch_from，步驟仍在子圖、負載齊全', () {
      final built = _build([
        _uc01([
          _s('s1'),
          _s('b1', {'branch_from': 'ghost'}),
        ]),
      ]);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(_ids(g.branches), ['b1']);
      final ref = g.branches.single.branchFrom!;
      expect(ref.isResolved, isFalse);
      expect(ref.rawValue, 'ghost');
      final d = _flowDefects(built.event).single;
      expect(d.kind, FlowDefectKind.unresolvedReference);
      expect(
        (d.ucId, d.stepId, d.field, d.rawValue),
        (_uc, 'b1', FlowFields.branchFrom, 'ghost'),
      );
    });

    test('G10-4 正向對照：已解析 branch_from 無缺陷', () {
      final built = _build([
        _uc01([
          _s('s1'),
          _s('b1', {'branch_from': 's1'}),
        ]),
      ]);
      expect(_flowDefects(built.event), isEmpty);
    });

    test('G10-5 守衛：return_to 與分支 next 未解析各一筆', () {
      final built = _build([
        _uc01([
          _s('s1'),
          _s('b1', {'branch_from': 's1', 'return_to': 'ghost'}),
          _s('b2', {'branch_from': 's1', 'next': 'ghost2'}),
        ]),
      ]);
      final ds = _flowDefects(built.event);
      expect(ds, hasLength(2));
      expect(_sig(ds[0]), (
        FlowDefectKind.unresolvedReference,
        'b1',
        FlowFields.returnTo,
        'ghost',
      ));
      expect(_sig(ds[1]), (
        FlowDefectKind.unresolvedReference,
        'b2',
        FlowFields.next,
        'ghost2',
      ));
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(_ids(g.branches), ['b1', 'b2']);
    });

    test('G10-6 回指帶指向，已解析無缺陷', () {
      final built = _build([
        _uc01([
          _s('s1'),
          _s('s2'),
          _s('b1', {'branch_from': 's1', 'return_to': 's2'}),
        ]),
      ]);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(_ids(g.returns), ['b1']);
      expect(g.targetOf(g.returns.single.returnTo!)!.id, 's2');
      expect(_flowDefects(built.event), isEmpty);
    });

    test('G10-7 守衛：UC 內 step id 重複，兩步保留、恰一筆缺陷', () {
      final built = _build([
        _uc01([
          _s('x'),
          _s('x', {'branch_from': 'x'}),
        ]),
      ]);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(_ids(g.mainline), ['x']);
      expect(_ids(g.branches), ['x']);
      final dups = _flowDefects(built.event)
          .where((d) => d.kind == FlowDefectKind.duplicateStepId);
      expect(dups.single.field, FlowFields.id);
      expect(dups.single.rawValue, 'x');
    });

    test('G10-7 正向對照：id 改為 x、y 零缺陷', () {
      final built = _build([
        _uc01([
          _s('x'),
          _s('y', {'branch_from': 'x'}),
        ]),
      ]);
      expect(_flowDefects(built.event), isEmpty);
    });

    test('G10-8 指向重複 id 的參照逐筆斷言（依 FR-10 實際共四筆）', () {
      final built = _build([
        _uc01([
          _s('x'),
          _s('x', {'branch_from': 'x'}),
          _s('r', {'branch_from': 'x', 'return_to': 'x'}),
        ]),
      ]);
      // 來源：(1) 重複 id x；(2) 第二個 x 的 branch_from 指向重複 id；
      // (3) r 的 branch_from 指向重複 id；(4) r 的 return_to 指向重複 id。
      final expected = [
        (FlowDefectKind.duplicateStepId, 'x', FlowFields.id, 'x'),
        (FlowDefectKind.unresolvedReference, 'x', FlowFields.branchFrom, 'x'),
        (FlowDefectKind.unresolvedReference, 'r', FlowFields.branchFrom, 'x'),
        (FlowDefectKind.unresolvedReference, 'r', FlowFields.returnTo, 'x'),
      ];
      expect(_flowDefects(built.event).map(_sig).toList(), expected);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      final r = g.steps[2];
      expect(r.branchFrom!.isResolved, isFalse);
      expect(r.returnTo!.isResolved, isFalse);
      expect(g.steps[1].branchFrom!.isResolved, isFalse);
    });

    test('G10-8 補：分支步 next 指向重複 id 標未解析，各一筆缺陷', () {
      final built = _build([
        _uc01([
          _s('x'),
          _s('x'),
          _s('b', {'branch_from': 'x', 'next': 'x'}),
        ]),
      ]);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      expect(g.steps[2].nextRef!.isResolved, isFalse);
      expect(_flowDefects(built.event).map(_sig).toList(), [
        (FlowDefectKind.duplicateStepId, 'x', FlowFields.id, 'x'),
        (FlowDefectKind.unresolvedReference, 'b', FlowFields.branchFrom, 'x'),
        (FlowDefectKind.unresolvedReference, 'b', FlowFields.next, 'x'),
      ]);
    });

    test('S1 非字串 id 與參照轉字串後比對：id 整數 1 可被 "1" 與 1 解析，零缺陷', () {
      final built = _build([
        _uc01([
          {'id': 1},
          {'id': 'b1', 'branch_from': '1', 'return_to': 1, 'next': 1},
        ]),
      ]);
      expect(_flowDefects(built.event), isEmpty);
      final g = (built.query.flowOf(_uc) as FlowOfAvailable).subgraph;
      final b = g.steps[1];
      expect(g.targetOf(b.branchFrom!)!.id, 1);
      expect(g.targetOf(b.returnTo!)!.id, 1);
      expect(g.targetOf(b.nextRef!)!.id, 1);
    });

    test('S1 對照：id 1 與 "1" 判為重複，指向它的參照未解析', () {
      final built = _build([
        _uc01([
          {'id': 1},
          {'id': '1'},
          {'id': 'b', 'branch_from': '1'},
        ]),
      ]);
      expect(_flowDefects(built.event).map(_sig).toList(), [
        (FlowDefectKind.duplicateStepId, 1, FlowFields.id, 1),
        (FlowDefectKind.unresolvedReference, 'b', FlowFields.branchFrom, '1'),
      ]);
    });

    test('S1 對照：id 1 與 2 不重複；指向不存在的整數 9 仍為未解析', () {
      final built = _build([
        _uc01([
          {'id': 1},
          {'id': 2},
          {'id': 'b', 'branch_from': 9},
        ]),
      ]);
      expect(_flowDefects(built.event).map(_sig).toList(), [
        (FlowDefectKind.unresolvedReference, 'b', FlowFields.branchFrom, 9),
      ]);
    });

    test('分支步 next 為空清單視為空值，不報缺陷', () {
      final built = _build([
        _uc01([
          _s('a'),
          _s('b', {'branch_from': 'a', 'next': <String>[]}),
        ]),
      ]);
      expect(_flowDefects(built.event), isEmpty);
    });

    test('M2 子圖不可改寫，且與 RawNode 原 Map 不共用參照', () {
      final raw = <String, dynamic>{
        'id': 'a',
        'traverses': ['graph'],
      };
      final node = _uc01([raw]);
      final g = (_build([node]).query.flowOf(_uc) as FlowOfAvailable).subgraph;
      final step = g.steps.single.step;
      expect(() => step['id'] = 'z', throwsUnsupportedError);
      expect(
        () => (g.steps.single.traverses! as List).add('x'),
        throwsUnsupportedError,
      );
      expect(() => g.steps.add(g.steps.single), throwsUnsupportedError);
      expect(identical(step, raw), isFalse);
      expect(node.flowSteps.single, {
        'id': 'a',
        'traverses': ['graph'],
      });
      raw['id'] = 'changed';
      expect(g.steps.single.id, 'a');
    });

    test('G10-9 不同 UC 的相同 step id 不是缺陷', () {
      final built = _build([
        _uc01([_s('rescan')], id: 'UC-A'),
        _uc01([_s('rescan')], id: 'UC-B'),
      ]);
      expect(_flowDefects(built.event), isEmpty);
      for (final id in ['UC-A', 'UC-B']) {
        final g = (built.query.flowOf(id) as FlowOfAvailable).subgraph;
        expect(g.ucId, id);
        expect(_ids(g.steps), ['rescan']);
      }
    });

    test('G10-10 守衛：不跨 UC 解析', () {
      final built = _build([
        _uc01([
          _s('a'),
          _s('b1', {'branch_from': 'only_in_b'}),
        ], id: 'UC-A'),
        _uc01([_s('only_in_b')], id: 'UC-B'),
      ]);
      final d = _flowDefects(built.event).single;
      expect((d.ucId, d.stepId, d.rawValue), ('UC-A', 'b1', 'only_in_b'));
    });

    test('G10-11 步驟屬性原值原樣保存', () {
      final g = _flow([
        _s('a', {
          'name': ' 名稱 ',
          'next': 'b',
          'emits': ['E1'],
          'consumes': ['E0'],
          'traverses': [' graph ', 7],
        }),
      ]);
      final n = g.steps.single;
      expect(n.id, 'a');
      expect(n.name, ' 名稱 ');
      expect(n.next, 'b');
      expect(n.emits, ['E1']);
      expect(n.consumes, ['E0']);
      expect(n.traverses, [' graph ', 7]);
    });

    test('G10-12 空步驟、不在圖上、非 UC 三種回傳可區分', () {
      final built = _build([
        _uc01(const []),
        buildRawNode(id: 'SPEC-001', typeName: 'SPEC'),
      ]);
      final empty = built.query.flowOf(_uc);
      expect(empty, isA<FlowOfAvailable>());
      final g = (empty as FlowOfAvailable).subgraph;
      expect([g.mainline, g.branches, g.returns], everyElement(isEmpty));
      expect(built.query.flowOf('UC-99'), isA<FlowOfNotFound>());
      expect(built.query.flowOf('SPEC-001'), isA<FlowOfNotFound>());
    });

    test('G10-13 守衛：圖不可用與未完成建圖，皆非空子圖亦非不存在', () {
      final bad = FlowQuery(
        buildResult: buildGraph(
          rawNodes: [_uc01([])],
          projectSchemaJson: buildEdgeTableJson(version: '99.0.0'),
          builtinSchemaJson: loadBuiltinSchemaJson(),
        ),
      ).flowOf(_uc);
      expect(
        (bad as FlowOfGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildUnavailable,
      );
      final pending = FlowQuery(buildResult: null).flowOf(_uc);
      expect(
        (pending as FlowOfGraphUnavailable).cause,
        AdjacencyUnavailableCause.buildNotCompleted,
      );
    });

    test('G10-14 E1 鑑別：子圖不進邊集合，圖計數與有無缺陷步驟無關', () {
      final defectSteps = [
        _s('x'),
        _s('x'),
        _s('b1', {'branch_from': 'ghost'}),
      ];
      final withFlow = buildGraphEvent([_uc01(defectSteps)]);
      final without = buildGraphEvent([_uc01(const [])]);
      expect(withFlow.edgeCount, without.edgeCount);
      expect(withFlow.edgesByType, without.edgesByType);
      expect(withFlow.danglingRefCount, without.danglingRefCount);
      expect(withFlow.malformedRefCount, without.malformedRefCount);
      expect(withFlow.duplicateIdCount, without.duplicateIdCount);
      expect(withFlow.multiSourceCount, without.multiSourceCount);
      expect(_flowDefects(without), isEmpty);
      expect(
        withFlow.graphDefects.length - without.graphDefects.length,
        _flowDefects(withFlow).length,
      );
      expect(_flowDefects(withFlow), hasLength(2));
    });

    test('G10-15 負載鍵集合恰為 UC ID、step id、欄位、原始值', () {
      final built = _build([
        _uc01([
          _s('x'),
          _s('x', {'branch_from': 'ghost', 'return_to': 'ghost'}),
        ]),
      ]);
      final ds = _flowDefects(built.event);
      expect(ds, hasLength(3));
      for (final d in ds) {
        expect(d.ucId, _uc);
        expect(d.field, isA<String>());
        expect(d.stepId, 'x');
      }
    });

    test('主圖重複 id 的 UC 不進子圖（回傳不存在）', () {
      final built = _build([
        _uc01([_s('a')]),
        _uc01([_s('b')]),
      ]);
      expect(built.query.flowOf(_uc), isA<FlowOfNotFound>());
    });
  });
}
