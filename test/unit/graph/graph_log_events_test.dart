import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/graph/adjacency_query.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';

import '../../helpers/spec007/edge_table_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/log_recorder.dart';
import '../../helpers/spec007/raw_node_builder.dart';

GraphBuildResult _build(
  LogRecorder recorder,
  List<RawNode> rawNodes,
  Map<String, dynamic>? project,
) => buildGraph(
  rawNodes: rawNodes,
  projectSchemaJson: project,
  builtinSchemaJson: loadBuiltinSchemaJson(),
  logSink: recorder.sink,
);

Map<String, dynamic> _missingEdgeTypesHigherVersion() =>
    buildEdgeTableJson(version: '99.0.0');

Map<String, dynamic> _missingCardinalityHigherVersion() => buildEdgeTableJson(
  version: '99.0.0',
  edges: {
    'custom': const EdgeSpec(forwardField: 'f', forwardCardinality: null),
  },
);

void main() {
  group('L1 建圖完成日誌', () {
    test('L1-1 分布已知 fixture：恰一筆建圖完成，負載為實際結果值', () {
      final known = buildKnownGraphDistribution();
      final recorder = LogRecorder();
      _build(recorder, known.rawNodes, loadBuiltinSchemaJson());
      final logs = recorder.ofEvent(GraphLogEvent.buildCompleted);
      expect(recorder.entries.length, 1);
      expect(logs.single.payload, {
        GraphLogKeys.nodeCount: known.nodeCount,
        GraphLogKeys.edgeCount: known.edgeCount,
        GraphLogKeys.danglingRefCount: known.dangling,
        GraphLogKeys.malformedRefCount: known.malformed,
        GraphLogKeys.duplicateIdCount: known.duplicateIdCount,
        GraphLogKeys.multiSourceCount: known.multiSourceCount,
        GraphLogKeys.resolvedCount: known.resolved,
        GraphLogKeys.totalReferences: known.totalReferences,
      });
    });

    test('L1-2 E1 鑑別：空 rawNodes 的計數全為 0，且與 L1-1 負載不同', () {
      final empty = LogRecorder();
      _build(empty, const [], loadBuiltinSchemaJson());
      final emptyPayload = empty
          .ofEvent(GraphLogEvent.buildCompleted)
          .single
          .payload;
      expect(emptyPayload.values.every((v) => v == 0), isTrue);

      final filled = LogRecorder();
      _build(
        filled,
        buildKnownGraphDistribution().rawNodes,
        loadBuiltinSchemaJson(),
      );
      final filledPayload = filled
          .ofEvent(GraphLogEvent.buildCompleted)
          .single
          .payload;
      expect(filledPayload, isNot(emptyPayload));
    });

    test('L1-3 不存在只記開始而無結果值的事件：每筆事件皆帶結果負載', () {
      final recorder = LogRecorder();
      _build(
        recorder,
        buildKnownGraphDistribution().rawNodes,
        loadBuiltinSchemaJson(),
      );
      expect(recorder.entries, isNotEmpty);
      for (final entry in recorder.entries) {
        expect(entry.payload, isNotEmpty);
      }
      expect(
        recorder.entries.single.payload.containsKey(GraphLogKeys.nodeCount),
        isTrue,
      );
    });
  });

  group('L2 建圖不可用日誌', () {
    test('L2-1 缺 edge_types 且版本不在已知範圍：恰一筆，原因碼為版本不在已知範圍', () {
      final recorder = LogRecorder();
      final result = _build(
        recorder,
        const [],
        _missingEdgeTypesHigherVersion(),
      );
      expect(result, isA<GraphBuildUnavailable>());
      final logs = recorder.ofEvent(GraphLogEvent.buildUnavailable);
      expect(recorder.entries.length, 1);
      expect(logs.single.payload, {
        GraphLogKeys.reason:
            EdgeTypeUnavailableReason.projectVersionOutOfKnownRange.name,
      });
    });

    test('L2-2 缺正向基數：原因碼與 L2-1 不同', () {
      final recorder = LogRecorder();
      final result = _build(
        recorder,
        const [],
        _missingCardinalityHigherVersion(),
      );
      expect(result, isA<GraphBuildUnavailable>());
      final reason = recorder
          .ofEvent(GraphLogEvent.buildUnavailable)
          .single
          .payload[GraphLogKeys.reason];
      expect(reason, EdgeTypeUnavailableReason.missingForwardCardinality.name);
      expect(
        reason,
        isNot(EdgeTypeUnavailableReason.projectVersionOutOfKnownRange.name),
      );
    });

    test('L2-4 邊型值為字串且版本高於內建：原因碼與 L2-1、L2-2 皆不同', () {
      final table = buildEdgeTableJson(version: '99.0.0', edges: const {});
      (table['edge_types'] as Map<String, dynamic>)['association'] = 'oops';
      final recorder = LogRecorder();
      final result = _build(recorder, const [], table);
      expect(result, isA<GraphBuildUnavailable>());
      final reason = recorder
          .ofEvent(GraphLogEvent.buildUnavailable)
          .single
          .payload[GraphLogKeys.reason];
      expect(reason, EdgeTypeUnavailableReason.invalidEdgeTypeEntry.name);
      expect(
        reason,
        isNot(EdgeTypeUnavailableReason.projectVersionOutOfKnownRange.name),
      );
      expect(
        reason,
        isNot(EdgeTypeUnavailableReason.missingForwardCardinality.name),
      );
    });

    test('L2-3 守衛：可用型別表不記建圖不可用；正向對照為 L2-1', () {
      final ok = LogRecorder();
      final result = _build(ok, const [], loadBuiltinSchemaJson());
      expect(result, isA<GraphBuildAvailable>());
      expect(ok.ofEvent(GraphLogEvent.buildUnavailable), isEmpty);

      final bad = LogRecorder();
      _build(bad, const [], _missingEdgeTypesHigherVersion());
      expect(bad.ofEvent(GraphLogEvent.buildUnavailable), hasLength(1));
    });
  });

  group('L3 鄰接查詢圖不可用日誌', () {
    AdjacencyQuery unavailableQuery(LogRecorder recorder) => AdjacencyQuery(
      buildResult: buildGraph(
        rawNodes: const [],
        projectSchemaJson: _missingEdgeTypesHigherVersion(),
        builtinSchemaJson: loadBuiltinSchemaJson(),
      ),
      logSink: recorder.sink,
    );

    test('L3-1 圖不可用時連續三次查詢：事件恰記一次，帶原因碼', () {
      final recorder = LogRecorder();
      final q = unavailableQuery(recorder);
      for (var i = 0; i < 3; i++) {
        expect(q.query('0.1.0-W1-001'), isA<AdjacencyUnavailable>());
      }
      final logs = recorder.ofEvent(GraphLogEvent.adjacencyUnavailable);
      expect(logs, hasLength(1));
      expect(recorder.entries, hasLength(1));
      expect(logs.single.payload, {
        GraphLogKeys.reason:
            EdgeTypeUnavailableReason.projectVersionOutOfKnownRange.name,
      });
    });

    test('L3-3 同一 buildResult 的兩個實例各查三次：事件恰記一次', () {
      final recorder = LogRecorder();
      final shared = buildGraph(
        rawNodes: const [],
        projectSchemaJson: _missingEdgeTypesHigherVersion(),
        builtinSchemaJson: loadBuiltinSchemaJson(),
      );
      final a = AdjacencyQuery(buildResult: shared, logSink: recorder.sink);
      final b = AdjacencyQuery(buildResult: shared, logSink: recorder.sink);
      for (var i = 0; i < 3; i++) {
        a.query('0.1.0-W1-001');
        b.query('0.1.0-W1-001');
      }
      expect(
        recorder.ofEvent(GraphLogEvent.adjacencyUnavailable),
        hasLength(1),
      );
    });

    test('L3-4 buildResult 為 null：每個實例各記一次', () {
      final recorder = LogRecorder();
      final a = AdjacencyQuery(buildResult: null, logSink: recorder.sink);
      final b = AdjacencyQuery(buildResult: null, logSink: recorder.sink);
      for (var i = 0; i < 3; i++) {
        a.query('0.1.0-W1-001');
        b.query('0.1.0-W1-001');
      }
      final logs = recorder.ofEvent(GraphLogEvent.adjacencyUnavailable);
      expect(logs, hasLength(2));
      expect(logs.first.payload, {
        GraphLogKeys.reason: AdjacencyUnavailableCause.buildNotCompleted.name,
      });
    });

    test('L3-2 守衛：可用圖查詢十次（含查無鄰居）不記事件；正向對照為 L3-1', () {
      final recorder = LogRecorder();
      final q = AdjacencyQuery(
        buildResult: buildGraph(
          rawNodes: [buildRawNode(id: '0.1.0-W1-001')],
          projectSchemaJson: loadBuiltinSchemaJson(),
          builtinSchemaJson: loadBuiltinSchemaJson(),
        ),
        logSink: recorder.sink,
      );
      for (var i = 0; i < 10; i++) {
        q.query(i.isEven ? '0.1.0-W1-001' : '0.9.9-W9-999');
      }
      expect(recorder.ofEvent(GraphLogEvent.adjacencyUnavailable), isEmpty);
      final bad = LogRecorder();
      unavailableQuery(bad).query('0.1.0-W1-001');
      expect(bad.ofEvent(GraphLogEvent.adjacencyUnavailable), hasLength(1));
    });
  });
}
