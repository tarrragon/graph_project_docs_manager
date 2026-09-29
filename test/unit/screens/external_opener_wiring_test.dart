// 四畫面外部開啟改接 ExternalOpener 的接線測試（0.3.2-W1-004；SPEC-003
// §3.1／§3.2／§3.6 三值對應）。以 FakeExternalOpener 指使 opened／notFound／
// failed，斷言呼叫路徑與畫面回饋。破洞報告的同型測試在 gap_report_test.dart。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/screens/project_switcher/project_switcher_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/helpers.dart';

const _opened = '已在外部開啟';
const _failed = '無法以系統預設方式開啟';
const _notFound = '找不到檔案';

void main() {
  group('Domain 開啟 docs 目錄（SPEC-003 §3.1）', () {
    Future<FakeExternalOpener> tapDocs(
      WidgetTester tester,
      ExternalOpenResult result,
    ) async {
      final fake = FakeExternalOpener(defaultResult: result);
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          externalOpenerProvider.overrideWithValue(fake),
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
          domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
        ],
      );
      await tester.tap(find.byKey(const Key('action-domain-open-docs')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened：傳入專案根目錄組成的絕對路徑，提示已開啟', (tester) async {
      final fake = await tapDocs(tester, ExternalOpenResult.opened);
      expect(fake.calls, ['/ws/proj/docs']);
      expect(find.text(_opened), findsOneWidget);
    });

    testWidgets('notFound：提示開啟失敗', (tester) async {
      final fake = await tapDocs(tester, ExternalOpenResult.notFound);
      expect(fake.calls, ['/ws/proj/docs']);
      expect(find.text(_failed), findsOneWidget);
      expect(find.text(_opened), findsNothing);
    });

    testWidgets('failed：提示開啟失敗', (tester) async {
      await tapDocs(tester, ExternalOpenResult.failed);
      expect(find.text(_failed), findsOneWidget);
      expect(find.text(_opened), findsNothing);
    });
  });

  group('Domain 泳道開啟原始檔（SPEC-003 §3.1）', () {
    Future<FakeExternalOpener> tapSource(
      WidgetTester tester,
      ExternalOpenResult result,
    ) async {
      final fake = FakeExternalOpener(defaultResult: result);
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          externalOpenerProvider.overrideWithValue(fake),
          domainViewStateProvider.overrideWith(
            (ref) => const DomainReady(mode: DomainMode.swimlane),
          ),
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
      );
      await tester.tap(find.byKey(const Key('action-domain-open-source')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened', (tester) async {
      final fake = await tapSource(tester, ExternalOpenResult.opened);
      expect(fake.calls, ['docs/usecases/UC-06.md']);
      expect(find.text(_opened), findsOneWidget);
    });

    testWidgets('notFound：提示找不到檔案', (tester) async {
      await tapSource(tester, ExternalOpenResult.notFound);
      expect(find.text(_notFound), findsOneWidget);
    });

    testWidgets('failed', (tester) async {
      await tapSource(tester, ExternalOpenResult.failed);
      expect(find.text(_failed), findsOneWidget);
    });
  });

  group('UC Flow 開啟原始檔（SPEC-003 §3.2）', () {
    Future<FakeExternalOpener> tapSource(
      WidgetTester tester,
      ExternalOpenResult result,
    ) async {
      final fake = FakeExternalOpener(defaultResult: result);
      await pumpHarness(
        tester,
        child: const UcFlowScreen(),
        overrides: [
          externalOpenerProvider.overrideWithValue(fake),
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
      );
      await tester.tap(find.byKey(const Key('action-ucFlow-open-source')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened', (tester) async {
      final fake = await tapSource(tester, ExternalOpenResult.opened);
      expect(fake.calls, ['docs/usecases/UC-06.md']);
      expect(find.text(_opened), findsOneWidget);
    });

    testWidgets('notFound：提示找不到檔案', (tester) async {
      await tapSource(tester, ExternalOpenResult.notFound);
      expect(find.text(_notFound), findsOneWidget);
    });

    testWidgets('failed', (tester) async {
      await tapSource(tester, ExternalOpenResult.failed);
      expect(find.text(_failed), findsOneWidget);
    });
  });

  group('節點詳情開啟原始檔（SPEC-003 §3.6）', () {
    Future<FakeExternalOpener> tapSource(
      WidgetTester tester,
      ExternalOpenResult result,
    ) async {
      final fake = FakeExternalOpener(defaultResult: result);
      await pumpApp(
        tester,
        overrides: [
          externalOpenerProvider.overrideWithValue(fake),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
        ],
      );
      await tester.tap(AnchorFinder.action(Screen.nodeDetail, 'open-source'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened：提示已開啟，畫面不轉消失態', (tester) async {
      final fake = await tapSource(tester, ExternalOpenResult.opened);
      expect(fake.calls, hasLength(1));
      expect(find.text(_opened), findsOneWidget);
      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsNothing);
    });

    testWidgets('notFound：轉為原始檔已消失，不出 SnackBar', (tester) async {
      await tapSource(tester, ExternalOpenResult.notFound);
      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsOneWidget);
      expect(find.text(_notFound), findsNothing);
    });

    testWidgets('failed：提示開啟失敗', (tester) async {
      await tapSource(tester, ExternalOpenResult.failed);
      expect(find.text(_failed), findsOneWidget);
    });
  });
}
