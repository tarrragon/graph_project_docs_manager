// 1.0.0-W3-553.2.3.4.2：schema／graph／diagnostics／layout 的日誌改經 LogSink。
// 斷言事件碼、等級、error_source 與負載，不斷言文案（SPEC-010 FR-02、FR-04）。
// 每組皆含正向對照（不該記的輸入不產生事件）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/uc_flow_extractor.dart';
import 'package:graph_project_docs_manager/diagnostics/diagnostics_log_event.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/graph/graph_log_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/layout/layout_log_event.dart';
import 'package:graph_project_docs_manager/layout/swim_lane_layout.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/schema/schema_log_event.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../helpers/spec001/flow_builder.dart';
import '../../helpers/spec007/known_distribution_fixture.dart';
import '../../helpers/spec007/raw_node_builder.dart';

class _Rec<E extends Enum> {
  final entries =
      <
        ({
          E event,
          Map<String, Object> fields,
          LogLevel level,
          ErrorSource? source,
        })
      >[];

  void call(
    E event,
    LogFields fields, {
    LogLevel level = LogLevel.info,
    ErrorSource? source,
    Object? error,
  }) => entries.add((
    event: event,
    fields: fields.toJson(),
    level: level,
    source: source,
  ));
}

void main() {
  group('schema：拒收事件為 warning／parse', () {
    test('邊型條目非 map：edgeTypeRejected', () {
      final rec = _Rec<SchemaLogEvent>();
      typeTableFromJson({
        'edge_types': {'bad': 5},
      }, logSink: rec.call);
      expect(rec.entries.single.event, SchemaLogEvent.edgeTypeRejected);
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.parse);
    });

    test('id_pattern 無法編譯：idPatternRejected；合法 pattern 不記', () {
      final bad = _Rec<SchemaLogEvent>();
      typeTableFromJson({
        'node_types': {
          'X': {'id_pattern': '('},
        },
      }, logSink: bad.call);
      expect(bad.entries.single.event, SchemaLogEvent.idPatternRejected);
      expect(bad.entries.single.source, ErrorSource.parse);

      final good = _Rec<SchemaLogEvent>();
      typeTableFromJson({
        'node_types': {
          'X': {'id_pattern': r'^X-\d+$'},
        },
      }, logSink: good.call);
      expect(good.entries, isEmpty);
    });

    test('specificity 長度不對：specificityRejected', () {
      final rec = _Rec<SchemaLogEvent>();
      typeTableFromJson({
        'node_types': {
          'X': {
            'carrier_path_patterns': [
              {
                'pattern': 'docs/*.md',
                'specificity': [1],
              },
            ],
          },
        },
      }, logSink: rec.call);
      expect(rec.entries.single.event, SchemaLogEvent.specificityRejected);
    });

    test('carrier 模式無法編譯：carrierPatternRejected', () {
      final rec = _Rec<SchemaLogEvent>();
      typeTableFromJson({
        'node_types': {
          'X': {
            'carrier_path_patterns': [
              {
                'pattern': '(',
                'specificity': [1, 0],
              },
            ],
          },
        },
      }, logSink: rec.call);
      expect(rec.entries.single.event, SchemaLogEvent.carrierPatternRejected);
    });
  });

  group('graph：debug 事件', () {
    test('closed_by 非語料值：closedBySkipped（debug）；語料內值不記', () {
      final inputs = graphInputsFrom();
      List<LogLevel> run(String value, _Rec<GraphLogEvent> rec) {
        classifyGraphReferences(
          rawNodes: [
            buildRawNode(id: '0.1.0-W1-001', extra: {'closed_by': value}),
            buildRawNode(id: '0.6.0-W1-010'),
          ],
          edgeTypes: inputs.edgeTypes,
          nodeTypes: inputs.nodeTypes,
          logSink: rec.call,
        );
        return [for (final e in rec.entries) e.level];
      }

      final skipped = _Rec<GraphLogEvent>();
      expect(run('none', skipped), [LogLevel.debug]);
      expect(skipped.entries.single.event, GraphLogEvent.closedBySkipped);

      final control = _Rec<GraphLogEvent>();
      expect(run('0.6.0-W1-010', control), isEmpty);
    });
  });

  group('diagnostics：上游違約為 warning／internal', () {
    FlowParseFailedEvent flow(String reason) =>
        FlowParseFailedEvent(path: 'docs/usecases/UC-01.md', reason: reason);

    test('reason 未以原因碼開頭：記一筆；以原因碼開頭不記', () {
      final rec = _Rec<DiagnosticsLogEvent>();
      detectParseFailureGaps(
        events: const [],
        undeterminedCount: 0,
        unavailableReason: null,
        flowEvents: [flow('free text')],
        logSink: rec.call,
      );
      expect(
        rec.entries.single.event,
        DiagnosticsLogEvent.flowReasonPrefixViolation,
      );
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.internal);

      final control = _Rec<DiagnosticsLogEvent>();
      detectParseFailureGaps(
        events: const [],
        undeterminedCount: 0,
        unavailableReason: null,
        flowEvents: [flow(flowBlockMalformedReasonCode)],
        logSink: control.call,
      );
      expect(control.entries, isEmpty);
    });
  });

  group('layout：不變式違反為 warning／internal', () {
    test('解析名稱不在列序內：先記事件再 assert', () {
      final rec = _Rec<LayoutLogEvent>();
      final flow = buildFlow(
        [
          stepRow('S', traverses: ['ghost']),
        ],
        declaredDomains: ['ghost'],
      );
      expect(
        () => buildSwimLaneLayout(
          flow: flow,
          bundleOrder: orderOf(['graph']),
          logSink: rec.call,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(rec.entries.single.event, LayoutLogEvent.laneInvariantViolated);
      expect(rec.entries.single.level, LogLevel.warning);
      expect(rec.entries.single.source, ErrorSource.internal);
      expect(rec.entries.single.fields[LayoutLogKeys.missingCount], 1);
    });
  });
}
