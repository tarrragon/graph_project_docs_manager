/// Domain 視圖資料編排（0.5.0-W1-114.14）：gate 通過後經共用掃描輪次
/// （[scanRoundProvider]）取得建圖結果，推導 [DomainViewState]。
///
/// 流程：`DomainLoading` → 取得輪次 → 節點數 > 0 為 `DomainReady`（矩陣由 domainMatrixProvider 衍生）、
/// 0 為 `DomainEmpty`。輪次取不到時（SPEC-001 §1 載入中列）：工作區非 Ready
/// 落「未選專案」，等待中被丟棄則接續新輪次（同破洞報告頁處置）。
///
/// 依賴方向：corpus／graph／layout 不得依賴本層；本層不另起掃描。
library;

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

const String _tag = 'domain_view_loader';

/// 不變式違反與失敗的 log 出口；測試以 override 收集訊息。
typedef DomainViewLogSink = void Function(String message, {int level});

final domainViewLogSinkProvider = Provider<DomainViewLogSink>(
  (ref) =>
      (message, {level = 500}) =>
          developer.log(message, name: _tag, level: level),
);

/// 載入編排的 Riverpod 掛點。
final domainViewLoaderProvider = NotifierProvider<DomainViewLoader, void>(
  DomainViewLoader.new,
);

/// Domain 視圖資料載入、取消與降級進入動作的擁有者。
class DomainViewLoader extends Notifier<void> {
  /// 每次載入、取消、降級遞增；過期的載入結果不寫回。
  int _generation = 0;

  /// 最近一次載入帶入的推定版本，供 [reload] 沿用。
  String? _lastInferredVersion;

  @override
  void build() {}

  /// gate 通過（或降級進入）後的資料載入。[inferredVersion] 為 gate 推定的
  /// 版本旗標，原樣帶入 `DomainReady`／`DomainEmpty`。
  Future<void> load({String? inferredVersion}) async {
    final generation = ++_generation;
    // 確保「最後完成輪次」擁有者先於輪次存在，才能收到本次完成。
    ref.read(lastCompletedRoundProvider);
    _write(const DomainLoading());
    // provider 的建構期間不可修改其他 provider；讓出一個 microtask。
    await Future<void>.microtask(() {});
    final progress = ref.listen<ScanRoundState>(scanRoundProvider, (_, next) {
      if (next is ScanRoundRunning) _updateProgress(generation, next);
    });
    try {
      await _loadRound(generation, inferredVersion);
    } finally {
      progress.close();
    }
  }

  /// 載入中的計數更新：被取代的載入（世代過期）不寫入，保留 isCancelling。
  void _updateProgress(int generation, ScanRoundRunning running) {
    if (!_isCurrent(generation)) return;
    final current = ref.read(domainViewStateProvider);
    if (current is! DomainLoading) return;
    if (current.processedCount == running.processedCount) return;
    _write(
      DomainLoading(
        isCancelling: current.isCancelling,
        processedCount: running.processedCount,
      ),
    );
  }

  Future<void> _loadRound(int generation, String? inferredVersion) async {
    _lastInferredVersion = inferredVersion;
    final ScanRoundResult? round;
    try {
      round = await _obtainRound(generation);
    } catch (e, st) {
      developer.log(
        'Domain 視圖取得掃描輪次失敗', // i18n-exempt: 開發者 debug log
        name: _tag,
        level: 900,
        error: e,
        stackTrace: st,
      );
      // SPEC-001 v1.49 §1 載入失敗：落阻擋狀態，不外拋（降級入口以 unawaited 呼叫）。
      if (_isCurrent(generation)) _write(const DomainLoadFailed());
      return;
    }
    if (!_isCurrent(generation)) return;
    if (round == null) {
      _write(const DomainUnset());
      return;
    }
    final next = await _stateOfRound(round, inferredVersion: inferredVersion);
    if (!_isCurrent(generation)) return;
    _write(next);
  }

