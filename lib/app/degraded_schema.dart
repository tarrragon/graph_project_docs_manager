/// 降級型別表旗標（SPEC-001 §1〈降級型別表〉疊加旗標；SPEC-004 §4.27
/// `AppShell` state-change 列）。
///
/// 全域布林：任一畫面觸發「以 App 內建型別表檢視」後應設為真，供
/// [components.AppShell] 於返回列同一列常駐渲染
/// `badge-<screen>-degraded-schema`（SPEC-004 §4.27〈實作註記〉「降級徽章
/// 比照同一實作方式，與返回列同一列疊於 `IndexedStack` 內容之上」）；
/// 切換專案時應重置（SPEC-001 §1「切換專案時旗標重置」）。
///
/// **寫入端尚未接線**：本票（`0.1.0-W2-009`）僅建立容器與本 provider 骨架，
/// 由畫面觸發（`lib/screens/domain_view/`）寫入此值、以及專案切換時重置，
/// 兩者依派發範圍限制不在本票內——該目錄由另一票（`0.1.0-W1-078`）並行
/// 修改中，本票不觸碰，見本票 NeedsContext。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 降級型別表旗標，預設 `false`（未降級）。
final degradedSchemaProvider = StateProvider<bool>((ref) => false);
