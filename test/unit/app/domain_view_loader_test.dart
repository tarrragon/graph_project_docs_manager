// 需求：0.5.0-W1-114.14 B1～B9；SPEC-001 §1（載入中、矩陣的 UC 欄、降級型別表、
// FR-13 圖不可用）、SPEC-003 §2.4／§2.5。
// 「E1」「E2」標註對照輸入／正向對照輸入（test-assertion-design-rules）。
// B10 回歸（schema／analyze／全量）由命令列驗證。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/domain_uc_columns.dart';
import 'package:graph_project_docs_manager/app/domain_view_loader.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

LightNode _uc(String id) => LightNode(
  id: id,
  typeName: 'UC',
  status: null,
  title: null,
  path: 'docs/usecases/$id.md',
);

class _Harness {
  _Harness(this.container, this.fake, this.logs);

  final ProviderContainer container;
  final FakeScanRound fake;
  final List<(String, int)> logs;

  DomainViewState get state => container.read(domainViewStateProvider);
  DomainViewLoader get loader =>
      container.read(domainViewLoaderProvider.notifier);
}

_Harness _harness({
  required ScanRoundResult? Function() produce,
  ScanRoundResult? initial,
  Duration latency = Duration.zero,
  bool workspaceReady = false,
}) {
  final fake = FakeScanRound(
    produce: produce,
    initial: initial,
    latency: latency,
  );
  final logs = <(String, int)>[];
  final container = ProviderContainer(
    overrides: [
      scanRoundProvider.overrideWith(() => fake),
      domainViewStateProvider.overrideWith(
        (ref) => const DomainReady(mode: DomainMode.matrix),
      ),
      builtinSchemaVersionProvider.overrideWith((ref) async => '1.0.0'),
      domainViewLogSinkProvider.overrideWithValue(
        (message, {level = 500}) => logs.add((message, level)),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (workspaceReady) {
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceReady('/ws/fake');
  }
  // 建立擁有者（FakeScanRound.build 登記工作區監聽）。
  container.read(scanRoundProvider);
  return _Harness(container, fake, logs);
}

List<String> _idsOf(Iterable<LightNode> nodes) => orderedUcColumnIds(nodes);

void main() {
  group('載入中已處理計數（SPEC-003 §2.6）', () {
    // ignore_for_file: invalid_use_of_protected_member
    test('DomainLoading.processedCount 隨 ScanRoundRunning 更新', () async {
      final h = _harness(
        produce: () => fakeRound(),
        latency: const Duration(milliseconds: 50),
        workspaceReady: true,
      );
      final pending = h.loader.load();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect((h.state as DomainLoading).processedCount, 0);

      h.fake.state = const ScanRoundRunning('/ws/fake', processedCount: 32);
      expect((h.state as DomainLoading).processedCount, 32);
      h.fake.state = const ScanRoundRunning('/ws/fake', processedCount: 64);
      expect((h.state as DomainLoading).processedCount, 64);

      await pending;
      expect(h.state, isA<DomainReady>());
    });

    test('E2 被取代的載入不寫入計數', () async {
      final h = _harness(
        produce: () => fakeRound(),
        latency: const Duration(milliseconds: 50),
        workspaceReady: true,
      );
      final pending = h.loader.load();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      h.loader.cancelLoading();
      expect(h.state, isA<DomainUnset>());

      h.fake.state = const ScanRoundRunning('/ws/fake', processedCount: 99);
      expect(h.state, isA<DomainUnset>());
      await pending;
    });
  });

  group('B1 狀態推導', () {
    test('gate 通過後依序 Loading → Ready（帶矩陣）', () async {
      final h = _harness(produce: () => fakeRound());
      final seen = <Type>[];
      h.container.listen<DomainViewState>(
        domainViewStateProvider,
        (_, next) => seen.add(next.runtimeType),
      );

      await h.loader.load();

      expect(seen, [DomainLoading, DomainReady]);
      final ready = h.state as DomainReady;
      expect(h.container.read(domainMatrixProvider), isNotNull);
      expect(ready.mode, DomainMode.matrix);
    });

    test('E1 節點數 0 → DomainEmpty；>0 → DomainReady', () async {
      final empty = _harness(produce: () => fakeRound(nodes: const []));
      await empty.loader.load();
      expect(empty.state, isA<DomainEmpty>());

      final filled = _harness(produce: () => fakeRound());
      await filled.loader.load();
      expect(filled.state, isA<DomainReady>());
    });

    test('inferredVersion 與降級旗標帶入 Ready／Empty', () async {
      final ready = _harness(produce: () => fakeRound(isDegraded: true));
      await ready.loader.load(inferredVersion: '2.40.3');
      final readyState = ready.state as DomainReady;
      expect(readyState.inferredVersion, '2.40.3');
      expect(readyState.isDegraded, isTrue);

      final empty = _harness(produce: () => fakeRound(nodes: const []));
      await empty.loader.load(inferredVersion: '2.40.3');
      expect((empty.state as DomainEmpty).inferredVersion, '2.40.3');
    });
  });

  group('B2 共用輪次', () {
    test('E1 已有完成輪次不重掃；無輪次則掃一次', () async {
      final existing = fakeRound();
      final shared = _harness(produce: () => fakeRound(), initial: existing);
      await shared.loader.load();
      expect(shared.fake.produced, 0);

      final fresh = _harness(produce: () => fakeRound());
      await fresh.loader.load();
      expect(fresh.fake.produced, 1);
    });

    test('與破洞報告共用同一輪：先一方完成，另一方不再掃描', () async {
      final h = _harness(produce: () => fakeRound());
      await h.container.read(scanRoundProvider.notifier).ensureRound();
      await h.loader.load();
      expect(h.fake.produced, 1);
      expect(h.state, isA<DomainReady>());
    });
  });

  group('B3 UC 欄序', () {
    test('UC-9 在 UC-10 前；E1 字串排序會得到相反結果', () {
      final ids = _idsOf([_uc('UC-10'), _uc('UC-9'), _uc('UC-2')]);
      expect(ids, ['UC-2', 'UC-9', 'UC-10']);
      final stringSorted = ['UC-10', 'UC-9', 'UC-2']..sort();
      expect(stringSorted, isNot(ids));
    });

    test('數值相同依 code point：UC-01 在 UC-1 前（0 < 1）', () {
      expect(_idsOf([_uc('UC-1'), _uc('UC-01')]), ['UC-01', 'UC-1']);
    });

    test('無數字結尾者接在最後，彼此依 code point', () {
      final ids = _idsOf([_uc('UC-b'), _uc('UC-3'), _uc('UC-a'), _uc('UC-1')]);
      expect(ids, ['UC-1', 'UC-3', 'UC-a', 'UC-b']);
    });

    test('非 UC 型別節點不入欄', () {
      const other = LightNode(
        id: 'SPEC-1',
        typeName: 'SPEC',
        status: null,
        title: null,
        path: 'docs/spec/SPEC-1.md',
      );
      expect(_idsOf([other, _uc('UC-1')]), ['UC-1']);
    });
  });

  group('B4 本專案快照', () {
    test('矩陣 6 欄依序，48 格 19／10／19', () async {
      final event = await loadSnapshotEvent('graph_project_docs_manager');
      final h = _harness(produce: () => fakeRound(event: event));

      await h.loader.load();

      final matrix = h.container.read(domainMatrixProvider)!;
      expect(
        [for (final c in matrix.columns) c.id],
        ['UC-01', 'UC-02', 'UC-03', 'UC-04', 'UC-05', 'UC-06'],
      );
      final cells = [for (final r in matrix.rows) ...r.cells];
      expect(cells, hasLength(48));
      int countOf(DomainRelation k) =>
          cells.where((c) => c.relation == k).length;
      expect(countOf(DomainRelation.direct), 19);
      expect(countOf(DomainRelation.indirect), 10);
      expect(countOf(DomainRelation.none), 19);
    });
  });

  group('B5 泳道 provider', () {
    late GraphBuiltEvent event;
    setUpAll(() async {
      event = await loadSnapshotEvent('graph_project_docs_manager');
    });

    ProviderContainer containerWith(ScanRoundResult round) {
      final c = ProviderContainer(
        overrides: [
          scanRoundProvider.overrideWith(
            () => FakeScanRound(produce: () => round, initial: round),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('未選定 UC 為 null；選定後有泳道，變更選定隨之變更', () {
      final c = containerWith(fakeRound(event: event));
      expect(c.read(domainSwimlaneProvider), isNull);

      c.read(selectedUcProvider.notifier).state = 'UC-02';
      final first = c.read(domainSwimlaneProvider);
      expect(first, isA<DomainSwimlane>());

      c.read(selectedUcProvider.notifier).state = 'UC-03';
      final second = c.read(domainSwimlaneProvider);
      expect(second, isA<DomainSwimlane>());
      expect(
        (second! as DomainSwimlane).edges.length,
        isNot((first! as DomainSwimlane).edges.length),
      );
    });

    test('E1 flow 解析失敗 UC：列入帶旗標，未列入無旗標', () {
      final path = event.nodes.firstWhere((n) => n.id == 'UC-02').path;
      final listed = containerWith(
        fakeRound(
          event: event,
          flowEvents: [
            FlowParseFailedEvent(path: path, reason: 'flowBlockMalformed'),
          ],
        ),
      )..read(selectedUcProvider.notifier).state = 'UC-02';
      final unlisted = containerWith(fakeRound(event: event))
        ..read(selectedUcProvider.notifier).state = 'UC-02';

      expect(
        (listed.read(domainSwimlaneProvider)! as DomainSwimlane)
            .hasFlowParseFailure,
        isTrue,
      );
      expect(
        (unlisted.read(domainSwimlaneProvider)! as DomainSwimlane)
            .hasFlowParseFailure,
        isFalse,
      );
    });

    test('輪次尚未完成時為 null', () {
      final c = ProviderContainer(
        overrides: [
          scanRoundProvider.overrideWith(
            () => FakeScanRound(produce: () => null),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.read(selectedUcProvider.notifier).state = 'UC-02';
      expect(c.read(domainSwimlaneProvider), isNull);
    });
  });

  group('B6 降級', () {
    test('E1 進入降級會 discard 輪次並重掃：動作前後輪次不同', () async {
      late _Harness h;
      h = _harness(
        produce: () =>
            fakeRound(isDegraded: h.container.read(degradedSchemaProvider)),
      );
      await h.loader.load();
      final before =
          (h.container.read(scanRoundProvider) as ScanRoundCompleted).result;
      expect(before.isDegraded, isFalse);
      final discardsBefore = h.fake.discardCalls;

      await h.loader.enterDegradedView(
        builtinVersion: '2.40.3',
        projectVersion: '2.22.1',
      );

      final after =
          (h.container.read(scanRoundProvider) as ScanRoundCompleted).result;
      expect(h.fake.discardCalls, discardsBefore + 1);
      expect(identical(after, before), isFalse);
      expect(after.isDegraded, isTrue);
      expect((h.state as DomainReady).isDegraded, isTrue);
      expect(h.container.read(degradedSchemaProvider), isTrue);
      final versions = h.container.read(degradedSchemaVersionsProvider)!;
      expect(versions.builtinVersion, '2.40.3');
      expect(versions.projectVersion, '2.22.1');
    });
  });

  group('B7 取消與丟棄', () {
    test('取消時 Running 輪次被 discard，狀態落未選專案且完成結果作廢', () async {
      final h = _harness(
        produce: () => fakeRound(),
        latency: const Duration(milliseconds: 20),
      );
      final pending = h.loader.load();
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(scanRoundProvider), isA<ScanRoundRunning>());

      h.loader.cancelLoading();

      expect(h.fake.discardCalls, 1);
      expect(h.state, isA<DomainUnset>());
      await pending;
      expect(h.state, isA<DomainUnset>());
    });

    test('E1 非 Running 時取消不 discard 輪次', () async {
      final h = _harness(produce: () => fakeRound());
      await h.loader.load();
      h.loader.cancelLoading();
      expect(h.fake.discardCalls, 0);
      expect(h.state, isA<DomainUnset>());
    });

    test('ensureRound 回 null（工作區非 Ready）→ 未選專案', () async {
      final h = _harness(produce: () => null);
      await h.loader.load();
      expect(h.state, isA<DomainUnset>());
      expect(h.fake.produced, 1);
    });

    test('ensureRound 回 null（等待中被丟棄、工作區 Ready）→ 接續新輪次', () async {
      var calls = 0;
      final h = _harness(
        produce: () => ++calls == 1 ? null : fakeRound(),
        workspaceReady: true,
      );
      await h.loader.load();
      expect(h.fake.produced, 2);
      expect(h.state, isA<DomainReady>());
    });
  });

  group('B8 不變式', () {
    test('建圖不可用的輪次：記 level 900 並落 schema 不相容阻擋態', () async {
      for (final reason in EdgeTypeUnavailableReason.values) {
        final h = _harness(produce: () => fakeRound(graphUnavailable: reason));

        await h.loader.load();

        final state = h.state;
        expect(state, isA<DomainSchemaIncompatible>(), reason: '$reason');
        expect((state as DomainSchemaIncompatible).appVersion, isNotEmpty);
        expect(state.projectVersion, isNull);
        expect(h.logs.single.$2, 900);
      }
    });

    test('E1 建圖可用的輪次不記 warning', () async {
      final h = _harness(produce: () => fakeRound());
      await h.loader.load();
      expect(h.logs, isEmpty);
    });
  });

  group('B9 依賴方向', () {
    final transit = RegExp(
      r'''^\s*export\s+['"][^'"]*current_workspace_provider\.dart['"]''',
      multiLine: true,
    );

    test('E2 正向對照：過渡轉出樣本被攔下，一般 import 放行', () {
      const sample =
          "import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';\n"
          "export 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart'\n"
          '    show currentWorkspaceStateProvider;\n';
      expect(transit.allMatches(sample), hasLength(1));
    });

    test(
      'project_switcher_providers.dart 不再轉出 currentWorkspaceStateProvider',
      () {
        final source = File('lib/app/project_switcher_providers.dart')
            .readAsStringSync();
        expect(transit.hasMatch(source), isFalse);
      },
    );

    test('編排檔位於 lib/app', () {
      expect(File('lib/app/domain_view_loader.dart').existsSync(), isTrue);
      expect(File('lib/app/domain_uc_columns.dart').existsSync(), isTrue);
    });
    // corpus／graph／layout 不依賴 app／screens 的守衛（含 E2 違規樣本）
    // 見 scan_round_test.dart 的 R7 與 graph／layout 各自的 import 方向測試。
  });
}
