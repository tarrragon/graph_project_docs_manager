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

  /// 授權失效時的說明，reason 由原生端提供
  ///
  /// In zh, this message translates to:
  /// **'無法存取先前的資料夾：{reason}'**
  String workspaceUnavailable(String reason);

  /// 剛在選擇器選定的資料夾不可讀或不存在時的提示，reason 為 WorkspaceUnavailable.reason 固定文案
  ///
  /// In zh, this message translates to:
  /// **'資料夾無法使用：{reason}'**
  String folderUnavailableMessage(String reason);

  /// 選取資料夾成功但持久化寫入失敗時的提示
  ///
  /// In zh, this message translates to:
  /// **'已選定，但下次啟動需重新選擇'**
  String get workspaceNotRemembered;

  /// 系統面板本身開不起來時的固定提示；結果陳述加一般語言原因（主要成因為安裝或建置層問題，如平台外掛缺失），不含操作指引；不顯示原始例外訊息
  ///
  /// In zh, this message translates to:
  /// **'無法開啟資料夾選取面板，應用程式可能安裝不完整'**
  String get chooseFolderUnavailableMessage;

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
  /// **'此資料夾缺少本框架所需的設定檔（.claude/VERSION 與型別表皆缺），不是使用本框架的專案'**
  String get notFrameworkProjectMessage;

  /// SPEC-001 §1 Domain 視圖·不是框架專案狀態的補充說明文案（說明本 App 需要什麼）
  ///
  /// In zh, this message translates to:
  /// **'本 App 需要 .claude/VERSION 或型別表（.claude/skills/doc/doc_system/core/tracking_schema.json）其中一項存在，才能判讀此專案的框架版本'**
  String get notFrameworkProjectExplanation;

  /// SPEC-001 §1 Domain 視圖·無可消費的型別表狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'此專案的框架版本（{version}）早於圖譜型別表的機器可讀匯出'**
  String schemaUnconsumableMessage(String version);

  /// SPEC-004 §4.0.6〈1.41 新增〉：Domain 視圖無可消費的型別表阻擋態，與降級動作同條件渲染的降級說明（explanation slot）
  ///
  /// In zh, this message translates to:
  /// **'可改用 App 內建型別表（v{builtinVersion}）檢視，B 層邊不渲染'**
  String schemaUnconsumableDegradedExplanation(String builtinVersion);

  /// SPEC-001 §1 Domain 視圖·schema 不相容狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'App 支援的 schema 版本為 {appVersion}，此專案為 {projectVersion}，版本不相容'**
  String schemaIncompatibleMessage(String appVersion, String projectVersion);

  /// SPEC-001 §1 Domain 視圖·schema 不相容且型別表版本無法判讀時的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'無法判讀此專案型別表的版本，請在該專案重新產生型別表後再開啟'**
  String get schemaVersionUnreadableMessage;

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

  /// SPEC-001 §2 UC Flow 視圖·flow 未結構化狀態、flow 區塊皆解析失敗時的顯示文案（與 Domain 泳道同 key）
  ///
  /// In zh, this message translates to:
  /// **'此 UC 的 flow 區塊解析失敗，請開啟來源檔修正'**
  String get flowParseFailedMessage;

  /// SPEC-001 §1 正常 · 泳道：選定 UC 有 flow 區塊解析失敗但仍有合法區塊時，置於 SwimlaneGrid 之上的提示
  ///
  /// In zh, this message translates to:
  /// **'此 UC 有 flow 區塊解析失敗，泳道只呈現第一個合法區塊'**
  String get swimlaneFlowParseFailedHint;

  /// SPEC-001 §2 UC Flow 視圖·尚未選定 UC 狀態的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'選擇一條 UC 以檢視 flow'**
  String get ucUnsetPrompt;

  /// SPEC-004 §3.6〈UC 選擇入口〉Section.static 節首文案
  ///
  /// In zh, this message translates to:
  /// **'選擇 UC'**
  String get ucSelectorTitle;

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

  /// SPEC-003 §3.1 Domain 視圖：action-domain-degraded-view 按鈕文案（0.1.0-W1-035 降級策略）
  ///
  /// In zh, this message translates to:
  /// **'以 App 內建型別表檢視'**
  String get useBuiltinSchemaAction;

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

  /// SPEC-003 §2.2 外部開啟契約 failed 結果的 SnackBar 文案（§3.1／§3.2／§3.5／§3.6 四處共用）：檔案存在但系統開啟失敗，畫面狀態不變
  ///
  /// In zh, this message translates to:
  /// **'無法以系統預設方式開啟'**
  String get externalOpenFailedMessage;

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

  /// SPEC-003 §3.7：專案切換浮層內「選擇其他」選擇器無法開啟時的常駐原因文字（SPEC-004 4.42 chooseOtherFailureReason）
  ///
  /// In zh, this message translates to:
  /// **'無法開啟資料夾選取面板，應用程式可能安裝不完整'**
  String get switcherChooseFolderUnavailableReason;

  /// SPEC-003 §3.7：專案切換浮層內「選擇其他」選定資料夾不可讀或不存在時的常駐原因文字（SPEC-004 4.42 chooseOtherFailureReason）
  ///
  /// In zh, this message translates to:
  /// **'資料夾無法使用：{reason}'**
  String switcherFolderUnavailableReason(String reason);

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

  /// SPEC-003 §3.6：action-nodeDetail-refresh 重新整理後，檔案存在但 frontmatter 解析失敗分支的 SnackBar 文案
  ///
  /// In zh, this message translates to:
  /// **'檔案存在但無法解析，詳見破洞報告'**
  String get sourceFileUnparsableMessage;

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

  /// SPEC-004 §4.0.6：欄名沿用欄位字面，SPEC-001 §4（4.35 ticket）
  ///
  /// In zh, this message translates to:
  /// **'blockedBy'**
  String get columnBlockedBy;

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

  /// SPEC-004 §4.19：isProposed 的尾端 Badge.category 文字
  ///
  /// In zh, this message translates to:
  /// **'暫定'**
  String get relationProposedLabel;

  /// SPEC-004 §4.19：isProposed 的 RelationItem 朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'關聯節點 {id}，暫定邊，形狀可能變動'**
  String relationItemProposedA11yLabel(String id);

  /// SPEC-004 §4.38：「畫面」列列首（kind: screen）
  ///
  /// In zh, this message translates to:
  /// **'畫面'**
  String get swimlaneScreenLaneName;

  /// SPEC-004 §4.38：「未定位」列列首（kind: unplaced）
  ///
  /// In zh, this message translates to:
  /// **'未定位'**
  String get swimlaneUnplacedLaneName;

  /// SPEC-004 §4.9：目前專案朗讀標籤
  ///
  /// In zh, this message translates to:
  /// **'目前專案'**
  String get currentProjectA11yLabel;

  /// SPEC-004 §4.9：最近專案項降級徽章（isDegraded 為 true 時，S-34）
  ///
  /// In zh, this message translates to:
  /// **'內建型別表'**
  String get degradedSchemaShortLabel;

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

  /// SPEC-004 §4.23：BlockedState.withDetail 面板小標，取代 schemaAppVersionLabel／schemaProjectVersionLabel
  ///
  /// In zh, this message translates to:
  /// **'App 已知版本範圍'**
  String get schemaKnownRangeLabel;

  /// SPEC-004 §4.23：BlockedState.withDetail 面板值；appVersion 為 App 內建型別表產生版本
  ///
  /// In zh, this message translates to:
  /// **'不高於 {appVersion}'**
  String schemaKnownRangeValue(String appVersion);

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

  /// SPEC-004 §1 畫面（4.21 section 呼叫端；SPEC-003 §3.1）：泳道尚未選定 UC 提示文案
  ///
  /// In zh, this message translates to:
  /// **'尚未選定 UC，請至矩陣點格或於 UC Flow 視圖選擇一條 UC'**
  String get swimlaneUcUnsetPrompt;

  /// SPEC-004 §1 畫面（4.21 section 呼叫端；SPEC-001 v1.55 §1）：泳道投影準備中提示文案（已選定 UC 而該專案尚無完成輪次）
  ///
  /// In zh, this message translates to:
  /// **'泳道投影準備中，掃描完成後即顯示此 UC 的步驟'**
  String get swimlaneProjectionPendingPrompt;

  /// SPEC-004 §4.0.6：泳道面板標題（正常 · 泳道、泳道 · flow 未結構化，AppText.subtitle）
  ///
  /// In zh, this message translates to:
  /// **'{ucId} {ucTitle}'**
  String swimlanePanelTitle(String ucId, String ucTitle);

  /// SPEC-001 §1〈降級型別表〉疊加旗標：`badge-<screen>-degraded-schema` 徽章文案，含內建型別表版本與觸發降級時的專案 VERSION（`0.1.0-W2-014` 接線寫入端）
  ///
  /// In zh, this message translates to:
  /// **'降級型別表（內建 {builtinVersion} / 專案 {projectVersion}）'**
  String degradedSchemaBadgeLabel(String builtinVersion, String projectVersion);

  /// SPEC-001 §1〈推定版本〉疊加旗標：`badge-<screen>-inferred-version` 徽章文案（SPEC-004 §4.0.6 1.45 新增，`0.2.0-W1-042` 接線寫入端與渲染），與降級徽章互斥
  ///
  /// In zh, this message translates to:
  /// **'版本推定自型別表 (v{inferredVersion})'**
  String inferredVersionBadgeLabel(String inferredVersion);

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

  /// SPEC-004 §4.0.6〈1.80 提案〉：分節 parse-failure（EVT-CORPUS-003）
  ///
  /// In zh, this message translates to:
  /// **'解析失敗'**
  String get gapCategoryParseFailure;

  /// SPEC-004 §4.0.6〈1.80 提案〉：分節 flow-block-malformed（EVT-CORPUS-004）
  ///
  /// In zh, this message translates to:
  /// **'flow 區塊解析失敗'**
  String get gapCategoryFlowBlockMalformed;

  /// SPEC-004 §4.0.6〈1.80 提案〉：分節 non-domain-paths-malformed（EVT-CORPUS-005）
  ///
  /// In zh, this message translates to:
  /// **'非 domain 路徑清單格式錯誤'**
  String get gapCategoryNonDomainPathsMalformed;

  /// SPEC-004 §4.0.6〈1.80 提案〉：分節 graph-defect（主圖四子類與 domain 重複宣告）
  ///
  /// In zh, this message translates to:
  /// **'圖結構缺陷'**
  String get gapCategoryGraphDefect;

  /// SPEC-004 §4.0.6〈1.80 提案〉：分節 graph-defect-flow（flow 四子類）
  ///
  /// In zh, this message translates to:
  /// **'flow 結構缺陷'**
  String get gapCategoryGraphDefectFlow;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 reason「無 frontmatter」
  ///
  /// In zh, this message translates to:
  /// **'缺少 frontmatter'**
  String get gapParseNoFrontmatter;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 reason「frontmatter 未閉合」
  ///
  /// In zh, this message translates to:
  /// **'frontmatter 未閉合'**
  String get gapParseFrontmatterUnclosed;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 reason「frontmatter 為空或非 map」
  ///
  /// In zh, this message translates to:
  /// **'frontmatter 為空或不是鍵值對映'**
  String get gapParseFrontmatterNotMap;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 reason「YAML 語法錯誤」
  ///
  /// In zh, this message translates to:
  /// **'frontmatter 的 YAML 無法解析'**
  String get gapParseYamlInvalid;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 無法讀取，子原因編碼
  ///
  /// In zh, this message translates to:
  /// **'無法讀取檔案：編碼錯誤'**
  String get gapParseUnreadableEncoding;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 無法讀取，子原因權限
  ///
  /// In zh, this message translates to:
  /// **'無法讀取檔案：沒有權限'**
  String get gapParseUnreadablePermission;

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-003 無法讀取，子原因檔案消失
  ///
  /// In zh, this message translates to:
  /// **'無法讀取檔案：檔案已消失'**
  String get gapParseUnreadableMissing;

  /// SPEC-004 §4.0.6〈1.80 提案〉：schemaAmbiguous 為 true 時附於原因說明之後；types 為 candidateTypes 以分隔符連接
  ///
  /// In zh, this message translates to:
  /// **'歸屬型別不明，候選：{types}'**
  String gapParseTypeAmbiguous(String types);

  /// SPEC-004 §4.0.6〈1.80 提案〉：EVT-CORPUS-004 原因碼 flowBlockMalformed
  ///
  /// In zh, this message translates to:
  /// **'flow 區塊解析失敗，請修正後重新掃描'**
  String get gapFlowBlockMalformed;

  /// SPEC-004 §4.0.6：EVT-CORPUS-005 子原因 elementNotString
  ///
  /// In zh, this message translates to:
  /// **'清單內 {count} 個非字串元素'**
  String gapNonDomainPathsNonStringElements(int count);

  /// SPEC-004 §4.0.6：EVT-CORPUS-005 子原因 yamlInvalid
  ///
  /// In zh, this message translates to:
  /// **'清單檔的 YAML 無法解析'**
  String get gapNonDomainPathsYamlInvalid;

  /// SPEC-004 §4.0.6：EVT-CORPUS-005 子原因 keyMissing
  ///
  /// In zh, this message translates to:
  /// **'清單檔缺少 {key} 鍵'**
  String gapNonDomainPathsKeyMissing(String key);

  /// SPEC-004 §4.0.6：EVT-CORPUS-005 子原因 notList
  ///
  /// In zh, this message translates to:
  /// **'清單檔中 {key} 的值不是清單'**
  String gapNonDomainPathsNotList(String key);

  /// SPEC-004 §4.0.6〈1.80 提案〉：danglingRef，原因 targetMissing
  ///
  /// In zh, this message translates to:
  /// **'{field} 指向的 {value} 不存在'**
  String gapDanglingRefTargetMissing(String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：danglingRef，原因 targetDuplicated
  ///
  /// In zh, this message translates to:
  /// **'{field} 指向的 {value} 對應多個節點'**
  String gapDanglingRefTargetDuplicated(String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：malformedRef，原因 invalidShape
  ///
  /// In zh, this message translates to:
  /// **'{field} 的值 {value} 格式不正確'**
  String gapMalformedRefInvalidShape(String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：malformedRef，原因 patternMismatch
  ///
  /// In zh, this message translates to:
  /// **'{field} 的值 {value} 不符合 ID 格式'**
  String gapMalformedRefPatternMismatch(String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：malformedRef，原因 selfReference
  ///
  /// In zh, this message translates to:
  /// **'{field} 指向自己'**
  String gapMalformedRefSelfReference(String field);

  /// SPEC-004 §4.0.6〈1.80 提案〉：duplicateId；paths 為全部路徑以分隔符連接
  ///
  /// In zh, this message translates to:
  /// **'ID {id} 出現在 {count} 個檔案：{paths}'**
  String gapDuplicateId(String id, int count, String paths);

  /// SPEC-004 §4.0.6〈1.80 提案〉：multiSource；targets 為全部終點 ID 以分隔符連接
  ///
  /// In zh, this message translates to:
  /// **'{edgeType} 只能指向一個終點，目前指向 {targets}'**
  String gapMultiSource(String edgeType, String targets);

  /// SPEC-004 §4.0.6〈1.96 新增〉：flow 子類事件引用未解析
  ///
  /// In zh, this message translates to:
  /// **'步驟 {stepId} 的 {field} 引用的事件不存在：{value}'**
  String gapFlowEventUnresolved(String stepId, String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：flow 參照未解析
  ///
  /// In zh, this message translates to:
  /// **'步驟 {stepId} 的 {field} 無法解析：{value}'**
  String gapFlowRefUnresolved(String stepId, String field, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：UC 內 step id 重複
  ///
  /// In zh, this message translates to:
  /// **'步驟 ID {stepId} 在此 UC 內重複'**
  String gapFlowStepIdDuplicated(String stepId);

  /// SPEC-004 §4.0.6〈1.80 提案〉：traverses 名稱未宣告
  ///
  /// In zh, this message translates to:
  /// **'步驟 {stepId} 的 traverses 含未宣告的 domain：{value}'**
  String gapTraversesUndeclared(String stepId, String value);

  /// SPEC-004 §4.0.6〈1.80 提案〉：traverses 鍵缺席
  ///
  /// In zh, this message translates to:
  /// **'步驟 {stepId} 缺少 traverses 欄位'**
  String gapTraversesMissing(String stepId);

  /// SPEC-004 §4.0.6〈1.80 提案〉：domain 重複宣告；bundles 為衝突 DomainBundle ID 以分隔符連接
  ///
  /// In zh, this message translates to:
  /// **'domain {domain} 被多個 DomainBundle 宣告：{bundles}'**
  String gapDomainDeclaredTwice(String domain, String bundles);

  /// SPEC-001 §5／SPEC-003 §3.5：破洞類別 orphan-event 的分節標籤
  ///
  /// In zh, this message translates to:
  /// **'孤立事件'**
  String get gapCategoryOrphanEvent;

  /// SPEC-001 §5／SPEC-003 §3.5：破洞類別 event-declaration-mismatch 的分節標籤
  ///
  /// In zh, this message translates to:
  /// **'事件宣告與 flow 不符'**
  String get gapCategoryEventDeclarationMismatch;

  /// SPEC-001 §5 破洞報告·有破洞狀態：ListRow.item 次文字，破洞所在行號
  ///
  /// In zh, this message translates to:
  /// **'第 {lineNumber} 行'**
  String gapItemLineLabel(int lineNumber);

  /// SPEC-003 §2.2 系統層通知：macOS 通知標題
  ///
  /// In zh, this message translates to:
  /// **'破洞掃描完成'**
  String get scanCompleteNotificationTitle;

  /// SPEC-003 §2.2 系統層通知：state-gaps-found 時的通知內文
  ///
  /// In zh, this message translates to:
  /// **'偵測到 {count} 個破洞'**
  String scanCompleteNotificationBody(int count);

  /// SPEC-003 §2.2 系統層通知：state-gaps-none 時的通知內文
  ///
  /// In zh, this message translates to:
  /// **'未偵測到破洞'**
  String get scanCompleteNoGapsNotificationBody;

  /// SPEC-003 §2.2 系統層通知：權限 denied fallback 的 App 內 SnackBar 文字
  ///
  /// In zh, this message translates to:
  /// **'掃描完成，偵測到 {count} 個破洞'**
  String scanCompleteSnackbarMessage(int count);

  /// SPEC-003 §2.2 系統層通知：權限 denied fallback 的 App 內 SnackBar 文字（無破洞）
  ///
  /// In zh, this message translates to:
  /// **'掃描完成，未偵測到破洞'**
  String get scanCompleteNoGapsSnackbarMessage;

  /// SPEC-003 §2.2 系統層通知：state-gaps-undeterminable 時的通知內文
  ///
  /// In zh, this message translates to:
  /// **'無法判定破洞，原因請見破洞報告'**
  String get scanCompleteUndeterminableNotificationBody;

  /// SPEC-003 §2.2 系統層通知：權限 denied fallback 的 App 內 SnackBar 文字（無法判定破洞）
  ///
  /// In zh, this message translates to:
  /// **'掃描結束，無法判定破洞'**
  String get scanCompleteUndeterminableSnackbarMessage;

  /// SPEC-001 §5「無法判定破洞」原因說明之三（掃描輪次拋出非預期例外）
  ///
  /// In zh, this message translates to:
  /// **'掃描時發生非預期錯誤，無法判斷破洞；請重新掃描'**
  String get gapsUndeterminableReasonScanFailed;

  /// SPEC-003 §2.2 系統層通知：App 內 SnackBar 的動作按鈕文字
  ///
  /// In zh, this message translates to:
  /// **'檢視'**
  String get viewGapsAction;

  /// SPEC-001「專案未就緒」共用定義：Domain 視圖未選專案時的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'尚未選擇專案'**
  String get projectUnreadyReasonNotSelected;

  /// SPEC-001「專案未就緒」共用定義：Domain 視圖載入中時的顯示文案
  ///
  /// In zh, this message translates to:
  /// **'圖譜載入中'**
  String get projectUnreadyReasonLoading;

  /// SPEC-001「專案未就緒」共用定義：Domain 視圖處於三個阻擋狀態（不是框架專案／無可消費的型別表／schema 不相容）之一時的顯示文案，本畫面不區分三者
  ///
  /// In zh, this message translates to:
  /// **'此專案不適用本 App'**
  String get projectUnreadyReasonIncompatible;

  /// SPEC-001「專案未就緒」共用定義：Domain 視圖處於載入失敗時的顯示文案（SPEC-004 §4.0.6 1.86）
  ///
  /// In zh, this message translates to:
  /// **'圖譜載入失敗'**
  String get projectUnreadyReasonLoadFailed;

  /// SPEC-001 §1 Domain 視圖·載入失敗的顯示文案（state-domain-load-failed；只寫結果與原因，操作由按鈕承載）
  ///
  /// In zh, this message translates to:
  /// **'掃描此專案時發生非預期錯誤，無法載入圖譜'**
  String get domainLoadFailedMessage;

  /// SPEC-001 §1 Domain 視圖·圖不可用的原因文案（state-domain-graph-unavailable；appVersion 為 App 內建型別表產生版本）
  ///
  /// In zh, this message translates to:
  /// **'此專案的型別表版本不在 App 已知範圍內（不高於 {appVersion}），最近一次掃描無法建立圖譜；型別表修正或重新產生之前，重新掃描仍會得到相同結果'**
  String domainGraphUnavailableMessage(String appVersion);

  /// SPEC-001 §1 Domain 視圖·圖不可用列在掃描輪次進行期間取代原因文字的訊息（SPEC-004 §4.0.6）
  ///
  /// In zh, this message translates to:
  /// **'掃描中'**
  String get domainGraphUnavailableScanning;

  /// SPEC-001 §1 Domain 視圖·載入失敗的重新載入動作（action-domain-reload）
  ///
  /// In zh, this message translates to:
  /// **'重新載入'**
  String get reloadAction;

  /// SPEC-001「專案未就緒」共用定義：前往 Domain 視圖的動作文案（SPEC-003 §2.9 `action-<screen>-goto-domain`）
  ///
  /// In zh, this message translates to:
  /// **'前往 Domain 視圖'**
  String get gotoDomainViewAction;

  /// SPEC-003 §3.3 追溯視圖：Ticket 清單未載入時的前往動作文案（`0.1.0-W3-335.38` S-28）
  ///
  /// In zh, this message translates to:
  /// **'前往 Ticket 清單'**
  String get gotoTicketsListAction;

  /// SPEC-004 §4.0.6：追溯視圖鏈路斷裂缺口列主文字，layer 為缺的下游層型別名
  ///
  /// In zh, this message translates to:
  /// **'（尚無 {layer}）'**
  String traceabilityNoDownstream(String layer);

  /// SPEC-004 §4.0.6：追溯視圖 Ticket 清單未載入時樹上方常駐說明文字（S-28）
  ///
  /// In zh, this message translates to:
  /// **'Ticket 尚未載入'**
  String get traceabilityTicketsNotLoadedHint;

  /// SPEC-004 §4.26；SPEC-003 §3.4〈帶目標跳入〉目標被搜尋詞或篩選隱藏時清除後的提示
  ///
  /// In zh, this message translates to:
  /// **'已清除搜尋與篩選以顯示目標 ticket'**
  String get ticketsFiltersClearedSnackbarMessage;

  /// SPEC-004 §4.26 AppSnackBar.plain；SPEC-003 §3.4〈帶目標跳入〉目標 ticketId 不在清單時的提示
  ///
  /// In zh, this message translates to:
  /// **'找不到該 ticket，可能已被移除'**
  String get ticketsTargetNotFoundMessage;

  /// SPEC-004 §4.26；SPEC-003 §3.4〈帶目標跳入〉的 AppSnackBar.withAction 動作，還原清除前的搜尋詞與全部篩選值
  ///
  /// In zh, this message translates to:
  /// **'復原'**
  String get undoAction;

  /// SPEC-004 §2 事件流小表欄位標題（4.35 `header` / `eventFlow`；SPEC-001 §2〈事件流小表〉欄位）
  ///
  /// In zh, this message translates to:
  /// **'事件'**
  String get columnEvent;

  /// SPEC-004 §2 事件流小表欄位標題（4.35 `header` / `eventFlow`；SPEC-001 §2〈事件流小表〉欄位）
  ///
  /// In zh, this message translates to:
  /// **'發出'**
  String get columnEmitter;

  /// SPEC-004 §2 事件流小表欄位標題（4.35 `header` / `eventFlow`；SPEC-001 §2〈事件流小表〉欄位）
  ///
  /// In zh, this message translates to:
  /// **'消費'**
  String get columnConsumer;

  /// SPEC-004 4.35 `eventFlow` 發出／消費格（多個以「、」串接）
  ///
  /// In zh, this message translates to:
  /// **'{step} · {domain}'**
  String eventFlowStepDomain(String step, String domain);

  /// SPEC-004 4.35 `eventFlow`（SPEC-003 §3.2「本 UC 外」列；domains 為空時仍顯示括號內空值，提案）
  ///
  /// In zh, this message translates to:
  /// **'本 UC 外（{domains}）'**
  String eventOutsideUc(String domains);

  /// SPEC-004 4.35 `eventFlow` 標記格朗讀
  ///
  /// In zh, this message translates to:
  /// **'孤立事件'**
  String get orphanEventMarkerLabel;

  /// SPEC-001 §1〈路徑模式取自內建表〉旗標：`badge-gaps-builtin-path-pattern` 徽章文案，只在破洞報告常駐（SPEC-004 §4.0.6 1.46 新增）
  ///
  /// In zh, this message translates to:
  /// **'路徑模式取自 App 內建型別表'**
  String get builtinPathPatternBadgeLabel;

  /// SPEC-001 §5「無法判定破洞」列頁首標題（`state-gaps-undeterminable`）
  ///
  /// In zh, this message translates to:
  /// **'無法判定破洞'**
  String get gapsUndeterminableTitle;

  /// SPEC-001 §5「無法判定破洞」原因說明之一（版本不在 App 已知範圍；建圖不可用的四個原因碼亦映射至此）
  ///
  /// In zh, this message translates to:
  /// **'專案型別表版本不在 App 已知範圍內，且缺少路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出'**
  String get gapsUndeterminableReasonVersionOutOfRange;

  /// SPEC-001 §5「無法判定破洞」原因說明之二（型別表沒有路徑模式）
  ///
  /// In zh, this message translates to:
  /// **'專案型別表與 App 內建型別表都沒有路徑模式，無法判斷哪些檔案應為節點；解析失敗類別不列出'**
  String get gapsUndeterminableReasonNoPathPattern;

  /// SPEC-001 §5 專案層級宣告狀態一行（部分缺口）；detail 為 pathDeclarationBundlesPartial、pathDeclarationNonDomainMissing／Malformed 片段以分隔符連接，count 為受影響路徑條數（跨票去重，同一條正規化路徑只算一次）
  ///
  /// In zh, this message translates to:
  /// **'路徑宣告不完整：{detail}（影響 {count} 條路徑）'**
  String pathDeclarationIncompleteLine(String detail, int count);

  /// SPEC-004 §4.0.6：宣告狀態行 detail 片段（domain 側）
  ///
  /// In zh, this message translates to:
  /// **'已宣告 {declared}／{total} 個 domain'**
  String pathDeclarationBundlesPartial(int declared, int total);

  /// SPEC-004 §4.0.6：宣告狀態行 detail 片段（非 domain 側缺席）
  ///
  /// In zh, this message translates to:
  /// **'缺非 domain 路徑清單'**
  String get pathDeclarationNonDomainMissing;

  /// SPEC-004 §4.0.6：宣告狀態行 detail 片段（bundle 總數為 0 時取代 pathDeclarationBundlesPartial）
  ///
  /// In zh, this message translates to:
  /// **'尚未宣告任何 domain'**
  String get pathDeclarationNoBundles;

  /// SPEC-001 §5：兩側皆未宣告的整體狀態，不顯示路徑數
  ///
  /// In zh, this message translates to:
  /// **'本專案未宣告路徑'**
  String get pathDeclarationNoneLine;

  /// SPEC-004 §4.0.6：宣告狀態行 detail 片段（清單檔存在但格式錯誤，取代「缺」）
  ///
  /// In zh, this message translates to:
  /// **'非 domain 路徑清單格式錯誤'**
  String get pathDeclarationNonDomainMalformed;

  /// SPEC-004 §4.0.6〈1.94 新增〉：orphan-event，形態有發出無消費
  ///
  /// In zh, this message translates to:
  /// **'有步驟發出此事件，但沒有步驟消費，consumers 也未宣告'**
  String get gapOrphanEventEmittedNotConsumed;

  /// SPEC-004 §4.0.6〈1.94 新增〉：orphan-event，形態有消費無發出
  ///
  /// In zh, this message translates to:
  /// **'有步驟消費此事件，但沒有步驟發出，producers 也未宣告'**
  String get gapOrphanEventConsumedNotEmitted;

  /// SPEC-004 §4.0.6〈1.94 新增〉：event-declaration-mismatch，方向 consumers；domain 為宣告值原樣
  ///
  /// In zh, this message translates to:
  /// **'consumers 宣告了 {domain}，但沒有對應的步驟消費此事件'**
  String gapEventConsumerUnmatched(String domain);

  /// SPEC-004 §4.0.6〈1.94 新增〉：event-declaration-mismatch，方向 producers；domain 為宣告值原樣
  ///
  /// In zh, this message translates to:
  /// **'producers 宣告了 {domain}，但沒有對應的步驟發出此事件'**
  String gapEventProducerUnmatched(String domain);
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
