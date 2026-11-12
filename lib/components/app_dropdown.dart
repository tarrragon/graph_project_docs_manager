/// AppDropdown（SPEC-004 §4.45）。
///
/// 表單欄位的列舉值選擇：觸發器 + 覆蓋層選單。不允許樂觀更新：選取只呼叫
/// `onChanged`（值改變時恰一次），觸發器文字只由 `selected` 決定，呼叫端寫入
/// 受理後改傳 `selected` 才變。`selected` 不在 `options` 內（檔案內手寫值）
/// 時觸發器顯示原值（outOfDomain）。頁面層禁直用 `DropdownButton` /
/// `DropdownMenu`（SPEC-004 §6）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 單一選項：`value` 為值域原值（不進 i18n），`label` 為呼叫端傳入的可見文字。
class DropdownOption {
  const DropdownOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// 表單下拉（SPEC-004 §4.45，單一變體 `default`）。
class AppDropdown extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.enabled = true,
    this.locked = false,
    required this.testKey,
  });

  /// 選項，1..10 項（推導上限見 SPEC-004 4.45〈尺寸契約〉）。
  final List<DropdownOption> options;

  /// 目前已落檔值；`null` 為欄位缺值，不在 `options` 內為 outOfDomain。
  final String? selected;

  /// 選取且值改變時呼叫恰一次。
  final ValueChanged<String> onChanged;

  /// 朗讀名（與 FieldBlock label 同一字串）。
  final String semanticLabel;

  /// `false` 時依 disabled 呈現，不可聚焦與展開。
  final bool enabled;

  /// `true` 時外觀同 disabled、已持有的焦點保留、不可展開（寫入進行中）。
  final bool locked;

  /// 觸發器錨點 `action-nodeDetail-field-<fieldKey>`；選單
  /// `menu-nodeDetail-field-<fieldKey>`、選項
  /// `option-nodeDetail-field-<fieldKey>-<value>` 由此推導。
  final Key testKey;

  @override
  State<AppDropdown> createState() => _AppDropdownState();
}

class _AppDropdownState extends State<AppDropdown> {
  /// D1：全 App 同時至多一個選單展開。
  static _AppDropdownState? _openInstance;

