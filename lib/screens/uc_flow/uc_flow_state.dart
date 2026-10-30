/// UC Flow 視圖（SPEC-001 §2）的畫面狀態模型。
///
/// 五個狀態列（專案未就緒／無 UC／尚未選定 UC／flow 未結構化／正常）依
/// [UcFlowState] 切換。選定 UC 是 App 層共用值（`app/selected_uc.dart`），
/// 不屬本頁狀態——「尚未選定 UC」與「flow 未結構化」／「正常」的分派
/// 由該值與 UC 是否含 FlowStep 共同決定，由畫面層
/// （`uc_flow_providers.dart`）計算，本檔只定資料形狀。
///
/// **本票已知缺件**（`0.1.0-W2-002` NeedsContext）：〈UC 選擇入口〉
/// （SPEC-004 §3.6，`ListRow.option` 變體）與事件流小表
/// （`TableRow.eventFlow` 變體、`AppDataTable.appendix` slot）皆為
/// SPEC-004 已核定但 `lib/components/` 尚未實作的元件庫缺件；下列三個
/// 狀態（[UcFlowUcUnset]／[UcFlowUnstructured]／[UcFlowNormal]）因此無法
/// 依 SPEC-004 §3.6 句型完整組成，本票只交出狀態模型，畫面渲染見
/// `uc_flow_screen.dart` 檔頭說明。
library;

import '../../app/graph_status.dart';

/// 單一步驟（0.5.0-W1-114.18：由 Graph `flowOf` 子圖投影，或測試 fixture 直接給定）。
class UcFlowStepItem {
  const UcFlowStepItem({
    required this.label,
    required this.domain,
    this.id,
    this.emits = const [],
    this.consumes = const [],
  });

  /// 步驟 id 原值字串化；缺 id 為 `null`（無法被跳轉定位）。
  final String? id;
  final String label;
  final String domain;
  final List<String> emits;
  final List<String> consumes;
}

/// EVT 節點 frontmatter 宣告的對側 domain（SPEC-001 §2〈事件流小表〉
/// 「本 UC 外」列）：[producers] 供缺發出側、[consumers] 供缺消費側時附帶。
/// 值為宣告原字面（含本地保留字 `presentation`），空清單代表未宣告。
class UcFlowEventSides {
  const UcFlowEventSides({
    this.producers = const [],
    this.consumers = const [],
  });

  final List<String> producers;
  final List<String> consumers;
}

/// UC 清單項：id、標題、原始檔路徑、步驟，以及 flow 區塊是否解析失敗
/// （EVT-CORPUS-004，決定未結構化態用哪一則訊息）。
class UcFlowUcItem {
  const UcFlowUcItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.steps = const [],
    this.isFlowParseFailed = false,
    this.eventSides = const {},
  });

  final String id;
  final String title;
  final String filePath;
  final List<UcFlowStepItem> steps;

  /// 以 EVT id 為鍵的對側宣告；找不到 EVT 節點的事件不在其中。
  final Map<String, UcFlowEventSides> eventSides;
  final bool isFlowParseFailed;

  /// 含結構化 flow：步驟清單非空。
  bool get hasFlowStep => steps.isNotEmpty;
}

/// UC Flow 視圖的五個畫面狀態（SPEC-001 §2）。
sealed class UcFlowState {
  const UcFlowState();
}

/// 專案未就緒：`EmptyState.page`（SPEC-001 §5 之後共用定義）。
class UcFlowProjectUnready extends UcFlowState {
  const UcFlowProjectUnready(this.reason);

  /// Three-way reason (shared enum).
  final ProjectUnreadyReason reason;
}

/// 無 UC：`EmptyState.page`（專案無 UC 型別節點）。
class UcFlowEmpty extends UcFlowState {
  const UcFlowEmpty();
}

/// 尚未選定 UC：專案有 UC 節點，選定 UC 為空。
class UcFlowUcUnset extends UcFlowState {
  const UcFlowUcUnset();
}

/// flow 未結構化：已選定的 UC 無 FlowStep。
class UcFlowUnstructured extends UcFlowState {
  const UcFlowUnstructured({required this.ucId, this.isParseFailed = false});

  /// 已選定的 UC id。
  final String ucId;

  /// 該 UC 的 flow 區塊皆解析失敗：訊息改用 `flowParseFailedMessage`。
  final bool isParseFailed;
}

/// 正常：已選定一條含結構化 flow 的 UC。
class UcFlowNormal extends UcFlowState {
  const UcFlowNormal({required this.ucId});

  /// 已選定的 UC id。
  final String ucId;
}
