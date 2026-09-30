// 跨語言契約 K3-3：completeness_fields 與 lostFields 的鑑別測試
// （SPEC-006-test-design.md §3.4）。
//
// 原位於 test/unit/schema/tracking_schema_contract_test.dart；因 schema 層
// 不得 import lib/corpus/（SPEC-007-test-design.md §1.3）而搬到此處。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/lost_fields.dart';

import '../../helpers/spec006/real_type_table.dart';

void main() {
  group('completeness', () {
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