  final LayerLink _link = LayerLink();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'AppDropdown.trigger');
  final List<FocusNode> _optionFocus = [];
  OverlayEntry? _entry;
  int _highlight = 0;
  bool _openUp = false;
  double _menuWidth = 0;
  bool _disposing = false;

  bool get _isOpen => _entry != null;
  bool get _interactive => widget.enabled && !widget.locked;

  @override
  void didUpdateWidget(AppDropdown old) {
    super.didUpdateWidget(old);
    if (_isOpen && !_interactive) _closeMenu();
  }

  @override
  void dispose() {
    _disposing = true;
    _closeMenu();
    _triggerFocus.dispose();
    super.dispose();
  }

  int get _selectedIndex =>
      widget.options.indexWhere((o) => o.value == widget.selected);

  String get _fieldKey {
    final k = widget.testKey;
    final raw = k is ValueKey<String> ? k.value : '';
    const prefix = 'action-nodeDetail-field-';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }

  double get _menuHeight =>
      widget.options.length * LayoutSize.hitTargetMin + 2 * Space.xs;

  void _openMenu() {
    if (_isOpen || !_interactive) return;
    _openInstance?._closeMenu();
    _openInstance = this;
    _decideGeometry();
    _highlight = _selectedIndex < 0 ? 0 : _selectedIndex;
    _optionFocus
      ..clear()
      ..addAll([
        for (final _ in widget.options)
          FocusNode(debugLabel: 'AppDropdown.option'),
      ]);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) _optionFocus[_highlight].requestFocus();
    });
  }

  /// D4：預設向下；底緣超出視窗且上方空間較大時向上。
  void _decideGeometry() {
    final box = context.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final below = MediaQuery.sizeOf(context).height - top - box.size.height;
    _menuWidth = box.size.width;
    _openUp = below < _menuHeight && top > below;
  }

  void _closeMenu({bool refocusTrigger = false}) {
    _entry?.remove();
    _entry = null;
    if (identical(_openInstance, this)) _openInstance = null;
    for (final n in _optionFocus) {
      n.dispose();
    }
    _optionFocus.clear();
    if (mounted && !_disposing) setState(() {});
    if (refocusTrigger && !_disposing) _triggerFocus.requestFocus();
  }

  void _toggleMenu() {
    if (!_interactive) return;
    _isOpen ? _closeMenu() : _openMenu();
  }

  void _select(String value) {
    _closeMenu(refocusTrigger: true);
    if (value != widget.selected) widget.onChanged(value);
  }

  void _moveTo(int index) {
    final next = index.clamp(0, widget.options.length - 1);
    _highlight = next;
    _optionFocus[next].requestFocus();
  }

  KeyEventResult _onMenuKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveTo(_highlight + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveTo(_highlight - 1);
    } else if (key == LogicalKeyboardKey.home) {
      _moveTo(0);
    } else if (key == LogicalKeyboardKey.end) {
      _moveTo(widget.options.length - 1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _select(widget.options[_highlight].value);
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab) {
      _closeMenu(refocusTrigger: true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _currentText(AppLocalizations l10n) {
    final i = _selectedIndex;
    if (widget.selected == null) return l10n.fieldEmptyValue;
    return i < 0 ? widget.selected! : widget.options[i].label;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _currentText(l10n);
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        key: widget.testKey,
        button: true,
        label: l10n.dropdownA11yLabel(widget.semanticLabel, text),
        expanded: _isOpen,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _openMenu();
                  return null;
                },
              ),
            },
            child: _trigger(text),
          ),
        ),
      ),
    );
  }

  Widget _trigger(String text) {
    final empty = widget.selected == null;
    return InkWell(
      // locked 時 onTap 仍非 null：InkWell 以 onTap 判定 enabled，null 會
      // 使已持有的焦點被收回（SPEC-004 4.44〈值格鎖定〉要求保留）。
      onTap: widget.enabled ? _toggleMenu : null,
      focusNode: _triggerFocus,
      canRequestFocus:
          widget.enabled && (!widget.locked || _triggerFocus.hasFocus),
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(Radius.md),
      mouseCursor: _interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        height: LayoutSize.hitTargetMin,
        padding: EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(Radius.md),
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: AppText.singleLine(
                  text,
                  tone: !_interactive
                      ? AppTextTone.textDisabled
                      : empty
                      ? AppTextTone.textSecondary
                      : AppTextTone.textPrimary,
                ),
              ),
              SizedBox(width: Space.xs),
              Icon(
                Icons.arrow_drop_down,
                size: LayoutSize.iconMd,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _openUp ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _openUp ? Alignment.bottomLeft : Alignment.topLeft,
          child: SizedBox(width: _menuWidth, child: _menu()),
        ),
      ],
    );
  }

  Widget _menu() {
    return Semantics(
      key: ValueKey('menu-nodeDetail-field-$_fieldKey'),
      role: SemanticsRole.menu,
      child: Focus(
        skipTraversal: true,
        onKeyEvent: _onMenuKey,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(Radius.md),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: Space.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(Radius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.options.length; i++) _option(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(int i) {
    final o = widget.options[i];
    return Semantics(
      key: ValueKey('option-nodeDetail-field-$_fieldKey-${o.value}'),
      role: SemanticsRole.menuItem,
      label: o.label,
      selected: o.value == widget.selected,
      child: Focus(
        focusNode: _optionFocus[i],
        skipTraversal: true,
        child: InkWell(
          onTap: () => _select(o.value),
          excludeFromSemantics: true,
          child: Container(
            constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin),
            padding: EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            alignment: Alignment.centerLeft,
            child: AppText.singleLine(o.label),
          ),
        ),
      ),
    );
  }
}
