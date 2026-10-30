/// 破洞報告畫面狀態模型（SPEC-001 §5；SPEC-003 §3.5）。
///
/// 三個狀態密封為 [GapReportState]：掃描中、無破洞、有破洞（依類別分節，
/// 各節帶 N 個 [GapReportItem]）。0.1 不接真實掃描，資料由 provider 層以
/// 真實 repo 快照的缺 frontmatter 樣本驅動（見 gap_report_provider.dart）。
library;

import 'package:graph_project_docs_manager/diagnostics/parse_failure_gap.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';

import '../../app/graph_status.dart';

/// 破洞項指向的節點型別（SPEC-001 §5〈破洞項的主操作與次要操作〉，
/// `0.1.0-W3-335.19` 用戶裁示 2026-09-14）。點擊行為依此分派：
/// [ticket]／[otherNode]／[event] 三類跳轉，主操作外另有次要操作
/// `action-gaps-open-source-<itemId>`；[none] 主操作本身即開啟原始檔，
/// 不渲染次要操作。
enum GapItemPointerType {
  /// 指向 Ticket 節點。
  ticket,

  /// 指向其他圖節點（提案、規格、UC 等）。
  otherNode,

  /// 事件類（破洞類別 `orphan-event` 或 `event-declaration-mismatch`）。
  event,

  /// flow 類（SPEC-001 §5〈定案〉J2）：EVT-CORPUS-004 與 flow 四子類，
  /// 點擊選定 UC 並 jump 至 UC Flow；步驟定位由 `ucFlowFocusProvider`
  /// （`0.5.0-W1-114.18`）承接，本類只攜帶 [GapReportItem.flowUcId]／[GapReportItem.flowStepId]。
  flow,

  /// 無法指向任何節點。
  none,
}

/// 項目說明的識別名（SPEC-004 §4.0.6〈1.80 提案〉，一值對一個 ARB key；
/// 文案由 `gapItemDescriptionText` 查 l10n，投影層不產生在地化字串）。
enum GapDescriptionKind {
  parseNoFrontmatter,
  parseFrontmatterUnclosed,
  parseFrontmatterNotMap,
  parseYamlInvalid,
  parseUnreadableEncoding,
  parseUnreadablePermission,
  parseUnreadableMissing,
  flowBlockMalformed,
  nonDomainPathsYamlInvalid,
  nonDomainPathsKeyMissing,
  nonDomainPathsNotList,
  nonDomainPathsNonStringElements,
  danglingRefTargetMissing,
  danglingRefTargetDuplicated,
  malformedRefInvalidShape,
  malformedRefPatternMismatch,
  malformedRefSelfReference,
  duplicateId,
  multiSource,
  flowRefUnresolved,
  flowStepIdDuplicated,
  traversesUndeclared,
  traversesMissing,
  flowEventUnresolved,
  domainDeclaredTwice,
  orphanEventEmittedNotConsumed,
  orphanEventConsumedNotEmitted,
  eventConsumerUnmatched,
  eventProducerUnmatched,
}

/// 項目說明：[kind] 加 ARB 佔位符的原始值 [args]（欄位名、原始值不經 i18n）。
class GapItemDescription {
  const GapItemDescription(this.kind, [this.args = const {}]);

  final GapDescriptionKind kind;

  /// 佔位符名稱 → 值；清單類（paths／targets／bundles）在此保持 `List`，
  /// 連接符號依語系於格式化時決定。
  final Map<String, Object> args;
}

/// 單一破洞項：檔案路徑、行號（可缺）與指向節點屬性
/// （SPEC-001 §5「顯示」欄；SPEC-003 §3.5〈破洞項的指向節點〉）。
class GapReportItem {
  const GapReportItem({
    required this.id,
    required this.filePath,
    this.lineNumber,
    this.pointerType = GapItemPointerType.none,
    this.pointerNodeId,
    this.eventUcId,
    this.eventId,
    this.flowUcId,
    this.flowStepId,
    this.description,
    this.ambiguousTypes = const [],
    this.isOpenable = true,
  });

  /// 是否可開啟原始檔；降級項目（節點查不到、無路徑可開）為 `false`，
  /// 主操作不動作、不渲染開檔圖示，[filePath] 改放查不到的節點 ID 供顯示
  /// （出處：SPEC-001 v1.44 §5〈定案〉降級落點）。
  final bool isOpenable;

  /// 穩定識別碼，供 `card-gaps-<itemId>` 錨點使用（SPEC-003 §3.5、§2.9）。
  final String id;

  /// 檔案路徑（相對於工作資料夾），呼叫端以 [AppText.mono] 顯示。
  final String filePath;

  /// 破洞所在行號；`null` 時不顯示（SPEC-001 §5「有值時附」，
  /// `0.1.0-W3-335.37` R11：事件類破洞項無單一行號）。
  final int? lineNumber;

  /// 指向節點型別，預設 [GapItemPointerType.none]（沿用既有「開啟原始檔」
  /// 行為，向後相容既有呼叫端）。
  final GapItemPointerType pointerType;

  /// 指向的圖節點 ID（[GapItemPointerType.ticket]／[otherNode] 使用；
  /// [event] 類指向 EVT 節點 ID）；[GapItemPointerType.none] 時為 `null`。
  final String? pointerNodeId;

