// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Docs Flow';

  @override
  String get sectionRecentDocuments => 'Recent Documents';

  @override
  String get statInProgress => 'In Progress';

  @override
  String get statPendingReview => 'Pending Review';

  @override
  String get statArchived => 'Archived';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
      zero: 'No documents',
    );
    return '$_temp0';
  }

  @override
  String get chooseWorkspaceFolder => 'Choose Workspace Folder';

  @override
  String get folderAccessRationale =>
      'Pick a folder for the app to read and edit documents in. This permission is remembered, so you won\'t need to select it again.';

  @override
  String workspaceReady(String path) {
    return 'Workspace: $path';
  }

  @override
  String workspaceUnavailable(String reason) {
    return 'Cannot access the previous folder: $reason';
  }

  @override
  String get changeWorkspaceFolder => 'Change Folder';
}
