// 最近專案計數快照寫入（SPEC-005 §2.4〈計數快照〉〈計數寫入的回饋點〉）。
//
// 「E2」標註正向對照輸入：fixture 含兩類以上破洞，使 issueCount 的計法
// 有鑑別力（零破洞時任何計法皆為 0）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/app/recent_project_counts_writer.dart';
import 'package:graph_project_docs_manager/app/round_gaps.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/corpus/scan_summary.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/reference_classification.dart';
import 'package:graph_project_docs_manager/graph/reference_extraction.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_round_state.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';

const _key = 'workspace.recentProjects';
const _workspacePath = '/ws/fake';
const _nonDomainKey = 'non_domain_path_patterns';

GraphDefect _danglingDefect() => DanglingRefGraphDefect(
  ref: ReferenceValue(
    sourceId: 'UC-01',
    sourcePath: fakeUcPath,
    edgeTypeName: 'spawn',
    fieldName: 'spawned_tickets',
    isReverse: false,
    value: 'T-404',
    isShapeValid: true,
  ),
  reason: DanglingReason.targetMissing,
);

/// 含解析失敗與懸空引用兩類破洞、2 張 Ticket、nodeCount 為 7 的輪次。
ScanRoundResult _roundWithTwoGapKinds() {
  final base = fakeRound(
    parseFailureEvents: [fakeCarrierEvent('docs/a.md')],
    graphDefects: [_danglingDefect()],
    extraRawNodes: const [
      RawNode(path: 't1.md', frontmatter: {'id': 'T-1'}, typeName: 'Ticket'),
      RawNode(path: 't2.md', frontmatter: {'id': 'T-2'}, typeName: 'Ticket'),
    ],
  );
  final scan = base.scan;
  return ScanRoundResult(
    workspacePath: base.workspacePath,
    scan: CorpusScanResult(
      rawNodes: scan.rawNodes,
      parseErrors: scan.parseErrors,
      parseFailureEvents: scan.parseFailureEvents,
      schemaAmbiguousNodes: scan.schemaAmbiguousNodes,
      nonDomainPathsRead: scan.nonDomainPathsRead,
      summary: const ScanSummary(
        totalFilesScanned: 0,
        nodeCount: 7,
        nonNodeWithFrontmatterCount: 0,
        failureReasonCounts: <ParseResultKind, int>{},
        hitCarrierCount: 0,
        noHitCount: 0,
        undeterminedCount: 0,
        carrierPathQueryAvailable: true,
      ),
    ),
    graph: base.graph,
    schemaResolution: base.schemaResolution,
    isDegraded: false,
  );
}

class _Port implements WorkspacePreferencesPort {
  _Port(this.values);
  final Map<String, String?> values;

  @override
  Future<WorkspacePreferencesHandle> open() async => _Handle(values);
}

class _Handle implements WorkspacePreferencesHandle {
  _Handle(this.values);
  final Map<String, String?> values;

  @override
  String? readString(String key) => values[key];

  @override
  Future<bool> writeString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

const _seed =
    '[{"path": "$_workspacePath", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}]';

({ProviderContainer container, FakeScanRound round, Map<String, String?> store})
_setup({String seed = _seed}) {
  final store = <String, String?>{_key: seed};
  late final FakeScanRound fake;
  fake = FakeScanRound(produce: () => null);
  final container = ProviderContainer(
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(
        WorkspaceRepository(preferencesPort: _Port(store)),
      ),
      scanRoundProvider.overrideWith(() => fake),
    ],
  );
  addTearDown(container.dispose);
  container.read(recentProjectsProvider.notifier).state = [
    RecentProject(
      path: _workspacePath,
      lastOpenedAt: DateTime.utc(2026, 9, 20, 8),
    ),
  ];
  container.read(recentProjectCountsWriterProvider);
  return (container: container, round: fake, store: store);
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('recentProjectCountsOf', () {
    test('W-1 三個計數取自輪次（nodeCount／Ticket 數／破洞項數）', () {
      final counts = recentProjectCountsOf(_roundWithTwoGapKinds());

      expect(counts.nodeCount, 7);
      expect(counts.ticketCount, 2);
      expect(counts.issueCount, 2);
    });

    test('W-2（E2）issueCount 與破洞報告畫面項數、gapItemIdsOf 集合大小相等', () {
      final round = _roundWithTwoGapKinds();
      final state = gapReportStateFromRound(
        round,
        nonDomainPathsKey: _nonDomainKey,
      );
      final screenCount = switch (state) {
        GapReportFound(:final categories) ||
        GapReportUndeterminable(
          :final categories,
        ) => categories.fold<int>(0, (sum, c) => sum + c.items.length),
        _ => 0,
      };

      expect(screenCount, greaterThanOrEqualTo(2));
      expect(gapItemIdsOf(round).length, screenCount);
      expect(recentProjectCountsOf(round).issueCount, screenCount);
    });

    test('W-3 零破洞輪次 issueCount 為 0', () {
      expect(recentProjectCountsOf(fakeRound()).issueCount, 0);
    });
  });

