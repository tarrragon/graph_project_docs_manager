// 破洞掃描「App 啟動路徑」通知閘門驗證（0.1.0-W3-096 後續，team-lead 要求；
// 觸發時機於 0.3.1-W3-122 修復）。
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
//
// `0.3.1-W3-122` 修復前，本檔曾以此組態斷言「掃描完成時機一到，
// authorizationStatus 確實被呼叫一次」，並確實觀測到綠燈——即
// `GapReportNotifier.build()` 掛在 App 啟動路徑（`ScanNotificationController
// .start()` 的 `listenManual` 觸發首次 build()），與 SPEC-003 §2.2 觸發條件
// (b)（可見頁非 `nav-page-gaps`）在啟動當下即成立，使通知在使用者尚未看過
// 破洞報告頁前就發送——這正是本票 why 段記載的缺陷。修復後掃描改為消費
// `firstVisibleProvider(AppDestination.gaps)`，App 啟動當下預設可見頁為
// `domain`，掃描不會被觸發，下方斷言即為此修復的鑑別證據：若觸發時機退回
// build()（原缺陷），本斷言會翻紅（`authorizationStatusCalls` 變為 1）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/services/scan_notifier_provider.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';
import 'scan_notification_controller_test.dart' show FakeScanNotifier;

void main() {
  testWidgets(
    'App 啟動（不覆寫 gapReportProvider，預設可見頁 domain、視窗前景）：'
    '掃描不因啟動路徑觸發，authorizationStatus 全程未被呼叫',
    (tester) async {
      final fake = FakeScanNotifier();
      await pumpApp(
        tester,
        overrides: [scanNotifierProvider.overrideWithValue(fake)],
        settle: false,
      );

      // build() 剛完成：預設可見頁為 domain（≠ gaps），
      // firstVisibleProvider(gaps) 為 false，掃描不應被排程。
      expect(
        fake.authorizationStatusCalls,
        0,
        reason: '啟動當下可見頁非 gaps，掃描不應被觸發',
      );

      await pumpContract(tester, Motion.spinnerMinVisible);
      await tester.pump();

      // 鑑別證據（E1）：即使時間推進超過 Motion.spinnerMinVisible（修復前
      // 掃描完成、觸發通知評估的時間點），authorizationStatus 仍應維持
      // 0 次——因為掃描從未被排程。若觸發時機退回 build()（本票修復前的
      // 行為），本斷言會翻紅為 1。
      expect(
        fake.authorizationStatusCalls,
        0,
        reason:
            'App 啟動路徑修復後：掃描觸發改掛在首次可見 nav-page-gaps，'
            '啟動當下使用者未曾造訪該頁，authorizationStatus 應全程為 0。'
            '若此斷言翻紅為 1，代表觸發時機退回了 build()（0.3.1-W3-122 '
            '修復前的缺陷行為）。',
      );
    },
  );
}
