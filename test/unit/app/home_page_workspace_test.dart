// G7｜UI 消費端四分支（0.1.0-W3-121 Solution Phase 2 §2.3）：驗證
// `_HomePageState._chooseFolder()` 對 [ChooseFolderResult] 四個 variant 的
// exhaustive switch 反應。落實裁決 A 的呼叫端義務——NotRemembered／
// Unavailable 兩分支各自鎖定一個使用者可見提示的契約：NotRemembered 顯示
// 「下次啟動需重新選擇」文字提示（G7-2），Unavailable 顯示 SnackBar
// 錯誤提示（G7-4），皆與 3b-C 的日誌事件分別成立、互不抵扣。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/main.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/pump_harness.dart';

void main() {
  group('G7｜UI 消費端四分支', () {
    testWidgets('G7-1 ChooseFolderSelected → banner 更新為 Ready 狀態',
        (tester) async {
      final repository = _StubWorkspaceRepository(
        chooseFolderResult:
            const ChooseFolderSelected(WorkspaceReady('/tmp/g7-selected')),
      );
      await pumpHarness(
        tester,
        child: HomePage(repository: repository),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.workspaceReady('/tmp/g7-selected')),
        findsOneWidget,
      );
    });

    testWidgets(
        'G7-2 ChooseFolderNotRemembered → banner 更新為其攜帶的 state，'
        '且顯示「下次啟動需重新選擇」提示', (tester) async {
      final repository = _StubWorkspaceRepository(
        chooseFolderResult: const ChooseFolderNotRemembered(
          state: WorkspaceReady('/tmp/g7-not-remembered'),
          reason: '寫入失敗',
        ),
      );
      await pumpHarness(
        tester,
        child: HomePage(repository: repository),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.workspaceReady('/tmp/g7-not-remembered')),
        findsOneWidget,
      );
      // 鎖定裁決 A 的呼叫端義務：state 攜帶而非取代（見上方斷言），
      // 且另有獨立的使用者可見提示（與 3b-C 的日誌事件分別成立）。
      expect(find.text(l10n.workspaceNotRemembered), findsOneWidget);
    });

    testWidgets('G7-3 ChooseFolderCancelled → 狀態不變、無提示', (tester) async {
      final repository = _StubWorkspaceRepository(
        restoreState: const WorkspaceUnset(),
        chooseFolderResult: const ChooseFolderCancelled(),
      );
      await pumpHarness(
        tester,
        child: HomePage(repository: repository),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.folderAccessRationale), findsOneWidget);
    });

    testWidgets('G7-4 ChooseFolderUnavailable → 顯示錯誤提示，狀態不變',
        (tester) async {
      final repository = _StubWorkspaceRepository(
        restoreState: const WorkspaceUnset(),
        chooseFolderResult:
            const ChooseFolderUnavailable('MissingPluginException'),
      );
      await pumpHarness(
        tester,
        child: HomePage(repository: repository),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(HomePage)));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // 狀態不變：初始文案仍在。
      expect(find.text(l10n.folderAccessRationale), findsOneWidget);
      // 鎖定裁決 A 的呼叫端義務：面板不可用時仍要有使用者可見的錯誤提示，
      // 不能只更新內部狀態或只寫日誌。
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

/// 固定回傳指定結局的替身，不碰真實檔案系統與偏好設定。
///
/// 覆寫 [WorkspaceRepository] 的兩個公開方法；建構子接縫全走預設值，
/// 但因兩個方法皆被覆寫，預設接縫實際上不會被呼叫到。
class _StubWorkspaceRepository extends WorkspaceRepository {
  _StubWorkspaceRepository({
    required this.chooseFolderResult,
    this.restoreState = const WorkspaceUnset(),
  });

  final ChooseFolderResult chooseFolderResult;
  final WorkspaceState restoreState;

  @override
  Future<WorkspaceState> restore() async => restoreState;

  @override
  Future<ChooseFolderResult> chooseFolder() async => chooseFolderResult;
}
