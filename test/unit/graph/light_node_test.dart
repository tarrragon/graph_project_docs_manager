import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';

import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

void main() {
  group('G1 輕節點（FR-02）', () {
    test('G1-1 欄位集合恰為五項且不共用 frontmatter 引用', () {
      final raw = buildRawNode(
        id: '0.1.0-W1-001',
        extra: {'status': 'open', 'title': 'T', 'who': 'a', 'what': 'b'},
      );
      final node = buildLightNodes([raw]).nodes.single;
      expect(node.id, '0.1.0-W1-001');
      expect(node.typeName, 'Ticket');
      expect(node.status, 'open');
      expect(node.title, 'T');
      expect(node.path, 'docs/0.1.0-W1-001.md');
      raw.frontmatter['status'] = 'changed';
      expect(node.status, 'open');
    });

    test('G1-2 status、title 非字串時為 null', () {
      final raw = buildRawNode(
        id: '0.1.0-W1-001',
        extra: {
          'status': 3,
          'title': ['a'],
        },
      );
      final node = buildLightNodes([raw]).nodes.single;
      expect(node.status, isNull);
      expect(node.title, isNull);
    });

    test('G1-3 缺 status、title 時為 null', () {
      final node = buildLightNodes([buildRawNode(id: 'X-W1-1')]).nodes.single;
      expect(node.status, isNull);
      expect(node.title, isNull);
    });

    test('G1-4 同 id 兩份：皆不在圖上並回報 duplicateId；id 不同則皆在', () {
      final dup = buildLightNodes([
        buildRawNode(id: 'X-W1-1', path: 'docs/a.md'),
        buildRawNode(id: 'X-W1-1', path: 'docs/b.md'),
      ]);
      expect(dup.nodes, isEmpty);
      expect(dup.duplicates, hasLength(1));
      expect(dup.duplicates.single.id, 'X-W1-1');
      expect(dup.duplicates.single.paths, ['docs/a.md', 'docs/b.md']);

      final distinct = buildLightNodes([
        buildRawNode(id: 'X-W1-1', path: 'docs/a.md'),
        buildRawNode(id: 'X-W1-2', path: 'docs/b.md'),
      ]);
      expect(distinct.nodes, hasLength(2));
      expect(distinct.duplicates, isEmpty);
    });

    test('G1-4 重複 id 節點的引用值不進任何分類計數', () {
      final inputs = graphInputsFrom();
      final result = classifyGraphReferences(
        rawNodes: [
          buildRawNode(
            id: '0.1.0-W1-001',
            path: 'docs/a.md',
            extra: {
              'relatedTo': ['0.1.0-W1-009'],
            },
          ),
          buildRawNode(
            id: '0.1.0-W1-001',
            path: 'docs/b.md',
            extra: {
              'relatedTo': ['0.1.0-W1-009'],
            },
          ),
        ],
        edgeTypes: inputs.edgeTypes,
        nodeTypes: inputs.nodeTypes,
      );
      expect(result.totalReferences, 0);
      expect(result.resolved, isEmpty);
      expect(result.dangling, isEmpty);
      expect(result.malformed, isEmpty);
    });

    test('G1-5 指向重複 id 的引用為 targetDuplicated', () {
      final inputs = graphInputsFrom();
      final result = classifyGraphReferences(
        rawNodes: [
          buildRawNode(id: '0.1.0-W1-001', path: 'docs/a.md'),
          buildRawNode(id: '0.1.0-W1-001', path: 'docs/b.md'),
          buildRawNode(
            id: '0.1.0-W1-002',
            extra: {
              'relatedTo': ['0.1.0-W1-001'],
            },
          ),
        ],
        edgeTypes: inputs.edgeTypes,
        nodeTypes: inputs.nodeTypes,
      );
      expect(result.dangling, hasLength(1));
      expect(result.dangling.single.reason, DanglingReason.targetDuplicated);
      expect(result.resolved, isEmpty);
    });

    test('G1-6 三份同 id：一筆 duplicateId 帶三個路徑', () {
      final build = buildLightNodes([
        buildRawNode(id: 'X-W1-1', path: 'docs/a.md'),
        buildRawNode(id: 'X-W1-1', path: 'docs/b.md'),
        buildRawNode(id: 'X-W1-1', path: 'docs/c.md'),
      ]);
      expect(build.duplicates, hasLength(1));
      expect(build.duplicates.single.paths, hasLength(3));
    });
  });
}
