/// 展開觸發器（SPEC-004 §4.18）。
///
/// 樹節點、主題節、破洞分節共用的展開／收合按鈕。狀態由 [isExpanded] 與
/// [isLeaf] 兩個旗標承載，非內部管理——呼叫端持有真實狀態，本元件純顯示
/// 加回呼（SPEC-004 §2 傳值 + callback 慣例）。`leaf` 態不渲染箭頭但保留
/// 命中區寬度以對齊同欄其餘列（SPEC-004 4.18 狀態矩陣）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 展開觸發器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [isExpanded] | 是 | 展開態旗標，決定箭頭方向 |
/// | [isLeaf] | 否（預設 `false`） | 無子層時為 `true`，不渲染箭頭且排除於語意樹 |
/// | [onToggle] | 非 leaf 必填 | 點選或鍵盤觸發（Enter / Space）呼叫一次 |
/// | [testKey] | 是 | 呼叫端依 SPEC-004 4.18 slot 契約提供的定址 key |
class ExpanderIcon extends StatefulWidget {
  const ExpanderIcon({
    super.key,
    required this.isExpanded,
    required this.testKey,
    this.isLeaf = false,
    this.onToggle,
  });

  /// 展開態旗標；`isLeaf` 為 `true` 時本值不影響顯示。
  final bool isExpanded;

  /// 無子層時為 `true`：不渲染箭頭但保留 [LayoutSize.hitTargetMin] 寬度
  /// 對齊同欄其餘列，且排除於語意樹（SPEC-004 4.18 無障礙子節）。
  final bool isLeaf;

  /// 點選或鍵盤觸發時呼叫；`isLeaf` 為 `true` 時不使用。
  final VoidCallback? onToggle;

  /// 呼叫端定址 key（SPEC-004 4.18 slot 契約）。
  final Key testKey;

  @override
  State<ExpanderIcon> createState() => _ExpanderIconState();
}

class _ExpanderIconState extends State<ExpanderIcon> {
  /// 未聚焦時的邊框色：透明，僅焦點時（[AppColors.accent]）可見。
  /// 非語意色彩，不進 token 表。
  static const Color _unfocusedBorder = Colors.transparent; // color-exempt

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ExpanderIcon');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = LayoutSize.hitTargetMin;

    if (widget.isLeaf) {
      return ExcludeSemantics(
        child: SizedBox(key: widget.testKey, width: size, height: size),
      );
    }

    final l10n = AppLocalizations.of(context);

    return Semantics(
      key: widget.testKey,
      button: true,
      label: l10n.expanderLabel,
      expanded: widget.isExpanded,
      child: SizedBox(
        width: size,
        height: size,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onToggle?.call();
                  return null;
                },
              ),
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.accent
                      : _unfocusedBorder,
                ),
                borderRadius: BorderRadius.circular(Radius.sm),
              ),
              child: InkWell(
                onTap: () {
                  _focusNode.requestFocus();
                  widget.onToggle?.call();
                },
                focusNode: _focusNode,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(Radius.sm),
                child: Center(
                  child: Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: LayoutSize.iconSm,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
