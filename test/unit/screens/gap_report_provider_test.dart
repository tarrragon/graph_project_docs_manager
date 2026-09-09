// 破洞掃描完成時機測試（0.1.0-W3-096）。
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
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/tokens/motion.dart';

import '../../helpers/helpers.dart';

void main() {
  group('掃描完成時機（SPEC-003 §2.6 最短顯示時間適用）', () {
    testWidgets(
      'build() 後：Motion.spinnerMinVisible 內完成態不出現，'
      '轉換序列中確實觀測到 state-gaps-scanning',
      (tester) async {
        final container = await pumpHarness(
          tester,
          child: const SizedBox.shrink(),
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
  });
}
