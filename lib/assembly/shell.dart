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

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/components.dart' as components;
import '../state/state_holder.dart' show StateHolder;
import '../l10n/app_localizations.dart';
import '../app/domain_view_providers.dart';
import '../screens/domain_view/domain_view_screen.dart';
import '../app/domain_view_state.dart';
import '../app/gate_detection_notifier.dart';
import '../app/history_providers.dart';
import '../screens/gap_report/gap_report_screen.dart';
import '../screens/gap_report/scan_notification_controller.dart';
import '../screens/node_detail/node_detail_screen.dart';
import '../screens/ticket_list/ticket_list_screen.dart';
import '../screens/preferences/preferences_panel.dart';
import '../screens/shortcuts/shortcuts_panel.dart';
import '../screens/project_switcher/project_switcher_overlay.dart';
import '../screens/write_log/write_log_panel.dart';
import '../app/write_list_providers.dart';
import '../services/macos_preferences_channel.dart';
import '../app/project_switcher_providers.dart';
import '../workspace/current_workspace_provider.dart';
import '../workspace/workspace_types.dart';
import '../app/app_lifecycle.dart';
import '../app/corpus_watch_provider.dart';
import '../app/degraded_schema.dart';
import '../app/recent_project_counts_writer.dart';
import '../app/router.dart';
import '../app/workspace_selection.dart' show projectGenerationProvider;
import 'destination_pages.dart';

