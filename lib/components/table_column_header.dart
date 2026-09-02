/// 表格與矩陣欄首（SPEC-004 §4.14）。
///
/// 三個變體：`plain`（一行 caption，UC Flow 步驟表欄首）、`sortable`
/// （一行 caption + 排序指示，Ticket 清單欄首）、`twoLine`（矩陣欄首，
/// 第一行 `AppText.mono` 為 UC ID，第二行 caption 為名稱）。`sortable`
/// 的排序循環與唯一排序欄斷言由呼叫端維持（SPEC-003 §3.4 S1–S2），本元件
/// 只呈現 [SortOrder] 並回呼 [onSort]，不持有狀態（SPEC-004 §2 傳值 +
/// callback 慣例）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_icon.dart';
import 'app_text.dart';

/// 排序狀態（SPEC-004 §4.14 slot 契約）。
enum SortOrder {
  /// 未排序：無指示圖示，列序等於載入完成當下的列序（SPEC-003 S3）。
  none,

  /// 遞增。
  asc,

  /// 遞減。
  desc,
}

/// [TableColumnHeader] 的三個變體（SPEC-004 §4.14「變體」表）。
enum TableColumnHeaderVariant {
  /// 一行 caption，無互動。UC Flow 步驟表欄首。
  plain,

  /// 一行 caption + 排序指示圖示（`asc` / `desc` 時），點選觸發 [onSort]。
  /// Ticket 清單欄首。
  sortable,

  /// 第一行 `AppText.mono`（UC ID）、第二行 caption（名稱）。矩陣欄首。
  twoLine,
}

/// 表格與矩陣欄首元件（SPEC-004 §4.14）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [label] | 是 | 呼叫端傳入（`column*`；`twoLine` 第一行為 UC ID 資料值） |
/// | [secondLine] | `twoLine` 必填 | 呼叫端傳入資料值 |
/// | [order] | `sortable` 必填 | 當前排序狀態 |
/// | [onSort] | `sortable` 必填 | 點選或鍵盤（Space / Enter）觸發，下一個
/// | | | [SortOrder] 由呼叫端依 SPEC-003 §3.4 S1–S2 決定 |
/// | [testKey] | `sortable` 必填 | `action-tickets-sort-<key>`（呼叫端提供） |
class TableColumnHeader extends StatelessWidget {
  const TableColumnHeader._({
    super.key,
    required this.variant,
    required this.label,
    this.secondLine,
    this.order,
    this.onSort,
    this.testKey,
  });

  /// 一行 caption，無互動（UC Flow 步驟表欄首）。
  const TableColumnHeader.plain({Key? key, required String label})
    : this._(key: key, variant: TableColumnHeaderVariant.plain, label: label);

  /// 一行 caption + 排序指示，點選呼叫 [onSort]（Ticket 清單欄首）。
  const TableColumnHeader.sortable({
    Key? key,
    required String label,
    required SortOrder order,
    required VoidCallback onSort,
    required Key testKey,
  }) : this._(
         key: key,
         variant: TableColumnHeaderVariant.sortable,
         label: label,
         order: order,
         onSort: onSort,
         testKey: testKey,
       );

  /// 第一行 `AppText.mono`（UC ID）、第二行 caption（名稱）（矩陣欄首）。
  const TableColumnHeader.twoLine({
    Key? key,
    required String label,
    required String secondLine,
  }) : this._(
         key: key,
         variant: TableColumnHeaderVariant.twoLine,
         label: label,
         secondLine: secondLine,
       );

  /// 三個變體之一。
  final TableColumnHeaderVariant variant;

  /// 主文字（`twoLine` 第一行為 UC ID）。
  final String label;

  /// `twoLine` 第二行（名稱）。
  final String? secondLine;

  /// `sortable` 的當前排序狀態。
  final SortOrder? order;

  /// `sortable` 點選或鍵盤觸發的回呼；下一個 [SortOrder] 由呼叫端決定
  /// （本元件不循環）。
  final VoidCallback? onSort;

  /// `sortable` 呼叫端定址 key（`action-tickets-sort-<key>`）。
  final Key? testKey;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      TableColumnHeaderVariant.plain => _buildPlain(),
      TableColumnHeaderVariant.twoLine => _buildTwoLine(),
      TableColumnHeaderVariant.sortable => _SortableHeader(
        label: label,
        order: order!,
        onSort: onSort!,
        testKey: testKey!,
      ),
    };
  }

  Widget _buildPlain() {
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(width: double.infinity, child: _LabelText(label)),
    );
  }

  Widget _buildTwoLine() {
    return Semantics(
      header: true,
      label: '$label，$secondLine',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(label, variant: AppTextVariant.mono),
            SizedBox(height: Space.xxs.h),
            _LabelText(secondLine!),
          ],
        ),
      ),
    );
  }
}

/// `label` / `secondLine` 共用樣式（caption、半粗、`textSecondary`，
/// SPEC-004 §4.14「使用 design token」）。`AppText.caption` 不支援半粗字重
/// （僅 `emphasis` 布林 → `FontWeight.bold`），故不重用，直接建構。
class _LabelText extends StatelessWidget {
  const _LabelText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.caption.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// `sortable` 變體的互動實作：Tab 進入焦點順序、Space / Enter 觸發
/// [onSort]，語意播報依 SPEC-003 §3.4 S4（`sortA11yLabel` 隨 [order] 重建）。
class _SortableHeader extends StatefulWidget {
  const _SortableHeader({
    required this.label,
    required this.order,
    required this.onSort,
    required this.testKey,
  });

  final String label;
  final SortOrder order;
  final VoidCallback onSort;
  final Key testKey;

  @override
  State<_SortableHeader> createState() => _SortableHeaderState();
}

class _SortableHeaderState extends State<_SortableHeader> {
  /// 未聚焦時的邊框色：透明，僅焦點時（[AppColors.accent]）可見。
  /// 非語意色彩，不進 token 表。
  static const Color _unfocusedBorder = Colors.transparent; // color-exempt

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TableColumnHeader.sortable');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  String _orderLabel(AppLocalizations l10n) => switch (widget.order) {
    SortOrder.none => l10n.sortNone,
    SortOrder.asc => l10n.sortAscending,
    SortOrder.desc => l10n.sortDescending,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      key: widget.testKey,
      button: true,
      label: l10n.sortA11yLabel(widget.label, _orderLabel(l10n)),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: LayoutSize.hitTargetMin.h),
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onSort();
                  return null;
                },
              ),
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.accent
                      : _unfocusedBorder,
                ),
                borderRadius: BorderRadius.circular(Radius.sm.r),
              ),
              child: InkWell(
                onTap: () {
                  _focusNode.requestFocus();
                  widget.onSort();
                },
                focusNode: _focusNode,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(Radius.sm.r),
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: _LabelText(widget.label)),
                      if (widget.order != SortOrder.none) ...[
                        SizedBox(width: Space.xs.w),
                        AppIcon(
                          icon: widget.order == SortOrder.asc
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: IconSize.sm,
                          color: AppColors.accentStrong,
                        ),
                      ],
                    ],
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
