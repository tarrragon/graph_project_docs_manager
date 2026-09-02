/// 表格列容器（SPEC-004 §4.35、§5.9）。
///
/// 欄寬對齊表頭的水平格線列，三變體：`header`（欄首，配合 `columns` 決定
/// 欄數與寬度）、`ticket`（票列，欄序 ID / 標題 / 狀態 / 優先 / 標記）、
/// `step`（步驟列，欄序 序號 / 步驟名 / domain / 事件）。子件依變體固定
/// 型別序列（SPEC-004 4.35「slot 契約」），非任意 `Widget` 清單——`header`
/// 因欄首元件（`TableColumnHeader`，4.14）尚未建立，改以 `Widget` 承接
/// （與 `ListRow` leading/trailing 已記錄的契約差異同一慣例）。
///
/// **命名注意**：類別名稱因與 `package:flutter/widgets.dart` 內建的
/// `TableRow`（`Table` widget 用）撞名，改為 [AppTableRow]（依 `AppButton`
/// / `AppText` / `AppSnackBar` 既有撞名慣例，前綴 `App`）。契約名
/// （SPEC-004 4.35）仍為 `TableRow`，本檔類別名為實作層偏離，契約名對照
/// 說明由後續 DOC 票回填。
library;

import 'package:flutter/material.dart' show InkWell;
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';
import 'app_text.dart';
import 'badge.dart';
import 'badge_row.dart';
import 'issue_marker.dart';
import 'relation_item.dart';
import 'step_number.dart';

/// 欄規格（SPEC-004 4.35「slot 契約」`columns`）：固定寬或依比例填滿。
sealed class ColumnSpec {
  const ColumnSpec();

  /// 固定寬欄，`width` 傳 `LayoutSize.*` 常數（未縮放原始值，縮放於
  /// build 時以 `.w` 套用）。
  const factory ColumnSpec.fixed(double width) = _FixedColumnSpec;

  /// 填滿欄，依 [flex] 比例分配剩餘寬度，預設 1（等分）。
  const factory ColumnSpec.flex([int flex]) = _FlexColumnSpec;
}

class _FixedColumnSpec extends ColumnSpec {
  const _FixedColumnSpec(this.width);
  final double width;
}

class _FlexColumnSpec extends ColumnSpec {
  const _FlexColumnSpec([this.flex = 1]);
  final int flex;
}

/// 三變體（SPEC-004 4.35「變體」表）。
enum _TableRowVariant { header, ticket, step }

/// 表格列（SPEC-004 §4.35，契約名 `TableRow`；類別名因與 Flutter 內建
/// `TableRow` 撞名改為 [AppTableRow]，見檔頭「命名注意」）。
class AppTableRow extends StatelessWidget {
  const AppTableRow._({
    super.key,
    required this._variant,
    required this.columns,
    required this.cells,
    this.onTap,
    this.testKey,
  }) : assert(
         columns.length == cells.length,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'cells 數量須等於 columns 數量（SPEC-004 §5.9 子件數量上限 = 欄數）',
       );

  /// 欄首列。`columns` 決定欄數與寬度（傳 [ticketColumns] 或
  /// [stepColumns]，對齊所頭的資料列），`cells` 為對應的欄首 widget
  /// （型別見檔頭說明）。無點擊、無自身狀態集。
  const AppTableRow.header({
    Key? key,
    required List<ColumnSpec> columns,
    required List<Widget> cells,
  }) : this._(
         key: key,
         variant: _TableRowVariant.header,
         columns: columns,
         cells: cells,
       );

