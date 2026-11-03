/// 手動推進的 [DebounceClock]（0.6.0-W1-080，SPEC-006 FR-11 規則 4）。
///
/// 測試以 [advance] 推進虛擬時間，到期的回呼依到期時間順序執行；不使用
/// 真實計時（test-assertion-design D1、D3）。
library;

import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';

class ManualDebounceClock implements DebounceClock {
  Duration _now = Duration.zero;
  final List<_ManualTimer> _timers = <_ManualTimer>[];

  /// 目前虛擬時間（自建立起算）。
  Duration get now => _now;

  @override
  DebounceTimer schedule(Duration delay, void Function() callback) {
    final timer = _ManualTimer(_now + delay, callback);
    _timers.add(timer);
    return timer;
  }

  /// 推進 [by]，期間到期的計時器依到期順序觸發。
  void advance(Duration by) {
    final target = _now + by;
    while (true) {
      final due =
          _timers.where((t) => !t.cancelled && t.dueAt <= target).toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.dueAt;
      next.cancelled = true;
      next.callback();
    }
    _now = target;
    _timers.removeWhere((t) => t.cancelled);
  }
}

class _ManualTimer implements DebounceTimer {
  _ManualTimer(this.dueAt, this.callback);

  final Duration dueAt;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}
