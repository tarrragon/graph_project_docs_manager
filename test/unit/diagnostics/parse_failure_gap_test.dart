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
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      final gaps = (result as GapsDetected).gaps;
      expect(gaps, hasLength(3));

      for (var i = 0; i < events.length; i++) {
        final event = events[i];
        final gap = gaps[i];
        expect(gap.path, event.path);
        expect(gap.reason, event.reason);
        expect(gap.nodeType, event.nodeType);
        expect(gap.candidateTypes, event.candidateTypes);
        expect(gap.schemaAmbiguous, event.schemaAmbiguous);
      }

      // 平手者帶候選型別與歧義標記。
      final tieGap = gaps[2];
      expect(tieGap.nodeType, isNull);
      expect(tieGap.candidateTypes, ['EventNode', 'SpecNode']);
      expect(tieGap.schemaAmbiguous, isTrue);
    });

    test('D1-2 零筆事件 → 零筆破洞，非「無法判定」', () {
      final result = detectParseFailureGaps(
        events: const [],
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      expect((result as GapsDetected).gaps, isEmpty);
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
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      final gaps = (result as GapsDetected).gaps;
      expect(gaps, hasLength(events.length));
      expect(gaps, hasLength(independentlyCountedCarrierHits));
    });

    test('D1-4 破洞類別：本版只產生 parseFailure，不產生其餘三類', () {
      final result = detectParseFailureGaps(
        events: [_singleMatchEvent(path: 'docs/a.md', type: 'Proposal')],
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      for (final gap in (result as GapsDetected).gaps) {
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
    test(
      'D2-1a（守衛）查詢不可用、原因碼=沒有路徑模式 → 零筆 parseFailure，回報無法判定並帶原因碼',
      () {
        final events = [
          _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
          _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
          _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
        ];

        final result = detectParseFailureGaps(
          events: events,
          undeterminedCount: 3,
          unavailableReason: UndeterminedGapReason.noPathPattern,
        );

        expect(result, isA<Undetermined>());
        final undetermined = result as Undetermined;
        expect(undetermined.undeterminedCount, 3);
        expect(undetermined.reason, UndeterminedGapReason.noPathPattern);
      },
    );

    test(
      'D2-1b（守衛）查詢不可用、原因碼=專案版本高於內建 → 回報無法判定並帶對應原因碼',
      () {
        final result = detectParseFailureGaps(
          events: const [],
          undeterminedCount: 5,
          unavailableReason: UndeterminedGapReason.projectVersionHigherThanBuiltin,
        );

        expect(result, isA<Undetermined>());
        final undetermined = result as Undetermined;
        expect(undetermined.undeterminedCount, 5);
        expect(
          undetermined.reason,
          UndeterminedGapReason.projectVersionHigherThanBuiltin,
        );
      },
    );

    test('D2-2（正向對照）同一輸入但查詢可用、命中 3 → 三筆破洞，不回報無法判定', () {
      final events = [
        _singleMatchEvent(path: 'docs/a.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/b.md', type: 'Proposal'),
        _singleMatchEvent(path: 'docs/c.md', type: 'Proposal'),
      ];

      final result = detectParseFailureGaps(
        events: events,
        undeterminedCount: 0,
        unavailableReason: null,
      );

      expect(result, isA<GapsDetected>());
      expect((result as GapsDetected).gaps, hasLength(3));
    });
  });
}
