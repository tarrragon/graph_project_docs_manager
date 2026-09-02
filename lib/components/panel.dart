/// 容器面板（SPEC-004 §4.30；排列不變式 §5.4）。
///
/// 白底、邊框、圓角、內距的垂直堆疊，所有內容區塊的表面。子件依序垂直
/// 堆疊、填滿寬、上緣對齊，兩兩間距固定 `Space.sm`（§5.4「最小間距」
/// 「呼叫端不得覆寫」，故無對應建構子參數）；內距固定 `Space.md`。
///
/// **與契約的一處差異（範圍限定）**：slot 契約 `children` 型別寫具名清單
/// （`Toolbar` \| `SplitRow` \| `DataTable` \| … 等 14 種），但元件庫尚無
/// 這些容器／資料視圖型別（皆非本票 4.30 範圍）。本檔改以 `List<Widget>`
/// 承接，語意不變；上述型別建立後可直接代入，型別相容。
library;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// 面板變體（SPEC-004 §4.30「變體」表）。規格值 `default` 為 Dart 保留字，
/// 改名 [standard]。
enum PanelVariant {
  /// 規格 `default`：無自身捲動，子件中恰一個為填滿高的資料視圖，吸收
  /// 剩餘高——呼叫端把該子件以 `Expanded` 包裹後放入 [Panel.children]。
  standard,

  /// 主體垂直捲動；子件總高超過面板高時捲動。
  scrollable,
}

/// 白底、邊框、圓角、內距的垂直堆疊容器（SPEC-004 §4.30）。
///
/// 尺寸模式「填滿父格位（寬與高）」由外部約束被動達成：呼叫端把本元件
/// 放入提供定高定寬的父格位（`PageColumn` 內容 slot、`TwoColumnLayout`
/// 主欄／右欄），本元件不自行指定 `width`／`height`。
class Panel extends StatelessWidget {
  /// `standard` 變體（規格 `default`）：子件中恰一個資料視圖吸收剩餘高，
  /// 由呼叫端以 `Expanded` 包裹該子件後放入 [children]（1..12 項）。
  const Panel({Key? key, required List<Widget> children})
    : this._(key: key, variant: PanelVariant.standard, children: children);

  /// `scrollable` 變體：主體垂直捲動，無子件數量上限。[scrollKey] 為
  /// 必填錨點（`scroll-<screen>-<area>`，§4.30 slot 契約）。
  const Panel.scrollable({
    Key? key,
    required List<Widget> children,
    required Key scrollKey,
  }) : this._(
         key: key,
         variant: PanelVariant.scrollable,
         children: children,
         scrollKey: scrollKey,
       );

  const Panel._({
    super.key,
    required this.variant,
    required this.children,
    this.scrollKey,
  });

  /// 面板變體。
  final PanelVariant variant;

  /// 子件（`standard`：1..12，其中資料視圖恰 1；`scrollable`：無上限）。
  final List<Widget> children;

  /// 捲動容器錨點（`scrollable` 必填；`standard` 不使用）。
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final body = variant == PanelVariant.scrollable
        ? SingleChildScrollView(
            key: scrollKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _spacedChildren(),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spacedChildren(),
          );

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(Radius.lg),
        ),
        child: Padding(padding: EdgeInsets.all(Space.md), child: body),
      ),
    );
  }

  /// 子件間插入 `Space.sm` 間距（§5.4「最小間距」）。
  List<Widget> _spacedChildren() {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) {
        spaced.add(const SizedBox(height: Space.sm));
      }
    }
    return spaced;
  }
}
