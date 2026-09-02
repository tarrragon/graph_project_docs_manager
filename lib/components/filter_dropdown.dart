/// 篩選下拉觸發器（SPEC-004 §4.13）。
///
/// 「狀態：pending」「優先：全部」類的篩選觸發器（`action-tickets-filter-<key>`）。
/// 開合、鍵盤走選項、播報等互動反應原標「待決」，已於 SPEC-003 §3.4 篩選
/// 七列與 F1–F7 元件級契約補齊（2026-09-02），本檔依該內容實作（SPEC-004
/// 4.13 本文的「待決」標記去標屬後續 DOC 票範圍，不影響本實作依循的行為
/// 來源）。
///
/// 選單以覆蓋層呈現：頂緣貼觸發器底緣、左緣貼觸發器左緣，全數選項展開、
/// 選單內不捲動（SPEC-003 F4）。展開／走選項／收合皆不呼叫 [onChanged]，
/// 唯一呼叫點是「選取且值與目前 [selected] 不同」（F5）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 單一篩選選項（不含「全部」，該項由元件自動前置）。
class FilterOption {
  const FilterOption({required this.value, required this.label});

  /// 選項值，呼叫端資料值域約束：不得為 `'all'`（SPEC-003 F3）。
  final String value;

  /// 選單內顯示文字。
  final String label;
}

