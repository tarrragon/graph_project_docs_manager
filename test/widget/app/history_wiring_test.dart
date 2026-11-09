// app root 對 historyScanInputsProvider 的接線（測試設計 §3.9，WR-1～WR-5）。
//
// 不 override historyScanInputsProvider：預設實作須取自實際 Schema 狀態。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/history_providers.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';

import '../../helpers/history/fake_process_runner.dart';
import '../../helpers/history/history_screen_fixtures.dart';
import '../../helpers/pump_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _pumpWired(
  WidgetTester tester,
  FakeProcessRunner runner, {
  bool schemaJson = true,
}) => pumpApp(
  tester,
  overrides: [
    ...historyGateOverrides(schemaJson: schemaJson),
    historyProcessRunnerProvider.overrideWithValue(runner),
  ],
);

void main() {
  testWidgets('WR-1 真實 app root：進入第七畫面不拋 UnimplementedError', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner);
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_key('state-history-project-unready'), findsNothing);
    expect(runner.callKinds, contains('version'));
    expect(
      historyContainer(tester).read(historyProvider),
      isA<HistoryLoaded>(),
    );
  });

  testWidgets('WR-2 內建型別表降級：降級徽章可見（Schema 就緒度取自實際狀態）', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner, schemaJson: false);
    await tester.tap(_key('action-domain-degraded-view'));
    await tester.pumpAndSettle();
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_key('badge-history-degraded-schema'), findsOneWidget);
    expect(runner.callKinds, contains('version'));
  });

  testWidgets('WR-3 無可消費的型別表：專案未就緒，git 0 次', (tester) async {
    final runner = FakeProcessRunner();
    await _pumpWired(tester, runner, schemaJson: false);
    await tester.tap(_key('nav-item-history'));
    await tester.pumpAndSettle();
    expect(_key('state-history-project-unready'), findsOneWidget);
    expect(runner.calls, isEmpty);
  });

  test('WR-4（對照）不含 history override 的最小容器讀取必接線 provider 拋錯', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(historyScanInputsProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  testWidgets('WR-5 導覽列七項，變更記錄為第七項', (tester) async {
    await _pumpWired(tester, FakeProcessRunner());
    for (final d in AppDestination.values) {
      expect(_key('nav-item-${d.name}'), findsOneWidget);
    }
    expect(AppDestination.values.last, AppDestination.history);
    expect(AppDestination.values, hasLength(7));
    final ys = [
      for (final d in AppDestination.values)
        tester.getTopLeft(_key('nav-item-${d.name}')).dy,
    ];
    expect(ys, [...ys]..sort());
    expect(ys.last, greaterThan(ys[ys.length - 2]));
  });
}
