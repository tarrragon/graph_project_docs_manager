// SPEC-009 v1.4 FR-09：逐欄位輸入元件對照與可否清空判定（F-1～F-7）。
// 畫面狀態層純函式，不經元件。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/field_domain_source.dart';
import 'package:graph_project_docs_manager/screens/edit/field_input_mapping.dart';

/// 值域來源 fake：[enumFields] 為「節點型別.欄位」集合，[completeness] 為必填集合。
class _FakeSource implements FieldDomainSource {
  _FakeSource({this.enumFields = const {}, this.completeness = const {}});

  final Set<String> enumFields;
  final Map<String, Set<String>> completeness;

  @override
  bool hasMachineDefinedEnum(String nodeType, String field) =>
      enumFields.contains('$nodeType.$field');

  @override
  Set<String> completenessFields(String nodeType) =>
      completeness[nodeType] ?? const <String>{};
}

const _fullCompleteness = <String, Set<String>>{
  'PROP': {'id', 'status', 'title'},
  'SPEC': {'id', 'status', 'title'},
  'UC': {'id', 'status', 'title'},
  'EVT': {'canonical_name', 'category', 'id', 'name'},
  'DomainBundle': {'domain', 'id'},
};

// FR-09 表中 PROP status、has_functional_requirements、EVT category 的現行
// 元件是下拉／單選鈕組，代表這三欄在撰寫時已有機器定義的值域。
final _definedEnums = {
  'PROP.status',
  'SPEC.has_functional_requirements',
  'EVT.category',
};

const _e = FieldInputElement.singleLine;

