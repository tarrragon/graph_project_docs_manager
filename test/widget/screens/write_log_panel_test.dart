// 寫入清單面板（SPEC-003 §3.12、§4 #61／#62、SPEC-001 §12）：無寫入與寫入清單
// 兩態、新列在上、列內容、路徑跳轉、關閉。資料來自真實 Edit domain 的寫入路徑，
// 面板只讀取。
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/jump_targets.dart';
import 'package:graph_project_docs_manager/app/router.dart';
import 'package:graph_project_docs_manager/app/write_list_providers.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/write_log/write_log_panel.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/helpers.dart';
import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

final _l10n = AppLocalizationsZh();

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(writeLogOpenProvider);
    return open ? const WriteLogPanel() : const SizedBox.shrink();
  }
}

Future<(ProviderContainer, EditHarness, EditSession)> _pumpOpen(
  WidgetTester tester, {
  FakeValidatorPort? validator,
  Map<String, String> nodeIds = const {},
}) async {
  final h = await tester.runAsync(
    () => EditHarness.create(validator: validator ?? FakeValidatorPort()),
  );
  final session = (await tester.runAsync(h!.begin))!;
  final container = await pumpHarness(
    tester,
    child: const _Host(),
    overrides: [
      editWorkspaceProvider.overrideWith((ref) async => h.workspace),
      writeListNodeIdByPathProvider.overrideWithValue(nodeIds),
      writeLogOpenProvider.overrideWithInitial((_) => true),
    ],
  );
  await tester.runAsync(() => container.read(editWorkspaceProvider.future));
  await tester.pump();
  return (container, h, session);
}

Future<void> _write(
  WidgetTester tester,
  EditSession session,
  String field,
  String value,
) async {
  await tester.runAsync(() async {
    await session.writeField(field: field, newValue: value);
    await session.validationIdle;
  });
  await tester.pump();
}

