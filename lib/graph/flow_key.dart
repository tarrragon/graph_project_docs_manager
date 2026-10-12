/// 比對鍵正規化（SPEC-007 FR-10 S1，FR-11 沿用）。不依賴任何其他 graph 模組。
library;

/// 空值：null、空字串、空清單／空 Map（規格 FR-10 的「非空」；空集合視為空）。
bool isEmptyFlowRef(Object? value) =>
    value == null ||
    value == '' ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);

/// 步驟 `id` 與參照值的比對鍵：非空值一律轉成字串（FR-10 用戶裁決 S1，
/// 與上游 `doc validate` 的 `str()` 正規化一致）；空值回傳 null。
String? flowKeyOf(Object? value) => isEmptyFlowRef(value) ? null : '$value';
