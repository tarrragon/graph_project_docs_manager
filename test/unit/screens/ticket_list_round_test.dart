// 需求：0.6.0-W1-073.3；SPEC-001 §4〈Ticket 清單由掃描輪次衍生〉〈票列欄位的
// 取值來源〉、SPEC-003 §3.4〈生命週期〉。Ticket 清單讀最後完成輪次，票列欄位取
// TicketDetail 回傳的 frontmatter。「E1」標註對照輸入。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/corpus/topic_files_reader.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/tokens/tokens.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';

RawNode _ticket(String id, [Map<String, dynamic> extra = const {}]) => RawNode(
  path: 'docs/work-logs/$id.md',
  frontmatter: {'id': id, ...extra},
  typeName: 'Ticket',
);

ParseFailureEvent _failure(String path, String? nodeType) => ParseFailureEvent(
  path: path,
  reason: 'noFrontmatter',
  failureReason: CarrierParseFailureReason.noFrontmatter,
  nodeType: nodeType,
  candidateTypes: [?nodeType],
  schemaAmbiguous: false,
  salvagedFields: const [],
  lostFields: const [],
  severity: ParseFailureSeverity.edgeAffecting,
);

ScanRoundResult _round({
  List<RawNode> tickets = const [],
  List<ParseFailureEvent> failures = const [],
  EdgeTypeUnavailableReason? graphUnavailable,
}) => fakeRound(
  nodes: const [],
  extraRawNodes: tickets,
  parseFailureEvents: failures,
  graphUnavailable: graphUnavailable,
);

(ProviderContainer, FakeScanRound) _harness({
  ScanRoundResult? first,
  List<Override> overrides = const [],
}) {
  final fake = FakeScanRound(produce: () => _round());
  final container = ProviderContainer(
    overrides: [scanRoundProvider.overrideWith(() => fake), ...overrides],
  );
  addTearDown(container.dispose);
  // 原因取自 Domain 視圖狀態（1.0.0-W3-661）：預設 Loading 會落未就緒。
  container.read(domainViewStateProvider.notifier).state = const DomainReady(
    mode: DomainMode.matrix,
  );
  container.read(currentWorkspaceStateProvider.notifier).state =
      const WorkspaceReady('/ws/fake');
  container.read(scanRoundProvider);
  container.read(lastCompletedRoundProvider);
  container.read(ticketListStateProvider);
  if (first != null) fake.completeExternally(first);
  return (container, fake);
}

ScanRoundResult _roundWithTopics(
  TopicFilesReadResult read, {
  List<RawNode> tickets = const [],
}) {
  final base = _round(tickets: tickets);
  final s = base.scan;
  return ScanRoundResult(
    workspacePath: base.workspacePath,
    scan: CorpusScanResult(
      rawNodes: s.rawNodes,
      parseErrors: s.parseErrors,
      parseFailureEvents: s.parseFailureEvents,
      schemaAmbiguousNodes: s.schemaAmbiguousNodes,
      summary: s.summary,
      topicFilesRead: read,
    ),
    graph: base.graph,
    schemaResolution: base.schemaResolution,
    isDegraded: base.isDegraded,
  );
}

TopicFilesReadResult _topicRead(
  TopicFileStatus assignments,
  TopicFileStatus registry, [
  Map<String, String> topics = const {},
]) => TopicFilesReadResult(
  ticketTopics: topics,
  assignmentsStatus: assignments,
  registryStatus: registry,
  events: const [],
);

TicketsReady _ready(ProviderContainer c) =>
    c.read(ticketListStateProvider) as TicketsReady;

