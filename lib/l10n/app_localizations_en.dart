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
  String get chooseWorkspaceFolder => 'Choose Workspace Folder';

  @override
  String get folderAccessRationale =>
      'Pick a folder for the app to read and edit documents in. This permission is remembered, so you won\'t need to select it again.';

  @override
  String workspaceUnavailable(String reason) {
    return 'Cannot access the previous folder: $reason';
  }

  @override
  String folderUnavailableMessage(String reason) {
    return 'Folder unavailable: $reason';
  }

  @override
  String get workspaceNotRemembered =>
      'Selected, but you will need to choose again next time';

  @override
  String get chooseFolderUnavailableMessage =>
      'Could not open the folder picker; the app may not be installed correctly';

  @override
  String get domainLoading => 'Resolving graph nodes…';

  @override
  String get cancelLoadingAction => 'Cancel loading';

  @override
  String get emptyGraphMessage => 'This project has no graph nodes yet';

  @override
  String get notFrameworkProjectMessage =>
      'This folder is missing the configuration this framework requires (both .claude/VERSION and the type table are absent) — it does not use this framework';

  @override
  String get notFrameworkProjectExplanation =>
      'This app needs either .claude/VERSION or the type table (.claude/skills/doc/doc_system/core/tracking_schema.json) to determine this project\'s framework version';

  @override
  String schemaUnconsumableMessage(String version) {
    return 'This project\'s framework version ($version) predates the machine-readable export of the graph type table';
  }

  @override
  String schemaUnconsumableDegradedExplanation(String builtinVersion) {
    return 'You can view this with the app\'s built-in schema (v$builtinVersion); tier-B edges will not render';
  }

  @override
  String schemaIncompatibleMessage(String appVersion, String projectVersion) {
    return 'This app supports schema version $appVersion; this project uses $projectVersion, which is incompatible';
  }

  @override
  String get schemaVersionUnreadableMessage =>
      'The version of this project\'s schema file cannot be read. Regenerate the schema in that project and open it again';

  @override
  String get emptyUcMessage => 'This project has no UC nodes yet';

  @override
  String get flowUnstructuredMessage =>
      'No structured flow has been written yet';

  @override
  String get flowParseFailedMessage =>
      'This UC\'s flow block failed to parse. Open the source file to fix it.';

  @override
  String get swimlaneFlowParseFailedHint =>
      'Some flow blocks in this UC failed to parse; the lanes show the first valid block only';

  @override
  String get ucUnsetPrompt => 'Select a UC to view its flow';

  @override
  String get ucSelectorTitle => 'Select UC';

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
  String get useBuiltinSchemaAction => 'View with the app\'s built-in schema';

  @override
  String get gotoGapsReportAction => 'Go to Gap Report';

  @override
  String get openSourceFileAction => 'Open Source File';

  @override
  String get sourceFileNotFoundSnackbarMessage => 'File not found';

  @override
  String get externalOpenFailedMessage =>
      'Could not open with the default application';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get viewRelationsAction => 'View Relations';

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
  String get switcherChooseFolderUnavailableReason =>
      'Could not open the folder picker; the app may not be installed correctly';

  @override
  String switcherFolderUnavailableReason(String reason) {
    return 'Folder unavailable: $reason';
  }

  @override
  String get probeTimeoutReason => 'May be an unmounted disk';

  @override
  String get sourceFileStillMissingMessage => 'File still not found';

  @override
  String get sourceFileUnparsableMessage =>
      'File exists but cannot be parsed; see the gap report';

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
  String get columnBlockedBy => 'blockedBy';

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
  String get relationProposedLabel => 'Proposed';

  @override
  String relationItemProposedA11yLabel(String id) {
    return 'Related node $id, proposed edge, shape may change';
  }

  @override
  String get swimlaneScreenLaneName => 'Screen';

  @override
  String get swimlaneUnplacedLaneName => 'Unplaced';

  @override
  String get currentProjectA11yLabel => 'Current project';

  @override
  String get degradedSchemaShortLabel => 'Built-in schema';

  @override
  String projectSummaryLabel(int nodes, int tickets) {
    return '$nodes nodes · $tickets tickets';
  }

  @override
  String healthBadgeA11yLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String get switcherTitle => 'Switch project';

  @override
  String get schemaKnownRangeLabel => 'Supported schema version range';

  @override
  String schemaKnownRangeValue(String appVersion) {
    return 'Up to $appVersion';
  }

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
  String get swimlaneUcUnsetPrompt =>
      'No UC selected yet — pick a cell in the matrix or select a UC in the UC Flow view';

  @override
  String get swimlaneProjectionPendingPrompt =>
      'Preparing swimlane: this UC\'s steps appear when the scan completes';

  @override
  String swimlanePanelTitle(String ucId, String ucTitle) {
    return '$ucId $ucTitle';
  }

  @override
  String degradedSchemaBadgeLabel(
    String builtinVersion,
    String projectVersion,
  ) {
    return 'Degraded schema (builtin $builtinVersion / project $projectVersion)';
  }

  @override
  String inferredVersionBadgeLabel(String inferredVersion) {
    return 'Version inferred from schema (v$inferredVersion)';
  }

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
  String get gapCategoryParseFailure => 'Parse Failures';

  @override
  String get gapCategoryFlowBlockMalformed => 'Flow Block Parse Failures';

  @override
  String get gapCategoryNonDomainPathsMalformed =>
      'Malformed Non-domain Path List';

  @override
  String get gapCategoryGraphDefect => 'Graph Defects';

  @override
  String get gapCategoryGraphDefectFlow => 'Flow Defects';

  @override
  String get gapParseNoFrontmatter => 'No frontmatter';

  @override
  String get gapParseFrontmatterUnclosed => 'Frontmatter is not closed';

  @override
  String get gapParseFrontmatterNotMap => 'Frontmatter is empty or not a map';

  @override
  String get gapParseYamlInvalid => 'The frontmatter YAML could not be parsed';

  @override
  String get gapParseUnreadableEncoding =>
      'Could not read the file: invalid encoding';

  @override
  String get gapParseUnreadablePermission =>
      'Could not read the file: permission denied';

  @override
  String get gapParseUnreadableMissing =>
      'Could not read the file: it no longer exists';

  @override
  String gapParseTypeAmbiguous(String types) {
    return 'Type is ambiguous; candidates: $types';
  }

  @override
  String get gapFlowBlockMalformed =>
      'The flow block failed to parse; fix it and rescan';

  @override
  String gapNonDomainPathsNonStringElements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non-string elements in the list',
      one: '1 non-string element in the list',
    );
    return '$_temp0';
  }

  @override
  String get gapNonDomainPathsYamlInvalid =>
      'The list file\'s YAML could not be parsed';

  @override
  String gapNonDomainPathsKeyMissing(String key) {
    return 'The list file is missing the $key key';
  }

  @override
  String gapNonDomainPathsNotList(String key) {
    return 'The value of $key in the list file is not a list';
  }

  @override
  String gapDanglingRefTargetMissing(String field, String value) {
    return '$value in $field does not exist';
  }

  @override
  String gapDanglingRefTargetDuplicated(String field, String value) {
    return '$value in $field matches more than one node';
  }

  @override
  String gapMalformedRefInvalidShape(String field, String value) {
    return 'The value $value in $field is malformed';
  }

  @override
  String gapMalformedRefPatternMismatch(String field, String value) {
    return 'The value $value in $field does not match the ID pattern';
  }

  @override
  String gapMalformedRefSelfReference(String field) {
    return '$field refers to the node itself';
  }

  @override
  String gapDuplicateId(String id, int count, String paths) {
    return 'ID $id appears in $count files: $paths';
  }

  @override
  String gapMultiSource(String edgeType, String targets) {
    return '$edgeType allows one target but points to $targets';
  }

  @override
  String gapFlowEventUnresolved(String stepId, String field, String value) {
    return 'Step $stepId: $field refers to an event that does not exist: $value';
  }

  @override
  String gapFlowRefUnresolved(String stepId, String field, String value) {
    return 'Step $stepId: $field cannot be resolved: $value';
  }

  @override
  String gapFlowStepIdDuplicated(String stepId) {
    return 'Step ID $stepId is duplicated in this UC';
  }

  @override
  String gapTraversesUndeclared(String stepId, String value) {
    return 'Step $stepId: traverses has an undeclared domain: $value';
  }

  @override
  String gapTraversesMissing(String stepId) {
    return 'Step $stepId is missing the traverses field';
  }

  @override
  String gapDomainDeclaredTwice(String domain, String bundles) {
    return 'Domain $domain is declared by more than one DomainBundle: $bundles';
  }

  @override
  String get gapCategoryOrphanEvent => 'Orphan Events';

  @override
  String get gapCategoryEventDeclarationMismatch =>
      'Event Declaration Mismatch';

  @override
  String gapItemLineLabel(int lineNumber) {
    return 'Line $lineNumber';
  }

  @override
  String get scanCompleteNotificationTitle => 'Gap scan complete';

  @override
  String scanCompleteNotificationBody(int count) {
    return '$count gaps detected';
  }

  @override
  String get scanCompleteNoGapsNotificationBody => 'No gaps detected';

  @override
  String scanCompleteSnackbarMessage(int count) {
    return 'Scan complete: $count gaps detected';
  }

  @override
  String get scanCompleteNoGapsSnackbarMessage =>
      'Scan complete: no gaps detected';

  @override
  String get scanCompleteUndeterminableNotificationBody =>
      'Gaps could not be determined. See the gap report for the reason.';

  @override
  String get scanCompleteUndeterminableSnackbarMessage =>
      'Scan finished: gaps could not be determined';

  @override
  String get gapsUndeterminableReasonScanFailed =>
      'An unexpected error occurred during the scan, so gaps cannot be determined. Try rescanning.';

  @override
  String get viewGapsAction => 'View';

  @override
  String get projectUnreadyReasonNotSelected => 'No project selected yet';

  @override
  String get projectUnreadyReasonLoading => 'Graph loading';

  @override
  String get projectUnreadyReasonIncompatible =>
      'This project is not usable with this app';

  @override
  String get projectUnreadyReasonLoadFailed => 'Graph failed to load';

  @override
  String get domainLoadFailedMessage =>
      'An unexpected error occurred while scanning this project, so the graph could not be loaded.';

  @override
  String domainGraphUnavailableMessage(String appVersion) {
    return 'This project\'s schema version is outside the range this app knows (up to $appVersion), so the latest scan could not build the graph. Until the schema is fixed or regenerated, rescanning will give the same result';
  }

  @override
  String get domainGraphUnavailableScanning => 'Scanning…';

  @override
  String get reloadAction => 'Reload';

  @override
  String get gotoDomainViewAction => 'Go to Domain View';

  @override
  String get gotoTicketsListAction => 'Go to Ticket List';

  @override
  String traceabilityNoDownstream(String layer) {
    return '(No $layer yet)';
  }

  @override
  String get traceabilityTicketsNotLoadedHint => 'Tickets not loaded yet';

  @override
  String get ticketsFiltersClearedSnackbarMessage =>
      'Search and filters cleared to show the target ticket';

  @override
  String get ticketsTargetNotFoundMessage =>
      'Ticket not found; it may have been removed';

  @override
  String get undoAction => 'Undo';

  @override
  String get columnEvent => 'Event';

  @override
  String get columnEmitter => 'Emitted by';

  @override
  String get columnConsumer => 'Consumed by';

  @override
  String eventFlowStepDomain(String step, String domain) {
    return '$step · $domain';
  }

  @override
  String eventOutsideUc(String domains) {
    return 'Outside this UC ($domains)';
  }

  @override
  String get eventOutsideUcBare => 'Outside this UC';

  @override
  String get orphanEventMarkerLabel => 'Orphan event';

  @override
  String get builtinPathPatternBadgeLabel =>
      'Path patterns from built-in schema';

  @override
  String get gapsUndeterminableTitle => 'Gaps cannot be determined';

  @override
  String get gapsUndeterminableReasonVersionOutOfRange =>
      'The project schema version is outside the range this app knows and lacks path patterns, so node files cannot be identified; parse failures are not listed';

  @override
  String get gapsUndeterminableReasonNoPathPattern =>
      'Neither the project schema nor the built-in one has path patterns, so node files cannot be identified; parse failures are not listed';

  @override
  String pathDeclarationIncompleteLine(String detail, int count) {
    return 'Path declarations incomplete: $detail ($count paths affected)';
  }

  @override
  String pathDeclarationBundlesPartial(int declared, int total) {
    return '$declared of $total domains declared';
  }

  @override
  String get pathDeclarationNonDomainMissing => 'non-domain path list missing';

  @override
  String get pathDeclarationNoBundles => 'no domains declared';

  @override
  String get pathDeclarationNoneLine => 'This project declares no paths';

  @override
  String get pathDeclarationNonDomainMalformed =>
      'non-domain path list is malformed';

  @override
  String get gapOrphanEventEmittedNotConsumed =>
      'Emitted by a step, but no step consumes it and no consumers are declared';

  @override
  String get gapOrphanEventConsumedNotEmitted =>
      'Consumed by a step, but no step emits it and no producers are declared';

  @override
  String gapEventConsumerUnmatched(String domain) {
    return 'Declared consumer $domain has no matching step that consumes this event';
  }

  @override
  String gapEventProducerUnmatched(String domain) {
    return 'Declared producer $domain has no matching step that emits this event';
  }
}
