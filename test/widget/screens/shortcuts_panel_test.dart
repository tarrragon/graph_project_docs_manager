// 鍵盤快捷鍵面板（SPEC-003 §3.10、SPEC-001 §11）：十列靜態清單、
// Esc 與關閉鈕可關閉、焦點落在關閉鈕。
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations_zh.dart';
import 'package:graph_project_docs_manager/screens/shortcuts/shortcuts_panel.dart';
import 'package:graph_project_docs_manager/state/state_holder.dart';

import '../../helpers/helpers.dart';

final _l10n = AppLocalizationsZh();

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(shortcutsOpenProvider);
    return open ? const ShortcutsPanel() : const SizedBox.shrink();
  }
}

Future<ProviderContainer> _pumpOpen(WidgetTester tester) => pumpHarness(
  tester,
  child: const _Host(),
  overrides: [shortcutsOpenProvider.overrideWithInitial((_) => true)],
);

void main() {
  testWidgets('依 SPEC-001 §11 列序渲染標題與十列', (tester) async {
    await _pumpOpen(tester);

    expect(find.byKey(const Key('state-shortcuts-list')), findsOneWidget);
    expect(find.text(_l10n.keyboardShortcutsTitle), findsOneWidget);
    final rows = tester
        .widgetList<ListRow>(find.byType(ListRow, skipOffstage: false))
        .toList();
    expect(rows, hasLength(10));
    expect(rows.every((r) => r.variant == ListRowVariant.shortcut), isTrue);
    expect(
      [for (final r in rows) r.primary.text],
      [
        _l10n.shortcutOpenPreferencesAction,
        _l10n.shortcutCloseSwitcherAction,
        _l10n.shortcutCloseSchemaDetailAction,
        _l10n.shortcutClearCellAction,
        _l10n.shortcutCloseFilterMenuAction,
        _l10n.shortcutClosePanelAction,
        _l10n.shortcutMoveFocusAction,
        _l10n.shortcutActivateAction,
        _l10n.shortcutOpenFilterMenuAction,
        _l10n.shortcutMoveInFilterMenuAction,
      ],
    );
    expect(
      [for (final r in rows) r.keys],
      [
        '⌘,',
        'Esc',
        'Esc',
        'Esc',
        'Esc',
        'Esc',
        'Tab／Shift+Tab',
        'Enter／Space',
        '↓',
        '↑／↓／Home／End',
      ],
    );
    expect(
      [for (final r in rows) r.contextLabel],
      [
        _l10n.shortcutContextAnywhere,
        _l10n.shortcutContextSwitcherOpen,
        _l10n.shortcutContextSchemaDetailOpen,
        _l10n.shortcutContextCellSelected,
        _l10n.shortcutContextFilterMenuOpen,
        _l10n.shortcutContextPanelOpen,
        _l10n.shortcutContextAnywhere,
        _l10n.shortcutContextAnywhere,
        _l10n.shortcutContextFilterFocused,
        _l10n.shortcutContextFilterMenuOpen,
      ],
    );
  });

  testWidgets('關閉鈕關閉面板', (tester) async {
    final container = await _pumpOpen(tester);

    // 關閉鈕為固定底部 footer，不需捲動即可點；開啟時焦點落在其上。
    final closeFinder = find.byKey(const Key('action-shortcuts-close'));
    expect(
      tester.getRect(closeFinder).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(Panel)).bottom),
    );
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    expect(
      find.descendant(
        of: closeFinder,
        matching: find.byElementPredicate((e) => e == focusedContext),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('action-shortcuts-close')));
    await tester.pump();

    expect(container.read(shortcutsOpenProvider), isFalse);
    expect(find.byKey(const Key('state-shortcuts-list')), findsNothing);
  });

  testWidgets('Esc 關閉面板', (tester) async {
    final container = await _pumpOpen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(shortcutsOpenProvider), isFalse);
  });
}
