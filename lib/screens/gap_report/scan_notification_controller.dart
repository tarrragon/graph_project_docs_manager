/// 掃描完成系統層通知的觸發／撤回／導向邏輯（SPEC-003 §2.2）。
///
/// 純邏輯類別，不繼承任何 Riverpod 基底——由 `app/shell.dart` 的
/// `_AppShellState.initState` 建立一次並以 `ref.listenManual` 掛上三個
/// 監聽（掃描狀態、目前可見頁、生命週期）與一個 stream 訂閱
/// （[ScanNotifier.activated]），`dispose` 時一併清理。拆成獨立檔案
/// 而非塞進 `shell.dart`，讓「決定要不要發通知」這件事可被靜態閱讀
/// 與未來獨立測試，不與導覽殼骨架程式碼混在一起。
library;

import 'dart:async' show unawaited;
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_lifecycle.dart';
import '../../app/attention_level.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../services/macos_scan_notifier.dart';
import '../../services/scan_notifier.dart';
import '../../services/scan_notifier_provider.dart';
import 'gap_report_models.dart';
import 'gap_report_provider.dart';

const String _tag = 'ScanNotificationController';

/// 點擊通知路徑的日誌事件前綴（SPEC-003 §2.2「點擊通知的導向」列）。
/// 事件依序為 `activated`、`navigate`、`locate-set`（或 `locate-skip`）、
/// `locate-scroll`、`locate-focus`。
const String clickPathLogPrefix = 'click-path:';

/// 點擊路徑日誌的輸出點；預設寫入 `developer.log`，測試可替換為記錄器
/// 以機械驗證事件順序（結束後須還原為 [defaultClickPathLogSink]）。
void Function(String message, String name) clickPathLogSink =
    defaultClickPathLogSink;

void defaultClickPathLogSink(String message, String name) =>
    developer.log(message, name: name); // i18n-exempt: 開發者診斷 log

/// 記錄一則點擊路徑事件。
void logClickPath(String event, String detail, String name) =>
    clickPathLogSink('$clickPathLogPrefix$event $detail', name);

/// 撤回通知的觸發條件（SPEC-003 §2.2「可觀測性」列）。
enum WithdrawTrigger { destination, lifecycle, rescan, projectSwitch }

/// 撤回日誌前綴；事件格式為 `withdraw-trigger:<條件名>`。
const String withdrawLogPrefix = 'withdraw-trigger:';

/// 撤回觸發日誌的輸出點；預設寫入 `developer.log`，測試可替換為記錄器
/// 斷言四值（結束後須還原為 [defaultWithdrawLogSink]）。
void Function(String message, String name) withdrawLogSink =
    defaultWithdrawLogSink;

void defaultWithdrawLogSink(String message, String name) =>
    developer.log(message, name: name); // i18n-exempt: 開發者診斷 log

/// 命中時定位到的破洞項 id（SPEC-004 §1 locate 列）；`null` 表示無待定位
/// 項。[GapReportScreen] 消費本值捲動並移入焦點後，清空回 `null`。
final pendingLocateGapItemProvider = StateProvider<String?>((ref) => null);

class ScanNotificationController {
  ScanNotificationController(this._ref, this._contextProvider);

  /// 來源恆為 `ConsumerState.ref`（`WidgetRef`）：`listenManual` 僅在
  /// `WidgetRef` 上提供，用於 `initState`／`dispose` 情境（riverpod 2.x）。
  final WidgetRef _ref;

  /// 讀取目前 `AppShell` 的 `BuildContext`（供 [AppSnackBar.show] 使用）。
  /// `AppShell` 是應用程式常駐殼，呼叫時機皆在其掛載期間內。
  final BuildContext Function() _contextProvider;

  /// 已透過系統通知 `show()` 成功發送、尚未被撤回的完成狀態；`null`
  /// 表示無待撤回的系統通知。
  GapReportState? _pendingWithdrawableState;

  /// `denied` fallback 待 `resumed` 後顯示的通知內容；`null` 表示無待顯示
  /// 的 SnackBar（已顯示過、或使用者已自行進入 `nav-page-gaps`）。
  ScanCompleteNotification? _pendingDeniedNotification;

  late final ProviderSubscription<GapReportState> _gapReportSubscription;
  late final ProviderSubscription<AppDestination> _destinationSubscription;
  late final ProviderSubscription<AppLifecycleState> _lifecycleSubscription;
  late final Stream<void> _activatedStream;
  void Function()? _cancelActivatedSubscription;

