/// [SPEC-006 FR-11] 檔案監看與自動重新解析（0.6.0-W1-080，批 B1）。
///
/// 過濾、去抖合併與監看生命週期；真實 `DirectoryWatcher` 的 [WatchSource]
/// 實作留待後續批次（需 `package:watcher`）。
// 具名參數不可為私有名稱，欄位以初始化清單賦值。
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

import 'corpus_log_event.dart';

/// FR-11 規則 4 靜默窗（W3）。
const Duration watchQuietWindow = Duration(
  milliseconds: 500,
); // magic-exempt: 規格裁定值 W3

/// FR-11 規則 4 最長等待（W3）。
const Duration watchMaxWait = Duration(seconds: 3); // magic-exempt: 規格裁定值 W3

/// FR-11 規則 10 就緒逾時（用戶裁定 2026-11-03）。
const Duration watchReadyTimeout = Duration(
  seconds: 5,
); // magic-exempt: 規格裁定值 規則 10

/// FR-11 規則 10 就緒後存活檢查的存活時限。
/// 實測定案：單次實測金絲雀寫入到收到事件約 0.11 s，3 s 維持不變
/// （0.6.0-W1-141.2.3）。
const Duration watchAliveTimeout = Duration(
  seconds: 3,
); // magic-exempt: 實機量測定案值

/// FR-11 規則 10 金絲雀檔命名（置於 `docs/` 第一層）。
const String watchCanaryPrefix = '.gpdm-watch-canary-';
const String watchCanarySuffix = '.tmp';

const String _docsPrefix = 'docs/';
const String _markdownSuffix = '.md';
const String _vcsDirName = '.git';
const Set<String> _topicFiles = {
  'docs/work-logs/topic-assignments.txt',
  'docs/work-logs/topics-registry.txt',
};

/// EVT-CORPUS-002 單筆變動的種類（FR-11 規則 5）。
enum WatchChangeKind { created, modified, deleted }

/// 單筆檔案變動：相對工作區根的 `/` 形式路徑與種類。
class WatchChange {
  const WatchChange(this.relativePath, this.kind);

  final String relativePath;
  final WatchChangeKind kind;

  @override
  bool operator ==(Object other) =>
      other is WatchChange &&
      other.relativePath == relativePath &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(relativePath, kind);

  @override
  String toString() => 'WatchChange($relativePath, ${kind.name})';
}

/// EVT-CORPUS-002：一窗合併後的變動清單（FR-11 規則 5，清單非空）。
class CorpusChangedEvent {
  const CorpusChangedEvent(this.changes);

  final List<WatchChange> changes;
}

/// FR-11 規則 3：路徑是否為掃描輸入（保留）；否則丟棄。
/// [nonDomainPathsLocation] 為 FR-10 非 domain 路徑清單檔位置（取自型別表，
/// 未宣告為 null）。
bool isScanInputPath(String relativePath, {String? nonDomainPathsLocation}) {
  if (relativePath.split('/').contains(_vcsDirName)) return false;
  if (_topicFiles.contains(relativePath)) return true;
  if (nonDomainPathsLocation != null &&
      relativePath == nonDomainPathsLocation) {
    return true;
  }
  return relativePath.startsWith(_docsPrefix) &&
      relativePath.endsWith(_markdownSuffix);
}

/// 去抖用的可注入計時器（測試以手動時鐘取代真實 Timer）。
abstract interface class DebounceTimer {
  void cancel();
}

/// 去抖用的可注入時鐘。
abstract interface class DebounceClock {
  DebounceTimer schedule(Duration delay, void Function() callback);
}

/// FR-11 規則 4、5：靜默窗與最長等待去抖，合併為一筆 [CorpusChangedEvent]。
class WatchDebouncer {
  WatchDebouncer({
    required DebounceClock clock,
    required void Function(CorpusChangedEvent event) onFlush,
    this.quietWindow = watchQuietWindow,
    this.maxWait = watchMaxWait,
  }) : _clock = clock,
       _onFlush = onFlush;

  final Duration quietWindow;
  final Duration maxWait;
  final DebounceClock _clock;
  final void Function(CorpusChangedEvent event) _onFlush;
  final Map<String, WatchChangeKind> _pending = <String, WatchChangeKind>{};
  DebounceTimer? _quietTimer;
  DebounceTimer? _maxTimer;

  /// 累積一筆已通過過濾的變動。
  void add(WatchChange change) {
    _merge(change);
    _quietTimer?.cancel();
    _quietTimer = _clock.schedule(quietWindow, _flush);
    _maxTimer ??= _clock.schedule(maxWait, _flush);
  }

  void _merge(WatchChange change) {
    final previous = _pending[change.relativePath];
    if (previous == WatchChangeKind.created) {
      if (change.kind == WatchChangeKind.deleted) {
        _pending.remove(change.relativePath);
        return;
      }
      if (change.kind == WatchChangeKind.modified) return;
    }
    _pending[change.relativePath] = change.kind;
  }

  void _flush() {
    final changes = [
      for (final e in _pending.entries) WatchChange(e.key, e.value),
    ];
    _reset();
    if (changes.isNotEmpty) _onFlush(CorpusChangedEvent(changes));
  }

