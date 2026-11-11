/// 需求：[SPEC-009 v1.4 FR-09] 逐欄位輸入元件對照與可否清空判定。
///
/// 畫面狀態層純函式，不經元件。App 不內建值域表與必填清單：
/// 列舉值域與必填集合都經 [FieldDomainSource] 讀取（CLAUDE.md §7）。
library;

/// 欄位的輸入元件。
enum FieldInputElement {
  singleLine,
  multiLine,
  dropdown,
  radioGroup,
  searchableDropdown,
  notEditable,
}

/// 送出被擋下的提示類別（SPEC-004 4.48）。
enum FieldInputError { fieldRequiredEmpty }

/// 值域來源：讀自 `tracking_schema.json` 的機器定義。
abstract interface class FieldDomainSource {
  /// 該欄位是否有機器定義的列舉值域。
  bool hasMachineDefinedEnum(String nodeType, String field);

  /// 該節點型別的完整性（必填）欄位集合，即 `completeness_fields`。
  Set<String> completenessFields(String nodeType);
}

/// 送出判定結果。
sealed class FieldSubmitDecision {
  const FieldSubmitDecision();
}

/// 發出寫入；[value] 為 `null` 代表清空（寫 YAML null）。
final class FieldSubmitWrite extends FieldSubmitDecision {
  const FieldSubmitWrite(this.value);
  final String? value;
}

/// 不發出寫入，提示格顯示 [error]，草稿保留。
final class FieldSubmitBlocked extends FieldSubmitDecision {
  const FieldSubmitBlocked(this.error);
  final FieldInputError error;
}

/// 欄位在 1.0 不可編輯。
final class FieldSubmitNotEditable extends FieldSubmitDecision {
  const FieldSubmitNotEditable();
}

/// 對照表一列。[enumTarget] 非空表示該欄是列舉：有機器定義才用該元件，
/// 否則退回單行文字（用戶裁定，上游 tarrragon/claude#99）。
class _Row {
  const _Row(this.element, {this.enumTarget});
  final FieldInputElement element;
  final FieldInputElement? enumTarget;
}

const _single = _Row(FieldInputElement.singleLine);
const _multi = _Row(FieldInputElement.multiLine);
const _search = _Row(FieldInputElement.searchableDropdown);
const _enumDropdown = _Row(
  FieldInputElement.singleLine,
  enumTarget: FieldInputElement.dropdown,
);
const _enumRadio = _Row(
  FieldInputElement.singleLine,
  enumTarget: FieldInputElement.radioGroup,
);

const _docNodes = ['PROP', 'SPEC', 'UC', 'EVT'];

/// 自 1.0 起可編輯的欄位（SPEC-009 FR-09 兩張表「自」為 1.0 的列）。
final Map<String, _Row> _editableInOneZero = {
  for (final n in ['PROP', 'SPEC', 'UC']) '$n.title': _single,
  for (final n in _docNodes) '$n.status': _enumDropdown,
  'PROP.source': _enumDropdown,
  'PROP.priority': _enumDropdown,
  'PROP.evaluation_level': _enumDropdown,
  'PROP.target_version': _search,
  'PROP.proposed_by': _single,
  'SPEC.domain': _search,
  'SPEC.subdomain': _single,
  'SPEC.owner': _single,
  'SPEC.has_functional_requirements': _enumRadio,
  'UC.primary_actor': _single,
  'UC.platform': _enumRadio,
  'UC.extension_status': _enumRadio,
  'UC.runtime_surface': _enumRadio,
  'EVT.name': _single,
  'EVT.canonical_name': _single,
  'EVT.category': _enumRadio,
  'EVT.payload': _multi,
};

/// 1.0 可編輯欄位的鍵（`節點型別.欄位`）。
List<String> editableInOneZeroFields() => _editableInOneZero.keys.toList();

/// 以（節點型別、欄位）查現行輸入元件；1.0 不可編輯回傳 notEditable。
FieldInputElement inputElementFor(
  String nodeType,
  String field,
  FieldDomainSource source,
) {
  final row = _editableInOneZero['$nodeType.$field'];
  if (row == null) return FieldInputElement.notEditable;
  final target = row.enumTarget;
  if (target != null && source.hasMachineDefinedEnum(nodeType, field)) {
    return target;
  }
  return row.element;
}

bool _isTextElement(FieldInputElement e) =>
    e == FieldInputElement.singleLine || e == FieldInputElement.multiLine;

/// 判定送出內容（FR-09〈可否清空〉）。
///
/// 單行、多行草稿 trim 後為空：必填欄位擋下，其餘寫 `null`；
/// 非空值逐字寫入不修剪。其他元件無清空途徑，原樣寫入。
FieldSubmitDecision decideSubmit(
  String nodeType,
  String field,
  String draft,
  FieldDomainSource source,
) {
  final element = inputElementFor(nodeType, field, source);
  if (element == FieldInputElement.notEditable) {
    return const FieldSubmitNotEditable();
  }
  if (!_isTextElement(element) || draft.trim().isNotEmpty) {
    return FieldSubmitWrite(draft);
  }
  final required = source.completenessFields(nodeType).contains(field);
  if (required) {
    return const FieldSubmitBlocked(FieldInputError.fieldRequiredEmpty);
  }
  return const FieldSubmitWrite(null);
}
