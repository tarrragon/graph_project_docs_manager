/// 版本比較（規則 7；SPEC-006-test-design.md S5-7）。
///
/// 單一實作放 L0（Schema domain），供 `schema_source_resolver.dart`（同層）
/// 與 `lib/screens/domain_view/domain_view_schema_version.dart`（L4 畫面
/// 狀態層）共用；L4 經 import 取用，方向符合 `docs/domain-map.md` §2
/// （高層可依賴低層，反之不行）。
library;

/// [version] 是否高於 [builtinVersion]（逐段整數比較，段數不足補零；
/// S5-7：`2.40.3` 對 `2.40.10` 判為低於，數值逐段比較非字串比較）。
///
/// 任一段無法解析為整數時視為高於（安全預設拒絕降級出口，呼應
/// SPEC-001 §1「無可消費的型別表」顯式關卡精神：不確定時不自動降級）。
///
/// 版本缺席（呼叫端拿不到 [version] 或 [builtinVersion] 字串）不在本函式
/// 職責內——本函式要求兩個非 null 字串參數；呼叫端（如
/// `schema_source_resolver.dart` 的 `resolveSchemaSource`）在任一版本
/// 缺席時，應直接判定路徑模式查詢不可用，不呼叫本函式比較。
/// [version] 是否在 App 已知範圍內（不高於 [builtinVersion]），供 schema
/// 不相容關卡（`gate_detection_notifier.dart`）與型別表來源 resolver
/// （`schema_source_resolver.dart`）共用（`0.3.0-W3-543`）。
///
/// [version] 為 `null`、任一段無法解析為整數、或高於 [builtinVersion]
/// 時回傳 `false`（不在範圍）；等於或低於時回傳 `true`。由
/// [classifySchemaVersion] 推導（`InKnownRange` 才回傳 `true`），使
/// 「不在範圍」與「無法判讀」共用同一個分類來源，不可能分歧
/// （`0.3.0-W3-545`；SPEC-001 v1.23 §1 schema 不相容列）。
bool isWithinKnownSchemaRange(String? version, String builtinVersion) =>
    classifySchemaVersion(version, builtinVersion) is InKnownRange;

/// 型別表版本分類結果（`0.3.0-W3-545`；SPEC-001 v1.23 §1）。
///
/// 區分「版本太新」（[HigherThanBuiltin]）與「版本無法判讀」（[Unreadable]）
/// 兩種不在已知範圍的原因，供 schema 不相容畫面選用不同文案
/// （`schemaVersionUnreadableMessage` vs 一般版本不符說明）。
sealed class SchemaVersionClass {
  const SchemaVersionClass();
}

/// 版本在 App 已知範圍內（不高於 builtin，含相等與較低）。
final class InKnownRange extends SchemaVersionClass {
  const InKnownRange();
}

/// 版本高於 builtin，但可正常解析。
final class HigherThanBuiltin extends SchemaVersionClass {
  const HigherThanBuiltin();
}

/// 版本無法判讀：[version] 為 `null`，或任一段無法解析為整數。
final class Unreadable extends SchemaVersionClass {
  const Unreadable();
}

/// 對 [version] 相對 [builtinVersion] 分類（規則 7 逐段整數比較）。
///
/// [version] 為 `null` 或任一段無法解析為整數時回傳 [Unreadable]；
/// 高於 [builtinVersion] 時回傳 [HigherThanBuiltin]；否則（等於或低於）
/// 回傳 [InKnownRange]。
SchemaVersionClass classifySchemaVersion(String? version, String builtinVersion) {
  if (version == null) return const Unreadable();

  final target = version.split('.').map(int.tryParse).toList();
  final builtin = builtinVersion.split('.').map(int.tryParse).toList();
  final length = target.length > builtin.length
      ? target.length
      : builtin.length;
  for (var i = 0; i < length; i++) {
    final t = i < target.length ? target[i] : 0;
    final b = i < builtin.length ? builtin[i] : 0;
    if (t == null || b == null) return const Unreadable();
    if (t != b) {
      return t > b ? const HigherThanBuiltin() : const InKnownRange();
    }
  }
  return const InKnownRange();
}

bool isHigherThanBuiltinSchemaVersion(String version, String builtinVersion) {
  final target = version.split('.').map(int.tryParse).toList();
  final builtin = builtinVersion.split('.').map(int.tryParse).toList();
  final length = target.length > builtin.length
      ? target.length
      : builtin.length;
  for (var i = 0; i < length; i++) {
    final t = i < target.length ? target[i] : 0;
    final b = i < builtin.length ? builtin[i] : 0;
    if (t == null || b == null) return true;
    if (t != b) return t > b;
  }
  return false;
}
