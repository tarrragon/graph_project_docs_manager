// 變更記錄跳轉節點詳情（測試設計 §3.5，JP-1～JP-3）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/jump_targets.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';

import '../../../helpers/history/history_screen_fixtures.dart';

Finder _key(String k) => find.byKey(Key(k));

String? _readyId(NodeDetailState s) => s is NodeDetailReady ? s.nodeId : null;

const _graphIds = ['UC-07', '0.7.0-W1-012.11', '0.7.0-W1-012.9'];

void main() {
  testWidgets('JP-1 點宣告端：到節點詳情，payload 與 returnTo 正確', (tester) async {
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapTagged()),
      extra: [historyGraphNodes(_graphIds)],
    );
    await tester.tap(_key('action-history-open-0-declarer'));
    await tester.pumpAndSettle();
    final c = historyContainer(tester);
    expect(c.read(selectedDestinationProvider), AppDestination.nodeDetail);
    expect(c.read(returnToProvider), AppDestination.history);
    expect(_readyId(c.read(nodeDetailEffectiveStateProvider)), 'UC-07');
    expect(c.read(nodeDetailTargetProvider), isNull);
  });

  testWidgets('JP-2 點對端後返回：回到變更記錄，篩選保留', (tester) async {
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapTagged()),
      extra: [historyGraphNodes(_graphIds)],
    );
    await tester.tap(_key('option-history-period-all'));
    await tester.pumpAndSettle();
    await tester.tap(_key('action-history-open-1-counterpart'));
    await tester.pumpAndSettle();
    final c = historyContainer(tester);
    expect(
      _readyId(c.read(nodeDetailEffectiveStateProvider)),
      '0.7.0-W1-012.9',
    );
    await tester.tap(_key('action-nodeDetail-back'));
    await tester.pumpAndSettle();
    expect(c.read(selectedDestinationProvider), AppDestination.history);
    expect(_key('option-history-period-all'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(_key('option-history-period-all'))
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('JP-3 節點不在目前的圖上：落節點不存在狀態', (tester) async {
    await pumpHistoryApp(
      tester,
      HistoryLoaded(snapAbsentNode()),
      extra: [historyGraphNodes(_graphIds)],
    );
    await tester.tap(_key('action-history-open-0-counterpart'));
    await tester.pumpAndSettle();
    expect(_key('state-nodeDetail-node-absent'), findsOneWidget);
  });
}