/// 可觀測性（observability 規則 5）：`didChangeAppLifecycleState`
/// 屬生命週期回調，狀態轉換以 `developer.log` 記錄（開發者診斷字串，
/// 非使用者可見文字，不進 i18n）。
const String _tag = 'AppShell';

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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  late final ScanNotificationController _scanNotificationController;
  StreamSubscription<void>? _preferencesRequests;
  StreamSubscription<void>? _shortcutsRequests;
  final FocusNode _preferencesItemFocus = FocusNode(
    debugLabel: 'nav-action-preferences',
  );
  final FocusNode _shortcutsItemFocus = FocusNode(
    debugLabel: 'nav-action-shortcuts',
  );
  final FocusNode _writeLogItemFocus = FocusNode(
    debugLabel: 'nav-action-writeLog',
  );

  /// 面板關閉後焦點的歸還目標（SPEC-003 §3.10）：底部項開啟為該項，
  /// 選單或 ⌘, 開啟為開啟前的焦點持有者（無則 null，不預設焦點）。
  FocusNode? _returnFocusTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ⌘,（選單列「Preferences…」）開啟主視窗內的偏好設定面板（SPEC-003 §3.8）；
    // 面板已開啟時再收到請求不重複掛載、不重新偵測。
    _preferencesRequests = ref
        .read(preferencesChannelProvider)
        .openRequested
        .listen((_) => _openPreferences(FocusManager.instance.primaryFocus));
    // 說明選單「鍵盤快捷鍵」開啟快捷鍵面板；與偏好設定互斥由 build 的 ref.listen 處理。
    _shortcutsRequests = ref
        .read(preferencesChannelProvider)
        .openKeyboardShortcutsRequested
        .listen((_) => _openShortcuts(FocusManager.instance.primaryFocus));
    // SPEC-006 FR-11 規則 1：常駐殼啟動即掛上監看，早於還原工作區後的首輪掃描。
    ref.read(corpusWatchProvider);
    // 每輪掃描完成寫入最近專案計數快照（SPEC-005 §2.4〈計數快照〉）。
    ref.read(recentProjectCountsWriterProvider);
    // `AppShell` 是應用程式常駐殼：以 `context` 作為系統通知 fallback
    // SnackBar 的載體，掛載期間內恆有效（SPEC-003 §2.2）。
    _scanNotificationController = ScanNotificationController(ref, () => context)
      ..start();
    // App 啟動：還原先前選定的工作資料夾並執行 gate 偵測（0.2.0-W1-042，
    // W1-019 接線的上游進入點）。`unawaited`：initState 不可為 async，
    // 結果透過 provider 寫回，畫面依 domainViewStateProvider 反應變化。
    unawaited(_restoreWorkspaceAndDetect());
    // 變更記錄的掃描輸入由本殼接線（SPEC-008 FR-09）：延後到 build 階段之後
    // 寫入，避免在 initState 內改寫 provider。
    Future.microtask(() {
      if (!mounted) return;
      ref.read(historyScanInputsWiredProvider.notifier).state = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      developer.log(
        '首幀 Domain 狀態：${ref.read(domainViewStateProvider).runtimeType}', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 500,
      );
    });
  }

  /// [WorkspaceRepository.restore] 任何失敗皆降級為非 [WorkspaceReady]
  /// （見該檔契約），此時不執行 [GateDetectionNotifier.detect]，Domain 視圖
  /// 改寫為 [DomainUnset]；仍不阻擋 App 啟動。
  Future<void> _restoreWorkspaceAndDetect() async {
    final repository = ref.read(workspaceRepositoryProvider);
    final state = await repository.restore();
    if (!mounted) return;
    developer.log(
      'restore 完成：${state.runtimeType}', // i18n-exempt: 開發者診斷 log
      name: _tag,
      level: 500,
    );
    ref.read(currentWorkspaceStateProvider.notifier).state = state;
    // 最近專案清單與目前資料夾是否還原成功正交——即使 restore() 未還原到
    // WorkspaceReady，清單本身（SPEC-005 §2.4）仍應載入供切換浮層使用。
    final recentProjects = await repository.loadRecentProjects();
    if (!mounted) return;
    ref.read(recentProjectsProvider.notifier).state = recentProjects;
    switch (state) {
      case WorkspaceReady(:final path):
        await ref.read(gateDetectionNotifierProvider.notifier).detect(path);
      case WorkspaceUnset() || WorkspaceUnavailable():
        // SPEC-003 §3.1〈生命週期〉：無已存路徑或還原失敗，Domain 視圖進入
        // state-domain-unset，不停在預設的 fixture 矩陣（0.3.3-W3-398）。
        ref.read(domainViewStateProvider.notifier).state = const DomainUnset();
    }
  }

  void _openPreferences(FocusNode? returnTo) {
    _returnFocusTarget = returnTo;
    ref.read(preferencesOpenProvider.notifier).state = true;
  }

  void _openShortcuts(FocusNode? returnTo) {
    _returnFocusTarget = returnTo;
    ref.read(shortcutsOpenProvider.notifier).state = true;
  }

  void _openWriteLog(FocusNode? returnTo) {
    _returnFocusTarget = returnTo;
    ref.read(writeLogOpenProvider.notifier).state = true;
  }

  /// 面板互斥：[panel] 開啟時關閉 [others]；關閉且其他面板皆未開時歸還焦點。
  void _listenExclusivePanel(
    NotifierProvider<StateHolder<bool>, bool> panel,
    List<NotifierProvider<StateHolder<bool>, bool>> others,
  ) {
    ref.listen<bool>(panel, (_, open) {
      if (open) {
        for (final other in others) {
          ref.read(other.notifier).state = false;
        }
      } else {
        _restoreFocusAfterClose(
          otherPanelOpen: others.any((other) => ref.read(other)),
        );
      }
    });
  }

  /// 面板關閉（非因另一面板開啟而被互斥關閉）後把焦點交還開啟者。
  void _restoreFocusAfterClose({required bool otherPanelOpen}) {
    if (otherPanelOpen) return;
    final target = _returnFocusTarget;
    _returnFocusTarget = null;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && target.context != null) target.requestFocus();
    });
  }

  @override
  void dispose() {
    _preferencesItemFocus.dispose();
    _shortcutsItemFocus.dispose();
    _writeLogItemFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _preferencesRequests?.cancel();
    _shortcutsRequests?.cancel();
    _scanNotificationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = ref.read(appLifecycleStateProvider);
    developer.log(
      '生命週期狀態轉換：$previous -> $state', // i18n-exempt: 開發者診斷 log
      name: _tag,
      level: 500,
    );
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _scanNotificationController.syncLocalizedStrings(l10n);
    // 專案改變（含同路徑重選）：清除顯示中的暫態提示（SPEC-003 §2.8）。
    ref.listen<int>(
      projectGenerationProvider,
      (_, _) => components.AppSnackBar.clearForProjectChange(context),
    );
    final destination = ref.watch(selectedDestinationProvider);
    final isSwitcherOpen = ref.watch(switcherOpenProvider);
    final projectName = ref.watch(currentProjectNameProvider);
    final returnTo = ref.watch(returnToProvider);
    final isDegraded = ref.watch(degradedSchemaProvider);
    final degradedVersions = ref.watch(degradedSchemaVersionsProvider);
    final inferredVersion = ref.watch(inferredVersionProvider);

    // `MaterialApp.home` 不自動提供 Material／Scaffold 祖先；
    // `components.AppShell` 是純骨架容器不含 `Scaffold`，故在此補上唯一
    // 一層 `Scaffold`（取代先前的 `Material`）——`Scaffold` 內建
    // `Material`，子件（`InkWell` 等）的 ink 效果同樣有著落，額外提供
    // `ScaffoldMessenger` 呈現 SnackBar 所需的至少一個已掛載 `Scaffold`
    // （0.1.0-W3-064：系統通知 denied fallback 走 `AppSnackBar.show`，
    // 若樹上無任何 `Scaffold`，`ScaffoldMessengerState.showSnackBar` 會
    // 因 `_scaffolds.isEmpty` 直接拋出斷言錯誤——純 `Material` 無法滿足
    // 此前提，屬既有設計缺口，隨本票一併修正）。
    final isPreferencesOpen = ref.watch(preferencesOpenProvider);
    final isShortcutsOpen = ref.watch(shortcutsOpenProvider);
    final isWriteLogOpen = ref.watch(writeLogOpenProvider);
    final failureCount = ref.watch(writeListFailureCountProvider);
    // 三面板互斥（SPEC-003 §3.8、§3.10、§3.12）：開一個時先關其他兩個。
    _listenExclusivePanel(preferencesOpenProvider, [
      shortcutsOpenProvider,
      writeLogOpenProvider,
    ]);
    _listenExclusivePanel(shortcutsOpenProvider, [
      preferencesOpenProvider,
      writeLogOpenProvider,
    ]);
    _listenExclusivePanel(writeLogOpenProvider, [
      preferencesOpenProvider,
      shortcutsOpenProvider,
    ]);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: components.AppShell(
              selectedIndex: destination.index,
              screenName: destination.name,
              hasBackAction: returnTo != null,
              onBack: () => consumeReturnTo(ref.read),
              isDegraded: isDegraded,
              degradedBuiltinVersion: degradedVersions?.builtinVersion,
              degradedProjectVersion: degradedVersions?.projectVersion,
              inferredVersion: inferredVersion,
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
              bottomItems: [
                components.NavItem.action(
                  icon: const components.AppIcon(icon: Icons.settings_outlined),
                  label: l10n.sidebarSettingsLabel,
                  focusNode: _preferencesItemFocus,
                  onTap: () => _openPreferences(_preferencesItemFocus),
                  testKey: const Key('nav-action-preferences'),
                ),
                components.NavItem.action(
                  icon: const components.AppIcon(icon: Icons.keyboard_outlined),
                  label: l10n.keyboardShortcutsTitle,
                  focusNode: _shortcutsItemFocus,
                  onTap: () => _openShortcuts(_shortcutsItemFocus),
                  testKey: const Key('nav-action-shortcuts'),
                ),
                components.NavItem.action(
                  icon: const components.AppIcon(icon: Icons.edit_note),
                  label: l10n.writeLogTitle,
                  focusNode: _writeLogItemFocus,
                  onTap: () => _openWriteLog(_writeLogItemFocus),
                  testKey: const Key('nav-action-writeLog'),
                  badge: failureCount == 0
                      ? null
                      : components.Badge.count(
                          key: const Key('badge-writeLog-failure-count'),
                          count: failureCount,
                          inline: true,
                        ),
                ),
              ],
              pages: [
                for (final item in AppDestination.values)
                  components.PageColumn(
                    semanticLabel: item.label(l10n),
                    header: components.SplitRow.header(
                      leading: components.PageTitle(title: item.label(l10n)),
                      // 四個目的地已接線頁首右格內容（`SegmentedControl` 矩陣／
                      // 泳道切換、Ticket 清單主題切換、破洞報告重新掃描、節點
                      // 詳情開啟原始檔，SPEC-004 §3.6 §1／§4／§5／§6 表、§3.7
                      // 第 17、18 項）；泳道與追溯視圖 trailing 仍為 null，渲染
                      // 不受影響。
                      trailing: switch (item) {
                        AppDestination.domain => const DomainHeaderTrailing(),
                        AppDestination.tickets => const TicketsHeaderTrailing(),
                        AppDestination.gaps => const GapReportHeaderTrailing(),
                        AppDestination.nodeDetail =>
                          const NodeDetailHeaderTrailing(),
                        _ => null,
                      },
                    ),
                    content: buildDestinationPage(context, item),
                  ),
              ],
              overlay: isSwitcherOpen
                  ? buildProjectSwitcherOverlay(context: context, ref: ref)
                  : null,
            ),
          ),
          if (isPreferencesOpen) const Center(child: PreferencesPanel()),
          if (isShortcutsOpen) const Center(child: ShortcutsPanel()),
          if (isWriteLogOpen) const Center(child: WriteLogPanel()),
        ],
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
  AppDestination.history => Icons.history_outlined,
};
