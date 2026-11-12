// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '專案文件流';

  @override
  String get chooseWorkspaceFolder => '選擇工作資料夾';

  @override
  String get folderAccessRationale =>
      '請選擇一個資料夾，App 將在其中讀取與編輯文件。此授權會被記住，下次開啟不需重選。';

  @override
  String workspaceUnavailable(String reason) {
    return '無法存取先前的資料夾：$reason';
  }

  @override
  String folderUnavailableMessage(String reason) {
    return '資料夾無法使用：$reason';
  }

  @override
  String get workspaceNotRemembered => '已選定，但下次啟動需重新選擇';

  @override
  String get chooseFolderUnavailableMessage => '無法開啟資料夾選取面板，應用程式可能安裝不完整';

  @override
  String get domainLoading => '正在解析圖譜節點…';

  @override
  String get cancelLoadingAction => '取消載入';

  @override
  String get emptyGraphMessage => '此專案尚無圖譜節點';

  @override
  String get notFrameworkProjectMessage =>
      '此資料夾缺少本框架所需的設定檔（.claude/VERSION 與型別表皆缺），不是使用本框架的專案';

  @override
  String get notFrameworkProjectExplanation =>
      '本 App 需要 .claude/VERSION 或型別表（.claude/skills/doc/doc_system/core/tracking_schema.json）其中一項存在，才能判讀此專案的框架版本';

  @override
  String schemaUnconsumableMessage(String version) {
    return '此專案的框架版本（$version）早於圖譜型別表的機器可讀匯出';
  }

  @override
  String schemaUnconsumableDegradedExplanation(String builtinVersion) {
    return '可改用 App 內建型別表（v$builtinVersion）檢視，B 層邊不渲染';
  }

  @override
  String schemaIncompatibleMessage(String appVersion, String projectVersion) {
    return 'App 支援的 schema 版本為 $appVersion，此專案為 $projectVersion，版本不相容';
  }

  @override
  String get schemaVersionUnreadableMessage => '無法判讀此專案型別表的版本，請在該專案重新產生型別表後再開啟';

  @override
  String get emptyUcMessage => '此專案尚無 UC 節點';

  @override
  String get flowUnstructuredMessage => '尚未填寫結構化 flow';

  @override
  String get flowParseFailedMessage => '此 UC 的 flow 區塊解析失敗，請開啟來源檔修正';

  @override
  String get swimlaneFlowParseFailedHint => '此 UC 有 flow 區塊解析失敗，泳道只呈現第一個合法區塊';

  @override
  String get ucUnsetPrompt => '選擇一條 UC 以檢視 flow';

  @override
  String get ucSelectorTitle => '選擇 UC';

  @override
  String get emptyProposalMessage => '此專案尚無提案';

  @override
  String get ticketsUnassignedSection => '未歸屬';

  @override
  String get ticketsNoTopicFilesNotice => '此專案無主題檔';

  @override
  String get emptyTicketsMessage => '此專案尚無 ticket';

  @override
  String corruptedTicketsBadge(int count) {
    return '$count 張損壞';
  }

  @override
  String get gapReportScanning => '正在掃描破洞…';

  @override
  String get cancelScanAction => '取消';

  @override
  String get noGapsMessage => '未偵測到破洞';

  @override
  String get noGapsScanScope => '已掃描全部節點與邊';

  @override
  String get sourceFileMissingMessage => '原始檔已不存在';

  @override
  String lastKnownPathLabel(String path) {
    return '最後已知路徑：$path';
  }

  @override
  String get switcherChooseFolderPrompt => '選擇資料夾…';

  @override
  String get switcherChooseOtherFolder => '選擇其他';

  @override
  String get navDomain => 'Domain 視圖';

  @override
  String get navUcFlow => 'UC Flow';

  @override
  String get navTraceability => '追溯視圖';

  @override
  String get navTickets => 'Ticket 清單';

  @override
  String get navGaps => '破洞報告';

  @override
  String get navNodeDetail => '節點詳情';

  @override
  String get projectSwitcherEntryLabel => '切換專案';

  @override
  String get domainSwitchToMatrixAction => '切換至矩陣';

  @override
  String get domainSwitchToSwimlaneAction => '切換至泳道';

  @override
  String get ticketsSwitchToListAction => '切換至列表';

  @override
  String get ticketsSwitchToTopicAction => '切換至主題';

  @override
  String get openDocsFolderAction => '開啟 docs 目錄';

  @override
  String get openedExternallyMessage => '已在外部開啟';

  @override
  String get viewSchemaDetailAction => '檢視詳情';

  @override
  String get useBuiltinSchemaAction => '以 App 內建型別表檢視';

  @override
  String get gotoGapsReportAction => '前往破洞報告';

  @override
  String get openSourceFileAction => '開啟原始檔';

  @override
  String get sourceFileNotFoundSnackbarMessage => '找不到檔案';

  @override
  String get externalOpenFailedMessage => '無法以系統預設方式開啟';

  @override
  String get refreshAction => '重新整理';

  @override
  String get viewRelationsAction => '檢視關聯';

  @override
  String get backAction => '返回';

  @override
  String get startLoadAction => '開始載入';

  @override
  String get rescanAction => '重新掃描';

  @override
  String get cancelInProgressAction => '取消中';

  @override
  String domainLoadingProcessedCount(int count) {
    return '已處理 $count 個節點';
  }

  @override
  String gapsScanningProcessedCount(int count) {
    return '已掃描 $count 項';
  }

  @override
  String get noNodeSelectedMessage => '尚未選取節點';

  @override
  String get gotoTraceabilityAction => '前往追溯視圖';

  @override
  String projectUnavailableReasonLabel(String reason) {
    return '無法使用：$reason';
  }

  @override
  String get switcherChooseFolderUnavailableReason => '無法開啟資料夾選取面板，應用程式可能安裝不完整';

  @override
  String switcherFolderUnavailableReason(String reason) {
    return '資料夾無法使用：$reason';
  }

  @override
  String get probeTimeoutReason => '可能是磁碟未掛載';

  @override
  String get probingReason => '檢查中…';

  @override
  String get sourceFileStillMissingMessage => '檔案仍不存在';

  @override
  String get sourceFileUnparsableMessage => '檔案存在但無法解析，詳見破洞報告';

  @override
  String get expanderLabel => '展開或收合';

  @override
  String get searchPlaceholder => '搜尋';

  @override
  String get fieldEmptyValue => '未填';

  @override
  String get searchClearAction => '清除搜尋';

  @override
  String get filterAllOption => '全部';

  @override
  String filterA11yLabel(String label, String value) {
    return '$label 篩選，目前：$value';
  }

  @override
  String get filterStatusLabel => '狀態';

  @override
  String get filterPriorityLabel => '優先';

  @override
  String sortA11yLabel(String label, String order) {
    return '$label，可排序，目前：$order';
  }

  @override
  String get sortNone => '未排序';

  @override
  String get sortAscending => '遞增';

  @override
  String get sortDescending => '遞減';

  @override
  String get columnId => 'ID';

  @override
  String get columnTitle => '標題';

  @override
  String get columnStatus => '狀態';

  @override
  String get columnPriority => '優先';

  @override
  String get columnBlockedBy => 'blockedBy';

  @override
  String get columnStep => '步驟';

  @override
  String get columnDomain => 'Domain';

  @override
  String get columnEvents => '發送事件';

  @override
  String matrixCellA11yLabel(String domain, String uc, String relation) {
    return '$domain × $uc：$relation';
  }

  @override
  String get legendDirect => '直接貫穿';

  @override
  String get legendIndirect => '間接依賴';

  @override
  String get legendNone => '無關';

  @override
  String matrixSubtotalA11yLabel(int count) {
    return '小計 $count';
  }

  @override
  String laneA11yLabel(String name) {
    return '泳道 $name';
  }

  @override
  String get laneNodeActive => '作用中';

  @override
  String get laneNodeInactive => '非作用中';

  @override
  String stepNumberA11yLabel(int number) {
    return '步驟 $number';
  }

  @override
  String get gapMarkerLabel => '缺口';

  @override
  String get damagedEdgeMarkerLabel => '邊損壞';

  @override
  String get damagedDetailMarkerLabel => '詳情損壞';

  @override
  String relationItemA11yLabel(String id) {
    return '關聯節點 $id';
  }

  @override
  String get relationProposedLabel => '暫定';

  @override
  String relationItemProposedA11yLabel(String id) {
    return '關聯節點 $id，暫定邊，形狀可能變動';
  }

  @override
  String get swimlaneScreenLaneName => '畫面';

  @override
  String get swimlaneUnplacedLaneName => '未定位';

  @override
  String get currentProjectA11yLabel => '目前專案';

  @override
  String get degradedSchemaShortLabel => '內建型別表';

  @override
  String projectSummaryLabel(int nodes, int tickets) {
    return '$nodes 節點 · $tickets 票';
  }

  @override
  String healthBadgeA11yLabel(int count) {
    return '$count 個問題';
  }

  @override
  String get switcherTitle => '切換專案';

  @override
  String get schemaKnownRangeLabel => 'App 已知版本範圍';

  @override
  String schemaKnownRangeValue(String appVersion) {
    return '不高於 $appVersion';
  }

  @override
  String treeDepthA11yLabel(int depth) {
    return '第 $depth 層';
  }

  @override
  String get openExternallyA11yLabel => '在外部開啟';

  @override
  String get loadingSkeletonA11yLabel => '載入中';

  @override
  String get cellDetailPrompt => '點選一格檢視詳情';

  @override
  String get cellDetailNotInvolved => '此 domain 不參與此 UC';

  @override
  String get cellDetailCloseAction => '關閉';

  @override
  String get cellDetailViewInSwimlaneAction => '在泳道中檢視';

  @override
  String get swimlaneUcUnsetPrompt => '尚未選定 UC：請在矩陣點選一格，或至 UC Flow 視圖選擇一條 UC';

  @override
  String get swimlaneProjectionPendingPrompt => '泳道投影準備中：掃描完成後即顯示此 UC 的步驟';

  @override
  String swimlanePanelTitle(String ucId, String ucTitle) {
    return '$ucId $ucTitle';
  }

  @override
  String degradedSchemaBadgeLabel(
    String builtinVersion,
    String projectVersion,
  ) {
    return '降級型別表（內建 $builtinVersion / 專案 $projectVersion）';
  }

  @override
  String inferredVersionBadgeLabel(String inferredVersion) {
    return '版本推定自型別表 (v$inferredVersion)';
  }

  @override
  String get modeMatrixLabel => '矩陣';

  @override
  String get modeSwimlaneLabel => '泳道';

  @override
  String get modeListLabel => '列表';

  @override
  String get modeTopicLabel => '主題';

  @override
  String ticketsSummaryLabel(int from, int to, int total) {
    return '顯示 $from–$to / 共 $total';
  }

  @override
  String get ticketsVirtualScrollNote => '虛擬捲動，不分頁';

  @override
  String topicSectionSummary(int count, String priority) {
    return '($count tasks, 最高優先級=$priority)';
  }

  @override
  String gapSectionCount(int count) {
    return '$count 項';
  }

  @override
  String get gapCategoryParseFailure => '解析失敗';

  @override
  String get gapCategoryFlowBlockMalformed => 'flow 區塊解析失敗';

  @override
  String get gapCategoryNonDomainPathsMalformed => '非 domain 路徑清單格式錯誤';

  @override
  String get gapCategoryTopicFilesMalformed => '主題檔無法讀取或不一致';

  @override
  String get gapTopicFilesUnreadable => '無法讀取主題檔';

  @override
  String gapTopicFilesUnregisteredTopics(int count) {
    return '$count 個主題名不在主題清單';
  }

  @override
  String get gapCategoryGraphDefect => '圖結構缺陷';

  @override
  String get gapCategoryGraphDefectFlow => 'flow 結構缺陷';

  @override
  String get gapParseNoFrontmatter => '缺少 frontmatter';

  @override
  String get gapParseFrontmatterUnclosed => 'frontmatter 未閉合';

  @override
  String get gapParseFrontmatterNotMap => 'frontmatter 為空或不是鍵值對映';

  @override
  String get gapParseYamlInvalid => 'frontmatter 的 YAML 無法解析';

  @override
  String get gapParseUnreadableEncoding => '無法讀取檔案：編碼錯誤';

  @override
  String get gapParseUnreadablePermission => '無法讀取檔案：沒有權限';

  @override
  String get gapParseUnreadableMissing => '無法讀取檔案：檔案已消失';

  @override
  String gapParseTypeAmbiguous(String types) {
    return '歸屬型別不明，候選：$types';
  }

  @override
  String get gapFlowBlockMalformed => 'flow 區塊解析失敗，請修正後重新掃描';

  @override
  String gapNonDomainPathsNonStringElements(int count) {
    return '清單內 $count 個非字串元素';
  }

  @override
  String get gapNonDomainPathsYamlInvalid => '清單檔的 YAML 無法解析';

  @override
  String gapNonDomainPathsKeyMissing(String key) {
    return '清單檔缺少 $key 鍵';
  }

  @override
  String gapNonDomainPathsNotList(String key) {
    return '清單檔中 $key 的值不是清單';
  }

  @override
  String gapDanglingRefTargetMissing(String field, String value) {
    return '$field 指向的 $value 不存在';
  }

  @override
  String gapDanglingRefTargetDuplicated(String field, String value) {
    return '$field 指向的 $value 對應多個節點';
  }

  @override
  String gapMalformedRefInvalidShape(String field, String value) {
    return '$field 的值 $value 格式不正確';
  }

  @override
  String gapMalformedRefPatternMismatch(String field, String value) {
    return '$field 的值 $value 不符合 ID 格式';
  }

  @override
  String gapMalformedRefSelfReference(String field) {
    return '$field 指向自己';
  }

  @override
  String gapDuplicateId(String id, int count, String paths) {
    return 'ID $id 出現在 $count 個檔案：$paths';
  }

  @override
  String gapMultiSource(String edgeType, String targets) {
    return '$edgeType 只能指向一個終點，目前指向 $targets';
  }

  @override
  String gapFlowEventUnresolved(String stepId, String field, String value) {
    return '步驟 $stepId 的 $field 引用的事件不存在：$value';
  }

  @override
  String gapFlowRefUnresolved(String stepId, String field, String value) {
    return '步驟 $stepId 的 $field 無法解析：$value';
  }

  @override
  String gapFlowStepIdDuplicated(String stepId) {
    return '步驟 ID $stepId 在此 UC 內重複';
  }

  @override
  String gapTraversesUndeclared(String stepId, String value) {
    return '步驟 $stepId 的 traverses 含未宣告的 domain：$value';
  }

  @override
  String gapTraversesMissing(String stepId) {
    return '步驟 $stepId 缺少 traverses 欄位';
  }

  @override
  String gapDomainDeclaredTwice(String domain, String bundles) {
    return 'domain $domain 被多個 DomainBundle 宣告：$bundles';
  }

  @override
  String gapIsolatedNode(String nodeType, String nodeId) {
    return '$nodeType $nodeId 沒有任何關聯';
  }

  @override
  String gapMissingRequiredEdge(
    String nodeType,
    String nodeId,
    String edgeType,
  ) {
    return '$nodeType $nodeId 缺少必要的關聯：$edgeType';
  }

  @override
  String gapMissingRequiredEdgeAnyOf(
    String nodeType,
    String nodeId,
    String edgeTypes,
  ) {
    return '$nodeType $nodeId 至少需要一種關聯：$edgeTypes';
  }

  @override
  String get gapCategoryOrphanEvent => '孤立事件';

  @override
  String get gapCategoryEventDeclarationMismatch => '事件宣告與 flow 不符';

  @override
  String gapItemLineLabel(int lineNumber) {
    return '第 $lineNumber 行';
  }

  @override
  String get scanCompleteNotificationTitle => '破洞掃描完成';

  @override
  String scanCompleteNotificationBody(int count) {
    return '偵測到 $count 個破洞';
  }

  @override
  String get scanCompleteNoGapsNotificationBody => '未偵測到破洞';

  @override
  String scanCompleteSnackbarMessage(int count) {
    return '掃描完成，偵測到 $count 個破洞';
  }

  @override
  String get scanCompleteNoGapsSnackbarMessage => '掃描完成，未偵測到破洞';

  @override
  String get scanCompleteUndeterminableNotificationBody => '無法判定破洞，原因請見破洞報告';

  @override
  String get scanCompleteUndeterminableSnackbarMessage => '掃描結束，無法判定破洞';

  @override
  String get scanCompleteWatchNotificationTitle => '破洞報告已更新';

  @override
  String scanCompleteWatchNotificationBody(int count) {
    return '檔案變動後重新掃描，目前 $count 個破洞';
  }

  @override
  String get gapsUndeterminableReasonScanFailed => '掃描時發生非預期錯誤，無法判斷破洞；請重新掃描';

  @override
  String get viewGapsAction => '檢視';

  @override
  String get projectUnreadyReasonNotSelected => '尚未選擇專案';

  @override
  String get projectUnreadyReasonLoading => '圖譜載入中';

  @override
  String get projectUnreadyReasonIncompatible => '此專案不適用本 App';

  @override
  String get projectUnreadyReasonLoadFailed => '圖譜載入失敗';

  @override
  String get domainLoadFailedMessage => '掃描此專案時發生非預期錯誤，無法載入圖譜';

  @override
  String domainGraphUnavailableMessage(String appVersion) {
    return '此專案的型別表版本不在 App 已知範圍內（不高於 $appVersion），最近一次掃描無法建立圖譜；型別表修正或重新產生之前，重新掃描仍會得到相同結果';
  }

  @override
  String traceabilityGraphUnavailableMessage(String appVersion) {
    return '此專案的型別表版本不在 App 已知範圍內（不高於 $appVersion），最近一次掃描無法建立圖譜，追溯視圖暫無法顯示；可至 Domain 視圖重新掃描';
  }

  @override
  String nodeDetailGraphUnavailableMessage(String appVersion) {
    return '此專案的型別表版本不在 App 已知範圍內（不高於 $appVersion），最近一次掃描無法建立圖譜，節點詳情暫無法顯示；可至 Domain 視圖重新掃描';
  }

  @override
  String nodeDetailNodeAbsentMessage(String nodeId) {
    return '節點 $nodeId 不在目前的圖上';
  }

  @override
  String get nodeDetailNodeAbsentHint => '可能已被刪除、改了 ID，或因 ID 重複而被排除';

  @override
  String get domainGraphUnavailableScanning => '掃描中';

  @override
  String get reloadAction => '重新載入';

  @override
  String get gotoDomainViewAction => '前往 Domain 視圖';

  @override
  String traceabilityNoDownstream(String layer) {
    return '（尚無 $layer）';
  }

  @override
  String get ticketsFiltersClearedSnackbarMessage => '已清除搜尋與篩選以顯示目標 ticket';

  @override
  String get ticketsTargetNotFoundMessage => '找不到該 ticket，可能已被移除';

  @override
  String get undoAction => '復原';

  @override
  String get columnEvent => '事件';

  @override
  String get columnEmitter => '發出';

  @override
  String get columnConsumer => '消費';

  @override
  String eventFlowStepDomain(String step, String domain) {
    return '$step · $domain';
  }

  @override
  String eventOutsideUc(String domains) {
    return '本 UC 外（$domains）';
  }

  @override
  String get eventOutsideUcBare => '本 UC 外';

  @override
  String get orphanEventMarkerLabel => '孤立事件';

  @override
  String get builtinPathPatternBadgeLabel => '路徑模式取自 App 內建型別表';

  @override
  String get gapsUndeterminableTitle => '無法判定破洞';

  @override
  String get gapsUndeterminableReasonVersionOutOfRange =>
      '專案型別表版本不在 App 已知範圍內，且缺少路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出';

  @override
  String get gapsUndeterminableReasonNoPathPattern =>
      '專案型別表與 App 內建型別表都沒有路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出';

  @override
  String pathDeclarationIncompleteLine(String detail, int count) {
    return '路徑宣告不完整：$detail（影響 $count 條路徑）';
  }

  @override
  String pathDeclarationBundlesPartial(int declared, int total) {
    return '已宣告 $declared／$total 個 domain';
  }

  @override
  String pathDeclarationBundlesMalformed(int count) {
    return '$count 個 domain 的路徑宣告格式錯誤';
  }

  @override
  String get pathDeclarationNonDomainMissing => '缺非 domain 路徑清單';

  @override
  String get pathDeclarationNoBundles => '尚未宣告任何 domain';

  @override
  String get pathDeclarationNoneLine => '本專案未宣告路徑';

  @override
  String get pathDeclarationNonDomainMalformed => '非 domain 路徑清單格式錯誤';

  @override
  String get gapOrphanEventEmittedNotConsumed =>
      '有步驟發出此事件，但沒有步驟消費，consumers 也未宣告';

  @override
  String get gapOrphanEventConsumedNotEmitted =>
      '有步驟消費此事件，但沒有步驟發出，producers 也未宣告';

  @override
  String gapEventConsumerUnmatched(String domain) {
    return 'consumers 宣告了 $domain，但沒有對應的步驟消費此事件';
  }

  @override
  String gapEventProducerUnmatched(String domain) {
    return 'producers 宣告了 $domain，但沒有對應的步驟發出此事件';
  }

  @override
  String get openedWithoutEditorMessage => '所選編輯器無法使用，已以系統預設方式開啟';

  @override
  String get preferencesTitle => '偏好設定';

  @override
  String get preferencesEditorSystemOption => '系統預設（不定位）';

  @override
  String get preferencesNoEditorsExplanation =>
      '本機未找到支援定位至行號的編輯器。支援的編輯器：VS Code、VS Code Insiders、Cursor、Zed';

  @override
  String writeLogNavA11yLabel(String label, int count) {
    return '$label，$count 筆失敗';
  }

  @override
  String get navHistory => '變更記錄';

  @override
  String get historyLoading => '正在讀取 git 歷史';

  @override
  String historyLoadingProcessedCount(int count) {
    return '已處理 $count 個 commit';
  }

  @override
  String get historyPeriodDefaultLabel => '預設期間';

  @override
  String get historyPeriodRecent30Label => '最近 30 天';

  @override
  String get historyPeriodAllLabel => '全部歷史';

  @override
  String historyPeriodSelectA11yHint(String period) {
    return '以「$period」篩選事件';
  }

  @override
  String historyPeriodSinceTag(String tag) {
    return '$tag 之後';
  }

  @override
  String historyPeriodSummary(String period, int count) {
    return '$period · $count 筆事件';
  }

  @override
  String get historyIncludeTicketCreatedLabel => '包含 ticket 建檔';

  @override
  String historyShallowCloneBadge(String boundaryDate) {
    return '歷史不完整：早於 $boundaryDate 的變更不在其中';
  }

  @override
  String get columnChange => '變動';

  @override
  String get columnEdgeType => '邊型';

  @override
  String get columnDeclarer => '宣告端';

  @override
  String get columnCounterpart => '對端';

  @override
  String get columnCommit => 'Commit';

  @override
  String get columnDate => '日期';

  @override
  String get columnAuthorMessage => '作者與訊息';

  @override
  String get historyEventAdded => '新增';

  @override
  String get historyEventRemoved => '移除';

  @override
  String historyEventAuthorMessage(String author, String subject) {
    return '$author：$subject';
  }

  @override
  String historyEventA11yLabel(
    String change,
    String edgeType,
    String declarer,
    String counterpart,
    String hash,
    String date,
    String author,
    String subject,
  ) {
    return '$change $edgeType，$declarer 至 $counterpart，commit $hash，$date，$author：$subject';
  }

  @override
  String get historyEmptyMessage => '此期間沒有關係變動';

  @override
  String get historyShowAllAction => '顯示全部歷史';

  @override
  String get historyNoCommitsMessage => '此專案尚無 commit';

  @override
  String get historyNotGitMessage => '此專案不是 git repo，無法讀取變更記錄';

  @override
  String get historyGitMissingMessage => '找不到 git 指令';

  @override
  String get historyGitMissingExplanation => '請安裝 git，或確認 git 位於 PATH 中';

  @override
  String get historyRecheckAction => '重新檢查';

  @override
  String get historyLoadFailedMessage => '讀取 git 歷史失敗';

  @override
  String historyLoadFailedDetail(String reason) {
    return '原因：$reason';
  }

  @override
  String get retryAction => '重試';

  @override
  String get historyCancelledMessage => '已取消讀取';

  @override
  String get historyReloadAction => '重新讀取';

  @override
  String preferencesEditorAppliedMessage(String editor) {
    return '已改用 $editor，下次開啟原始檔時生效';
  }

  @override
  String get preferencesEditorSaveFailedMessage => '無法儲存編輯器設定';

  @override
  String get sidebarSettingsLabel => '設定';

  @override
  String get keyboardShortcutsTitle => '鍵盤快捷鍵';

  @override
  String get shortcutOpenPreferencesAction => '開啟偏好設定';

  @override
  String get shortcutCloseSwitcherAction => '收合專案切換浮層';

  @override
  String get shortcutCloseSchemaDetailAction => '收合型別表詳情面板';

  @override
  String get shortcutClearCellAction => '清除矩陣的已選格';

  @override
  String get shortcutCloseFilterMenuAction => '收合篩選選單';

  @override
  String get shortcutClosePanelAction => '關閉偏好設定或鍵盤快捷鍵面板';

  @override
  String get shortcutMoveFocusAction => '依序移動焦點（Shift+Tab 反向）';

  @override
  String get shortcutActivateAction => '執行已聚焦的按鈕或項目';

  @override
  String get shortcutOpenFilterMenuAction => '展開已聚焦的篩選選單';

  @override
  String get shortcutMoveInFilterMenuAction => '在篩選選單的選項間移動';

  @override
  String get shortcutContextAnywhere => '任何畫面';

  @override
  String get shortcutContextSwitcherOpen => '專案切換浮層展開時';

  @override
  String get shortcutContextSchemaDetailOpen => 'Domain 視圖的型別表詳情面板展開時';

  @override
  String get shortcutContextCellSelected => 'Domain 視圖矩陣有已選格，且焦點在矩陣內時';

  @override
  String get shortcutContextFilterMenuOpen => 'Ticket 清單的篩選選單展開時';

  @override
  String get shortcutContextPanelOpen => '任一面板開啟時';

  @override
  String get shortcutContextFilterFocused => 'Ticket 清單的篩選按鈕取得焦點時';

  @override
  String shortcutRowA11yLabel(String keys, String action, String context) {
    return '$keys：$action，$context';
  }

  @override
  String get sourceChainTitle => '來源鏈';

  @override
  String sourceChainNoUpstream(String layer) {
    return '（缺上游 $layer）';
  }

  @override
  String get editDiscardAndReloadAction => '放棄並重讀';

  @override
  String get editBannerExternallyModifiedWarning =>
      '這個檔案已在 App 外被修改。未送出的值仍保留，放棄並重讀可載入目前的檔案內容';

  @override
  String get editBannerExternallyModifiedBlocked =>
      '這個檔案已在 App 外被修改，這次寫入沒有執行。放棄並重讀後才能繼續編輯';

  @override
  String get editBannerReloadFailed => '無法重新讀取這個檔案，請再按一次放棄並重讀';

  @override
  String get readonlyWorkspaceNotGitBadge => '此資料夾不是 git repo，無法在 App 內編輯';

  @override
  String get readonlyWorkspaceGitMissingBadge => '找不到 git，無法在 App 內編輯';

  @override
  String get writeLogTitle => '寫入清單';

  @override
  String get nodeDetailBodyUnavailableMessage =>
      '無法顯示本文：檔案在上次掃描後已改動或無法讀取，下次掃描完成後會更新';

  @override
  String fieldValueOutOfDomain(String value) {
    return '目前值「$value」不在可選值內';
  }

  @override
  String get fieldDraftUnsentHint => '尚未送出（Enter 送出、Esc 還原）';

  @override
  String get fieldDraftUnsentHintMultiLine => '尚未送出（⌘Enter 送出、Esc 還原）';

  @override
  String get fieldWriteInProgress => '寫入中';

  @override
  String get fieldSeeWriteLogHint => '取回方式見寫入清單';

  @override
  String get fieldBlockedSnapshotFailed => '無法建立快照，檔案未改';

  @override
  String get fieldBlockedRewriteNotIsolated => '無法只改這個欄位，檔案未改。請改用外部編輯器';

  @override
  String get fieldIoFailed => '讀寫失敗，檔案未改';

  @override
  String get fieldNotEditableHint => '此欄位目前不能在 App 內編輯';

  @override
  String get fieldRequiredEmpty => '此欄位必填，空白未送出';

  @override
  String get validationRunning => '驗證中';

  @override
  String get validationPassed => '驗證通過';

  @override
  String validationFailed(int count) {
    return '發現 $count 個新問題';
  }

  @override
  String get validationUnavailable => '無法驗證';

  @override
  String get validationUnavailableExecutableMissing => '找不到 uv 或 doc CLI';

  @override
  String get validationUnavailableUnexpectedExitCode => '驗證程式以非預期的結束碼結束';

  @override
  String get validationUnavailableUnparsableOutput => '驗證程式的輸出無法解析';

  @override
  String get validationUnavailableTimedOut => '驗證超過 30 秒，已停止';

  @override
  String get radioYes => '是';

  @override
  String get radioNo => '否';
}
