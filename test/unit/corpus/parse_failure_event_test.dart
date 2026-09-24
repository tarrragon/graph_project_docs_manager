import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';

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
            table: table,
          );

          expect(event, isNotNull);
          expect(event!.nodeType, 'DomainBundle');
          expect(event.candidateTypes, ['DomainBundle']);
          expect(event.schemaAmbiguous, isFalse);
          expect(event.reason, contains('無 frontmatter'));
        },
      );

      test(
        'C5-2（守衛，C5-1 為正向對照）docs/work-logs/v0/note.md YAML 錯誤：不發事件',
        () {
          final table = readRealTypeTable();

          final event = buildParseFailureEvent(
            path: 'docs/work-logs/v0/note.md',
            outcome: ParseOutcome.yamlSyntaxError(lineNumber: 3),
            table: table,
          );

          expect(event, isNull);
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
          table: tiedTable,
        );

        expect(event, isNotNull);
        expect(event!.nodeType, isNull);
        expect(event.candidateTypes, unorderedEquals(['Alpha', 'Beta']));
        expect(event.schemaAmbiguous, isTrue);
        expect(event.lostFields, isEmpty);
      });

      test('C5-4 carrier 內 YAML 語法錯誤：發事件（D6：YAML 錯誤也走 carrier 分流）', () {
        final table = readRealTypeTable();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.yamlSyntaxError(lineNumber: 5),
          table: table,
        );

        expect(event, isNotNull);
        expect(event!.nodeType, 'DomainBundle');
        expect(event.line, 5);
        expect(event.reason, contains('YAML 語法錯誤'));
      });

      test('C5-5 carrier 內五種失敗原因各一：各發一筆，reason 對應值域', () {
        final table = readRealTypeTable();
        const path = 'docs/domain-map.md';

        final outcomes = <ParseOutcome>[
          ParseOutcome.noFrontmatter(),
          ParseOutcome.unclosed(),
          ParseOutcome.emptyOrNotMap(),
          ParseOutcome.yamlSyntaxError(lineNumber: 2),
          ParseOutcome.unreadable(UnreadableReason.encoding),
        ];

        final events = [
          for (final outcome in outcomes)
            buildParseFailureEvent(path: path, outcome: outcome, table: table),
        ];

        expect(events, everyElement(isNotNull));
        final reasons = events.map((e) => e!.reason).toList();
        expect(reasons[0], contains('無 frontmatter'));
        expect(reasons[1], contains('未閉合'));
        expect(reasons[2], contains('空或非 map'));
        expect(reasons[3], contains('YAML 語法錯誤'));
        expect(reasons[4], contains('無法讀取'));
      });

      test('C5-6 查詢不可用（S5-4 的型別表）：不發事件', () {
        // 型別表中沒有任何型別帶 carrier_path_patterns 欄位，代表專案 JSON
        // 與內建表都取不到路徑模式（FR-06 規則 7 下界情形）。
        final unavailableTable = TypeTableBuilder()
            .addType('SPEC', idPattern: r'^SPEC-\d{3}$')
            .build();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.noFrontmatter(),
          table: unavailableTable,
        );

        expect(event, isNull);
      });

      test('C5-7 可用檔：不發事件（事件只對失敗檔）', () {
        final table = readRealTypeTable();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.available(const {'id': 'DOMAIN-MAP-docs-graph'}),
          table: table,
        );

        expect(event, isNull);
      });
    },
  );

  group(
    '固定欄位 (SPEC-006-test-design §3.2 C7, FR-04)',
    () {
      test('C7-1 C5-5 的五筆事件：salvagedFields 皆為 []，severity 皆為 edgeAffecting', () {
        final table = readRealTypeTable();
        const path = 'docs/domain-map.md';

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
            table: table,
          );

          expect(event, isNotNull);
          expect(event!.salvagedFields, isEmpty);
          expect(event.severity, ParseFailureSeverity.edgeAffecting);
        }
      });

      test('C7-2 YAML 語法錯誤：salvagedFields 仍為 []（不救回）', () {
        final table = readRealTypeTable();

        final event = buildParseFailureEvent(
          path: 'docs/domain-map.md',
          outcome: ParseOutcome.yamlSyntaxError(lineNumber: 4),
          table: table,
        );

        expect(event, isNotNull);
        expect(event!.salvagedFields, isEmpty);
      });
    },
  );
}
