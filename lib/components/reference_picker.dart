/// ReferencePicker（SPEC-004 §4.46）。
///
/// 表單欄位的單一引用選擇：觸發器 + 覆蓋層（過濾輸入框 + 可捲動選項清單）。
/// 不允許樂觀更新：選取只呼叫 `onChanged`（值改變時恰一次），觸發器文字只由
/// `selected` 決定。`selected` 不在 `options` 內（檔案內手寫值）時觸發器顯示
/// 原值（outOfDomain）。頁面層禁直用 `DropdownMenu`、`Autocomplete`
/// （SPEC-004 §6）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 單一選項：`value` 為值域原值（不進 i18n），`label` 為呼叫端傳入的可見文字。
class ReferenceOption {
  const ReferenceOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// 覆蓋層清單區最多同時可見的列數，超過時垂直捲動（SPEC-004 4.46 尺寸契約）。
const int _maxVisibleRows = 8;

/// `allowEmpty` 首項的錨點後綴（資料值不會是此字串）。
const String _emptyEntrySuffix = '__empty__';

/// 可搜尋的引用下拉（SPEC-004 §4.46，單一變體 `default`）。
class ReferencePicker extends StatefulWidget {
  const ReferencePicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.allowEmpty = false,
    this.enabled = true,
    this.locked = false,
    required this.testKey,
  });

  /// 選項，0..N（無上限）；清單過長時垂直捲動。
  final List<ReferenceOption> options;

  /// 目前已落檔值；`null` 為欄位缺值，不在 `options` 內為 outOfDomain。
  final String? selected;

  /// 選取且值改變時呼叫恰一次；選首項（`allowEmpty`）時傳 `null`。
  final ValueChanged<String?> onChanged;

  /// 朗讀名（與 FieldBlock label 同一字串）。
  final String semanticLabel;

  /// 選單首項為 `fieldEmptyValue`，選取時 `onChanged(null)`；不參與過濾。
  final bool allowEmpty;

  /// `false` 時依 disabled 呈現，不可聚焦與展開。
  final bool enabled;

  /// `true` 時外觀同 disabled、已持有的焦點保留、不可展開（寫入進行中）。
  final bool locked;

  /// 觸發器錨點 `action-nodeDetail-field-<fieldKey>`；過濾框
  /// `...-filter`、選單 `menu-nodeDetail-field-<fieldKey>`、選項
  /// `option-nodeDetail-field-<fieldKey>-<value>` 由此推導。
  final Key testKey;

  @override
  State<ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<ReferencePicker>
    with TickerProviderStateMixin {
  /// 全 App 同時至多一個選單展開。
  static _ReferencePickerState? _openInstance;

  final LayerLink _link = LayerLink();
  final FocusNode _triggerFocus = FocusNode(
    debugLabel: 'ReferencePicker.trigger',
  );
  final List<VoidCallback> _pendingTeardowns = [];
  AnimationController? _ctrl;
  OverlayEntry? _entry;
  TextEditingController? _filter;
  FocusNode? _filterFocus;
  ScrollController? _scroll;
  String _query = '';
  int _highlight = 0;
  bool _openUp = false;
  double _menuWidth = 0;
  double _menuMaxHeight = 0;
  bool _disposing = false;

  bool get _isOpen => _entry != null;
  bool get _interactive => widget.enabled && !widget.locked;

  @override
  void didUpdateWidget(ReferencePicker old) {
    super.didUpdateWidget(old);
    if (_isOpen && !_interactive) _closeMenu();
  }

  @override
  void dispose() {
    _disposing = true;
    _closeMenu();
    for (final t in List.of(_pendingTeardowns)) {
      t();
    }
    _triggerFocus.dispose();
    super.dispose();
  }

  String get _fieldKey {
    final k = widget.testKey;
    final raw = k is ValueKey<String> ? k.value : '';
    const prefix = 'action-nodeDetail-field-';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }

  /// 過濾：對 value 與 label 做不分大小寫子字串比對，保持原序。
  List<ReferenceOption> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.value.toLowerCase().contains(q) ||
            o.label.toLowerCase().contains(q))
          o,
    ];
  }

  int get _emptyRows => widget.allowEmpty ? 1 : 0;

  /// 高亮可走的項目數（首項 + 過濾後選項）。
  int get _entryCount => _emptyRows + _filtered.length;

  void _openMenu() {
    if (_isOpen || !_interactive) return;
    _openInstance?._closeMenu();
    _openInstance = this;
    _query = '';
    _decideGeometry();
    final idx = widget.options.indexWhere((o) => o.value == widget.selected);
    _highlight = idx < 0 ? 0 : idx + _emptyRows;
    _filter = TextEditingController()..addListener(_onFilterChanged);
    _filterFocus = FocusNode(
      debugLabel: 'ReferencePicker.filter',
      onKeyEvent: _onFilterKey,
    );
    _scroll = ScrollController();
    final ctrl = AnimationController(
      vsync: this,
      duration: Motion.overlay(context),
    );
    _ctrl = ctrl;
    _entry = OverlayEntry(builder: (c) => _overlayBody(ctrl));
    Overlay.of(context).insert(_entry!);
    ctrl.forward();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterOpen());
  }

  void _afterOpen() {
    if (!mounted || !_isOpen) return;
    _filterFocus?.requestFocus();
    _scrollToHighlight(jumpToTop: true);
  }

  /// 預設向下；選較大的一側，可用高不足時清單區縮至可用高（捲動）。
  void _decideGeometry() {
    final box = context.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final below = MediaQuery.sizeOf(context).height - top - box.size.height;
    _menuWidth = box.size.width;
    final full = _fullMenuHeight;
    _openUp = below < full && top > below;
    _menuMaxHeight = full < (_openUp ? top : below)
        ? full
        : (_openUp ? top : below);
  }

  double get _fullMenuHeight {
    final rows = widget.options.length + _emptyRows;
    final visible = (rows < 1 ? 1 : rows) < _maxVisibleRows
        ? (rows < 1 ? 1 : rows)
        : _maxVisibleRows;
    return 3 * Space.xs + LayoutSize.hitTargetMin * (1 + visible);
  }

  void _onFilterChanged() {
    final c = _filter;
    if (c == null) return;
    final composing = c.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    if (c.text == _query) return;
    _query = c.text;
    _highlight = _emptyRows < _entryCount ? _emptyRows : 0;
    _entry?.markNeedsBuild();
  }

  void _closeMenu({bool refocusTrigger = false}) {
    final entry = _entry;
    final ctrl = _ctrl;
    final filter = _filter;
    final filterFocus = _filterFocus;
    final scroll = _scroll;
    _entry = null;
    _ctrl = null;
    _filter = null;
    _filterFocus = null;
    _scroll = null;
    _query = '';
    if (identical(_openInstance, this)) _openInstance = null;
    var done = false;
    void teardown() {
      if (done) return;
      done = true;
      _pendingTeardowns.remove(teardown);
      entry?.remove();
      ctrl?.dispose();
      filter?.dispose();
      filterFocus?.dispose();
      scroll?.dispose();
    }

    if (_disposing || ctrl == null || ctrl.duration == Duration.zero) {
      teardown();
    } else {
      _pendingTeardowns.add(teardown);
      ctrl.reverse().whenComplete(teardown);
    }
    if (mounted && !_disposing) setState(() {});
    if (refocusTrigger && !_disposing) _triggerFocus.requestFocus();
  }

  void _toggleMenu() {
    if (!_interactive) return;
    _isOpen ? _closeMenu() : _openMenu();
  }

  void _select(String? value) {
    _closeMenu(refocusTrigger: true);
    if (value != widget.selected) widget.onChanged(value);
  }

  void _commitHighlight() {
    if (_entryCount == 0) return;
    if (widget.allowEmpty && _highlight == 0) return _select(null);
    _select(_filtered[_highlight - _emptyRows].value);
  }

  void _moveTo(int index) {
    if (_entryCount == 0) return;
    _highlight = index.clamp(0, _entryCount - 1);
    _entry?.markNeedsBuild();
    _scrollToHighlight();
  }

  void _scrollToHighlight({bool jumpToTop = false}) {
    final c = _scroll;
    if (c == null || !c.hasClients) return;
    final row = _highlight - _emptyRows;
    if (row < 0) return;
    final h = LayoutSize.hitTargetMin;
    final target = row * h;
    final view = c.position.viewportDimension;
    final max = c.position.maxScrollExtent;
    if (jumpToTop) return c.jumpTo(target.clamp(0, max));
    if (target < c.offset) {
      c.jumpTo(target.clamp(0, max));
    } else if (target + h > c.offset + view) {
      c.jumpTo((target + h - view).clamp(0, max));
    }
  }

  KeyEventResult _onFilterKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveTo(_highlight + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveTo(_highlight - 1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _commitHighlight();
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab) {
      _closeMenu(refocusTrigger: true);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _currentText(AppLocalizations l10n) {
    final sel = widget.selected;
    if (sel == null) return l10n.fieldEmptyValue;
    final i = widget.options.indexWhere((o) => o.value == sel);
    return i < 0 ? sel : widget.options[i].label;
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

  Widget _overlayBody(AnimationController ctrl) {
    return FadeTransition(
      opacity: ctrl,
      child: Stack(
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
      ),
    );
  }

  Widget _menu() {
    return Semantics(
      key: ValueKey('menu-nodeDetail-field-$_fieldKey'),
      role: SemanticsRole.menu,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(Radius.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _menuMaxHeight),
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
                _filterField(),
                SizedBox(height: Space.xs),
                if (widget.allowEmpty) _emptyEntry(),
                Flexible(child: _list()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterField() {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: LayoutSize.hitTargetMin,
      child: Semantics(
        textField: true,
        label: l10n.searchPlaceholder,
        excludeSemantics: true,
        child: TextField(
          key: ValueKey('action-nodeDetail-field-$_fieldKey-filter'),
          controller: _filter,
          focusNode: _filterFocus,
          mouseCursor: SystemMouseCursors.text,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppFontSize.body,
            height: 1,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            hintText: l10n.searchPlaceholder,
            hintMaxLines: 1,
            hintStyle: TextStyle(
              fontSize: AppFontSize.body,
              height: 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyEntry() {
    final l10n = AppLocalizations.of(context);
    return _row(
      key: ValueKey('option-nodeDetail-field-$_fieldKey-$_emptyEntrySuffix'),
      label: l10n.fieldEmptyValue,
      selected: widget.selected == null,
      active: _highlight == 0,
      tone: AppTextTone.textSecondary,
      onTap: () => _select(null),
    );
  }

  Widget _list() {
    final items = _filtered;
    if (items.isEmpty) return _noMatch();
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemExtent: LayoutSize.hitTargetMin,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final o = items[i];
        return _row(
          key: ValueKey('option-nodeDetail-field-$_fieldKey-${o.value}'),
          label: o.label,
          selected: o.value == widget.selected,
          active: _highlight == i + _emptyRows,
          onTap: () => _select(o.value),
        );
      },
    );
  }

  Widget _noMatch() {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      label: l10n.referencePickerNoMatch,
      excludeSemantics: true,
      child: Container(
        height: LayoutSize.hitTargetMin,
        padding: EdgeInsets.symmetric(horizontal: Space.sm),
        alignment: Alignment.centerLeft,
        child: AppText.singleLine(
          l10n.referencePickerNoMatch,
          tone: AppTextTone.textSecondary,
        ),
      ),
    );
  }

  Widget _row({
    required Key key,
    required String label,
    required bool selected,
    required bool active,
    required VoidCallback onTap,
    AppTextTone tone = AppTextTone.textPrimary,
  }) {
    return Semantics(
      key: key,
      role: SemanticsRole.menuItem,
      label: label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Container(
          height: LayoutSize.hitTargetMin,
          padding: EdgeInsets.symmetric(horizontal: Space.sm),
          alignment: Alignment.centerLeft,
          color: active ? AppColors.surfaceIconTint : null,
          child: AppText.singleLine(label, tone: tone),
        ),
      ),
    );
  }
}
