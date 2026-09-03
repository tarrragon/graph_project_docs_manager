/// 六項導覽的路由殼。
///
/// 左側導覽列 + 右側內容區的共用容器，實作骨架委派給
/// [components.AppShell]（SPEC-004 §4.27）——本檔只負責把 [router.dart]
/// 的路由狀態組成該容器所需的六組 slot，不再自建側欄／標題列骨架。
///
/// 側欄頂端顯示專案名，是專案切換的入口——PROP-004 §範圍界定已定案：
/// 專案切換不是獨立畫面，故不佔導覽列一項，收為側欄浮層。浮層的三個狀態
/// （近期專案／選擇資料夾／切換中）由後續票實作，本票只留入口與空殼浮層。
library;

import 'package:flutter/material.dart' show Icons, Material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/components.dart' as components;
import '../l10n/app_localizations.dart';
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

class _AppShellState extends ConsumerState<AppShell> {
  bool _isSwitcherOpen = false;

  void _toggleSwitcher() => setState(() => _isSwitcherOpen = !_isSwitcherOpen);

  void _dismissSwitcher() => setState(() => _isSwitcherOpen = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destination = ref.watch(selectedDestinationProvider);

    // `MaterialApp.home` 不自動提供 Material 祖先（過去由 shell.dart 自建
    // 的 `Scaffold` 承接）；`components.AppShell` 是純骨架容器不含
    // `Scaffold`，故在此補上唯一一層 `Material`，讓子件（`InkWell` 等）
    // 的 ink 效果有著落。
    return Material(
      child: components.AppShell(
        switcherEntry: components.ProjectSwitcherEntry(
          isExpanded: _isSwitcherOpen,
          onTap: _toggleSwitcher,
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
        overlay: _isSwitcherOpen
            ? components.SwitcherOverlay(
                items: const [],
                chooseOther: components.AppButton(
                  label: l10n.switcherChooseOtherFolder,
                  onPressed: _dismissSwitcher,
                  testKey: const Key('action-switcher-choose-other'),
                  variant: components.AppButtonVariant.text,
                ),
                onDismiss: _dismissSwitcher,
                testKey: const Key('state-switcher-no-recent'),
                scrollKey: const Key('scroll-switcher-recent'),
              )
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
