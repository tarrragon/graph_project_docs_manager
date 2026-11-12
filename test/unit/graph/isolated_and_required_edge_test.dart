import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _ticket = '0.1.0-W1-001';

RawNode _prop(String id) => buildRawNode(id: id, typeName: 'PROP');

RawNode _spec(String id, {Map<String, dynamic> extra = const {}}) =>
    buildRawNode(id: id, typeName: 'SPEC', extra: extra);

RawNode _uc(String id, {Map<String, dynamic> extra = const {}}) =>
    buildRawNode(id: id, typeName: 'UC', extra: extra);

RawNode _evt(String id, {Map<String, dynamic> extra = const {}}) =>
    buildRawNode(id: id, typeName: 'EVT', extra: extra);

/// 三條必要邊皆滿足的 UC（目標節點由 [_targets] 提供）。
RawNode _fullUc(String id) => _uc(
  id,
  extra: {
    'source_proposal': ['PROP-001'],
    'related_specs': ['SPEC-001'],
    'ticket_refs': [_ticket],
  },
);

List<RawNode> _targets() => [
  _prop('PROP-001'),
  _spec('SPEC-001'),
  buildRawNode(id: _ticket),
];

List<IsolatedNodeGraphDefect> _isolated(GraphBuiltEvent e) =>
    e.graphDefects.whereType<IsolatedNodeGraphDefect>().toList();

List<MissingRequiredEdgeGraphDefect> _missing(GraphBuiltEvent e) =>
    e.graphDefects.whereType<MissingRequiredEdgeGraphDefect>().toList();

