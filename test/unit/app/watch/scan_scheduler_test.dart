/// SPEC-006 FR-11 規則 7、8（含 D2 取消）：共用掃描排程（0.6.0-W1-080 Phase 2 紅燈）。
///
/// 每輪以 [Completer] 控制完成時點，不用真實計時。
/// Phase 3b 待補 stub：`lib/app/scan_scheduler.dart` 的 [ScanScheduler]。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';

void main() {
  late List<ScanTrigger> started;
  late List<Completer<void>> rounds;
  late int clearCalls;
  late ScanScheduler scheduler;

  setUp(() {
    started = <ScanTrigger>[];
    rounds = <Completer<void>>[];
    clearCalls = 0;
    scheduler = ScanScheduler(
      runRound: (t) {
        started.add(t);
        final c = Completer<void>();
        rounds.add(c);
        return c.future;
      },
      clearPendingWatchEvents: () => clearCalls++,
    );
  });

  Future<void> finishRound(int i) async {
    rounds[i].complete();
    await Future<void>.delayed(Duration.zero);
  }

  test('驗收 6：進行中收到三筆監看事件 → 當輪不中止，完成後恰好再跑一輪', () async {
    scheduler.request(ScanTrigger.watch);
    scheduler
      ..request(ScanTrigger.watch)
      ..request(ScanTrigger.watch)
      ..request(ScanTrigger.watch);
    expect(started, hasLength(1), reason: '不並行第二輪');
    expect(scheduler.hasPendingRerun, isTrue);

    await finishRound(0);
    expect(started, hasLength(2));
    await finishRound(1);
    expect(started, hasLength(2), reason: '多筆只重跑一輪');
    expect(scheduler.isRunning, isFalse);
  });

  test('對照：閒置時一筆請求立即開跑一輪，無待重跑', () async {
    scheduler.request(ScanTrigger.watch);
    expect(started, [ScanTrigger.watch]);
    expect(scheduler.hasPendingRerun, isFalse);
  });

  test('驗收 7：手動重掃立即開始並清空去抖累積', () {
    scheduler.request(ScanTrigger.manual);
    expect(started, [ScanTrigger.manual]);
    expect(clearCalls, 1);
  });

  test('對照：監看觸發不清空去抖累積', () {
    scheduler.request(ScanTrigger.watch);
    expect(clearCalls, 0);
  });

  test('規則 8（D2）：監看輪次中手動重掃 → 不中止、標記待重跑、完成後接續', () async {
    scheduler.request(ScanTrigger.watch);
    scheduler.request(ScanTrigger.manual);
    expect(started, [ScanTrigger.watch]);
    expect(scheduler.hasPendingRerun, isTrue);
    await finishRound(0);
    expect(started, [ScanTrigger.watch, ScanTrigger.manual]);
  });

  test('D2：取消 → 中止當輪並清除待重跑，不接續再跑', () async {
    scheduler.request(ScanTrigger.watch);
    scheduler.request(ScanTrigger.manual);
    scheduler.cancel();
    expect(scheduler.hasPendingRerun, isFalse);
    expect(scheduler.isRunning, isFalse);
    await finishRound(0);
    expect(started, hasLength(1));
  });

  test('規則 8：再次可見自動掃描共用排程，進行中同樣只標記待重跑', () {
    scheduler.request(ScanTrigger.watch);
    scheduler.request(ScanTrigger.visibility);
    expect(started, hasLength(1));
    expect(scheduler.hasPendingRerun, isTrue);
  });
}
