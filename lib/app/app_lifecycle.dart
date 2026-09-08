/// App 生命週期狀態的 Riverpod 掛點（SPEC-003 §2.2 觸發條件 (a)）。
///
/// [WidgetsBindingObserver.didChangeAppLifecycleState] 只能掛在
/// widget 上，本 provider 只是承接該回調寫入的值，讓非 widget 的
/// controller（`scan_notification_controller.dart`）能以 `ref.watch`
/// 讀取，不需持有 `WidgetsBinding` 參照。寫入端見
/// `app/shell.dart`（`AppShell` 已是應用程式的常駐殼，掛載 observer
/// 於此不需額外的殼層 widget）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 目前的 [AppLifecycleState]。初值 `resumed`：App 啟動當下即在前景，
/// 與 [WidgetsBinding] 的預設假設一致。
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);