void main() {
  testWidgets('#61 無寫入：state-writeLog-empty 帶標題與說明，無列', (tester) async {
    await _pumpOpen(tester);

    expect(find.byKey(const Key('state-writeLog-empty')), findsOneWidget);
    expect(find.byKey(const Key('state-writeLog-list')), findsNothing);
    expect(find.text(_l10n.writeLogTitle), findsOneWidget);
    expect(find.text(_l10n.writeLogEmptyMessage), findsOneWidget);
    expect(find.byType(WriteLogRow), findsNothing);
    expect(find.byKey(const Key('scroll-writeLog-list')), findsOneWidget);
  });

  testWidgets('#61 關閉鈕關閉面板、不改導覽狀態；焦點落在關閉鈕', (tester) async {
    final (container, _, _) = await _pumpOpen(tester);
    final before = container.read(selectedDestinationProvider);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<AppButton>()
          ?.testKey,
      const Key('action-writeLog-close'),
    );

    await tester.tap(find.byKey(const Key('action-writeLog-close')));
    await tester.pump();

    expect(container.read(writeLogOpenProvider), isFalse);
    expect(find.byKey(const Key('state-writeLog-empty')), findsNothing);
    expect(container.read(selectedDestinationProvider), before);
  });

  testWidgets('#61 Esc 關閉面板（正向對照：未按 Esc 時維持開啟）', (tester) async {
    final (container, _, _) = await _pumpOpen(tester);
    expect(container.read(writeLogOpenProvider), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(writeLogOpenProvider), isFalse);
  });

  testWidgets('#61→#62 面板開啟期間發出第一筆寫入：由無寫入轉為寫入清單', (tester) async {
    final (_, _, session) = await _pumpOpen(tester);
    expect(find.byKey(const Key('state-writeLog-empty')), findsOneWidget);

    await _write(tester, session, 'title', '新標題');

    expect(find.byKey(const Key('state-writeLog-empty')), findsNothing);
    expect(find.byKey(const Key('state-writeLog-list')), findsOneWidget);
    expect(find.byKey(const Key('card-writeLog-row-0')), findsOneWidget);
    expect(find.text(_l10n.writeLogEmptyMessage), findsNothing);
  });

  testWidgets('#62 列內容：路徑、欄位名、寫入結果、驗證狀態、取回說明', (tester) async {
    final (_, _, session) = await _pumpOpen(tester);

    await _write(tester, session, 'title', '新標題');

    expect(find.text(targetRelative), findsWidgets);
    expect(find.text('title'), findsOneWidget);
    expect(find.text(_l10n.writeResultWritten), findsOneWidget);
    expect(find.text(_l10n.validationPassed), findsOneWidget);
    // 第一次寫入 W = H：無快照，取回說明為 checkout，且沒有快照期限說明。
    expect(find.text('git checkout HEAD -- $targetRelative'), findsOneWidget);
    expect(find.byKey(WriteLogRow.expiryNoteKey), findsNothing);
  });

  testWidgets('#62 新的在上；有快照時取回說明為 cat-file 並附期限說明', (tester) async {
    final (_, _, session) = await _pumpOpen(tester);

    await _write(tester, session, 'title', 'a');
    await _write(tester, session, 'title', 'b');

    final top = tester.getTopLeft(find.byKey(const Key('card-writeLog-row-1')));
    final bottom = tester.getTopLeft(
      find.byKey(const Key('card-writeLog-row-0')),
    );
    expect(top.dy, lessThan(bottom.dy));
    expect(find.textContaining('git cat-file -p '), findsOneWidget);
    expect(find.byKey(WriteLogRow.expiryNoteKey), findsOneWidget);
  });

  testWidgets('#62 驗證結果晚到時該列原地更新（驗證中→發現 N 個新問題）', (tester) async {
    final (_, _, session) = await _pumpOpen(
      tester,
      validator: FakeValidatorPort(
        ucVerify: [
          validatorOk,
          ValidatorExit(1, ucViolationOutput(unregisteredUc, 1)),
        ],
      ),
    );

    await tester.runAsync(() async {
      await session.baselineIdle;
      await session.writeField(field: 'title', newValue: 'x');
    });
    await tester.pump();
    expect(find.text(_l10n.validationRunning), findsOneWidget);

    await tester.runAsync(() => session.validationIdle);
    await tester.pump();

    expect(find.text(_l10n.validationRunning), findsNothing);
    expect(find.text(_l10n.validationFailed(1)), findsOneWidget);
  });

  testWidgets('#62 baseline 未完成即寫入：顯示 baselineNotReady 原因，非非預期結束碼文案', (
    tester,
  ) async {
    final (_, _, session) = await _pumpOpen(
      tester,
      validator: FakeValidatorPort(
        ucVerify: const [ValidatorHang(), validatorOk],
      ),
    );

    await tester.runAsync(() async {
      await session.writeField(field: 'title', newValue: 'x');
      await session.validationIdle;
    });
    await tester.pump();

    expect(find.text(_l10n.validationUnavailable), findsOneWidget);
    expect(
      find.text(_l10n.validationUnavailableBaselineNotReady),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.validationUnavailableUnexpectedExitCode),
      findsNothing,
    );
  });

  testWidgets('#62 路徑可由節點表查得：渲染為可點，點擊關閉面板並跳到節點詳情', (tester) async {
    final (container, _, session) = await _pumpOpen(
      tester,
      nodeIds: {targetRelative: 'SPEC-900'},
    );
    container.read(returnToProvider.notifier).state = AppDestination.gaps;
    await _write(tester, session, 'title', 'x');

    await tester.tap(find.byKey(const Key('action-writeLog-goto-node-0')));
    await tester.pump();

    expect(container.read(writeLogOpenProvider), isFalse);
    expect(
      container.read(selectedDestinationProvider),
      AppDestination.nodeDetail,
    );
    expect(container.read(nodeDetailTargetProvider), 'SPEC-900');
    expect(container.read(returnToProvider), AppDestination.gaps);
  });

  testWidgets('#62 路徑查不到節點：不渲染為可點（正向對照：查得時有按鈕）', (tester) async {
    final (_, _, session) = await _pumpOpen(tester);

    await _write(tester, session, 'title', 'x');

    expect(find.byKey(const Key('action-writeLog-goto-node-0')), findsNothing);
    expect(find.text(targetRelative), findsWidgets);
  });
}