  /// 事件類破洞項預先解析出的選定 UC（多條 FlowStep 引用時取編號最小者，
  /// 由破洞分類邏輯決定，見 CLAUDE.md §6 待決；此欄只承接結果）。`null`
  /// 代表無任何 UC 引用該 EVT，跳轉行為改依 [otherNode] 處理
  /// （`0.1.0-W3-335.38` S-31）。僅 [GapItemPointerType.event] 使用。
  final String? eventUcId;

  /// 事件類破洞項的 EVT 節點 ID（只攜帶，本票不消費；事件列定位由
  /// `0.5.0-W1-114.18` 承接）。僅 [GapItemPointerType.event] 使用。
  final String? eventId;

  /// flow 類破洞項的選定 UC ID。僅 [GapItemPointerType.flow] 使用。
  final String? flowUcId;

  /// flow 類破洞項觸發缺陷的 step id 原值字串化；EVT-CORPUS-004 無步驟可
  /// 定位，為 `null`。只攜帶，不消費。
  final String? flowStepId;

  /// 項目說明（SPEC-004 §4.0.6〈1.80 提案〉）；既有 0.1 項目與事件類為 `null`。
  final GapItemDescription? description;

  /// EVT-CORPUS-003 `schemaAmbiguous` 為 `true` 時的候選型別，說明之後
  /// 另附 `gapParseTypeAmbiguous`；非歧義為空。
  final List<String> ambiguousTypes;

  /// 是否渲染次要操作 `action-gaps-open-source-<itemId>`（SPEC-001 §5：
  /// 有指向節點的前三類另有次要操作；無指向者主操作本身即開啟原始檔，
  /// 不重複提供次要操作）。
  bool get hasSecondaryOpenSource => pointerType != GapItemPointerType.none;
}

/// 依類別分節的破洞群組（SPEC-004 §3.6 §5「有破洞」列）。
class GapReportCategory {
  const GapReportCategory({required this.id, required this.items});

  /// 穩定識別碼，供 `expander-gaps-<category>` 錨點與 l10n 標籤查表使用。
  final String id;

  /// 本類別下的破洞項清單。
  final List<GapReportItem> items;
}

/// 破洞報告的畫面狀態（SPEC-001 §5）。
sealed class GapReportState {
  const GapReportState();
}

/// 專案未就緒：Domain 視圖尚未建立圖（SPEC-001 §5 共用定義，
/// `0.1.0-W3-335.37` R9）。對應 `EmptyState.page` + 前往 Domain 視圖動作。
class GapReportProjectUnready extends GapReportState {
  const GapReportProjectUnready(this.reason);

  /// Three-way reason (shared enum).
  final ProjectUnreadyReason reason;
}

/// 掃描中：對應 `LoadingState.skeleton`（版位 `sections`）。
class GapReportScanning extends GapReportState {
  const GapReportScanning({this.processedCount = 0, this.isCancelling = false});

  /// 已掃描項目計數（SPEC-003 §2.6 進度文字）。
  final int processedCount;

  /// 取消契約 C2：按下取消後 `Motion.feedback` 內轉為 `true`。
  final bool isCancelling;
}

/// 無破洞：對應 `EmptyState.page`。
class GapReportNoGaps extends GapReportState {
  const GapReportNoGaps({
    this.isPathPatternFromBuiltin = false,
    this.pathDeclaration,
  });

  /// 專案層宣告狀態（SPEC-001 §5）；`null` 不渲染宣告狀態行。
  final ProjectPathDeclaration? pathDeclaration;

  /// 路徑模式取自內建表（SPEC-001 §1〈路徑模式取自內建表〉）：為 `true`
  /// 時報告頁常駐 `badge-gaps-builtin-path-pattern`。
  final bool isPathPatternFromBuiltin;
}

/// 有破洞：對應 `Panel.scrollable`[`Section.collapsible` × N]。
class GapReportFound extends GapReportState {
  const GapReportFound(
    this.categories, {
    this.isPathPatternFromBuiltin = false,
    this.pathDeclaration,
  });

  final List<GapReportCategory> categories;

  /// 同 [GapReportNoGaps.pathDeclaration]。
  final ProjectPathDeclaration? pathDeclaration;

  /// 同 [GapReportNoGaps.isPathPatternFromBuiltin]。
  final bool isPathPatternFromBuiltin;
}

/// 無法判定破洞（SPEC-001 §5，`state-gaps-undeterminable`）：路徑模式查詢
/// 或建圖不可用。[categories] 為不依賴不可用資料的其餘類別，可為空；與
/// 「路徑模式取自內建表」旗標互斥，故不攜帶該旗標。
class GapReportUndeterminable extends GapReportState {
  const GapReportUndeterminable({
    required UndeterminedGapReason this.reason,
    this.categories = const [],
    this.pathDeclaration,
  });

  /// 掃描輪次拋出非預期例外（SPEC-001 v1.48，原因說明之三）：無原因碼，
  /// 無其餘類別。
  const GapReportUndeterminable.scanFailed()
    : reason = null,
      categories = const [],
      pathDeclaration = null;

  /// 同 [GapReportNoGaps.pathDeclaration]；掃描失敗時無輪次資料，為 `null`。
  final ProjectPathDeclaration? pathDeclaration;

  /// 原因碼（二選一，顯示文字由畫面經 l10n 投影）；`null` 代表
  /// [isScanFailure]。
  final UndeterminedGapReason? reason;

  /// 是否為掃描失敗（非預期例外）所致。
  bool get isScanFailure => reason == null;

  final List<GapReportCategory> categories;
}