  /// 票列。欄序 ID / 標題 / 狀態 / 優先 / 標記，[marker] 可為 `null`
  /// （欄位保留但不渲染內容，維持欄寬對齊）。整列可點。
  AppTableRow.ticket({
    Key? key,
    required AppText id,
    required AppText title,
    required Badge status,
    required AppText priority,
    IssueMarker? marker,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: _TableRowVariant.ticket,
         columns: ticketColumns,
         cells: [id, title, status, priority, marker ?? const SizedBox.shrink()],
         onTap: onTap,
         testKey: testKey,
       );

  /// 步驟列。欄序 序號 / 步驟名 / domain / 事件。整列可點；domain 格另有
  /// 自己的點擊（`RelationItem`，不觸發列 `onTap`）。
  AppTableRow.step({
    Key? key,
    required StepNumber number,
    required AppText stepName,
    required RelationItem domain,
    required BadgeRow events,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: _TableRowVariant.step,
         columns: stepColumns,
         cells: [number, stepName, domain, events],
         onTap: onTap,
         testKey: testKey,
       );

  /// `ticket` 欄規格（SPEC-004 4.35「尺寸契約」欄規格 `ticket`）：ID 固定寬、
  /// 標題填滿、狀態固定寬、優先固定寬、標記固定寬。
  static const List<ColumnSpec> ticketColumns = [
    ColumnSpec.fixed(LayoutSize.ticketIdColumnWidth),
    ColumnSpec.flex(),
    ColumnSpec.fixed(LayoutSize.ticketStatusColumnWidth),
    ColumnSpec.fixed(LayoutSize.ticketPriorityColumnWidth),
    ColumnSpec.fixed(LayoutSize.ticketMarkerColumnWidth),
  ];

  /// `step` 欄規格（SPEC-004 4.35「尺寸契約」欄規格 `step`）：序號固定寬、
  /// 步驟名與事件兩個填滿欄等分（畫布 `1fr 118px 1fr`）、domain 固定寬。
  static const List<ColumnSpec> stepColumns = [
    ColumnSpec.fixed(LayoutSize.stepNumberColumnWidth),
    ColumnSpec.flex(),
    ColumnSpec.fixed(LayoutSize.stepDomainColumnWidth),
    ColumnSpec.flex(),
  ];

  /// 變體。
  final _TableRowVariant _variant;

  /// 欄規格，長度須等於 [cells] 長度。
  final List<ColumnSpec> columns;

  /// 依變體固定型別序列的欄子件（見各具名建構子文件）。
  final List<Widget> cells;

  /// 整列點選回呼；`ticket` / `step` 必填，`header` 不使用。
  final VoidCallback? onTap;

  /// 呼叫端定址 key（`card-tickets-<ticketId>` /
  /// `card-ucFlow-step-<stepId>`）；`ticket` / `step` 必填。
  final Key? testKey;

  bool get _isTappable => _variant != _TableRowVariant.header;

  Color get _borderColor => _variant == _TableRowVariant.header
      ? AppColors.borderStrong
      : AppColors.border;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
      child: SizedBox(
        height: LayoutSize.rowHeightRelaxed.h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _buildColumnChildren(),
        ),
      ),
    );

    final bordered = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: row,
    );

    if (!_isTappable) {
      return bordered;
    }

    return Semantics(
      key: testKey,
      button: true,
      label: _semanticLabel,
      child: InkWell(onTap: onTap, excludeFromSemantics: true, child: bordered),
    );
  }

  List<Widget> _buildColumnChildren() {
    final children = <Widget>[];
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: Space.md.w));
      }
      children.add(_buildColumn(columns[i], cells[i]));
    }
    return children;
  }

  Widget _buildColumn(ColumnSpec spec, Widget cell) {
    // 序號欄置中；其餘欄（含填滿欄的文字）維持起始對齊（SPEC-004 4.35
    // 「組合規則」對齊基準：格垂直置中；文字欄 start、優先欄 start、
    // 序號欄置中）。
    final aligned = _variant == _TableRowVariant.step && cell is StepNumber
        ? Center(child: cell)
        : Align(alignment: Alignment.centerLeft, child: cell);

    return switch (spec) {
      _FixedColumnSpec(width: final w) => SizedBox(width: w.w, child: aligned),
      _FlexColumnSpec(flex: final f) => Expanded(flex: f, child: aligned),
    };
  }

  /// `ticket` / `step` 的朗讀標籤：各格文字依序串接（SPEC-004 4.35
  /// 「無障礙」朗讀標籤，ticket 例：ID，標題，狀態，優先）。
  String get _semanticLabel {
    final parts = switch (_variant) {
      _TableRowVariant.ticket => [
          (cells[0] as AppText).text,
          (cells[1] as AppText).text,
          (cells[2] as Badge).label ?? '',
          (cells[3] as AppText).text,
        ],
      _TableRowVariant.step => [
          '${(cells[0] as StepNumber).number}',
          (cells[1] as AppText).text,
          (cells[2] as RelationItem).id,
        ],
      _TableRowVariant.header => const <String>[],
    };
    return parts.join('，');
  }
}
