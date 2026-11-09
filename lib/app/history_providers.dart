// SPEC-008 FR-09：History 的惰性載入、快取、取消與切換專案清除。
//
// Riverpod 只在此層；lib/history 保持純 Dart。
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
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

/// 時鐘；測試以固定值覆寫。
final historyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// app root（`AppShell`）啟動時設為 `true`，宣告 [historyScanInputsProvider]
/// 已接線到實際 Schema 狀態；未接線（最小容器）讀取時仍拋錯。
final historyScanInputsWiredProvider = stateHolderProvider<bool>(
  (ref) => false,
);

/// 必接線：Schema 就緒度、型別表識別與事件建構器工廠。
///
/// 未接線（[historyScanInputsWiredProvider] 為 `false`）即拋錯（DI 契約，配
/// wiring test）；接線後取自實際 Schema 狀態（Domain 視圖狀態、降級旗標、
/// 最近一輪掃描的型別表），其中任一改變即重建。
final historyScanInputsProvider = stateHolderProvider<HistoryScanInputs>((ref) {
  if (!ref.watch(historyScanInputsWiredProvider)) {
    throw UnimplementedError(
      // i18n-exempt: 開發者面向的 DI 契約錯誤訊息
      'historyScanInputsProvider must be overridden at app root',
    );
  }
  return _inputsFromSchemaState(ref);
});

/// 期間選擇（預設期間／最近 30 天／全部）；切換專案時重置。
final historyPeriodChoiceProvider = stateHolderProvider<PeriodChoice>((ref) {
  ref.watch(currentWorkspaceStateProvider.select(_workspaceRootOf));
  return PeriodChoice.defaultPeriod;
});

/// 是否包含 ticket 建檔事件；切換專案時重置。
final historyIncludeTicketCreationProvider = stateHolderProvider<bool>((ref) {
  ref.watch(currentWorkspaceStateProvider.select(_workspaceRootOf));
  return false;
});

String? _workspaceRootOf(WorkspaceState s) =>
    s is WorkspaceReady ? s.path : null;

HistoryScanInputs _inputsFromSchemaState(Ref ref) {
  final domain = ref.watch(domainViewStateProvider);
  final degraded = ref.watch(degradedSchemaProvider);
  final round = ref.watch(scanRoundProvider);
  final table = round is ScanRoundCompleted
      ? round.result.schemaResolution.typeTable
      : null;
  return HistoryScanInputs(
    schemaReadiness: _readinessOf(domain, degraded),
    tableIdentity: _tableIdentityOf(table, degraded),
    createBuilder: () => _newBuilder(ref, table),
  );
}

/// 需求：[SPEC-008 FR-08 規則 6] 三個阻擋狀態不掃描；降級檢視時以內建表掃描。
HistorySchemaReadiness _readinessOf(DomainViewState domain, bool degraded) {
  if (degraded || (domain is DomainReady && domain.isDegraded)) {
    return HistorySchemaReadiness.degradedBuiltinTable;
  }
  return switch (domain) {
    DomainNotFramework() ||
    DomainSchemaUnconsumable() ||
    DomainSchemaIncompatible() => HistorySchemaReadiness.blocked,
    _ => HistorySchemaReadiness.ready,
  };
}

String _tableIdentityOf(TypeTable? table, bool degraded) {
  final edges = [
    for (final e in table?.edgeTypes?.values ?? const <EdgeTypeDecl>[])
      '${e.name}/${e.layer}/${e.forwardField}/${e.edgeClass}',
  ]..sort();
  return '${degraded ? 'builtin' : 'project'}:${Object.hashAll(edges)}';
}

/// 事件建構器：使用中邊型取內建表決議後，限縮到實際型別表宣告的邊型；
/// ticket 與 closed_by 略過規則的 id_pattern 取自實際型別表。
EdgeEventBuilder _newBuilder(Ref ref, TypeTable? table) {
  final builtin = ref.read(builtinTrackingSchemaJsonProvider).value;
  final declared = table?.edgeTypes?.keys.toSet();
  final active = builtin == null
      ? const <EdgeTypeEntry>[]
      : resolveEdgeTypes(projectSchemaJson: null, builtinSchemaJson: builtin)
            .activeEdgeTypes
            .where((e) => declared == null || declared.contains(e.name));
  final nodeTypes = table?.nodeTypes ?? const <String, NodeTypeEntry>{};
  return EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: active,
      closedByIdPatterns: [
        for (final entry in nodeTypes.entries)
          if (entry.key != 'FlowStep') ?entry.value.idRegExp,
      ],
    ),
    ticketIdPattern: nodeTypes['Ticket']?.idRegExp ?? RegExp(r'(?!)'),
  );
}

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
      case GitPreflightFailed(:final reason, :final stderrSummary):
        _terminal(HistoryFailed(reason, stderrSummary: stderrSummary));
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
    var processed = 0;
    DateTime? boundary;
    void feed(List<ScanCommitResult> done) {
      for (final r in done) {
        events.addAll(
          builder.processCommitWithShallow(r, isShallow: ready.isShallow),
        );
        processed++;
        if (ready.isShallow && r.commit.parents.isEmpty) {
          boundary = _utcOf(r.commit.committedAtSeconds);
        }
      }
      // G-3：讀取中帶已處理 commit 數；已有結果的重掃維持結果畫面。
      if (token == _generation && state is HistoryLoading) {
        state = HistoryLoading(processedCount: processed);
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
        shallowBoundaryDate: boundary,
      ),
    );
  }

  static DateTime _utcOf(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  void _finishWithoutResult(GitScanResult result) {
    developer.log(
      // i18n-exempt: 開發者 log
      'scan ended without result: ${result.runtimeType}',
      name: _tag,
    );
    final cached = _cache;
    state = switch (result) {
      GitScanFailed(:final reason, :final stderrSummary) => HistoryFailed(
        reason,
        stderrSummary: stderrSummary,
      ),
      _ => cached == null ? const HistoryCancelled() : HistoryLoaded(cached),
    };
  }
}