void main() {
  group('F-1 自為 1.0 的每一列回傳現行元件', () {
    final source = _FakeSource(
      enumFields: _definedEnums,
      completeness: _fullCompleteness,
    );
    // (節點型別, 欄位, 現行元件)：逐列自 SPEC-009 v1.4 FR-09 兩張表抄錄。
    const rows = <(String, String, FieldInputElement)>[
      ('PROP', 'title', _e),
      ('SPEC', 'title', _e),
      ('UC', 'title', _e),
      ('PROP', 'status', FieldInputElement.dropdown),
      ('SPEC', 'status', _e),
      ('UC', 'status', _e),
      ('EVT', 'status', _e),
      ('PROP', 'source', _e),
      ('PROP', 'priority', _e),
      ('PROP', 'evaluation_level', _e),
      ('PROP', 'target_version', FieldInputElement.searchableDropdown),
      ('PROP', 'proposed_by', _e),
      ('SPEC', 'domain', FieldInputElement.searchableDropdown),
      ('SPEC', 'subdomain', _e),
      ('SPEC', 'owner', _e),
      ('SPEC', 'has_functional_requirements', FieldInputElement.radioGroup),
      ('UC', 'primary_actor', _e),
      ('UC', 'platform', _e),
      ('UC', 'extension_status', _e),
      ('UC', 'runtime_surface', _e),
      ('EVT', 'name', _e),
      ('EVT', 'canonical_name', _e),
      ('EVT', 'category', FieldInputElement.radioGroup),
      ('EVT', 'payload', FieldInputElement.multiLine),
    ];
    for (final (node, field, expected) in rows) {
      test('$node.$field -> ${expected.name}', () {
        expect(inputElementFor(node, field, source), expected);
      });
    }
    test('1.0 可編輯列數固定（表增減時本案紅燈）', () {
      expect(rows.length, 24);
      expect(editableInOneZeroFields().length, rows.length);
    });
    test('1.0 清單與本案列舉逐項相同', () {
      final listed = {for (final r in rows) '${r.$1}.${r.$2}'};
      expect(editableInOneZeroFields().toSet(), listed);
    });
  });

  group('F-2 無機器定義列舉以單行（守衛）', () {
    test('SPEC status 無機器定義 -> 單行', () {
      final source = _FakeSource();
      expect(inputElementFor('SPEC', 'status', source), _e);
    });
    test('正向對照：PROP status 有機器定義 -> 下拉', () {
      final source = _FakeSource(enumFields: {'PROP.status'});
      expect(
        inputElementFor('PROP', 'status', source),
        FieldInputElement.dropdown,
      );
    });
    test('正向對照：SPEC status 有機器定義時才為下拉', () {
      final source = _FakeSource(enumFields: {'SPEC.status'});
      expect(
        inputElementFor('SPEC', 'status', source),
        FieldInputElement.dropdown,
      );
    });
  });

  group('F-3 App 沒有內建值域表（守衛）', () {
    test('值域來源全部回傳無 -> 沒有下拉或單選鈕組', () {
      final source = _FakeSource();
      for (final key in editableInOneZeroFields()) {
        final parts = key.split('.');
        final element = inputElementFor(parts[0], parts[1], source);
        expect(element, isNot(FieldInputElement.dropdown), reason: key);
        expect(element, isNot(FieldInputElement.radioGroup), reason: key);
      }
    });
  });

  group('F-4 自 1.1 以後或 — 的欄位不可編輯', () {
    final source = _FakeSource(
      enumFields: _definedEnums,
      completeness: _fullCompleteness,
    );
    const rows = <(String, String)>[
      ('PROP', 'id'),
      ('PROP', 'created'),
      ('PROP', 'updated'),
      ('SPEC', 'version'),
      ('UC', 'version'),
      ('PROP', 'proposed_date'),
      ('PROP', 'confirmed_date'),
      ('PROP', 'outputs'),
      ('PROP', 'related_proposals'),
      ('PROP', 'supersedes'),
      ('SPEC', 'source_proposal'),
      ('SPEC', 'related_usecases'),
      ('SPEC', 'related_specs'),
      ('SPEC', 'implements_requirements'),
      ('SPEC', 'depends_on_domains'),
      ('UC', 'secondary_actors'),
      ('UC', 'related_specs'),
      ('UC', 'related_usecases'),
      ('UC', 'ticket_refs'),
      ('UC', 'flow'),
      ('DomainBundle', 'domain'),
      ('DomainBundle', 'source_specs'),
      ('DomainBundle', 'related_usecases'),
      ('DomainBundle', 'depends_on_bundles'),
      ('DomainBundle', 'path_patterns'),
      ('EVT', 'producers'),
      ('EVT', 'consumers'),
      ('PROP', 'body'),
    ];
    for (final (node, field) in rows) {
      test('$node.$field -> 不可編輯', () {
        expect(
          inputElementFor(node, field, source),
          FieldInputElement.notEditable,
        );
      });
    }
  });

  group('F-5 可清空欄位的空白草稿寫 null', () {
    final source = _FakeSource(completeness: _fullCompleteness);
    for (final (node, field) in [('PROP', 'proposed_by'), ('EVT', 'payload')]) {
      for (final draft in ['', '   ']) {
        test('$node.$field 草稿 "$draft" -> null', () {
          final d = decideSubmit(node, field, draft, source);
          expect(d, isA<FieldSubmitWrite>());
          expect((d as FieldSubmitWrite).value, isNull);
        });
      }
      test('$node.$field 草稿 "  x " 逐字寫入不修剪', () {
        final d = decideSubmit(node, field, '  x ', source);
        expect((d as FieldSubmitWrite).value, '  x ');
      });
    }
  });

  group('F-6 必填欄位空白擋下（守衛）', () {
    final source = _FakeSource(completeness: _fullCompleteness);
    for (final (node, field) in [('PROP', 'title'), ('EVT', 'name')]) {
      for (final draft in ['', ' \t ']) {
        test('$node.$field 草稿 "$draft" -> fieldRequiredEmpty', () {
          final d = decideSubmit(node, field, draft, source);
          expect(d, isA<FieldSubmitBlocked>());
          expect(
            (d as FieldSubmitBlocked).error,
            FieldInputError.fieldRequiredEmpty,
          );
        });
      }
    }
    test('SPEC/UC status、EVT canonical_name 同樣擋下', () {
      for (final (n, f) in [
        ('SPEC', 'status'),
        ('UC', 'status'),
        ('SPEC', 'title'),
        ('UC', 'title'),
        ('EVT', 'canonical_name'),
      ]) {
        expect(decideSubmit(n, f, '  ', source), isA<FieldSubmitBlocked>());
      }
    });
    test('必填欄位非空草稿照常寫入', () {
      final d = decideSubmit('PROP', 'title', 'T', source);
      expect((d as FieldSubmitWrite).value, 'T');
    });
    test('正向對照：可清空欄位同樣輸入時發出寫入', () {
      expect(
        decideSubmit('PROP', 'proposed_by', '', source),
        isA<FieldSubmitWrite>(),
      );
    });
  });

  group('F-7 必填集合讀自 completeness_fields（守衛）', () {
    test('PROP 只列 id、status -> title 空白改判寫 null', () {
      final source = _FakeSource(
        completeness: {
          'PROP': {'id', 'status'},
        },
      );
      final d = decideSubmit('PROP', 'title', '', source);
      expect(d, isA<FieldSubmitWrite>());
      expect((d as FieldSubmitWrite).value, isNull);
    });
    test('正向對照：列入 title 時擋下', () {
      final source = _FakeSource(completeness: _fullCompleteness);
      expect(
        decideSubmit('PROP', 'title', '', source),
        isA<FieldSubmitBlocked>(),
      );
    });
  });

  group('FR-09〈可否清空〉第三類：元件無清空途徑', () {
    test('下拉、單選鈕組、可搜尋下拉不經空白判定，原樣寫入', () {
      final source = _FakeSource(
        enumFields: _definedEnums,
        completeness: _fullCompleteness,
      );
      for (final (n, f) in [
        ('PROP', 'status'),
        ('SPEC', 'domain'),
        ('SPEC', 'has_functional_requirements'),
        ('EVT', 'category'),
      ]) {
        final d = decideSubmit(n, f, '', source);
        expect(d, isA<FieldSubmitWrite>(), reason: '$n.$f');
        expect((d as FieldSubmitWrite).value, '', reason: '$n.$f');
      }
    });
    test('不可編輯欄位不產生寫入', () {
      final source = _FakeSource(completeness: _fullCompleteness);
      expect(
        decideSubmit('PROP', 'created', 'x', source),
        isA<FieldSubmitNotEditable>(),
      );
    });
  });
}
