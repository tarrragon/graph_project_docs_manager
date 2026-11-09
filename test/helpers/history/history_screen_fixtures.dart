/// 變更記錄畫面測試的具名 snapshot 與 fake notifier
/// （docs/test-design/SPEC-001-history-screen-test-design.md §1.4）。
///
/// 每個函式都回傳新物件，不共享可變狀態。時鐘固定為 [kHistoryTestNow]。
library;

import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/events/edge_event.dart';
import 'package:graph_project_docs_manager/history/events/edge_key.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';

import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';

import '../gap_round_fakes.dart';
import 'fake_process_runner.dart';
import '../pump_harness.dart';
import '../stub_workspace_repository.dart';
import '../window_sizes.dart';

/// 固定時鐘：2026-11-09T00:00:00Z。
final DateTime kHistoryTestNow = DateTime.utc(2026, 11, 9);

/// 測試用時鐘函式。
DateTime historyTestClock() => kHistoryTestNow;

const String _hash = 'a1b2c3d4e5f6';

int _secondsOf(int month, int day) =>
    DateTime.utc(2026, month, day).millisecondsSinceEpoch ~/ 1000;

EdgeEvent _event({
  required EdgeEventType type,
  required String edge,
  required String from,
  required String to,
  required String commit,
  required int seconds,
  bool isTicketCreation = false,
}) => EdgeEvent(
  type: type,
  key: EdgeKey(edge, from, to),
  declarersBefore: const [],
  declarersAfter: const [],
  commitId: commit,
  committedAtSeconds: seconds,
  author: 'tester',
  subject: 'subject $commit $_hash',
  isTicketCreation: isTicketCreation,
);

const List<String> _mainline = ['h5', 'h4', 'h3', 'h2', 'h1'];

const List<GitTagRef> _tag060 = [GitTagRef(name: 'v0.6.0', commitId: 'h3')];

HistoryCacheKey _key() =>
    const HistoryCacheKey(root: '/ws', head: 'h5', tableIdentity: 'table');

/// 有 tag：預設期間內 E0、E1、E2，期間外 E3，另有 ticket 建檔事件 E4。
HistoryScanSnapshot snapTagged({
  bool isShallow = false,
  bool degraded = false,
  DateTime? boundary,
}) => HistoryScanSnapshot(
  key: _key(),
  events: [
    _event(
      type: EdgeEventType.added,
      edge: 'uc_ticket_refs',
      from: 'UC-07',
      to: '0.7.0-W1-012.11',
      commit: 'h5',
      seconds: _secondsOf(11, 5),
    ),
    _event(
      type: EdgeEventType.removed,
      edge: 'blockedBy',
      from: '0.7.0-W1-012.11',
      to: '0.7.0-W1-012.9',
      commit: 'h5',
      seconds: _secondsOf(11, 5),
    ),
    _event(
      type: EdgeEventType.added,
      edge: 'domain_dependency',
      from: 'history',
      to: 'schema',
      commit: 'h4',
      seconds: _secondsOf(11, 3),
    ),
    _event(
      type: EdgeEventType.added,
      edge: 'uc_ticket_refs',
      from: 'UC-07',
      to: '0.7.0-W1-012.4',
      commit: 'h4',
      seconds: _secondsOf(11, 3),
      isTicketCreation: true,
    ),
    _event(
      type: EdgeEventType.added,
      edge: 'spec_association',
      from: 'UC-01',
      to: 'SPEC-001',
      commit: 'h2',
      seconds: _secondsOf(10, 1),
    ),
  ],
  mainline: _mainline,
  tags: _tag060,
  isShallow: isShallow,
  isBuiltinTableDegraded: degraded,
  shallowBoundaryDate: boundary,
);

/// 無 tag：最近 30 天內 1 筆、30 天前 1 筆。
HistoryScanSnapshot snapNoTag() => HistoryScanSnapshot(
  key: _key(),
  events: [
    _event(
      type: EdgeEventType.added,
      edge: 'spec_association',
      from: 'UC-01',
      to: 'SPEC-001',
      commit: 'h5',
      seconds: _secondsOf(11, 1),
    ),
    _event(
      type: EdgeEventType.added,
      edge: 'spec_association',
      from: 'UC-02',
      to: 'SPEC-001',
      commit: 'h4',
      seconds: _secondsOf(9, 1),
    ),
  ],
  mainline: _mainline,
  tags: const [],
  isShallow: false,
  isBuiltinTableDegraded: false,
);

/// 有 tag：預設期間內 0 筆、tag 之前 2 筆。
HistoryScanSnapshot snapEmptyDefault() => HistoryScanSnapshot(
  key: _key(),
  events: [
    _event(
      type: EdgeEventType.added,
      edge: 'spec_association',
      from: 'UC-01',
      to: 'SPEC-001',
      commit: 'h2',
      seconds: _secondsOf(10, 1),
    ),
    _event(
      type: EdgeEventType.added,
      edge: 'spec_association',
      from: 'UC-02',
      to: 'SPEC-001',
      commit: 'h1',
      seconds: _secondsOf(9, 1),
    ),
  ],
  mainline: _mainline,
  tags: _tag060,
  isShallow: false,
  isBuiltinTableDegraded: false,
);

/// 有 commit 但全歷史 0 筆事件。
HistoryScanSnapshot snapAllEmpty() => HistoryScanSnapshot(
  key: _key(),
  events: const [],
  mainline: _mainline,
  tags: _tag060,
  isShallow: false,
  isBuiltinTableDegraded: false,
);

