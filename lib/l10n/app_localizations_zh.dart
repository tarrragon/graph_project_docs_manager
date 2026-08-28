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
}
