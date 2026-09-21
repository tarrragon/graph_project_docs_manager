// 節點詳情畫面（SPEC-001 §6）五個狀態的渲染與退出路徑測試。
//
// 依 `pump_harness.dart` 慣例：以 `nodeDetailStateProvider.overrideWith`
// 直接注入目標狀態，不經真實節點解析。逐狀態斷言 SPEC-004 §3.6 對應行的
// 契約內元件型別存在，並驗證每個狀態的退出路徑可實際操作走通。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';

import '../../helpers/helpers.dart';

void main() {
  group('專案未就緒（state-nodeDetail-project-unready，SPEC-001 §6 共用定義）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailProjectUnready(),
          ),
        ],
        size: size,
      );

      expect(
        AnchorFinder.state(Screen.nodeDetail, 'project-unready'),
        findsOneWidget,
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-nodeDetail-goto-domain：jump 至 Domain 視圖並記錄 returnTo', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailProjectUnready(),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.nodeDetail, 'goto-domain'));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.domain,
      );
      expect(container.read(returnToProvider), AppDestination.nodeDetail);
    });
  });

  group('未選節點（state-nodeDetail-unset，SPEC-001 §6 v1.3 新增）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith((ref) => const NodeDetailUnset()),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.nodeDetail, 'unset'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-nodeDetail-goto-traceability：jump 至追溯視圖並記錄 returnTo', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith((ref) => const NodeDetailUnset()),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
        ],
      );

      await tester.tap(
        AnchorFinder.action(Screen.nodeDetail, 'goto-traceability'),
      );
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.traceability,
      );
      expect(container.read(returnToProvider), AppDestination.nodeDetail);
    });
  });

  group('正常（state-nodeDetail-normal）', () {
    testWidgetsAtEachSize('渲染 TwoColumnLayout + DocumentBody', (
      tester,
      size,
    ) async {
      await pumpHarness(tester, child: const NodeDetailScreen(), size: size);

      expect(AnchorFinder.state(Screen.nodeDetail, 'normal'), findsOneWidget);
      expect(find.byType(TwoColumnLayout), findsOneWidget);
      expect(find.byType(DocumentBody), findsOneWidget);
      expect(find.byType(Panel), findsNWidgets(2));
      expectNoOverflow(tester);
    });

    testWidgets('card-nodeDetail-relation-<id>：同畫面替換主欄內容為部分損壞節點', (
      tester,
    ) async {
      await pumpHarness(tester, child: const NodeDetailScreen());

      await tester.tap(
        find.byKey(
          Key('card-nodeDetail-relation-${NodeDetailFixtures.partialNodeId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(AnchorFinder.state(Screen.nodeDetail, 'partial'), findsOneWidget);
    });

    testWidgets(
      'action-nodeDetail-open-source（SplitRow.header 右格；檔案不存在）：同畫面轉為原始檔已消失',
      (tester) async {
        await pumpApp(
          tester,
          overrides: [
            selectedDestinationProvider.overrideWith(
              (ref) => AppDestination.nodeDetail,
            ),
          ],
        );

        await tester.tap(
          AnchorFinder.action(Screen.nodeDetail, 'open-source'),
        );
        await tester.pump();

        expect(
          AnchorFinder.state(Screen.nodeDetail, 'missing'),
          findsOneWidget,
        );
      },
    );
  });

  group('部分損壞（state-nodeDetail-partial）', () {
    testWidgetsAtEachSize('渲染欄位級 IssueMarker.damagedDetail', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailReady(
              nodeId: NodeDetailFixtures.partialNodeId,
            ),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.nodeDetail, 'partial'), findsOneWidget);
      expect(find.byType(IssueMarker), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-nodeDetail-goto-gaps：jump 至破洞報告並記錄 returnTo', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailReady(
              nodeId: NodeDetailFixtures.partialNodeId,
            ),
          ),
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
        ],
      );

      await tester.tap(AnchorFinder.action(Screen.nodeDetail, 'goto-gaps'));
      await tester.pump();

      expect(
        container.read(selectedDestinationProvider),
        AppDestination.gaps,
      );
      expect(container.read(returnToProvider), AppDestination.nodeDetail);
    });
  });

  group('原始檔已消失（state-nodeDetail-missing）', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('node_detail_missing_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    testWidgetsAtEachSize('渲染 MissingSourceState', (tester, size) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => NodeDetailMissing(
              nodeId: NodeDetailFixtures.normalNodeId,
              lastKnownPath: '${tempDir.path}/missing.md',
            ),
          ),
        ],
        size: size,
      );

      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsOneWidget);
      expect(find.byType(MissingSourceState), findsOneWidget);
      expectNoOverflow(tester);
    });

    testWidgets('action-nodeDetail-refresh（檔案仍不存在）：維持本狀態並提示', (
      tester,
    ) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => NodeDetailMissing(
              nodeId: NodeDetailFixtures.normalNodeId,
              lastKnownPath: '${tempDir.path}/missing.md',
            ),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-nodeDetail-refresh')));
      await tester.pump();

      expect(find.text('檔案仍不存在'), findsOneWidget);
      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsOneWidget);
    });

    testWidgets('action-nodeDetail-refresh（檔案已存在）：轉為正常', (tester) async {
      final file = File('${tempDir.path}/restored.md')
        ..writeAsStringSync('# restored');

      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => NodeDetailMissing(
              nodeId: NodeDetailFixtures.normalNodeId,
              lastKnownPath: file.path,
            ),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('action-nodeDetail-refresh')));
      await tester.pump();

      expect(AnchorFinder.state(Screen.nodeDetail, 'normal'), findsOneWidget);
      expect(
        container.read(nodeDetailStateProvider),
        isA<NodeDetailReady>(),
      );
    });
  });

  group('頁首開啟原始檔鈕（SplitRow.header 右格，lib/app/shell.dart 接線）', () {
    testWidgets('未選節點不渲染開啟原始檔鈕（正向對照）', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          selectedDestinationProvider.overrideWith(
            (ref) => AppDestination.nodeDetail,
          ),
          nodeDetailStateProvider.overrideWith((ref) => const NodeDetailUnset()),
        ],
      );

      expect(AnchorFinder.action(Screen.nodeDetail, 'open-source'), findsNothing);
    });
  });
}
