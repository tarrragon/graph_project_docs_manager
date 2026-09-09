// 破洞掃描「App 啟動路徑」通知閘門驗證（0.1.0-W3-096 後續，team-lead 要求）。
//
// 動機：`0.1.0-W3-096` 修復後，team-lead 的實機量測（`ncprefs` 條目數在
// App 啟動前後皆為 0）與 Problem Analysis 的原始碼推導（App 啟動當下
// `selectedDestinationProvider` 預設為 `domain`（≠ gaps），`_isVisibleForeground()`
// 應為 false，`_evaluateCompletion` 應呼叫 `authorizationStatus()`）出現矛盾。
// `w3-096-fix` 進一步指出：票面「結構性不可達」的前提可能只對 `rescan()`
// 路徑成立，App 啟動路徑是否同樣不可達需要驗證而非接受推論。
//
// 本檔不 override `gapReportProvider`（與 `scan_notification_controller_test.dart`
// 全數 override 為 `_ControllableGapReportNotifier` 不同），走真實
// `GapReportNotifier` + 真實 `ScanNotificationController`（經 `AppShell.initState`
// 掛載），只把 `scanNotifierProvider` 換成 `FakeScanNotifier` 攔截外部呼叫，
// 藉此觀察「監聽掛載順序」與「啟動路徑的觸發條件判定」在測試環境下的
// 實際行為，取代對原始碼的靜態推導。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/services/scan_notifier_provider.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';
import 'scan_notification_controller_test.dart' show FakeScanNotifier;

void main() {
  testWidgets(
    'App 啟動（不覆寫 gapReportProvider，預設可見頁 domain、視窗前景）：'
    '掃描完成時機一到，authorizationStatus 確實被呼叫一次',
    (tester) async {
      final fake = FakeScanNotifier();
      await pumpApp(
        tester,
        overrides: [scanNotifierProvider.overrideWithValue(fake)],
        settle: false,
      );

      // build() 剛完成：GapReportNotifier 進入 GapReportScanning，
      // _scheduleScan() 已排定但 Motion.spinnerMinVisible 尚未到期。
      expect(
        fake.authorizationStatusCalls,
        0,
        reason: '完成時機未到，不應提前呼叫',
      );

      await pumpContract(tester, Motion.spinnerMinVisible);
      await tester.pump();

      // 監聽附掛順序：ScanNotificationController.start() 於 AppShell.initState
      // 同步執行，其中 listenManual(gapReportProvider, ...) 這一行本身觸發
      // gapReportProvider 的首次 build()（排定延遲完成回呼）；監聽的註冊與
      // 這次 build() 屬同一次同步呼叫，回呼必然在 start() 返回之後才可能
      // 執行，故監聽在完成回呼觸發前必然已就緒——與計時器種類（原
      // Future.microtask、現 Future.delayed）無關。
      //
      // 可見頁判定：預設 selectedDestinationProvider 為 domain（≠ gaps），
      // appLifecycleStateProvider 預設 resumed，_isVisibleForeground() 應為
      // false，觸發條件 (b) 成立 → _evaluateCompletion 應呼叫
      // authorizationStatus()。
      expect(
        fake.authorizationStatusCalls,
        1,
        reason:
            'App 啟動路徑：監聽在完成回呼前已附掛，預設可見頁非 gaps，'
            '觸發條件 (b) 成立，authorizationStatus 應被呼叫一次。若此斷言'
            '失敗，代表啟動路徑存在另一個提前返回點，需另外定位（例如'
            ' context.mounted 判定、_pendingWithdrawableState 初值等）。',
      );
    },
  );
}
