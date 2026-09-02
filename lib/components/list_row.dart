/// 容器：leading（可選）+ 主／次文字 + trailing（可選）水平列
/// （SPEC-004 §4.40、§5.14）。
///
/// 五個變體（[ListRowVariant]）：`tree` / `sectionHeader` / `item` /
/// `meta` / `numbered`。`primary` / `secondary` 型別限 [AppText]（SPEC-004
/// §5.14 子件契約），`leading` / `trailing` 因所接受的
/// `ExpanderIcon | AppIcon | Badge | StepNumber`（leading）與
/// `Badge | AppIcon | AppText.caption | IssueMarker`（trailing）跨多個
/// 元件型別、且 `StepNumber`／`IssueMarker` 尚未建立於 `lib/components/`，
/// 改以 `Widget` 承接（與 `AppButton` leading 已記錄的契約差異同一慣例）。
///
/// `sectionHeader` 主文字需 `emphasis` + `accentStrong`（SPEC-004
/// 4.40「變體」），但 [AppText] 無 `accentStrong` 顏色參數（僅
/// `secondary` 布林切 `textSecondary`）。本元件對此變體讀出呼叫端傳入
/// [AppText] 的 `text`，以符合契約色的內部 `Text` 重繪，非直接渲染呼叫端
/// 元件——契約型別（`primary` 恰一個 [AppText]）不變，僅呈現手段不同。
library;

import 'package:flutter/material.dart' show InkWell;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';
import 'app_text.dart';

/// 五個變體（SPEC-004 §4.40「變體」表）。
enum ListRowVariant {
  /// 追溯樹列：leading `ExpanderIcon`、trailing `Badge.status` 或
  /// `IssueMarker.gap`；整列可點。
  tree,

  /// 主題節首、破洞類別節首：leading `ExpanderIcon` 或 `Badge.category`、
  /// trailing 計數／摘要文字；列本體不可點，展開由 leading 承載。
  sectionHeader,

  /// 破洞項：主文字 + 次文字堆疊、trailing 外開箭頭；整列可點。
  item,

  /// 節點詳情 meta 列：leading `Badge.type`、主文字 `AppText.mono`。
  meta,

  /// 格詳情卡步驟清單：leading `StepNumber`、主文字 `AppText.body`。
  numbered,
}

/// 容器：leading（可選）+ 主文字（填滿）+ 次文字（可選，堆疊於主文字下）
/// + trailing（可選）水平列（SPEC-004 §4.40）。
class ListRow extends StatelessWidget {
  const ListRow._({
    super.key,
    required this.variant,
    this.leading,
    required this.primary,
    this.secondary,
    this.trailing,
    this.onTap,
    this.testKey,
  }) : assert(
         secondary == null || variant == ListRowVariant.item,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'secondary 僅 item 變體接受（SPEC-004 §5.14 子件契約）',
       );

  /// 追溯樹列。leading／onTap／testKey 必填（SPEC-004 4.40 slot 契約）。
  const ListRow.tree({
    Key? key,
    required Widget leading,
    required AppText primary,
    Widget? trailing,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: ListRowVariant.tree,
         leading: leading,
         primary: primary,
         trailing: trailing,
         onTap: onTap,
         testKey: testKey,
       );

  /// 主題節首、破洞類別節首。列本體不可點（展開由 leading 承載）。
  const ListRow.sectionHeader({
    Key? key,
    required Widget leading,
    required AppText primary,
    Widget? trailing,
  }) : this._(
         key: key,
         variant: ListRowVariant.sectionHeader,
         leading: leading,
         primary: primary,
         trailing: trailing,
       );

  /// 破洞項。secondary／onTap／testKey 必填（SPEC-004 4.40 slot 契約）。
  const ListRow.item({
    Key? key,
    required AppText primary,
    required AppText secondary,
    Widget? trailing,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: ListRowVariant.item,
         primary: primary,
         secondary: secondary,
         trailing: trailing,
         onTap: onTap,
         testKey: testKey,
       );

  /// 節點詳情 meta 列。leading 必填，primary 為 `AppText.mono`（路徑）。
  const ListRow.meta({Key? key, required Widget leading, required AppText primary})
    : this._(key: key, variant: ListRowVariant.meta, leading: leading, primary: primary);

  /// 格詳情卡步驟清單。leading 必填。
  const ListRow.numbered({
    Key? key,
    required Widget leading,
    required AppText primary,
  }) : this._(
         key: key,
         variant: ListRowVariant.numbered,
         leading: leading,
         primary: primary,
       );

  /// 語意變體。
  final ListRowVariant variant;

  /// leading slot（`ExpanderIcon` \| `AppIcon` \| `Badge` \| `StepNumber`）。
  final Widget? leading;

  /// 主文字（恰 1，填滿；`AppText.body` 或 `.mono`）。
  final AppText primary;

  /// 次文字（僅 `item` 變體接受，堆疊於主文字下）。
  final AppText? secondary;

  /// trailing slot（`Badge` \| `AppIcon` \| `AppText.caption` \|
  /// `IssueMarker`）。
  final Widget? trailing;

  /// 整列點選回呼；`tree` / `item` 必填，其餘變體不使用。
  final VoidCallback? onTap;

  /// 呼叫端定址 key；`tree` / `item` 必填（SPEC-004 4.40 slot 契約）。
  final Key? testKey;

  bool get _isTappableRow =>
      variant == ListRowVariant.tree || variant == ListRowVariant.item;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: variant == ListRowVariant.item
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          SizedBox(width: Space.sm.w),
        ],
        Expanded(child: _buildTextBlock()),
        if (trailing != null) ...[
          SizedBox(width: Space.sm.w),
          trailing!,
        ],
      ],
    );

    final sized = variant == ListRowVariant.item
        ? DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Space.sm.h),
              child: row,
            ),
          )
        : SizedBox(height: LayoutSize.rowHeightDense.h, child: row);

    if (variant == ListRowVariant.sectionHeader) {
      return Semantics(header: true, child: sized);
    }

    if (_isTappableRow) {
      return MergeSemantics(
        child: Semantics(
          key: testKey,
          button: true,
          child: InkWell(onTap: onTap, child: sized),
        ),
      );
    }

    return sized;
  }

  /// 主／次文字堆疊。`sectionHeader` 依契約色（`emphasis` +
  /// `accentStrong`）重繪，見檔頭「與契約的一處差異」。
  Widget _buildTextBlock() {
    if (variant != ListRowVariant.item) {
      return _buildPrimary();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        primary,
        SizedBox(height: Space.xxs.h),
        secondary!,
      ],
    );
  }

  Widget _buildPrimary() {
    if (variant != ListRowVariant.sectionHeader) {
      return primary;
    }
    return Text(
      primary.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.body.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.accentStrong,
      ),
    );
  }
}
