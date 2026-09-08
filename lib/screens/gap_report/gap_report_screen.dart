/// 破洞報告畫面（SPEC-001 §5；SPEC-003 §3.5）。
///
/// 三狀態依 [GapReportState] 切換，內容由 [gapReportProvider] 供給。導覽
/// 退出路徑（`nav-item-<d>`、`project-switcher-entry`）由 `AppShell` 統一
/// 承載，本畫面只處理狀態內的退出路徑（取消、重新掃描、破洞項）。
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import 'gap_report_models.dart';
import 'gap_report_provider.dart';
import 'scan_notification_controller.dart';

const String _tag = 'GapReportScreen';

/// 外部開啟的行程執行接縫（暫時）。
///
/// 存在理由是可測性：`_openItem` 的兩條失敗路徑（exitCode 非零、呼叫本身
/// 拋例外）在 `Process.run` 直接寫死時無法以替身抵達，而失敗路徑正是本畫面
/// 過去回報假成功的地方。此 provider 只把 `dart:io` 的呼叫拉成可覆寫的一級
/// 函式，**不定義結果語意**——三結果契約（`opened` / `notFound` / `failed`）
/// 屬 `ExternalOpener`（SPEC-003 §2.2），由 `0.1.0-W1-068` 落地；該票落地後
/// 本 provider 與 `_openItem` 內的分支一併由注入的 `ExternalOpener` 取代。
@visibleForTesting
final gapItemProcessRunnerProvider =
    Provider<Future<ProcessResult> Function(String, List<String>)>(
      (ref) => Process.run,
    );

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
          _LocatableGapItem(
            item: item,
            child: ListRow.item(
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
          ),
      ],
    );
  }

  /// 破洞項（SPEC-003 §3.5）：三種結局各有一則對應的回饋，缺任一則即為
  /// 靜默失敗或假成功（ARCH-GPD-001）——檔案不存在提示找不到檔案並帶重新
  /// 掃描動作；開啟成功提示已開啟；開啟失敗提示無法以系統預設方式開啟。
  /// 停留時間由 [AppSnackBar.show] 承載，本函式不重複時限決策。
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
    final failure = await _runOpen(item.filePath);
    if (failure != null) {
      developer.log(
        '外部開啟失敗（${item.filePath}）：$failure', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
    }
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: failure == null
          ? l10n.openedExternallyMessage
          : l10n.externalOpenFailedMessage,
    );
  }

  /// 以系統預設方式開啟 [path]，成功回傳 `null`，失敗回傳診斷字串。
  ///
  /// 兩種失敗在此合為同一個結局：非零 exitCode 與呼叫本身拋出的例外，對
  /// 使用者而言都是「這個檔案沒有被打開」。例外不外傳的理由是比例——讓它
  /// 傳播會由 `FatalErrorGate` 把整個畫面轉為阻擋狀態，而收斂之後的狀態
  /// 必須有可見表現（ARCH-GPD-001 解決方案 3），此處即那一則失敗 SnackBar。
  Future<String?> _runOpen(String path) async {
    developer.log('外部開啟：$path', name: _tag); // i18n-exempt: 開發者診斷 log
    try {
      final result = await ref.read(gapItemProcessRunnerProvider)('open', [
        path,
      ]);
      if (result.exitCode == 0) return null;
      // i18n-exempt: 開發者診斷字串，只進 developer.log 不進畫面
      return 'exitCode=${result.exitCode} stderr=${result.stderr}';
    } catch (error) {
      return '$error';
    }
  }
}

/// 點擊系統通知後的定位載體（SPEC-004 §1 locate 列；SPEC-003 §2.2「點擊
/// 通知的導向」）：命中 [pendingLocateGapItemProvider] 時 scroll-into-view
/// 並移入焦點，處理後清空該 provider，避免重複觸發。
class _LocatableGapItem extends ConsumerStatefulWidget {
  const _LocatableGapItem({required this.item, required this.child});

  final GapReportItem item;
  final Widget child;

  @override
  ConsumerState<_LocatableGapItem> createState() => _LocatableGapItemState();
}

class _LocatableGapItemState extends ConsumerState<_LocatableGapItem> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingId = ref.watch(pendingLocateGapItemProvider);
    if (pendingId == widget.item.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(context, alignment: 0.1);
        _focusNode.requestFocus();
        ref.read(pendingLocateGapItemProvider.notifier).state = null;
      });
    }
    return Focus(focusNode: _focusNode, child: widget.child);
  }
}

/// 類別識別碼 → 語系化標籤。0.1 只有一個真實類別（缺 frontmatter），
/// 保留 switch 形式供後續類別擴充時集中查表。
String _categoryLabel(AppLocalizations l10n, String categoryId) =>
    switch (categoryId) {
      'missing-frontmatter' => l10n.gapCategoryMissingFrontmatter,
      _ => categoryId,
    };
