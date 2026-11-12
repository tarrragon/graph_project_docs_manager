// 需求：1.0.0-W3-553.15.1；SPEC-009 v1.4 FR-09〈值域來源〉。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/screens/edit/field_input_mapping.dart';
import 'package:graph_project_docs_manager/screens/edit/type_table_field_domain_source.dart';

final _table = TypeTable({
  'SPEC': NodeTypeEntry(
    name: 'SPEC',
    completenessFields: const {'title', 'status'},
  ),
  'UC': NodeTypeEntry(name: 'UC', completenessFields: const {'title'}),
});

void main() {
  group('completenessFields', () {
    test('讀 TypeTable.nodeTypes[type].completenessFields', () {
      final source = TypeTableFieldDomainSource(_table);
      expect(source.completenessFields('SPEC'), {'title', 'status'});
      expect(source.completenessFields('UC'), {'title'});
    });

    test('未知型別回空集合', () {
      expect(
        TypeTableFieldDomainSource(_table).completenessFields('NOPE'),
        isEmpty,
      );
    });

    test('無型別表時回空集合', () {
      expect(
        const TypeTableFieldDomainSource.empty().completenessFields('SPEC'),
        isEmpty,
      );
    });
  });

  group('hasMachineDefinedEnum', () {
    // SPEC-009 FR-09 過渡期：上游 tarrragon/claude#99 補值域前恆回 false。
    test('FR-09 過渡期 #99：恆回 false，含 completeness 內的欄位', () {
      final source = TypeTableFieldDomainSource(_table);
      expect(source.hasMachineDefinedEnum('SPEC', 'status'), isFalse);
      expect(source.hasMachineDefinedEnum('SPEC', 'title'), isFalse);
      expect(source.hasMachineDefinedEnum('NOPE', 'x'), isFalse);
    });

    test('列舉欄位因此退回單行文字（鑑別：決策函式吃真實來源）', () {
      final source = TypeTableFieldDomainSource(_table);
      expect(
        inputElementFor('SPEC', 'status', source),
        FieldInputElement.singleLine,
      );
    });
  });

  test('必填集合經決策函式生效（正向對照：必填空白被擋、非必填寫 null）', () {
    final source = TypeTableFieldDomainSource(_table);
    expect(
      decideSubmit('SPEC', 'title', ' ', source),
      isA<FieldSubmitBlocked>(),
    );
    expect(decideSubmit('SPEC', 'owner', ' ', source), isA<FieldSubmitWrite>());
  });
}