  void _reset() {
    _quietTimer?.cancel();
    _maxTimer?.cancel();
    _quietTimer = null;
    _maxTimer = null;
    _pending.clear();
  }

  /// 清空尚未送出的累積事件（FR-11 規則 8：手動重掃時）。
  void clearPending() => _reset();

  void dispose() => _reset();
}

/// 監看事件來源埠。事件路徑已轉為相對工作區根的 `/` 形式。
abstract interface class WatchSource {
  Stream<WatchChange> watch(String workspaceRoot);

  /// 規則 2：監看目標（`<root>/docs`）是否存在；不存在則不建立監看。
  bool targetExists(String workspaceRoot);

  /// 規則 1：[watch] 建立的監看就緒時完成；失敗則以錯誤完成。
  Future<void> ready(String workspaceRoot);
}

/// 規則 10 就緒後存活檢查的檔案操作埠；路徑為相對工作區根的 `/` 形式。
/// 任一方法失敗以例外表示。
abstract interface class WatchCanaryIo {
  /// `docs/` 第一層符合金絲雀命名的殘留檔。
  List<String> residualCanaries(String workspaceRoot);

  /// 產生一個新的金絲雀相對路徑。
  String newCanaryPath();

  void write(String workspaceRoot, String relativePath);

  void delete(String workspaceRoot, String relativePath);
}

/// FR-11 規則 1、2、10、11：監看生命週期（過濾 → 去抖 → 送出 EVT-CORPUS-002）。
/// [log] 為 SPEC-010 的 `LogSink<CorpusWatchLogEvent>`；逐檔變動記 debug。
class CorpusWatcher {
  CorpusWatcher({
    required WatchSource source,
    required DebounceClock clock,
    required void Function(CorpusChangedEvent event) onChanged,
    required LogSink<CorpusWatchLogEvent> log,
    String? nonDomainPathsLocation,
    this.readyTimeout = watchReadyTimeout,
    this.aliveTimeout = watchAliveTimeout,
    WatchCanaryIo? canaryIo,
  }) : _canaryIo = canaryIo,
       _source = source,
       _clock = clock,
       _log = log,
       _nonDomainPathsLocation = nonDomainPathsLocation {
    _debouncer = WatchDebouncer(
      clock: clock,
      onFlush: (event) {
        _log(
          CorpusWatchLogEvent.changesFlushed,
          _flushFields(event),
          level: LogLevel.debug,
        );
        onChanged(event);
      },
    );
  }

  final Duration readyTimeout;
  final Duration aliveTimeout;
  final WatchCanaryIo? _canaryIo;
  DebounceTimer? _aliveTimer;
  String? _canaryPath;
  String? _canaryRoot;
  final DebounceClock _clock;
  DebounceTimer? _readyTimer;
  final WatchSource _source;
  final LogSink<CorpusWatchLogEvent> _log;
  final String? _nonDomainPathsLocation;
  late final WatchDebouncer _debouncer;
  StreamSubscription<WatchChange>? _subscription;
  Completer<void> _readyGate = Completer<void>()..complete();

  /// 規則 1：監看就緒（或未建立、已失敗、已停止）時完成，首輪掃描在此之後開始。
  Future<void> get ready => _readyGate.future;

  bool get isWatching => _subscription != null;

  Future<void> start(String workspaceRoot) async {
    // F5：start 發起當下同步換上未完成的新閘門，stop 的 await 期間
    // 讀 ready 的呼叫端拿到的就是新閘門；舊閘門在此放行。
    final previousGate = _readyGate;
    final gate = _readyGate = Completer<void>();
    _openGate(previousGate);
    await _teardown();
    if (gate.isCompleted || !identical(gate, _readyGate)) return;
    if (!_source.targetExists(workspaceRoot)) {
      // 規則 2：docs/ 缺席是「不建立監看」，不是監看失敗，不記 warning。
      _log(CorpusWatchLogEvent.watchSkippedDocsAbsent, LogFields.empty);
      _openGate(gate);
      return;
    }
    _subscription = _source
        .watch(workspaceRoot)
        .listen(
          _onChange,
          onError: (Object e) =>
              _fail(WatchFailReason.streamError, gate, error: e),
          onDone: () => _fail(WatchFailReason.streamClosed, gate),
        );
    _log(CorpusWatchLogEvent.watchStarted, LogFields.empty);
    // 規則 10：就緒逾時視同監看失敗。
    _readyTimer = _clock.schedule(readyTimeout, () {
      _fail(WatchFailReason.readyTimeout, gate);
      _openGate(gate);
    });
    final timer = _readyTimer;
    _source
        .ready(workspaceRoot)
        .then(
          (_) {
            timer?.cancel();
            _openGate(gate);
            if (isWatching && identical(gate, _readyGate)) {
              _startAliveCheck(workspaceRoot, gate);
            }
          },
          onError: (Object e) {
            _fail(WatchFailReason.readyError, gate, error: e);
            _openGate(gate);
          },
        );
  }

  void _openGate(Completer<void> gate) {
    if (!gate.isCompleted) gate.complete();
  }