/// 尚無 commit。
HistoryScanSnapshot snapNoCommit() => const HistoryScanSnapshot.noCommit(
  key: HistoryCacheKey(root: '/ws', head: '', tableIdentity: 'table'),
  isBuiltinTableDegraded: false,
);

/// 淺層：同 [snapTagged]，邊界 commit 日期 2026-10-01。
HistoryScanSnapshot snapShallow() =>
    snapTagged(isShallow: true, boundary: DateTime.utc(2026, 10, 1));

/// 降級：同 [snapTagged]，內建型別表降級。
HistoryScanSnapshot snapDegraded() => snapTagged(degraded: true);

/// 八狀態各一個代表值（ST-11、EX-1、LY-1 共用），依 SPEC-001 §10 順序。
List<(String rootKey, HistoryViewState state)> historyStateCases() => [
  ('state-history-loading', const HistoryLoading(processedCount: 7)),
  ('state-history-normal', HistoryLoaded(snapTagged())),
  ('state-history-empty', HistoryLoaded(snapEmptyDefault())),
  ('state-history-not-git', const HistoryNotGitRepo()),
  ('state-history-git-missing', const HistoryGitNotFound()),
  (
    'state-history-load-failed',
    const HistoryFailed(
      GitFailureReason.scanNonZeroExit,
      stderrSummary: 'fatal: bad object h3',
    ),
  ),
  ('state-history-cancelled', const HistoryCancelled()),
  ('state-history-project-unready', const HistorySchemaBlocked()),
];

/// 讓經 shell 啟動的 app 抵達 DomainReady（或「無可消費的型別表」）：
/// restore 回 Ready，gate 訊號齊備且版本等於覆寫的內建版本。
List<Override> historyGateOverrides({
  bool schemaJson = true,
  String root = '/ws',
}) => [
  workspaceRepositoryProvider.overrideWithValue(
    StubWorkspaceRepository(WorkspaceReady(root)),
  ),
  frameworkSignalProbeProvider.overrideWithValue(
    StubFrameworkSignalProbe(version: '0.0.1', schemaJson: schemaJson),
  ),
  builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
  fakeScanRoundOverride(),
];

/// pump 真實 app root，停在第七畫面，狀態由 fake notifier 固定。
Future<FakeHistoryNotifier> pumpHistoryApp(
  WidgetTester tester,
  HistoryViewState state, {
  List<Override> extra = const [],
  Locale locale = const Locale('zh'),
  WindowSize size = WindowSize.min,
  bool settle = true,
}) async {
  final (fake, overrides) = fakeHistoryOverrides(state);
  await tester.pumpWidget(const SizedBox());
  await pumpApp(
    tester,
    locale: locale,
    size: size,
    settle: settle,
    overrides: [
      ...historyGateOverrides(),
      selectedDestinationProvider.overrideWithInitial(
        (ref) => AppDestination.history,
      ),
      ...overrides,
      ...extra,
    ],
  );
  return fake;
}

/// 測試用掃描輸入（不含事件抽取規則）。
HistoryScanInputs historyTestScanInputs({
  HistorySchemaReadiness readiness = HistorySchemaReadiness.ready,
}) => HistoryScanInputs(
  schemaReadiness: readiness,
  tableIdentity: 'table',
  createBuilder: () => EdgeEventBuilder(
    extractor: DeclarationExtractor(
      activeEdgeTypes: const [],
      closedByIdPatterns: const [],
    ),
    ticketIdPattern: RegExp(r'^\d+$'),
  ),
);

/// 真實 `HistoryNotifier` 搭配 fake 程序執行器與測試掃描輸入。
List<Override> historyRealOverrides(
  FakeProcessRunner runner, {
  HistorySchemaReadiness readiness = HistorySchemaReadiness.ready,
}) => [
  historyProcessRunnerProvider.overrideWithValue(runner),
  historyScanInputsProvider.overrideWithInitial(
    (ref) => historyTestScanInputs(readiness: readiness),
  ),
  historyClockProvider.overrideWithValue(historyTestClock),
];

/// pump 真實 app root，使用真實 notifier；停在 [start] 畫面。
Future<void> pumpHistoryRealApp(
  WidgetTester tester,
  FakeProcessRunner runner, {
  AppDestination start = AppDestination.history,
  List<Override> extra = const [],
  Locale locale = const Locale('zh'),
  WindowSize size = WindowSize.min,
  bool settle = true,
}) => pumpApp(
  tester,
  locale: locale,
  size: size,
  settle: settle,
  overrides: [
    ...historyGateOverrides(),
    selectedDestinationProvider.overrideWithInitial((ref) => start),
    ...historyRealOverrides(runner),
    ...extra,
  ],
);

/// 取目前 app 的 provider 容器。
ProviderContainer historyContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// 狀態固定、記錄 `enter`／`refresh`／`cancel` 呼叫次數的 fake notifier。
class FakeHistoryNotifier extends HistoryNotifier {
  FakeHistoryNotifier(this.fixed);

  final HistoryViewState fixed;
  int enterCalls = 0;
  int refreshCalls = 0;
  int cancelCalls = 0;

  @override
  HistoryViewState build() => fixed;

  @override
  Future<void> enter() async => enterCalls++;

  @override
  Future<void> refresh() async => refreshCalls++;

  @override
  void cancel() => cancelCalls++;
}

/// 注入固定狀態的 override 與固定時鐘；回傳的 fake 可讀呼叫次數。
(FakeHistoryNotifier, List<Override>) fakeHistoryOverrides(
  HistoryViewState state,
) {
  final fake = FakeHistoryNotifier(state);
  return (
    fake,
    [
      historyProvider.overrideWith(() => fake),
      historyClockProvider.overrideWithValue(historyTestClock),
    ],
  );
}
