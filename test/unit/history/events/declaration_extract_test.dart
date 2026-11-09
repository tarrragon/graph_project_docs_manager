// SPEC-008 FR-03：宣告抽取（測試設計 §3.3 E-1～E-11）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../../helpers/spec007/edge_table_builder.dart';

final _ticketPattern = RegExp(r'^[\w.]+-W\d+-\d+(\.\d+)*$');

const _baseEdges = <String, EdgeSpec>{
  'spawn': EdgeSpec(
    forwardField: 'source_ticket',
    reverseField: 'spawned_tickets',
    direction: 'directed',
  ),
  'association': EdgeSpec(forwardField: 'relatedTo', direction: 'undirected'),
  'closed_by': EdgeSpec(
    forwardField: 'closed_by',
    layer: 'proposed',
    direction: 'directed',
  ),
  'domain_dependency': EdgeSpec(
    forwardField: 'domain_dependency',
    direction: 'directed',
  ),
  'bundle_dependency': EdgeSpec(
    forwardField: 'bundle_dependency',
    layer: 'proposed',
    direction: 'directed',
  ),
  'other_proposed': EdgeSpec(
    forwardField: 'proposed_refs',
    layer: 'proposed',
    direction: 'directed',
  ),
  'blood': EdgeSpec(
    forwardField: 'parent_id',
    reverseField: 'children',
    direction: 'directed',
  ),
};

DeclarationExtractor extractorOf(Map<String, EdgeSpec> edges) {
  final table = buildEdgeTableJson(edges: edges);
  final resolution = resolveEdgeTypes(
    projectSchemaJson: table,
    builtinSchemaJson: table,
  );
  return DeclarationExtractor(
    activeEdgeTypes: resolution.activeEdgeTypes,
    closedByIdPatterns: [_ticketPattern],
  );
}

Set<String> declSet(DeclarationExtraction e) => {
  for (final d in e.declarations) '${d.edgeType.name}|${d.field}|${d.value}',
};

void main() {
  final base = extractorOf(_baseEdges);

  group('E 宣告抽取（FR-03）', () {
    test('E-1 block 清單加一列：宣告集合多一筆 spawn 值，宣告者為 id', () {
      final before = base.extract('id: P\nspawned_tickets:\n  - A\n  - B\n');
      final after = base.extract(
        'id: P\nspawned_tickets:\n  - A\n  - B\n  - C\n',
      );
      expect(before.nodeId, 'P');
      expect(declSet(after).difference(declSet(before)), {
        'spawn|spawned_tickets|C',
      });
    });

    test('E-2 型別表新增 established 邊型：不改程式即產生宣告', () {
      final e = extractorOf({
        ..._baseEdges,
        'fixture_link': const EdgeSpec(
          forwardField: 'fixture_refs',
          direction: 'directed',
        ),
      });
      final r = e.extract('id: A\nfixture_refs: [B]\n');
      expect(declSet(r), {'fixture_link|fixture_refs|B'});
    });

    test('E-3 同一 frontmatter、型別表不含該邊型：不產生宣告', () {
      final r = base.extract('id: A\nfixture_refs: [B]\n');
      expect(r.declarations, isEmpty);
    });

    test('E-4 closed_by 外部格式值：不產生宣告', () {
      final r = base.extract('id: A\nclosed_by: tarrragon/claude#60\n');
      expect(r.declarations, isEmpty);
    });

    test('E-5 closed_by 符合 id_pattern：產生宣告（正向對照）', () {
      final r = base.extract('id: A\nclosed_by: 0.1.0-W1-002\n');
      expect(declSet(r), {'closed_by|closed_by|0.1.0-W1-002'});
    });

    test('E-6 純量、清單、反向欄位 map：宣告數等於值數；null 與空清單無宣告', () {
      final e = extractorOf({
        'blood': _baseEdges['blood']!,
        'outs': const EdgeSpec(
          forwardField: 'in_field',
          reverseField: 'outputs',
          direction: 'directed',
        ),
      });
      final r = e.extract(
        'id: A\nparent_id: P\nchildren: [C1, C2]\n'
        'outputs:\n  x: [O1, O2]\n  y: [O3]\nin_field: null\n',
      );
      expect(declSet(r), {
        'blood|parent_id|P',
        'blood|children|C1',
        'blood|children|C2',
        'outs|outputs|O1',
        'outs|outputs|O2',
        'outs|outputs|O3',
      });
      expect(base.extract('id: A\nchildren: []\n').declarations, isEmpty);
    });

    test('E-7 relatedTo: [3, true, B]：只有 B，非字串值計數 2', () {
      final r = base.extract('id: A\nrelatedTo: [3, true, B]\n');
      expect(declSet(r), {'association|relatedTo|B'});
      expect(r.nonStringValues, 2);
    });

    test('E-8 無 id：無宣告，標記無 ID 檔案', () {
      final r = base.extract('parent_id: A\n');
      expect(r.declarations, isEmpty);
      expect(r.missingId, isTrue);
    });

    test('E-9 指向不存在節點的值仍產生宣告', () {
      final r = base.extract('id: A\nparent_id: NOT-EXIST\n');
      expect(declSet(r), {'blood|parent_id|NOT-EXIST'});
    });

    test('E-10 domain_dependency 值為名稱：產生宣告', () {
      final r = base.extract('id: D\ndomain_dependency: [schema]\n');
      expect(declSet(r), {'domain_dependency|domain_dependency|schema'});
    });

    test('E-11 proposed 層（bundle_dependency／closed_by 以外）不產生宣告', () {
      final r = base.extract(
        'id: A\nproposed_refs: [X]\nbundle_dependency: [DOMAIN-MAP-a]\n',
      );
      expect(declSet(r), {'bundle_dependency|bundle_dependency|DOMAIN-MAP-a'});
    });

    test('無 frontmatter 與無法解析：分別為空與 parseFailed', () {
      expect(base.extract(null).declarations, isEmpty);
      expect(base.extract(null).missingId, isFalse);
      expect(base.extract('id: [unclosed\n').parseFailed, isTrue);
    });
  });
}
