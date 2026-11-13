/// [SPEC-006 FR-11] 監看接線（0.6.0-W1-080，批 B4）。
///
/// 工作區 [WorkspaceReady] 時啟動監看，其餘狀態停止；監看變動經
/// [ScanScheduler] 觸發整輪重掃，並對外送出輪次開始／完成事件
/// （供破洞頁呈現 B5、系統通知 B6 使用）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/app_log_event.dart';
import 'package:graph_project_docs_manager/app/corpus_watcher_provider.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/scan_scheduler.dart';
import 'package:graph_project_docs_manager/corpus/corpus_watch.dart';
import 'package:graph_project_docs_manager/app/round_gaps.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

export 'package:graph_project_docs_manager/app/corpus_watcher_provider.dart'
    show watchClockProvider, watchSourceProvider;

/// 輪次事件。
sealed class WatchRoundEvent {
  const WatchRoundEvent(this.trigger);

  final ScanTrigger trigger;
}

class WatchRoundStarted extends WatchRoundEvent {
  const WatchRoundStarted(super.trigger);
}

class WatchRoundCompleted extends WatchRoundEvent {
  const WatchRoundCompleted(
    super.trigger, {
    required this.itemIds,
    required this.rerunPending,
    this.failed = false,
  });

  /// 取得輪次時拋出非預期例外（破洞頁落「無法判定」）。
  final bool failed;

  /// 本輪破洞項 itemId 集合；輪次不可用或失敗時為 null。
  final Set<String>? itemIds;

  /// 完成當下是否仍有待重跑輪次。
  final bool rerunPending;
}

/// 監看與排程的擁有者。
class CorpusWatchController {
  CorpusWatchController(this._ref) {
    _watcher = _ref.read(corpusWatcherProvider);
    _ref.read(watchChangedSinkProvider).listener = () =>
        scheduler.request(ScanTrigger.watch);
    scheduler = ScanScheduler(
      runRound: _runRound,
      clearPendingWatchEvents: _watcher.clearPending,
    );
  }

  final Ref _ref;
  late final CorpusWatcher _watcher;
  late final ScanScheduler scheduler;
  final StreamController<WatchRoundEvent> _events =
      StreamController<WatchRoundEvent>.broadcast();

  Stream<WatchRoundEvent> get events => _events.stream;

  bool get isWatching => _watcher.isWatching;

  Future<void> sync(WorkspaceState state) => switch (state) {
    WorkspaceReady(:final path) => _watcher.start(path),
    _ => _watcher.stop(),
  };

  Future<void> _runRound(ScanTrigger trigger) async {
    // 規則 1 的就緒閘門在 ScanRoundNotifier.ensureRound（所有首輪路徑共用）。
    final generation = scheduler.generation;
    _events.add(WatchRoundStarted(trigger));
    Set<String>? ids;
    var failed = false;
    try {
      final round = await _obtainRound(trigger);
      if (round != null) ids = gapItemIdsOf(round);
    } catch (e) {
      failed = true;
      appLogSink(
        AppLogEvent.watchRoundFetchFailed,
        LogFields.empty,
        level: LogLevel.error,
        source: ErrorSource.internal,
        error: e,
      );
    }
    // 排程已被使用者取消（含首輪等待就緒期間）：不發完成事件。
    if (generation != scheduler.generation) return;
    _events.add(
      WatchRoundCompleted(
        trigger,
        itemIds: ids,
        rerunPending: scheduler.hasPendingRerun,
        failed: failed,
      ),
    );
  }

  /// visibility 共用已完成或進行中的輪次；watch、manual 丟棄後重掃。
  Future<ScanRoundResult?> _obtainRound(ScanTrigger trigger) {
    final rounds = _ref.read(scanRoundProvider.notifier);
    return trigger == ScanTrigger.visibility
        ? rounds.ensureRound()
        : rounds.rescan();
  }

  Future<void> dispose() async {
    await _watcher.stop();
    await _events.close();
  }
}

/// 監看控制器；啟動後隨工作區狀態啟停。
final corpusWatchProvider = Provider<CorpusWatchController>((ref) {
  final controller = CorpusWatchController(ref);
  ref.listen<WorkspaceState>(
    currentWorkspaceStateProvider,
    (_, next) => unawaited(controller.sync(next)),
    fireImmediately: true,
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});