  /// 掛上所有監聽；`_AppShellState.initState` 呼叫一次。
  void start() {
    _gapReportSubscription = _ref.listenManual<GapReportState>(
      gapReportProvider,
      _onGapReportStateChange,
    );
    _destinationSubscription = _ref.listenManual<AppDestination>(
      selectedDestinationProvider,
      _onDestinationChange,
    );
    _lifecycleSubscription = _ref.listenManual<AppLifecycleState>(
      appLifecycleStateProvider,
      _onLifecycleChange,
    );
    final notifier = _ref.read(scanNotifierProvider);
    _activatedStream = notifier.activated;
    final subscription = _activatedStream.listen(_onActivated);
    _cancelActivatedSubscription = subscription.cancel;
  }

  void dispose() {
    _gapReportSubscription.close();
    _destinationSubscription.close();
    _lifecycleSubscription.close();
    _cancelActivatedSubscription?.call();
  }

  /// 每次 build 由 `AppShell` 呼叫，確保 [MacosScanNotifier] 使用當前語系
  /// 的字串（`AppLocalizations` 需要 `BuildContext`，無法在 provider
  /// 建構時期一次性注入）。
  void syncLocalizedStrings(AppLocalizations l10n) {
    final notifier = _ref.read(scanNotifierProvider);
    if (notifier is MacosScanNotifier) {
      notifier.updateLocalizedStrings(
        title: () => l10n.scanCompleteNotificationTitle,
        foundBody: l10n.scanCompleteNotificationBody,
        noGapsBody: () => l10n.scanCompleteNoGapsNotificationBody,
      );
    }
  }

  void _onGapReportStateChange(GapReportState? previous, GapReportState next) {
    // 新一輪掃描開始：舊結果待汰換，撤回尚未被點擊的系統通知
    // （SPEC-003 §2.2「不重複發送」列「新一輪掃描開始」）。
    if (next is GapReportScanning && _pendingWithdrawableState != null) {
      _withdraw(WithdrawTrigger.rescan);
    }
    // 專案切換使圖重建而回到未就緒：舊專案的結果通知同樣失效。
    if (next is GapReportProjectUnready && _pendingWithdrawableState != null) {
      _withdraw(WithdrawTrigger.projectSwitch);
    }

    // 觸發條件僅「state-gaps-scanning 轉換至 state-gaps-none 或
    // state-gaps-found」；取消完成（isCancelling）不通知（§2.5 C5）。
    final cancelled = previous is GapReportScanning && previous.isCancelling;
    final completed = next is GapReportNoGaps || next is GapReportFound;
    if (previous is GapReportScanning && completed && !cancelled) {
      _evaluateCompletion(next);
    }
  }

  void _onDestinationChange(AppDestination? previous, AppDestination next) {
    if (next != AppDestination.gaps) return;
    // 使用者自行回到 nav-page-gaps：結果已被看見。
    _pendingDeniedNotification = null;
    if (_pendingWithdrawableState != null) {
      _withdraw(WithdrawTrigger.destination);
    }
  }

  void _onLifecycleChange(AppLifecycleState? previous, AppLifecycleState next) {
    if (next != AppLifecycleState.resumed) return;
    // 回到前景時可見頁已是 gaps：結果已被看見（SPEC-003 §2.2 時刻 ii）。
    if (_pendingWithdrawableState != null &&
        _ref.read(selectedDestinationProvider) == AppDestination.gaps) {
      _withdraw(WithdrawTrigger.lifecycle);
    }
    final pending = _pendingDeniedNotification;
    if (pending == null) return;
    // 回到前景前使用者已自行進入 nav-page-gaps：_onDestinationChange 已
    // 清空 _pendingDeniedNotification，這裡不會再看到非 null 值。
    _pendingDeniedNotification = null;
    _showDeniedSnackbar(pending);
  }

  int _gapCountOf(GapReportState state) => switch (state) {
    GapReportFound(:final categories) => categories.fold(
      0,
      (sum, category) => sum + category.items.length,
    ),
    GapReportNoGaps() => 0,
    GapReportScanning() => 0,
    GapReportProjectUnready() => 0,
  };

  bool _isVisibleForeground() {
    final lifecycle = _ref.read(appLifecycleStateProvider);
    final destination = _ref.read(selectedDestinationProvider);
    return lifecycle == AppLifecycleState.resumed &&
        destination == AppDestination.gaps;
  }

