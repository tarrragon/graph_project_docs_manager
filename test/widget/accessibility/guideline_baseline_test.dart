// 六個畫面的 flutter_test 無障礙準則基線（0.5.0-W1-466.1）。
//
// 每畫面（正常態）× 兩尺寸 × 三準則。已知失敗以 [_knownFailures] 鎖定：
// 失敗集合與清單不一致即紅燈（新增失敗或修好舊失敗都須同步更新清單）。
// 注意：widget test 使用測試字型（方塊），對比量測只作粗篩。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/app/domain_view_schema_version.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';
import 'package:graph_project_docs_manager/app/gate_detection_notifier.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/assembly/shell.dart';
import 'package:graph_project_docs_manager/workspace/workspace_repository.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_models.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_provider.dart';
import 'package:graph_project_docs_manager/screens/gap_report/gap_report_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_fixtures.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_providers.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_screen.dart';
import 'package:graph_project_docs_manager/screens/node_detail/node_detail_state.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_providers.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_screen.dart';
import 'package:graph_project_docs_manager/screens/ticket_list/ticket_list_state.dart';
import 'package:graph_project_docs_manager/screens/trace/trace_screen.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_fixtures.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_providers.dart';
import 'package:graph_project_docs_manager/screens/uc_flow/uc_flow_screen.dart';

import '../../helpers/domain_view_fixtures.dart';
import '../../helpers/gap_round_fakes.dart';
import '../../helpers/stub_workspace_repository.dart';
import '../../helpers/helpers.dart';

class _FixedGap extends GapReportNotifier {
  @override
  GapReportState build() => const GapReportFound([
    GapReportCategory(
      id: 'parse-failure',
      items: [
        GapReportItem(
          id: 'spec-readme',
          filePath: 'docs/spec/README.md',
          lineNumber: 1,
        ),
      ],
    ),
  ]);
}

class _Case {
  const _Case(this.name, this.child, this.overrides);
  final String name;
  final Widget child;
  final List<Override> overrides;
}

final _cases = <_Case>[
  // 含 app shell：側欄 NavItem 唯一使用處（0.5.0-W1-523）。
  _Case('shell', const AppShell(), [
    domainViewStateProvider.overrideWith(
      (ref) => const DomainReady(mode: DomainMode.matrix),
    ),
    workspaceRepositoryProvider.overrideWithValue(
      StubWorkspaceRepository(const WorkspaceReady('/ws')),
    ),
    frameworkSignalProbeProvider.overrideWithValue(
      const StubFrameworkSignalProbe(version: '0.0.1', schemaJson: true),
    ),
    builtinSchemaVersionProvider.overrideWith((ref) async => '0.0.1'),
    fakeScanRoundOverride(),
  ]),
  _Case('domain', const DomainViewScreen(), domainFixtureOverrides()),
  _Case('ucFlow', const UcFlowScreen(), [
    ucFlowUcListProvider.overrideWithValue(UcFlowFixtures.ucList),
    selectedUcProvider.overrideWith((ref) => 'UC-02'),
  ]),
  _Case('traceability', const TraceabilityScreen(), const []),
  _Case('gaps', const GapReportScreen(), [
    gapReportProvider.overrideWith(_FixedGap.new),
  ]),
  _Case('tickets', const TicketListScreen(), [
    ticketListStateProvider.overrideWith(
      (ref) => const TicketsReady(
        tickets: [
          TicketFixtureItem(
            id: '0.1.0-W1-001',
            title: 'Alpha ticket',
            status: 'completed',
            priority: 'P0',
            topic: 'shell',
          ),
          TicketFixtureItem(
            id: '0.1.0-W1-002',
            title: 'Beta ticket',
            status: 'pending',
            priority: 'P1',
            topic: 'screens',
          ),
        ],
      ),
    ),
  ]),
  _Case('nodeDetail', const NodeDetailScreen(), [
    nodeDetailNodesProvider.overrideWithValue(NodeDetailFixtures.nodes),
    nodeDetailStateProvider.overrideWith(
      (ref) => const NodeDetailReady(nodeId: NodeDetailFixtures.normalNodeId),
    ),
  ]),
];

final _guidelines = <String, AccessibilityGuideline>{
  'textContrast': textContrastGuideline,
  'labeledTapTarget': labeledTapTargetGuideline,
  'minTapTarget28': const MinimumTapTargetGuideline(
    size: Size(28, 28),
    link: 'lib/tokens/layout.dart hitTargetMin',
  ),
};

/// 已知失敗基線：key = `畫面|尺寸|準則`，value = 失敗訊息行集合。
///
/// 兩項皆為 textContrast，原註解稱「區段標題文字色對白比值約 1.17～1.18」
/// 屬取樣誤判（出處 0.5.0-W1-468）：
/// - 1.18 是 surfaceIconTint #E0EFED 對白；1.17 是 surfaceChip #E9EEED 對白，
///   取到的是色塊底色而非標題文字色。
/// - 標題實際為 textSecondary #6A7674 對 surfaceBase #FFFFFF = 4.71:1，達標。
/// 清單內容與 0.5.0-W1-468 結論一致，保留作基線鎖定（原見 0.5.0-W1-466.1）。
const Map<String, Set<String>> _knownFailures = {
  'ucFlow|min|textContrast': {'選擇 UC'},
  'ucFlow|design|textContrast': {'選擇 UC'},
  'nodeDetail|min|textContrast': {'關聯節點'},
  'nodeDetail|design|textContrast': {'關聯節點'},
};

/// 從準則失敗訊息取出失敗節點的 label（每個節點一個 `label: "..."`）。
Set<String> _failedLabels(String reason) =>
    RegExp(r'label: "([^"]*)"')
        .allMatches(reason)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  for (final c in _cases) {
    for (final size in WindowSize.values) {
      testWidgets('${c.name} @ ${size.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHarness(
          tester,
          child: c.child,
          overrides: c.overrides,
          size: size,
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (c.name == 'shell') {
          // 側欄導覽項必須在受測語意樹內，否則準則通過不代表側欄被檢查。
          expect(find.byKey(const Key('nav-item-domain')), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('.+'), skipOffstage: false),
            findsWidgets,
          );
        }
        final actual = <String, Set<String>>{};
        for (final g in _guidelines.entries) {
          final r = await g.value.evaluate(tester);
          if (!r.passed) {
            actual['${c.name}|${size.name}|${g.key}'] = _failedLabels(
              r.reason ?? '',
            );
          }
        }
        handle.dispose();
        final scoped = Map.fromEntries(
          _knownFailures.entries.where(
            (e) => e.key.startsWith('${c.name}|${size.name}|'),
          ),
        );
        expect(actual, scoped);
      });
    }
  }
}
