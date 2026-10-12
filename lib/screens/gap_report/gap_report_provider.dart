/// 破洞報告狀態機（SPEC-001 §5；SPEC-003 §3.5 生命週期、§2.5 取消契約）。
///
/// 資料來自共用掃描輪次（`scanRoundProvider`，0.5.0-W1-114.19）：首次可見
/// 時 `ensureRound()`，已有完成輪次直接呈現不重掃；「重新掃描」走
/// `rescan()`。輪次結果經 [gapReportStateFromRound] 投影為畫面狀態。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/schema/type_table_json_codec.dart';

import '../../app/graph_status.dart';
import '../../app/router.dart';
import '../../tokens/motion.dart';
import 'gap_report_models.dart';
import 'gap_report_round_state.dart';

const String _tag = 'GapReportNotifier';

/// 破洞報告畫面狀態機。
///
/// 生命週期（SPEC-003 §3.5）：首次可見自動進入掃描中，完成後轉無破洞、
/// 有破洞或無法判定破洞；再次可見不重新掃描；`rescan()` 對應
/// `action-gaps-rescan`，重新掃描時現有結果立即被骨架取代（不做兩段淡出
/// 淡入）。
class GapReportNotifier extends Notifier<GapReportState> {
  /// 目前這一輪掃描的世代號。`_scheduleScan()` 每次呼叫遞增；完成回呼
  /// 觸發時比對世代號，避免 `rescan()` 疊代排程時較舊一輪蓋過較新一輪的
  /// 結果（見 [_completeScan]）。
  int _scanGeneration = 0;

  /// 掃描是否已被觸發過一次（0.3.1-W3-122：觸發時機改為消費
  /// [firstVisibleProvider]）。額外防止「已見集合更新」觸發的重建
  /// rebuild build() 時，因 `firstVisibleProvider` 仍為 `true` 而重複呼叫
  /// [_scheduleScan]。
  bool _hasTriggeredScan = false;

  /// build() 上一次回傳的結果，供本次 rebuild 在「未觸發新一輪掃描」時
  /// 原樣回傳（不可讀取 [Notifier.state]：首次 build() 呼叫時該 getter
  /// 尚未初始化）。
  GapReportState _lastResult = const GapReportScanning();

  @override
  GapReportState build() {
    // SPEC-003 §3.5〈生命週期〉「首次可見但圖未建立」：不自動掃描，渲染
    // 共用「專案未就緒」定義；watch 使圖建立完成時 build() 重跑，依「首次
    // 可見且圖已建立」列重新判定（SPEC-001 §5 共用定義，`0.1.0-W3-335.37`
    // R9）。此分支刻意不寫入 [_lastResult]：`IndexedStack` 一次建構六頁
    // （SPEC-003 §2.8），本畫面即使未被選取也持續存在，圖建立狀態可能在
    // 已觸發過掃描後又反覆變化（例如切換專案）；若在此覆寫 `_lastResult`，
    // 圖重新建立後會錯誤地卡在本狀態，而非恢復已完成的掃描結果。
    final unreadyReason = ref.watch(projectUnreadyReasonProvider);
    if (unreadyReason != null) {
      return GapReportProjectUnready(unreadyReason);
    }
    // 0.3.1-W3-122：掃描觸發改掛在「首次可見 nav-page-gaps」，不再掛在
    // provider 的 build()。
    final isFirstVisible = ref.watch(firstVisibleProvider(AppDestination.gaps));
    if (isFirstVisible && !_hasTriggeredScan) {
      _hasTriggeredScan = true;
      // PM 處置 5：已有完成輪次即直接呈現，不重掃、不渲染骨架。
      final existing = _stateOfCompletedRound();
      if (existing != null) {
        _lastResult = existing;
        return existing;
      }
      _scheduleScan();
      _lastResult = const GapReportScanning();
      return _lastResult;
    }
    if (!_hasTriggeredScan) {
      // 圖已建立但尚未首次造訪 nav-page-gaps：本頁尚未被選取，`IndexedStack`
      // 仍在背景持續建構本 widget tree。若回傳 [GapReportScanning]，
      // `_ScanningView` 的 shimmer `AnimationController` 會在背景無限
      // `repeat()`，使涉及完整 App（`pumpApp`）的 `pumpAndSettle` 永不收斂
      // （0.3.1-W3-122 根因）。改用 [GapReportProjectUnready]（`EmptyState`，
      // 靜態無動畫）作為佔位——使用者尚未選取本頁，畫面文字不會被看見；
      // 選取當下 `isFirstVisible` 已於同一次 provider 重算中翻為 `true`。
      // reason 取 notSelected 僅為填滿必填欄位。
      return const GapReportProjectUnready(ProjectUnreadyReason.notSelected);
    }
    // 已觸發過掃描：保留目前結果，不因 firstVisibleProvider 的後續讀值
    // （例如已見集合寫回導致的 rebuild）重置狀態。
    return _lastResult;
  }

