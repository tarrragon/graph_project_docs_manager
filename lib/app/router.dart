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
import '../screens/trace/trace_screen.dart';
import '../screens/gap_report/gap_report_screen.dart';

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

/// 觸發導覽切換的兩種意圖（SPEC-003 §2.3）。
///
/// 兩者的差異只在對 [returnToProvider] 的效果：[rail] 清空來源記錄
/// （切換工作區語意，等同 `go`），[jump] 記錄跳轉前的畫面（暫時離開
/// 語意，等同 `push`）。
enum NavIntent {
  /// 使用者點擊 `nav-item-<d>` 造成的切換。
  rail,

  /// 畫面內元素（空狀態的前進動作、徽章、節點卡、關聯項）造成的切換。
  jump,
}

/// 單槽來源記錄（SPEC-003 §2.3 FR-03）。
///
/// **採單槽而非堆疊**：六項導覽恆常可見於側欄，逐層回退相對於直接點擊
/// 目標分頁不提供額外使用者價值，單槽記錄「最近一次跳轉從哪來」即可
/// 滿足 SPEC-001 四個退出路徑的「回到來源」語意。
///
/// 四條規則（皆由 [navigateTo] 與 [consumeReturnTo] 落實，畫面不得繞過
/// 這兩個入口直接寫 [selectedDestinationProvider]）：
/// 1. `rail` 切換 → 設為 `null`
/// 2. `jump` 切換 → 設為跳轉前的 destination
/// 3. 連續 `jump`（A→B→C）→ 為 B，此為明確定義而非未定義行為
/// 4. 觸發返回時 → 切至 `returnTo`，隨即設為 `null`
final returnToProvider = StateProvider<AppDestination?>((ref) => null);

/// [navigateTo] / [consumeReturnTo] 共用的讀取簽章。[WidgetRef.read] 與
/// [ProviderContainer.read] 皆符合此簽章，讓兩函式在 widget 與純
/// provider（測試用 [ProviderContainer]）情境下皆可直接呼叫同一份實作，
/// 不需為測試另建重複邏輯。
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// 依 [intent] 切換到 [target]，同時依 SPEC-003 §2.3 四條規則更新
/// [returnToProvider]。畫面內的導覽動作（`nav-item-<d>`、jump 錨點）
/// 一律透過本函式切換（呼叫時傳入 `ref.read`），不得直接寫
/// provider——否則 `returnTo` 的兩條規則會被繞過而產生不一致的來源記錄。
void navigateTo(ProviderReader read, AppDestination target, NavIntent intent) {
  final current = read(selectedDestinationProvider);
  read(returnToProvider.notifier).state = switch (intent) {
    NavIntent.rail => null,
    NavIntent.jump => current,
  };
  read(selectedDestinationProvider.notifier).state = target;
}

/// 觸發「返回」（SPEC-003 §2.4 第四類反應）：切至 [returnToProvider]
/// 的值，隨即將其設為 `null`。呼叫前應先確認 `returnTo` 非 `null`——
/// 為 `null` 時沒有意義的返回目標，`action-<screen>-back` 錨點依規則 4
/// 本就不應渲染。
void consumeReturnTo(ProviderReader read) {
  final target = read(returnToProvider);
  if (target == null) return;
  read(returnToProvider.notifier).state = null;
  read(selectedDestinationProvider.notifier).state = target;
}

/// 已首次可見過的畫面集合（SPEC-003 §2.8：`IndexedStack` 一次建構六頁，
/// 「依視圖惰性」不得以首次建構為觸發訊號，須以首次成為 index 觸發）。
///
/// 初始為空集合——啟動當下的落地頁尚未被記錄，讓它在第一次被
/// [firstVisibleProvider] 讀取時仍判定為「首次」；此後由
/// [firstVisibleProvider] 寫入。判斷來源完全在 provider 層（本值 +
/// [selectedDestinationProvider]），不依賴任何 widget 生命週期。
final visitedDestinationsProvider = StateProvider<Set<AppDestination>>(
  (ref) => <AppDestination>{},
);

/// [destination] 是否為「首次可見」：目前選取項恰為 [destination]，且
/// 尚未出現在 [visitedDestinationsProvider]。
///
/// 讀取到 `true` 的那次即為觸發惰性載入的時機；讀取後立即（下一個
/// microtask）把 [destination] 併入已見集合，故同一個 destination 不會
/// 重複觸發——切走再切回只會再次讀到 `false`。副作用延後到 microtask
/// 執行，避免在其他 provider 的 build 過程中同步改寫本 provider 狀態。
final firstVisibleProvider = Provider.family<bool, AppDestination>(
  (ref, destination) {
    final current = ref.watch(selectedDestinationProvider);
    final visited = ref.watch(visitedDestinationsProvider);
    final isFirst = current == destination && !visited.contains(destination);
    if (isFirst) {
      Future.microtask(() {
        final notifier = ref.read(visitedDestinationsProvider.notifier);
        notifier.state = {...notifier.state, destination};
      });
    }
    return isFirst;
  },
);

/// 依 [destination] 產生對應的畫面內容。
///
/// 目前六項全部渲染標示畫面名的佔位頁——各畫面的實際內容由後續票逐一
/// 實作，本票只交出「可切換」這件事本身。
Widget buildDestinationPage(BuildContext context, AppDestination destination) {
  if (destination == AppDestination.traceability) {
    return TraceabilityScreen(key: destination.pageKey);
  if (destination == AppDestination.gaps) {
    return GapReportScreen(key: destination.pageKey);
  }
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
