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

  @override
  String get domainLoading => 'Resolving graph nodes…';

  @override
  String get emptyGraphMessage => 'This project has no graph nodes yet';

  @override
  String get notFrameworkProjectMessage =>
      'This folder has no docs/ — it does not use this framework';

  @override
  String schemaUnconsumableMessage(String version) {
    return 'This project\'s framework version ($version) predates the machine-readable export of the graph type table';
  }

  @override
  String schemaIncompatibleMessage(String appVersion, String projectVersion) {
    return 'This app supports schema version $appVersion; this project uses $projectVersion, which is incompatible';
  }

  @override
  String get emptyUcMessage => 'This project has no UC nodes yet';

  @override
  String get flowUnstructuredMessage =>
      'No structured flow has been written yet';

  @override
  String get emptyProposalMessage => 'This project has no proposals yet';

  @override
  String ticketsLoadPrompt(int count) {
    return 'Load $count tickets';
  }

  @override
  String ticketsLoadingProgress(int parsed) {
    return 'Parsed $parsed so far';
  }

  @override
  String get emptyTicketsMessage => 'This project has no tickets yet';

  @override
  String corruptedTicketsBadge(int count) {
    return '$count corrupted';
  }

  @override
  String get noGapsMessage => 'No gaps detected';

  @override
  String get fieldCorruptedMessage => 'Unreadable due to file corruption';

  @override
  String get sourceFileMissingMessage => 'Source file no longer exists';

  @override
  String lastKnownPathLabel(String path) {
    return 'Last known path: $path';
  }

  @override
  String get switcherChooseFolderPrompt => 'Choose a folder…';
}
