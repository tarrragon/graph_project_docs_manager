/// 共用掃描輪次（0.5.0-W1-114.19）：讀型別表 → [scanCorpus] → [buildGraph]
/// 的單一輪次，供 Domain 視圖（114.14）與破洞報告（114.15）共用。
///
/// 一輪＝一次掃描＋一次建圖。已有完成輪次直接回傳；切換工作區或手動重掃
/// 開新輪；取消時丟棄該輪結果（SPEC-003 §2.5「丟棄結果」），不為
/// [scanCorpus] 新增取消參數。「再次可見自動重掃」屬待決，不在本檔。
///
/// 依賴方向：lib/app 編排 corpus／graph／schema，反向不得依賴本層。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/docs_file_system.dart';
import 'package:graph_project_docs_manager/graph/graph_builder.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/schema/schema_source_resolver.dart';
import 'package:graph_project_docs_manager/schema/type_table.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

const String _tag = 'scan_round';

/// 專案 `tracking_schema.json` 相對工作區根的路徑（PROP-002）。
const String projectSchemaRelativePath =
    '.claude/skills/doc/doc_system/core/tracking_schema.json';

/// App 內建型別表資產路徑（見 `pubspec.yaml`）。
const String builtinTrackingSchemaAssetPath =
    'assets/schema/builtin_tracking_schema.json';

/// 一輪的不可變結果。
class ScanRoundResult {
  const ScanRoundResult({
    required this.workspacePath,
    required this.scan,
    required this.graph,
    required this.schemaResolution,
    required this.isDegraded,
  });

  /// 本輪所屬工作區根目錄。
  final String workspacePath;

  final CorpusScanResult scan;

  final GraphBuildResult graph;

  /// 型別表來源判定結果（含決議後型別表與路徑模式來源）。
  final SchemaSourceResolution schemaResolution;

  /// 本輪是否以內建表作為專案型別表（SPEC-007 FR-01 降級）。
  final bool isDegraded;
}

/// 輪次狀態。
sealed class ScanRoundState {
  const ScanRoundState();
}

/// 目前沒有輪次。
class ScanRoundIdle extends ScanRoundState {
  const ScanRoundIdle();
}

/// 輪次進行中。
class ScanRoundRunning extends ScanRoundState {
  const ScanRoundRunning(this.workspacePath, {this.processedCount = 0});
  final String workspacePath;

  /// 預設掃描函式分批回報的已處理檔案數（SPEC-003 §2.6）；替身不回報時恆為 0。
  final int processedCount;
}

/// 進度入口的 Zone 識別鍵：輪次擁有者在 Zone 內放入帶 generation 的回報函式，
/// 預設掃描函式於呼叫時取用，不使用全域可變狀態。
const Object _progressZoneKey = #scanRoundProgressSink;

/// 輪次已完成。
class ScanRoundCompleted extends ScanRoundState {
  const ScanRoundCompleted(this.result);
  final ScanRoundResult result;
}

typedef ScanCorpusFn = Future<CorpusScanResult> Function({
  required DocsFileSystem fileSystem,
  required TypeTable table,
  required TypeTable builtinTable,
});

typedef BuildGraphFn = GraphBuildResult Function({
  required List<RawNode> rawNodes,
  required Map<String, dynamic>? projectSchemaJson,
  required Map<String, dynamic> builtinSchemaJson,
});

/// 掃描函式掛點；測試以計數替身覆寫。
final scanCorpusFnProvider = Provider<ScanCorpusFn>(
  (ref) =>
      ({required fileSystem, required table, required builtinTable}) =>
          scanCorpus(
            fileSystem: fileSystem,
            table: table,
            builtinTable: builtinTable,
            onProcessed: Zone.current[_progressZoneKey] as void Function(int)?,
          ),
);

