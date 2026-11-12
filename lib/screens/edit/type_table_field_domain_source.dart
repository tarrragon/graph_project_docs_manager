/// 需求：[SPEC-009 v1.4 FR-09] 讀型別表的值域來源正式實作。
library;

import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/screens/edit/field_input_mapping.dart';

/// 以 [TypeTable] 回答完整性欄位；值域一律視為無機器定義。
class TypeTableFieldDomainSource implements FieldDomainSource {
  const TypeTableFieldDomainSource(this._table);

  /// 尚無型別表（輪次未完成）時使用：必填集合為空，值域亦無。
  const TypeTableFieldDomainSource.empty() : _table = null;

  final TypeTable? _table;

  /// SPEC-009 FR-09〈值域來源〉過渡期用戶裁定：上游 tarrragon/claude#99
  /// 補上欄位值域前恆回 false，不建 App 內建值域表。
  @override
  bool hasMachineDefinedEnum(String nodeType, String field) => false;

  @override
  Set<String> completenessFields(String nodeType) =>
      _table?.nodeTypes[nodeType]?.completenessFields ?? const <String>{};
}
