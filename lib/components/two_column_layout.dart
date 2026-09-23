/// 主副雙欄容器（SPEC-004 §4.31、§5.5）。
///
/// 主欄（`main`，`Panel` | `Panel.scrollable`）填滿剩餘寬；右欄（`detail`，
/// `Panel.scrollable`）固定寬 [LayoutSize.detailPaneWidth]，常駐不隱藏
/// （SPEC-001 §1 註記）。兩欄各自獨立捲動——本容器不持有共享
/// `ScrollController`，主欄捲動不影響右欄 offset，反之亦然（SPEC-003
/// §1.1 連動禁令 #8/#9、#1/#11）。
///
/// 右欄內容換件（提示 ↔ 詳情卡）以 [AnimatedSwitcher] 的預設
/// cross-fade 呈現，時長取 [Motion.transition]；呼叫端傳入不同 `Key`
/// 的 [detail] 即觸發過場，主欄寬與 offset 不受影響。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// 主副雙欄容器（SPEC-004 §4.31）。
///
/// 單一變體（`default`，右欄寬單一值，§3.7 第 21 項）。容器本身無互動
/// 狀態集——右欄內容切換是子件換件，非本容器狀態。
class TwoColumnLayout extends StatelessWidget {
  const TwoColumnLayout({super.key, required this.main, required this.detail});

  /// 主欄內容，契約型別為 `Panel` 或 `Panel.scrollable`（SPEC-004 §4.31
  /// slot 契約，恰 1）。維持 `Widget` 承接：收窄為 `Panel` 會使
  /// `domain_view_screen.dart` 的 `_CellDetailPanel`（`ConsumerWidget`，
  /// 承載 AnimatedSwitcher 過場所需的動態 `Key`）與
  /// `uc_flow_screen.dart` 的 `_UcSelectorPanel` 型別不相容（`0.1.0-W1-067`
  /// 實測：`dart analyze`／`flutter test` 編譯失敗，5 處呼叫點），此二檔
  /// 案不在本票 `where.files` 範圍，且 `_CellDetailPanel` 的過場觸發鍵與
  /// 測試定址鍵分居兩個 widget 層級，收窄需要额外的識別鍵架構決策，非
  /// 機械改型別可解，故回報 PM 另立票處理（見本票 NeedsContext）。
  final Widget main;

  /// 右欄內容，契約型別為 `Panel.scrollable`（SPEC-004 §4.31 slot 契約，
  /// 恰 1）；§1 與 §6 皆為可捲動。維持 `Widget` 承接，理由同 [main]。
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Semantics(container: true, child: main),
        ),
        SizedBox(width: Space.md),
        SizedBox(
          width: LayoutSize.detailPaneWidth,
          child: Semantics(
            container: true,
            child: AnimatedSwitcher(
              duration: Motion.transition(context),
              child: detail,
            ),
          ),
        ),
      ],
    );
  }
}
