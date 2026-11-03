/// 跨畫面跳轉的帶目標意圖（性質同 `uc_flow_focus.dart`）：來源畫面寫入，
/// 目標畫面的 provider 消費後清空，使來源畫面不必 import 其他畫面功能目錄
/// （docs/system-layer.md §2.1）。
library;

import 'package:graph_project_docs_manager/state/state_holder.dart';

import 'router.dart';

/// 待顯示的節點 id（節點詳情消費）；`null` 代表無待定位目標。
final nodeDetailTargetProvider = stateHolderProvider<String?>((ref) => null);

/// 待定位的 ticket id（Ticket 清單消費）；`null` 代表無待定位目標。
final ticketListTargetProvider = stateHolderProvider<String?>((ref) => null);

/// 需求：[SPEC-003 §3.5] 帶目標跳至節點詳情：寫入意圖後 jump。
/// [nodeId] 為空時僅跳轉（無目標可寫）。
void jumpToNodeDetail(ProviderReader read, String? nodeId) {
  if (nodeId != null) read(nodeDetailTargetProvider.notifier).state = nodeId;
  navigateTo(read, AppDestination.nodeDetail, NavIntent.jump);
}