  group('recentProjectCountsWriterProvider', () {
    test('W-4 ScanRoundCompleted 以 workspacePath 寫入並同步 provider', () async {
      final s = _setup();

      s.round.completeExternally(_roundWithTwoGapKinds());
      await _settle();

      final reloaded = await WorkspaceRepository(
        preferencesPort: _Port(s.store),
      ).loadRecentProjects();
      expect(reloaded.single.counts?.nodeCount, 7);
      expect(reloaded.single.counts?.ticketCount, 2);
      expect(reloaded.single.counts?.issueCount, 2);
      final synced = s.container.read(recentProjectsProvider).single.counts;
      expect(synced?.issueCount, 2);
    });

    test('W-5 進行中與取消（Idle）輪次不寫入，快照維持前一輪值', () async {
      final s = _setup();

      // produce 回 null：狀態經 Running 回到 Idle（對應失敗／取消輪次）。
      await s.round.rescan();
      s.round.discard();
      await _settle();

      expect(s.store[_key], _seed);
      expect(s.container.read(recentProjectsProvider).single.counts, isNull);
    });

    test('W-6 清單無同 path 項時不寫入、provider 不變', () async {
      const other =
          '[{"path": "/other", "lastOpenedAt": "2026-09-20T08:00:00.000Z"}]';
      final s = _setup(seed: other);

      s.round.completeExternally(_roundWithTwoGapKinds());
      await _settle();

      expect(s.store[_key], other);
      expect(s.container.read(recentProjectsProvider).single.counts, isNull);
    });
  });

  group('backfillRecentProjectCounts（0.6.0-W1-145）', () {
    final backfillProvider = Provider<Future<void> Function(String)>(
      (ref) =>
          (path) => backfillRecentProjectCounts(ref, path),
    );

    Future<ProviderContainer> firstRoundBeforeAdd() async {
      final s = _setup(seed: '[]');
      s.container.read(recentProjectsProvider.notifier).state = [];
      s.container.read(lastCompletedRoundProvider);
      s.round.completeExternally(_roundWithTwoGapKinds());
      await _settle();
      return s.container;
    }

    test('B-1 首輪先完成、再加入清單 → 補寫並同步 provider', () async {
      final container = await firstRoundBeforeAdd();
      final repository = container.read(workspaceRepositoryProvider);
      await repository.addRecentProject(_workspacePath);
      container.read(recentProjectsProvider.notifier).state = await repository
          .loadRecentProjects();

      await container.read(backfillProvider)(_workspacePath);

      final reloaded = await repository.loadRecentProjects();
      expect(reloaded.single.counts?.issueCount, 2);
      expect(reloaded.single.counts?.ticketCount, 2);
      final synced = container.read(recentProjectsProvider).single.counts;
      expect(synced?.nodeCount, 7);
    });

    test('B-2（E1 對照）最近完成輪次 workspacePath 不同 → 不補寫', () async {
      final container = await firstRoundBeforeAdd();
      final repository = container.read(workspaceRepositoryProvider);
      await repository.addRecentProject('/ws/other');
      container.read(recentProjectsProvider.notifier).state = await repository
          .loadRecentProjects();

      await container.read(backfillProvider)('/ws/other');

      final reloaded = await repository.loadRecentProjects();
      expect(reloaded.single.counts, isNull);
      expect(container.read(recentProjectsProvider).single.counts, isNull);
    });
  });
}
