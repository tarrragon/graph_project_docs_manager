// SPEC-001-test-design F1-6、F1-7：UC Flow 視圖「flow 未結構化」狀態的訊息
// 依 flow 區塊是否解析失敗（EVT-CORPUS-004）分派。
//
// F1-6：F1-3 輸入（選定 UC 無步驟 + 有解析失敗破洞）→ `flowParseFailedMessage`。
// F1-7（E1 對照）：F1-4 輸入（無步驟、無解析失敗破洞）→ 「尚未填寫結構化
// flow」原文案，且與 F1-6 不同。兩者走同一條真實輪次路徑，差異只在破洞。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/corpus/parse_failure_event.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';

import '../../../helpers/gap_round_fakes.dart';
import '../../../helpers/helpers.dart';

const _unstructuredAnchor = 'unstructured';

/// 選定 [fakeUcNode]（無任何步驟），輪次的 EVT-CORPUS-004 由 [failed] 決定。
Future<AppLocalizations> _pumpUnstructured(
  WidgetTester tester, {
  required bool failed,
}) async {
  final round = fakeRound(
    flowEvents: [
      if (failed)
        const FlowParseFailedEvent(
          path: fakeUcPath,
          reason: 'flowBlockMalformed', // i18n-exempt: 測試用原因碼
        ),
    ],
  );
  await pumpHarness(
    tester,
    child: const UcFlowScreen(),
    overrides: [
      scanRoundProvider.overrideWith(
        () => FakeScanRound(produce: () => round, initial: round),
      ),
      selectedUcProvider.overrideWith((ref) => fakeUcNode.id),
    ],
  );
  return AppLocalizations.of(tester.element(find.byType(UcFlowScreen)));
}

void main() {
  testWidgets('F1-6 無步驟且有解析失敗破洞 → flowParseFailedMessage', (tester) async {
    final l10n = await _pumpUnstructured(tester, failed: true);

    expect(
      AnchorFinder.state(Screen.ucFlow, _unstructuredAnchor),
      findsOneWidget,
    );
    expect(find.text(l10n.flowParseFailedMessage), findsOneWidget);
    expect(find.text(l10n.flowUnstructuredMessage), findsNothing);
    expect(
      find.byKey(const Key('action-ucFlow-open-source')),
      findsOneWidget,
    );
  });

  testWidgets('F1-7（E1）無步驟、無解析失敗破洞 → 原文案，且與 F1-6 不同', (tester) async {
    final l10n = await _pumpUnstructured(tester, failed: false);

    expect(
      AnchorFinder.state(Screen.ucFlow, _unstructuredAnchor),
      findsOneWidget,
    );
    expect(find.text('尚未填寫結構化 flow'), findsOneWidget);
    expect(find.text(l10n.flowUnstructuredMessage), findsOneWidget);
    expect(find.text(l10n.flowParseFailedMessage), findsNothing);
    expect(l10n.flowParseFailedMessage, isNot(l10n.flowUnstructuredMessage));
  });
}
