/// 0.6.0-W1-080 B7：FR-11 規則 1 就緒閘門、規則 2 docs/ 缺席、規則 10 失敗放行。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/corpus_watch_provider.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../../helpers/fake_watch_source.dart';
import '../../../helpers/manual_debounce_clock.dart';

const _warningLevel = 900;
const _infoLevel = 800;

class _Log {
  _Log(this.message, this.level);
  final String message;
  final int level;
}

void main() {
  group('CorpusWatcher 就緒與 docs 缺席', () {
    late FakeWatchSource source;
    late List<_Log> logs;
    late CorpusWatcher watcher;

    setUp(() {
      source = FakeWatchSource();
      logs = <_Log>[];
      watcher = CorpusWatcher(
        source: source,
        clock: ManualDebounceClock(),
        onChanged: (_) {},
        log: (m, {int level = 0}) => logs.add(_Log(m, level)),
      );
    });

    test('ready 完成前 ready Future 未完成，完成後才完成', () async {
      final gate = Completer<void>();
      source.readyBuilder = (_) => gate.future;
      var done = false;
      await watcher.start('/ws');
      unawaited(watcher.ready.then((_) => done = true));
      await pumpEventQueue();
      expect(done, isFalse);
      gate.complete();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(watcher.isWatching, isTrue);
    });

    test('ready 失敗：記一筆 warning、停止監看、ready 照常放行', () async {
      source.readyBuilder = (_) => Future<void>.error(StateError('boom'));
      await watcher.start('/ws');
      await watcher.ready;
      expect(logs.where((l) => l.level == _warningLevel), hasLength(1));
      expect(watcher.isWatching, isFalse);
    });

    test('docs 缺席：不訂閱、只有 info、沒有 warning、ready 立即放行', () async {
      source.docsExists = false;
      await watcher.start('/ws');
      await watcher.ready;
      expect(source.watchCalls, 0);
      expect(watcher.isWatching, isFalse);
      expect(logs.where((l) => l.level == _warningLevel), isEmpty);
      expect(logs.where((l) => l.level == _infoLevel), hasLength(1));
    });

    test('正向對照：docs 存在時有訂閱', () async {
      await watcher.start('/ws');
      expect(source.watchCalls, 1);
      expect(watcher.isWatching, isTrue);
    });
  });

  group('首輪（visibility）等監看就緒', () {
    test('ready 前不開始，ready 後才開始；manual 不受閘門影響', () async {
      final gate = Completer<void>();
      final source = FakeWatchSource()..readyBuilder = (_) => gate.future;
      final container = ProviderContainer(
        overrides: [watchSourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      final controller = container.read(corpusWatchProvider);
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws');
      await pumpEventQueue();

      final started = <WatchRoundEvent>[];
      controller.events.listen(started.add);
      controller.scheduler.request(ScanTrigger.visibility);
      await pumpEventQueue();
      expect(started, isEmpty);

      gate.complete();
      await pumpEventQueue();
      expect(started.whereType<WatchRoundStarted>(), isNotEmpty);
    });

    test('ready 失敗：首輪照常開始', () async {
      final source = FakeWatchSource()
        ..readyBuilder = (_) => Future<void>.error(StateError('boom'));
      final container = ProviderContainer(
        overrides: [watchSourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      final controller = container.read(corpusWatchProvider);
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws');
      await pumpEventQueue();

      final started = <WatchRoundEvent>[];
      controller.events.listen(started.add);
      controller.scheduler.request(ScanTrigger.visibility);
      await pumpEventQueue();
      expect(started.whereType<WatchRoundStarted>(), isNotEmpty);
    });
  });
}
