/// AppTextInput（SPEC-004 §4.44）。
///
/// 表單欄位的自由文字值輸入，兩變體：`singleLine`（Enter 提交）與
/// `multiLine`（3–8 行可見，⌘Enter 提交）。受控值（已落檔值），草稿為元件
/// 內部狀態：失焦保留、不提交；Esc 還原；提交呼叫 [onSubmitted] 恰一次。
/// 內部以 Material `TextField` 實作，頁面層禁直用 `TextField`（SPEC-004 §6）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 文字輸入元件（SPEC-004 §4.44）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [value] | 是 | 已落檔值，缺值傳空字串 |
/// | [onSubmitted] | 是 | 提交鍵呼叫，傳原草稿（trim 後為空亦呼叫） |
/// | [semanticLabel] | 是 | 朗讀 label |
/// | [enabled] | 否 | false：外部已改阻擋，失去焦點、不進 Tab 順序 |
/// | [locked] | 否 | true：寫入進行中，外觀同 disabled、保留焦點、不可輸入 |
/// | [hasError] | 否 | 框色 error |
/// | [onDirtyChanged] | 否 | 草稿與 [value] 是否不同的轉換通知 |
/// | [testKey] | 是 | `action-nodeDetail-field-<fieldKey>` |
class AppTextInput extends StatefulWidget {
  const AppTextInput.singleLine({
    super.key,
    required this.value,
    required this.onSubmitted,
    required this.semanticLabel,
    required this.testKey,
    this.enabled = true,
    this.locked = false,
    this.hasError = false,
    this.onDirtyChanged,
  }) : multiLine = false;

  const AppTextInput.multiLine({
    super.key,
    required this.value,
    required this.onSubmitted,
    required this.semanticLabel,
    required this.testKey,
    this.enabled = true,
    this.locked = false,
    this.hasError = false,
    this.onDirtyChanged,
  }) : multiLine = true;

  /// 已落檔值（受控）。
  final String value;

  /// 提交時呼叫，帶原草稿。
  final ValueChanged<String> onSubmitted;

  /// 朗讀 label。
  final String semanticLabel;

  /// 是否可用；false 時為 disabled。
  final bool enabled;

  /// 寫入進行中鎖定。
  final bool locked;

  /// 最近一次寫入失敗。
  final bool hasError;

  /// 草稿是否與 [value] 不同的轉換通知。
  final ValueChanged<bool>? onDirtyChanged;

  /// 定址 key。
  final Key testKey;

  /// 是否為多行變體。
  final bool multiLine;

  @override
  State<AppTextInput> createState() => _AppTextInputState();
}

class _AppTextInputState extends State<AppTextInput> {
  static const int _minLines = 3;
  static const int _maxLines = 8;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasFocus = false;
  bool _lastDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value)
      ..addListener(_handleTextChanged);
    _focusNode = FocusNode(debugLabel: 'AppTextInput')
      ..addListener(() => setState(() => _hasFocus = _focusNode.hasFocus));
  }

  @override
  void didUpdateWidget(covariant AppTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 未有草稿時跟隨新值；有草稿則保留（SPEC-004 4.44 狀態變更提示）。
    if (_controller.text == oldWidget.value &&
        widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
    _reportDirty();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isDirty => _controller.text != widget.value;

  void _handleTextChanged() {
    setState(() {});
    _reportDirty();
  }

  void _reportDirty() {
    final dirty = _isDirty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  bool get _isComposing {
    final composing = _controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  void _submit() {
    if (widget.locked || !widget.enabled || _isComposing || !_isDirty) return;
    widget.onSubmitted(_controller.text);
  }

  void _revert() {
    if (widget.locked || !widget.enabled) return;
    _controller.text = widget.value;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _revert();
      return KeyEventResult.handled;
    }
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (!widget.multiLine || HardwareKeyboard.instance.isMetaPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color get _borderColor {
    if (widget.hasError) return AppColors.error;
    final inactive = widget.locked || !widget.enabled;
    return (_hasFocus && !inactive) ? AppColors.accent : AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inactive = widget.locked || !widget.enabled;
    _focusNode.skipTraversal = widget.locked;
    final field = _buildField(l10n.fieldEmptyValue, inactive);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(Radius.md),
      ),
      child: widget.multiLine
          ? field
          : Align(alignment: Alignment.centerLeft, child: field),
    );
    return Semantics(
      key: widget.testKey,
      container: true,
      textField: true,
      multiline: widget.multiLine,
      label: widget.semanticLabel,
      value: _controller.text,
      child: ExcludeSemantics(
        child: widget.multiLine
            ? box
            : SizedBox(
                height: LayoutSize.hitTargetMin,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: inactive ? null : _focusNode.requestFocus,
                  child: box,
                ),
              ),
      ),
    );
  }

  Widget _buildField(String placeholder, bool inactive) {
    final textColor = inactive ? AppColors.textDisabled : AppColors.textPrimary;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        readOnly: widget.locked,
        showCursor: !widget.locked,
        keyboardType: widget.multiLine
            ? TextInputType.multiline
            : TextInputType.text,
        minLines: widget.multiLine ? _minLines : 1,
        maxLines: widget.multiLine ? _maxLines : 1,
        style: TextStyle(
          fontSize: AppFontSize.body,
          height: 1,
          color: textColor,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xs,
          ),
          hintText: placeholder,
          hintMaxLines: 1,
          hintStyle: TextStyle(
            fontSize: AppFontSize.body,
            height: 1,
            color: AppColors.textSecondary,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
