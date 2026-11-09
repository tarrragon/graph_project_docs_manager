// SPEC-008 測試設計 §3.10 C-1～C-10、§3.7 B-4、§3.8 Q-5（承接 0.7.0-W1-012.9）。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/history/events/declaration_extractor.dart';
import 'package:graph_project_docs_manager/history/events/edge_event_builder.dart';
import 'package:graph_project_docs_manager/history/git/git_history_types.dart';
import 'package:graph_project_docs_manager/history/git/git_process_runner.dart';
import 'package:graph_project_docs_manager/history/query/history_query.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/history/fake_process_runner.dart';
import '../../helpers/history/synthetic_git_log.dart';

/// 一次性呼叫可被暫停的 fake（C-6：前置檢查進行中）。
class _GatedRunner extends FakeProcessRunner {
  _GatedRunner({super.scanFactory});

  Completer<void>? gate;

  @override
  Future<GitCommandResult> run(GitInvocation invocation) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.run(invocation);
  }
}

EdgeEventBuilder _newBuilder() => EdgeEventBuilder(
  extractor: DeclarationExtractor(
    activeEdgeTypes: const [],
    closedByIdPatterns: const [],
  ),
  ticketIdPattern: RegExp(r'^\d+$'),
);

HistoryScanInputs _inputs({
  String table = 'table-1',
  HistorySchemaReadiness readiness = HistorySchemaReadiness.ready,
}) => HistoryScanInputs(
  schemaReadiness: readiness,
  tableIdentity: table,
  createBuilder: _newBuilder,
);