  /// `action-gaps-rescan`：現有結果立即被骨架取代，重新掃描（新輪次）。
  void rescan() {
    state = const GapReportScanning();
    _lastResult = state;
    _scheduleScan(forceNewRound: true);
  }

  /// `action-gaps-cancel-scan`（取消契約 C2、C4，SPEC-003 §2.5）。
  ///
  /// 按下後立即轉 `isCancelling`；`Motion.cancelDeadline` 內抵達
  /// `returnTo` 指定畫面，`returnTo` 為 `null` 時抵達 Domain 視圖
  /// （SPEC-001 §5「掃描中」列「取消 → 返回」）。進行中的輪次一併丟棄
  /// （C6 部分結果全數丟棄、C7 重來自 0）。C8 冪等：非掃描中或已在取消中
  /// 時不重複觸發。
  void cancelScan() {
    final current = state;
    if (current is! GapReportScanning || current.isCancelling) {
      return;
    }
    state = const GapReportScanning(isCancelling: true);
    _lastResult = state;
    if (ref.read(scanRoundProvider) is ScanRoundRunning) {
      ref.read(scanRoundProvider.notifier).discard('gap-report-cancel');
    }
    Future<void>.delayed(Motion.cancelDeadline, () {
      final returnTo = ref.read(returnToProvider);
      if (returnTo != null) {
        consumeReturnTo(ref.read);
      } else {
        navigateTo(ref.read, AppDestination.domain, NavIntent.rail);
      }
    });
  }

  /// 取得輪次結果並投影；完成時機取真實耗時與 `Motion.spinnerMinVisible`
  /// 的較長者（SPEC-003 §2.4 / §2.6，非疊加）。
  void _scheduleScan({bool forceNewRound = false}) {
    final generation = ++_scanGeneration;
    unawaited(_runScan(generation, forceNewRound));
  }

  Future<void> _runScan(int generation, bool forceNewRound) async {
    final minVisible = Future<void>.delayed(Motion.spinnerMinVisible);
    // build() 內同步呼叫會讓輪次擁有者在本 provider 建構期間改寫自身狀態，
    // Riverpod 禁止（debug 斷言）；讓出一個 microtask 待 build() 返回。
    await Future<void>.microtask(() {});
    final result = await _projectRound(forceNewRound);
    await minVisible;
    _completeScan(generation, result);
  }

  /// 輪次不可用（非 WorkspaceReady、等待中被丟棄）或失敗時回傳 `null`。
  Future<GapReportState?> _projectRound(bool forceNewRound) async {
    final rounds = ref.read(scanRoundProvider.notifier);
    try {
      final round = await (forceNewRound
          ? rounds.rescan()
          : rounds.ensureRound());
      if (round == null) return null;
      return gapReportStateFromRound(
        round,
        nonDomainPathsKey: _nonDomainPathsKeyOf(round),
      );
    } catch (e, st) {
      developer.log(
        '取得掃描輪次失敗', // i18n-exempt: 開發者 debug log
        name: _tag,
        level: 900,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  GapReportState? _stateOfCompletedRound() {
    final round = ref.read(scanRoundProvider);
    if (round is! ScanRoundCompleted) return null;
    return gapReportStateFromRound(
      round.result,
      nonDomainPathsKey: _nonDomainPathsKeyOf(round.result),
    );
  }

  /// EVT-CORPUS-005 說明的鍵名：專案型別表優先，缺欄回落內建表。清單檔
  /// 位置缺席時 005 不會產生，故取不到時的空字串不會被顯示。
  String _nonDomainPathsKeyOf(ScanRoundResult round) {
    final fromProject = round.schemaResolution.typeTable.nonDomainPathsKey;
    if (fromProject != null) return fromProject;
    final builtin = ref.read(builtinTrackingSchemaJsonProvider).valueOrNull;
    final fromBuiltin = builtin == null
        ? null
        : typeTableFromJson(builtin).nonDomainPathsKey;
    return fromBuiltin ?? '';
  }

  void _completeScan(int generation, GapReportState? result) {
    if (generation != _scanGeneration) {
      // 已被更新一輪的 rescan() 取代，本次（較舊）結果作廢。
      return;
    }
    final current = state;
    if (current is! GapReportScanning || current.isCancelling) {
      // 掃描期間已被 rescan() 改變狀態，或正在取消中，本次結果作廢。
      return;
    }
    if (result == null) {
      _showUnreadyAfterDiscardedRound();
      return;
    }
    state = result;
    _lastResult = state;
  }

  /// 輪次取不到（沒有可掃的工作區或輪次被丟棄）：不顯示任何舊輪結果，
  /// 改渲染「專案未就緒」，並讓下一次 build() 能重新觸發掃描。
  void _showUnreadyAfterDiscardedRound() {
    _hasTriggeredScan = false;
    state = GapReportProjectUnready(
      ref.read(projectUnreadyReasonProvider) ??
          ProjectUnreadyReason.notSelected,
    );
    _lastResult = state;
  }
}

/// 破洞報告畫面狀態 provider。
final gapReportProvider = NotifierProvider<GapReportNotifier, GapReportState>(
  GapReportNotifier.new,
);
