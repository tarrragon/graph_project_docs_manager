// 節點詳情畫面（SPEC-001 §6）五個狀態的渲染與退出路徑測試。
//
// 依 `pump_harness.dart` 慣例：以 `nodeDetailStateProvider.overrideWith`
// 直接注入目標狀態，不經真實節點解析。逐狀態斷言 SPEC-004 §3.6 對應行的
// 契約內元件型別存在，並驗證每個狀態的退出路徑可實際操作走通。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/corpus/parse_outcome.dart';
import 'package:graph_project_docs_manager/graph/graph_built_event.dart';
import 'package:graph_project_docs_manager/graph/light_node.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/workspace/external_opener.dart';

import '../../helpers/helpers.dart';

void main() {
  group('專案未就緒（state-nodeDetail-project-unready，SPEC-001 §6 共用定義）', () {
    testWidgetsAtEachSize('渲染 EmptyState.page', (tester, size) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailProjectUnready(
              ProjectUnreadyReason.notSelected,
            ),
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
            (ref) => const NodeDetailProjectUnready(
              ProjectUnreadyReason.notSelected,
            ),
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
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailUnset(),
          ),
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
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailUnset(),
          ),
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

  test('不注入狀態時預設為未選節點（NodeDetailUnset）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(nodeDetailStateProvider), isA<NodeDetailUnset>());
  });

  group('正常（state-nodeDetail-normal）', () {
    testWidgetsAtEachSize('渲染 TwoColumnLayout + DocumentBody', (
      tester,
      size,
    ) async {
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [_fixtureNodes, _readyNormal],
        size: size,
      );

      expect(AnchorFinder.state(Screen.nodeDetail, 'normal'), findsOneWidget);
      expect(find.byType(TwoColumnLayout), findsOneWidget);
      expect(find.byType(DocumentBody), findsOneWidget);
      expect(find.byType(Panel), findsNWidgets(2));
      expectNoOverflow(tester);
    });

    testWidgets('card-nodeDetail-relation-<id>：同畫面替換主欄為該節點，returnTo 不變', (
      tester,
    ) async {
      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [_fixtureNodes, _readyNormal],
      );
      final before = container.read(returnToProvider);
      final firstTitle =
          NodeDetailFixtures.nodes[NodeDetailFixtures.normalNodeId]!.title;
      final secondTitle =
          NodeDetailFixtures.nodes[NodeDetailFixtures.secondNodeId]!.title;
      expect(find.text(firstTitle), findsWidgets);
      expect(find.text(secondTitle), findsNothing);

      await tester.tap(
        find.byKey(
          Key('card-nodeDetail-relation-${NodeDetailFixtures.secondNodeId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(AnchorFinder.state(Screen.nodeDetail, 'normal'), findsOneWidget);
      expect(find.text(firstTitle), findsNothing);
      expect(find.text(secondTitle), findsWidgets);
      expect(container.read(returnToProvider), before);
    });

    testWidgets(
      'action-nodeDetail-open-source（SplitRow.header 右格；檔案不存在）：同畫面轉為原始檔已消失',
      (tester) async {
        await pumpApp(
          tester,
          overrides: [
            _fixtureNodes,
            _readyNormal,
            selectedDestinationProvider.overrideWith(
              (ref) => AppDestination.nodeDetail,
            ),
            externalOpenerProvider.overrideWithValue(
              FakeExternalOpener(defaultResult: ExternalOpenResult.notFound),
            ),
          ],
        );

        await tester.tap(AnchorFinder.action(Screen.nodeDetail, 'open-source'));
        await tester.pump();

        expect(
          AnchorFinder.state(Screen.nodeDetail, 'missing'),
          findsOneWidget,
        );
      },
    );
  });

  // 部分損壞測試群組在 0.x 不可達而退場，恢復條件見 0.5.0-W1-540.1.1。

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

    testWidgets('action-nodeDetail-refresh（檔案仍不存在）：維持本狀態並提示', (tester) async {
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
      expect(find.text('檔案存在但無法解析，詳見破洞報告'), findsNothing);
      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsOneWidget);
    });

    testWidgets('action-nodeDetail-refresh（檔案已存在）：轉為正常', (tester) async {
      final file = File('${tempDir.path}/restored.md')
        ..writeAsStringSync('---\ntitle: restored\n---\n# restored');

      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          _fixtureNodes,
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
      expect(container.read(nodeDetailStateProvider), isA<NodeDetailReady>());
      expect(find.text('檔案仍不存在'), findsNothing);
      expect(find.text('檔案存在但無法解析，詳見破洞報告'), findsNothing);
    });

    testWidgets('action-nodeDetail-refresh（存在但解析失敗）：維持本狀態並提示無法解析', (
      tester,
    ) async {
      final file = File('${tempDir.path}/broken.md')
        ..writeAsStringSync('---\ntitle: broken\n# 未閉合');

      final container = await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          _fixtureNodes,
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

      expect(find.text('檔案存在但無法解析，詳見破洞報告'), findsOneWidget);
      expect(find.text('檔案仍不存在'), findsNothing);
      expect(AnchorFinder.state(Screen.nodeDetail, 'missing'), findsOneWidget);
      expect(container.read(nodeDetailStateProvider), isA<NodeDetailMissing>());
    });
  });

  group('重新整理讀檔失敗分類（readRefreshOutcome）', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('refresh_reason_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Unreadable readWithErrno(int errno) {
      final file = File('${dir.path}/a.md')..writeAsStringSync('x');
      final outcome = readRefreshOutcome(
        file.path,
        readBytes: (_) =>
            throw FileSystemException('read', file.path, OSError('', errno)),
      );
      return outcome! as Unreadable;
    }

    test('E1 對照：errno 13 為 permission、errno 2 為 fileDeleted，且分類不同', () {
      final denied = readWithErrno(13);
      final gone = readWithErrno(2);
      expect(denied.reason, UnreadableReason.permission);
      expect(gone.reason, UnreadableReason.fileDeleted);
      expect(denied.reason, isNot(gone.reason));
      expect(denied.kind, gone.kind); // 同為 unreadable，畫面皆提示無法解析
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
          nodeDetailStateProvider.overrideWith(
            (ref) => const NodeDetailUnset(),
          ),
        ],
      );

      expect(
        AnchorFinder.action(Screen.nodeDetail, 'open-source'),
        findsNothing,
      );
    });
  });

  group('關聯項 isProposed（SPEC-001 §6、SPEC-004 4.19）', () {
    testWidgets('E1 對照：同一節點詳情內 proposed 分節項目有「暫定」，established 無', (
      tester,
    ) async {
      final base = NodeDetailFixtures.nodes[NodeDetailFixtures.normalNodeId]!;
      final node = NodeDetailFixture(
        id: base.id,
        type: base.type,
        status: base.status,
        title: base.title,
        filePath: base.filePath,
        markdown: base.markdown,
        relations: const [
          NodeRelationCategory(
            label: 'bundle_dependency',
            nodeIds: ['P1'],
            isProposed: true,
          ),
          NodeRelationCategory(label: 'spawn', nodeIds: ['E1']),
        ],
      );
      await pumpHarness(
        tester,
        child: const NodeDetailScreen(),
        overrides: [
          nodeDetailNodesProvider.overrideWithValue({base.id: node}),
          _readyNormal,
        ],
      );

      Finder badgeIn(String label) => find.descendant(
        of: find.byKey(Key('panel-nodeDetail-relations-$label')),
        matching: find.text('暫定'),
      );
      expect(badgeIn('bundle_dependency'), findsOneWidget);
      expect(badgeIn('spawn'), findsNothing);
    });

    test('同一節點對的 proposed 與 established 邊分成兩個分節各自標示', () {
      GraphEdge edge(String type, String layer) => GraphEdge(
        edgeType: type,
        from: 'A',
        to: 'B',
        declaredBy: {'A'},
        isUndirected: false,
        layer: layer,
      );
      final event = GraphBuiltEvent(
        nodes: const [],
        edges: [
          edge('bundle_dependency', 'proposed'),
          edge('spawn', 'established'),
        ],
        graphDefects: const [],
        totalReferences: 0,
        resolvedCount: 0,
      );
      final event2 = GraphBuiltEvent(
        nodes: const [
          LightNode(
            id: 'A',
            typeName: 'SPEC',
            status: null,
            title: 'A',
            path: 'a.md',
          ),
        ],
        edges: event.edges,
        graphDefects: const [],
        totalReferences: 0,
        resolvedCount: 0,
      );

      final cats = projectNodeDetails(event2)['A']!.relations;

      expect(
        [for (final c in cats) (c.label, c.isProposed)],
        [('bundle_dependency', true), ('spawn', false)],
      );
    });

    test('projectNodeDetails 由建圖結果投影節點與相鄰關聯', () {
      final event = GraphBuiltEvent(
        nodes: const [
          LightNode(
            id: 'A',
            typeName: 'SPEC',
            status: 'draft',
            title: 'Alpha',
            path: 'a.md',
          ),
          LightNode(
            id: 'B',
            typeName: 'UC',
            status: null,
            title: null,
            path: 'b.md',
          ),
        ],
        edges: [
          GraphEdge(
            edgeType: 't',
            from: 'A',
            to: 'B',
            declaredBy: {'A'},
            isUndirected: false,
            layer: 'established',
          ),
        ],
        graphDefects: const [],
        totalReferences: 0,
        resolvedCount: 0,
      );

      final nodes = projectNodeDetails(event);

      expect(nodes['A']!.title, 'Alpha');
      expect(nodes['A']!.markdown, isEmpty); // 內文延遲讀取
      expect(nodes['A']!.relations.single.label, 't');
      expect(nodes['A']!.relations.single.nodeIds, ['B']);
      expect(nodes['B']!.relations.single.nodeIds, ['A']);
    });
  });
}

/// 測試注入：狀態明示為正常態（provider 預設為未選節點）。
final _readyNormal = nodeDetailStateProvider.overrideWith(
  (ref) => const NodeDetailReady(nodeId: NodeDetailFixtures.normalNodeId),
);

/// 測試注入：節點資料改用 fixture（預設讀共用掃描輪次）。
final _fixtureNodes = nodeDetailNodesProvider.overrideWithValue(
  NodeDetailFixtures.nodes,
);
