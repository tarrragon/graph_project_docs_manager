/// FatalErrorGate 元件測試。
// rule8-exempt: illustration:worktree 路徑含 .claude/ 前綴觸發框架文件誤判，本檔為專案測試檔非框架文件
///
/// 驗收「單一錯誤出口含一個 app 級的最後手段顯示」：`fatalErrorNotifier`
/// 非空時，`FatalErrorGate` 以 `BlockedState.plain` 取代原本的
/// `child`，使用者看得到畫面而非停在半渲染狀態。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/main.dart';

import '../../helpers/helpers.dart';

void main() {
  tearDown(() {
    fatalErrorNotifier.value = null;
  });

  testWidgets('無錯誤時顯示原本的 child', (tester) async {
    await pumpHarness(
      tester,
      child: const FatalErrorGate(child: Text('normal-content')),
    );

    expectNoOverflow(tester);
    expect(find.text('normal-content'), findsOneWidget);
    expect(find.byType(BlockedState), findsNothing);
  });

  testWidgets('fatalErrorNotifier 非空時以 BlockedState.plain 取代 child', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      child: const FatalErrorGate(child: Text('normal-content')),
    );

    fatalErrorNotifier.value = StateError('人為觸發的致命例外');
    await tester.pump();

    expectNoOverflow(tester);
    expect(find.text('normal-content'), findsNothing);
    expect(find.byType(BlockedState), findsOneWidget);
    expect(find.byKey(const Key('state-fatal-error')), findsOneWidget);
  });
}
