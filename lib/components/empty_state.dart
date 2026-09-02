/// `EmptyState`（SPEC-004 §4.21）。
///
/// 「這裡目前沒有內容」+ 至少一個非返回的前進動作（SPEC-001 FR-03）；
/// 訊息、說明、動作為 slot。[EmptyStateVariant.page] 置中於內容區，動作
/// 必填（FR-03）；[EmptyStateVariant.section] 靠上對齊，動作可缺（前進
/// 動作在區塊外時，例：未選格右欄由點格本身承載前進）。
library;

import 'package:flutter/widgets.dart';

import 'app_button.dart';
import 'app_text.dart';
import 'button_row.dart';
import '../tokens/tokens.dart';

/// 元件外觀與動作必填性（SPEC-004 §4.21「變體」）。
enum EmptyStateVariant {
  /// 全頁空狀態：置中於內容區，訊息 [AppTextVariant.subtitle]、
  /// 說明 [AppTextVariant.body]（`secondary`），動作必填。
  page,

  /// 區塊級空狀態：靠上對齊，訊息 [AppTextVariant.body]，說明可缺，
  /// 動作可缺。
  section,
}

/// SPEC-001 FR-03 空狀態承載元件：訊息 + 說明（可缺）+ 動作列（依變體）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [message] | 是 | 呼叫端傳入（i18n key 取值） |
/// | [explanation] | 否 | 呼叫端傳入 |
/// | [actions] | `page` 必填（1..3）；`section` 可空 | 經 [ButtonRow]，首個非 `backAction`（FR-03，由呼叫端保證） |
/// | [testKey] | 是 | `state-<screen>-<state>` / `panel-domain-cell-detail-empty` |
class EmptyState extends StatelessWidget {
  EmptyState({
    super.key,
    required this.variant,
    required this.message,
    required this.testKey,
    this.explanation,
    this.actions = const [],
  }) : assert(
         variant != EmptyStateVariant.page || actions.isNotEmpty,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'page 變體動作必填（SPEC-004 §4.21 slot 契約，FR-03）',
       ),
       assert(
         actions.length <= 3,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'actions 至多 3 個（經 ButtonRow，SPEC-004 §4.34 slot 契約）',
       );

  /// `page`（置中、動作必填）或 `section`（靠上、動作可缺）。
  final EmptyStateVariant variant;

  /// 訊息（`page`：`subtitle` 單行；`section`：`body`，最大 2 行末截斷）。
  final String message;

  /// 說明，可缺（`body`，`secondary`，最大 4 行末截斷）。
  final String? explanation;

  /// 動作按鈕（經 [ButtonRow]，1..3 個）；`page` 必填、`section` 可空。
  final List<AppButton> actions;

  /// 呼叫端定址 key（`Key`）。
  final Key testKey;

  bool get _isPage => variant == EmptyStateVariant.page;

  @override
  Widget build(BuildContext context) {
    final textBlock = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: LayoutSize.detailPaneWidth * 2),
      child: Column(
        key: testKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: _isPage
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: _buildChildren(),
      ),
    );

    if (_isPage) {
      return Center(child: textBlock);
    }

    return Padding(padding: EdgeInsets.all(Space.md), child: textBlock);
  }

  List<Widget> _buildChildren() {
    final children = <Widget>[
      Semantics(
        liveRegion: true,
        child: AppText(
          message,
          variant: _isPage ? AppTextVariant.subtitle : AppTextVariant.body,
          maxLines: _isPage ? null : 2,
          textAlign: _isPage ? TextAlign.center : null,
        ),
      ),
    ];

    if (explanation != null) {
      children
        ..add(SizedBox(height: Space.xs))
        ..add(
          AppText(
            explanation!,
            variant: AppTextVariant.body,
            secondary: true,
            maxLines: 4,
            textAlign: _isPage ? TextAlign.center : null,
          ),
        );
    }

    if (actions.isNotEmpty) {
      children
        ..add(SizedBox(height: Space.lg))
        ..add(
          ButtonRow(
            alignment: _isPage
                ? ButtonRowAlignment.center
                : ButtonRowAlignment.start,
            children: actions,
          ),
        );
    }

    return children;
  }
}
