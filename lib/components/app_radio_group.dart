/// AppRadioGroup（SPEC-004 §4.47）。
///
/// 表單欄位的分類值單選鈕組：選項恆垂直堆疊，全組一個 Tab 停留點，
/// 上下鍵只移動焦點、Space 才選取（用戶裁定，1.0.0-W3-675）。不允許樂觀更新：
/// 選取只呼叫 `onChanged`，選中標示由呼叫端改傳 `selected` 才移動。內部以
/// Material `Radio` 實作，頁面層禁直用 `Radio` / `RadioListTile`（SPEC-004 §6）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';

/// 單選項：`value` 為欄位值原值，`label` 為呼叫端傳入的可見文字。
class RadioOption {
  const RadioOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// 單選鈕組（SPEC-004 §4.47，單一變體 `default`）。
class AppRadioGroup extends StatefulWidget {
  const AppRadioGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.enabled = true,
    this.locked = false,
    required this.testKey,
  });

  /// 選項，2..N 項。
  final List<RadioOption> options;

  /// 目前已落檔值；`null` 或不在 `options` 內時全部選項未選。
  final String? selected;

  /// 選取非選中項時呼叫恰一次。
  final ValueChanged<String> onChanged;

  /// 群組朗讀名（與 FieldBlock label 同一字串）。
  final String semanticLabel;

  /// `false` 時依 disabled 呈現，不可聚焦與選取。
  final bool enabled;

  /// `true` 時外觀同 disabled、已持有的焦點保留、不可選取（寫入進行中）。
  final bool locked;

  /// 欄位根錨點 `card-nodeDetail-field-<fieldKey>`；選項錨點由此推導為
  /// `option-nodeDetail-field-<fieldKey>-<value>`。群組根不另設錨點。
  final Key testKey;

  @override
  State<AppRadioGroup> createState() => _AppRadioGroupState();
}

class _AppRadioGroupState extends State<AppRadioGroup> {
  late List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    assert(widget.options.length >= 2, '互斥選擇至少兩個選項（SPEC-004 4.47 下限 2）');
    _nodes = _makeNodes(widget.options.length);
  }

  static List<FocusNode> _makeNodes(int n) => [
    for (var i = 0; i < n; i++) FocusNode(debugLabel: 'AppRadioGroup.option$i'),
  ];

  @override
  void didUpdateWidget(AppRadioGroup old) {
    super.didUpdateWidget(old);
    if (old.options.length != widget.options.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = _makeNodes(widget.options.length);
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _interactive => widget.enabled && !widget.locked;

  int get _selectedIndex =>
      widget.options.indexWhere((o) => o.value == widget.selected);

  int get _tabIndex => _selectedIndex < 0 ? 0 : _selectedIndex;

  String _anchor(String value) {
    final base = widget.testKey is ValueKey<String>
        ? (widget.testKey as ValueKey<String>).value
        : '';
    final field = base.startsWith('card-') ? base.substring(5) : base;
    return 'option-$field-$value';
  }

  void _select(int index) {
    if (!_interactive) return;
    final value = widget.options[index].value;
    if (value != widget.selected) widget.onChanged(value);
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (!_interactive || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _select(index);
      return KeyEventResult.handled;
    }
    final step = key == LogicalKeyboardKey.arrowDown
        ? 1
        : key == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (step == 0) return KeyEventResult.ignored;
    final next = index + step;
    if (next >= 0 && next < _nodes.length) _nodes[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final inDomain = _selectedIndex >= 0;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: RadioGroup<String>(
        groupValue: inDomain ? widget.selected : null,
        onChanged: (_) {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.options.length; i++) ...[
              if (i > 0) SizedBox(height: Space.xxs),
              _option(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option(int i) {
    final o = widget.options[i];
    final checked = o.value == widget.selected;
    final node = _nodes[i];
    return Focus(
      focusNode: node,
      skipTraversal: i != _tabIndex,
      canRequestFocus: widget.enabled && (!widget.locked || node.hasFocus),
      onKeyEvent: (_, e) => _onKey(i, e),
      child: Semantics(
        key: ValueKey(_anchor(o.value)),
        container: true,
        inMutuallyExclusiveGroup: true,
        checked: checked,
        label: o.label,
        child: InkWell(
          onTap: _interactive ? () => _select(i) : null,
          focusNode: null,
          canRequestFocus: false,
          excludeFromSemantics: true,
          mouseCursor: _interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin),
            child: _row(o, checked),
          ),
        ),
      ),
    );
  }

  Widget _row(RadioOption o, bool checked) {
    final dim = !_interactive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xs),
      child: ExcludeSemantics(
        child: Row(
          children: [
            _radio(o.value, dim),
            SizedBox(width: Space.xs),
            Expanded(child: _label(o.label, dim)),
          ],
        ),
      ),
    );
  }

  Widget _radio(String value, bool dim) {
    return SizedBox(
      width: LayoutSize.iconLg,
      height: LayoutSize.iconLg,
      child: ExcludeFocus(
        child: IgnorePointer(
          child: Radio<String>(
            value: value,
            activeColor: dim ? AppColors.textDisabled : AppColors.accent,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (dim) return AppColors.textDisabled;
              return states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.textSecondary;
            }),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool dim) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.body,
        color: dim ? AppColors.textDisabled : AppColors.textPrimary,
      ),
    );
  }
}
