/// 0.6.0-W1-080 B7／B9：FR-11 規則 1 就緒、規則 2 docs/ 缺席、規則 10 失敗放行
/// 與就緒逾時、舊 start 晚到失敗不影響新訂閱（F3、F4）。
/// 首輪被閘門擋住的對照組／實驗組在 test/unit/app/scan_round_watch_gate_test.dart。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';

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
    late ManualDebounceClock clock;
    late CorpusWatcher watcher;

    setUp(() {
      source = FakeWatchSource();
      logs = <_Log>[];
      clock = ManualDebounceClock();
      watcher = CorpusWatcher(
        source: source,
        clock: clock,
        onChanged: (_) {},
        log: (event, fields, {level = LogLevel.info, source, error}) =>
            logs.add(_Log(event.name, level.devLogLevel)),
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

    test('F3：就緒逾時（注入時鐘）記一筆 warning、停止監看、ready 放行', () async {
      source.readyBuilder = (_) => Completer<void>().future;
      await watcher.start('/ws');
      var done = false;
      unawaited(watcher.ready.then((_) => done = true));
      clock.advance(watchReadyTimeout - const Duration(milliseconds: 1));
      await pumpEventQueue();
      expect(done, isFalse);
      expect(logs.where((l) => l.level == _warningLevel), isEmpty);
      clock.advance(const Duration(milliseconds: 1));
      await pumpEventQueue();
      expect(done, isTrue);
      expect(watcher.isWatching, isFalse);
      expect(logs.where((l) => l.level == _warningLevel), hasLength(1));
    });

    test('F4：舊 start 的 ready 晚到失敗，不取消新工作區的訂閱', () async {
      final oldReady = Completer<void>();
      source.readyBuilder = (root) =>
          root == '/ws-a' ? oldReady.future : Future<void>.value();
      await watcher.start('/ws-a');
      await watcher.start('/ws-b');
      await pumpEventQueue();
      oldReady.completeError(StateError('late'));
      await pumpEventQueue();
      expect(watcher.isWatching, isTrue);
      expect(logs.where((l) => l.level == _warningLevel), isEmpty);
    });

    test('F4 對照：目前 start 的 ready 失敗照常停止監看', () async {
      source.readyBuilder = (_) => Future<void>.error(StateError('boom'));
      await watcher.start('/ws-b');
      await pumpEventQueue();
      expect(watcher.isWatching, isFalse);
    });
  });
}
