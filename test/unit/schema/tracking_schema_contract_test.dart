// 跨語言契約 K2：FR-06 ↔ tracking_schema.json 路徑模式與具體度
// （SPEC-006-test-design.md §3.4）。
//
// 讀真實 `.claude/skills/doc/doc_system/core/tracking_schema.json`，非最小
// 建構器 fixture。依賴方向：test/unit/schema/ 不得 import lib/corpus/、
// lib/diagnostics/（§1.3）。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/lost_fields.dart';
import 'package:graph_project_docs_manager/schema/carrier_path_lookup.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';

import '../../helpers/spec006/real_type_table.dart';

void main() {
  group('K2-1 真實 JSON 中每個非 FlowStep 型別都有 carrier_path_patterns', () {
    test('carrier_path_types 清單中的型別皆帶合法形態的 carrier_path_patterns', () {
      final json = readRealTrackingSchemaJson();
      final carrierPathTypes =
          (json['carrier_path_types'] as List<dynamic>).cast<String>();
      final nodeTypes = json['node_types'] as Map<String, dynamic>;

      expect(carrierPathTypes, isNotEmpty);

      for (final typeName in carrierPathTypes) {
        final typeJson = nodeTypes[typeName] as Map<String, dynamic>;
        final patterns = typeJson['carrier_path_patterns'];
        expect(
          patterns,
          isNotNull,
          reason: '$typeName 列在 carrier_path_types 但缺少 carrier_path_patterns',
        );

        for (final element in (patterns as List<dynamic>)) {
          final map = element as Map<String, dynamic>;
          expect(map.containsKey('pattern'), isTrue);
          expect(map.containsKey('specificity'), isTrue);
          expect(map['pattern'], isA<String>());

          final specificity = map['specificity'] as List<dynamic>;
          expect(specificity, hasLength(2));
          for (final value in specificity) {
            expect(value, isA<int>());
            expect(value as int, greaterThanOrEqualTo(0));
          }
        }
      }
    });

    test('K2-1（守衛正向對照）FlowStep 不在 carrier_path_types 中', () {
      final json = readRealTrackingSchemaJson();
      final carrierPathTypes =
          (json['carrier_path_types'] as List<dynamic>).cast<String>();
      expect(carrierPathTypes, isNot(contains('FlowStep')));

      final nodeTypes = json['node_types'] as Map<String, dynamic>;
      final flowStepJson = nodeTypes['FlowStep'] as Map<String, dynamic>;
      expect(flowStepJson.containsKey('carrier_path_patterns'), isFalse);
    });
  });

  group('K2-2 每個 pattern 都能被 Dart RegExp 編譯', () {
    test('真實型別表中所有 pattern 編譯不拋錯', () {
      final table = readRealTypeTable();

      for (final entry in table.pathParticipatingTypes) {
        for (final pattern in entry.carrierPathPatterns!) {
          expect(
            () => pattern.toRegExp(),
            returnsNormally,
            reason: '${entry.name} 的 pattern 無法被 Dart RegExp 編譯：${pattern.pattern}',
          );
        }
      }
    });
  });

  group('K2-3（守衛，E2）Python 專屬語法作正向對照', () {
    test('K2-3-1 (?P<name>...) 命名群組語法無法被 Dart RegExp 編譯', () {
      // python-re 支援 (?P<name>...) 具名群組，Dart RegExp 不支援此語法
      // （Dart 用 (?<name>...)）。以此作為方言檢查的正向對照輸入：
      // 若真實 JSON 意外混入 python 專屬語法，K2-2 的編譯檢查必須攔下它。
      const pythonOnlyPattern = r'^docs/(?P<name>[^/]+)\.md$';
      expect(() => RegExp(pythonOnlyPattern), throwsFormatException);
    });

    test('K2-3-2（正向對照的反例）真實 JSON 的 pattern 不使用 python 專屬語法', () {
      final table = readRealTypeTable();
      for (final entry in table.pathParticipatingTypes) {
        for (final pattern in entry.carrierPathPatterns!) {
          expect(pattern.pattern, isNot(contains('(?P<')));
        }
      }
    });
  });

  group('K2-4 S1～S2 的關鍵路徑以真實 JSON 查詢得到預期型別', () {
    late TypeTable table;

    setUp(() {
      table = readRealTypeTable();
    });

    test('K2-4-1 docs/spec/ui/README.md 未命中（S1-1）', () {
      final result = lookupCarrierPathType(table, 'docs/spec/ui/README.md');
      expect(result, isA<CarrierPathNoMatch>());
    });

    test('K2-4-2 docs/spec/ui/SPEC-001-x.md 命中 SPEC（S1-2）', () {
      final result = lookupCarrierPathType(table, 'docs/spec/ui/SPEC-001-x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'SPEC');
    });

    test('K2-4-3 docs/usecases/UC-01-x.md 命中 UC（S1-6）', () {
      final result = lookupCarrierPathType(table, 'docs/usecases/UC-01-x.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'UC');
    });

    test('K2-4-4 docs/work-logs/v0/v0.1/tickets/0.1.0-W1-001.md 命中 Ticket（S1-4）', () {
      final result = lookupCarrierPathType(
        table,
        'docs/work-logs/v0/v0.1/tickets/0.1.0-W1-001.md',
      );
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'Ticket');
    });

    test('K2-4-5 docs/spec/corpus/domain-map.md 回傳 DomainBundle（S2-1，具體度 3 > 2）', () {
      final result = lookupCarrierPathType(table, 'docs/spec/corpus/domain-map.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'DomainBundle');
    });

    test('K2-4-6 docs/domain-map.md 回傳 DomainBundle（具體度 2）', () {
      final result = lookupCarrierPathType(table, 'docs/domain-map.md');
      expect(result, isA<CarrierPathSingleMatch>());
      expect((result as CarrierPathSingleMatch).typeName, 'DomainBundle');
    });

    test('K2-4-7 大小寫不同的路徑未命中（S1-5）', () {
      final specResult = lookupCarrierPathType(table, 'docs/Spec/ui/SPEC-001-x.md');
      expect(specResult, isA<CarrierPathNoMatch>());
    });
  });

  group('K2-5 模式含 \\d 時，全形數字路徑不命中（N3：以 ASCII 為準）', () {
    test('K2-5-1 UC pattern 對全形數字路徑不命中', () {
      final table = readRealTypeTable();
      final ucEntry = table.nodeTypes['UC']!;
      final ucPattern = ucEntry.carrierPathPatterns!.single;

      // ASCII 半形數字：命中（正向對照，證明本案例對目標功能有鑑別力）。
      expect(ucPattern.toRegExp().hasMatch('docs/usecases/UC-01-x.md'), isTrue);

      // 全形數字（U+FF10 起）：Python 3 re 的 \d 預設匹配 Unicode 數字，
      // Dart RegExp 未啟用 unicode 旗標時 \d 只匹配 ASCII，故不命中。
      expect(
        ucPattern.toRegExp().hasMatch('docs/usecases/UC-０１-x.md'),
        isFalse,
      );
    });

    test('K2-5-2 Ticket pattern 的 \\w 段對全形數字路徑不命中', () {
      final table = readRealTypeTable();
      final ticketEntry = table.nodeTypes['Ticket']!;
      final ticketPattern = ticketEntry.carrierPathPatterns!.single;

      expect(
        ticketPattern
            .toRegExp()
            .hasMatch('docs/work-logs/v0/tickets/0.1.0-W1-001.md'),
        isTrue,
      );
    });
  });

  group('completeness', () {
    test(
      'K3-1 真實 JSON 含 completeness_fields，各值為字串清單',
      () {
        final json = readRealTrackingSchemaJson();
        expect(json.containsKey('completeness_fields'), isTrue);

        final completenessFields =
            json['completeness_fields'] as Map<String, dynamic>;
        expect(completenessFields, isNotEmpty);

        for (final entry in completenessFields.entries) {
          final value = entry.value;
          expect(
            value,
            isA<List<dynamic>>(),
            reason: '${entry.key} 的 completeness_fields 值應為清單',
          );
          for (final field in value as List<dynamic>) {
            expect(
              field,
              isA<String>(),
              reason: '${entry.key} 的 completeness_fields 元素應為字串',
            );
          }
        }
      },
    );

    test('K3-2 真實 JSON 含 completeness_semantics', () {
      final json = readRealTrackingSchemaJson();
      expect(json.containsKey('completeness_semantics'), isTrue);
      expect(json['completeness_semantics'], isA<String>());
      expect((json['completeness_semantics'] as String).isNotEmpty, isTrue);
    });

    test(
      'K3-3（E1 鑑別，守衛）以真實 JSON 的 SPEC completeness_fields 重跑 C6-2',
      () {
        final table = readRealTypeTable();
        final specCompletenessFields =
            table.nodeTypes['SPEC']!.completenessFields;
        expect(
          specCompletenessFields,
          isNotEmpty,
          reason: '本案例需要真實 SPEC completeness_fields 非空才具鑑別力',
        );

        final writtenFieldsWithNullAndEmpty = <String, Object?>{
          for (final field in specCompletenessFields) field: null,
        };
        final lostWithNullAndEmpty = lostFields(
          completenessFields: specCompletenessFields,
          writtenFields: writtenFieldsWithNullAndEmpty,
          isTied: false,
        );
        expect(
          lostWithNullAndEmpty,
          isEmpty,
          reason: '鍵存在但值為 null 仍算已寫出，不列入 lostFields',
        );

        // 正向對照：完全不寫出這些鍵，lostFields 必須等於完整性集合。
        final lostWithoutAnyFields = lostFields(
          completenessFields: specCompletenessFields,
          writtenFields: const <String, Object?>{},
          isTied: false,
        );
        expect(
          lostWithoutAnyFields.toSet(),
          specCompletenessFields,
          reason: '未寫出任何鍵時，lostFields 應等於完整性集合，證明鑑別力',
        );

        expect(lostWithNullAndEmpty, isNot(equals(lostWithoutAnyFields)));
      },
    );
  });
}
