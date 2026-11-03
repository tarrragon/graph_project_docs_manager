/// [SPEC-006 FR-11 規則 7、8] 共用掃描排程。
///
/// 監看觸發、`action-gaps-rescan`、再次可見自動掃描共用本排程。
library;

import 'dart:developer' as developer;

/// 掃描觸發來源。
enum ScanTrigger { watch, manual, visibility }

class ScanScheduler {
  ScanScheduler({required this.runRound, this.clearPendingWatchEvents});

  static const String _tag = 'ScanScheduler';

  /// 執行一輪掃描的回呼。
  final Future<void> Function(ScanTrigger trigger) runRound;

  /// 清空去抖累積事件的回呼（manual 觸發時呼叫）。
  final void Function()? clearPendingWatchEvents;

  bool _running = false;
  ScanTrigger? _pending;
  int _generation = 0;

  /// 取消世代；每次 [cancel] 遞增。
  int get generation => _generation;

  bool get isRunning => _running;

  bool get hasPendingRerun => _pending != null;

  /// 請求一輪；進行中則標記待重跑（多筆只重跑一輪，以後到的觸發為準）。
  /// manual 另清空去抖累積。
  void request(ScanTrigger trigger) {
    if (trigger == ScanTrigger.manual) clearPendingWatchEvents?.call();
    if (_running) {
      _pending = trigger;
      return;
    }
    _start(trigger);
  }

  /// 使用者取消：中止當輪並清除待重跑（D2）。
  void cancel() {
    _generation++;
    _pending = null;
    _running = false;
  }

  void _start(ScanTrigger trigger) {
    _running = true;
    final generation = _generation;
    _execute(trigger).whenComplete(() => _onDone(generation));
  }

  Future<void> _execute(ScanTrigger trigger) async {
    try {
      await runRound(trigger);
    } catch (e) {
      // i18n-exempt: 開發者日誌，非使用者可見字串
      developer.log('掃描輪次失敗：$e', name: _tag, level: 900);
    }
  }

  void _onDone(int generation) {
    if (generation != _generation) return;
    final next = _pending;
    _pending = null;
    _running = false;
    if (next != null) _start(next);
  }
}
