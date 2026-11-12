/// SPEC-006 FR-11 規則 1、3、10、11：監看生命週期（0.6.0-W1-080 Phase 2 紅燈）。
///
/// 檔案事件經可注入的 [WatchSource] 餵入假事件；真實 FSEvents（`package:watcher`
/// `DirectoryWatcher`）交實機驗證（Phase 3b 之後由 PM `/verify`）。
/// Phase 3b 待補 stub：`lib/corpus/corpus_watch.dart` 的 [CorpusWatcher]。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';

import '../../../helpers/fake_watch_source.dart';
import '../../../helpers/manual_debounce_clock.dart';

const _warningLevel = 900;

class _LogEntry {
  _LogEntry(this.message, this.level);
  final String message;
  final int level;
}

void main() {
  late FakeWatchSource source;
  late ManualDebounceClock clock;
  late List<CorpusChangedEvent> events;
  late List<_LogEntry> logs;
  late CorpusWatcher watcher;

  setUp(() {
    source = FakeWatchSource();
    clock = ManualDebounceClock();
    events = <CorpusChangedEvent>[];
    logs = <_LogEntry>[];
    watcher = CorpusWatcher(
      source: source,
      clock: clock,
      onChanged: events.add,
      log: (event, fields, {level = LogLevel.info, source, error}) =>
          logs.add(_LogEntry(event.name, level.devLogLevel)),
    );
  });

  Future<void> emit(String root, WatchChange c) async {
    source.controllers[root]!.add(c);
    await Future<void>.delayed(Duration.zero);
  }

  group('FR-11 規則 3 過濾接線', () {
    test('驗收 2：只改 .swp／.MD／.DS_Store 不發 EVT-CORPUS-002', () async {
      await watcher.start('/ws');
      await emit(
        '/ws',
        const WatchChange('docs/a.swp', WatchChangeKind.modified),
      );
      await emit(
        '/ws',
        const WatchChange('docs/a.MD', WatchChangeKind.modified),
      );
      await emit(
        '/ws',
        const WatchChange('docs/.DS_Store', WatchChangeKind.modified),
      );
      clock.advance(watchMaxWait);
      expect(events, isEmpty);
    });

    test('驗收 2 正向對照：同 fixture 改 .md 發出一筆', () async {
      await watcher.start('/ws');
      await emit(
        '/ws',
        const WatchChange('docs/a.md', WatchChangeKind.modified),
      );
      clock.advance(watchMaxWait);
      expect(events, hasLength(1));
      expect(events.single.changes.single.relativePath, 'docs/a.md');
    });
  });

  group('FR-11 規則 1 生命週期', () {
    test('start 後 isWatching 為真，並記 info 建立日誌', () async {
      await watcher.start('/ws');
      expect(watcher.isWatching, isTrue);
      expect(logs.where((l) => l.level < _warningLevel), isNotEmpty);
    });

    test('驗收 9：切換專案後舊專案變動不發事件；新專案變動照發（對照）', () async {
      await watcher.start('/old');
      await watcher.stop();
      await watcher.start('/new');
      expect(source.controllers['/old']!.hasListener, isFalse);

      source.controllers['/old']!.add(
        const WatchChange('docs/a.md', WatchChangeKind.modified),
      );
      await Future<void>.delayed(Duration.zero);
      clock.advance(watchMaxWait);
      expect(events, isEmpty);

      await emit(
        '/new',
        const WatchChange('docs/a.md', WatchChangeKind.modified),
      );
      clock.advance(watchMaxWait);
      expect(events, hasLength(1));
    });
  });

  group('FR-11 規則 10 失敗降級', () {
    test('驗收 8：串流回報錯誤 → 一筆 warning、停止監看、不再送事件', () async {
      await watcher.start('/ws');
      source.controllers['/ws']!.addError(const FileSystemWatchFailure());
      await Future<void>.delayed(Duration.zero);

      final warnings = logs.where((l) => l.level >= _warningLevel).toList();
      expect(warnings, hasLength(1));
      expect(warnings.single.message, 'watchFailed');
      expect(watcher.isWatching, isFalse);
    });

    test('串流非預期結束 → 一筆 warning、停止監看', () async {
      await watcher.start('/ws');
      await source.controllers['/ws']!.close();
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.level >= _warningLevel), hasLength(1));
      expect(watcher.isWatching, isFalse);
    });

    test('對照：正常 stop 不寫 warning', () async {
      await watcher.start('/ws');
      await watcher.stop();
      expect(logs.where((l) => l.level >= _warningLevel), isEmpty);
    });
  });
}
