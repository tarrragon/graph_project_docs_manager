/// 追溯視圖的狀態注入點（SPEC-003 §設計約束「狀態注入而非等待真實解析」）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trace_fixtures.dart';
import 'trace_state.dart';

/// 目前畫面狀態；預設正常態（[TraceabilityFixtures.normal]）。測試以
/// `overrideWith` 切換至鏈路斷裂／無提案，畫面直接渲染對應狀態，不經
/// 真實資料解析（本票範圍：只交狀態渲染，見 `trace_state.dart` 檔頭）。
final traceabilityStateProvider = StateProvider<TraceabilityScreenState>(
  (ref) => const TraceabilityNormal(TraceabilityFixtures.normal),
);

/// Ticket 清單（§4）是否已載入完成；預設 `false`（惰性載入尚未觸發）。
/// 為 `false` 時追溯視圖渲染 `action-traceability-goto-tickets`
/// （SPEC-003 §3.3，`0.1.0-W3-335.38` S-28）。
final ticketsLoadedProvider = StateProvider<bool>((ref) => false);

/// 目前展開的樹節點 id 集合（SPEC-004 §5.13 slot 契約：存於呼叫端
/// provider）。初始值依 [traceabilityStateProvider] 目前的樹計算（SPEC-003
/// §3.3〈生命週期〉：首次可見與切換專案後只顯示 PROP 層，含缺口的分支
/// 自動展開至缺口所在層）——藉由 `ref.watch` 依附狀態 provider，狀態改變
/// （即本票以 fixture 切換模擬的「切換專案」）會使本 provider 重新計算，
/// 天然滿足展開集合重設（`0.1.0-W3-335.38` S-28／S-29）。本票不接真實
/// 專案切換 listener，狀態改變仍需由呼叫端（測試或未來真實資料層）觸發。
final expandedTraceNodesProvider = StateProvider<Set<String>>(
  (ref) => _initialExpansion(ref.watch(traceabilityStateProvider)),
);

/// 計算首次渲染（或狀態重新計算）時應展開的節點 id 集合：只有「子樹含
/// 缺口且自身有子節點」的節點才需要展開——缺口節點本身為葉節點，展開
/// 它沒有意義；PROP 層若不含缺口分支則維持收合（用戶簽核 2026-09-14）。
Set<String> _initialExpansion(TraceabilityScreenState state) {
  final roots = switch (state) {
    TraceabilityNormal(:final roots) => roots,
    TraceabilityBroken(:final roots) => roots,
    TraceabilityNoProposal() => const <TraceNode>[],
    TraceabilityProjectUnready() => const <TraceNode>[],
  };
  final expand = <String>{};
  for (final root in roots) {
    _markGapAncestors(root, expand);
  }
  return expand;
}

/// 遞迴標記 [node] 的子樹是否含缺口；含缺口且有子節點者加入 [expand]。
/// 回傳值供上層呼叫判斷自身子樹是否亦含缺口。
bool _markGapAncestors(TraceNode node, Set<String> expand) {
  var subtreeHasGap = node.hasGap;
  for (final child in node.children) {
    if (_markGapAncestors(child, expand)) {
      subtreeHasGap = true;
    }
  }
  if (subtreeHasGap && node.children.isNotEmpty) {
    expand.add(node.id);
  }
  return subtreeHasGap;
}
