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

/// 目前展開的樹節點 id 集合（SPEC-004 §5.13 slot 契約：存於呼叫端
/// provider）。切換專案時應清空——本票不接真實專案切換，故未在此監聽。
final expandedTraceNodesProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);
