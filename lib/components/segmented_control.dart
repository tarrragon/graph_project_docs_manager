/// SegmentedControl（SPEC-004 §4.10）。
///
/// 雙模式切換（矩陣／泳道、列表／主題）唯一承載元件，段數上限 2；
/// 每段錨點由呼叫端經 [SegmentItem.testKey] 提供（`mode-<screen>-<mode>`）。
/// 選中態切換無動畫，內容 cross-fade 由畫面承載（SPEC-004 4.10 互動反應）。
///
/// **命名注意**：契約表原文欄位名為 `segments`（`Segment{...}`），但 `Segment`
/// 與 `package:flutter/material.dart` 內建的 `Segment<T>`（`SegmentedButton`
/// 用）撞名，兩者同檔匯入會使建構式解析歧義；本檔改名 [SegmentItem]，欄位
/// 語意不變。
library;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// [SegmentedControl] 單一段的內容（SPEC-004 4.10 slot 契約，原文 `Segment`）。
class SegmentItem {
  const SegmentItem({
    required this.label,
    required this.semanticLabel,
    required this.testKey,
  });

  /// 可見文字（單行，超出截斷）。呼叫端傳入 `mode*Label`。
  final String label;

  /// 朗讀提示（`Semantics.hint`）。呼叫端傳入既有 `*SwitchTo*Action`。
  final String semanticLabel;

  /// 測試錨點（`mode-<screen>-<mode>`）。
  final Key testKey;
}

/// 雙模式切換元件（SPEC-004 §4.10）。單一變體，[segments] 長度恰 2。
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(
         segments.length == 2,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'segments 長度必須恰為 2（SPEC-004 §4.10 slot 契約）',
       );

  /// 兩段內容，長度恰 2。
  final List<SegmentItem> segments;

  /// 目前選中的段索引。
  final int selectedIndex;

  /// 點選未選段時呼叫，帶該段索引；點選已選段不呼叫。
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSegmentTrack,
        borderRadius: BorderRadius.circular(Radius.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(Space.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) SizedBox(width: Space.xxs),
              Flexible(
                child: _SegmentButton(
                  segment: segments[i],
                  selected: i == selectedIndex,
                  onTap: i == selectedIndex ? null : () => onChanged(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatefulWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final SegmentItem segment;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  static const Color _unfocusedBorder = Colors.transparent; // color-exempt

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'SegmentedControlSegment');
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
    final segment = widget.segment;
    final foreground = widget.selected
        ? AppColors.accentStrong
        : AppColors.textPrimary;
    final fontWeight = widget.selected ? FontWeight.w600 : FontWeight.normal;

    return Semantics(
      key: segment.testKey,
      button: true,
      label: segment.label,
      hint: segment.semanticLabel,
      selected: widget.selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.accent : _unfocusedBorder,
          ),
          borderRadius: BorderRadius.circular(Radius.sm),
        ),
        child: SizedBox(
          height: LayoutSize.hitTargetMin,
          child: Material(
            color: widget.selected
                ? AppColors.surfaceBase
                : Colors.transparent, // color-exempt 未選段無底
            borderRadius: BorderRadius.circular(Radius.sm),
            child: InkWell(
              onTap: widget.onTap == null
                  ? null
                  : () {
                      _focusNode.requestFocus();
                      widget.onTap!();
                    },
              focusNode: _focusNode,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(Radius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.xs,
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        color: foreground,
                        fontWeight: fontWeight,
                      ),
                    ),
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
