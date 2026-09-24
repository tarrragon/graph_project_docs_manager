import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_detector.dart';
import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';

ParseFailureEvent _singleMatchEvent({required String path, required String type}) =>
    ParseFailureEvent(
      path: path,
      reason: 'YAML 語法錯誤',
      nodeType: type,
      candidateTypes: [type],
      schemaAmbiguous: false,
      salvagedFields: const [],
      lostFields: const ['title'],
      severity: ParseFailureSeverity.edgeAffecting,
    );

ParseFailureEvent _tieEvent({required String path, required List<String> types}) =>
    ParseFailureEvent(
      path: path,
      reason: '無 frontmatter',
      candidateTypes: types,
      schemaAmbiguous: true,
      salvagedFields: const [],
      lostFields: const [],
      severity: ParseFailureSeverity.edgeAffecting,
    );

void main() {
  group('detectParseFailureGaps 一事件一破洞（SPEC-006-test-design §3.3 D1，FR-08）', () {
    test('D1-1 三筆事件（一型、一型、平手）→ 三筆破洞，逐欄位與事件一致', () {
      final events = [
        _singleMatchEvent(path: 'docs/proposals/PROP-001.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/spec/corpus/SPEC-006.md', type: 'SpecNode'),
        _tieEvent(
          path: 'docs/events/corpus/EVT-CORPUS-003.md',
          types: ['EventNode', 'SpecNode'],
        ),
      ];

      final result = detectParseFailureGaps(
        events: events,
        carrierPathQueryAvailable: true,
      );

      expect(result.undetermined, isNull);
      expect(result.gaps, hasLength(3));

      for (var i = 0; i < events.length; i++) {
        final event = events[i];
        final gap = result.gaps[i];
        expect(gap.path, event.path);
        expect(gap.reason, event.reason);
        expect(gap.nodeType, event.nodeType);
        expect(gap.candidateTypes, event.candidateTypes);
        expect(gap.schemaAmbiguous, event.schemaAmbiguous);
      }

      // 平手者帶候選型別與歧義標記。
      final tieGap = result.gaps[2];
      expect(tieGap.nodeType, isNull);
      expect(tieGap.candidateTypes, ['EventNode', 'SpecNode']);
      expect(tieGap.schemaAmbiguous, isTrue);
    });

    test('D1-2 零筆事件 → 零筆破洞，非「無法判定」', () {
      final result = detectParseFailureGaps(
        events: const [],
        carrierPathQueryAvailable: true,
      );

      expect(result.gaps, isEmpty);
      expect(result.undetermined, isNull);
    });

    test('D1-3 破洞數等於輸入事件數，等於以同一構造獨立計數的命中 carrier 數', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _tieEvent(path: 'docs/c.md', types: ['Proposal', 'SpecNode']),
      ];

      // 以同一構造（events 清單）獨立計數，模擬掃描摘要「命中 carrier 數」
      // 應與破洞數相等（FR-07 守恆式：命中 carrier 數 = 破洞數）。
      final independentlyCountedCarrierHits = events.length;

      final result = detectParseFailureGaps(
        events: events,
        carrierPathQueryAvailable: true,
      );

      expect(result.gaps, hasLength(events.length));
      expect(result.gaps, hasLength(independentlyCountedCarrierHits));
    });

    test('D1-4 破洞類別：本版只產生 parseFailure，不產生其餘三類', () {
      final result = detectParseFailureGaps(
        events: [_singleMatchEvent(path: 'docs/a.md', type: 'Proposal')],
        carrierPathQueryAvailable: true,
      );

      for (final gap in result.gaps) {
        expect(gap.category, GapCategory.parseFailure);
      }
      expect(
        GapCategory.values,
        containsAll([
          GapCategory.parseFailure,
          GapCategory.graphDefect,
          GapCategory.traceGap,
          GapCategory.unlocatable,
        ]),
      );
    });
  });

  group('detectParseFailureGaps 查詢不可用（SPEC-006-test-design §3.3 D2，FR-08）', () {
    test('D2-1（守衛）查詢不可用、未判定數 3 → 零筆 parseFailure，回報無法判定並帶原因', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
      ];

      final result = detectParseFailureGaps(
        events: events,
        carrierPathQueryAvailable: false,
        undeterminedCount: 3,
      );

      expect(result.gaps, isEmpty);
      expect(result.undetermined, isNotNull);
      expect(result.undetermined!.undeterminedCount, 3);
      expect(result.undetermined!.reason, isNotEmpty);
    });

    test('D2-2（正向對照）同一輸入但查詢可用、命中 3 → 三筆破洞，不回報無法判定', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
      ];

      final result = detectParseFailureGaps(
        events: events,
        carrierPathQueryAvailable: true,
      );

      expect(result.gaps, hasLength(3));
      expect(result.undetermined, isNull);
    });
  });
}
