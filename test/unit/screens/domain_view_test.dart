// Domain 視圖（SPEC-001 §1；SPEC-003 §3.1；SPEC-004 §3.6）十一個狀態的
// 渲染與退出路徑測試。
//
// 涵蓋：
//   未選專案                  state-domain-unset                  EmptyState.page
//   載入中                    state-domain-loading                LoadingState.skeleton
//   正常 · 矩陣                state-domain-matrix                 TwoColumnLayout[Panel[MatrixGrid,...],...]
//   已選格（疊加）              panel-domain-cell-detail            右欄詳情卡
//   正常 · 泳道                state-domain-swimlane               Panel[...,SwimlaneGrid,...]
//   泳道 · 尚未選定 UC          state-domain-swimlane-uc-unset      EmptyState.section
//   泳道 · flow 未結構化        state-domain-swimlane-unstructured  EmptyState.section
//   空圖                      state-domain-empty                  EmptyState.page
//   不是框架專案                state-domain-not-framework          BlockedState.plain
//   無可消費的型別表            state-domain-schema-unconsumable    BlockedState.plain
//   schema 不相容               state-domain-schema-incompatible    BlockedState.withDetail
import 'dart:async';
import 'dart:io';

import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderScope;
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/degraded_schema.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_overlay.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/schema/edge_type.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/domain_view_fixtures.dart';
import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec001/corpus_snapshot.dart';
import '../../helpers/stub_workspace_repository.dart';

/// 讓經 shell 啟動的測試抵達 DomainReady：restore 回 Ready，gate 訊號齊備
/// 且版本等於（覆寫的）內建版本。
List<Override> _readyGateOverrides() => [
  workspaceRepositoryProvider.overrideWithValue(
    StubWorkspaceRepository(const WorkspaceReady('/ws')),
  ),
  frameworkSignalProbeProvider.overrideWithValue(
    const StubFrameworkSignalProbe(version: '0.0.1', schemaJson: true),
  ),
  builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
  fakeScanRoundOverride(),
];

/// 泳道模式、已選定 UC、尚無完成輪次；[produce] 決定重啟後輪次結果（§4 #42）。
List<Override> _pendingOverrides(ScanRoundResult? Function() produce) => [
  scanRoundProvider.overrideWith(() => FakeScanRound(produce: produce)),
  domainViewStateProvider.overrideWith(
    (ref) => const DomainReady(mode: DomainMode.swimlane),
  ),
  selectedUcProvider.overrideWith((ref) => 'UC-02'),
];

/// chooseFolder 回固定結果並計次的替身（0.5.0-W1-206.2）。
class _ChooseRepo extends StubWorkspaceRepository {
  _ChooseRepo(this._result) : super(const WorkspaceUnset());

  final ChooseFolderResult _result;
  int chooseCalls = 0;
  final List<String> addedRecent = [];

  @override
  Future<bool> addRecentProject(String path) async {
    addedRecent.add(path);
    return true;
  }

  @override
  Future<ChooseFolderResult> chooseFolder() async {
    chooseCalls++;
    return _result;
  }
}

/// 記錄 gate 讀取版本時的工作區路徑；等於 gate detect 被呼叫的計次證據。
class _CountingProbe extends StubFrameworkSignalProbe {
  _CountingProbe() : super(version: null, schemaJson: false);

  final List<String> readVersionPaths = [];

  /// gate 讀取期間的副作用；用來模擬載入編排接手畫面（`_UnsetView` 卸載）。
  void Function()? onRead;

  @override
  Future<String?> readVersion(String workspacePath) async {
    readVersionPaths.add(workspacePath);
    onRead?.call();
    // 讓出時間，使 pumpAndSettle 在 gate 完成前渲染一幀（卸載生效）。
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return null;
  }
}

List<Override> _chooseOverrides(_ChooseRepo repo, _CountingProbe probe) => [
  domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
  workspaceRepositoryProvider.overrideWithValue(repo),
  frameworkSignalProbeProvider.overrideWithValue(probe),
  fakeScanRoundOverride(),
];

