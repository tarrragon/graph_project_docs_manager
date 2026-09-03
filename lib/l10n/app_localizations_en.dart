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
  String get cancelLoadingAction => 'Cancel loading';

  @override
  String get emptyGraphMessage => 'This project has no graph nodes yet';

  @override
  String get notFrameworkProjectMessage =>
      'This folder has no docs/ — it does not use this framework';

  @override
  String get notFrameworkProjectExplanation =>
      'This app requires a docs/ directory at the project root, organized per framework conventions';

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
  String get ticketsUnassignedSection => 'Unassigned';

  @override
  String get emptyTicketsMessage => 'This project has no tickets yet';

  @override
  String corruptedTicketsBadge(int count) {
    return '$count corrupted';
  }

  @override
  String get gapReportScanning => 'Scanning for gaps…';

  @override
  String get cancelScanAction => 'Cancel';

  @override
  String get noGapsMessage => 'No gaps detected';

  @override
  String get noGapsScanScope => 'Scanned all nodes and edges';

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

  @override
  String get switcherChooseOtherFolder => 'Choose another';

  @override
  String get navDomain => 'Domain';

  @override
  String get navUcFlow => 'UC Flow';

  @override
  String get navTraceability => 'Traceability';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navGaps => 'Gaps';

  @override
  String get navNodeDetail => 'Node Detail';

  @override
  String get projectSwitcherEntryLabel => 'Switch project';

  @override
  String get projectSwitcherPlaceholderTitle => 'Project switcher';

  @override
  String get domainSwitchToMatrixAction => 'Switch to Matrix';

  @override
  String get domainSwitchToSwimlaneAction => 'Switch to Swimlane';

  @override
  String get ticketsSwitchToListAction => 'Switch to List';

  @override
  String get ticketsSwitchToTopicAction => 'Switch to Topic';

  @override
  String get openDocsFolderAction => 'Open docs Folder';

  @override
  String get openedExternallyMessage => 'Opened externally';

  @override
  String get viewSchemaDetailAction => 'View Details';

  @override
  String get gotoGapsReportAction => 'Go to Gap Report';

  @override
  String get openSourceFileAction => 'Open Source File';

  @override
  String get sourceFileNotFoundSnackbarMessage => 'File not found';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get viewRelationsAction => 'View Relations';

  @override
  String get backToDomainAction => 'Back to Domain View';

  @override
  String get backAction => 'Back';

  @override
  String get startLoadAction => 'Start Loading';

  @override
  String get rescanAction => 'Rescan';

  @override
  String get cancelInProgressAction => 'Cancelling…';

  @override
  String domainLoadingProcessedCount(int count) {
    return '$count nodes processed';
  }

  @override
  String gapsScanningProcessedCount(int count) {
    return '$count items scanned';
  }

  @override
  String get noNodeSelectedMessage => 'No node selected';

  @override
  String get gotoTraceabilityAction => 'Go to Traceability View';

  @override
  String projectUnavailableReasonLabel(String reason) {
    return 'Unavailable: $reason';
  }

  @override
  String get probeTimeoutReason => 'May be an unmounted disk';

  @override
  String get sourceFileStillMissingMessage => 'File still not found';

  @override
  String get expanderLabel => 'Expand or collapse';

  @override
  String get searchPlaceholder => 'Search';

  @override
  String get searchClearAction => 'Clear search';

  @override
  String get filterAllOption => 'All';

  @override
  String filterA11yLabel(String label, String value) {
    return '$label filter, current: $value';
  }

  @override
  String get filterStatusLabel => 'Status';

  @override
  String get filterPriorityLabel => 'Priority';

  @override
  String sortA11yLabel(String label, String order) {
    return '$label, sortable, current: $order';
  }

  @override
  String get sortNone => 'Unsorted';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get columnId => 'ID';

  @override
  String get columnTitle => 'Title';

  @override
  String get columnStatus => 'Status';

  @override
  String get columnPriority => 'Priority';

  @override
  String get columnStep => 'Step';

  @override
  String get columnDomain => 'Domain';

  @override
  String get columnEvents => 'Events';

  @override
  String matrixCellA11yLabel(String domain, String uc, String relation) {
    return '$domain × $uc: $relation';
  }

  @override
  String get legendDirect => 'Direct';

  @override
  String get legendIndirect => 'Indirect';

  @override
  String get legendNone => 'None';

  @override
  String matrixSubtotalA11yLabel(int count) {
    return 'Subtotal $count';
  }

  @override
  String laneA11yLabel(String name) {
    return 'Lane $name';
  }

  @override
  String get laneNodeActive => 'Active';

  @override
  String get laneNodeInactive => 'Inactive';

  @override
  String stepNumberA11yLabel(int number) {
    return 'Step $number';
  }

  @override
  String get gapMarkerLabel => 'Gap';

  @override
  String get damagedEdgeMarkerLabel => 'Edge damaged';

  @override
  String get damagedDetailMarkerLabel => 'Detail damaged';

  @override
  String relationItemA11yLabel(String id) {
    return 'Related node $id';
  }

  @override
  String get currentProjectA11yLabel => 'Current project';

  @override
  String projectSummaryLabel(int nodes, int tickets) {
    return '$nodes nodes · $tickets tickets';
  }

  @override
  String healthBadgeA11yLabel(int count) {
    return '$count issues';
  }

  @override
  String get switcherTitle => 'Switch project';

  @override
  String get schemaAppVersionLabel => 'Supported schema version';

  @override
  String get schemaProjectVersionLabel => 'Project version';

  @override
  String treeDepthA11yLabel(int depth) {
    return 'Level $depth';
  }

  @override
  String get openExternallyA11yLabel => 'Opens externally';

  @override
  String get loadingSkeletonA11yLabel => 'Loading';

  @override
  String progressA11yLabel(int parsed, int total) {
    return 'Progress $parsed of $total';
  }

  @override
  String get cellDetailPrompt => 'Select a cell to view details';

  @override
  String get cellDetailNotInvolved => 'This domain is not involved in this UC';

  @override
  String get cellDetailCloseAction => 'Close';

  @override
  String get cellDetailViewInSwimlaneAction => 'View in swimlane';

  @override
  String get modeMatrixLabel => 'Matrix';

  @override
  String get modeSwimlaneLabel => 'Swimlane';

  @override
  String get modeListLabel => 'List';

  @override
  String get modeTopicLabel => 'Topic';

  @override
  String ticketsSummaryLabel(int from, int to, int total) {
    return 'Showing $from–$to of $total';
  }

  @override
  String get ticketsVirtualScrollNote => 'Virtual scrolling, no pagination';

  @override
  String topicSectionSummary(int count, String priority) {
    return '($count tasks, top priority=$priority)';
  }

  @override
  String gapSectionCount(int count) {
    return '$count items';
  }

  @override
  String get gapCategoryMissingFrontmatter => '缺少 Frontmatter';

  @override
  String gapItemLineLabel(int lineNumber) {
    return '第 $lineNumber 行';
  }
}
