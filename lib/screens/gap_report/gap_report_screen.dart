/// 破洞報告畫面（SPEC-001 §5；SPEC-003 §3.5）。
///
/// 三狀態依 [GapReportState] 切換，內容由 [gapReportProvider] 供給。導覽
/// 退出路徑（`nav-item-<d>`、`project-switcher-entry`）由 `AppShell` 統一
/// 承載，本畫面只處理狀態內的退出路徑（取消、重新掃描、破洞項）。
library;

import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'gap_report_models.dart';
import 'gap_report_provider.dart';

/// 破洞報告畫面。
class GapReportScreen extends ConsumerWidget {
  const GapReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gapReportProvider);
    return switch (state) {
      GapReportScanning() => _ScanningView(state: state),
      GapReportNoGaps() => const _NoGapsView(),
      GapReportFound() => _FoundView(state: state),
    };
  }
}

/// 掃描中：`LoadingState.skeleton`（版位 `sections`）。
class _ScanningView extends ConsumerWidget {
  const _ScanningView({required this.state});

  final GapReportScanning state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return LoadingState.skeleton(
      message: l10n.gapReportScanning,
      skeletonLayout: SkeletonLayout.sections,
      isCancelling: state.isCancelling,
      onCancel: () => ref.read(gapReportProvider.notifier).cancelScan(),
      testKey: const Key('state-gaps-scanning'),
      cancelKey: const Key('action-gaps-cancel-scan'),
      countText: l10n.gapsScanningProcessedCount(state.processedCount),
      cancelLabel: l10n.cancelScanAction,
    );
  }
}

/// 無破洞：`EmptyState.page`（說明 slot 放掃描範圍說明；動作放重新掃描）。
class _NoGapsView extends ConsumerWidget {
  const _NoGapsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      message: l10n.noGapsMessage,
      explanation: l10n.noGapsScanScope,
      testKey: const Key('state-gaps-none'),
      actions: [
        AppButton(
          label: l10n.rescanAction,
          onPressed: () => ref.read(gapReportProvider.notifier).rescan(),
          testKey: const Key('action-gaps-rescan'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}

/// 有破洞：`Panel.scrollable`[`Section.collapsible`[`ListRow.sectionHeader`,
/// `ListRow.item` × N] × N]；重新掃描鈕與內容同置於可捲動面板頂部（元件庫
/// 尚無「每頁頁首右側可依畫面自訂內容」的 slot——`lib/app/shell.dart` 的
/// `SplitRow.header` 對六個畫面共用同一份 `leading: PageTitle`，無 per-screen
/// trailing 掛點；SPEC-004 §3.7 第 18 項核定的頁首位置需要該掛點才能落地，
/// 已於本票 Solution 記錄並提報後續票）。
class _FoundView extends ConsumerWidget {
  const _FoundView({required this.state});

  final GapReportFound state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Panel.scrollable(
      key: const Key('state-gaps-found'),
      scrollKey: const Key('scroll-gaps-sections'),
      children: [
        ButtonRow(
          alignment: ButtonRowAlignment.end,
          children: [
            AppButton(
              label: l10n.rescanAction,
              onPressed: () => ref.read(gapReportProvider.notifier).rescan(),
              testKey: const Key('action-gaps-rescan'),
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
        for (final category in state.categories)
          _CategorySection(category: category),
      ],
    );
  }
}

/// 單一破洞類別分節：節首含展開器 + 計數，展開時列出各破洞項。
class _CategorySection extends ConsumerStatefulWidget {
  const _CategorySection({required this.category});

  final GapReportCategory category;

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Section(
      variant: SectionVariant.collapsible,
      isExpanded: _isExpanded,
      testKey: Key('state-gaps-section-${widget.category.id}'),
      header: ListRow.sectionHeader(
        leading: ExpanderIcon(
          isExpanded: _isExpanded,
          testKey: Key('expander-gaps-${widget.category.id}'),
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
        ),
        primary: AppText(_categoryLabel(l10n, widget.category.id)),
        trailing: AppText(
          l10n.gapSectionCount(widget.category.items.length),
          variant: AppTextVariant.caption,
        ),
      ),
      items: [
        for (final item in widget.category.items)
          ListRow.item(
            primary: AppText(item.filePath, variant: AppTextVariant.mono),
            secondary: AppText(
              l10n.gapItemLineLabel(item.lineNumber),
              variant: AppTextVariant.caption,
              secondary: true,
            ),
            trailing: AppIcon(
              icon: Icons.open_in_new,
              size: IconSize.sm,
              semanticLabel: l10n.openExternallyA11yLabel,
            ),
            onTap: () => _openItem(context, item),
            testKey: Key('card-gaps-${item.id}'),
          ),
      ],
    );
  }

  /// 破洞項（SPEC-003 §3.5）：檔案存在則以系統預設方式開啟並提示已開啟；
  /// 不存在則提示找不到檔案，帶重新掃描動作，停留 `Motion.snackBarWithAction`
  /// （由 [AppSnackBar.show] 承載，本函式不重複時限決策）。
  Future<void> _openItem(BuildContext context, GapReportItem item) async {
    final l10n = AppLocalizations.of(context);
    final exists = File(item.filePath).existsSync();
    if (!exists) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: l10n.sourceFileNotFoundSnackbarMessage,
        variant: AppSnackBarVariant.withAction,
        actionLabel: l10n.rescanAction,
        actionTestKey: Key('action-gaps-rescan-snackbar-${item.id}'),
        onAction: () => ref.read(gapReportProvider.notifier).rescan(),
      );
      return;
    }
    await Process.run('open', [item.filePath]);
    if (!context.mounted) return;
    AppSnackBar.show(context, message: l10n.openedExternallyMessage);
  }
}

/// 類別識別碼 → 語系化標籤。0.1 只有一個真實類別（缺 frontmatter），
/// 保留 switch 形式供後續類別擴充時集中查表。
String _categoryLabel(AppLocalizations l10n, String categoryId) =>
    switch (categoryId) {
      'missing-frontmatter' => l10n.gapCategoryMissingFrontmatter,
      _ => categoryId,
    };
