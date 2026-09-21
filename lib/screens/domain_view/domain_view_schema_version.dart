/// 內建型別表版本讀取與漂移偵測（`0.1.0-W2-012`）。
///
/// 版本值改由 [builtinSchemaVersionProvider] 於執行期讀取實際內嵌資產
/// （`assets/schema/builtin_schema_version.json`），取代先前寫死於
/// `domain_view_screen.dart` 的常數；該資產內容複製自
/// `.claude/skills/doc/doc_system/core/tracking_schema.json` 之
/// `schema_generated_at_framework_version` 欄，非隨意寫死
/// （SPEC-001 §1／SPEC-003 §3.1）。
///
/// 漂移偵測：[isBuiltinSchemaVersionDrifted] 比較內嵌資產版本與本 repo
/// 現行 `.claude/VERSION`（次版號差距）。承擔者與門檻——
/// 門檻：次版號差距超過 [kSchemaVersionDriftThreshold]（目前 25，已知
/// 現行漂移為 20，留 5 的餘裕）；承擔者：下一位執行涉及本檔或
/// `assets/schema/builtin_schema_version.json` 的 IMP ticket 之
/// parsley-flutter-developer。偵測機制為
/// `test/unit/screens/domain_view_schema_drift_test.dart` 內以真實
/// `.claude/VERSION` 驅動的門檻測試：超過門檻時該測試轉紅、CI 卡關，
/// 不是無 trigger 的待觀察（`decision-trigger-binding` 規則 1／2.5）。
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 內嵌資產路徑（見 `pubspec.yaml` 的 `flutter.assets` 宣告）。
const String builtinSchemaVersionAssetPath =
    'assets/schema/builtin_schema_version.json';

/// 漂移偵測門檻（次版號差距，見檔頭「漂移偵測」）。
const int kSchemaVersionDriftThreshold = 25;

/// 讀取內嵌資產的 `schema_generated_at_framework_version` 欄。
///
/// `cache: false`：`rootBundle` 的字串快取是行程層級單例，測試環境下
/// 一個測試未等待其 Future 完成即結束時，快取的 Future 會卡在未完成
/// 狀態並被後續測試重用，導致永久掛起（`flutter test` 實測重現）；停用
/// 快取讓每次呼叫各自獨立完成，副作用僅為省去一次記憶體快取，讀取的是
/// 本機小型資產檔，成本可忽略。
final builtinSchemaVersionProvider = FutureProvider<String>((ref) async {
  final raw = await rootBundle.loadString(
    builtinSchemaVersionAssetPath,
    cache: false,
  );
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return data['schema_generated_at_framework_version'] as String;
});

/// [version] 是否高於 [builtinVersion]（逐段整數比較，段數不足補零；
/// 任一段無法解析為整數時視為高於——安全預設拒絕提供降級出口，呼應
/// SPEC-001 §1「無可消費的型別表」顯式關卡精神：不確定時不自動降級）。
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

/// [liveVersion]（本 repo 現行 `.claude/VERSION`）與 [assetVersion]
/// （內嵌資產版本）的次版號（第二段）差距。任一版本字串段數不足兩段
/// 或該段無法解析為整數時回傳 `null`（無法判定，呼叫端須視為不漂移，
/// 與 [isHigherThanBuiltinSchemaVersion] 的「不確定時安全預設」呼應但
/// 方向相反——漂移偵測是診斷用途而非阻擋關卡，無法判定時不應誤報）。
int? schemaVersionMinorDrift(String liveVersion, String assetVersion) {
  final live = liveVersion.split('.').map(int.tryParse).toList();
  final asset = assetVersion.split('.').map(int.tryParse).toList();
  if (live.length < 2 || asset.length < 2) return null;
  final liveMinor = live[1];
  final assetMinor = asset[1];
  if (liveMinor == null || assetMinor == null) return null;
  return liveMinor - assetMinor;
}

/// 漂移是否已超過 [threshold]（預設 [kSchemaVersionDriftThreshold]）。
bool isBuiltinSchemaVersionDrifted(
  String liveVersion,
  String assetVersion, {
  int threshold = kSchemaVersionDriftThreshold,
}) {
  final drift = schemaVersionMinorDrift(liveVersion, assetVersion);
  if (drift == null) return false;
  return drift > threshold;
}
