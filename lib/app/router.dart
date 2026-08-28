/// 六項導覽的路由定義（PROP-004 §範圍界定；SPEC-001 §1-6）。
///
/// 這不是完整的 URL-based 路由系統——桌面單視窗 App 目前不需要瀏覽器式的
/// history stack。[AppDestination] 是六個畫面的型別化列舉，[selectedDestinationProvider]
/// 持有目前選取項，[AppShell]（見 `shell.dart`）依此在 `IndexedStack` 中切換內容。
/// 未來若真的需要 deep link，再升級為完整路由套件，介面（enum + provider）不必變。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

/// 六個畫面，順序即導覽列的顯示順序（SPEC-001 §1-6 逐項對應）。
enum AppDestination {
  /// SPEC-001 §1 Domain 視圖（矩陣／泳道雙模式）。
  domain,

  /// SPEC-001 §2 UC Flow 視圖。
  ucFlow,

  /// SPEC-001 §3 追溯視圖。
  traceability,

  /// SPEC-001 §4 Ticket 清單（列表／主題雙模式）。
  tickets,

  /// SPEC-001 §5 破洞報告。
  gaps,

  /// SPEC-001 §6 節點詳情。
  nodeDetail;

  /// 導覽列上顯示的語系化文字。
  String label(AppLocalizations l10n) => switch (this) {
        AppDestination.domain => l10n.navDomain,
        AppDestination.ucFlow => l10n.navUcFlow,
        AppDestination.traceability => l10n.navTraceability,
        AppDestination.tickets => l10n.navTickets,
        AppDestination.gaps => l10n.navGaps,
        AppDestination.nodeDetail => l10n.navNodeDetail,
      };

  /// 整合測試與 widget 測試用來定位個別佔位頁的錨點。
  ///
  /// 值刻意與 [name] 一致（穩定、不受語系影響），供測試以
  /// `find.byKey(Key('nav-page-${AppDestination.domain.name}'))` 定位。
  Key get pageKey => Key('nav-page-$name');
}

/// 目前選取的導覽項。預設落在 [AppDestination.domain]——六個畫面中，
/// Domain 視圖是 SPEC-001 §1 列出的第一個，也是概念上的總覽入口。
final selectedDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.domain,
);

/// 依 [destination] 產生對應的畫面內容。
///
/// 目前六項全部渲染標示畫面名的佔位頁——各畫面的實際內容由後續票逐一
/// 實作，本票只交出「可切換」這件事本身。
Widget buildDestinationPage(BuildContext context, AppDestination destination) {
  final l10n = AppLocalizations.of(context);
  return _DestinationPlaceholderPage(
    key: destination.pageKey,
    label: destination.label(l10n),
  );
}

/// 標示畫面名稱的佔位頁。
class _DestinationPlaceholderPage extends StatelessWidget {
  const _DestinationPlaceholderPage({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}
