/// UC Flow 視圖的狀態計算入口（設計約束同 domain/trace/gap_report：狀態
/// 注入而非等待真實解析，本票不接真實工作資料夾與圖建置）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/graph_status.dart';
import '../../app/selected_uc.dart';
import 'uc_flow_fixtures.dart';
import 'uc_flow_state.dart';

/// 專案內 UC 清單（`0.1.0-W1-003` fixture 驅動）；測試以
/// `overrideWithValue(const [])` 驗證「無 UC」分支。
final ucFlowUcListProvider = Provider<List<UcFlowFixtureUc>>(
  (ref) => UcFlowFixtures.ucList,
);

/// 目前畫面狀態：依 [graphBuiltProvider]、[ucFlowUcListProvider]、
/// [selectedUcProvider] 三者計算（SPEC-001 §2）。
final ucFlowStateProvider = Provider<UcFlowState>((ref) {
  final graphBuilt = ref.watch(graphBuiltProvider);
  if (!graphBuilt) {
    return const UcFlowProjectUnready();
  }
  final ucList = ref.watch(ucFlowUcListProvider);
  if (ucList.isEmpty) {
    return const UcFlowEmpty();
  }
  final selectedUcId = ref.watch(selectedUcProvider);
  if (selectedUcId == null) {
    return const UcFlowUcUnset();
  }
  final matches = ucList.where((uc) => uc.id == selectedUcId);
  final hasFlowStep = matches.isNotEmpty && matches.first.hasFlowStep;
  if (!hasFlowStep) {
    return UcFlowUnstructured(ucId: selectedUcId);
  }
  return UcFlowNormal(ucId: selectedUcId);
});
