// F1-1～F1-5：flow 區塊解析失敗的泳道呈現（SPEC-001 §1）。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';

import '../../../helpers/helpers.dart';

List<Override> _overrides(DomainSwimlaneView swimlane) => [
  domainViewStateProvider.overrideWith(
    (ref) => const DomainReady(mode: DomainMode.swimlane),
  ),
  domainSwimlaneProvider.overrideWith((ref) => swimlane),
  selectedUcProvider.overrideWith((ref) => 'UC-01'),
];

DomainSwimlane _lanes({required bool failed}) => DomainSwimlane(
  hasFlowParseFailure: failed,
  edges: const [],
  lanes: const [
    DomainLane(
      domainId: null,
      kind: DomainLaneKind.screen,
      nodes: [DomainLaneNode(stepLabel: 's1', column: 0, stepTraverses: [])],
    ),
  ],
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  DomainSwimlaneView swimlane,
) async {
  await pumpHarness(
    tester,
    child: const DomainViewScreen(),
    overrides: _overrides(swimlane),
  );
  return AppLocalizations.of(tester.element(find.byType(DomainViewScreen)));
}

void main() {
  group('F1 泳道解析失敗呈現', () {
    testWidgets('F1-1 有失敗且有步驟：泳道 + caption 提示', (tester) async {
      final l10n = await _pump(tester, _lanes(failed: true));
      expect(find.byKey(const Key('state-domain-swimlane')), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(find.text(l10n.swimlaneFlowParseFailedHint), findsOneWidget);
    });

    testWidgets('F1-2 無失敗：同泳道、無 caption', (tester) async {
      final l10n = await _pump(tester, _lanes(failed: false));
      expect(find.byKey(const Key('state-domain-swimlane')), findsOneWidget);
      expect(find.byType(SwimlaneGrid), findsOneWidget);
      expect(find.text(l10n.swimlaneFlowParseFailedHint), findsNothing);
    });

    testWidgets('F1-3 步驟為空且有失敗：解析失敗文案、有開啟動作', (tester) async {
      final l10n = await _pump(
        tester,
        const DomainSwimlaneUnstructured(isFlowParseFailed: true),
      );
      expect(find.text(l10n.flowParseFailedMessage), findsOneWidget);
      expect(find.text(l10n.flowUnstructuredMessage), findsNothing);
      expect(find.byType(SwimlaneGrid), findsNothing);
      expect(
        find.byKey(const Key('action-domain-open-source')),
        findsOneWidget,
      );
    });

    testWidgets('F1-4 步驟為空且無失敗：未結構化文案', (tester) async {
      final l10n = await _pump(tester, const DomainSwimlaneUnstructured());
      expect(find.text(l10n.flowUnstructuredMessage), findsOneWidget);
      expect(find.text(l10n.flowParseFailedMessage), findsNothing);
      expect(
        find.byKey(const Key('state-domain-swimlane-unstructured')),
        findsOneWidget,
      );
    });

    testWidgets('F1-5 開啟原始檔不改變畫面狀態', (tester) async {
      await _pump(
        tester,
        const DomainSwimlaneUnstructured(isFlowParseFailed: true),
      );
      await tester.tap(find.byKey(const Key('action-domain-open-source')));
      await tester.pump();
      expect(
        find.byKey(const Key('state-domain-swimlane-unstructured')),
        findsOneWidget,
      );
    });
  });
}
