/// 降級型別表旗標（SPEC-001 §1〈降級型別表〉疊加旗標；SPEC-004 §4.27
/// `AppShell` state-change 列）。
///
/// 全域布林：任一畫面觸發「以 App 內建型別表檢視」後應設為真，供
/// [components.AppShell] 於返回列同一列常駐渲染
/// `badge-<screen>-degraded-schema`（SPEC-004 §4.27〈實作註記〉「降級徽章
/// 比照同一實作方式，與返回列同一列疊於 `IndexedStack` 內容之上」）；
/// 切換專案時應重置（SPEC-001 §1「切換專案時旗標重置」）。
///
/// 寫入端已接線（`0.1.0-W2-014`）：`domain_view_screen.dart` 的
/// `_SchemaUnconsumableView.onDegradedView` 觸發時同步寫入本旗標與
/// [degradedSchemaVersionsProvider]；`project_switcher_overlay.dart` 的
/// `_selectProject`（切換專案）重置兩者。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 降級型別表旗標，預設 `false`（未降級）。
final degradedSchemaProvider = StateProvider<bool>((ref) => false);

/// 降級徽章版本文字所需的兩個值（`badge-<screen>-degraded-schema` 徽章
/// `{builtinVersion}` / `{projectVersion}` placeholder，`app_zh.arb`
/// `degradedSchemaBadgeLabel`）。
class DegradedSchemaVersions {
  const DegradedSchemaVersions({
    required this.builtinVersion,
    required this.projectVersion,
  });

  /// 內建型別表版本（`builtinSchemaVersionProvider` 讀值）。
  final String builtinVersion;

  /// 觸發降級當下的專案 VERSION（`DomainSchemaUnconsumable.version`）。
  final String projectVersion;
}

/// 降級徽章版本文字，與 [degradedSchemaProvider] 同步寫入／重置；
/// `null` 表示尚未降級（不應被畫面讀取渲染文字）。
final degradedSchemaVersionsProvider =
    StateProvider<DegradedSchemaVersions?>((ref) => null);