void main() {
  group('未選專案 state-domain-unset', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    // 0.5.0-W1-206.2：按鈕開啟選擇器並依四種結果分流（SPEC-003 §3.1）。
    testWidgets('選定資料夾：chooseFolder 一次，經共用流程呼叫 gate detect', (tester) async {
      final repo = _ChooseRepo(
        const ChooseFolderSelected(WorkspaceReady('/ws')),
      );
      final probe = _CountingProbe();
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _chooseOverrides(repo, probe),
      );

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();

      expect(repo.chooseCalls, 1);
      expect(probe.readVersionPaths, ['/ws']);
    });

    testWidgets('選定但未能記住：照常載入，另顯示 workspaceNotRemembered', (tester) async {
      final repo = _ChooseRepo(
        const ChooseFolderNotRemembered(
          state: WorkspaceReady('/ws'),
          reason: 'prefs-failed',
        ),
      );
      final probe = _CountingProbe();
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _chooseOverrides(repo, probe),
      );
      // 載入編排在 gate 期間把畫面轉為載入中，_UnsetView 隨之卸載。
      probe.onRead = () =>
          container.read(domainViewStateProvider.notifier).state =
              const DomainLoading();

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();

      expect(probe.readVersionPaths, ['/ws']);
      // 畫面卸載後最近專案清單仍須寫入（共用流程不依賴呼叫端 ref）。
      expect(repo.addedRecent, ['/ws']);
      expect(
        find.text(AppLocalizationsZh().workspaceNotRemembered),
        findsOneWidget,
      );
    });

    testWidgets('選擇器取消：仍為未選專案，無 SnackBar，gate 未觸發', (tester) async {
      final repo = _ChooseRepo(const ChooseFolderCancelled());
      final probe = _CountingProbe();
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _chooseOverrides(repo, probe),
      );

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();

      expect(repo.chooseCalls, 1);
      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(find.byType(AppSnackBar), findsNothing);
      expect(probe.readVersionPaths, isEmpty);
      expect(container.read(domainViewStateProvider), isA<DomainUnset>());
    });

    testWidgets('選擇器無法開啟：SnackBar 固定文案，仍為未選專案', (tester) async {
      final repo = _ChooseRepo(const ChooseFolderUnavailable('boom-detail'));
      final probe = _CountingProbe();
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _chooseOverrides(repo, probe),
      );

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizationsZh();
      expect(find.text(l10n.chooseFolderUnavailableMessage), findsOneWidget);
      expect(find.textContaining('boom-detail'), findsNothing);
      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(probe.readVersionPaths, isEmpty);
    });

    testWidgets('資料夾不可讀：SnackBar 含原因，仍為未選專案', (tester) async {
      final repo = _ChooseRepo(
        const ChooseFolderSelected(
          WorkspaceUnavailable(lastKnownPath: '/gone', reason: 'missing'),
        ),
      );
      final probe = _CountingProbe();
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: _chooseOverrides(repo, probe),
      );

      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizationsZh();
      expect(
        find.text(l10n.folderUnavailableMessage('missing')),
        findsOneWidget,
      );
      expect(AnchorFinder.state(Screen.domain, 'unset'), findsOneWidget);
      expect(probe.readVersionPaths, isEmpty);
    });
  });

  group('載入中 state-domain-loading', () {
    testWidgetsAtEachSize('渲染 LoadingState.skeleton', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainLoading()),
        ],
        size: size,
        settle: false,
      );

      expect(AnchorFinder.state(Screen.domain, 'loading'), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('顯示已處理節點計數且不顯示百分比', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainLoading(processedCount: 64),
          ),
        ],
        settle: false,
      );

      expect(find.text('已處理 64 個節點'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      container.read(domainViewStateProvider.notifier).state =
          const DomainLoading(processedCount: 96);
      await tester.pump();
      expect(find.text('已處理 96 個節點'), findsOneWidget);
      expect(find.text('已處理 64 個節點'), findsNothing);
    });

    testWidgets('action-domain-cancel-load → 回到未選專案', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainLoading()),
        ],
        settle: false,
      );

      await tester.tap(find.byKey(const Key('action-domain-cancel-load')));
      await tester.pump();

      expect(container.read(domainViewStateProvider), isA<DomainUnset>());
    });
  });

  group('正常 · 矩陣 state-domain-matrix', () {
    testWidgetsAtEachSize(
      '渲染 TwoColumnLayout[Panel[MatrixGrid, BadgeRow.legend], '
      'Panel.scrollable[EmptyState.section]]',
      (tester, size) async {
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: domainFixtureOverrides(),
          size: size,
        );

        expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
        expect(find.byType(TwoColumnLayout), findsOneWidget);
        expect(find.byType(Panel), findsWidgets);
        expect(find.byType(MatrixGrid), findsOneWidget);
        expect(find.byType(BadgeRow), findsWidgets);
        expect(
          find.byKey(const Key('panel-domain-cell-detail-empty')),
          findsOneWidget,
        );
        expectNoOverflow(tester);
      },
    );

    testWidgets('點格子 → 已選格出現，panel-domain-cell-detail 內容正確', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);
      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsNothing,
      );
      // 三區塊皆有：說明 + 8 個編號步驟 + 事件標籤。
      expect(find.byType(ListRow), findsNWidgets(8));
      expect(find.byType(Badge), findsWidgets);
      expect(container.read(selectedUcProvider), 'UC-02');
    });

    testWidgets('已選格「無關」格顯示 cellDetailNotInvolved，不渲染步驟', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-schema-UC-02')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panel-domain-cell-detail')), findsOneWidget);
      expect(find.byType(ListRow), findsNothing);
    });

    testWidgets('action-domain-cell-clear → 回到未選格', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action-domain-cell-clear')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('panel-domain-cell-detail')), findsNothing);
    });

    testWidgets('Esc 清除選取（同 action-domain-cell-clear 效果）', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
    });

    testWidgets('換選另一格 → 詳情卡內容替換', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cell-domain-schema-UC-04')));
      await tester.pumpAndSettle();

      final state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, ('schema', 'UC-04'));
      expect(container.read(selectedUcProvider), 'UC-04');
    });

    testWidgets('action-domain-select-<domainId> 選不同列 → 選格清除，'
        '同列則保留', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();

      // 同一列（workspace）列首：選格不變。
      await tester.tap(find.byKey(const Key('action-domain-select-workspace')));
      await tester.pumpAndSettle();
      var state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, ('workspace', 'UC-02'));

      // 不同列（graph）列首：選格清除。
      await tester.tap(find.byKey(const Key('action-domain-select-graph')));
      await tester.pumpAndSettle();
      state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedCell, isNull);
      expect(state.selectedDomainId, 'graph');
      expect(
        find.byKey(const Key('panel-domain-cell-detail-empty')),
        findsOneWidget,
      );
    });

    testWidgets('action-domain-cell-goto-swimlane → 切至正常 · 泳道', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: domainFixtureOverrides(),
      );

      await tester.tap(find.byKey(const Key('cell-domain-workspace-UC-02')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('action-domain-cell-goto-swimlane')),
      );
      await tester.pumpAndSettle();

      final state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.mode, DomainMode.swimlane);
      expect(state.selectedCell, ('workspace', 'UC-02'));
      expect(AnchorFinder.state(Screen.domain, 'swimlane'), findsOneWidget);
    });
  });

  group('正常 · 泳道 state-domain-swimlane', () {
    testWidgetsAtEachSize('渲染 Panel[AppText.subtitle, SwimlaneGrid, '
        'BadgeRow.legend]，節點所屬列依 traverses', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          ...domainFixtureOverrides(mode: DomainMode.swimlane),
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'swimlane'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DomainViewScreen)),
      );
      final uc = DomainViewFixtures.ucColumns.firstWhere(
        (u) => u.id == 'UC-02',
      );
      expect(
        find.text(l10n.swimlanePanelTitle(uc.id, uc.title)),
        findsOneWidget,
      );
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(
        find.byType(SwimlaneNode),
        findsNWidgets(10),
      ); // 8（workspace）+2（graph）
      expect(find.byType(BadgeRow), findsWidgets);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-select-<domainId> 點列首 → selectedDomainId 改變，'
        '與矩陣模式共用同一選中值', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          ...domainFixtureOverrides(mode: DomainMode.swimlane),
          selectedUcProvider.overrideWith((ref) => 'UC-02'),
        ],
      );

      var state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedDomainId, isNull);

      await tester.tap(find.byKey(const Key('action-domain-select-graph')));
      await tester.pumpAndSettle();

      state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.selectedDomainId, 'graph');

      // 矩陣與泳道共用同一 domainViewStateProvider：模式切換不重置
      // selectedDomainId（頁首 SegmentedControl 由 lib/app/shell.dart 接線，
      // 不在 DomainViewScreen 樹內，此處直接切換 mode 驗證同一 provider
      // 承載的值不因模式切換清除）。
      container.read(domainViewStateProvider.notifier).state = state.copyWith(
        mode: DomainMode.matrix,
      );
      await tester.pumpAndSettle();

      state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.mode, DomainMode.matrix);
      expect(state.selectedDomainId, 'graph');
    });
  });

  group('泳道 · 尚未選定 UC state-domain-swimlane-uc-unset', () {
    testWidgetsAtEachSize('渲染 EmptyState.section + 0 節點的 SwimlaneGrid', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [...domainFixtureOverrides(mode: DomainMode.swimlane)],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-uc-unset'),
        findsOneWidget,
      );
      // EmptyState 存在：與「空圖」等其他 EmptyState.page 狀態共用型別，
      // 鑑別力來自 SwimlaneGrid 同時存在（下一行）——僅 EmptyState 本身
      // 不足以區分此狀態與其他 EmptyState 狀態。
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(find.byType(SwimlaneNode), findsNothing);
      // BadgeRow.legend 不存在：SPEC-004 §3.6 §1 明訂「不渲染
      // BadgeRow.legend（無節點可圖例）」，此為與「正常 · 泳道」狀態
      // （同樣渲染 SwimlaneGrid，但額外渲染 BadgeRow.legend）的鑑別點。
      expect(find.byType(BadgeRow), findsNothing);
      expectNoOverflow(tester);
    });
  });

  group('泳道 · 投影準備中 state-domain-swimlane-projection-pending（§4 #42）', () {
    // 真實檔案 I/O 不可在 testWidgets 的 fake async 內等待，於 setUpAll 載入。
    late final dynamic pendingSnapshotEvent;
    setUpAll(() async {
      pendingSnapshotEvent = await loadSnapshotEvent(
        'graph_project_docs_manager',
      );
    });

    testWidgets('渲染該狀態後切回矩陣 → state-domain-matrix', (tester) async {
      await pumpApp(
        tester,
        settle: false,
        overrides: _pendingOverrides(() => null),
      );
      await tester.pump();
      await tester.pump();
      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-projection-pending'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mode-domain-matrix')));
      await tester.pump();
      await tester.pump();
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
    });

    testWidgets('首次輪次完成 → 轉為 swimlane 或 swimlane-unstructured', (tester) async {
      final round = fakeRound(event: pendingSnapshotEvent);
      await pumpApp(
        tester,
        settle: false,
        overrides: _pendingOverrides(() => round),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      final pendingKey = AnchorFinder.state(
        Screen.domain,
        'swimlane-projection-pending',
      );
      expect(pendingKey, findsNothing);
      final landed =
          AnchorFinder.state(Screen.domain, 'swimlane').evaluate().isNotEmpty ||
          AnchorFinder.state(
            Screen.domain,
            'swimlane-unstructured',
          ).evaluate().isNotEmpty;
      expect(landed, isTrue);
    });
  });

  group('泳道 · flow 未結構化 state-domain-swimlane-unstructured', () {
    testWidgetsAtEachSize('渲染 EmptyState.section，不渲染 SwimlaneGrid', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          ...domainFixtureOverrides(mode: DomainMode.swimlane),
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-unstructured'),
        findsOneWidget,
      );
      // EmptyState 存在 + SwimlaneGrid 不存在：兩者合看才有鑑別力——
      // 「泳道 · 尚未選定 UC」同樣有 EmptyState 但 SwimlaneGrid 存在，
      // 「正常 · 泳道」則兩者相反（無 EmptyState、有 SwimlaneGrid）。
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DomainViewScreen)),
      );
      final uc = DomainViewFixtures.ucColumns.firstWhere(
        (u) => u.id == 'UC-06',
      );
      expect(
        find.text(l10n.swimlanePanelTitle(uc.id, uc.title)),
        findsOneWidget,
      );
      expectNoOverflow(tester);
    });
  });

  group('空圖 state-domain-empty', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.domain, 'empty'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-goto-gaps → jump 至破洞報告', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.domain,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-domain-goto-gaps')));
      await tester.pumpAndSettle();

      expect(container.read(selectedDestinationProvider), AppDestination.gaps);
      expect(container.read(returnToProvider), AppDestination.domain);
    });

    testWidgets('docs 目錄不存在時不渲染 action-domain-open-docs（正向對照）', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainEmpty(docsDirExists: false),
          ),
        ],
      );

      expect(find.byKey(const Key('action-domain-open-docs')), findsNothing);
    });
  });

  group('不是框架專案 state-domain-not-framework', () {
    testWidgetsAtEachSize('渲染 BlockedState.plain', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainNotFramework(),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'not-framework'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-switch-project → 開啟切換浮層', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainNotFramework(),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-domain-switch-project')));
      await tester.pump();

      expect(container.read(switcherOpenProvider), isTrue);
    });
  });

  group('無可消費的型別表 state-domain-schema-unconsumable', () {
    testWidgetsAtEachSize('渲染 BlockedState.plain（版本值 slot）', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'schema-unconsumable'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expect(find.text('0.0.3'), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('VERSION 不高於內建型別表版本 → action-domain-degraded-view 按下後轉為降級檢視', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
          ),
          // 降級進入經共用輪次重掃（0.5.0-W1-114.14）；輪次讀降級旗標。
          fakeScanRoundOverride(),
        ],
      );

      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('action-domain-degraded-view')));
      await tester.pump();
      await tester.pump();

      final state = container.read(domainViewStateProvider);
      expect(state, isA<DomainReady>());
      expect((state as DomainReady).isDegraded, isTrue);
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);

      // 寫入端接線（0.1.0-W2-014）：觸發降級檢視時，app 層旗標與版本
      // 文字須同步寫入——此斷言在寫入端未接線時應翻紅（旗標維持預設
      // 值 false / null）。
      expect(container.read(degradedSchemaProvider), isTrue);
      final versions = container.read(degradedSchemaVersionsProvider);
      expect(versions, isNotNull);
      expect(versions!.projectVersion, '0.0.3');
      expect(versions.builtinVersion, isNotEmpty);
    });

    testWidgets('VERSION 高於內建型別表版本 → 不提供 action-domain-degraded-view', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '9.99.9'),
          ),
        ],
      );

      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('action-domain-switch-project')),
        findsOneWidget,
      );
    });

    // 降級說明（schemaUnconsumableDegradedExplanation）與降級動作同條件渲染。
    Finder degradedExplanation() => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(RegExp(r'tier-B edges|B 層邊')),
    );

    testWidgets('有降級動作時降級說明同時渲染且含內建版本', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '0.0.3'),
          ),
        ],
      );

      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsOneWidget,
      );
      expect(degradedExplanation(), findsOneWidget);
    });

    testWidgets('無降級動作時降級說明與動作皆不渲染', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaUnconsumable(version: '9.99.9'),
          ),
        ],
      );

      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsNothing,
      );
      expect(degradedExplanation(), findsNothing);
    });

    testWidgets('以現行 .claude/VERSION 實值為底、次版號 +1 驅動：高於內建資產版本時不提供降級出口'
        '（0.1.0-W2-012：防止只用遠低於門檻的 fixture 值掩蓋真實漂移；'
        '0.3.0-W2-001 起 builtin_schema_version.json 與現行 VERSION 同步，'
        '直接讀 VERSION 已不保證嚴格高於內建版本，改以其為底再遞增確保恆高於）', (tester) async {
      final liveVersion = File('.claude/VERSION').readAsStringSync().trim();
      final segments = liveVersion.split('.').map(int.parse).toList();
      segments[1] += 1;
      final higherThanBuiltinVersion = segments.join('.');

      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) =>
                DomainSchemaUnconsumable(version: higherThanBuiltinVersion),
          ),
        ],
      );

      // 以現行 .claude/VERSION 次版號 +1 的版本，保證高於內建資產版本
      // （assets/schema/builtin_schema_version.json，見同名 provider），
      // SPEC-001 §1／SPEC-003 §3.1 此時不提供降級出口。
      expect(
        find.byKey(const Key('action-domain-degraded-view')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('action-domain-switch-project')),
        findsOneWidget,
      );
    });
  });

  group('schema 不相容 state-domain-schema-incompatible', () {
    testWidgetsAtEachSize('渲染 BlockedState.withDetail', (tester, size) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaIncompatible(
              appVersion: '2.60.1',
              projectVersion: '9.99.9',
            ),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.domain, 'schema-incompatible'),
        findsOneWidget,
      );
      expect(find.byType(BlockedState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-domain-schema-detail → 展開詳情面板', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaIncompatible(
              appVersion: '2.60.1',
              projectVersion: '9.99.9',
            ),
          ),
        ],
      );

      expect(find.byKey(const Key('panel-domain-schema-detail')), findsNothing);

      await tester.tap(find.byKey(const Key('action-domain-schema-detail')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('panel-domain-schema-detail')),
        findsOneWidget,
      );
      expect(find.text('App 已知版本範圍'), findsOneWidget);
      expect(find.text('不高於 2.60.1'), findsOneWidget);
      expect(find.text('App 支援版本'), findsNothing);
      expect(find.text('專案版本'), findsNothing);
    });

    testWidgets(
      'projectVersion 為 null（版本無法判讀）→ 本體顯示 schemaVersionUnreadableMessage'
      '（0.3.0-W3-542）',
      (tester) async {
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            domainViewStateProvider.overrideWith(
              (ref) => const DomainSchemaIncompatible(
                appVersion: '2.60.1',
                projectVersion: null,
              ),
            ),
          ],
        );

        final l10n = AppLocalizations.of(
          tester.element(find.byType(DomainViewScreen)),
        );
        expect(find.text(l10n.schemaVersionUnreadableMessage), findsOneWidget);
      },
    );

    testWidgets('projectVersion 非 null（版本太新）→ 本體照舊顯示 schemaIncompatibleMessage'
        '（0.3.0-W3-542）', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith(
            (ref) => const DomainSchemaIncompatible(
              appVersion: '2.60.1',
              projectVersion: '9.99.9',
            ),
          ),
        ],
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DomainViewScreen)),
      );
      expect(
        find.text(l10n.schemaIncompatibleMessage('2.60.1', '9.99.9')),
        findsOneWidget,
      );
    });
  });

  group('頁首模式切換（SplitRow.header 右格，lib/app/shell.dart 接線）', () {
    testWidgets('mode-domain-swimlane → 切至泳道；mode-domain-matrix → 切回矩陣', (
      tester,
    ) async {
      // 啟動改寫（0.3.3-W3-398）：注入 Ready 替身，gate 判 DomainReady。
      await pumpApp(tester, overrides: _readyGateOverrides());

      expect(find.byKey(const Key('mode-domain-matrix')), findsOneWidget);
      expect(find.byKey(const Key('mode-domain-swimlane')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-domain-swimlane')));
      await tester.pumpAndSettle();
      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-uc-unset'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mode-domain-matrix')));
      await tester.pumpAndSettle();
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
    });

    testWidgets('未選專案等六列不渲染頁首模式切換（正向對照）', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
        ],
      );

      expect(find.byKey(const Key('mode-domain-matrix')), findsNothing);
      expect(find.byKey(const Key('mode-domain-swimlane')), findsNothing);
    });
  });

  group('降級旗標寫入端真實執行路徑（0.1.0-W2-014）', () {
    testWidgets('真實 App（非 degradedSchemaProvider override）：觸發降級檢視後'
        'badge-domain-degraded-schema 可見，徽章文字含兩個版本值', (tester) async {
      // 僅覆寫 domainViewStateProvider 以抵達「無可消費的型別表」列，
      // 與同檔其餘測試同一慣例；degradedSchemaProvider /
      // degradedSchemaVersionsProvider 完全不覆寫，走真實寫入路徑。
      await pumpApp(
        tester,
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            StubWorkspaceRepository(const WorkspaceReady('/ws')),
          ),
          frameworkSignalProbeProvider.overrideWithValue(
            const StubFrameworkSignalProbe(version: '0.0.3', schemaJson: false),
          ),
          fakeScanRoundOverride(),
        ],
      );

      expect(
        find.byKey(const Key('badge-domain-degraded-schema')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('action-domain-degraded-view')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('badge-domain-degraded-schema')),
        findsOneWidget,
      );

      final label = tester
          .widget<Badge>(find.byKey(const Key('badge-domain-degraded-schema')))
          .label;
      expect(label, contains('0.0.3'));
    });
  });

  group('假資料一致性（本票 acceptance 第四項）', () {
    test('矩陣列序與欄序為固定順序', () {
      expect(DomainViewFixtures.domainIds, [
        'workspace',
        'schema',
        'corpus',
        'graph',
      ]);
      expect(DomainViewFixtures.ucColumns.map((u) => u.id), [
        'UC-02',
        'UC-04',
        'UC-06',
      ]);
    });

    test('泳道節點所屬列依 FlowStep.traverses', () {
      final lanes = DomainViewFixtures.lanesForUc('UC-04');
      final graphLane = lanes.firstWhere((l) => l.domainId == 'graph');
      expect(graphLane.nodes.map((n) => n.column), [1, 2]);
      final workspaceLane = lanes.firstWhere((l) => l.domainId == 'workspace');
      expect(workspaceLane.nodes, isEmpty);
    });
  });

  group('圖不可用 state-domain-graph-unavailable（§4 #43，0.5.0-W1-486.2）', () {
    // 已有完成輪次、最後一輪建圖不可用；produce 決定重掃結果。
    ScanRoundResult unavailableRound() => fakeRound(
      graphUnavailable: EdgeTypeUnavailableReason.projectVersionOutOfKnownRange,
    );

    List<Override> overrides({
      required DomainMode mode,
      ScanRoundResult? Function()? produce,
      Duration latency = Duration.zero,
      DomainReady? ready,
    }) => [
      scanRoundProvider.overrideWith(
        () => FakeScanRound(
          produce: produce ?? unavailableRound,
          initial: unavailableRound(),
          latency: latency,
        ),
      ),
      domainViewStateProvider.overrideWith(
        (ref) => ready ?? DomainReady(mode: mode),
      ),
      selectedUcProvider.overrideWith((ref) => 'UC-02'),
      builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
    ];

    final unavailable = AnchorFinder.state(Screen.domain, 'graph-unavailable');

    testWidgets('RED：矩陣模式落圖不可用列，不渲染矩陣', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.matrix),
      );
      expect(unavailable, findsOneWidget);
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsNothing);
      expect(find.byType(MatrixGrid), findsNothing);
    });

    testWidgets('RED：泳道模式落圖不可用列，不顯示 uc-unset', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.swimlane),
      );
      expect(unavailable, findsOneWidget);
      expect(
        AnchorFinder.state(Screen.domain, 'swimlane-uc-unset'),
        findsNothing,
      );
      expect(AnchorFinder.state(Screen.domain, 'swimlane'), findsNothing);
    });

    final l10n = AppLocalizationsZh();
    const latency = Duration(seconds: 5);
    final rescanButton = find.descendant(
      of: unavailable,
      matching: find.byType(AppButton),
    );
    bool buttonEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(rescanButton).enabled;
    Finder textIn(String text) =>
        find.descendant(of: unavailable, matching: find.text(text));
    final reasonText = l10n.domainGraphUnavailableMessage('0.0.1');
    // 自 [node] 沿 parent 往上（含自身），以 id 判斷是否經過 [block]。
    // 不鎖定節點合併形狀：按鈕有無獨立節點皆成立。
    bool chainIncludes(SemanticsNode node, SemanticsNode block) {
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        if (n.id == block.id) return true;
      }
      return false;
    }

    testWidgets('原因文字含內建型別表版本，按鈕可按', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.matrix),
      );
      expect(textIn(reasonText), findsOneWidget);
      expect(buttonEnabled(tester), isTrue);
      expect(find.text(l10n.rescanAction), findsOneWidget);
    });

    testWidgets('掃描中（本列觸發）：掃描中文字與計數、按鈕停用；結束仍不可用 → 恢復原因文字', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.matrix, latency: latency),
      );
      await tester.tap(find.byKey(const Key('action-domain-rescan')));
      await tester.pump();
      await tester.pump();

      expect(textIn(l10n.domainGraphUnavailableScanning), findsOneWidget);
      expect(textIn(l10n.gapsScanningProcessedCount(0)), findsOneWidget);
      expect(textIn(reasonText), findsNothing);
      expect(buttonEnabled(tester), isFalse);
      // SPEC-004 §4.4 適用條件 2：原因文案與按鈕同一語意區塊。530.1 起
      // liveRegion 只包訊息並獨立成節點（不再併入外層容器），故訊息節點與
      // 按鈕節點分離；「同一語意區塊」改以兩者的共同祖先表達——該祖先須為
      // 真實節點、不等於訊息節點，且訊息節點 label 含掃描中文字、不含計數。
      final messageNode = tester.getSemantics(
        find.text(l10n.domainGraphUnavailableScanning),
      );
      final buttonNode = tester.getSemantics(rescanButton);
      SemanticsNode? blockNode;
      for (SemanticsNode? n = messageNode.parent; n != null; n = n.parent) {
        if (chainIncludes(buttonNode, n)) {
          blockNode = n;
          break;
        }
      }
      expect(blockNode, isNotNull);
      expect(blockNode!.id, isNot(messageNode.id));
      expect(chainIncludes(messageNode, blockNode), isTrue);
      expect(chainIncludes(buttonNode, blockNode), isTrue);
      expect(chainIncludes(buttonNode, messageNode), isFalse);
      expect(messageNode.label, contains(l10n.domainGraphUnavailableScanning));
      expect(
        messageNode.label,
        isNot(contains(l10n.gapsScanningProcessedCount(0))),
      );
      // 停用原因由列內訊息承載：按鈕內僅 label 一個文字節點（無空 caption）。
      expect(
        find.descendant(
          of: find.byKey(const Key('action-domain-rescan')),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );

      await tester.pump(latency);
      await tester.pump();
      expect(unavailable, findsOneWidget);
      expect(textIn(l10n.domainGraphUnavailableScanning), findsNothing);
      expect(textIn(l10n.gapsScanningProcessedCount(0)), findsNothing);
      expect(textIn(reasonText), findsOneWidget);
      expect(buttonEnabled(tester), isTrue);
      expect(find.byType(AppSnackBar), findsNothing);
      handle.dispose();
    });

    testWidgets('E2 正向對照：訊息與按鈕分屬不同語意容器時祖先鏈不含對方（斷言可鑑別）', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(
        tester,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(container: true, child: const Text('msg')),
            Semantics(
              container: true,
              child: AppButton(
                label: 'btn',
                enabled: false,
                reasonShownNearby: true,
                onPressed: () {},
                testKey: const Key('control-btn'),
              ),
            ),
          ],
        ),
      );
      final messageNode = tester.getSemantics(find.text('msg'));
      final buttonNode = tester.getSemantics(
        find.byKey(const Key('control-btn')),
      );
      // messageNode 為訊息所在容器（block）；按鈕祖先鏈上不應含它。
      expect(chainIncludes(buttonNode, messageNode), isFalse);
      handle.dispose();
    });

    testWidgets('掃描中（他頁觸發）：同樣顯示掃描中並停用按鈕，結束後消失', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.swimlane, latency: latency),
      );
      expect(buttonEnabled(tester), isTrue);

      unawaited(container.read(scanRoundProvider.notifier).rescan());
      await tester.pump();
      await tester.pump();
      expect(textIn(l10n.domainGraphUnavailableScanning), findsOneWidget);
      expect(textIn(l10n.gapsScanningProcessedCount(0)), findsOneWidget);
      expect(buttonEnabled(tester), isFalse);

      await tester.pump(latency);
      await tester.pump();
      expect(textIn(l10n.domainGraphUnavailableScanning), findsNothing);
      expect(textIn(reasonText), findsOneWidget);
      expect(buttonEnabled(tester), isTrue);
    });

    testWidgets('重掃後建圖可用 → 回矩陣；選中 domain、選中格與選定 UC 保留', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(
          mode: DomainMode.matrix,
          latency: latency,
          produce: () => fakeRound(),
          ready: const DomainReady(
            mode: DomainMode.matrix,
            selectedDomainId: 'workspace',
            selectedCell: ('workspace', 'UC-02'),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('action-domain-rescan')));
      await tester.pump();
      await tester.pump(latency);
      await tester.pump();
      await tester.pump();

      expect(unavailable, findsNothing);
      expect(AnchorFinder.state(Screen.domain, 'matrix'), findsOneWidget);
      final state = container.read(domainViewStateProvider) as DomainReady;
      expect(state.mode, DomainMode.matrix);
      expect(state.selectedDomainId, 'workspace');
      expect(state.selectedCell, ('workspace', 'UC-02'));
      expect(container.read(selectedUcProvider), 'UC-02');
    });

    testWidgets('切模式只改選中值，圖不可用列維持', (tester) async {
      final container = await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: overrides(mode: DomainMode.matrix),
      );
      container.read(domainViewStateProvider.notifier).state =
          const DomainReady(mode: DomainMode.swimlane);
      await tester.pump();
      expect(unavailable, findsOneWidget);
    });

    // §4 #43 逐列導航：渲染 → tap 錨點 → 斷言目標錨點。
    testWidgets('§4 #43：nav-item 破洞報告 → 離開本狀態並抵達該頁', (tester) async {
      await pumpApp(
        tester,
        settle: false,
        overrides: overrides(mode: DomainMode.matrix),
      );
      await tester.pump();
      await tester.pump();
      expect(unavailable, findsOneWidget);

      await tester.tap(AnchorFinder.navItem(AppDestination.gaps));
      await tester.pump();
      await tester.pump();
      expect(unavailable, findsNothing);
      expect(AnchorFinder.navPage(AppDestination.gaps), findsOneWidget);
    });

    testWidgets('§4 #43：project-switcher-entry → 浮層展開', (tester) async {
      await pumpApp(
        tester,
        settle: false,
        overrides: overrides(mode: DomainMode.matrix),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(AnchorFinder.projectSwitcherEntry);
      await tester.pumpAndSettle();
      // 浮層內容（expanded／no-recent）取決於最近專案資料；本列只驗證出口
      // 已觸發浮層開啟，浮層本身由 project_switcher_test 覆蓋。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DomainViewScreen)),
      );
      expect(container.read(switcherOpenProvider), isTrue);
    });
  });
}
