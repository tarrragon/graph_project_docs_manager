import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/domain_name_resolver.dart';
import 'package:graph_project_docs_manager/graph/flow_subgraph.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import '../../helpers/spec006/fake_docs_fs.dart';
import '../../helpers/spec006/type_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _uc = 'UC-01';

RawNode _bundle(String id, Object? domain, {Map<String, dynamic>? extra}) =>
    buildRawNode(
      id: id,
      typeName: domainBundleTypeName,
      extra: {domainBundleDomainField: domain, ...?extra},
    );

RawNode _ucNode(List<Map<String, dynamic>> steps) => RawNode(
  path: 'docs/usecases/$_uc.md',
  frontmatter: {'id': _uc},
  typeName: flowSourceTypeName,
  flowSteps: steps,
);

Map<String, dynamic> _step(String id, [Object? traverses = const []]) => {
  'id': id,
  'traverses': traverses,
};

GraphBuiltEvent _build(List<RawNode> nodes) => (buildGraph(
  rawNodes: nodes,
  projectSchemaJson: loadBuiltinSchemaJson(),
  builtinSchemaJson: loadBuiltinSchemaJson(),
) as GraphBuildAvailable).event;

List<FlowGraphDefect> _flowDefects(GraphBuiltEvent e) =>
    e.graphDefects.whereType<FlowGraphDefect>().toList();

List<DomainDuplicateDeclarationGraphDefect> _dupDefects(GraphBuiltEvent e) =>
    e.graphDefects.whereType<DomainDuplicateDeclarationGraphDefect>().toList();

FlowStepNode _only(GraphBuiltEvent e, String stepId) =>
    e.flowSubgraphs[_uc]!.steps.firstWhere((s) => s.id == stepId);

List<String> _resolvedIds(FlowStepNode s) => [
  for (final r in s.traversesResolution.resolved) r.bundleId,
];

List<(FlowDefectKind, Object?, Object?)> _sig(GraphBuiltEvent e) => [
  for (final d in _flowDefects(e)) (d.kind, d.stepId, d.rawValue),
];