  /// 規則 10 就緒後存活檢查：清殘留、寫金絲雀、限時等原始事件。
  void _startAliveCheck(String root, Completer<void> gate) {
    final io = _canaryIo;
    if (io == null) return;
    _clearResidue(io, root);
    final path = io.newCanaryPath();
    try {
      io.write(root, path);
    } catch (e) {
      _log(
        CorpusWatchLogEvent.aliveCheckSkipped,
        LogFields.empty,
        source: ErrorSource.platformIo,
        error: e,
      );
      return;
    }
    _log(
      CorpusWatchLogEvent.canaryWritten,
      LogFields.empty,
      level: LogLevel.debug,
    );
    _canaryPath = path;
    _canaryRoot = root;
    _aliveTimer = _clock.schedule(aliveTimeout, () {
      _removeCanary(); // 時限到期即刪
      _fail(WatchFailReason.aliveTimeout, gate);
    });
  }

  void _clearResidue(WatchCanaryIo io, String root) {
    try {
      for (final name in io.residualCanaries(root)) {
        try {
          io.delete(root, name);
          _log(
            CorpusWatchLogEvent.residualCanaryRemoved,
            LogFields({CorpusWatchLogKeys.path: corpusPathValue(name)}),
            level: LogLevel.debug,
          );
        } catch (e) {
          _log(
            CorpusWatchLogEvent.residualCanaryRemovalFailed,
            LogFields({CorpusWatchLogKeys.path: corpusPathValue(name)}),
            level: LogLevel.warning,
            source: ErrorSource.platformIo,
            error: e,
          );
        }
      }
    } catch (e) {
      _log(
        CorpusWatchLogEvent.residualCanaryScanFailed,
        LogFields.empty,
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
        error: e,
      );
    }
  }

  /// 刪除進行中的金絲雀；失敗只記 warning，不重試、不影響監看狀態。
  void _removeCanary() {
    _aliveTimer?.cancel();
    _aliveTimer = null;
    final path = _canaryPath;
    final root = _canaryRoot;
    _canaryPath = null;
    _canaryRoot = null;
    if (path == null || root == null) return;
    try {
      _canaryIo?.delete(root, path);
    } catch (e) {
      _log(
        CorpusWatchLogEvent.canaryRemovalFailed,
        LogFields({CorpusWatchLogKeys.path: corpusPathValue(path)}),
        level: LogLevel.warning,
        source: ErrorSource.platformIo,
        error: e,
      );
    }
  }

  void _onChange(WatchChange change) {
    if (change.relativePath == _canaryPath) {
      _log(
        CorpusWatchLogEvent.canaryEventReceived,
        LogFields.empty,
        level: LogLevel.debug,
      );
      _removeCanary();
      return;
    }
    final keep = isScanInputPath(
      change.relativePath,
      nonDomainPathsLocation: _nonDomainPathsLocation,
    );
    _log(
      CorpusWatchLogEvent.changeObserved,
      LogFields({
        CorpusWatchLogKeys.path: corpusPathValue(change.relativePath),
        CorpusWatchLogKeys.kind: LogValue.enumValue(change.kind),
        CorpusWatchLogKeys.kept: LogValue.boolean(keep),
      }),
      level: LogLevel.debug,
    );
    if (keep) _debouncer.add(change);
  }

  static LogFields _flushFields(CorpusChangedEvent event) {
    int countOf(WatchChangeKind kind) =>
        event.changes.where((c) => c.kind == kind).length;
    return LogFields({
      CorpusWatchLogKeys.changeCount: LogValue.integer(event.changes.length),
      CorpusWatchLogKeys.createdCount: LogValue.integer(
        countOf(WatchChangeKind.created),
      ),
      CorpusWatchLogKeys.modifiedCount: LogValue.integer(
        countOf(WatchChangeKind.modified),
      ),
      CorpusWatchLogKeys.deletedCount: LogValue.integer(
        countOf(WatchChangeKind.deleted),
      ),
    });
  }

  /// [gate] 為發起該次 start 的閘門；已被新的 start 取代者的失敗不生效（F4）。
  void _fail(WatchFailReason reason, Completer<void> gate, {Object? error}) {
    if (!isWatching || !identical(gate, _readyGate)) return;
    _log(
      CorpusWatchLogEvent.watchFailed,
      LogFields({CorpusWatchLogKeys.reason: LogValue.enumValue(reason)}),
      level: LogLevel.warning,
      source: ErrorSource.platformIo,
      error: error,
    );
    _subscription?.cancel();
    _subscription = null;
    _debouncer.clearPending();
    _openGate(_readyGate);
  }

  Future<void> stop() {
    _openGate(_readyGate);
    return _teardown();
  }

  Future<void> _teardown() async {
    _readyTimer?.cancel();
    _readyTimer = null;
    _removeCanary();
    final sub = _subscription;
    _subscription = null;
    _debouncer.clearPending();
    await sub?.cancel();
  }

  /// 清空去抖窗內尚未送出的累積事件（FR-11 規則 8）。
  void clearPending() => _debouncer.clearPending();
}
