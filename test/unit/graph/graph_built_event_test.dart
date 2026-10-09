import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';

GraphEdge _edge(Set<String> declaredBy) => GraphEdge(
  edgeType: 'spawn',
  from: 'A',
  to: 'B',
  declaredBy: declaredBy,
  isUndirected: false,
  layer: 'established',
);

void main() {
  group('不可變集合（0.4.1-W1-004）', () {
    test('事件的 nodes／edges／graphDefects 寫入拋 UnsupportedError', () {
      final event = GraphBuiltEvent(
        nodes: [
          const LightNode(
            id: 'A',
            typeName: 'Ticket',
            status: null,
            title: null,
            path: 'a.md',
          ),
        ],
        edges: [
          _edge({'A'}),
        ],
        graphDefects: [],
        totalReferences: 0,
        resolvedCount: 0,
      );
      expect(() => event.nodes.add(event.nodes.first), throwsUnsupportedError);
      expect(() => event.edges.add(event.edges.first), throwsUnsupportedError);
      expect(
        () =>
            event.graphDefects.add(DuplicateIdGraphDefect(id: 'x', paths: [])),
        throwsUnsupportedError,
      );
    });

    test('GraphEdge.declaredBy 與來源集合脫鉤且唯讀', () {
      final source = {'A'};
      final edge = _edge(source);
      expect(() => edge.declaredBy.add('B'), throwsUnsupportedError);
      source.add('B');
      expect(edge.declaredBy, {'A'});
    });

    test('MultiSourceTarget.declaredBy 唯讀', () {
      final target = MultiSourceTarget(to: 'B', declaredBy: {'A'});
      expect(() => target.declaredBy.add('B'), throwsUnsupportedError);
    });

    test(
      'DuplicateIdGraphDefect.paths 與 MultiSourceGraphDefect.targets 唯讀',
      () {
        final dup = DuplicateIdGraphDefect(id: 'x', paths: ['a.md']);
        expect(() => dup.paths.add('b.md'), throwsUnsupportedError);
        final multi = MultiSourceGraphDefect(
          from: 'A',
          edgeType: 'spawn',
          targets: [
            MultiSourceTarget(to: 'B', declaredBy: {'A'}),
          ],
        );
        expect(
          () => multi.targets.add(multi.targets.first),
          throwsUnsupportedError,
        );
      },
    );

    test('正向對照：計數與分佈與建構內容一致', () {
      final event = GraphBuiltEvent(
        nodes: const [],
        edges: [
          _edge({'A'}),
          _edge({'A', 'B'}),
        ],
        graphDefects: [
          DuplicateIdGraphDefect(id: 'x', paths: ['a.md']),
        ],
        totalReferences: 2,
        resolvedCount: 2,
      );
      expect(event.edgeCount, 2);
      expect(event.duplicateIdCount, 1);
      expect(event.edgesByType, {'spawn': 2});
      expect(event.directedShapeCounts, {
        DirectedDeclarationShape.fromOnly: 1,
        DirectedDeclarationShape.toOnly: 0,
        DirectedDeclarationShape.both: 1,
      });
    });
  });
}