/// 建圖函式掛點；測試以計數替身覆寫。
final buildGraphFnProvider = Provider<BuildGraphFn>(
  (ref) =>
      ({
        required rawNodes,
        required projectSchemaJson,
        required builtinSchemaJson,
      }) => buildGraph(
        rawNodes: rawNodes,
        projectSchemaJson: projectSchemaJson,
        builtinSchemaJson: builtinSchemaJson,
      ),
);

/// 依工作區根目錄建檔案系統；測試覆寫為假檔案系統。
final docsFileSystemFactoryProvider =
    Provider<DocsFileSystem Function(String workspaceRoot)>(
      (ref) => DefaultDocsFileSystem.new,
    );

/// App 內建型別表（頂層 JSON）；測試覆寫為固定值。
final builtinTrackingSchemaJsonProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final raw = await rootBundle.loadString(
    builtinTrackingSchemaAssetPath,
    cache: false,
  );
  return jsonDecode(raw) as Map<String, dynamic>;
});

/// 共用輪次 provider 識別名：`scanRoundProvider`。
final scanRoundProvider = NotifierProvider<ScanRoundNotifier, ScanRoundState>(
  ScanRoundNotifier.new,
);

/// 同一專案最後一次完成的輪次結果（0.5.0-W1-205.2.1，SPEC-001 §1〈矩陣與泳道
/// 同由掃描輪次衍生〉）：重掃中、取消重掃（Idle）、輪次失敗時皆保留上一輪；
/// 切換專案（工作區路徑變更）時清除。Domain 矩陣與泳道共讀此來源，兩者同輪。
final lastCompletedRoundProvider =
    NotifierProvider<LastCompletedRoundNotifier, ScanRoundResult?>(
      LastCompletedRoundNotifier.new,
    );

/// [lastCompletedRoundProvider] 的擁有者。
class LastCompletedRoundNotifier extends Notifier<ScanRoundResult?> {
  @override
  ScanRoundResult? build() {
    ref.listen<ScanRoundState>(scanRoundProvider, (_, next) {
      if (next is ScanRoundCompleted) state = next.result;
    });
    ref.listen<WorkspaceState>(currentWorkspaceStateProvider, (prev, next) {
      final same =
          prev is WorkspaceReady &&
          next is WorkspaceReady &&
          prev.path == next.path;
      if (!same) state = null;
    });
    final current = ref.read(scanRoundProvider);
    return current is ScanRoundCompleted ? current.result : null;
  }
}

/// 輪次擁有者。消費者呼叫 [ensureRound] 取得（或開始）本工作區的輪次。
class ScanRoundNotifier extends Notifier<ScanRoundState> {
  Future<ScanRoundResult?>? _inFlight;
  int _generation = 0;

  @override
  ScanRoundState build() {
    ref.onDispose(() => _generation++);
    ref.listen<WorkspaceState>(currentWorkspaceStateProvider, (prev, next) {
      if (_isSameWorkspace(prev, next)) return;
      discard('workspace-changed');
    });
    return const ScanRoundIdle();
  }

  void _log(String message, {int level = 500, Object? error}) {
    developer.log(
      message, // i18n-exempt: 開發者 debug log
      name: _tag,
      level: level,
      error: error,
    );
  }

  bool _isSameWorkspace(WorkspaceState? prev, WorkspaceState next) =>
      prev is WorkspaceReady &&
      next is WorkspaceReady &&
      prev.path == next.path;

  /// 已有完成輪次直接回傳；進行中則共用該輪；否則開新輪。工作區非
  /// [WorkspaceReady] 回傳 `null`；該輪於等待期間被丟棄（切換、重掃、取消）
  /// 亦回傳 `null`。
  Future<ScanRoundResult?> ensureRound() {
    final current = state;
    if (current is ScanRoundCompleted) {
      return Future.value(current.result);
    }
    return _inFlight ?? _startRound();
  }

  /// 手動重新掃描：丟棄現有輪次並開新輪。
  Future<ScanRoundResult?> rescan() {
    discard('rescan');
    return _startRound();
  }

