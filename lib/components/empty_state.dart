/// `EmptyState`（SPEC-004 §4.21）。
///
/// 「這裡目前沒有內容」+ 至少一個非返回的前進動作（SPEC-001 FR-03）；
/// 訊息、說明、動作為 slot。[EmptyStateVariant.page] 置中於內容區，動作
/// 必填（FR-03）；[EmptyStateVariant.section] 靠上對齊，動作可缺（前進
/// 動作在區塊外時，例：未選格右欄由點格本身承載前進）。`page` 動作必填
/// 只對 [EmptyStatePageActionsException] 明列的例外狀態成立——目前唯一
/// 成員 [EmptyStatePageActionsException.actionsRelocatedToHeader]
/// 對應破洞報告「無破洞」列：前進動作改置於 `SplitRow.header` 右側
/// （SPEC-004 §3.7 第 18 項、`0.1.0-W3-335.37` R10、SPEC-003 §2.7）。
/// 呼叫端須傳入該具名狀態識別，非任意布林旗標；新增例外需在此
/// enum 新增具名成員並引用對應 SPEC 條款，不可隱式放行。
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

/// `page` 動作必填斷言的明列例外狀態清單（SPEC-004 §4.21、SPEC-003 §2.7）。
///
/// 非任意布林旗標——每個非 [none] 成員對應一個 SPEC 明列的例外狀態，
/// 呼叫端須傳入具體識別以繞過必填斷言。新增例外需在此新增具名成員並
/// 於註解引用 SPEC 條款，不可以泛用布林隱式放行。
enum EmptyStatePageActionsException {
  /// 無例外，`page` 動作必填斷言正常生效。
  none,

  /// 前進動作已置於畫面外的其他掛點（例：`SplitRow.header` 右側，
  /// SPEC-004 §3.7 第 18 項），如破洞報告「無破洞」列
  /// （`0.1.0-W3-335.37` R10、SPEC-003 §2.7）。
  actionsRelocatedToHeader,
}

/// SPEC-001 FR-03 空狀態承載元件：訊息 + 說明（可缺）+ 動作列（依變體）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [message] | 是 | 呼叫端傳入（i18n key 取值） |
/// | [explanation] | 否 | 呼叫端傳入 |
/// | [actions] | `page` 必填（1..3），[pageActionsException] 非 [EmptyStatePageActionsException.none] 時可空；`section` 可空 | 經 [ButtonRow]，首個非 `backAction`（FR-03，由呼叫端保證） |
/// | [testKey] | 是 | `state-<screen>-<state>` / `panel-domain-cell-detail-empty` |
class EmptyState extends StatelessWidget {
  EmptyState({
    super.key,
    required this.variant,
    required this.message,
    required this.testKey,
    this.explanation,
    this.actions = const [],
    this.pageActionsException = EmptyStatePageActionsException.none,
  }) : assert(
         variant != EmptyStateVariant.page ||
             actions.isNotEmpty ||
             pageActionsException != EmptyStatePageActionsException.none,
         'page 變體動作必填，明式例外需以 pageActionsException 標示 SPEC 明列狀態（SPEC-004 §4.21）', // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
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

  /// `page` 動作必填斷言的例外狀態識別（SPEC-004 §4.21、SPEC-003 §2.7）；
  /// 預設 [EmptyStatePageActionsException.none]（隱式放行禁止），
  /// 只有 SPEC 明列的具名狀態可繞過必填斷言。
  final EmptyStatePageActionsException pageActionsException;

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
