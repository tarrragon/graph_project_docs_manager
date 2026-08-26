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
}
