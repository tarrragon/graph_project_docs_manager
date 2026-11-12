/// [SPEC-006 FR-11 規則 1] 監看實例的獨立 provider（0.6.0-W1-080，批 B9）。
///
/// 就緒閘門由輪次擁有者（scanRound）讀取，監看控制器（corpusWatch）也讀
/// 同一個實例；獨立成檔避免兩者互相依賴。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/corpus/corpus_log_event.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/services/directory_watch_source.dart';
import 'package:graph_project_docs_manager/services/file_watch_canary_io.dart';

/// 監看事件來源；測試覆寫為假來源。
final watchSourceProvider = Provider<WatchSource>(
  (ref) => DirectoryWatchSource(),
);

class _TimerHandle implements DebounceTimer {
  _TimerHandle(this._timer);
  final Timer _timer;
  @override
  void cancel() => _timer.cancel();
}

class _RealDebounceClock implements DebounceClock {
  const _RealDebounceClock();
  @override
  DebounceTimer schedule(Duration delay, void Function() callback) =>
      _TimerHandle(Timer(delay, callback));
}

/// 存活檢查的檔案操作；測試覆寫為假實作。
final watchCanaryIoProvider = Provider<WatchCanaryIo>(
  (ref) => FileWatchCanaryIo(),
);

/// 去抖與就緒逾時共用的時鐘；測試覆寫為手動時鐘。
final watchClockProvider = Provider<DebounceClock>(
  (ref) => const _RealDebounceClock(),
);

/// 監看變動的接收端；由監看控制器掛上排程，未掛上前變動被忽略。
class WatchChangedSink {
  void Function()? listener;
}

final watchChangedSinkProvider = Provider<WatchChangedSink>(
  (ref) => WatchChangedSink(),
);

/// 工作區監看實例（唯一）。
final corpusWatcherProvider = Provider<CorpusWatcher>((ref) {
  final watcher = CorpusWatcher(
    source: ref.read(watchSourceProvider),
    clock: ref.read(watchClockProvider),
    canaryIo: ref.read(watchCanaryIoProvider),
    onChanged: (_) => ref.read(watchChangedSinkProvider).listener?.call(),
    log: defaultCorpusWatchLogSink,
  );
  ref.onDispose(() => unawaited(watcher.stop()));
  return watcher;
});
