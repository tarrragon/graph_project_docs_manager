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
  String get sectionRecentDocuments => '近期文件';

  @override
  String get statInProgress => '進行中';

  @override
  String get statPendingReview => '待審閱';

  @override
  String get statArchived => '已歸檔';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份文件',
    );
    return '$_temp0';
  }

  @override
  String get chooseWorkspaceFolder => '選擇工作資料夾';

  @override
  String get folderAccessRationale =>
      '請選擇一個資料夾，App 將在其中讀取與編輯文件。此授權會被記住，下次開啟不需重選。';

  @override
  String workspaceReady(String path) {
    return '工作資料夾：$path';
  }

  @override
  String workspaceUnavailable(String reason) {
    return '無法存取先前的資料夾：$reason';
  }

  @override
  String get changeWorkspaceFolder => '變更資料夾';

  @override
  String get domainLoading => '正在解析圖譜節點…';

  @override
  String get cancelLoadingAction => '取消載入';

  @override
  String get emptyGraphMessage => '此專案尚無圖譜節點';

  @override
  String get notFrameworkProjectMessage => '此資料夾沒有 docs/，不是使用本框架的專案';

  @override
  String get notFrameworkProjectExplanation =>
      '本 App 需要專案根目錄下含 docs/ 目錄，並依循框架文件慣例組織文件';

  @override
  String schemaUnconsumableMessage(String version) {
    return '此專案的框架版本（$version）早於圖譜型別表的機器可讀匯出';
  }

  @override
  String schemaIncompatibleMessage(String appVersion, String projectVersion) {
    return 'App 支援的 schema 版本為 $appVersion，此專案為 $projectVersion，版本不相容';
  }

  @override
  String get emptyUcMessage => '此專案尚無 UC 節點';

  @override
  String get flowUnstructuredMessage => '尚未填寫結構化 flow';

  @override
  String get emptyProposalMessage => '此專案尚無提案';

  @override
  String ticketsLoadPrompt(int count) {
    return '載入 $count 張 ticket';
  }

  @override
  String ticketsLoadingProgress(int parsed) {
    return '已解析 $parsed 筆';
  }

  @override
  String get ticketsUnassignedSection => '未歸屬';

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
  String get fieldCorruptedMessage => '因檔案損壞而無法讀取';

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
  String get projectSwitcherPlaceholderTitle => '專案切換';

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
  String get gotoGapsReportAction => '前往破洞報告';

  @override
  String get openSourceFileAction => '開啟原始檔';

  @override
  String get sourceFileNotFoundSnackbarMessage => '找不到檔案';

  @override
  String get refreshAction => '重新整理';

  @override
  String get viewRelationsAction => '檢視關聯';

  @override
  String get backToDomainAction => '返回 Domain 視圖';

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
  String get probeTimeoutReason => '可能是磁碟未掛載';

  @override
  String get sourceFileStillMissingMessage => '檔案仍不存在';

  @override
  String get expanderLabel => '展開或收合';

  @override
  String get searchPlaceholder => '搜尋';

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
  String get currentProjectA11yLabel => '目前專案';

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
  String get schemaAppVersionLabel => 'App 支援版本';

  @override
  String get schemaProjectVersionLabel => '專案版本';

  @override
  String treeDepthA11yLabel(int depth) {
    return '第 $depth 層';
  }

  @override
  String get openExternallyA11yLabel => '在外部開啟';

  @override
  String get loadingSkeletonA11yLabel => '載入中';

  @override
  String progressA11yLabel(int parsed, int total) {
    return '進度 $parsed / $total';
  }

  @override
  String get cellDetailPrompt => '點選一格檢視詳情';

  @override
  String get cellDetailNotInvolved => '此 domain 不參與此 UC';

  @override
  String get cellDetailCloseAction => '關閉';

  @override
  String get cellDetailViewInSwimlaneAction => '在泳道中檢視';

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
  String get gapCategoryMissingFrontmatter => '缺少 Frontmatter';

  @override
  String gapItemLineLabel(int lineNumber) {
    return '第 $lineNumber 行';
  }
}