void main() {
  group('G11 名稱解析（FR-11）', () {
    test('G11-1 解析到 DomainBundle 節點 ID、無缺陷', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([
          _step('a', ['corpus']),
        ]),
      ]);
      expect(_resolvedIds(_only(e, 'a')), ['DOMAIN-MAP-corpus']);
      expect(_flowDefects(e), isEmpty);
    });

    test('G11-2 守衛：未宣告名稱一筆缺陷，負載齊全（對照 G11-1）', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([
          _step('a', ['nope']),
        ]),
      ]);
      final d = _flowDefects(e).single;
      expect(d.kind, FlowDefectKind.traversesUndeclared);
      expect(
        (d.ucId, d.stepId, d.field, d.rawValue),
        (_uc, 'a', FlowFields.traverses, 'nope'),
      );
      expect(_only(e, 'a').traversesResolution.resolved, isEmpty);
    });

    test('G11-3 守衛：區分大小寫、不去空白', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([
          _step('a', ['Corpus']),
          _step('b', [' corpus']),
          _step('ok', ['corpus']),
        ]),
      ]);
      expect(_sig(e), [
        (FlowDefectKind.traversesUndeclared, 'a', 'Corpus'),
        (FlowDefectKind.traversesUndeclared, 'b', ' corpus'),
      ]);
    });

    test('G11-4 E1 鑑別：以 domain 欄索引，不由 ID 拼接或拆解', () {
      final e = _build([
        _bundle('DOMAIN-MAP-alpha', 'beta'),
        _ucNode([
          _step('b', ['beta']),
          _step('a', ['alpha']),
        ]),
      ]);
      expect(_resolvedIds(_only(e, 'b')), ['DOMAIN-MAP-alpha']);
      expect(_resolvedIds(_only(e, 'a')), isEmpty);
      expect(_sig(e), [(FlowDefectKind.traversesUndeclared, 'a', 'alpha')]);
    });

    test('G11-5 ID 不符慣例仍解析成功', () {
      final e = _build([
        _bundle('BUNDLE-x', 'x'),
        _ucNode([
          _step('a', ['x']),
        ]),
      ]);
      expect(_resolvedIds(_only(e, 'a')), ['BUNDLE-x']);
      expect(_flowDefects(e), isEmpty);
    });

    test('G11-6 空清單：無結果、無缺陷，與缺鍵可區分', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([_step('a')]),
      ]);
      final r = _only(e, 'a').traversesResolution;
      expect(r.resolved, isEmpty);
      expect(r.keyAbsent, isFalse);
      expect(_flowDefects(e), isEmpty);
    });

    test('G11-7 逐值回報：一成功、兩缺陷', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([
          _step('a', ['corpus', 'nope', 'nope2']),
        ]),
      ]);
      expect(_resolvedIds(_only(e, 'a')), ['DOMAIN-MAP-corpus']);
      expect(_sig(e), [
        (FlowDefectKind.traversesUndeclared, 'a', 'nope'),
        (FlowDefectKind.traversesUndeclared, 'a', 'nope2'),
      ]);
    });

    test('G11-8 depends_on_domains 不建邊、不產生缺陷', () {
      final e = _build([
        buildRawNode(
          id: 'SPEC-001',
          typeName: 'SPEC',
          extra: {
            'depends_on_domains': ['corpus'],
          },
        ),
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
      ]);
      expect(e.edgeCount, 0);
      expect(e.graphDefects, isEmpty);
      expect(e.edgesByType.containsKey('domain_dependency'), isFalse);
    });

    test('G11-9 解析器公開面：名稱字串進、節點 ID 或 null 出，可反查', () {
      final r = DomainNameResolver.fromDeclarations([
        ('B-1', 'corpus'),
        ('B-2', 'graph'),
      ]);
      expect(r.resolve('corpus'), 'B-1');
      expect(r.resolve('Corpus'), isNull);
      expect(r.resolve('nope'), isNull);
      expect(r.resolve(1), isNull);
      expect(r.domainOf('B-2'), 'graph');
      expect(r.domainOf('UC-01'), isNull);
    });

    // bundle_dependency 尚未進使用中邊型（內建表為 proposed，SPEC-007 D2 的
    // 啟用由其他票承接），故本案只驗證解析器與節點 ID 值互不相干：
    // 節點 ID 不是名稱，宣告 depends_on_bundles 不使解析器產生任何缺陷。
    test('G11-10 DomainBundle 的 ID 值不經名稱解析器：ID 字面不是名稱', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _bundle(
          'DOMAIN-MAP-graph',
          'graph',
          extra: {
            'depends_on_bundles': ['DOMAIN-MAP-corpus'],
          },
        ),
      ]);
      expect(e.domainResolver.resolve('DOMAIN-MAP-corpus'), isNull);
      expect(e.domainResolver.resolve('corpus'), 'DOMAIN-MAP-corpus');
      expect(e.graphDefects, isEmpty);
    });

    test('G11-11 E1 去重：同一步重複的未宣告值一筆，對照組兩筆', () {
      final dup = _build([
        _ucNode([
          _step('a', ['nope', 'nope']),
        ]),
      ]);
      final distinct = _build([
        _ucNode([
          _step('a', ['nope', 'nope2']),
        ]),
      ]);
      expect(_flowDefects(dup), hasLength(1));
      expect(_flowDefects(distinct), hasLength(2));
    });

    test('G11-12 去重以步驟為單位，不跨步驟合併', () {
      final e = _build([
        _ucNode([
          _step('a', ['nope']),
          _step('b', ['nope']),
        ]),
      ]);
      expect(_sig(e), [
        (FlowDefectKind.traversesUndeclared, 'a', 'nope'),
        (FlowDefectKind.traversesUndeclared, 'b', 'nope'),
      ]);
    });

    test('G11-13 守衛＋E1：缺鍵一筆（原始值 null），[] 零缺陷', () {
      final e = _build([
        _ucNode([
          {'id': 'S1'},
          _step('S2'),
        ]),
      ]);
      final d = _flowDefects(e).single;
      expect(d.kind, FlowDefectKind.traversesKeyAbsent);
      expect(
        (d.ucId, d.stepId, d.field, d.rawValue),
        (_uc, 'S1', FlowFields.traverses, null),
      );
      expect(_only(e, 'S1').traversesResolution.keyAbsent, isTrue);
      expect(_only(e, 'S2').traversesResolution.keyAbsent, isFalse);
      expect(_only(e, 'S1').traversesResolution.resolved, isEmpty);
      expect(_only(e, 'S2').traversesResolution.resolved, isEmpty);
    });

    test('G11-14 部分已宣告：只含已宣告值，未宣告另報', () {
      final e = _build([
        _bundle('DOMAIN-MAP-graph', 'graph'),
        _ucNode([
          _step('a', ['graph', 'nope']),
        ]),
      ]);
      expect(_resolvedIds(_only(e, 'a')), ['DOMAIN-MAP-graph']);
      expect(_sig(e), [(FlowDefectKind.traversesUndeclared, 'a', 'nope')]);
    });

    test('G11-15 守衛＋E1：重複 domain 不取其一，兩節點仍在（對照組正常）', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _bundle('BUNDLE-corpus-2', 'corpus'),
        _ucNode([
          _step('a', ['corpus']),
        ]),
      ]);
      expect(_sig(e), [(FlowDefectKind.traversesUndeclared, 'a', 'corpus')]);
      final dup = _dupDefects(e).single;
      expect(dup.domain, 'corpus');
      expect(dup.bundleIds.toSet(), {'DOMAIN-MAP-corpus', 'BUNDLE-corpus-2'});
      expect(
        e.nodes.map((n) => n.id),
        containsAll(['DOMAIN-MAP-corpus', 'BUNDLE-corpus-2']),
      );
      expect(e.domainResolver.domainOf('BUNDLE-corpus-2'), 'corpus');

      final ok = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _bundle('BUNDLE-corpus-2', 'corpus2'),
        _ucNode([
          _step('a', ['corpus']),
        ]),
      ]);
      expect(_resolvedIds(_only(ok, 'a')), ['DOMAIN-MAP-corpus']);
      expect(ok.graphDefects, isEmpty);
    });

    test('G11-16 三者重複：恰一筆，清單含三個', () {
      final e = _build([
        _bundle('P1', 'corpus'),
        _bundle('P2', 'corpus'),
        _bundle('P3', 'corpus'),
      ]);
      expect(_dupDefects(e).single.bundleIds.toSet(), {'P1', 'P2', 'P3'});
    });

    test('G11-17 兩個 domain 各重複：兩筆', () {
      final e = _build([
        _bundle('P1', 'corpus'),
        _bundle('P2', 'corpus'),
        _bundle('P3', 'graph'),
        _bundle('P4', 'graph'),
      ]);
      expect({for (final d in _dupDefects(e)) d.domain}, {'corpus', 'graph'});
      expect(_dupDefects(e), hasLength(2));
    });

    test('G11-18 重複宣告：兩步各一筆未宣告，重複宣告仍一筆', () {
      final e = _build([
        _bundle('P1', 'corpus'),
        _bundle('P2', 'corpus'),
        _ucNode([
          _step('a', ['corpus']),
          _step('b', ['corpus']),
        ]),
      ]);
      expect(_sig(e), [
        (FlowDefectKind.traversesUndeclared, 'a', 'corpus'),
        (FlowDefectKind.traversesUndeclared, 'b', 'corpus'),
      ]);
      expect(_dupDefects(e), hasLength(1));
    });

    test('G10-11 traverses 原值保留、不修剪不轉型，解析結果另存', () {
      final e = _build([
        _bundle('DOMAIN-MAP-corpus', 'corpus'),
        _ucNode([
          _step('a', ['corpus', ' x', 7]),
        ]),
      ]);
      final s = _only(e, 'a');
      expect(s.traverses, ['corpus', ' x', 7]);
      expect(_resolvedIds(s), ['DOMAIN-MAP-corpus']);
      expect(s.traversesResolution.undeclared, [' x', 7]);
    });

    test('重複宣告與缺陷計入 graphDefects 總數（FR-06）', () {
      final e = _build([
        _bundle('P1', 'corpus'),
        _bundle('P2', 'corpus'),
        _ucNode([
          _step('a', ['corpus']),
          {'id': 'b'},
        ]),
      ]);
      expect(e.graphDefects, hasLength(3));
    });
  });

  group('兩語料 traverses 解析（FR-11 驗收 1）', () {
    const root = 'test/fixtures/spec001/corpus_snapshot';

    TypeTable table() => TypeTableBuilder()
        .addType(
          'UC',
          idPattern: r'^UC-\d{2}$',
          carrierPathPatterns: const [
            PathPatternSpec(
              pattern: r'^docs/usecases/.*\.md$',
              specificity: [2, 0],
            ),
          ],
        )
        .addType(
          domainBundleTypeName,
          idPattern: r'^DOMAIN-MAP-.+$',
          carrierPathPatterns: const [
            PathPatternSpec(
              pattern: r'^docs/(spec/[^/]+/)?domain-map\.md$',
              specificity: [2, 0],
            ),
          ],
        )
        .build();

    Future<GraphBuiltEvent> buildOf(String project) async {
      final fs = FakeDocsFileSystem();
      final base = Directory('$root/$project/docs');
      for (final f in base.listSync(recursive: true).whereType<File>()) {
        final rel = f.path.substring('$root/$project/'.length);
        if (rel.contains('/usecases/')) {
          final id = RegExp(r'UC-\d+').firstMatch(rel)![0]!;
          fs.addFile('docs/usecases/$id.md', [
            ...utf8.encode('---\nid: $id\n---\n\n'),
            ...f.readAsBytesSync(),
          ]);
        } else if (rel.endsWith('domain-map.md')) {
          fs.addFile(rel, f.readAsBytesSync());
        }
      }
      final scan = await scanCorpus(
        fileSystem: fs,
        table: table(),
        builtinTable: table(),
      );
      return _build(scan.rawNodes);
    }

    test('graph_project_docs_manager：八個 bundle，全部 traverses 值解析、零缺陷', () async {
      final e = await buildOf('graph_project_docs_manager');
      expect(e.domainResolver.bundleIds, hasLength(8));
      var declared = 0;
      var resolved = 0;
      for (final g in e.flowSubgraphs.values) {
        for (final s in g.steps) {
          declared += (s.traverses! as List).length;
          for (final r in s.traversesResolution.resolved) {
            resolved++;
            expect(e.domainResolver.domainOf(r.bundleId), r.name);
          }
        }
      }
      expect(declared, greaterThan(0));
      expect(resolved, declared);
      // 其餘 dangling 來自 domain-map 指向未載入的 SPEC／UC，與 FR-11 無關。
      expect(_flowDefects(e), isEmpty);
      expect(_dupDefects(e), isEmpty);
    });

    test('flutter_balance：bundle 解析成功；UC 步驟皆無 traverses 鍵，各報缺鍵', () async {
      final e = await buildOf('flutter_balance');
      expect(e.domainResolver.resolve('balance-sheet'), isNotNull);
      final steps = [for (final g in e.flowSubgraphs.values) ...g.steps];
      expect(steps, isNotEmpty);
      final defects = _flowDefects(e);
      expect(defects, hasLength(steps.length));
      expect(
        defects.every((d) => d.kind == FlowDefectKind.traversesKeyAbsent),
        isTrue,
      );
      expect(_dupDefects(e), isEmpty);
    });
  });
}
