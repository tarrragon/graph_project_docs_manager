import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event_builder.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';

import '../../helpers/spec006/real_type_table.dart';
import '../../helpers/spec006/type_table_builder.dart';

void main() {
  group(
    'buildParseFailureEvent (SPEC-006-test-design §3.2 C5, FR-04/FR-06/D6/D7)',
    () {
      test(
        'C5-1 docs/domain-map.md 無 frontmatter：發事件，DomainBundle 單一候選',
        () {
          final table = readRealTypeTable();

          final event = buildParseFailureEvent(
            path: 'docs/domain-map.md',
            outcome: ParseOutcome.noFrontmatter(),
            lookup: const CarrierPathSingleMatch('DomainBundle'),
            table: table,
          );

          expect(event.nodeType, 'DomainBundle');
          expect(event.candidateTypes, ['DomainBundle']);
          expect(event.schemaAmbiguous, isFalse);
          expect(event.reason, contains('無 frontmatter'));
        },
      );

      test('C5-3 平手路徑的失敗檔：發事件，nodeType null，列全部候選', () {
        final tiedTable = TypeTableBuilder()
            .addType(
              'Alpha',
              carrierPathPatterns: [
                const PathPatternSpec(
                  pattern: r'^docs/tied\.md$',
                  specificity: [2, 0],
                ),
              ],
            )
            .addType(
              'Beta',
              carrierPathPatterns: [
                const PathPatternSpec(
                  pattern: r'^docs/tied\.md$',
                  specificity: [2, 0],
                ),
              ],
            )
            .build();

        final event = buildParseFailureEvent(
          path: 'docs/tied.md',
          outcome: ParseOutcome.noFrontmatter(),
          lookup: CarrierPathTie(['Alpha', 'Beta']),
          table: tiedTable,
        );

        expect(event.nodeType, isNull);
        expect(event.candidateTypes, unorderedEquals(['Alpha', 'Beta']));
        expect(event.schemaAmbiguous, isTrue);
        expect(event.lostFields, isEmpty);
      });

      test('C5-4 carrier 內 YAML 語法錯誤：發事件（D6：YAML 錯誤也走 carrier 分流）', () {
        final table = readRealTypeTable();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.yamlSyntaxError(lineNumber: 5),
          lookup: const CarrierPathSingleMatch('DomainBundle'),
          table: table,
        );

        expect(event.nodeType, 'DomainBundle');
        expect(event.line, 5);
        expect(event.reason, contains('YAML 語法錯誤'));
      });

      test('C5-5 carrier 內五種失敗原因各一：各發一筆，reason 對應值域', () {
        final table = readRealTypeTable();
        const path = 'docs/domain-map.md';
        const lookup = CarrierPathSingleMatch('DomainBundle');

        final outcomes = <ParseOutcome>[
          ParseOutcome.noFrontmatter(),
          ParseOutcome.unclosed(),
          ParseOutcome.emptyOrNotMap(),
          ParseOutcome.yamlSyntaxError(lineNumber: 2),
          ParseOutcome.unreadable(UnreadableReason.encoding),
        ];

        final events = [
          for (final outcome in outcomes)
            buildParseFailureEvent(
              path: path,
              outcome: outcome,
              lookup: lookup,
              table: table,
            ),
        ];

        final reasons = events.map((e) => e.reason).toList();
        expect(reasons[0], contains('無 frontmatter'));
        expect(reasons[1], contains('未閉合'));
        expect(reasons[2], contains('空或非 map'));
        expect(reasons[3], contains('YAML 語法錯誤'));
        expect(reasons[4], contains('無法讀取'));
      });

      test(
        'C5-8（守衛）lookup 為 CarrierPathNoMatch：拋出契約違反例外，'
        '證明呼叫端未篩除未命中檔案時不會靜默產生錯誤事件',
        () {
          final table = readRealTypeTable();

          expect(
            () => buildParseFailureEvent(
              path: 'docs/domain-map.md',
              outcome: ParseOutcome.noFrontmatter(),
              lookup: const CarrierPathNoMatch(),
              table: table,
            ),
            throwsStateError,
          );
        },
      );
    },
  );

  group(
    '固定欄位 (SPEC-006-test-design §3.2 C7, FR-04)',
    () {
      test('C7-1 C5-5 的五筆事件：salvagedFields 皆為 []，severity 皆為 edgeAffecting', () {
        final table = readRealTypeTable();
        const path = 'docs/domain-map.md';
        const lookup = CarrierPathSingleMatch('DomainBundle');

        final outcomes = <ParseOutcome>[
          ParseOutcome.noFrontmatter(),
          ParseOutcome.unclosed(),
          ParseOutcome.emptyOrNotMap(),
          ParseOutcome.yamlSyntaxError(lineNumber: 2),
          ParseOutcome.unreadable(UnreadableReason.encoding),
        ];

        for (final outcome in outcomes) {
          final event = buildParseFailureEvent(
            path: path,
            outcome: outcome,
            lookup: lookup,
            table: table,
          );

          expect(event.salvagedFields, isEmpty);
          expect(event.severity, ParseFailureSeverity.edgeAffecting);
        }
      });

      test('C7-2 YAML 語法錯誤：salvagedFields 仍為 []（不救回）', () {
        final table = readRealTypeTable();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.yamlSyntaxError(lineNumber: 4),
          lookup: const CarrierPathSingleMatch('DomainBundle'),
          table: table,
        );

        expect(event.salvagedFields, isEmpty);
      });
    },
  );
}
