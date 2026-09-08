/// 六項導覽的路由殼。
///
/// 左側導覽列 + 右側內容區的共用容器，實作骨架委派給
/// [components.AppShell]（SPEC-004 §4.27）——本檔只負責把 [router.dart]
/// 的路由狀態組成該容器所需的六組 slot，不再自建側欄／標題列骨架。
///
/// 側欄頂端顯示專案名，是專案切換的入口——PROP-004 §範圍界定已定案：
/// 專案切換不是獨立畫面，故不佔導覽列一項，收為側欄浮層。浮層開合與三個
/// 狀態（收合／展開／無最近專案）委派給
/// `screens/project_switcher/project_switcher_overlay.dart`，本檔只把
/// provider 值接進 [components.AppShell] 的 `overlay` slot。
library;

import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/components.dart' as components;
import '../l10n/app_localizations.dart';
import '../screens/gap_report/scan_notification_controller.dart';
import '../screens/project_switcher/project_switcher_overlay.dart';
import '../screens/project_switcher/project_switcher_providers.dart';
import 'app_lifecycle.dart';
import 'router.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  /// 整合測試用來確認「已抵達導覽殼」的錨點。
  static const Key shellKey = components.AppShell.shellKey;

  /// 側欄頂端專案名按鈕的錨點，供測試定位點擊目標。
  static const Key projectSwitcherEntryKey =
      components.AppShell.projectSwitcherEntryKey;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  late final ScanNotificationController _scanNotificationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `AppShell` 是應用程式常駐殼：以 `context` 作為系統通知 fallback
    // SnackBar 的載體，掛載期間內恆有效（SPEC-003 §2.2）。
    _scanNotificationController = ScanNotificationController(
      ref,
      () => context,
    )..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanNotificationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _scanNotificationController.syncLocalizedStrings(l10n);
    final destination = ref.watch(selectedDestinationProvider);
    final isSwitcherOpen = ref.watch(switcherOpenProvider);
    final projectName = ref.watch(currentProjectNameProvider);

    // `MaterialApp.home` 不自動提供 Material／Scaffold 祖先；
    // `components.AppShell` 是純骨架容器不含 `Scaffold`，故在此補上唯一
    // 一層 `Scaffold`（取代先前的 `Material`）——`Scaffold` 內建
    // `Material`，子件（`InkWell` 等）的 ink 效果同樣有著落，額外提供
    // `ScaffoldMessenger` 呈現 SnackBar 所需的至少一個已掛載 `Scaffold`
    // （0.1.0-W3-064：系統通知 denied fallback 走 `AppSnackBar.show`，
    // 若樹上無任何 `Scaffold`，`ScaffoldMessengerState.showSnackBar` 會
    // 因 `_scaffolds.isEmpty` 直接拋出斷言錯誤——純 `Material` 無法滿足
    // 此前提，屬既有設計缺口，隨本票一併修正）。
    return Scaffold(
      body: components.AppShell(
        switcherEntry: components.ProjectSwitcherEntry(
          projectName: projectName,
          isExpanded: isSwitcherOpen,
          onTap: () => ref.read(switcherOpenProvider.notifier).state =
              !isSwitcherOpen,
          testKey: AppShell.projectSwitcherEntryKey,
        ),
        navItems: [
          for (final item in AppDestination.values)
            components.NavItem(
              icon: components.AppIcon(icon: _iconFor(item)),
              label: item.label(l10n),
              isSelected: item == destination,
              onTap: () => navigateTo(ref.read, item, NavIntent.rail),
              testKey: Key('nav-item-${item.name}'),
            ),
        ],
        pages: [
          for (final item in AppDestination.values)
            components.PageColumn(
              semanticLabel: item.label(l10n),
              header: components.SplitRow.header(
                leading: components.PageTitle(title: item.label(l10n)),
              ),
              content: buildDestinationPage(context, item),
            ),
        ],
        overlay: isSwitcherOpen
            ? buildProjectSwitcherOverlay(context: context, ref: ref)
            : null,
      ),
    );
  }
}

/// 六個導覽項的裝飾性圖示（純顯示，不承載語意——`NavItem` 已以 `label`
/// 承載朗讀內容）。依畫面性質挑選語意相近的圖示，元件庫契約未限定圖示集。
IconData _iconFor(AppDestination destination) => switch (destination) {
      AppDestination.domain => Icons.grid_view_outlined,
      AppDestination.ucFlow => Icons.timeline_outlined,
      AppDestination.traceability => Icons.route_outlined,
      AppDestination.tickets => Icons.checklist_outlined,
      AppDestination.gaps => Icons.report_problem_outlined,
      AppDestination.nodeDetail => Icons.description_outlined,
    };
