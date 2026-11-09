// 變更記錄事件列（測試設計 §3.4，EV-1～EV-7）。
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/history/application/history_state.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';

import '../../../helpers/history/history_screen_fixtures.dart';

final _l10n = AppLocalizationsZh();

Finder _key(String k) => find.byKey(Key(k));

Finder _row(int i) => find.byType(AppTableRow).at(i + 1);

Finder _inRow(int i, Finder f) => find.descendant(of: _row(i), matching: f);

String _label(
  int i,
  String change,
  String edge,
  String declarer,
  String counterpart,
  String hash,
  String date,
) => _l10n.historyEventA11yLabel(
  change,
  edge,
  declarer,
  counterpart,
  hash,
  date,
  'tester',
  'subject $hash a1b2c3d4e5f6',
);

void main() {
  testWidgets('EV-1 表頭七欄與列 0 的七格值', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    for (final h in [
      _l10n.columnChange,
      _l10n.columnEdgeType,
      _l10n.columnDeclarer,
      _l10n.columnCounterpart,
      _l10n.columnCommit,
      _l10n.columnDate,
      _l10n.columnAuthorMessage,
    ]) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(_inRow(0, find.text(_l10n.historyEventAdded)), findsOneWidget);
    expect(_inRow(0, find.text('uc_ticket_refs')), findsOneWidget);
    expect(_inRow(0, find.text('UC-07')), findsOneWidget);
    expect(_inRow(0, find.text('0.7.0-W1-012.11')), findsOneWidget);
    expect(_inRow(0, find.text('h5')), findsOneWidget);
    expect(_inRow(0, find.text('2026-11-05')), findsOneWidget);
    expect(
      _inRow(
        0,
        find.text(
          _l10n.historyEventAuthorMessage('tester', 'subject h5 a1b2c3d4e5f6'),
        ),
      ),
      findsOneWidget,
    );
    final badge = tester.widget<Badge>(_inRow(0, find.byType(Badge)));
    expect(badge.tone, BadgeTone.positive);
  });

  testWidgets('EV-2 列序 E0、E1、E2，index 自 0 起算', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(find.byType(AppTableRow), findsNWidgets(4));
    expect(_inRow(0, find.text('0.7.0-W1-012.11')), findsOneWidget);
    expect(_inRow(1, find.text('0.7.0-W1-012.9')), findsOneWidget);
    expect(_inRow(2, find.text('schema')), findsOneWidget);
    expect(_key('action-history-open-0-declarer'), findsOneWidget);
    expect(_key('action-history-open-3-declarer'), findsNothing);
  });

  testWidgets('EV-3 列 1 為移除（negative），兩端皆可點', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_inRow(1, find.text(_l10n.historyEventRemoved)), findsOneWidget);
    expect(
      tester.widget<Badge>(_inRow(1, find.byType(Badge))).tone,
      BadgeTone.negative,
    );
    expect(_key('action-history-open-1-declarer'), findsOneWidget);
    expect(_key('action-history-open-1-counterpart'), findsOneWidget);
  });

  testWidgets('EV-4 domain_dependency 對端純文字不可點', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_key('action-history-open-2-declarer'), findsOneWidget);
    expect(_key('action-history-open-2-counterpart'), findsNothing);
    expect(_inRow(2, find.text('schema')), findsOneWidget);
  });

  testWidgets('EV-5 對照：列 0、列 1 的 counterpart 錨點存在', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    expect(_key('action-history-open-0-counterpart'), findsOneWidget);
    expect(_key('action-history-open-1-counterpart'), findsOneWidget);
  });

  testWidgets('EV-6 每列 Semantics label 含完整值', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    final expected = [
      _label(
        0,
        _l10n.historyEventAdded,
        'uc_ticket_refs',
        'UC-07',
        '0.7.0-W1-012.11',
        'h5',
        '2026-11-05',
      ),
      _label(
        1,
        _l10n.historyEventRemoved,
        'blockedBy',
        '0.7.0-W1-012.11',
        '0.7.0-W1-012.9',
        'h5',
        '2026-11-05',
      ),
      _label(
        2,
        _l10n.historyEventAdded,
        'domain_dependency',
        'history',
        'schema',
        'h4',
        '2026-11-03',
      ),
    ];
    for (final label in expected) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('EV-7 include 後重新編號：E4 依主線位置插入，E3 位移', (tester) async {
    await pumpHistoryApp(tester, HistoryLoaded(snapTagged()));
    await tester.tap(_key('option-history-period-all'));
    await tester.pumpAndSettle();
    expect(_inRow(3, find.text('UC-01')), findsOneWidget);
    await tester.tap(_key('action-history-include-ticket-created'));
    await tester.pumpAndSettle();
    expect(_inRow(3, find.text('0.7.0-W1-012.4')), findsOneWidget);
    expect(_inRow(4, find.text('UC-01')), findsOneWidget);
    expect(_key('action-history-open-4-declarer'), findsOneWidget);
  });
}
