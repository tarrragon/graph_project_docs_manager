/// 鍵盤快捷鍵面板（SPEC-003 §3.10、SPEC-001 §11）。
///
/// 主視窗內的面板（不是獨立視窗）：由側欄底部「鍵盤快捷鍵」開啟，內容為
/// 建構時決定的靜態十列清單（按鍵字面為資料值，不進 i18n），Esc 或關閉鈕
/// 關閉；開啟時焦點落在關閉鈕。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../l10n/app_localizations.dart';
import '../../state/state_holder.dart';
import '../../tokens/tokens.dart';

/// 面板開合；`true` 時由組裝根掛載 [ShortcutsPanel]。
final shortcutsOpenProvider = stateHolderProvider<bool>((ref) => false);

/// 清單列（SPEC-001 §11〈清單內容〉）：按鍵字面與其作用、情境的文案取值。
typedef _Entry = ({
  String keys,
  String Function(AppLocalizations) action,
  String Function(AppLocalizations) context,
});

/// 依 SPEC-001 §11〈清單內容〉列序。
final List<_Entry> _entries = [
  (
    keys: '⌘,',
    action: (l) => l.shortcutOpenPreferencesAction,
    context: (l) => l.shortcutContextAnywhere,
  ),
  (
    keys: 'Esc',
    action: (l) => l.shortcutCloseSwitcherAction,
    context: (l) => l.shortcutContextSwitcherOpen,
  ),
  (
    keys: 'Esc',
    action: (l) => l.shortcutCloseSchemaDetailAction,
    context: (l) => l.shortcutContextSchemaDetailOpen,
  ),
  (
    keys: 'Esc',
    action: (l) => l.shortcutClearCellAction,
    context: (l) => l.shortcutContextCellSelected,
  ),
  (
    keys: 'Esc',
    action: (l) => l.shortcutCloseFilterMenuAction,
    context: (l) => l.shortcutContextFilterMenuOpen,
  ),
  (
    keys: 'Esc',
    action: (l) => l.shortcutClosePanelAction,
    context: (l) => l.shortcutContextPanelOpen,
  ),
  (
    keys: 'Tab／Shift+Tab',
    action: (l) => l.shortcutMoveFocusAction,
    context: (l) => l.shortcutContextAnywhere,
  ),
  (
    keys: 'Enter／Space',
    action: (l) => l.shortcutActivateAction,
    context: (l) => l.shortcutContextAnywhere,
  ),
  (
    keys: '↓',
    action: (l) => l.shortcutOpenFilterMenuAction,
    context: (l) => l.shortcutContextFilterFocused,
  ),
  (
    keys: '↑／↓／Home／End',
    action: (l) => l.shortcutMoveInFilterMenuAction,
    context: (l) => l.shortcutContextFilterMenuOpen,
  ),
];

class ShortcutsPanel extends ConsumerWidget {
  const ShortcutsPanel({super.key});

  void _close(WidgetRef ref) {
    ref.read(shortcutsOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _close(ref),
      },
      child: FocusScope(
        autofocus: true,
        child: SizedBox(
          width: LayoutSize.overlayWidth * 2,
          height: LayoutSize.overlayWidth * 2,
          child: Panel.scrollable(
            key: const Key('state-shortcuts-list'),
            scrollKey: const Key('scroll-shortcuts-list'),
            footer: AppButton(
              label: l10n.cellDetailCloseAction,
              onPressed: () => _close(ref),
              variant: AppButtonVariant.text,
              autofocus: true,
              testKey: const Key('action-shortcuts-close'),
            ),
            children: [
              AppText.singleLine(
                l10n.keyboardShortcutsTitle,
                variant: AppTextVariant.subtitle,
              ),
              for (final entry in _entries)
                ListRow.shortcut(
                  keys: entry.keys,
                  action: entry.action(l10n),
                  contextLabel: entry.context(l10n),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
