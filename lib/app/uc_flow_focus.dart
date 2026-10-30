/// 跨畫面跳轉的定位意圖（性質同 `router.dart`）：破洞報告寫入，UC Flow 消費。
///
/// 下沉自 `screens/uc_flow`，使 gap_report 不必 import 其他畫面功能目錄
/// （docs/system-layer.md §2.1）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跳轉定位目標（SPEC-001 §5 主操作表事件類／flow 類兩列）：[ucId] 為目標 UC，
/// [stepId] 定位步驟、[eventId] 定位事件流小表列；兩者皆可缺。
class UcFlowFocus {
  const UcFlowFocus({required this.ucId, this.stepId, this.eventId});

  final String ucId;
  final String? stepId;
  final String? eventId;
}

/// 跳轉定位目標（破洞報告 flow 類／事件類項目寫入，UC Flow 消費）；`null`
/// 代表無待定位目標。
final ucFlowFocusProvider = StateProvider<UcFlowFocus?>((ref) => null);
