/// 節容器（SPEC-004 4.41、5.15）。
///
/// 節首 + 項目垂直堆疊：主題節、破洞類別節、關聯群、schema 詳情面板皆用
/// 本容器。[SectionVariant.collapsible] 節首含展開器，收合時 [items] 不
/// 渲染入元件樹；[SectionVariant.static] 恆展開，無展開器。狀態存於呼叫
/// 端（SPEC-004 §2 傳值 + callback 慣例），本元件不持有 [isExpanded]。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// 節首形式與收合能力（SPEC-004 4.41「變體」）。
enum SectionVariant {
  /// 節首含展開器；收合時 [Section.items] 不渲染。主題節、破洞類別節。
  collapsible,

  /// 節首為純文字，恆展開。關聯群、schema 詳情面板。
  static,
}

/// 節容器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [header] | 是 | `collapsible` 傳含展開器的節首；`static` 傳 `AppText.caption` |
/// | [items] | 是（可為空清單） | 單一型別的項目清單；0 項只渲染節首 |
/// | [isExpanded] | `collapsible` 必填 | 展開態旗標 |
/// | [onToggle] | 否 | `collapsible` 用；未傳則節首本身仍可能提供觸發（如 `ExpanderIcon`） |
/// | [dashedTop] | 否（預設 `false`） | 頂部虛線修飾，用於「未歸屬」節 |
/// | [testKey] | 是 | 呼叫端定址 key |
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.variant,
    required this.header,
    required this.items,
    required this.testKey,
    this.isExpanded = true,
    this.dashedTop = false,
  });

  /// 節首形式與收合能力。
  final SectionVariant variant;

  /// 節首 widget：`collapsible` 為 `ListRow.sectionHeader`，`static` 為
  /// `AppText.caption`。
  final Widget header;

  /// 項目清單，單一型別（`TableRow.ticket` | `ListRow.item` |
  /// `RelationItem` | `AppText.mono`），呼叫端負責型別一致。
  final List<Widget> items;

  /// 展開態旗標；`variant` 為 [SectionVariant.static] 時忽略（恆展開）。
  final bool isExpanded;

  /// 頂部虛線修飾（`AppColors.borderStrong`），「未歸屬」節專用。
  final bool dashedTop;

  /// 呼叫端定址 key（`Key`，例：`expander-tickets-topic-<name>`）。
  final Key testKey;

  bool get _showItems => variant == SectionVariant.static || isExpanded;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      key: testKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AnimatedSize(
          duration: Motion.transition(context),
          alignment: Alignment.topCenter,
          child: _showItems ? _buildItems() : const SizedBox.shrink(),
        ),
      ],
    );

    if (!dashedTop) {
      return body;
    }

    return Padding(
      padding: EdgeInsets.only(top: Space.sm),
      child: CustomPaint(
        painter: const _DashedTopPainter(),
        child: body,
      ),
    );
  }

  Widget _buildItems() {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[SizedBox(height: Space.xxs), item],
      ],
    );
  }
}

/// 頂部虛線繪製：`Border` 不支援虛線樣式，改用 [CustomPainter] 逐段畫短劃。
class _DashedTopPainter extends CustomPainter {
  const _DashedTopPainter();

  static const double _dashWidth = 4;
  static const double _dashGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + _dashWidth, 0), paint);
      x += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedTopPainter oldDelegate) => false;
}
