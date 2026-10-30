// 四畫面外部開啟改接 ExternalOpener 的接線測試（0.3.2-W1-004；SPEC-003
// §3.1／§3.2／§3.6 三值對應）。以 FakeExternalOpener 指使 opened／notFound／
// failed，斷言呼叫路徑與畫面回饋。破洞報告的同型測試在 gap_report_test.dart。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/app/workspace_selection.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/domain_view/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_state.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_fixtures.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';
import 'package:graph_project_docs_manager/workspace/stale_open_result.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/domain_view_fixtures.dart';
import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/stub_workspace_repository.dart';

const _opened = '已在外部開啟';
const _failed = '無法以系統預設方式開啟';
const _notFound = '找不到檔案';
const _domainSelectedUc = 'UC-06';

/// 由測試決定何時回傳的開啟器；用來製造「切換前發出、切換後才回來」。
class _GatedOpener implements ExternalOpener {
  final Completer<ExternalOpenResult> gate = Completer();
  final List<String> calls = [];

  @override
  Future<ExternalOpenResult> open(String path) {
    calls.add(path);
    return gate.future;
  }
}

class _NotRememberedRepo extends StubWorkspaceRepository {
  _NotRememberedRepo() : super(const WorkspaceUnset());

  @override
  Future<bool> addRecentProject(String path) async => true;

