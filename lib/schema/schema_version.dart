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
/// 時回傳 `false`（不在範圍）；等於或低於時回傳 `true`。取代兩處各自
/// 重複的「null 檢查加比較」，使兩者結構上不可能分歧。
bool isWithinKnownSchemaRange(String? version, String builtinVersion) =>
    version != null && !isHigherThanBuiltinSchemaVersion(version, builtinVersion);

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