  /// 取消／失效：丟棄進行中或已完成的輪次，之後讀取開新輪。
  void discard([String reason = 'cancel']) {
    // i18n-exempt: 開發者 debug log
    _log('discard：reason=$reason, generation=$_generation');
    _generation++;
    _inFlight = null;
    state = const ScanRoundIdle();
  }

  Future<ScanRoundResult?> _startRound() {
    final workspace = ref.read(currentWorkspaceStateProvider);
    if (workspace is! WorkspaceReady) return Future.value(null);
    final generation = ++_generation;
    state = ScanRoundRunning(workspace.path);
    // i18n-exempt: 開發者 debug log
    _log('開始：path=${workspace.path}, generation=$generation');
    final future = _runGuarded(workspace.path, generation);
    _inFlight = future;
    return future;
  }

  Future<ScanRoundResult?> _runGuarded(String path, int generation) async {
    try {
      final result = await runZoned(
        () => _runRound(path),
        zoneValues: {
          _progressZoneKey: (int count) =>
              _reportProgress(path, generation, count),
        },
      );
      if (generation != _generation) {
        // i18n-exempt: 開發者 debug log
        _log('丟棄過期輪次：path=$path, generation=$generation');
        return null;
      }
      state = ScanRoundCompleted(result);
      _inFlight = null;
      // i18n-exempt: 開發者 debug log
      _log('完成：path=$path, degraded=${result.isDegraded}');
      return result;
    } catch (e, st) {
      developer.log(
        '輪次失敗：$path, generation=$generation', // i18n-exempt: 開發者 debug log
        name: _tag,
        level: 900,
        error: e,
        stackTrace: st,
      );
      // 過期輪次失敗與過期輪次成功一致：回傳 null，不往外拋。
      if (generation != _generation) return null;
      _inFlight = null;
      state = const ScanRoundIdle();
      rethrow;
    }
  }

  /// 進度入口：被取代輪次（generation 不符）的回報直接丟棄。
  void _reportProgress(String path, int generation, int count) {
    if (generation != _generation) return;
    state = ScanRoundRunning(path, processedCount: count);
  }

  Future<ScanRoundResult> _runRound(String path) async {
    final fileSystem = ref.read(docsFileSystemFactoryProvider)(path);
    final builtinJson = await ref.read(
      builtinTrackingSchemaJsonProvider.future,
    );
    // 降級切換由呼叫端 discard／rescan，輪次不監聽旗標。
    final isDegraded = ref.read(degradedSchemaProvider);
    final projectJson = isDegraded
        ? builtinJson
        : await _readProjectSchemaJson(fileSystem);
    final resolution = resolveSchemaSource(
      projectSchemaJson: projectJson,
      builtinSchemaJson: builtinJson,
    );
    final scan = await ref.read(scanCorpusFnProvider)(
      fileSystem: fileSystem,
      table: resolution.typeTable,
      builtinTable: typeTableFromJson(builtinJson),
    );
    final graph = ref.read(buildGraphFnProvider)(
      rawNodes: scan.rawNodes,
      projectSchemaJson: projectJson,
      builtinSchemaJson: builtinJson,
    );
    return ScanRoundResult(
      workspacePath: path,
      scan: scan,
      graph: graph,
      schemaResolution: resolution,
      isDegraded: isDegraded,
    );
  }

  Future<Map<String, dynamic>?> _readProjectSchemaJson(
    DocsFileSystem fileSystem,
  ) async {
    final read = await fileSystem.readBytes(projectSchemaRelativePath);
    if (read is! DocsReadSuccess) {
      // i18n-exempt: 開發者 debug log
      _log('專案型別表讀取失敗（視為缺席）：$projectSchemaRelativePath', level: 900);
      return null;
    }
    try {
      final decoded = jsonDecode(utf8.decode(read.bytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (e) {
      developer.log(
        'tracking_schema.json 解析失敗', // i18n-exempt: 開發者 debug log
        name: _tag,
        level: 900,
        error: e,
      );
      return null;
    }
  }
}
