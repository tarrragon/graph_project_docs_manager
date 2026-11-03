/// [SPEC-006 FR-11] 檔案監看與自動重新解析（0.6.0-W1-080，批 B1）。
///
/// 過濾、去抖合併與監看生命週期；真實 `DirectoryWatcher` 的 [WatchSource]
/// 實作留待後續批次（需 `package:watcher`）。
// 具名參數不可為私有名稱，欄位以初始化清單賦值。
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

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

const String _docsPrefix = 'docs/';
const String _markdownSuffix = '.md';
const String _vcsDirName = '.git';
const Set<String> _topicFiles = {
  'docs/work-logs/topic-assignments.txt',
  'docs/work-logs/topics-registry.txt',
};
const int _warningLevel = 900; // magic-exempt: developer.log warning 級別
const int _infoLevel = 800; // magic-exempt: developer.log info 級別

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

/// FR-11 規則 1、2、10、11：監看生命週期（過濾 → 去抖 → 送出 EVT-CORPUS-002）。
/// [log] 的 level 沿用 `developer.log`（900 為 warning）。
class CorpusWatcher {
  CorpusWatcher({
    required WatchSource source,
    required DebounceClock clock,
    required void Function(CorpusChangedEvent event) onChanged,
    required void Function(String message, {int level}) log,
    String? nonDomainPathsLocation,
    this.readyTimeout = watchReadyTimeout,
  }) : _source = source,
       _clock = clock,
       _log = log,
       _nonDomainPathsLocation = nonDomainPathsLocation {
    _debouncer = WatchDebouncer(clock: clock, onFlush: onChanged);
  }

  final Duration readyTimeout;
  final DebounceClock _clock;
  DebounceTimer? _readyTimer;
  final WatchSource _source;
  final void Function(String message, {int level}) _log;
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
      // i18n-exempt: 開發者日誌，非使用者介面字串
      _log('watch skipped, docs/ absent: $workspaceRoot', level: _infoLevel);
      _openGate(gate);
      return;
    }
    _subscription = _source
        .watch(workspaceRoot)
        .listen(
          _onChange,
          // i18n-exempt: 開發者日誌，非使用者介面字串
          onError: (Object e) =>
              _fail(workspaceRoot, 'error: $e', gate), // i18n-exempt: 開發者日誌
          onDone: () => _fail(
            workspaceRoot,
            'stream closed unexpectedly', // i18n-exempt: 開發者日誌
            gate,
          ),
        );
    // i18n-exempt: 開發者日誌，非使用者介面字串
    _log('watch started: $workspaceRoot', level: _infoLevel);
    // 規則 10：就緒逾時視同監看失敗。
    _readyTimer = _clock.schedule(readyTimeout, () {
      // i18n-exempt: 開發者日誌，非使用者介面字串
      _fail(workspaceRoot, 'ready timeout', gate);
      _openGate(gate);
    });
    final timer = _readyTimer;
    _source
        .ready(workspaceRoot)
        .then(
          (_) {
            timer?.cancel();
            _openGate(gate);
          },
          onError: (Object e) {
            // i18n-exempt: 開發者日誌，非使用者介面字串
            _fail(workspaceRoot, 'ready error: $e', gate);
            _openGate(gate);
          },
        );
  }

  void _openGate(Completer<void> gate) {
    if (!gate.isCompleted) gate.complete();
  }

  void _onChange(WatchChange change) {
    if (isScanInputPath(
      change.relativePath,
      nonDomainPathsLocation: _nonDomainPathsLocation,
    )) {
      _debouncer.add(change);
    }
  }

  /// [gate] 為發起該次 start 的閘門；已被新的 start 取代者的失敗不生效（F4）。
  void _fail(String workspaceRoot, String reason, Completer<void> gate) {
    if (!isWatching || !identical(gate, _readyGate)) return;
    // i18n-exempt: 開發者日誌，非使用者介面字串
    final message = 'watch failed, stopped: $workspaceRoot ($reason)';
    _log(message, level: _warningLevel);
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
    final sub = _subscription;
    _subscription = null;
    _debouncer.clearPending();
    await sub?.cancel();
  }

  /// 清空去抖窗內尚未送出的累積事件（FR-11 規則 8）。
  void clearPending() => _debouncer.clearPending();
}
