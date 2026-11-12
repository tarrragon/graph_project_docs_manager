/// SPEC-010 test-design O4-5：監看來源連續送出 3 個檔案事件，逐檔事件皆 debug。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_log_event.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import '../../../helpers/fake_watch_source.dart';
import '../../../helpers/manual_debounce_clock.dart';
import '../../../helpers/recording_log_sink.dart';

void main() {
  late FakeWatchSource source;
  late ManualDebounceClock clock;
  late RecordingLogSink<CorpusWatchLogEvent> recorder;
  late CorpusWatcher watcher;

  setUp(() {
    source = FakeWatchSource();
    clock = ManualDebounceClock();
    recorder = RecordingLogSink<CorpusWatchLogEvent>();
    watcher = CorpusWatcher(
      source: source,
      clock: clock,
      onChanged: (_) {},
      log: recorder.sink,
    );
  });

  Future<void> emitThree() async {
    await watcher.start('/ws');
    recorder.entries.clear(); // 只觀測檔案事件，生命週期記錄不在判定範圍
    for (final name in ['a', 'b', 'c']) {
      source.controllers['/ws']!.add(
        WatchChange('docs/$name.md', WatchChangeKind.modified),
      );
    }
    await Future<void>.delayed(Duration.zero);
    clock.advance(watchMaxWait);
  }

  group('O4-5 監看路徑逐檔事件不以 info 以上逐筆記錄', () {
    test('3 個檔案事件：info 以上為 0 筆；逐檔 debug 記錄為 3 筆', () async {
      await emitThree();

      expect(
        isDebugOrSingleAggregate(recorder.entries, <CorpusWatchLogEvent>{}),
        isTrue,
      );
      final observed = recorder.ofEvent(CorpusWatchLogEvent.changeObserved);
      expect(observed, hasLength(3));
      expect(observed.every((e) => e.level == LogLevel.debug), isTrue);
      expect(
        recorder
            .ofEvent(CorpusWatchLogEvent.changesFlushed)
            .single
            .payload[CorpusWatchLogKeys.changeCount],
        3,
      );
    });

    test('正向對照：逐檔以 info 記錄 3 筆的輸入，判定函式判紅', () {
      final perFileInfo = RecordingLogSink<CorpusWatchLogEvent>();
      for (var i = 0; i < 3; i++) {
        perFileInfo.sink(CorpusWatchLogEvent.changeObserved, LogFields.empty);
      }

      expect(
        isDebugOrSingleAggregate(perFileInfo.entries, <CorpusWatchLogEvent>{}),
        isFalse,
      );
    });
  });
}
