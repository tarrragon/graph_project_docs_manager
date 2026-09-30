import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

void main() {
  group('G6 建圖結果與事件（FR-06）', () {
    test('G6-1 分布已知 fixture：各計數項等於已知值，守恆式成立', () {
      final known = buildKnownGraphDistribution();
      final event = buildGraphEvent(known.rawNodes);
      expect(event.nodeCount, known.nodeCount);
      expect(event.duplicateIdCount, known.duplicateIdCount);
      expect(event.edgeCount, known.edgeCount);
      expect(event.edgesByType, known.edgesByType);
      final directed = event.directedShapeCounts;
      expect(directed[DirectedDeclarationShape.fromOnly], known.directedFromOnly);
      expect(directed[DirectedDeclarationShape.toOnly], known.directedToOnly);
      expect(directed[DirectedDeclarationShape.both], known.directedBoth);
      expect(event.undirectedOneEndCount, known.undirectedOneEnd);
      expect(event.undirectedBothCount, known.undirectedBoth);
      expect(event.totalReferences, known.totalReferences);
      expect(event.resolvedCount, known.resolved);
      expect(event.danglingRefCount, known.dangling);
      expect(event.malformedRefCount, known.malformed);
      expect(event.multiSourceCount, known.multiSourceCount);
      expect(
        event.totalReferences,
        event.resolvedCount + event.danglingRefCount + event.malformedRefCount,
      );
    });

    test('G6-2 rawNodes 為空：建出空圖，計數全為 0，非錯誤', () {
      final event = buildGraphEvent(const []);
      expect(event.nodeCount, 0);
      expect(event.edgeCount, 0);
      expect(event.graphDefects, isEmpty);
    });

    test('G6-3 graphDefects 筆數 = 斷邊 + 格式錯誤 + duplicateId + multiSource', () {
      final known = buildKnownGraphDistribution();
      final event = buildGraphEvent(known.rawNodes);
      expect(event.graphDefects.length, known.graphDefectCount);
      expect(
        event.graphDefects.length,
        event.danglingRefCount +
            event.malformedRefCount +
            event.duplicateIdCount +
            event.multiSourceCount,
      );
    });

    test('G6-4 同一邊多次宣告：edgeCount 只計一次', () {
      final event = buildGraphEvent([
        buildRawNode(
          id: '0.1.0-W1-001',
          extra: {
            'source_ticket': '0.1.0-W1-002',
            'relatedTo': ['0.1.0-W1-002', '0.1.0-W1-002'],
          },
        ),
        buildRawNode(
          id: '0.1.0-W1-002',
          extra: {
            'spawned_tickets': ['0.1.0-W1-001', '0.1.0-W1-001'],
            'relatedTo': ['0.1.0-W1-001'],
          },
        ),
      ]);
      expect(event.edgesByType, {'spawn': 1, 'association': 1});
      expect(event.edgeCount, 2);
    });
  });
}