  /// 重新載入（`action-domain-reload`）：回載入中，同一資料夾、同一模式——
  /// 降級旗標不動故降級檢視重試仍為降級；推定版本沿用上一次載入的值。
  Future<void> reload() => load(inferredVersion: _lastInferredVersion);

  /// gate 阻擋結果（NotFramework／SchemaUnconsumable／SchemaIncompatible）的
  /// 寫入口：遞增世代使進行中的載入失效，再寫入阻擋態
  /// （SPEC-003 §3.1〈導航跳轉與退出〉切換專案中止載入）。
  void applyGateBlock(DomainViewState blocked) {
    _generation++;
    _write(blocked);
  }

  /// 取消載入（SPEC-001 §1 載入中列：取消 → 未選專案）：Running 輪次一併
  /// 丟棄，進行中的載入結果作廢。
  void cancelLoading() {
    _generation++;
    if (ref.read(scanRoundProvider) is ScanRoundRunning) {
      ref.read(scanRoundProvider.notifier).discard('domain-cancel');
    }
    _write(const DomainUnset());
  }

  /// 「以 App 內建型別表檢視」：設降級旗標與徽章版本文字，丟棄現有輪次，
  /// 以內建型別表重掃並載入（SPEC-001 §1〈降級型別表〉）。
  Future<void> enterDegradedView({
    required String builtinVersion,
    required String projectVersion,
  }) {
    ref.read(degradedSchemaProvider.notifier).state = true;
    ref
        .read(degradedSchemaVersionsProvider.notifier)
        .state = DegradedSchemaVersions(
      builtinVersion: builtinVersion,
      projectVersion: projectVersion,
    );
    ref.read(scanRoundProvider.notifier).discard('degraded-view');
    return load();
  }

  Future<ScanRoundResult?> _obtainRound(int generation) async {
    final rounds = ref.read(scanRoundProvider.notifier);
    var round = await rounds.ensureRound();
    // 回 null 兩種：工作區不是 Ready（落未選專案），或等待中被丟棄（丟棄方
    // 已開新輪，接續之）。迴圈由世代與工作區守衛收束。
    while (round == null) {
      if (!_isCurrent(generation)) return null;
      if (ref.read(currentWorkspaceStateProvider) is! WorkspaceReady) {
        return null;
      }
      round = await rounds.ensureRound();
    }
    return round;
  }

  Future<DomainViewState> _stateOfRound(
    ScanRoundResult round, {
    required String? inferredVersion,
  }) async {
    final graph = round.graph;
    if (graph is! GraphBuildAvailable) return _unavailableGraph(graph);
    final event = graph.event;
    if (event.nodes.isEmpty) {
      return DomainEmpty(
        isDegraded: round.isDegraded,
        inferredVersion: inferredVersion,
      );
    }
    return DomainReady(
      mode: DomainMode.matrix,
      isDegraded: round.isDegraded,
      inferredVersion: inferredVersion,
    );
  }

  /// 建圖不可用（gate 每次重讀 JSON，建圖沿用快取輪次，兩者可不同步，故不是
  /// 不變式）：記 level 900 後落 SPEC-001 §1 的 schema 不相容阻擋態。專案版本
  /// 於此不可得，以 `null`（型別表版本無法判讀）呈現，不代位為其他值。
  Future<DomainViewState> _unavailableGraph(GraphBuildResult graph) async {
    final reason = graph is GraphBuildUnavailable ? graph.reason : null;
    final message = // i18n-exempt: 開發者 debug log
        'Domain 視圖收到建圖不可用的輪次（gate 與輪次不同步）：$reason';
    ref.read(domainViewLogSinkProvider)(message, level: 900);
    final appVersion = await ref.read(builtinSchemaVersionProvider.future);
    return DomainSchemaIncompatible(
      appVersion: appVersion,
      projectVersion: null,
    );
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _write(DomainViewState state) {
    ref.read(domainViewStateProvider.notifier).state = state;
  }
}
