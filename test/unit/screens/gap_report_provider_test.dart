// 破洞掃描完成時機測試（0.1.0-W3-096；觸發時機於 0.3.1-W3-122 改為消費
// firstVisibleProvider）。
//
// `gap_report_test.dart` 與 `scan_notification_controller_test.dart` 皆以
// `gapReportProvider.overrideWith` 注入替身，刻意繞過真實完成時機（見兩檔
// 檔頭說明）——這正是本票 why 段指出的測試盲區：沒有任何測試讓正式的
// `GapReportNotifier` 參與，`_scheduleScan()` 曾以 `Future.microtask` 在
// 同一 microtask 內完成，使 `state-gaps-scanning` 骨架與 SPEC-003 §2.2
// 系統通知的觸發條件皆無法被觀測到，卻沒有任何測試能察覺。
//
// 本檔反向操作：保留正式 `GapReportNotifier`（不 override），斷言完成
// 時機依 SPEC-003 §2.6「最短顯示時間適用」規則，在轉換序列中確實先觀測到
// `GapReportScanning`，而非僅斷言最終態。
//
// 0.3.1-W3-122：掃描觸發改掛在「首次可見 nav-page-gaps」而非 build()
// 本身，故本檔全數 override `selectedDestinationProvider` 為
// `AppDestination.gaps`，模擬使用者已在破洞報告頁的前提（本檔關注的是
// 「掃描一旦被觸發後」的完成時機序列，不是觸發時機本身——後者由
// `gap_report_startup_notification_test.dart` 專責覆蓋）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';

/// 本檔共用：模擬使用者已在破洞報告頁，使 `firstVisibleProvider(gaps)`
/// 於 build() 首次讀取時為 `true`。
final _onGapsPage = [
  selectedDestinationProvider.overrideWith((ref) => AppDestination.gaps),
];

/// 可於測試中動態切換的 `projectUnreadyReasonProvider` 替身（0.3.1-W3-122 補測：
/// 圖建立狀態 true→false→true 往返）。`projectUnreadyReasonProvider` 本身是
/// `Provider<bool>`（不可變），改以 override 間接綁定到一個
/// `StateProvider`，測試才能在同一 `ProviderContainer` 生命週期內改變它。
final _graphBuiltState = StateProvider<ProjectUnreadyReason?>((ref) => null);

