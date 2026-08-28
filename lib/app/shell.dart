/// 六項導覽的路由殼。
///
/// 左側導覽列 + 右側內容區的共用容器。各畫面若自帶導覽，切換行為會分歧
/// （見 ticket why）；[AppShell] 交出「可切換」這件事本身，內容由
/// [buildDestinationPage] 依 [AppDestination] 決定。
///
/// 側欄頂端顯示專案名，是專案切換的入口——PROP-004 §範圍界定已定案：
/// 專案切換不是獨立畫面，故不佔導覽列一項，收為側欄浮層。浮層的三個狀態
/// （近期專案／選擇資料夾／切換中）由後續票實作，本票只留入口與空殼浮層。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'router.dart';

/// 側欄固定寬度。桌面單視窗版型，不隨內容縮放。
const double _kSidebarWidth = 220;

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  /// 整合測試用來確認「已抵達導覽殼」的錨點。
  static const Key shellKey = Key('app-shell');

  /// 側欄頂端專案名按鈕的錨點，供測試定位點擊目標。
  static const Key projectSwitcherEntryKey = Key('project-switcher-entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destination = ref.watch(selectedDestinationProvider);
    return Scaffold(
      key: shellKey,
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: TextStyle(fontSize: AppFontSize.title.sp),
        ),
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(selected: destination),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(
              child: IndexedStack(
                index: destination.index,
                children: [
                  for (final item in AppDestination.values)
                    buildDestinationPage(context, item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 左側導覽列：頂端專案切換入口 + 六個畫面項目。
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected});

  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: _kSidebarWidth.w,
      color: AppColors.surfaceSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectSwitcherEntry(l10n: l10n),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: Space.sm.h),
              children: [
                for (final item in AppDestination.values)
                  _NavItem(
                    destination: item,
                    label: item.label(l10n),
                    isSelected: item == selected,
                    onTap: () => ref
                        .read(selectedDestinationProvider.notifier)
                        .state = item,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 側欄頂端的專案名按鈕，同時是專案切換浮層的入口。
///
/// 專案名稱本身由後續票接上真實資料來源；本票僅交出「點擊有回應」這件
/// 事——回應形式是彈出一個標示切換浮層標題的空殼對話框。
class _ProjectSwitcherEntry extends StatelessWidget {
  const _ProjectSwitcherEntry({required this.l10n});

  final AppLocalizations l10n;

  void _openSwitcher(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.projectSwitcherPlaceholderTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: AppShell.projectSwitcherEntryKey,
      onTap: () => _openSwitcher(context),
      child: Padding(
        padding: EdgeInsets.all(Space.md.w),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 18.r, color: AppColors.accent),
            SizedBox(width: Space.sm.w),
            Expanded(
              child: Text(
                l10n.projectSwitcherEntryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.subtitle.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTitle,
                ),
              ),
            ),
            Icon(
              Icons.unfold_more,
              size: 16.r,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 單一導覽項目。
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AppDestination destination;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('nav-item-${destination.name}'),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: Space.sm.w,
          vertical: Space.xxs.h,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: Space.md.w,
          vertical: Space.sm.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceChip : null,
          borderRadius: BorderRadius.circular(Radius.md),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppFontSize.body.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.accentStrong : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
