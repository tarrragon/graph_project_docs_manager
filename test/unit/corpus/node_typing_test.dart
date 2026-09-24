import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/node_typer.dart';

import '../../helpers/spec006/real_type_table.dart';
import '../../helpers/spec006/type_table_builder.dart';

void main() {
  group('classifyNodeType (SPEC-006-test-design §3.2 C4, FR-03)', () {
    test('C4-1 id: SPEC-001 判為節點，SPEC', () {
      final table = readRealTypeTable();

      final result = classifyNodeType(table, {'id': 'SPEC-001'});

      expect(result, isA<NodeTypingMatch>());
      expect((result as NodeTypingMatch).typeName, 'SPEC');
    });

    test('C4-2 id: DOMAIN-MAP-docs-graph 判為節點，DomainBundle', () {
      final table = readRealTypeTable();

      final result = classifyNodeType(table, {'id': 'DOMAIN-MAP-docs-graph'});

      expect(result, isA<NodeTypingMatch>());
      expect((result as NodeTypingMatch).typeName, 'DomainBundle');
    });

    test('C4-3 無 id 鍵：有 frontmatter 的非節點，無節點無破洞', () {
      final table = readRealTypeTable();

      final result = classifyNodeType(table, {'title': '無 id 的文件'});

      expect(result, isA<NodeTypingNonNode>());
      expect((result as NodeTypingNonNode).schemaAmbiguous, isFalse);
    });

    test('C4-4 id: v0.1.0-note（不符合任何 id_pattern）：同 C4-3', () {
      final table = readRealTypeTable();

      final result = classifyNodeType(table, {'id': 'v0.1.0-note'});

      expect(result, isA<NodeTypingNonNode>());
      expect((result as NodeTypingNonNode).schemaAmbiguous, isFalse);
    });

    test(
      'C4-5（守衛）測試型別表兩型 id_pattern 都命中 X-1：非節點，標記 schema 歧義',
      () {
        final ambiguousTable = TypeTableBuilder()
            .addType('Alpha', idPattern: r'^X-\d+$')
            .addType('Beta', idPattern: r'^X-\d+$')
            .build();

        final result = classifyNodeType(ambiguousTable, {'id': 'X-1'});

        expect(result, isA<NodeTypingNonNode>());
        expect((result as NodeTypingNonNode).schemaAmbiguous, isTrue);
        expect(result.candidateTypes, ['Alpha', 'Beta']);

        // 正向對照：只留一型時，同一個 id 應判為該型（證明歧義來自「兩型
        // 同時命中」，不是 id 本身有問題）。
        final singleTable = TypeTableBuilder()
            .addType('Alpha', idPattern: r'^X-\d+$')
            .build();

        final singleResult = classifyNodeType(singleTable, {'id': 'X-1'});

        expect(singleResult, isA<NodeTypingMatch>());
        expect((singleResult as NodeTypingMatch).typeName, 'Alpha');
      },
    );

    test('C4-6 依 id_pattern 判型，不依路徑（domain-map §7）', () {
      final table = readRealTypeTable();

      // classifyNodeType 的簽章本身不接受路徑參數：無論這份可用檔實際
      // 落在哪個 carrier 路徑下，判型結果只由 id 決定。
      final result = classifyNodeType(table, {'id': 'PROP-001'});

      expect(result, isA<NodeTypingMatch>());
      expect((result as NodeTypingMatch).typeName, 'PROP');
    });
  });
}
