/// SPEC-004 §4.28 / §5.2 `PageColumn`：每頁根堆疊容器。
///
/// 頁首（恰 1，固有高 [LayoutSize.headerHeight]）+ 內容（恰 1，填滿剩餘高，
/// 內距 [Space.xl]）垂直排列，為 `AppShell` 主區 `IndexedStack` 之下的頁面
/// 框架。內容 slot 換件時以 [Motion.transition] cross-fade，`disableAnimations`
/// 時一幀抵達（SPEC-003 §2.1）。
///
/// 契約來源：`docs/spec/ui/SPEC-004-component-library.md` §4.28、§5.2。
library;

import 'package:flutter/widgets.dart';

import '../tokens/colors.dart';
import '../tokens/layout.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';

/// 每頁根堆疊：頁首 + 內容垂直排列。
///
/// [header] 對應 §4.28 slot 契約的 `header`（`SplitRow.header`），固有高
/// 鎖定為 [LayoutSize.headerHeight]（§5.2 排列不變式「不重疊」的依據）。
/// [content] 對應 slot `content`（`Panel` / `TwoColumnLayout` / 各狀態元件
/// 之一），填滿剩餘高，內距 [Space.xl]（§5.2「最小間距」，呼叫端不得覆寫）。
/// [semanticLabel] 對應無障礙「朗讀標籤」（頁名，`nav*` i18n 值），由呼叫端
/// 傳入——`PageColumn` 本身不持有頁面識別資訊。
class PageColumn extends StatelessWidget {
  const PageColumn({
    super.key,
    required this.semanticLabel,
    required this.header,
    required this.content,
  });

  /// 朗讀標籤（頁名）。`Semantics(container: true)` 的 `label`。
  final String semanticLabel;

  /// 頁首 slot（恰 1，`SplitRow.header`）。
  final Widget header;

  /// 內容 slot（恰 1）。換件時觸發 cross-fade。
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ColoredBox(
        color: AppColors.surfaceSidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: LayoutSize.headerHeight, child: header),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(Space.xl),
                child: AnimatedSwitcher(
                  duration: Motion.transition(context),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
