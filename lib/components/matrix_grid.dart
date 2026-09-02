/// domain × UC 二維矩陣容器（SPEC-004 4.37、5.11）。
///
/// 欄首（[TableColumnHeader.twoLine]）與列首（可點 domain 名）釘選，格
/// （[MatrixCell]）與小計（[AppText.caption]）隨捲動移動。二維捲動委派
/// `two_dimensional_scrollables` 的 `TableView`（`pinnedRowCount: 1` 釘欄
/// 首列、`pinnedColumnCount: 1` 釘列首欄）。列高亮（`rowSelected`）與格選取
/// （`MatrixCell.selected`）皆由呼叫端持有狀態並經 [selectedDomainId] /
/// [selectedCell] 傳入，本容器不持有選取邏輯（SPEC-004 §2 傳值 + callback
/// 慣例）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../tokens/tokens.dart';
import 'app_text.dart';
import 'matrix_cell.dart';
import 'table_column_header.dart';

/// 矩陣一列的資料：列首 domain 名、該列各 UC 欄的格、小計。
///
/// [cells] 長度須等於 [MatrixGrid.columnHeaders] 長度，呼叫端負責對齊
/// （SPEC-004 5.11 子件契約「格數 = 列 × 欄」）。
class MatrixRow {
  const MatrixRow({
    required this.domainId,
    required this.domainName,
    required this.cells,
    required this.subtotal,
  });

  /// 列識別碼，供 [MatrixGrid.onSelectDomain] 回呼與 `action-domain-select-`
  /// 定址 key 使用。
  final String domainId;

  /// 列首顯示文字（domain 名），單行截斷（SPEC-004 4.37 內容政策）。
  final String domainName;

  /// 本列各 UC 欄的格，長度須等於欄首數。
  final List<MatrixCell> cells;

  /// 小計（`AppText.caption` 顯示，數字不截斷）。
  final int subtotal;
}

/// domain × UC 二維矩陣容器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [columnHeaders] | 是（1..無上限） | UC 欄首，逐一對應 [MatrixRow.cells] |
/// | [rows] | 是（可為空清單） | 逐列資料，`cells` 長度須等於 [columnHeaders] 長度 |
/// | [selectedDomainId] | 是 | 當前高亮列，`null` 表無高亮 |
/// | [selectedCell] | 是 | 當前選格（未用於本容器渲染，供呼叫端狀態一致性） |
/// | [onSelectDomain] | 是 | 點列首觸發，傳入該列 [MatrixRow.domainId] |
/// | [onClearSelection] | 是 | Esc（有選格時）觸發 |
/// | [scrollKey] | 是（`scroll-domain-matrix`） | 呼叫端定址 key |
class MatrixGrid extends StatelessWidget {
  const MatrixGrid({
    super.key,
    required this.columnHeaders,
    required this.rows,
    required this.selectedDomainId,
    required this.selectedCell,
    required this.onSelectDomain,
    required this.onClearSelection,
    required this.scrollKey,
  });

  /// UC 欄首，長度即欄數 N。
  final List<TableColumnHeader> columnHeaders;

  /// 逐列資料；每列 `cells` 長度須等於 [columnHeaders] 長度。
  final List<MatrixRow> rows;

  /// 當前高亮列的 domain id，`null` 表無高亮（`default` 態）。
  final String? selectedDomainId;

  /// 當前選格 `(rowId, colId)`，狀態存於呼叫端 provider（本容器不渲染
  /// 高亮以外的選格效果，選格視覺效果由 [MatrixCell] 自身承載）。
  final (String, String)? selectedCell;

  /// 點列首觸發，傳入該列 [MatrixRow.domainId]。
  final ValueChanged<String> onSelectDomain;

  /// Esc（有選格時）觸發（SPEC-004 4.37「互動反應」）。
  final VoidCallback onClearSelection;

  /// 呼叫端定址 key（`scroll-domain-matrix`）。
  final Key scrollKey;

  int get _columnCount => columnHeaders.length + 2; // 列首欄 + UC 欄 + 小計欄
  int get _rowCount => rows.length + 1; // 欄首列 + 資料列

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKey(event),
      child: TableView.builder(
        key: scrollKey,
        pinnedRowCount: 1,
        pinnedColumnCount: 1,
        columnCount: _columnCount,
        rowCount: _rowCount,
        columnBuilder: _buildColumnSpan,
        rowBuilder: _buildRowSpan,
        cellBuilder: _buildCell,
      ),
    );
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (selectedCell == null) return KeyEventResult.ignored;
    onClearSelection();
    return KeyEventResult.handled;
  }

  TableSpan _buildColumnSpan(int column) {
    final double extent = switch (column) {
      0 => LayoutSize.matrixLeadColumnWidth,
      final c when c == _columnCount - 1 => LayoutSize.matrixSubtotalWidth,
      _ => LayoutSize.matrixColumnWidth,
    };
    return TableSpan(extent: FixedTableSpanExtent(extent));
  }

  /// 資料列高含列間最小間距（SPEC-004 5.11「最小間距：列間 `Space.xxs`」）；
  /// 間距落於列底，格內容固定佔 [LayoutSize.rowHeightRelaxed]，由
  /// [_buildCell] 頂對齊裝入，使相鄰列之間留出 `Space.xxs` 空白。
  TableSpan _buildRowSpan(int row) {
    final double extent = row == 0
        ? LayoutSize.rowHeightRelaxed * 2 // twoLine 欄首列高（SPEC-004 4.37）
        : LayoutSize.rowHeightRelaxed + Space.xxs;
    return TableSpan(
      extent: FixedTableSpanExtent(extent),
      backgroundDecoration: row == 0
          ? const TableSpanDecoration(color: AppColors.surfaceBase)
          : null,
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    if (vicinity.row == 0) {
      return TableViewCell(child: _headerCell(vicinity.column));
    }
    final matrixRow = rows[vicinity.row - 1];
    final isRowSelected = matrixRow.domainId == selectedDomainId;
    return TableViewCell(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: LayoutSize.rowHeightRelaxed,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isRowSelected ? AppColors.surfaceIconTint : null,
              borderRadius: isRowSelected
                  ? BorderRadius.circular(Radius.md)
                  : null,
            ),
            child: _dataCell(vicinity.column, matrixRow),
          ),
        ),
      ),
    );
  }

  Widget _headerCell(int column) {
    if (column == 0) return const SizedBox.shrink();
    if (column == _columnCount - 1) return const SizedBox.shrink();
    return columnHeaders[column - 1];
  }

  Widget _dataCell(int column, MatrixRow matrixRow) {
    if (column == 0) {
      return _DomainHeaderCell(
        domainId: matrixRow.domainId,
        domainName: matrixRow.domainName,
        onSelectDomain: onSelectDomain,
      );
    }
    if (column == _columnCount - 1) {
      return Center(
        child: AppText(
          '${matrixRow.subtotal}',
          variant: AppTextVariant.caption,
        ),
      );
    }
    return matrixRow.cells[column - 1];
  }
}

/// 列首格：容器包成可點（SPEC-004 4.37 slot 契約「列首格由本容器包成可點，
/// 為容器內部互動區，非獨立元件」）。
class _DomainHeaderCell extends StatelessWidget {
  const _DomainHeaderCell({
    required this.domainId,
    required this.domainName,
    required this.onSelectDomain,
  });

  final String domainId;
  final String domainName;
  final ValueChanged<String> onSelectDomain;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('action-domain-select-$domainId'),
      button: true,
      label: domainName,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelectDomain(domainId),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.xs),
          child: AppText(
            domainName,
            variant: AppTextVariant.body,
            emphasis: true,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