  Future<void> _evaluateCompletion(GapReportState completed) async {
    if (_isVisibleForeground()) {
      // 使用者正看著破洞報告：狀態轉換本身即結果，不升級。
      return;
    }
    final context = _contextProvider();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    syncLocalizedStrings(l10n);
    final notifier = _ref.read(scanNotifierProvider);
    final authorization = await notifier.authorizationStatus();
    final gapCount = _gapCountOf(completed);
    switch (authorization) {
      case NotificationAuthorization.granted:
        await _showOrFallback(notifier, gapCount, completed);
      case NotificationAuthorization.notDetermined:
        final requested = await notifier.requestAuthorization();
        if (requested == NotificationAuthorization.granted) {
          await _showOrFallback(notifier, gapCount, completed);
        } else {
          _fallbackToSnackbar(gapCount);
        }
      case NotificationAuthorization.denied:
        _fallbackToSnackbar(gapCount);
    }
  }

  /// 發送系統通知；`delivered` 才記為待撤回，`failed` 走與 `denied` 相同
  /// 的 SnackBar fallback（SPEC-003 §2.2 權限 gate「發送失敗」列）。
  Future<void> _showOrFallback(
    ScanNotifier notifier,
    int gapCount,
    GapReportState completed,
  ) async {
    final result = await notifier.show(
      ScanCompleteNotification(gapCount: gapCount),
    );
    if (result == ScanNotificationDelivery.delivered) {
      _pendingWithdrawableState = completed;
      return;
    }
    developer.log(
      '系統通知發送失敗（gapCount=$gapCount），改走 SnackBar fallback', // i18n-exempt: 開發者診斷 log
      name: _tag,
      level: 900,
    );
    _fallbackToSnackbar(gapCount);
  }

  /// `denied` fallback（SPEC-003 §2.2 權限 gate `denied` 列）：視窗在前景
  /// 且可見頁不是 `nav-page-gaps` → 立即顯示；視窗非前景 → 延後至
  /// `resumed`。
  void _fallbackToSnackbar(int gapCount) {
    final notification = ScanCompleteNotification(gapCount: gapCount);
    final lifecycle = _ref.read(appLifecycleStateProvider);
    if (lifecycle == AppLifecycleState.resumed) {
      _showDeniedSnackbar(notification);
    } else {
      _pendingDeniedNotification = notification;
    }
  }

  void _showDeniedSnackbar(ScanCompleteNotification notification) {
    final context = _contextProvider();
    if (!context.mounted) {
      developer.log(
        'SnackBar fallback 略過：context 已卸載', // i18n-exempt: 開發者診斷 log
        name: _tag,
        level: 900,
      );
      return;
    }
    final l10n = AppLocalizations.of(context);
    final message = notification.gapCount == 0
        ? l10n.scanCompleteNoGapsSnackbarMessage
        : l10n.scanCompleteSnackbarMessage(notification.gapCount);
    AppSnackBar.show(
      context,
      message: message,
      level: AttentionLevel.discardable,
      variant: AppSnackBarVariant.withAction,
      actionLabel: l10n.viewGapsAction,
      actionTestKey: const Key('action-scan-complete-view-gaps'),
      onAction: () =>
          navigateTo(_ref.read, AppDestination.gaps, NavIntent.rail),
    );
  }

  void _withdraw(WithdrawTrigger trigger) {
    withdrawLogSink('$withdrawLogPrefix${trigger.name}', _tag);
    _pendingWithdrawableState = null;
    unawaited(_ref.read(scanNotifierProvider).withdraw());
  }

  /// 使用者點擊系統通知本體（SPEC-003 §2.2「點擊通知的導向」列）。
  void _onActivated(void _) {
    final state = _ref.read(gapReportProvider);
    logClickPath('activated', 'state=${state.runtimeType}', _tag);
    _pendingWithdrawableState = null;
    navigateTo(_ref.read, AppDestination.gaps, NavIntent.rail);
    logClickPath(
      'navigate',
      'destination=${_ref.read(selectedDestinationProvider).name} '
          'returnTo=${_ref.read(returnToProvider)}',
      _tag,
    );
    if (state is GapReportFound &&
        state.categories.isNotEmpty &&
        state.categories.first.items.isNotEmpty) {
      final itemId = state.categories.first.items.first.id;
      _ref.read(pendingLocateGapItemProvider.notifier).state = itemId;
      logClickPath('locate-set', 'itemId=$itemId', _tag);
    } else {
      logClickPath('locate-skip', 'state=${state.runtimeType}', _tag);
    }
    // 若專案已切換或已進入新一輪掃描，`gapReportProvider` 讀到的已非原本
    // 完成結果（`GapReportScanning` 或已重置），上式的型別檢查天然只在
    // 仍是 `GapReportFound` 時定位，符合「只切頁、不定位」列。
  }
}
