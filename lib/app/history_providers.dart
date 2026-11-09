// SPEC-008 FR-09：History 的惰性載入、快取、取消與切換專案清除。
//
// Riverpod 只在此層；lib/history 保持純 Dart。
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/git/git_history_port.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/parse/scan_stream_parser.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

const String _tag = 'HistoryNotifier';

/// git 程序執行器；預設為真實程序，測試以 fake 覆寫。
final historyProcessRunnerProvider = Provider<GitProcessRunner>(
  (ref) => const IoGitProcessRunner(),
);

final historyGitPortProvider = Provider<GitHistoryPort>(
  (ref) => GitHistoryPort(runner: ref.watch(historyProcessRunnerProvider)),
);

/// 必接線：Schema 就緒度、型別表識別與事件建構器工廠，app root 須以真實
/// 實作 override；未 override 即拋錯（DI 契約，配 wiring test）。
final historyScanInputsProvider = stateHolderProvider<HistoryScanInputs>(
  (ref) => throw UnimplementedError(
    // i18n-exempt: 開發者面向的 DI 契約錯誤訊息
    'historyScanInputsProvider must be overridden at app root',
  ),
);

final historyProvider = NotifierProvider<HistoryNotifier, HistoryViewState>(
  HistoryNotifier.new,
);

class HistoryNotifier extends Notifier<HistoryViewState> {
  HistoryScanSnapshot? _cache;
  GitScan? _activeScan;
  int _generation = 0;

  @override
  HistoryViewState build() {
    // 工作區根改變（或首次建立）：取消進行中掃描並清空快取。
    ref.watch(currentWorkspaceStateProvider.select(_rootOf));
    ref.onDispose(_abandonActiveScan);
    _abandonActiveScan();
    _cache = null;
    return const HistoryIdle();
  }

  static String? _rootOf(WorkspaceState s) =>
      s is WorkspaceReady ? s.path : null;

  /// 進入第七畫面：快取鍵相符則沿用，否則掃描。
  Future<void> enter() => _load(force: false);

  /// 使用者要求重新整理：全量掃描。
  Future<void> refresh() => _load(force: true);

  /// 取消進行中的前置檢查或掃描；已有結果者維持快取結果。
  void cancel() {
    _abandonActiveScan();
    final cached = _cache;
    state = cached == null ? const HistoryCancelled() : HistoryLoaded(cached);
  }

  void _abandonActiveScan() {
    _generation++;
    final scan = _activeScan;
    _activeScan = null;
    scan?.cancel();
  }

  /// 需求：[SPEC-008 FR-09] 前置檢查期間維持先前狀態；非 git 直接降級。
  Future<void> _load({required bool force}) async {
    final inputs = ref.read(historyScanInputsProvider);
    if (inputs.schemaReadiness == HistorySchemaReadiness.blocked) {
      state = const HistorySchemaBlocked();
      return;
    }
    final root = _rootOf(ref.read(currentWorkspaceStateProvider));
    if (root == null) return;
    _abandonActiveScan();
    final token = _generation;
    if (state is! HistoryLoaded) state = const HistoryLoading();
    final port = ref.read(historyGitPortProvider);
    final outcome = await port.preflight(root);
    if (token != _generation) return;
    await _afterPreflight(port, root, inputs, outcome, force, token);
  }

  Future<void> _afterPreflight(
    GitHistoryPort port,
    String root,
    HistoryScanInputs inputs,
    GitPreflightOutcome outcome,
    bool force,
    int token,
  ) async {
    switch (outcome) {
      case GitPreflightNotWorkTree():
        _terminal(const HistoryNotGitRepo());
      case GitPreflightGitNotFound():
        _terminal(const HistoryGitNotFound());
      case GitPreflightFailed(:final reason):
        _terminal(HistoryFailed(reason));
      case GitPreflightNoCommit():
        _cacheAndShow(_noCommitSnapshot(root, inputs));
      case GitPreflightReady():
        await _scanIfNeeded(port, root, inputs, outcome, force, token);
    }
  }

  void _terminal(HistoryViewState next) {
    _cache = null;
    state = next;
  }

  void _cacheAndShow(HistoryScanSnapshot snapshot) {
    _cache = snapshot;
    state = HistoryLoaded(snapshot);
  }

  HistoryScanSnapshot _noCommitSnapshot(String root, HistoryScanInputs i) =>
      HistoryScanSnapshot.noCommit(
        key: HistoryCacheKey(
          root: root,
          head: '',
          tableIdentity: i.tableIdentity,
        ),
        isBuiltinTableDegraded: _isDegraded(i),
      );

  bool _isDegraded(HistoryScanInputs i) =>
      i.schemaReadiness == HistorySchemaReadiness.degradedBuiltinTable;

  Future<void> _scanIfNeeded(
    GitHistoryPort port,
    String root,
    HistoryScanInputs inputs,
    GitPreflightReady ready,
    bool force,
    int token,
  ) async {
    final key = HistoryCacheKey(
      root: root,
      head: ready.head,
      tableIdentity: inputs.tableIdentity,
    );
    final cached = _cache;
    if (!force && cached != null && cached.key == key) {
      state = HistoryLoaded(cached);
      return;
    }
    if (state is! HistoryLoaded) state = const HistoryLoading();
    await _runScan(port, root, inputs, ready, key, token);
  }

  Future<void> _runScan(
    GitHistoryPort port,
    String root,
    HistoryScanInputs inputs,
    GitPreflightReady ready,
    HistoryCacheKey key,
    int token,
  ) async {
    final scan = await port.startScan(root, ready);
    if (token != _generation) {
      scan.cancel();
      return;
    }
    _activeScan = scan;
    final parseWatch = Stopwatch()..start();
    final parser = ScanStreamParser();
    final builder = inputs.createBuilder();
    final events = <EdgeEvent>[];
    void feed(List<ScanCommitResult> done) {
      for (final r in done) {
        events.addAll(
          builder.processCommitWithShallow(r, isShallow: ready.isShallow),
        );
      }
    }

    await for (final chunk in scan.stdout) {
      feed(parser.addChunk(chunk));
    }
    final result = await scan.result;
    if (token != _generation) return;
    _activeScan = null;
    if (result is! GitScanCompleted) {
      _finishWithoutResult(result);
      return;
    }
    feed(parser.close());
    scan.reportParse(
      parseDuration: parseWatch.elapsed,
      eventCount: events.length,
      counters: {
        'undecodableLines': parser.counters.undecodableLines,
        'unparsableVersions': parser.counters.unparsableVersions,
        'desyncs': parser.counters.desyncs,
        'yamlParses': parser.counters.yamlParses,
        'nonStringValues': builder.nonStringValues,
        'filesWithoutId': builder.filesWithoutId,
      },
    );
    _cacheAndShow(
      HistoryScanSnapshot(
        key: key,
        events: List.unmodifiable(events),
        mainline: ready.mainline,
        tags: ready.tags,
        isShallow: ready.isShallow,
        isBuiltinTableDegraded: _isDegraded(inputs),
      ),
    );
  }

  void _finishWithoutResult(GitScanResult result) {
    developer.log(
      // i18n-exempt: 開發者 log
      'scan ended without result: ${result.runtimeType}',
      name: _tag,
    );
    final cached = _cache;
    state = switch (result) {
      GitScanFailed(:final reason) => HistoryFailed(reason),
      _ => cached == null ? const HistoryCancelled() : HistoryLoaded(cached),
    };
  }
}
