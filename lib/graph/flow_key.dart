/// 比對鍵正規化（SPEC-007 FR-10 S1，FR-11 沿用）。不依賴任何其他 graph 模組。
library;

/// 空值：null、空字串、空清單／空 Map（規格 FR-10 的「非空」；空集合視為空）。
bool isEmptyFlowRef(Object? value) =>
    value == null ||
    value == '' ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);

/// 步驟 `id` 與參照值的比對鍵：非空值一律轉成字串（FR-10 用戶裁決 S1）；
/// 空值回傳 null。
///
/// 與上游 `doc validate` 的 `str()` 正規化一致，保證範圍限字串與整數
/// （FR-10 用戶裁決 K1）。bool（`true`／`True`）、清單、map 的轉字串結果
/// Dart 與 Python 不同，但 step id 與 domain 名受格式約束（kebab-case、
/// 小寫），這些值兩種轉法皆必然解析不到，解析結果與上游相同。
/// 本函式以 Dart 轉法為準，不模擬 Python repr。
String? flowKeyOf(Object? value) => isEmptyFlowRef(value) ? null : '$value';

/// 參照清單正規化（SPEC-007 FR-10 步驟屬性 `emits`／`consumes`）：純量視同
/// 單元素清單，空元素略過，非字串元素以 [flowKeyOf] 轉字串。各消費端共用本函式。
List<String> flowKeysOf(Object? raw) => List.unmodifiable([
  for (final e in raw is Iterable ? raw : [raw]) ?flowKeyOf(e),
]);
