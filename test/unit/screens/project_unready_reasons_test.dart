// 專案未就緒依原因三選一（SPEC-001 §2／§5／§6 共用定義；0.3.3-W3-389）。
//
// 三畫面（uc_flow／gap_report／node_detail）× 三原因，斷言顯示對應
// `projectUnreadyReason*` 文案，且動作標籤為 `gotoDomainViewAction`。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/graph_status.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';

import '../../helpers/helpers.dart';

const _messages = {
  ProjectUnreadyReason.notSelected: '尚未選擇專案',
  ProjectUnreadyReason.loading: '圖譜載入中',
  ProjectUnreadyReason.incompatible: '此專案不適用本 App',
};

const _gotoDomainViewLabel = '前往 Domain 視圖';

void main() {
  for (final reason in ProjectUnreadyReason.values) {
    group('專案未就緒依原因：${reason.name}', () {
      testWidgets('uc_flow', (tester) async {
        await pumpHarness(
          tester,
          child: const UcFlowScreen(),
          overrides: [projectUnreadyReasonProvider.overrideWithValue(reason)],
        );
        expect(
          AnchorFinder.state(Screen.ucFlow, 'project-unready'),
          findsOneWidget,
        );
        expect(find.text(_messages[reason]!), findsOneWidget);
        expect(find.text(_gotoDomainViewLabel), findsOneWidget);
      });

      testWidgets('gap_report', (tester) async {
        await pumpHarness(
          tester,
          child: const GapReportScreen(),
          overrides: [projectUnreadyReasonProvider.overrideWithValue(reason)],
        );
        expect(
          AnchorFinder.state(Screen.gaps, 'project-unready'),
          findsOneWidget,
        );
        expect(find.text(_messages[reason]!), findsOneWidget);
        expect(find.text(_gotoDomainViewLabel), findsOneWidget);
      });

      testWidgets('node_detail', (tester) async {
        await pumpHarness(
          tester,
          child: const NodeDetailScreen(),
          overrides: [
            nodeDetailStateProvider.overrideWith(
              (ref) => NodeDetailProjectUnready(reason),
            ),
          ],
        );
        expect(
          AnchorFinder.state(Screen.nodeDetail, 'project-unready'),
          findsOneWidget,
        );
        expect(find.text(_messages[reason]!), findsOneWidget);
        expect(find.text(_gotoDomainViewLabel), findsOneWidget);
      });
    });
  }
}