void main() {
  group('掃描完成時機（SPEC-003 §2.6 最短顯示時間適用）', () {
    testWidgets(
      'build() 後：Motion.spinnerMinVisible 內完成態不出現，'
      '轉換序列中確實觀測到 state-gaps-scanning',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const SizedBox.shrink(),
          overrides: _onGapsPage,
        );
        final observed = <GapReportState>[];
        container.listen<GapReportState>(
          gapReportProvider,
          (previous, next) => observed.add(next),
          fireImmediately: true,
        );

        // build() 剛完成：立即觀測到掃描中，這是修復前也成立的一半。
        expect(observed.single, isA<GapReportScanning>());

        // 修復前的缺陷：Future.microtask 會在下一次 pump 就把狀態推進到
        // 完成態，使骨架的存活時間短於一幀。這裡推進一次不足額的時間，
        // 斷言完成態依然不出現。
        await tester.pump(Motion.spinnerMinVisible - const Duration(milliseconds: 1));
        expect(
          observed.map((s) => s.runtimeType),
          everyElement(GapReportScanning),
          reason:
              '掃描完成不應早於 Motion.spinnerMinVisible，否則骨架不可能被'
              '使用者觀測到（SPEC-003 §2.6）',
        );

        // 推滿契約時長：完成態才出現。
        await tester.pump(const Duration(milliseconds: 1));
        expect(observed.last, isA<GapReportFound>());
      },
    );

    testWidgets('rescan()：重新排程後同樣先經過可觀測的 state-gaps-scanning', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: _onGapsPage,
      );
      // 強制建構（觸發 build() 排定首次掃描），再讓它先完成，回到穩定的
      // 結果態——若在此之前先推進假時鐘，provider 尚未建構、計時器根本
      // 還沒排定，pump 會落空。
      container.read(gapReportProvider.notifier);
      await pumpContract(tester, Motion.spinnerMinVisible);
      expect(container.read(gapReportProvider), isA<GapReportFound>());

      final observed = <GapReportState>[];
      container.listen<GapReportState>(
        gapReportProvider,
        (previous, next) => observed.add(next),
      );

      container.read(gapReportProvider.notifier).rescan();

      // rescan() 同步把狀態設回掃描中，監聽器應立即收到，不需等待 pump。
      expect(observed.single, isA<GapReportScanning>());

      await tester.pump(Motion.spinnerMinVisible - const Duration(milliseconds: 1));
      expect(
        observed.map((s) => s.runtimeType),
        everyElement(GapReportScanning),
        reason: '重新掃描的完成時機同樣受 Motion.spinnerMinVisible 約束',
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(observed.last, isA<GapReportFound>());
    });

    testWidgets(
      '快速連續 rescan()：只有最新一輪完成，較舊一輪的延遲回呼不覆蓋結果',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const SizedBox.shrink(),
          overrides: _onGapsPage,
        );
        final notifier = container.read(gapReportProvider.notifier);
        await pumpContract(tester, Motion.spinnerMinVisible);
        expect(container.read(gapReportProvider), isA<GapReportFound>());

        notifier.rescan();
        // 在第一輪完成前再次 rescan：第一輪的延遲回呼觸發時世代號已過期。
        await tester.pump(const Duration(milliseconds: 50));
        notifier.rescan();

        await pumpContract(tester, Motion.spinnerMinVisible);

        expect(
          container.read(gapReportProvider),
          isA<GapReportFound>(),
          reason: '較新一輪掃描應正常完成，未被較舊一輪的過期回呼卡住',
        );
      },
    );

    testWidgets('掃描中按下取消：延遲完成回呼不覆蓋 isCancelling 狀態', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const SizedBox.shrink(),
        overrides: _onGapsPage,
      );
      final notifier = container.read(gapReportProvider.notifier);
      // build() 已排程掃描（尚未完成，Motion.spinnerMinVisible 內）。
      notifier.cancelScan();

      await pumpContract(tester, Motion.spinnerMinVisible);
      await tester.pump();

      final state = container.read(gapReportProvider);
      expect(state, isA<GapReportScanning>());
      expect((state as GapReportScanning).isCancelling, isTrue);

      // 排乾 cancelScan() 自身的 Motion.cancelDeadline 計時器（相對
      // cancelScan() 呼叫當下起算，此時虛擬時鐘已在
      // Motion.spinnerMinVisible，還差一截才到 500 ms），避免測試結束時
      // 仍有 pending timer 觸發 flutter_test 的不變量檢查失敗。
      await tester.pump(Motion.cancelDeadline);
    });

    testWidgets(
      'projectUnreadyReasonProvider 由 null→非 null→null 往返：已觸發過掃描的結果'
      '在圖重建後恢復，不卡在「圖未建立」骨架、不重新掃描',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const SizedBox.shrink(),
          overrides: [
            ..._onGapsPage,
            projectUnreadyReasonProvider.overrideWith(
              (ref) => ref.watch(_graphBuiltState),
            ),
          ],
        );
        // 強制建構（觸發 build()）：pumpHarness 只渲染 SizedBox.shrink()，
        // 沒有任何 widget 真正 watch gapReportProvider。
        container.read(gapReportProvider.notifier);

        // 首次可見 + 圖已建立：正常觸發掃描並完成。
        await pumpContract(tester, Motion.spinnerMinVisible);
        expect(container.read(gapReportProvider), isA<GapReportFound>());

        // 圖被移除（例如切換專案途中）：渲染「專案未就緒」，不覆寫已完成
        // 的掃描結果內部記錄。
        container.read(_graphBuiltState.notifier).state = ProjectUnreadyReason.notSelected;
        await tester.pump();
        expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());

        // 圖重新建立：因 firstVisibleProvider(gaps) 早已於首次觸發時標記
        // 為已見，不會重新排程掃描（不需再等 Motion.spinnerMinVisible），
        // 應立即恢復先前完成的掃描結果，而非停留在「專案未就緒」。
        container.read(_graphBuiltState.notifier).state = null;
        await tester.pump();
        expect(
          container.read(gapReportProvider),
          isA<GapReportFound>(),
          reason:
              '圖重建後應恢復已觸發過掃描的最新結果（_lastResult），'
              '不應卡在圖未建立分支寫入的佔位狀態',
        );
      },
    );

    testWidgets(
      '首次可見時圖尚未建立，之後圖才建立：仍能正確觸發首次掃描'
      '（不因未建立期間被視為已訪問而卡住）',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const SizedBox.shrink(),
          overrides: [
            ..._onGapsPage,
            projectUnreadyReasonProvider.overrideWith(
              (ref) => ref.watch(_graphBuiltState),
            ),
          ],
        );
        // 覆寫為 false 須在 gapReportProvider 首次建構前完成，否則
        // `_graphBuiltState` 預設值 null 會使下一行的強制建構直接命中
        // 「圖已建立」分支，觸發掃描，汙染本測試意圖驗證的情境。
        container.read(_graphBuiltState.notifier).state = ProjectUnreadyReason.notSelected;
        // 強制建構（觸發 build()）：pumpHarness 只渲染 SizedBox.shrink()，
        // 沒有任何 widget 真正 watch gapReportProvider。
        container.read(gapReportProvider.notifier);
        await tester.pump();
        expect(container.read(gapReportProvider), isA<GapReportProjectUnready>());

        // 圖建立完成：即使先前處於「圖未建立」分支（該分支不 watch
        // firstVisibleProvider），此時應重新判定 isFirstVisible 為 true
        // 並正確觸發掃描。riverpod 對無活躍監聽者的 provider 採惰性重算，
        // 狀態變更本身不會立即重跑 build()；先強制讀取一次使
        // `_scheduleScan()` 在虛擬時鐘推進前就排定，pumpContract 才量得到
        // 完整的 Motion.spinnerMinVisible 契約時長。
        container.read(_graphBuiltState.notifier).state = null;
        container.read(gapReportProvider.notifier);
        await pumpContract(tester, Motion.spinnerMinVisible);
        expect(
          container.read(gapReportProvider),
          isA<GapReportFound>(),
          reason: '圖建立完成後應正確觸發首次掃描，不因未建立期間跳過而卡住',
        );
      },
    );
  });
}
