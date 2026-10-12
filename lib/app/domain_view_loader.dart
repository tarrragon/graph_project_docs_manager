/// Domain 視圖資料編排（0.5.0-W1-114.14）：gate 通過後經共用掃描輪次
/// （[scanRoundProvider]）取得建圖結果，推導 [DomainViewState]。
///
/// 流程：`DomainLoading` → 取得輪次 → 節點數 > 0 為 `DomainReady`（帶矩陣）、
/// 0 為 `DomainEmpty`。輪次取不到時（SPEC-001 §1 載入中列）：工作區非 Ready
/// 落「未選專案」，等待中被丟棄則接續新輪次（同破洞報告頁處置）。
///
/// 依賴方向：corpus／graph／layout 不得依賴本層；本層不另起掃描。
library;

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/domain_uc_columns.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_projection.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
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

  @override
  void build() {}

  /// gate 通過（或降級進入）後的資料載入。[inferredVersion] 為 gate 推定的
  /// 版本旗標，原樣帶入 `DomainReady`／`DomainEmpty`。
  Future<void> load({String? inferredVersion}) async {
    final generation = ++_generation;
    _write(const DomainLoading());
    // provider 的建構期間不可修改其他 provider；讓出一個 microtask。
    await Future<void>.microtask(() {});
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
      rethrow;
    }
    if (!_isCurrent(generation)) return;
    if (round == null) {
      _write(const DomainUnset());
      return;
    }
    _write(_stateOfRound(round, inferredVersion: inferredVersion));
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

  DomainViewState _stateOfRound(
    ScanRoundResult round, {
    required String? inferredVersion,
  }) {
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
      matrix: projectDomainMatrix(
        event: event,
        ucIds: orderedUcColumnIds(event.nodes),
      ),
    );
  }

  /// 建圖不可用時 gate 已擋下、Domain 視圖不會進入（SPEC-001 §1），屬不變式
  /// 違反：記 level 900 後 assert；release 落未選專案（不屬測試契約）。
  DomainViewState _unavailableGraph(GraphBuildResult graph) {
    final reason = graph is GraphBuildUnavailable ? graph.reason : null;
    // i18n-exempt: 開發者 debug log
    final message = 'Domain 視圖收到建圖不可用的輪次（gate 應已擋下）：$reason';
    ref.read(domainViewLogSinkProvider)(message, level: 900);
    assert(false, message);
    return const DomainUnset();
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _write(DomainViewState state) {
    ref.read(domainViewStateProvider.notifier).state = state;
  }
}
