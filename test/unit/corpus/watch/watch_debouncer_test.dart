/// SPEC-006 FR-11 規則 4、5：去抖與 EVT-CORPUS-002 負載（0.6.0-W1-080 Phase 2 紅燈）。
///
/// 以 [ManualDebounceClock] 推進虛擬時間，不用真實計時。
/// Phase 3b 待補 stub：`lib/corpus/corpus_watch.dart` 的 [WatchDebouncer]。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';

import '../../../helpers/manual_debounce_clock.dart';

const _ms100 = Duration(milliseconds: 100);
const _ms499 = Duration(milliseconds: 499);
const _ms1 = Duration(milliseconds: 1);

void main() {
  late ManualDebounceClock clock;
  late List<CorpusChangedEvent> flushed;
  late WatchDebouncer debouncer;

  setUp(() {
    clock = ManualDebounceClock();
    flushed = <CorpusChangedEvent>[];
    debouncer = WatchDebouncer(clock: clock, onFlush: flushed.add);
  });

  group('FR-11 規則 4 去抖', () {
    test('裁定值：靜默窗 500 ms、最長等待 3 s（W3）', () {
      expect(debouncer.quietWindow, watchQuietWindow);
      expect(watchQuietWindow, const Duration(milliseconds: 500));
      expect(watchMaxWait, const Duration(seconds: 3));
    });

    test('驗收 3：靜默窗內寫入 20 個 .md 只送出一筆，changes 含 20 筆', () {
      for (var i = 0; i < 20; i++) {
        debouncer.add(WatchChange('docs/f$i.md', WatchChangeKind.modified));
      }
      clock.advance(_ms499);
      expect(flushed, isEmpty, reason: '靜默窗未滿不得送出');
      clock.advance(_ms1);
      expect(flushed, hasLength(1));
      expect(flushed.single.changes, hasLength(20));
    });

    test('驗收 4：每 100 ms 一筆持續超過最長等待，不晚於 3 s 送出第一筆', () {
      // 對照：靜默窗從未滿足，只有最長等待能使其送出。
      Duration? firstFlushAt;
      final d = WatchDebouncer(
        clock: clock,
        onFlush: (e) {
          firstFlushAt ??= clock.now;
          flushed.add(e);
        },
      );
      for (var i = 0; i < 40; i++) {
        d.add(WatchChange('docs/f${i % 3}.md', WatchChangeKind.modified));
        clock.advance(_ms100);
      }
      expect(firstFlushAt, isNotNull);
      expect(firstFlushAt! <= watchMaxWait, isTrue);
    });
  });

  group('FR-11 規則 5 負載合併', () {
    test('同一路徑多次變動只保留最後一筆 kind', () {
      debouncer
        ..add(const WatchChange('docs/a.md', WatchChangeKind.modified))
        ..add(const WatchChange('docs/a.md', WatchChangeKind.deleted));
      clock.advance(watchQuietWindow);
      expect(flushed.single.changes, [
        const WatchChange('docs/a.md', WatchChangeKind.deleted),
      ]);
    });

    test('驗收 5：先建立後刪除整筆捨棄，另一路徑仍保留（對照）', () {
      debouncer
        ..add(const WatchChange('docs/tmp.md', WatchChangeKind.created))
        ..add(const WatchChange('docs/tmp.md', WatchChangeKind.deleted))
        ..add(const WatchChange('docs/b.md', WatchChangeKind.modified));
      clock.advance(watchQuietWindow);
      expect(flushed.single.changes, [
        const WatchChange('docs/b.md', WatchChangeKind.modified),
      ]);
    });

    test('驗收 5：清單因此為空時不發事件', () {
      debouncer
        ..add(const WatchChange('docs/tmp.md', WatchChangeKind.created))
        ..add(const WatchChange('docs/tmp.md', WatchChangeKind.deleted));
      clock.advance(watchMaxWait);
      expect(flushed, isEmpty);
    });
  });

  group('FR-11 規則 8 清空累積', () {
    test('clearPending 後窗結束不送出；未清空的對照會送出', () {
      debouncer.add(const WatchChange('docs/a.md', WatchChangeKind.modified));
      debouncer.clearPending();
      clock.advance(watchMaxWait);
      expect(flushed, isEmpty);

      debouncer.add(const WatchChange('docs/a.md', WatchChangeKind.modified));
      clock.advance(watchMaxWait);
      expect(flushed, hasLength(1));
    });
  });
}
