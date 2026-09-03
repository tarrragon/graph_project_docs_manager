import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 應用程式名稱，用於視窗標題與 AppBar
  ///
  /// In zh, this message translates to:
  /// **'專案文件流'**
  String get appTitle;

  /// 首頁文件列表的區塊標題
  ///
  /// In zh, this message translates to:
  /// **'近期文件'**
  String get sectionRecentDocuments;

  /// 統計卡片：處理中的文件數
  ///
  /// In zh, this message translates to:
  /// **'進行中'**
  String get statInProgress;

  /// 統計卡片：等待審閱的文件數
  ///
  /// In zh, this message translates to:
  /// **'待審閱'**
  String get statPendingReview;

  /// 統計卡片：已封存的文件數
  ///
  /// In zh, this message translates to:
  /// **'已歸檔'**
  String get statArchived;

  /// 文件數量。中文無單複數變化，故僅有 other 分支
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 份文件}}'**
  String documentCount(int count);

  /// 引導使用者授權本機資料夾存取的按鈕
  ///
  /// In zh, this message translates to:
  /// **'選擇工作資料夾'**
  String get chooseWorkspaceFolder;

  /// 說明為何需要資料夾存取權，顯示於選取面板之前
  ///
  /// In zh, this message translates to:
  /// **'請選擇一個資料夾，App 將在其中讀取與編輯文件。此授權會被記住，下次開啟不需重選。'**
  String get folderAccessRationale;

  /// 已取得授權時顯示的目前資料夾
  ///
  /// In zh, this message translates to:
  /// **'工作資料夾：{path}'**
  String workspaceReady(String path);

  /// 授權失效時的說明，reason 由原生端提供
  ///
  /// In zh, this message translates to:
  /// **'無法存取先前的資料夾：{reason}'**
  String workspaceUnavailable(String reason);

  /// 已有工作資料夾時的重新選取按鈕
  ///
  /// In zh, this message translates to:
  /// **'變更資料夾'**
  String get changeWorkspaceFolder;

  /// SPEC-001 §1 Domain 視圖·載入中狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'正在解析圖譜節點…'**
  String get domainLoading;

  /// SPEC-001 §1 Domain 視圖·載入中狀態與 §4 Ticket 清單·載入中狀態共用的操作文案（取消操作）
  ///
  /// In zh, this message translates to:
  /// **'取消載入'**
  String get cancelLoadingAction;

  /// SPEC-001 §1 Domain 視圖·空圖狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案尚無圖譜節點'**
  String get emptyGraphMessage;

  /// SPEC-001 §1 Domain 視圖·不是框架專案狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此資料夾沒有 docs/，不是使用本框架的專案'**
  String get notFrameworkProjectMessage;

  /// SPEC-001 §1 Domain 視圖·不是框架專案狀態的補充說明文案（說明本 App 需要什麼）
  ///
  /// In zh, this message translates to:
  /// **'本 App 需要專案根目錄下含 docs/ 目錄，並依循框架文件慣例組織文件'**
  String get notFrameworkProjectExplanation;

  /// SPEC-001 §1 Domain 視圖·無可消費的型別表狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案的框架版本（{version}）早於圖譜型別表的機器可讀匯出'**
  String schemaUnconsumableMessage(String version);

  /// SPEC-001 §1 Domain 視圖·schema 不相容狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'App 支援的 schema 版本為 {appVersion}，此專案為 {projectVersion}，版本不相容'**
  String schemaIncompatibleMessage(String appVersion, String projectVersion);

  /// SPEC-001 §2 UC Flow 視圖·無 UC 狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案尚無 UC 節點'**
  String get emptyUcMessage;

  /// SPEC-001 §2 UC Flow 視圖·flow 未結構化狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'尚未填寫結構化 flow'**
  String get flowUnstructuredMessage;

  /// SPEC-001 §3 追溯視圖·無提案狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案尚無提案'**
  String get emptyProposalMessage;

  /// SPEC-001 §4 Ticket 清單·未載入狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'載入 {count} 張 ticket'**
  String ticketsLoadPrompt(int count);

  /// SPEC-001 §4 Ticket 清單·載入中狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'已解析 {parsed} 筆'**
  String ticketsLoadingProgress(int parsed);

  /// SPEC-001 §4 Ticket 清單·正常·主題狀態的未歸屬節標題文案
  ///
  /// In zh, this message translates to:
  /// **'未歸屬'**
  String get ticketsUnassignedSection;

  /// SPEC-001 §4 Ticket 清單·無 ticket 狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案尚無 ticket'**
  String get emptyTicketsMessage;

  /// SPEC-001 §4 Ticket 清單·含損壞狀態的徽章文案
  ///
  /// In zh, this message translates to:
  /// **'{count} 張損壞'**
  String corruptedTicketsBadge(int count);

  /// SPEC-001 §5 破洞報告·掃描中狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'正在掃描破洞…'**
  String get gapReportScanning;

  /// SPEC-001 §5 破洞報告·掃描中狀態的操作文案（取消操作）
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelScanAction;

  /// SPEC-001 §5 破洞報告·無破洞狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'未偵測到破洞'**
  String get noGapsMessage;

  /// SPEC-001 §5 破洞報告·無破洞狀態的掃描範圍說明文案
  ///
  /// In zh, this message translates to:
  /// **'已掃描全部節點與邊'**
  String get noGapsScanScope;

  /// SPEC-001 §6 節點詳情·部分損壞狀態的欄位標示文案
  ///
  /// In zh, this message translates to:
  /// **'因檔案損壞而無法讀取'**
  String get fieldCorruptedMessage;

  /// SPEC-001 §6 節點詳情·原始檔已消失狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'原始檔已不存在'**
  String get sourceFileMissingMessage;

  /// SPEC-001 §6 節點詳情·原始檔已消失狀態的路徑標籤
  ///
  /// In zh, this message translates to:
  /// **'最後已知路徑：{path}'**
  String lastKnownPathLabel(String path);

  /// SPEC-001 §7 專案切換浮層·無最近專案狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'選擇資料夾…'**
  String get switcherChooseFolderPrompt;

  /// SPEC-001 §7 專案切換浮層·展開狀態的操作文案（選擇其他資料夾）
  ///
  /// In zh, this message translates to:
  /// **'選擇其他'**
  String get switcherChooseOtherFolder;

  /// 導覽列項目：Domain 視圖（SPEC-001 §1）
  ///
  /// In zh, this message translates to:
  /// **'Domain 視圖'**
  String get navDomain;

  /// 導覽列項目：UC Flow 視圖（SPEC-001 §2）
  ///
  /// In zh, this message translates to:
  /// **'UC Flow'**
  String get navUcFlow;

  /// 導覽列項目：追溯視圖（SPEC-001 §3）
  ///
  /// In zh, this message translates to:
  /// **'追溯視圖'**
  String get navTraceability;

  /// 導覽列項目：Ticket 清單（SPEC-001 §4）
  ///
  /// In zh, this message translates to:
  /// **'Ticket 清單'**
  String get navTickets;

  /// 導覽列項目：破洞報告（SPEC-001 §5）
  ///
  /// In zh, this message translates to:
  /// **'破洞報告'**
  String get navGaps;

  /// 導覽列項目：節點詳情（SPEC-001 §6）
  ///
  /// In zh, this message translates to:
  /// **'節點詳情'**
  String get navNodeDetail;

  /// 側欄頂端專案名按鈕的 tooltip／語意標籤，點擊開啟專案切換浮層（SPEC-001 §7）
  ///
  /// In zh, this message translates to:
  /// **'切換專案'**
  String get projectSwitcherEntryLabel;

  /// 專案切換浮層的佔位標題，浮層內容由後續票實作
  ///
  /// In zh, this message translates to:
  /// **'專案切換'**
  String get projectSwitcherPlaceholderTitle;

  /// SPEC-003 §3.1 Domain 視圖：mode-domain-matrix 切換按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'切換至矩陣'**
  String get domainSwitchToMatrixAction;

  /// SPEC-003 §3.1 Domain 視圖：mode-domain-swimlane 切換按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'切換至泳道'**
  String get domainSwitchToSwimlaneAction;

  /// SPEC-003 §3.4 Ticket 清單：mode-tickets-list 切換按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'切換至列表'**
  String get ticketsSwitchToListAction;

  /// SPEC-003 §3.4 Ticket 清單：mode-tickets-topic 切換按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'切換至主題'**
  String get ticketsSwitchToTopicAction;

  /// SPEC-003 §3.1 Domain 視圖：action-domain-open-docs 按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'開啟 docs 目錄'**
  String get openDocsFolderAction;

  /// SPEC-003 §2.2／§3.1／§3.2／§3.5：以系統預設方式開啟檔案或目錄成功後的 SnackBar 文案
  ///
  /// In zh, this message translates to:
  /// **'已在外部開啟'**
  String get openedExternallyMessage;

  /// SPEC-003 §3.1 Domain 視圖：action-domain-schema-detail 按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'檢視詳情'**
  String get viewSchemaDetailAction;

  /// SPEC-003 §3.1／§3.2／§3.3／§3.4：各畫面前往破洞報告的前進動作文案
  ///
  /// In zh, this message translates to:
  /// **'前往破洞報告'**
  String get gotoGapsReportAction;

  /// SPEC-003 §3.2 UC Flow／§3.6 節點詳情：action-*-open-source 按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'開啟原始檔'**
  String get openSourceFileAction;

  /// SPEC-003 §3.2／§3.5：開啟原始檔或破洞項時檔案不存在的 SnackBar 提示文案（暫時性，區別於既有的狀態文案 sourceFileMissingMessage）
  ///
  /// In zh, this message translates to:
  /// **'找不到檔案'**
  String get sourceFileNotFoundSnackbarMessage;

  /// SPEC-003 §3.2 SnackBar 動作／§3.6 action-nodeDetail-refresh 共用的重新整理文案
  ///
  /// In zh, this message translates to:
  /// **'重新整理'**
  String get refreshAction;

  /// SPEC-003 §3.2 UC Flow：action-ucFlow-relations 按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'檢視關聯'**
  String get viewRelationsAction;

  /// SPEC-003 §3.2 UC Flow：action-ucFlow-back-to-domain 固定目標按鈕文案，不循 returnTo 語意
  ///
  /// In zh, this message translates to:
  /// **'返回 Domain 視圖'**
  String get backToDomainAction;

  /// SPEC-003 §2.3／§3.4／§3.6：returnTo 語意的返回按鈕共用文案。返回鍵未來將由 AppShell 單一承擔，故此 key 不逐畫面分立
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get backAction;

  /// SPEC-003 §3.4 Ticket 清單：action-tickets-start-load 按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'開始載入'**
  String get startLoadAction;

  /// SPEC-003 §3.5 破洞報告：action-gaps-rescan 按鈕與 SnackBar 動作共用文案
  ///
  /// In zh, this message translates to:
  /// **'重新掃描'**
  String get rescanAction;

  /// SPEC-003 §2.5 C3：按下取消後 Motion.feedback 內的取消按鈕文案，三處載入態共用
  ///
  /// In zh, this message translates to:
  /// **'取消中'**
  String get cancelInProgressAction;

  /// SPEC-003 §2.6：state-domain-loading 的已處理節點計數文字
  ///
  /// In zh, this message translates to:
  /// **'已處理 {count} 個節點'**
  String domainLoadingProcessedCount(int count);

  /// SPEC-003 §2.6：state-gaps-scanning 的已掃描項目計數文字
  ///
  /// In zh, this message translates to:
  /// **'已掃描 {count} 項'**
  String gapsScanningProcessedCount(int count);

  /// SPEC-003 §3.6：經導覽列直接進入節點詳情且無選定節點時的空狀態文案
  ///
  /// In zh, this message translates to:
  /// **'尚未選取節點'**
  String get noNodeSelectedMessage;

  /// SPEC-003 §3.6：action-nodeDetail-goto-traceability 前進動作文案
  ///
  /// In zh, this message translates to:
  /// **'前往追溯視圖'**
  String get gotoTraceabilityAction;

  /// SPEC-003 §3.7：專案切換浮層中不可用專案項的常駐說明文案
  ///
  /// In zh, this message translates to:
  /// **'無法使用：{reason}'**
  String projectUnavailableReasonLabel(String reason);

  /// SPEC-003 §3.7：資料夾可用性探測逾時時，作為 projectUnavailableReasonLabel 的 reason 值
  ///
  /// In zh, this message translates to:
  /// **'可能是磁碟未掛載'**
  String get probeTimeoutReason;

  /// SPEC-003 §3.6：action-nodeDetail-refresh 重新整理後，檔案仍不存在分支的 SnackBar 文案
  ///
  /// In zh, this message translates to:
  /// **'檔案仍不存在'**
  String get sourceFileStillMissingMessage;

  /// SPEC-004 §4.18：Expander 展開/收合朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'展開或收合'**
  String get expanderLabel;

  /// SPEC-004 §4.12：SearchField 佔位文字
  ///
  /// In zh, this message translates to:
  /// **'搜尋'**
  String get searchPlaceholder;

  /// SPEC-004 §4.12：SearchField 清除按鈕文案
  ///
  /// In zh, this message translates to:
  /// **'清除搜尋'**
  String get searchClearAction;

  /// SPEC-004 §4.13：FilterDropdown「全部」選項文案
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAllOption;

  /// SPEC-004 §4.13：FilterDropdown 朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'{label} 篩選，目前：{value}'**
  String filterA11yLabel(String label, String value);

  /// SPEC-004 §4：畫面呼叫端使用的狀態篩選標籤（4.13 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'狀態'**
  String get filterStatusLabel;

  /// SPEC-004 §4：畫面呼叫端使用的優先篩選標籤（4.13 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'優先'**
  String get filterPriorityLabel;

  /// SPEC-004 §4.14：TableColumnHeader 排序朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'{label}，可排序，目前：{order}'**
  String sortA11yLabel(String label, String order);

  /// SPEC-004 §4.14：排序狀態文案
  ///
  /// In zh, this message translates to:
  /// **'未排序'**
  String get sortNone;

  /// SPEC-004 §4.14：排序狀態文案
  ///
  /// In zh, this message translates to:
  /// **'遞增'**
  String get sortAscending;

  /// SPEC-004 §4.14：排序狀態文案
  ///
  /// In zh, this message translates to:
  /// **'遞減'**
  String get sortDescending;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'ID'**
  String get columnId;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'標題'**
  String get columnTitle;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'狀態'**
  String get columnStatus;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'優先'**
  String get columnPriority;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'步驟'**
  String get columnStep;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'Domain'**
  String get columnDomain;

  /// SPEC-004 §2、§4：欄位標題文案（4.14 呼叫端）
  ///
  /// In zh, this message translates to:
  /// **'發送事件'**
  String get columnEvents;

  /// SPEC-004 §4.15：MatrixGrid 格子朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'{domain} × {uc}：{relation}'**
  String matrixCellA11yLabel(String domain, String uc, String relation);

  /// SPEC-004 §4.5（legend）、4.15、§1 畫面：關係圖例文案
  ///
  /// In zh, this message translates to:
  /// **'直接貫穿'**
  String get legendDirect;

  /// SPEC-004 §4.5（legend）、4.15、§1 畫面：關係圖例文案
  ///
  /// In zh, this message translates to:
  /// **'間接依賴'**
  String get legendIndirect;

  /// SPEC-004 §4.5（legend）、4.15、§1 畫面：關係圖例文案
  ///
  /// In zh, this message translates to:
  /// **'無關'**
  String get legendNone;

  /// SPEC-004 §4.37：MatrixGrid 小計朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'小計 {count}'**
  String matrixSubtotalA11yLabel(int count);

  /// SPEC-004 §4.38：泳道朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'泳道 {name}'**
  String laneA11yLabel(String name);

  /// SPEC-004 §4.16：泳道節點狀態文案
  ///
  /// In zh, this message translates to:
  /// **'作用中'**
  String get laneNodeActive;

  /// SPEC-004 §4.16：泳道節點狀態文案
  ///
  /// In zh, this message translates to:
  /// **'非作用中'**
  String get laneNodeInactive;

  /// SPEC-004 §4.17：StepNumber 朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'步驟 {number}'**
  String stepNumberA11yLabel(int number);

  /// SPEC-004 §4.6：缺口標記可見文字
  ///
  /// In zh, this message translates to:
  /// **'缺口'**
  String get gapMarkerLabel;

  /// SPEC-004 §4.6：邊損壞標記朗讀文案
  ///
  /// In zh, this message translates to:
  /// **'邊損壞'**
  String get damagedEdgeMarkerLabel;

  /// SPEC-004 §4.6：詳情損壞標記朗讀文案
  ///
  /// In zh, this message translates to:
  /// **'詳情損壞'**
  String get damagedDetailMarkerLabel;

  /// SPEC-004 §4.19：RelationItem 朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'關聯節點 {id}'**
  String relationItemA11yLabel(String id);

  /// SPEC-004 §4.9：目前專案朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'目前專案'**
  String get currentProjectA11yLabel;

  /// SPEC-004 §4.9：專案摘要文案
  ///
  /// In zh, this message translates to:
  /// **'{nodes} 節點 · {tickets} 票'**
  String projectSummaryLabel(int nodes, int tickets);

  /// SPEC-004 §4.5（health）：健康度徽章朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'{count} 個問題'**
  String healthBadgeA11yLabel(int count);

  /// SPEC-004 §4.42：專案切換器標題文案
  ///
  /// In zh, this message translates to:
  /// **'切換專案'**
  String get switcherTitle;

  /// SPEC-004 §4.23：Schema 版本標籤文案
  ///
  /// In zh, this message translates to:
  /// **'App 支援版本'**
  String get schemaAppVersionLabel;

  /// SPEC-004 §4.23：Schema 版本標籤文案
  ///
  /// In zh, this message translates to:
  /// **'專案版本'**
  String get schemaProjectVersionLabel;

  /// SPEC-004 §4.39：Tree 深度朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'第 {depth} 層'**
  String treeDepthA11yLabel(int depth);

  /// SPEC-004 §4.40（item）：外部開啟朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'在外部開啟'**
  String get openExternallyA11yLabel;

  /// SPEC-004 §4.24：載入骨架朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'載入中'**
  String get loadingSkeletonA11yLabel;

  /// SPEC-004 §4.24：進度朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'進度 {parsed} / {total}'**
  String progressA11yLabel(int parsed, int total);

  /// SPEC-004 §1 畫面（4.21 section 呼叫端；SPEC-003 §3.1）：格詳情卡提示文案
  ///
  /// In zh, this message translates to:
  /// **'點選一格檢視詳情'**
  String get cellDetailPrompt;

  /// SPEC-004 §1 畫面（SPEC-003 §3.1）：格詳情卡不參與文案
  ///
  /// In zh, this message translates to:
  /// **'此 domain 不參與此 UC'**
  String get cellDetailNotInvolved;

  /// SPEC-004 §1 畫面（4.4 text 呼叫端）：格詳情卡關閉動作文案
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get cellDetailCloseAction;

  /// SPEC-004 §1 畫面（4.4 secondary 呼叫端）：格詳情卡跳轉泳道動作文案
  ///
  /// In zh, this message translates to:
  /// **'在泳道中檢視'**
  String get cellDetailViewInSwimlaneAction;

  /// SPEC-004 §1、§4 畫面（4.10 可見標籤）：檢視模式文案
  ///
  /// In zh, this message translates to:
  /// **'矩陣'**
  String get modeMatrixLabel;

  /// SPEC-004 §1、§4 畫面（4.10 可見標籤）：檢視模式文案
  ///
  /// In zh, this message translates to:
  /// **'泳道'**
  String get modeSwimlaneLabel;

  /// SPEC-004 §1、§4 畫面（4.10 可見標籤）：檢視模式文案
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get modeListLabel;

  /// SPEC-004 §1、§4 畫面（4.10 可見標籤）：檢視模式文案
  ///
  /// In zh, this message translates to:
  /// **'主題'**
  String get modeTopicLabel;

  /// SPEC-004 §4 畫面（4.29 footer 呼叫端）：票列表摘要文案
  ///
  /// In zh, this message translates to:
  /// **'顯示 {from}–{to} / 共 {total}'**
  String ticketsSummaryLabel(int from, int to, int total);

  /// SPEC-004 §4 畫面：票列表虛擬捲動說明文案
  ///
  /// In zh, this message translates to:
  /// **'虛擬捲動，不分頁'**
  String get ticketsVirtualScrollNote;

  /// SPEC-004 §4 畫面（4.40 sectionHeader 呼叫端）：主題區塊摘要文案
  ///
  /// In zh, this message translates to:
  /// **'({count} tasks, 最高優先級={priority})'**
  String topicSectionSummary(int count, String priority);

  /// SPEC-004 §5 畫面（4.40 sectionHeader 呼叫端）：缺口區塊數量文案
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String gapSectionCount(int count);

  /// SPEC-001 §5 破洞報告·有破洞狀態：以真實 repo 快照缺 frontmatter 樣本驅動的分節類別名稱
  ///
  /// In zh, this message translates to:
  /// **'缺少 Frontmatter'**
  String get gapCategoryMissingFrontmatter;

  /// SPEC-001 §5 破洞報告·有破洞狀態：ListRow.item 次文字，破洞所在行號
  ///
  /// In zh, this message translates to:
  /// **'第 {lineNumber} 行'**
  String gapItemLineLabel(int lineNumber);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
