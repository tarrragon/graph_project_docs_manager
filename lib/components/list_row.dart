/// 容器：leading（可選）+ 主／次文字 + trailing（可選）水平列
/// （SPEC-004 §4.40、§5.14）。
///
/// 六個變體（[ListRowVariant]）：`tree` / `sectionHeader` / `item` /
/// `option` / `meta` / `numbered`。`primary` / `secondary` 型別限
/// [AppText]（SPEC-004 §5.14 子件契約），`leading` / `trailing` 因所接受的
/// `ExpanderIcon | AppIcon | Badge | StepNumber`（leading）與
/// `Badge | AppIcon | AppText.caption | IssueMarker`（trailing）跨多個
/// 元件型別、且 `StepNumber`／`IssueMarker` 尚未建立於 `lib/components/`，
/// 改以 `Widget` 承接（與 `AppButton` leading 已記錄的契約差異同一慣例）。
///
/// `sectionHeader` 主文字需 `emphasis` + `accentStrong`（SPEC-004
/// 4.40「變體」）。本元件依 [AppText.tone]（SPEC-004 §4.1「修飾參數優先
/// 序」）以 [AppText.copyWithModifiers] 重染呼叫端傳入的 [AppText]
/// （`emphasis: true`、`tone: AppTextTone.accentStrong`），維持文字恆以
/// [AppText] 承載（不繞道建 `Text`）。
///
/// 截斷責任：`primary` / `secondary` 的行數政策（單行省略號或多行）由
/// 呼叫端建構 [AppText] 時以 [AppText.singleLine] / [AppText.multiLine]
/// 明示，本容器不代為決定，重染時原樣保留（SPEC-004 §4.40）。
library;

import 'package:flutter/material.dart' show InkWell;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 六個變體（SPEC-004 §4.40「變體」表）。
enum ListRowVariant {
  /// 追溯樹列：leading `ExpanderIcon`、trailing `Badge.status` 或
  /// `IssueMarker.gap`；整列可點。
  tree,

  /// 主題節首、破洞類別節首：leading `ExpanderIcon` 或 `Badge.category`、
  /// trailing 計數／摘要文字；列本體不可點，展開由 leading 承載。
  sectionHeader,

  /// 破洞項：主文字 + 次文字堆疊、trailing 外開箭頭；整列可點。
  item,

  /// UC 選擇入口項：主文字為 UC ID + 標題，無 leading／trailing；
  /// `selected` 時底色 `surfaceIconTint` + 主文字 `emphasis`；整列可點。
  option,

  /// 節點詳情 meta 列：leading `Badge.type`、主文字 `AppText.mono`。
  meta,

  /// 格詳情卡步驟清單：leading `StepNumber`、主文字 `AppText.body`。
  numbered,

