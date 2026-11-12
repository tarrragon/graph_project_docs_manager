/// 0.6.0-W1-141.2.2：FR-11 規則 10 就緒後存活檢查（金絲雀）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';

import '../../../helpers/fake_watch_source.dart';
import '../../../helpers/manual_debounce_clock.dart';

const _warningLevel = 900;
const _infoLevel = 800;
const _canary = 'docs/.gpdm-watch-canary-abc.tmp';
const _oldCanary = 'docs/.gpdm-watch-canary-old.tmp';

class _FakeIo implements WatchCanaryIo {
  List<String> residue = [];
  final Set<String> files = {};
  final List<String> deleted = [];
  bool writable = true;
  bool deleteFails = false;
  bool residueDeleteFails = false;

  @override
  List<String> residualCanaries(String r) => List.of(residue);
  @override
  String newCanaryPath() => _canary;
  @override
  void write(String r, String path) {
    if (!writable) throw const FileSystemWatchFailure();
    files.add(path);
  }

  @override
  void delete(String r, String path) {
    if (path == _canary ? deleteFails : residueDeleteFails) {
      throw const FileSystemWatchFailure();
    }
    files.remove(path);
    deleted.add(path);
  }
}

void main() {
  late FakeWatchSource source;
  late _FakeIo io;
  late ManualDebounceClock clock;
  late List<(String, int)> logs;
  late List<CorpusChangedEvent> events;
  late CorpusWatcher watcher;

  int count(int level) => logs.where((l) => l.$2 == level).length;

  Future<void> startWatching() async {
    await watcher.start('/ws');
    await pumpEventQueue();
  }

  setUp(() {
    source = FakeWatchSource();
    io = _FakeIo();
    clock = ManualDebounceClock();
    logs = [];
    events = [];
    watcher = CorpusWatcher(
      source: source,
      clock: clock,
      canaryIo: io,
      onChanged: events.add,
      log: (event, fields, {level = LogLevel.info, source, error}) =>
          logs.add((event.name, level.devLogLevel)),
    );
  });

  test('事件不來：存活時限到期 warning、停止監看、金絲雀已刪', () async {
    await startWatching();
    expect(io.files, {_canary});
    clock.advance(watchAliveTimeout);
    expect(count(_warningLevel), 1);
    expect(watcher.isWatching, isFalse);
    expect(io.files, isEmpty);
  });

  test('E2 對照：事件來 -> 無 warning、監看持續、已刪、不觸發 EVT-CORPUS-002', () async {
    await startWatching();
    source.controllers['/ws']!.add(
      const WatchChange(_canary, WatchChangeKind.created),
    );
    await pumpEventQueue();
    clock.advance(watchAliveTimeout * 2);
    expect(count(_warningLevel), 0);
    expect(watcher.isWatching, isTrue);
    expect(io.files, isEmpty);
    expect(events, isEmpty);
  });

  test('docs 不可寫：只寫 info，監看持續', () async {
    io.writable = false;
    await startWatching();
    clock.advance(watchAliveTimeout * 2);
    expect(count(_warningLevel), 0);
    expect(
      logs.where((l) => l.$2 == _infoLevel && l.$1.contains('alive')),
      hasLength(1),
    );
    expect(watcher.isWatching, isTrue);
  });

  test('殘留先清除，不符命名者不受影響', () async {
    io.residue = [_oldCanary];
    io.files.addAll([_oldCanary, 'docs/keep.md']);
    await startWatching();
    expect(io.deleted, contains(_oldCanary));
    expect(io.files, contains('docs/keep.md'));
  });

  test('殘留清除失敗與金絲雀刪除失敗：各 warning，監看持續', () async {
    io.residue = [_oldCanary];
    io.residueDeleteFails = true;
    io.deleteFails = true;
    await startWatching();
    expect(count(_warningLevel), 1);
    source.controllers['/ws']!.add(
      const WatchChange(_canary, WatchChangeKind.created),
    );
    await pumpEventQueue();
    expect(count(_warningLevel), 2);
    expect(watcher.isWatching, isTrue);
  });
}
