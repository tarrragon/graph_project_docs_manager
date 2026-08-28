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
