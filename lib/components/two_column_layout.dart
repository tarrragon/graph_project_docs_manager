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
  /// slot 契約，恰 1）。維持 `Widget` 承接：既有測試以 `ListView` 型別
  /// 斷言（`tester.widget<ListView>`）直接驗證捲動子件本身，改用 `Panel`
  /// 需同步重寫該類斷言，非本票範圍。
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