  /// 鍵盤快捷鍵面板列：leading 按鍵字面（`AppText.mono`，固定寬）、主文字
  /// 作用、次文字作用情境；整列不可點、不取得焦點，朗讀合併為一個節點。
  shortcut,
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
    this.isSelected = false,
    this.shortcutKeys,
  }) : assert(
         secondary == null ||
             variant == ListRowVariant.item ||
             variant == ListRowVariant.shortcut,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'secondary 僅 item／shortcut 變體接受（SPEC-004 §5.14 子件契約）',
       ),
       assert(
         !isSelected || variant == ListRowVariant.option,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'isSelected 僅 option 變體接受（SPEC-004 §4.40 slot 契約）',
       );

  /// 追溯樹列。leading／testKey 必填（SPEC-004 4.40 slot 契約）。
  /// [onTap] 為 `null` 時整列不可點：不掛 `InkWell`、不給 button 語意
  /// （追溯視圖缺口列，SPEC-004 4.39／4.40）。
  const ListRow.tree({
    Key? key,
    required Widget leading,
    required AppText primary,
    Widget? trailing,
    required VoidCallback? onTap,
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

  /// 破洞項。onTap／testKey 必填；[secondary] 可省——項目沒有說明時路徑與
  /// 行號放主文字、不渲染次文字，列高一行（SPEC-004 v1.84 4.40 `item`）。
  const ListRow.item({
    Key? key,
    required AppText primary,
    AppText? secondary,
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

  /// UC 選擇入口項。onTap／testKey 必填（SPEC-004 4.40 slot 契約）；
  /// `isSelected` 為 `true` 時底色 `surfaceIconTint` + 主文字 `emphasis`。
  const ListRow.option({
    Key? key,
    required AppText primary,
    required VoidCallback onTap,
    required Key testKey,
    bool isSelected = false,
  }) : this._(
         key: key,
         variant: ListRowVariant.option,
         primary: primary,
         onTap: onTap,
         testKey: testKey,
         isSelected: isSelected,
       );

  /// 節點詳情 meta 列。leading 必填，primary 為 `AppText.mono`（路徑）。
  const ListRow.meta({
    Key? key,
    required Widget leading,
    required AppText primary,
  }) : this._(
         key: key,
         variant: ListRowVariant.meta,
         leading: leading,
         primary: primary,
       );

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

  /// 鍵盤快捷鍵列（SPEC-004 4.40 `shortcut`）。[keys] 為按鍵字面（資料值，
  /// 不進 i18n）、[action] 為作用、[contextLabel] 為作用情境。
  ListRow.shortcut({
    Key? key,
    required String keys,
    required String action,
    required String contextLabel,
  }) : this._(
         key: key,
         variant: ListRowVariant.shortcut,
         primary: AppText.multiLine(action, maxLines: null),
         secondary: AppText.singleLine(
           contextLabel,
           variant: AppTextVariant.caption,
         ),
         shortcutKeys: keys,
       );

  /// `shortcut` 變體的按鍵字面；其餘變體為 `null`。
  String? get keys => shortcutKeys;

  /// `shortcut` 變體的作用情境；其餘變體為 `null`。
  String? get contextLabel =>
      variant == ListRowVariant.shortcut ? secondary?.text : null;

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

  /// 整列點選回呼；`item` 必填，`tree` 可為 `null`（整列不可點），
  /// 其餘變體不使用。
  final VoidCallback? onTap;

  /// 呼叫端定址 key；`tree` / `item` / `option` 必填（SPEC-004 4.40 slot
  /// 契約）。
  final Key? testKey;

  /// `option` 變體的選定態；其餘變體不接受（預設 `false`）。
  final bool isSelected;

  /// `shortcut` 變體的按鍵字面（資料值，不進 i18n）。
  final String? shortcutKeys;

  bool get _isTappableRow =>
      variant == ListRowVariant.tree ||
      variant == ListRowVariant.item ||
      variant == ListRowVariant.option;

  @override
  Widget build(BuildContext context) {
    if (variant == ListRowVariant.shortcut) return _buildShortcut(context);
    final row = Row(
      crossAxisAlignment: variant == ListRowVariant.item
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: Space.sm.w)],
        Expanded(child: _buildTextBlock()),
        if (trailing != null) ...[SizedBox(width: Space.sm.w), trailing!],
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

    final background = variant == ListRowVariant.option && isSelected
        ? ColoredBox(color: AppColors.surfaceIconTint, child: sized)
        : sized;

    if (variant == ListRowVariant.sectionHeader) {
      return Semantics(header: true, child: sized);
    }

    if (variant == ListRowVariant.tree && onTap == null) {
      return KeyedSubtree(key: testKey, child: sized);
    }

    if (_isTappableRow) {
      return MergeSemantics(
        child: Semantics(
          key: testKey,
          button: true,
          selected: variant == ListRowVariant.option ? isSelected : null,
          child: InkWell(onTap: onTap, child: background),
        ),
      );
    }

    return sized;
  }

  /// `shortcut`：按鍵（固定寬 mono）+ 作用／情境堆疊，列間頂邊框同 `item`；
  /// 子文字以 [ExcludeSemantics] 排除，整列由 `shortcutRowA11yLabel` 朗讀。
  Widget _buildShortcut(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyText = shortcutKeys ?? '';
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: LayoutSize.ticketIdColumnWidth.w,
          child: AppText.singleLine(keyText, variant: AppTextVariant.mono),
        ),
        SizedBox(width: Space.sm.w),
        Expanded(child: _buildTextBlock()),
      ],
    );
    return Semantics(
      container: true,
      label: l10n.shortcutRowA11yLabel(
        keyText,
        primary.text,
        contextLabel ?? '',
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: Space.sm.h),
            child: row,
          ),
        ),
      ),
    );
  }

  /// 主／次文字堆疊。`sectionHeader` 依契約色（`emphasis` +
  /// `accentStrong`）重建，見檔頭說明。
  Widget _buildTextBlock() {
    final stacked =
        variant == ListRowVariant.item || variant == ListRowVariant.shortcut;
    if (!stacked || secondary == null) {
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
    if (variant == ListRowVariant.sectionHeader) {
      return primary.copyWithModifiers(
        emphasis: true,
        tone: AppTextTone.accentStrong,
      );
    }
    if (variant == ListRowVariant.option && isSelected) {
      return primary.copyWithModifiers(emphasis: true);
    }
    return primary;
  }
}
