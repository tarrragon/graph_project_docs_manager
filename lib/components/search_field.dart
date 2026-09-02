/// 搜尋輸入框（SPEC-004 §4.12）。
///
/// Ticket 清單工具列搜尋（`input-tickets-search`）。受控輸入：值由呼叫端
/// 狀態（provider）持有，本元件輸入停止 [Motion.searchDebounce] 後呼叫
/// [onChanged] 一次（防抖動），清除（清除鈕或刪至空）立即呼叫，不等待
/// 防抖動（SPEC-004 4.12 互動反應）。IME 組字中（`TextEditingValue.composing`
/// 非空）不觸發 [onChanged]。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 搜尋輸入框（SPEC-004 §4.12）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [value] | 是（受控） | 呼叫端狀態持有的目前值 |
/// | [onChanged] | 是 | 防抖動後（或清除時立即）呼叫一次 |
/// | [placeholder] | 否 | 預設 [AppLocalizations.searchPlaceholder]（強語意預設） |
/// | [testKey] | 是（`input-tickets-search`） | 呼叫端依 slot 契約提供的定址 key |
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.testKey,
    this.placeholder,
  });

  /// 呼叫端狀態持有的目前值（受控）。
  final String value;

  /// 防抖動後（或清除時立即）呼叫一次；清空傳入空字串。
  final ValueChanged<String> onChanged;

  /// 呼叫端定址 key（SPEC-004 4.12 slot 契約）。
  final Key testKey;

  /// placeholder 覆寫；`null` 時取元件預設 `searchPlaceholder`。
  final String? placeholder;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounceTimer;
  bool _hasFocus = false;

  /// 上一次視為「文字實際變更」的值，供 [_handleTextChanged] 分辨真正的
  /// 文字變更與純選取／焦點觸發的同步更新（後者 `text` 不變但仍會通知
  /// listener，例如取得焦點時平台送回的初始 editing state）。
  late String _lastKnownText;

  @override
  void initState() {
    super.initState();
    _lastKnownText = widget.value;
    _controller = TextEditingController(text: widget.value)
      ..addListener(_handleTextChanged);
    _focusNode = FocusNode(debugLabel: 'SearchField')
      ..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _lastKnownText = widget.value;
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  /// 值改變後排程防抖動；清空（清除鈕或刪至空）立即觸發，不排程。
  /// 組字中（[TextEditingValue.composing] 為非塌陷範圍）不觸發任何呼叫
  /// （SPEC-004 4.12 互動反應「IME 組字中」）。純選取或焦點變更（`text`
  /// 未變）不視為文字變更，不觸發 [SearchField.onChanged]（見 [_lastKnownText]）。
  void _handleTextChanged() {
    setState(() {}); // 更新清除鈕顯示與 Semantics.value

    final text = _controller.text;
    if (text == _lastKnownText) return;

    final composing = _controller.value.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    if (isComposing) return;

    _lastKnownText = text;
    _debounceTimer?.cancel();
    if (text.isEmpty) {
      widget.onChanged('');
      return;
    }
    _debounceTimer = Timer(Motion.searchDebounce, () {
      widget.onChanged(text);
    });
  }

  void _handleClear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeholderText = widget.placeholder ?? l10n.searchPlaceholder;
    final isFilled = _controller.text.isNotEmpty;

    return SizedBox(
      key: widget.testKey,
      height: LayoutSize.hitTargetMin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _hasFocus ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(Radius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: Space.sm),
            const ExcludeSemantics(
              child: Icon(
                Icons.search,
                size: LayoutSize.iconMd,
                color: AppColors.textDisabled,
              ),
            ),
            SizedBox(width: Space.sm),
            Expanded(
              child: Semantics(
                textField: true,
                label: placeholderText,
                value: _controller.text,
                child: ExcludeSemantics(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: AppFontSize.body,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: placeholderText,
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(
                        fontSize: AppFontSize.body,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isFilled)
              SizedBox(
                width: LayoutSize.hitTargetMin,
                height: LayoutSize.hitTargetMin,
                child: Semantics(
                  button: true,
                  label: l10n.searchClearAction,
                  child: InkWell(
                    onTap: _handleClear,
                    excludeFromSemantics: true,
                    child: Icon(
                      Icons.clear,
                      size: LayoutSize.iconSm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
            else
              SizedBox(width: Space.sm),
          ],
        ),
      ),
    );
  }
}