void main() {
  group('狀態：由最後完成輪次衍生', () {
    test('E1 對照：尚無完成輪次 → 專案未就緒（載入中），不是未載入／載入中態', () {
      final (c, _) = _harness();
      final state = c.read(ticketListStateProvider);
      expect(state, isA<TicketsProjectUnready>());
      expect(
        (state as TicketsProjectUnready).reason,
        ProjectUnreadyReason.loading,
      );
    });

    test('輪次完成且有票 → 正常（TicketsReady）', () {
      final (c, _) = _harness(first: _round(tickets: [_ticket('T-1')]));
      expect(c.read(ticketListStateProvider), isA<TicketsReady>());
    });

    test('輪次完成且票數為 0 → 無 ticket', () {
      final (c, _) = _harness(first: _round());
      expect(c.read(ticketListStateProvider), isA<TicketsEmpty>());
    });

    test('Domain 視圖未就緒原因優先於輪次', () {
      final (c, _) = _harness(
        first: _round(tickets: [_ticket('T-1')]),
        overrides: [
          projectUnreadyReasonProvider.overrideWithValue(
            ProjectUnreadyReason.incompatible,
          ),
        ],
      );
      final state = c.read(ticketListStateProvider);
      expect(state, isA<TicketsProjectUnready>());
      expect(
        (state as TicketsProjectUnready).reason,
        ProjectUnreadyReason.incompatible,
      );
    });

    test('建圖不可用不影響本畫面（列取自 rawNodes）', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [_ticket('T-1')],
          graphUnavailable:
              EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
        ),
      );
      expect(_ready(c).tickets.map((t) => t.id), ['T-1']);
    });
  });

  group('票列欄位取值（TicketDetail frontmatter）', () {
    test('ID／標題／狀態／優先／blockedBy 取 frontmatter 原值，依輪次載入序', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-2', {
              'title': 'Beta',
              'status': 'pending',
              'priority': 'P1',
              'blockedBy': ['T-1', 'T-9'],
            }),
            _ticket('T-1', {'title': 'Alpha', 'status': 'completed'}),
          ],
        ),
      );
      final rows = _ready(c).tickets;
      expect(rows.map((t) => t.id), ['T-2', 'T-1']);
      expect(rows[0].title, 'Beta');
      expect(rows[0].status, 'pending');
      expect(rows[0].priority, 'P1');
      expect(rows[0].blockedBy, ['T-1', 'T-9'], reason: '指向不存在 ID 的值照留');
      expect(rows[1].priority, isNull);
      expect(rows[1].blockedBy, isEmpty);
      expect(rows.any((t) => t.corrupted), isFalse);
    });

    test('標題缺席或非字串 → 佔位「—」；狀態／優先非字串 → null', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-1', {'status': 3, 'priority': 1}),
            _ticket('T-2', {'title': 42}),
          ],
        ),
      );
      final rows = _ready(c).tickets;
      expect(rows[0].title, '—');
      expect(rows[0].status, isNull);
      expect(rows[0].priority, isNull);
      expect(rows[1].title, '—');
    });

    test('值不在框架值域內時照原值保留', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-1', {'status': 'weird', 'priority': 'P9'}),
          ],
        ),
      );
      final row = _ready(c).tickets.single;
      expect(row.status, 'weird');
      expect(row.priority, 'P9');
    });

    test('blockedBy 缺席、非清單 → 空；非字串元素略過', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-1'),
            _ticket('T-2', {'blockedBy': 'T-1'}),
            _ticket('T-3', {
              'blockedBy': ['T-1', 7, null, 'T-2'],
            }),
          ],
        ),
      );
      final rows = _ready(c).tickets;
      expect(rows[0].blockedBy, isEmpty);
      expect(rows[1].blockedBy, isEmpty);
      expect(rows[2].blockedBy, ['T-1', 'T-2']);
    });

    test('重複 ID 的票不成列（FR-02 排除，查無 TicketDetail）', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-1', {'title': 'A'}),
            _ticket('T-dup', {'title': 'first'}),
            _ticket('T-dup', {'title': 'second'}),
            _ticket('T-3', {'title': 'C'}),
          ],
        ),
      );
      expect(_ready(c).tickets.map((t) => t.id), ['T-1', 'T-3']);
    });

    test('非 Ticket 型別的節點不成列', () {
      final (c, _) = _harness(
        first: fakeRound(
          nodes: const [fakeUcNode],
          extraRawNodes: [_ticket('T-1')],
        ),
      );
      expect(_ready(c).tickets.map((t) => t.id), ['T-1']);
    });
  });

  group('損壞票集合（EVT-CORPUS-003，歸屬型別為 Ticket）', () {
    test('損壞票計入票數：ID 取檔名、標題取檔名含副檔名、其餘欄為空', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [
            _ticket('T-1', {'title': 'A', 'status': 'pending'}),
          ],
          failures: [
            _failure('docs/work-logs/v0/tickets/0.25.0-W1-010.md', 'Ticket'),
          ],
        ),
      );
      final state = _ready(c);
      expect(state.tickets.map((t) => t.id), ['T-1', '0.25.0-W1-010']);
      final broken = state.tickets.last;
      expect(broken.corrupted, isTrue);
      expect(broken.title, '0.25.0-W1-010.md');
      expect(broken.status, isNull);
      expect(broken.priority, isNull);
      expect(broken.blockedBy, isEmpty);
      expect(state.corruptedCount, 1);
    });

    test('E1 對照：歸屬型別非 Ticket 或平手（null）的失敗不計入', () {
      final (c, _) = _harness(
        first: _round(
          tickets: [_ticket('T-1')],
          failures: [
            _failure('docs/spec/ui/SPEC-001.md', 'SPEC'),
            _failure('docs/unknown.md', null),
          ],
        ),
      );
      final state = _ready(c);
      expect(state.corruptedCount, 0);
      expect(state.tickets.map((t) => t.id), ['T-1']);
    });

    test('全部失敗 → 仍是正常（票數＝損壞票數 > 0），不是無 ticket', () {
      final (c, _) = _harness(
        first: _round(failures: [_failure('docs/a/T-x.md', 'Ticket')]),
      );
      final state = c.read(ticketListStateProvider);
      expect(state, isA<TicketsReady>());
      expect((state as TicketsReady).corruptedCount, 1);
    });
  });

  group('輪次更新與切換專案', () {
    test('重掃進行中、取消重掃（Idle）：保留上一輪票列', () {
      final (c, fake) = _harness(first: _round(tickets: [_ticket('T-1')]));
      fake.state = const ScanRoundRunning('/ws/fake');
      expect(_ready(c).tickets.map((t) => t.id), ['T-1']);
      fake.state = const ScanRoundIdle();
      expect(_ready(c).tickets.map((t) => t.id), ['T-1']);
    });

    test('新輪次完成：列集合替換，模式、搜尋詞、篩選、排序保留', () {
      final (c, fake) = _harness(first: _round(tickets: [_ticket('T-1')]));
      c.read(ticketListStateProvider.notifier).state = _ready(c).copyWith(
        mode: TicketListMode.topic,
        searchQuery: 'abc',
        statusFilter: () => 'pending',
        sortKey: () => TicketSortKey.id,
        sortOrder: TicketSortOrder.desc,
      );
      fake.completeExternally(
        _round(tickets: [_ticket('T-1'), _ticket('T-2')]),
      );
      final state = _ready(c);
      expect(state.tickets.map((t) => t.id), ['T-1', 'T-2']);
      expect(state.mode, TicketListMode.topic);
      expect(state.searchQuery, 'abc');
      expect(state.statusFilter, 'pending');
      expect(state.sortKey, TicketSortKey.id);
      expect(state.sortOrder, TicketSortOrder.desc);
    });

    test('新輪次票數降為 0 → 無 ticket；再有票 → 回正常', () {
      final (c, fake) = _harness(first: _round(tickets: [_ticket('T-1')]));
      fake.completeExternally(_round());
      expect(c.read(ticketListStateProvider), isA<TicketsEmpty>());
      fake.completeExternally(_round(tickets: [_ticket('T-5')]));
      expect(_ready(c).tickets.map((t) => t.id), ['T-5']);
    });

    test('切換專案：清除票列與搜尋輸入，回專案未就緒（載入中）', () {
      final (c, _) = _harness(first: _round(tickets: [_ticket('T-1')]));
      c.read(ticketSearchInputProvider.notifier).state = 'abc';
      c.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/other');
      final state = c.read(ticketListStateProvider);
      expect(state, isA<TicketsProjectUnready>());
      expect(
        (state as TicketsProjectUnready).reason,
        ProjectUnreadyReason.loading,
      );
      expect(c.read(ticketSearchInputProvider), isNull);
    });
  });

  group('畫面（真實衍生，不注入狀態）', () {
    testWidgets('首輪未完成 → 專案未就緒；輪次完成 → 票列出現', (tester) async {
      final fake = FakeScanRound(produce: () => _round());
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/fake');
      await tester.pump();
      expect(
        find.byKey(const Key('state-tickets-project-unready')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('state-tickets-unloaded')), findsNothing);
      expect(find.byKey(const Key('state-tickets-loading')), findsNothing);

      fake.completeExternally(
        _round(
          tickets: [
            _ticket('T-1', {'title': 'Alpha'}),
            _ticket('T-2', {'title': 'Beta'}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card-tickets-T-1')), findsOneWidget);
      expect(find.byKey(const Key('card-tickets-T-2')), findsOneWidget);
    });

    testWidgets('搜尋防抖沿用 TicketSearchDebouncer：先 pump 防抖期再斷言', (tester) async {
      final fake = FakeScanRound(produce: () => _round());
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/fake');
      fake.completeExternally(
        _round(
          tickets: [
            _ticket('T-1', {'title': 'Alpha'}),
            _ticket('T-2', {'title': 'Beta'}),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('input-tickets-search')),
        'Alpha',
      );
      await tester.pump(Motion.searchDebounce);
      expect(find.byKey(const Key('card-tickets-T-2')), findsNothing);
      expect(find.byKey(const Key('card-tickets-T-1')), findsOneWidget);
    });
  });

  group('主題模式讀輪次映射與缺主題檔提示（0.6.0-W1-113.3）', () {
    const present = TopicFileStatus.present;
    const absent = TopicFileStatus.absent;
    const unreadable = TopicFileStatus.unreadable;

    TicketsReady stateOf(TopicFilesReadResult read) {
      final (c, _) = _harness(
        first: _roundWithTopics(
          read,
          tickets: [_ticket('T-1'), _ticket('T-2')],
        ),
      );
      return _ready(c);
    }

    test('topic 取輪次映射，不讀票 frontmatter 的 topic', () {
      final (c, _) = _harness(
        first: _roundWithTopics(
          _topicRead(present, present, {'T-1': 'alpha'}),
          tickets: [
            _ticket('T-1', {'topic': 'fm'}),
            _ticket('T-2', {'topic': 'fm'}),
          ],
        ),
      );
      final topics = _ready(c).tickets.map((t) => t.topic).toList();
      expect(topics, ['alpha', null]);
    });

    test('指派檔 absent（清單 absent／present）→ 顯示提示', () {
      expect(stateOf(_topicRead(absent, absent)).noTopicFilesNotice, isTrue);
      expect(stateOf(_topicRead(absent, present)).noTopicFilesNotice, isTrue);
    });

    test('E1 對照：unreadable、只缺清單、兩檔在但無指派 → 不提示', () {
      for (final read in [
        _topicRead(unreadable, present),
        _topicRead(unreadable, absent),
        _topicRead(present, unreadable),
        _topicRead(present, absent, {'T-1': 'alpha'}),
        _topicRead(present, present),
      ]) {
        expect(stateOf(read).noTopicFilesNotice, isFalse);
      }
    });

    testWidgets('主題模式頂部說明列：absent 顯示、對照不顯示', (tester) async {
      final fake = FakeScanRound(produce: () => _round());
      final container = await pumpHarness(
        tester,
        child: const TicketListScreen(),
        overrides: [scanRoundProvider.overrideWith(() => fake)],
      );
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/ws/fake');
      fake.completeExternally(
        _roundWithTopics(_topicRead(absent, absent), tickets: [_ticket('T-1')]),
      );
      await tester.pumpAndSettle();
      container.read(ticketListStateProvider.notifier).state = (container.read(
        ticketListStateProvider,
      ) as TicketsReady).copyWith(mode: TicketListMode.topic);
      await tester.pumpAndSettle();
      const key = Key('text-tickets-no-topic-files');
      expect(find.byKey(key), findsOneWidget);

      fake.completeExternally(
        _roundWithTopics(
          _topicRead(present, present),
          tickets: [_ticket('T-1')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsNothing);
    });
  });
}
