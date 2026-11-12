/// 需求：[SPEC-009 v1.4 FR-09] 值域來源介面。
library;

/// 值域來源：讀自 `tracking_schema.json` 的機器定義。
abstract interface class FieldDomainSource {
  /// 該欄位是否有機器定義的列舉值域。
  bool hasMachineDefinedEnum(String nodeType, String field);

  /// 該節點型別的完整性（必填）欄位集合，即 `completeness_fields`。
  Set<String> completenessFields(String nodeType);
}
