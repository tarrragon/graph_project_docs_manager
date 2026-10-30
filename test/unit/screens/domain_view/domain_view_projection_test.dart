// 需求：0.5.0-W1-114.20 P1～P8；SPEC-001 §1（矩陣、已選格、泳道各列與註記）、
// SPEC-003 §3.1〈格詳情卡的內容契約〉、SPEC-004 4.15／4.37／4.38。
// 期望值取 SPEC-001 期望值欄與凍結快照，不由實作輸出自算。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_projection.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';

import '../../../helpers/spec001/corpus_snapshot.dart';
import '../../../helpers/spec007/bundle_graph_fixture.dart';
import '../../../helpers/spec007/raw_node_builder.dart';

const _ucIds = ['UC-01', 'UC-02', 'UC-03', 'UC-04', 'UC-05', 'UC-06'];

/// SPEC-001 §1〈泳道布局規則〉列序期望值欄（本專案）。
const _projectDomains = [
  'schema',
  'workspace',
  'corpus',
  'history',
  'diagnostics',
  'graph',
  'ticketdetail',
  'layout',
];

GraphBuiltEvent _eventOf(List<RawNode> nodes) =>
    (buildResultOf(nodes) as GraphBuildAvailable).event;

/// 一個 UC，步驟為完整宣告列（含 emits／consumes）。
RawNode _uc(String id, List<Map<String, dynamic>> steps) => RawNode(
  path: 'docs/usecases/$id.md',
  frontmatter: {'id': id},
  typeName: 'UC',
  flowSteps: steps,
);

Map<String, dynamic> _step(
  String id, {
  List<String> traverses = const ['a'],
  Object? emits = const <String>[],
  Object? consumes = const <String>[],
}) => {
  'id': id,
  'name': id,
  'traverses': traverses,
  'emits': emits,
  'consumes': consumes,
};

/// 單一 bundle `a` 與 UC-01，回傳 `a × UC-01` 格的事件標籤。
List<(String, bool)> _eventsOf(List<Map<String, dynamic>> steps) {
  final matrix = projectDomainMatrix(
    event: _eventOf([bundleNode('a'), _uc('UC-01', steps)]),
    ucIds: const ['UC-01'],
  );
  return matrix.rows.single.cells.single.events;
}

DomainRow _rowOf(DomainMatrix matrix, String domain) =>
    matrix.rows.firstWhere((r) => r.domainName == domain);

DomainCell _cellOf(DomainMatrix matrix, String domain, String ucId) =>
    _rowOf(matrix, domain).cells.firstWhere((c) => c.ucId == ucId);

DomainSwimlane _swimlaneOf(GraphBuiltEvent event, String ucId) =>
    projectDomainSwimlane(event: event, ucId: ucId) as DomainSwimlane;

/// stepId → 欄號（同一步驟多列節點欄號相同）。
Map<String, int> _columnsById(DomainSwimlane swimlane) => {
  for (final lane in swimlane.lanes)
    for (final node in lane.nodes) node.stepId!: node.column,
};

int _laneIndexOf(DomainSwimlane swimlane, String domain) =>
    swimlane.lanes.indexWhere((l) => l.domainName == domain);

