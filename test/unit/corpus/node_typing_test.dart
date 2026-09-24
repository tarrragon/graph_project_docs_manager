import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/node_typer.dart';

import '../../helpers/spec006/real_type_table.dart';
import '../../helpers/spec006/type_table_builder.dart';

void main() {
  group('classifyNodeType (SPEC-006-test-design §3.2 C4, FR-03)', () {
    // C4-1、C4-2 保留使用真實型別表：兩者驗證的是真實
    // tracking_schema.json 的 id_pattern 資料實際能判出正確型別（SPEC、
    // DomainBundle），屬真實 schema 相容性案例，非規則性邏輯；
    // tracking_schema_contract_test.dart 的 K2 群組只涵蓋 carrier 路徑
    // 查詢（lookupCarrierPathType），不涵蓋 classifyNodeType 的 id_pattern
    // 判型，此處為此路徑僅存的真實 schema 覆蓋，故保留（0.3.0-W3-538）。
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
      // 規則性案例：`id` 鍵缺席時 classifyNodeType 在檢查任何 id_pattern
      // 前即短路回傳，型別表內容不影響結果，改用 TypeTableBuilder 隔離
      // fixture（0.3.0-W3-538）。
      final table = TypeTableBuilder()
          .addType('Alpha', idPattern: r'^A-\d+$')
          .build();

      final result = classifyNodeType(table, {'title': '無 id 的文件'});

      expect(result, isA<NodeTypingNonNode>());
      expect((result as NodeTypingNonNode).schemaAmbiguous, isFalse);
    });

    test('C4-4 id 不符合任何 id_pattern：同 C4-3', () {
      // 規則性案例：測的是「id 存在但零命中」這條規則本身，不依賴真實
      // schema 的具體 id_pattern 值，改用 TypeTableBuilder（0.3.0-W3-538）。
      final table = TypeTableBuilder()
          .addType('Alpha', idPattern: r'^A-\d+$')
          .build();

      final result = classifyNodeType(table, {'id': 'ZZZ-not-matching'});

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
      // 規則性案例：驗證的是 classifyNodeType 簽章本身不接受路徑參數這條
      // API 設計不變量，與真實 schema 的具體型別無關，改用
      // TypeTableBuilder（0.3.0-W3-538）。
      final table = TypeTableBuilder()
          .addType('Alpha', idPattern: r'^A-\d+$')
          .build();

      // classifyNodeType 的簽章本身不接受路徑參數：無論這份可用檔實際
      // 落在哪個 carrier 路徑下，判型結果只由 id 決定。
      final result = classifyNodeType(table, {'id': 'A-1'});

      expect(result, isA<NodeTypingMatch>());
      expect((result as NodeTypingMatch).typeName, 'Alpha');
    });
  });
}
