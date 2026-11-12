import 'dart:async';

/// 需求：[SPEC-009-test-design §1.4] 逾時計時器：以虛擬時間推進，不以真實時間
/// 等待。傳給 `EditWorkspace.open(timer: manual.call)`。
class ManualEditTimer {
  Duration _now = Duration.zero;
  final List<({Duration due, Completer<void> done})> _pending = [];

  Future<void> call(Duration duration) {
    final completer = Completer<void>();
    _pending.add((due: _now + duration, done: completer));
    return completer.future;
  }

  /// 推進虛擬時間；到期的計時器完成。呼叫後以 `pumpEventQueue` 讓後續非同步
  /// 工作執行。
  void advance(Duration duration) {
    _now += duration;
    for (final timer in [..._pending]) {
      if (timer.due <= _now) {
        _pending.remove(timer);
        timer.done.complete();
      }
    }
  }
}
