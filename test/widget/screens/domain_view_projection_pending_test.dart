// 需求：0.5.0-W1-205.2.2 acceptance 1／2；SPEC-001 v1.55 §1「泳道 · 投影準備中」
// 與〈矩陣與泳道同由掃描輪次衍生〉生命週期條款。
// 只經 scanRoundProvider／selectedUcProvider／domainViewStateProvider 驅動，
// 以狀態錨點與替身呼叫計數斷言。「E1」標註對照輸入。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/scan_round.dart';
import 'package:graph_project_docs_manager/app/selected_uc.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';
import 'package:graph_project_docs_manager/app/domain_view_providers.dart';
import 'package:graph_project_docs_manager/screens/domain_view/domain_view_screen.dart';
import 'package:graph_project_docs_manager/app/domain_view_state.dart';

import '../../helpers/gap_round_fakes.dart';
import '../../helpers/helpers.dart';
import '../../helpers/spec001/corpus_snapshot.dart';

const _pending = Key('state-domain-swimlane-projection-pending');
const _unset = Key('state-domain-swimlane-uc-unset');
const _normal = Key('state-domain-swimlane');

void main() {
  late ScanRoundResult round;

  setUpAll(() async {
    round = fakeRound(
      event: await loadSnapshotEvent('graph_project_docs_manager'),
    );
  });

  Future<FakeScanRound> pump(
    WidgetTester tester, {
    required ScanRoundResult? initial,
    required String? selectedUc,
    ScanRoundResult? Function()? produce,
  }) async {
    final fake = FakeScanRound(
      produce: produce ?? () => null,
      initial: initial,
    );
    await pumpHarness(
      tester,
      child: const DomainViewScreen(),
      overrides: [
        scanRoundProvider.overrideWith(() => fake),
        domainViewStateProvider.overrideWith(
          (ref) => const DomainReady(mode: DomainMode.swimlane),
        ),
        selectedUcProvider.overrideWith((ref) => selectedUc),
      ],
    );
    await tester.pump();
    return fake;
  }

  testWidgets('已選定 UC 且無完成輪次：投影準備中，不顯示需先選定 UC，標題只有 UC id', (tester) async {
    await pump(tester, initial: null, selectedUc: 'UC-02');
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DomainViewScreen)),
    );

    expect(find.byKey(_pending), findsOneWidget);
    expect(find.byKey(_unset), findsNothing);
    expect(find.text(l10n.swimlaneProjectionPendingPrompt), findsOneWidget);
    expect(find.text('UC-02'), findsOneWidget);
  });

  testWidgets('E1 對照：未選定 UC 且無完成輪次 → 仍是 uc-unset', (tester) async {
    await pump(tester, initial: null, selectedUc: null);

    expect(find.byKey(_unset), findsOneWidget);
    expect(find.byKey(_pending), findsNothing);
  });

  testWidgets('E1 對照：已有完成輪次 → 不進準備中', (tester) async {
    await pump(tester, initial: round, selectedUc: 'UC-02');

    expect(find.byKey(_pending), findsNothing);
    expect(find.byKey(_unset), findsNothing);
  });

  testWidgets('Idle 且無完成輪次：重啟輪次，完成後準備中轉出', (tester) async {
    final fake = await pump(
      tester,
      initial: null,
      selectedUc: 'UC-02',
      produce: () => round,
    );
    await tester.pump();
    await tester.pump();

    expect(fake.ensureCalls + fake.rescanCalls, greaterThanOrEqualTo(1));
    expect(find.byKey(_pending), findsNothing);
    expect(
      find.byKey(_normal).evaluate().isNotEmpty ||
          find
              .byKey(const Key('state-domain-swimlane-unstructured'))
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
  });

  testWidgets('E1 對照：已有完成輪次，取消重掃（Idle）後不自動重啟', (tester) async {
    final fake = await pump(tester, initial: round, selectedUc: 'UC-02');
    final before = fake.ensureCalls + fake.rescanCalls;

    fake.discard('cancel');
    await tester.pump();
    await tester.pump();

    expect(fake.ensureCalls + fake.rescanCalls, before);
    expect(find.byKey(_pending), findsNothing);
  });
}
