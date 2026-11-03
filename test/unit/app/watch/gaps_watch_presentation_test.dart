/// SPEC-006 FR-11 規則 9（W4、D3）與規則 8（D2）的破洞報告呈現狀態
/// （SPEC-003 §3.5〈生命週期〉、SPEC-001 §5；0.6.0-W1-080 Phase 2 紅燈）。
///
/// 驗證狀態層；`state-gaps-scanning` 錨點與 widget 佈線由 Phase 3b 實作時
/// 於 widget 測試補驗。Phase 3b 待補 stub：`lib/app/gaps_watch_presentation.dart`。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/gaps_watch_presentation.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';

const _old = {'gap-a'};
const _new = {'gap-a', 'gap-b'};

GapsWatchPresentation _withResult() {
  final p = GapsWatchPresentation()..onRoundStarted(ScanTrigger.manual);
  p.onRoundCompleted(ScanTrigger.manual, _old, rerunPending: false);
  return p;
}

void main() {
  group('W4：監看輪次保留舊結果', () {
    test('監看輪次進行中不轉 scanning，仍顯示舊結果；完成後直接替換', () {
      final p = _withResult()..onRoundStarted(ScanTrigger.watch);
      expect(p.isScanning, isFalse);
      expect(p.shownItemIds, _old);
      p.onRoundCompleted(ScanTrigger.watch, _new, rerunPending: false);
      expect(p.shownItemIds, _new);
    });

    test('對照：手動輪次進行中轉 scanning', () {
      final p = _withResult()..onRoundStarted(ScanTrigger.manual);
      expect(p.isScanning, isTrue);
    });
  });

  group('D2：監看輪次中按 action-gaps-rescan', () {
    test('立即轉 scanning；當輪完成仍 scanning，接續一輪完成才轉結果', () {
      final p = _withResult()..onRoundStarted(ScanTrigger.watch);
      p.onManualRescanRequested();
      expect(p.isScanning, isTrue);

      p.onRoundCompleted(ScanTrigger.watch, _new, rerunPending: true);
      expect(p.isScanning, isTrue, reason: '兩輪皆完成才轉結果');

      p.onRoundStarted(ScanTrigger.manual);
      p.onRoundCompleted(ScanTrigger.manual, {'gap-c'}, rerunPending: false);
      expect(p.isScanning, isFalse);
      expect(p.shownItemIds, {'gap-c'});
    });

    test('取消 → 離開 scanning', () {
      final p = _withResult()..onRoundStarted(ScanTrigger.watch);
      p.onManualRescanRequested();
      p.onCancelled();
      expect(p.isScanning, isFalse);
    });
  });

  group('D3：無既有結果時的監看輪次', () {
    test('監看輪次完成的結果算既有結果，之後可見不自動掃描', () {
      final p = GapsWatchPresentation()..onRoundStarted(ScanTrigger.watch);
      p.onRoundCompleted(ScanTrigger.watch, _new, rerunPending: false);
      expect(p.shownItemIds, _new);
      expect(p.shouldAutoScanOnVisible, isFalse);
    });

    test('對照：從未有結果時可見須自動掃描', () {
      expect(GapsWatchPresentation().shouldAutoScanOnVisible, isTrue);
    });

    test('上一輪被取消（無既有結果）後監看輪次完成，同樣不自動掃描', () {
      final p = GapsWatchPresentation()..onRoundStarted(ScanTrigger.manual);
      p.onCancelled();
      expect(p.shouldAutoScanOnVisible, isTrue);
      p.onRoundStarted(ScanTrigger.watch);
      p.onRoundCompleted(ScanTrigger.watch, _old, rerunPending: false);
      expect(p.shouldAutoScanOnVisible, isFalse);
    });
  });
}