  @override
  Future<ChooseFolderResult> chooseFolder() async =>
      const ChooseFolderNotRemembered(
        state: WorkspaceReady('/ws'),
        reason: 'prefs-failed',
      );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Overlay).first));

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
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
          ...domainFixtureOverrides(mode: DomainMode.swimlane),
          selectedUcProvider.overrideWith((ref) => _domainSelectedUc),
        ],
      );
      await tester.tap(find.byKey(const Key('action-domain-open-source')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened', (tester) async {
      final fake = await tapSource(tester, ExternalOpenResult.opened);
      // Domain 畫面取矩陣欄上該 UC 節點的來源路徑（fixture 的 filePath）。
      expect(fake.calls, [
        '/ws/proj/docs/usecases/UC-06-find-and-fix-document-gaps.md',
      ]);
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
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
          ucFlowUcListProvider.overrideWithValue(UcFlowFixtures.ucList),
          selectedUcProvider.overrideWith((ref) => 'UC-06'),
        ],
      );
      await tester.tap(find.byKey(const Key('action-ucFlow-open-source')));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('opened', (tester) async {
      final fake = await tapSource(tester, ExternalOpenResult.opened);
      expect(fake.calls, [
        '/ws/proj/docs/usecases/UC-06-find-and-fix-document-gaps.md',
      ]);
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
          nodeDetailNodesProvider.overrideWithValue(NodeDetailFixtures.nodes),
          nodeDetailStateProvider.overrideWith(
            (ref) =>
                const NodeDetailReady(nodeId: NodeDetailFixtures.normalNodeId),
          ),
          externalOpenerProvider.overrideWithValue(fake),
          currentWorkspaceStateProvider.overrideWith(
            (ref) => const WorkspaceReady('/ws/proj'),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
          domainViewStateProvider.overrideWith(
            (ref) => const DomainReady(mode: DomainMode.matrix),
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
      expect(fake.calls.single, startsWith('/ws/proj/'));
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

  // 0.5.0-W1-168.2.2：切換前發出、切換後才回來的結果不呈現（SPEC-003 §2.8、
  // SPEC-004 §4.26）。留痕經 staleOpenLogSink 擷取，斷言 name 與內容。
  group('專案世代比對：晚回結果', () {
    const tags = <String, String>{
      'domain 開啟 docs 目錄': 'DomainViewScreen',
      'domain 泳道開啟原始檔': 'DomainViewScreen',
      'UC Flow 開啟原始檔': 'UcFlowScreen',
      '節點詳情開啟原始檔': 'NodeDetailScreen',
    };
    final logged = <(String, String)>[];
    setUp(() {
      logged.clear();
      staleOpenLogSink = (name, message) => logged.add((name, message));
    });
    tearDown(() => staleOpenLogSink = defaultStaleOpenLogSink);

    final sites = <String, Future<_GatedOpener> Function(WidgetTester)>{
      'domain 開啟 docs 目錄': (tester) async {
        final g = _GatedOpener();
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            externalOpenerProvider.overrideWithValue(g),
            currentWorkspaceStateProvider.overrideWith(
              (ref) => const WorkspaceReady('/ws/proj'),
            ),
            domainViewStateProvider.overrideWith((ref) => const DomainEmpty()),
          ],
        );
        await tester.tap(find.byKey(const Key('action-domain-open-docs')));
        await tester.pump();
        return g;
      },
      'domain 泳道開啟原始檔': (tester) async {
        final g = _GatedOpener();
        await pumpHarness(
          tester,
          child: const DomainViewScreen(),
          overrides: [
            externalOpenerProvider.overrideWithValue(g),
            currentWorkspaceStateProvider.overrideWith(
              (ref) => const WorkspaceReady('/ws/proj'),
            ),
            ...domainFixtureOverrides(mode: DomainMode.swimlane),
            selectedUcProvider.overrideWith((ref) => _domainSelectedUc),
          ],
        );
        await tester.tap(find.byKey(const Key('action-domain-open-source')));
        await tester.pump();
        return g;
      },
      'UC Flow 開啟原始檔': (tester) async {
        final g = _GatedOpener();
        await pumpHarness(
          tester,
          child: const UcFlowScreen(),
          overrides: [
            externalOpenerProvider.overrideWithValue(g),
            currentWorkspaceStateProvider.overrideWith(
              (ref) => const WorkspaceReady('/ws/proj'),
            ),
            ucFlowUcListProvider.overrideWithValue(UcFlowFixtures.ucList),
            selectedUcProvider.overrideWith((ref) => 'UC-06'),
          ],
        );
        await tester.tap(find.byKey(const Key('action-ucFlow-open-source')));
        await tester.pump();
        return g;
      },
      '節點詳情開啟原始檔': (tester) async {
        final g = _GatedOpener();
        await pumpApp(
          tester,
          overrides: [
            nodeDetailNodesProvider.overrideWithValue(NodeDetailFixtures.nodes),
            nodeDetailStateProvider.overrideWith(
              (ref) => const NodeDetailReady(
                nodeId: NodeDetailFixtures.normalNodeId,
              ),
            ),
            externalOpenerProvider.overrideWithValue(g),
            currentWorkspaceStateProvider.overrideWith(
              (ref) => const WorkspaceReady('/ws/proj'),
            ),
            selectedDestinationProvider.overrideWith(
              (ref) => AppDestination.nodeDetail,
            ),
            domainViewStateProvider.overrideWith(
              (ref) => const DomainReady(mode: DomainMode.matrix),
            ),
          ],
        );
        await tester.tap(AnchorFinder.action(Screen.nodeDetail, 'open-source'));
        await tester.pump();
        return g;
      },
    };

    for (final entry in sites.entries) {
      for (final result in [
        ExternalOpenResult.opened,
        ExternalOpenResult.notFound,
      ]) {
        testWidgets('${entry.key}：世代已變，晚回 ${result.name} 不呈現', (tester) async {
          final g = await entry.value(tester);
          expect(g.calls, hasLength(1));
          _containerOf(tester).read(projectGenerationProvider.notifier).state++;
          g.gate.complete(result);
          await tester.pumpAndSettle();
          expect(find.text(_opened), findsNothing);
          expect(find.text(_failed), findsNothing);
          expect(find.text(_notFound), findsNothing);
          expect(
            AnchorFinder.state(Screen.nodeDetail, 'missing'),
            findsNothing,
          );
          expect(logged, hasLength(1));
          expect(logged.single.$1, tags[entry.key]);
          expect(logged.single.$2, contains(openResultKey(result)));
          expect(logged.single.$2, contains('因專案已改變而丟棄'));
        });
      }

      testWidgets('${entry.key}：世代未變，晚回照常呈現（E2 對照）', (tester) async {
        final g = await entry.value(tester);
        g.gate.complete(ExternalOpenResult.opened);
        await tester.pumpAndSettle();
        expect(find.text(_opened), findsOneWidget);
        expect(logged, isEmpty);
      });
    }
  });

  group('專案世代比對不誤殺列 16「未能記住」提示', () {
    testWidgets('選定成功但偏好寫入失敗：workspaceNotRemembered 仍出現', (tester) async {
      await pumpHarness(
        tester,
        child: const DomainViewScreen(),
        overrides: [
          domainViewStateProvider.overrideWith((ref) => const DomainUnset()),
          workspaceRepositoryProvider.overrideWithValue(_NotRememberedRepo()),
          frameworkSignalProbeProvider.overrideWithValue(
            StubFrameworkSignalProbe(version: null, schemaJson: false),
          ),
          fakeScanRoundOverride(),
        ],
      );
      await tester.tap(find.byKey(const Key('action-domain-choose-folder')));
      await tester.pumpAndSettle();
      expect(
        _containerOf(tester).read(projectGenerationProvider),
        greaterThan(0),
      );
      expect(
        find.text(AppLocalizationsZh().workspaceNotRemembered),
        findsOneWidget,
      );
    });
  });
}