/// 篩選下拉觸發器（SPEC-004 4.13）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [label] | 是 | 呼叫端傳入（`filterStatusLabel` / `filterPriorityLabel`） |
/// | [options] | 是（不含「全部」） | 選單項，元件自動前置「全部」 |
/// | [allOptionLabel] | 否 | 預設 `l10n.filterAllOption`（強語意預設） |
/// | [selected] | 是 | `null` = 全部 |
/// | [onChanged] | 是 | 選取且值改變時呼叫恰一次；選「全部」傳 `null` |
/// | [testKey] | 是（`action-tickets-filter-<key>`） | 觸發器定址 key |
class FilterDropdown extends StatefulWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.testKey,
    this.allOptionLabel,
  });

  /// 篩選名稱（如「狀態」「優先」）。
  final String label;

  /// 選單項，不含「全部」。
  final List<FilterOption> options;

  /// 目前選取值；`null` 表示「全部」。
  final String? selected;

  /// 選取且值改變時呼叫恰一次；選「全部」傳 `null`（F5）。
  final ValueChanged<String?> onChanged;

  /// 呼叫端定址 key（SPEC-004 4.13 slot 契約）。
  final Key testKey;

  /// 「全部」文字覆寫；`null` 時取 [AppLocalizations.filterAllOption]。
  final String? allOptionLabel;

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _triggerFocusNode = FocusNode(debugLabel: 'FilterDropdown');
  final List<FocusNode> _optionFocusNodes = [];

  OverlayEntry? _overlayEntry;
  bool get _isOpen => _overlayEntry != null;

  /// 走選項的目前高亮索引（含「全部」為索引 0）。
  int _highlightedIndex = 0;

  bool _triggerHasFocus = false;

  /// dispose 進行中旗標：unmount 過程呼叫 [State.setState] 會拋出斷言
  /// （元件已在 defunct 化路徑上），[_closeMenu] 依此旗標略過重建，只做
  /// 資源清理（overlay 移除、FocusNode dispose）。
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _triggerFocusNode.addListener(_handleTriggerFocusChange);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _closeMenu();
    _triggerFocusNode
      ..removeListener(_handleTriggerFocusChange)
      ..dispose();
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleTriggerFocusChange() {
    setState(() => _triggerHasFocus = _triggerFocusNode.hasFocus);
  }

  int get _selectedIndex {
    if (widget.selected == null) return 0;
    final index = widget.options.indexWhere(
      (option) => option.value == widget.selected,
    );
    return index < 0 ? 0 : index + 1;
  }

  void _openMenu() {
    if (_isOpen) return;
    _highlightedIndex = _selectedIndex;
    _optionFocusNodes
      ..clear()
      ..addAll(
        List.generate(
          widget.options.length + 1,
          (_) => FocusNode(debugLabel: 'FilterDropdownOption'),
        ),
      );
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOpen) {
        _optionFocusNodes[_highlightedIndex].requestFocus();
      }
    });
  }

  void _closeMenu({bool refocusTrigger = false}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    _optionFocusNodes.clear();
    if (mounted && !_isDisposing) setState(() {});
    if (refocusTrigger) {
      _triggerFocusNode.requestFocus();
    }
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu(refocusTrigger: true);
    } else {
      _openMenu();
    }
  }

  void _select(String? value) {
    _closeMenu(refocusTrigger: true);
    if (value != widget.selected) {
      widget.onChanged(value);
    }
  }

  void _moveHighlight(int delta) {
    final last = widget.options.length;
    final next = (_highlightedIndex + delta).clamp(0, last);
    if (next == _highlightedIndex) return;
    _highlightedIndex = next;
    _optionFocusNodes[_highlightedIndex].requestFocus();
  }

  void _moveHighlightTo(int index) {
    _highlightedIndex = index;
    _optionFocusNodes[_highlightedIndex].requestFocus();
  }

  KeyEventResult _handleMenuKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _moveHighlight(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveHighlight(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _moveHighlightTo(0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _moveHighlightTo(widget.options.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _closeMenu(refocusTrigger: true);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  /// 觸發器固定寬：取「全部」與各選項文字（含 `label：` 前綴）的最寬者，
  /// 加圖示與內距，並以可用寬度為上限（避免超長測試文案撐破版面，尺寸
  /// 契約「選取不同值時寬不變」；最長文案由 [AppText] 的單行截斷承接）。
  double _resolveTriggerWidth(
    BuildContext context,
    AppLocalizations l10n,
    double maxAvailable,
  ) {
    final allLabel = widget.allOptionLabel ?? l10n.filterAllOption;
    final candidates = [
      allLabel,
      ...widget.options.map((option) => option.label),
    ];
    final directionality = Directionality.of(context);
    var widestTextWidth = 0.0;
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${widget.label}：$candidate',
          style: TextStyle(fontSize: AppFontSize.body.sp),
        ),
        textDirection: directionality,
        maxLines: 1,
      )..layout();
      if (painter.width > widestTextWidth) widestTextWidth = painter.width;
    }

    final chrome = Space.sm * 2 + Space.xs + LayoutSize.iconMd; // 內距＋圖示間距＋圖示
    final desired = widestTextWidth + chrome;
    final minWidth = LayoutSize.hitTargetMin * 2;
    final upperBound = maxAvailable.isFinite ? maxAvailable : desired;
    return desired.clamp(minWidth, math.max(minWidth, upperBound));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLabel = widget.selected == null
        ? (widget.allOptionLabel ?? l10n.filterAllOption)
        : widget.options
              .firstWhere((option) => option.value == widget.selected)
              .label;
    final isActive = widget.selected != null;

    final borderColor = isActive
        ? AppColors.accent
        : (_triggerHasFocus ? AppColors.accent : AppColors.border);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        key: widget.testKey,
        button: true,
        label: l10n.filterA11yLabel(widget.label, currentLabel),
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
                  if (!_isOpen) _openMenu();
                  return null;
                },
              ),
            },
            child: InkWell(
              onTap: _toggleMenu,
              focusNode: _triggerFocusNode,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(Radius.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = _resolveTriggerWidth(
                    context,
                    l10n,
                    constraints.maxWidth,
                  );
                  return Container(
                    width: width,
                    height: LayoutSize.hitTargetMin,
                    padding: EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: Space.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(Radius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AppText(
                            '${widget.label}：$currentLabel',
                            variant: AppTextVariant.body,
                          ),
                        ),
                        SizedBox(width: Space.xs),
                        ExcludeSemantics(
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: LayoutSize.iconMd,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allLabel = widget.allOptionLabel ?? l10n.filterAllOption;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _closeMenu(refocusTrigger: false),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Semantics(
            role: SemanticsRole.menu,
            child: Focus(
              autofocus: false,
              skipTraversal: true,
              onKeyEvent: _handleMenuKeyEvent,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(Radius.md),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(Radius.md),
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOption(index: 0, value: null, label: allLabel),
                        for (var i = 0; i < widget.options.length; i++)
                          _buildOption(
                            index: i + 1,
                            value: widget.options[i].value,
                            label: widget.options[i].label,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required int index,
    required String? value,
    required String label,
  }) {
    final isSelected = value == widget.selected;

    return Semantics(
      role: SemanticsRole.menuItem,
      label: label,
      selected: isSelected,
      child: Focus(
        focusNode: _optionFocusNodes[index],
        skipTraversal: true,
        child: InkWell(
          onTap: () => _select(value),
          excludeFromSemantics: true,
          child: Container(
            constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin),
            padding: EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            alignment: Alignment.centerLeft,
            child: AppText(label, variant: AppTextVariant.body),
          ),
        ),
      ),
    );
  }
}