void main() {
  late GraphBuiltEvent project;
  late GraphBuiltEvent balance;
  late DomainMatrix matrix;

  setUpAll(() async {
    project = await loadSnapshotEvent('graph_project_docs_manager');
    balance = await loadSnapshotEvent('flutter_balance');
    matrix = projectDomainMatrix(event: project, ucIds: _ucIds);
  });

  group('矩陣', () {
    test('P1 本專案快照：48 格 19／10／19，間接 10 格同 SPEC-001 期望分布，history 皆無關', () {
      final cells = [for (final r in matrix.rows) ...r.cells];
      expect(cells, hasLength(48));
      int countOf(DomainRelation k) =>
          cells.where((c) => c.relation == k).length;
      expect(countOf(DomainRelation.direct), 19);
      expect(countOf(DomainRelation.indirect), 10);
      expect(countOf(DomainRelation.none), 19);
      final indirect = {
        for (final r in matrix.rows)
          for (final c in r.cells)
            if (c.relation == DomainRelation.indirect)
              '${c.ucId}:${r.domainName}',
      };
      expect(indirect, {
        for (final uc in ['UC-02', 'UC-03', 'UC-05']) ...[
          '$uc:schema',
          '$uc:workspace',
        ],
        'UC-04:corpus',
        'UC-04:schema',
        'UC-04:workspace',
        'UC-06:schema',
      });
      expect(
        _rowOf(matrix, 'history').cells.map((c) => c.relation),
        everyElement(DomainRelation.none),
      );
    });

    test('P1 欄序依傳入 ucIds，各欄對齊', () {
      expect([for (final c in matrix.columns) c.id], _ucIds);
      expect(matrix.columns.every((c) => c.hasFlowStep), isTrue);
      for (final row in matrix.rows) {
        expect([for (final c in row.cells) c.ucId], _ucIds);
      }
    });

    test('P2 列序依 FR-13', () {
      expect([for (final r in matrix.rows) r.domainName], _projectDomains);
      expect([
        for (final r in matrix.rows) r.domainId,
      ], everyElement(startsWith('DOMAIN-MAP-')));
    });

    test('P3 列末小計＝該列直接貫穿格數，逐列加總 19', () {
      for (final row in matrix.rows) {
        expect(
          row.subtotal,
          row.cells.where((c) => c.relation == DomainRelation.direct).length,
          reason: row.domainName,
        );
      }
      expect(matrix.rows.fold<int>(0, (s, r) => s + r.subtotal), 19);
      expect(_rowOf(matrix, 'history').subtotal, 0);
    });

    test('P3 E1 對照：改動一步 traverses，該列小計隨之變動', () {
      Map<String, int> subtotalsWith(List<String> traverses) {
        final m = projectDomainMatrix(
          event: _eventOf([
            bundleNode('a'),
            bundleNode('b'),
            ucNode('UC-01', [traverses]),
          ]),
          ucIds: const ['UC-01'],
        );
        return {for (final r in m.rows) r.domainName: r.subtotal};
      }

      final before = subtotalsWith(['a']);
      final after = subtotalsWith(['b']);
      expect(before, isNot(equals(after)));
      expect(before, {'a': 1, 'b': 0});
      expect(after, {'a': 0, 'b': 1});
    });
  });

  group('已選格詳情', () {
    test('P4 間接格依賴路徑：UC-04 × schema 兩行、UC-06 × schema 一行', () {
      expect(_cellOf(matrix, 'schema', 'UC-04').dependencyPaths, [
        'graph → corpus → schema',
        'ticketdetail → corpus → schema',
      ]);
      expect(_cellOf(matrix, 'schema', 'UC-06').dependencyPaths, [
        'corpus → schema',
      ]);
    });

    test('P4 直接與無關格不帶依賴路徑', () {
      for (final row in matrix.rows) {
        for (final cell in row.cells) {
          if (cell.relation != DomainRelation.indirect) {
            expect(cell.dependencyPaths, isEmpty, reason: cell.ucId);
          } else {
            expect(cell.dependencyPaths, isNotEmpty, reason: cell.ucId);
          }
        }
      }
    });

    test('P5 直接格：步驟取 traverses 含該 domain 者（flow 順序），說明 null', () {
      final graph = _cellOf(matrix, 'graph', 'UC-02');
      expect(graph.relation, DomainRelation.direct);
      // 快照 UC-02：read-traversal-count（第 2 步）、enter-from-ticket（第 6 步）。
      expect(graph.steps, ['讀取貫穿數', '由 ticket 切入']);
      expect(graph.events, isEmpty);
      expect(graph.explanation, isNull);
    });

    test('P5 直接格事件取該格步驟的 emits／consumes', () {
      // 快照 UC-02 switch-to-swimlane：consumes EVT-LAYOUT-001，traverses layout。
      final layout = _cellOf(matrix, 'layout', 'UC-02');
      expect(layout.steps, ['切換至泳道']);
      expect(layout.events, [('EVT-LAYOUT-001', false)]);
    });

    test('P5 非直接格不帶步驟與事件，說明 null', () {
      for (final row in matrix.rows) {
        for (final cell in row.cells) {
          if (cell.relation == DomainRelation.direct) continue;
          expect(cell.steps, isEmpty);
          expect(cell.events, isEmpty);
          expect(cell.explanation, isNull);
        }
      }
    });
  });

  group('事件標籤排序（SPEC-003 v1.57 §3.1，用戶裁決 A）', () {
    test('不同事件依首次出現的步驟序（不依方向分段）', () {
      final events = _eventsOf([
        _step('s1', consumes: ['E1']),
        _step('s2', emits: ['E3']),
      ]);
      expect(events, [('E1', false), ('E3', true)]);
    });

    test('E1 對照：步驟順序對調，事件順序隨之對調', () {
      final events = _eventsOf([
        _step('s1', emits: ['E3']),
        _step('s2', consumes: ['E1']),
      ]);
      expect(events, [('E3', true), ('E1', false)]);
    });

    test('同一事件兩標籤相鄰、emits 在前（消費先於發出亦同）', () {
      final events = _eventsOf([
        _step('s1', emits: ['E2'], consumes: ['E1']),
        _step('s2', emits: ['E1']),
      ]);
      expect(events, [('E2', true), ('E1', true), ('E1', false)]);
    });

    test('首次出現於同一步驟的多個事件：依 emits 清單、再 consumes 清單順序', () {
      final events = _eventsOf([
        _step('s1', emits: ['B', 'A'], consumes: ['C']),
      ]);
      expect(events, [('B', true), ('A', true), ('C', false)]);
    });

    test('E1 對照（同步驟多事件）：對調 emits 清單順序，輸出順序隨之對調', () {
      final original = _eventsOf([
        _step('s1', emits: ['B', 'A'], consumes: ['C']),
      ]);
      final swapped = _eventsOf([
        _step('s1', emits: ['A', 'B'], consumes: ['C']),
      ]);
      expect(original, isNot(equals(swapped)));
      expect(swapped, [('A', true), ('B', true), ('C', false)]);
    });

    test('同一步驟 consumes 的事件不早於 emits 的事件', () {
      final events = _eventsOf([
        _step('s1', emits: ['Y'], consumes: ['X']),
      ]);
      expect(events, [('Y', true), ('X', false)]);
    });

    test('去重：每個（事件, 方向）只出一個標籤', () {
      final steps = [
        _step('s1', emits: ['E1', 'E1'], consumes: ['E2']),
        _step('s2', emits: ['E1'], consumes: ['E2']),
      ];
      // E1 對照：輸入確有重複（E1 發出 3 次、E2 消費 2 次），輸出各只一筆。
      final rawEmits = [for (final s in steps) ...s['emits'] as List];
      expect(rawEmits.where((e) => e == 'E1'), hasLength(3));
      expect(_eventsOf(steps), [('E1', true), ('E2', false)]);
    });

    test('純量視同單元素清單、空值略過', () {
      final events = _eventsOf([
        _step('s1', emits: 'E1', consumes: null),
        _step('s2', emits: const <String>[], consumes: ''),
      ]);
      expect(events, [('E1', true)]);
    });

    test('只取該格步驟：traverses 不含該 domain 的步驟事件不列入', () {
      final events = _eventsOf([
        _step('s1', traverses: const ['b'], emits: ['OTHER']),
        _step('s2', emits: ['MINE']),
      ]);
      expect(events, [('MINE', true)]);
    });
  });

  group('UC 標題顯示退路（SPEC-001 §1）', () {
    String titleOf(Map<String, dynamic> extra) {
      final uc = RawNode(
        path: 'docs/usecases/UC-01-open-project-and-reach-usable-state.md',
        frontmatter: {'id': 'UC-01', ...extra},
        typeName: 'UC',
      );
      final m = projectDomainMatrix(
        event: _eventOf([bundleNode('a'), uc]),
        ucIds: const ['UC-01'],
      );
      return m.columns.single.title;
    }

    test('F1-1 非字串轉字串', () => expect(titleOf({'title': 7}), '7'));
    test('F1-2 null 為空字串', () => expect(titleOf({'title': null}), ''));
    test('F1-3 缺鍵為空字串', () => expect(titleOf({}), ''));
    test('F1-4 空字串為空字串', () => expect(titleOf({'title': ''}), ''));
    test('F1-5 E1 對照：非字串與空字串結果不同', () {
      expect(titleOf({'title': 7}), isNot(titleOf({'title': ''})));
    });
  });

  group('泳道', () {
    test('P6 UC-02 列：「畫面」+ 8 個 DomainBundle 列，無「未定位」列', () {
      final swimlane = _swimlaneOf(project, 'UC-02');
      expect(swimlane.lanes.first.kind, DomainLaneKind.screen);
      expect(swimlane.lanes.first.domainId, isNull);
      expect([
        for (final l in swimlane.lanes.skip(1)) l.domainName,
      ], _projectDomains);
      expect(
        swimlane.lanes.skip(1).map((l) => l.kind),
        everyElement(DomainLaneKind.domain),
      );
      final empty = {
        for (final l in swimlane.lanes)
          if (l.kind == DomainLaneKind.domain && l.nodes.isEmpty) l.domainName,
      };
      expect(empty, {'schema', 'workspace', 'history', 'diagnostics'});
    });

    test('P6 UC-02 欄序同 SPEC-001 期望值欄', () {
      expect(_columnsById(_swimlaneOf(project, 'UC-02')), {
        'locate-domain': 0,
        'enter-from-ticket': 1,
        'read-traversal-count': 2,
        'matrix-overview-only': 3,
        'switch-to-swimlane': 4,
        'flow-not-structured': 5,
        'inspect-steps': 6,
      });
    });

    test('P6 UC-02 節點：enter-from-ticket 於 graph、ticketdetail 欄 1；locate-domain 於畫面列欄 0', () {
      final swimlane = _swimlaneOf(project, 'UC-02');
      List<String?> lanesOf(String stepId) => [
        for (final l in swimlane.lanes)
          if (l.nodes.any((n) => n.stepId == stepId))
            l.domainName ?? l.kind.name,
      ];
      expect(lanesOf('enter-from-ticket'), ['graph', 'ticketdetail']);
      expect(lanesOf('locate-domain'), ['screen']);
      final node = swimlane.lanes
          .expand((l) => l.nodes)
          .firstWhere((n) => n.stepId == 'enter-from-ticket');
      expect(node.stepLabel, '由 ticket 切入');
      expect(node.stepTraverses, hasLength(2));
    });

    test('P6 UC-02 邊形：5→0 弧線、1→2 直線，端點取最上方節點', () {
      final swimlane = _swimlaneOf(project, 'UC-02');
      final back = swimlane.edges.singleWhere(
        (e) => e.fromColumn == 5 && e.toColumn == 0,
      );
      expect(back.shape, DomainLaneEdgeShape.arc);
      expect(back.fromLane, _laneIndexOf(swimlane, 'corpus'));
      expect(back.toLane, 0);
      final forward = swimlane.edges.singleWhere(
        (e) => e.fromColumn == 1 && e.toColumn == 2,
      );
      expect(forward.shape, DomainLaneEdgeShape.straight);
      expect(forward.fromLane, _laneIndexOf(swimlane, 'graph'));
      // read-traversal-count 的 traverses 為 ["graph"]（快照 UC-02）。
      expect(forward.toLane, _laneIndexOf(swimlane, 'graph'));
    });

    test('P6 列以 domain 字面對應 bundle：無效 domain（FR-13 Z3）與列首同字面者各對上自己的列', () {
      RawNode invalid(String key, Map<String, dynamic> extra) => buildRawNode(
        id: bundleIdOf(key),
        typeName: domainBundleTypeName,
        extra: extra,
      );
      final event = _eventOf([
        bundleNode('a'),
        invalid('p', {domainBundleDomainField: 7}),
        invalid('q', {domainBundleDomainField: null}),
        invalid('r', const {}),
        invalid('s', {domainBundleDomainField: ''}),
        ucNode('UC-01', [
          ['a'],
        ]),
      ]);
      final lanes = _swimlaneOf(event, 'UC-01').lanes.skip(1).toList();
      // SPEC-007 FR-13 Z3：有效者在前；無效者同層排後並依 bundle ID；
      // 列首非字串轉字串，null／缺鍵／空字串為空字串。
      expect(
        [for (final l in lanes) l.domainId],
        [
          bundleIdOf('a'),
          bundleIdOf('p'),
          bundleIdOf('q'),
          bundleIdOf('r'),
          bundleIdOf('s'),
        ],
      );
      expect([for (final l in lanes) l.domainName], ['a', '7', '', '', '']);
      expect(lanes.first.nodes, hasLength(1));
      expect(lanes.skip(1).expand((l) => l.nodes), isEmpty);
    });

    test('P6 flutter_balance UC-01：九節點在未定位列（欄 0～8），4 弧線 8 直線', () {
      final swimlane = _swimlaneOf(balance, 'UC-01');
      expect(
        [for (final l in swimlane.lanes) l.kind],
        [DomainLaneKind.screen, DomainLaneKind.domain, DomainLaneKind.unplaced],
      );
      expect(swimlane.lanes[1].domainName, 'balance-sheet');
      expect(swimlane.lanes.last.domainId, isNull);
      expect(swimlane.lanes.last.nodes, hasLength(9));
      expect(swimlane.lanes.take(2).expand((l) => l.nodes), isEmpty);
      expect(_columnsById(swimlane), {
        'create-accounts': 0,
        'backup-restore': 1,
        'first-inventory': 2,
        'reject-invalid-input': 3,
        'view-net-worth': 4,
        'currency-switch': 5,
        'cashflow-runway': 6,
        'assess-leverage': 7,
        'periodic-inventory': 8,
      });
      final shapes = swimlane.edges.map((e) => e.shape);
      expect(shapes.where((s) => s == DomainLaneEdgeShape.arc), hasLength(4));
      expect(
        shapes.where((s) => s == DomainLaneEdgeShape.straight),
        hasLength(8),
      );
    });
  });

  group('flow 區塊解析失敗', () {
    test('P7 部分失敗（仍有 FlowStep）：提示旗標為真；E1 對照未列入者為假', () {
      final flagged = projectDomainSwimlane(
        event: project,
        ucId: 'UC-02',
        flowParseFailedUcIds: const {'UC-02'},
      );
      final plain = projectDomainSwimlane(event: project, ucId: 'UC-02');
      expect((flagged as DomainSwimlane).hasFlowParseFailure, isTrue);
      expect((plain as DomainSwimlane).hasFlowParseFailure, isFalse);
    });

    test('P7 全部失敗（無 FlowStep）：未結構化且帶解析失敗；E1 對照未列入者為一般未結構化', () {
      final event = _eventOf([bundleNode('a'), ucNode('UC-01', const [])]);
      final failed = projectDomainSwimlane(
        event: event,
        ucId: 'UC-01',
        flowParseFailedUcIds: const {'UC-01'},
      );
      final plain = projectDomainSwimlane(event: event, ucId: 'UC-01');
      expect((failed as DomainSwimlaneUnstructured).isFlowParseFailed, isTrue);
      expect((plain as DomainSwimlaneUnstructured).isFlowParseFailed, isFalse);
      final columns = projectDomainMatrix(event: event, ucIds: const ['UC-01']);
      expect(columns.columns.single.hasFlowStep, isFalse);
    });
  });

  group('P8 import 方向守衛', () {
    test('E2 正向對照：違規樣本被攔下、合法樣本放行', () {
      const sample =
          "import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';\n"
          "import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';\n"
          "import 'package:graph_project_docs_manager/components/badge.dart';\n"
          "import 'package:graph_project_docs_manager/screens/domain_view/domain_view_fixtures.dart';\n"
          "import '../../graph/flow_query.dart';\n"
          "export 'package:graph_project_docs_manager/app/selected_uc.dart';\n"
          "import 'package:graph_project_docs_manager/graph/flow_query.dart';\n"
          "import 'package:graph_project_docs_manager/layout/lane_order.dart';\n"
          "import 'package:graph_project_docs_manager/app/domain_view_state.dart';\n"
          "import 'dart:collection';\n";
      expect(disallowedImportsIn(sample), [
        'package:graph_project_docs_manager/corpus/corpus_scanner.dart',
        'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart',
        'package:graph_project_docs_manager/components/badge.dart',
        'package:graph_project_docs_manager/screens/domain_view/domain_view_fixtures.dart',
        '../../graph/flow_query.dart',
        'package:graph_project_docs_manager/app/selected_uc.dart',
      ]);
    });

    test('投影只依賴 graph／layout 公開面與本畫面模型', () {
      final source = File('lib/screens/domain_view/domain_view_projection.dart')
          .readAsStringSync();
      expect(disallowedImportsIn(source), isEmpty);
    });
  });
}

final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
const _allowedPrefixes = [
  'dart:',
  'package:graph_project_docs_manager/graph/',
  'package:graph_project_docs_manager/layout/',
];
const _allowedFiles = [
  'package:graph_project_docs_manager/app/domain_view_state.dart',
];

/// 白名單外的 import／export 目標（含一切相對路徑）。
List<String> disallowedImportsIn(String source) => [
  for (final line in source.split('\n'))
    if (_importPattern.firstMatch(line)?.group(1) case final target?
        when !_allowedPrefixes.any(target.startsWith) &&
            !_allowedFiles.contains(target))
      target,
];