ProviderContainer _container(_GatedRunner runner, {String root = '/a'}) {
  final container = ProviderContainer(
    overrides: [
      historyProcessRunnerProvider.overrideWithValue(runner),
      historyScanInputsProvider.overrideWithInitial((ref) => _inputs()),
      currentWorkspaceStateProvider.overrideWithInitial(
        (ref) => WorkspaceReady(root),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(historyProvider, (_, _) {});
  return container;
}

HistoryViewState _state(ProviderContainer c) => c.read(historyProvider);

HistoryNotifier _notifier(ProviderContainer c) =>
    c.read(historyProvider.notifier);

String _head(String ch) => '${ch * 40}\n';

void main() {
  group('C 快取、惰性載入、取消', () {
    test('C-1 未讀取 History provider 時 git 呼叫 0 次', () {
      final runner = _GatedRunner();
      final container = _container(runner);
      container.read(currentWorkspaceStateProvider);
      expect(runner.calls, isEmpty);
      expect(_state(container), isA<HistoryIdle>());
      expect(runner.calls, isEmpty);
    });

    test('C-2 HEAD 不變再次進入：前置檢查 1 次、掃描 0 次、同一結果', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      final first = (_state(container) as HistoryLoaded).snapshot;
      runner.calls.clear();
      await _notifier(container).enter();
      expect(runner.callKinds.where((k) => k == 'version'), hasLength(1));
      expect(runner.scanCalls, isEmpty);
      expect(runner.scanStartCount, 1);
      expect(
        identical((_state(container) as HistoryLoaded).snapshot, first),
        isTrue,
      );
    });

    test('C-3（E2 正向對照）HEAD 改變後再次進入掃描 1 次', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      runner.head = okResponse(_head('c'));
      await _notifier(container).enter();
      expect(runner.scanStartCount, 2);
      expect(_state(container), isA<HistoryLoaded>());
    });

    test('C-4 型別表識別改變、HEAD 不變：掃描 1 次', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      container.read(historyScanInputsProvider.notifier).state = _inputs(
        table: 'table-2',
      );
      await _notifier(container).enter();
      expect(runner.scanStartCount, 2);
    });

    test('C-5 重新整理：掃描 1 次（全量）', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      await _notifier(container).refresh();
      expect(runner.scanStartCount, 2);
    });

    test('C-6 再次進入時前置檢查進行中：維持先前完成結果', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      final before = _state(container);
      runner.gate = Completer<void>();
      final pending = _notifier(container).enter();
      await pumpEventQueue();
      expect(identical(_state(container), before), isTrue);
      runner.gate!.complete();
      await pending;
      expect(_state(container), isA<HistoryLoaded>());
    });

    test('C-7 再次進入判定不是 git 工作樹：轉非 git 專案，掃描 0 次', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      runner.workTree = okResponse('false\n');
      await _notifier(container).enter();
      expect(_state(container), isA<HistoryNotGitRepo>());
      expect(runner.scanStartCount, 1);
    });

    test('C-8 掃描進行中取消：kill 1 次、已取消、部分事件不外露', () async {
      final script = FakeScanScript.manual();
      final runner = _GatedRunner()..scanFactory = () => script;
      final container = _container(runner);
      final pending = _notifier(container).enter();
      await pumpEventQueue();
      script.emitText('partial');
      expect(_state(container), isA<HistoryLoading>());
      _notifier(container).cancel();
      await pending;
      expect(runner.killCount, 1);
      expect(_state(container), isA<HistoryCancelled>());
    });

    test('C-9 已有結果 R，重新整理中取消：快取仍為 R', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      final cached = (_state(container) as HistoryLoaded).snapshot;
      final script = FakeScanScript.manual();
      runner.scanFactory = () => script;
      final pending = _notifier(container).refresh();
      await pumpEventQueue();
      _notifier(container).cancel();
      await pending;
      expect(runner.killCount, 1);
      final after = _state(container);
      expect(after, isA<HistoryLoaded>());
      expect(identical((after as HistoryLoaded).snapshot, cached), isTrue);
    });

    test('C-10 切換專案：舊掃描 kill、快取清空、新根前置檢查以新根執行', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      runner.head = okResponse(_head('c'));
      final script = FakeScanScript.manual();
      runner.scanFactory = () => script;
      final pending = _notifier(container).enter();
      await pumpEventQueue();
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/b');
      await pumpEventQueue();
      await pending;
      expect(runner.killCount, 1);
      expect(_state(container), isA<HistoryIdle>());
      runner
        ..calls.clear()
        ..scanFactory = () => FakeScanScript.complete(const []);
      await _notifier(container).enter();
      expect(runner.calls.first.arguments, containsAllInOrder(['-C', '/b']));
      container.read(currentWorkspaceStateProvider.notifier).state =
          const WorkspaceReady('/a');
      await pumpEventQueue();
      final scansBefore = runner.scanStartCount;
      await _notifier(container).enter();
      expect(runner.scanStartCount, scansBefore + 1);
    });

    test('Schema 阻擋：不呼叫任何 git、不掃描', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      container.read(historyScanInputsProvider.notifier).state = _inputs(
        readiness: HistorySchemaReadiness.blocked,
      );
      await _notifier(container).enter();
      expect(_state(container), isA<HistorySchemaBlocked>());
      expect(runner.calls, isEmpty);
    });
  });

  group('B-4 與 Q-5（承接 012.8 未寫的兩案）', () {
    test('B-4 前置檢查沒有任何 commit：完成結果、事件空、帶尚無 commit 標記', () async {
      final runner = _GatedRunner()..head = failResponse(1);
      final container = _container(runner);
      await _notifier(container).enter();
      final state = _state(container);
      expect(state, isA<HistoryLoaded>());
      final snapshot = (state as HistoryLoaded).snapshot;
      expect(snapshot.hasNoCommit, isTrue);
      expect(snapshot.events, isEmpty);
      expect(runner.scanStartCount, 0);
    });

    test('Q-5 同一結果連查三次：掃描啟動 0 次', () async {
      final runner = _GatedRunner();
      final container = _container(runner);
      await _notifier(container).enter();
      final snapshot = (_state(container) as HistoryLoaded).snapshot;
      final startsBefore = runner.scanStartCount;
      final callsBefore = runner.calls.length;
      DateTime clock() => DateTime.utc(2026, 11, 9);
      for (final period in PeriodChoice.values) {
        snapshot.query(clock: clock).run(period: period);
      }
      expect(runner.scanStartCount, startsBefore);
      expect(runner.calls.length, callsBefore);
    });
  });

  group('G 畫面資料缺口（0.7.0-W1-012.11 G-1～G-3）', () {
    test('G-1 掃描非 0 結束：HistoryFailed 帶 stderr 摘要原文', () async {
      final runner = _GatedRunner()
        ..scanFactory = () =>
            FakeScanScript.exit(128, stderr: 'fatal: bad object h3');
      final container = _container(runner);
      await _notifier(container).enter();
      final state = _state(container);
      expect(state, isA<HistoryFailed>());
      expect((state as HistoryFailed).stderrSummary, contains('bad object h3'));
    });

    test('G-1 對照 前置檢查失敗同樣帶 stderr 摘要', () async {
      final runner = _GatedRunner()
        ..mainline = failResponse(128, stderr: 'fatal: bad revision');
      final container = _container(runner);
      await _notifier(container).enter();
      final state = _state(container);
      expect(state, isA<HistoryFailed>());
      expect((state as HistoryFailed).stderrSummary, contains('bad revision'));
    });

    test('G-3 讀取中帶已處理 commit 數，自 0 起算並隨掃描增加', () async {
      final script = FakeScanScript.manual();
      final runner = _GatedRunner(scanFactory: () => script);
      final container = _container(runner);
      final pending = _notifier(container).enter();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(_state(container), const HistoryLoading());
      script.emitText(
        (SyntheticLogBuilder()
              ..commit('c1', parents: ['c0'])
              ..commit('c2', parents: ['c1'])
              ..commit('c3', parents: ['c2']))
            .toBytes()
            .map(String.fromCharCode)
            .join(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final loading = _state(container) as HistoryLoading;
      expect(loading.processedCount, greaterThanOrEqualTo(2));
      await script.finish();
      await pending;
    });

    test('G-2 淺層快照帶邊界 commit 的 committer 時間；非淺層為 null', () async {
      final shallowRunner = _GatedRunner()
        ..workTree = okResponse('true\ntrue\n')
        ..scanFactory = () => FakeScanScript.complete([
          (SyntheticLogBuilder()
                ..commit('b', parents: ['a'], time: 1790000000)
                ..commit('a', time: 1780000000))
              .toBytes(),
        ]);
      final shallow = _container(shallowRunner);
      await _notifier(shallow).enter();
      final snap = (_state(shallow) as HistoryLoaded).snapshot;
      expect(snap.isShallow, isTrue);
      expect(
        snap.shallowBoundaryDate,
        DateTime.fromMillisecondsSinceEpoch(1780000000 * 1000, isUtc: true),
      );
      final full = _container(_GatedRunner());
      await _notifier(full).enter();
      expect(
        (_state(full) as HistoryLoaded).snapshot.shallowBoundaryDate,
        isNull,
      );
    });
  });

  group('wiring', () {
    test('(a) 真實型別接線：預設執行器與真實建構器可建立 provider，進入前零 git 呼叫', () {
      final container = ProviderContainer(
        overrides: [
          historyScanInputsProvider.overrideWithInitial((ref) => _inputs()),
          currentWorkspaceStateProvider.overrideWithInitial(
            (ref) => const WorkspaceReady('/a'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(historyProcessRunnerProvider),
        isA<IoGitProcessRunner>(),
      );
      expect(container.read(historyProvider), isA<HistoryIdle>());
    });

    test('(b) 未 override 的必接線輸入 provider 仍拋錯', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(historyScanInputsProvider),
        throwsA(isA<ProviderException>()),
      );
    });
  });
}
