/// 節點詳情的狀態注入點（設計約束同 trace／domain_view：狀態注入而非
/// 等待真實解析，`test/fixtures/corpus/` 收錄理由同源，本票不接真實
/// 節點解析）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'node_detail_fixtures.dart';
import 'node_detail_state.dart';

/// 目前畫面狀態；預設 `NodeDetailReady`（正常態，
/// [NodeDetailFixtures.normalNodeId]）。測試以 `overrideWith` 切換至其餘
/// 四個狀態，畫面直接渲染，不經真實資料夾選擇或節點解析。
final nodeDetailStateProvider = StateProvider<NodeDetailState>(
  (ref) => const NodeDetailReady(nodeId: NodeDetailFixtures.normalNodeId),
);