void main() {
  group('孤島（SPEC-007 FR-09 判準一）', () {
    test('無任何邊的 SPEC 報一筆孤島，負載為 ID、型別、路徑', () {
      final e = buildGraphEvent([_spec('SPEC-009')]);
      expect(_isolated(e), hasLength(1));
      final d = _isolated(e).single;
      expect(d.nodeId, 'SPEC-009');
      expect(d.nodeType, 'SPEC');
      expect(d.path, 'docs/SPEC-009.md');
      expect(_missing(e), isEmpty);
    });

    test('E2 對照：無邊的 Ticket 不報孤島，同樣無邊的 SPEC 報', () {
      final e = buildGraphEvent([buildRawNode(id: _ticket), _spec('SPEC-009')]);
      expect(_isolated(e).map((d) => d.nodeId), ['SPEC-009']);
    });

    test('唯一引用值是斷邊的 PROP 報 danglingRef 與孤島各一筆', () {
      final e = buildGraphEvent([
        buildRawNode(
          id: 'PROP-002',
          typeName: 'PROP',
          extra: {
            'related_proposals': ['PROP-404'],
          },
        ),
      ]);
      expect(e.graphDefects.whereType<DanglingRefGraphDefect>(), hasLength(1));
      expect(_isolated(e).map((d) => d.nodeId), ['PROP-002']);
    });

    test('只有入邊的節點不是孤島', () {
      final e = buildGraphEvent([
        _spec('SPEC-001'),
        _spec(
          'SPEC-002',
          extra: {
            'related_specs': ['SPEC-001'],
          },
        ),
      ]);
      expect(_isolated(e), isEmpty);
    });

    test('一個節點至多一筆孤島', () {
      final e = buildGraphEvent([_spec('SPEC-009'), _spec('SPEC-010')]);
      expect(_isolated(e), hasLength(2));
    });
  });

  group('缺必要邊（SPEC-007 FR-09 判準二）', () {
    test('UC 缺 uc_ticket_refs 出邊報一筆，邊型清單為 [uc_ticket_refs]', () {
      final e = buildGraphEvent([
        ..._targets(),
        _uc(
          'UC-01',
          extra: {
            'source_proposal': ['PROP-001'],
            'related_specs': ['SPEC-001'],
          },
        ),
      ]);
      expect(_missing(e), hasLength(1));
      final d = _missing(e).single;
      expect(d.nodeId, 'UC-01');
      expect(d.nodeType, 'UC');
      expect(d.path, 'docs/UC-01.md');
      expect(d.edgeTypes, ['uc_ticket_refs']);
      expect(_isolated(e), isEmpty);
    });

    test(
      'UC 三條要求皆缺但有其他邊：三筆，列序為 provenance、spec_association、uc_ticket_refs',
      () {
        final e = buildGraphEvent([
          ..._targets(),
          _uc(
            'UC-01',
            extra: {
              'related_usecases': ['UC-02'],
            },
          ),
          _uc('UC-02'),
        ]);
        final byUc1 = _missing(e).where((d) => d.nodeId == 'UC-01').toList();
        expect(byUc1.map((d) => d.edgeTypes), [
          ['provenance'],
          ['spec_association'],
          ['uc_ticket_refs'],
        ]);
      },
    );

    test('E2 對照：沒有任何邊的 UC 只報孤島，不報缺必要邊', () {
      final e = buildGraphEvent([_uc('UC-01')]);
      expect(_isolated(e).map((d) => d.nodeId), ['UC-01']);
      expect(_missing(e), isEmpty);
    });

    test('三條要求皆滿足的 UC 不報', () {
      final e = buildGraphEvent([..._targets(), _fullUc('UC-01')]);
      expect(_missing(e), isEmpty);
      expect(_isolated(e), isEmpty);
    });

    test('入邊不滿足出邊要求：只被引用的 UC 缺 provenance 出邊', () {
      final e = buildGraphEvent([
        ..._targets(),
        _fullUc('UC-01'),
        _spec(
          'SPEC-002',
          extra: {
            'related_usecases': ['UC-02'],
          },
        ),
        _uc('UC-02'),
      ]);
      final uc2 = _missing(e).where((d) => d.nodeId == 'UC-02');
      expect(uc2, hasLength(3));
    });

    test('EVT 只有 spec_association 出邊：不報', () {
      final e = buildGraphEvent([
        _spec('SPEC-001'),
        _evt(
          'EVT-GRAPH-001',
          extra: {
            'related_specs': ['SPEC-001'],
          },
        ),
      ]);
      expect(_missing(e), isEmpty);
    });

    test('EVT 有入邊但 provenance 與 spec_association 出邊皆無：報一筆二擇一', () {
      final e = buildGraphEvent([
        _spec('SPEC-001'),
        _evt('EVT-GRAPH-001'),
        _uc(
          'UC-01',
          extra: {
            'source_proposal': ['PROP-001'],
            'related_specs': ['EVT-GRAPH-001'],
            'ticket_refs': [_ticket],
          },
        ),
        _prop('PROP-001'),
        buildRawNode(id: _ticket),
      ]);
      final evt = _missing(e).where((d) => d.nodeId == 'EVT-GRAPH-001');
      expect(evt, hasLength(1));
      expect(evt.single.nodeType, 'EVT');
      expect(evt.single.edgeTypes, ['provenance', 'spec_association']);
    });

    test('SPEC 沒有 provenance 出邊：不報缺必要邊', () {
      final e = buildGraphEvent([
        _spec('SPEC-001'),
        _spec(
          'SPEC-002',
          extra: {
            'related_specs': ['SPEC-001'],
          },
        ),
      ]);
      expect(_missing(e), isEmpty);
    });
  });

  group('必要邊型不在使用中邊型', () {
    test('型別表少了 uc_ticket_refs：UC 不報缺 uc_ticket_refs；對照組有該邊型時報', () {
      final nodes = [
        ..._targets(),
        _uc(
          'UC-01',
          extra: {
            'source_proposal': ['PROP-001'],
            'related_specs': ['SPEC-001'],
          },
        ),
      ];
      final schema = loadBuiltinSchemaJson();
      (schema['edge_types'] as Map<String, dynamic>).remove('uc_ticket_refs');
      expect(_missing(buildGraphEvent(nodes, schema)), isEmpty);
      expect(_missing(buildGraphEvent(nodes)), hasLength(1));
    });
  });

  group('graphDefects 總數', () {
    test('孤島與缺必要邊計入 graphDefects 筆數', () {
      final e = buildGraphEvent([
        ..._targets(),
        _spec('SPEC-009'),
        _uc(
          'UC-01',
          extra: {
            'source_proposal': ['PROP-001'],
            'related_specs': ['SPEC-001'],
          },
        ),
      ]);
      expect(e.graphDefects, hasLength(2));
      expect(e.isolatedNodeCount, 1);
      expect(e.missingRequiredEdgeCount, 1);
    });
  });

  // flutter_test 的 group 無 timeout 參數，逾時改掛在組內兩案。
  const corpusTimeout = Timeout(Duration(minutes: 5));
  group('語料零筆（SPEC-007 FR-09 驗收）', () {
    Future<GraphBuiltEvent> buildRoot(String root) async {
      final schemaJson = jsonDecode(
        File('$root/.claude/skills/doc/doc_system/core/tracking_schema.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final table = typeTableFromJson(schemaJson);
      final scan = await scanCorpus(
        fileSystem: DefaultDocsFileSystem(root),
        table: table,
        builtinTable: table,
      );
      final result = buildGraph(
        rawNodes: scan.rawNodes,
        projectSchemaJson: schemaJson,
        builtinSchemaJson: schemaJson,
      );
      return (result as GraphBuildAvailable).event;
    }

    test('本專案語料：孤島 0 筆、缺必要邊 0 筆', () async {
      final e = await buildRoot(Directory.current.path);
      expect(e.nodeCount, greaterThan(100));
      expect(_isolated(e), isEmpty);
      expect(_missing(e), isEmpty);
    }, timeout: corpusTimeout);

    final balance = '${Platform.environment['HOME']}/project/flutter_balance';
    test(
      'flutter_balance 語料：孤島 0 筆、缺必要邊 0 筆',
      () async {
        final e = await buildRoot(balance);
        expect(e.nodeCount, greaterThan(0));
        expect(_isolated(e), isEmpty);
        expect(_missing(e), isEmpty);
      },
      timeout: corpusTimeout,
      skip: Directory(balance).existsSync() ? false : '本機無 flutter_balance',
    );
  });
}
