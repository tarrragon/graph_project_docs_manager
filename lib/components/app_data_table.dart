/// 表格容器（SPEC-004 §4.36、§5.10）。
///
/// `TableRow.header` 釘選於頂 + `TableRow` 資料列垂直堆疊；資料列以
/// [AppDataTableVariant.virtual]（`ListView.builder` + 固定
/// `LayoutSize.rowHeightRelaxed` `itemExtent` 虛擬化，Ticket 清單用）或
/// [AppDataTableVariant.plain]（一般 `ListView`，UC Flow 步驟表用）呈現。
/// 本容器無自身狀態集，空資料由呼叫端改渲染 `EmptyState`（4.36「狀態矩陣」）。
///
/// **命名注意**：類別名稱因與 `package:flutter/material.dart` 內建的
/// `DataTable` 撞名，改為 [AppDataTable]（依 `AppTableRow` / `AppButton`
/// 既有撞名慣例，前綴 `App`）。契約名（SPEC-004 4.36）仍為 `DataTable`，
/// 本檔類別名為實作層偏離，契約名對照說明由後續 DOC 票回填。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../tokens/tokens.dart';
import 'app_table_row.dart';

/// 資料列呈現方式（SPEC-004 4.36「變體」）。
enum AppDataTableVariant {
  /// `ListView.builder` + 固定 `itemExtent`（`LayoutSize.rowHeightRelaxed`）
  /// 虛擬化；不分頁。Ticket 清單（真實規模不低於 1300 筆）。
  virtual,

  /// 一般 `ListView`。UC Flow 步驟表。
  plain,
}

/// 表格容器（SPEC-004 §4.36，契約名 `DataTable`；類別名因與 Flutter 內建
/// `DataTable` 撞名改為 [AppDataTable]，見檔頭「命名注意」）。
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.variant,
    required this.columns,
    required this.header,
    required this.rows,
    required this.scrollKey,
  });

  /// 呈現方式，決定 [rows] 是否虛擬化（4.36「變體」）。
  final AppDataTableVariant variant;

  /// 欄規格（SPEC-004 4.36「slot 契約」`columns`），與 [header] 內部攜帶
  /// 的欄規格一致，供呼叫端與測試直接引用（不需自 [header] 反查）。
  final List<ColumnSpec> columns;

  /// 表頭列，恰 1，釘選於頂（`AppTableRow.header` 建構）。
  final AppTableRow header;

  /// 資料列（`AppTableRow.ticket` 或 `AppTableRow.step`，單一變體），
  /// 0..無上限。
  final List<AppTableRow> rows;

  /// 捲動區定址 key（`scroll-tickets-list` / `scroll-ucFlow-steps`）。
  final Key scrollKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, Expanded(child: _buildRows())],
    );
  }

  Widget _buildRows() {
    return switch (variant) {
      AppDataTableVariant.virtual => ListView.builder(
          key: scrollKey,
          itemExtent: LayoutSize.rowHeightRelaxed.h,
          itemCount: rows.length,
          itemBuilder: (context, index) => rows[index],
        ),
      AppDataTableVariant.plain => ListView(key: scrollKey, children: rows),
    };
  }
}
