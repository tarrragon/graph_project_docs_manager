/// 表格容器（SPEC-004 §4.36、§5.10）。
///
/// `TableRow.header` 釘選於頂 + `TableRow` 資料列垂直堆疊；資料列以
/// [AppDataTableVariant.virtual]（`ListView.builder` + 固定
/// `LayoutSize.rowHeightRelaxed` `itemExtent` 虛擬化，Ticket 清單用）或
/// [AppDataTableVariant.plain]（一般 `ListView`，UC Flow 步驟表用）呈現。
/// 本容器無自身狀態集，空資料由呼叫端改渲染 `EmptyState`（4.36「狀態矩陣」）。
///
/// `plain` 變體另可接受 [appendix]（事件流小表，SPEC-004 §5.10 slot 契約）
/// ——接在最後一列之下、共用本容器的捲動（不持有自身捲動）。[scrollKey] 為
/// `null` 時本實例即扮演「他人的 appendix」角色：不建立自身 `ListView`，只
/// 以 `header` + `rows` 疊放，交由承接它的外層 [AppDataTable] 捲動。
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
  AppDataTable({
    super.key,
    required this.variant,
    required this.columns,
    required this.header,
    required this.rows,
    this.scrollKey,
    this.appendix,
  }) : assert(
         appendix == null || variant == AppDataTableVariant.plain,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'appendix 僅 plain 變體接受（SPEC-004 §5.10 slot 契約）',
       ),
       assert(
         appendix == null || appendix.appendix == null,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'appendix 自身不得再帶 appendix（SPEC-004 §5.10 slot 契約）',
       ),
       assert(
         scrollKey != null || variant == AppDataTableVariant.plain,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'virtual 變體不接受 appendix 角色（scrollKey 為 null），SPEC-004 §5.10 slot 契約',
       );

  /// 呈現方式，決定 [rows] 是否虛擬化（4.36「變體」）。
  final AppDataTableVariant variant;

  /// 欄規格（SPEC-004 4.36「slot 契約」`columns`），與 [header] 內部攜帶
  /// 的欄規格一致，供呼叫端與測試直接引用（不需自 [header] 反查）。
  final List<ColumnSpec> columns;

  /// 表頭列，恰 1，釘選於頂（`AppTableRow.header` 建構）；本實例作為
  /// [appendix] 時隨外層捲動、不釘選。
  final AppTableRow header;

  /// 資料列（`AppTableRow.ticket`、`AppTableRow.step` 或
  /// `AppTableRow.eventFlow`，單一變體），0..無上限。
  final List<AppTableRow> rows;

  /// 捲動區定址 key（`scroll-tickets-list` / `scroll-ucFlow-steps`）；為
  /// `null` 時本實例扮演他人的 [appendix]（不持有捲動，SPEC-004 §5.10
  /// slot 契約）。
  final Key? scrollKey;

  /// 事件流小表（`rows` 為 `eventFlow`，無 `scrollKey`），接在最後一列
  /// 之下、共用本容器的捲動；只有 `plain` 變體接受，0..1，其自身不得再帶
  /// `appendix`（SPEC-004 §5.10 slot 契約，1.35 新增）。
  final AppDataTable? appendix;

  @override
  Widget build(BuildContext context) {
    if (scrollKey == null) {
      // 扮演他人的 appendix：不持有自身捲動，隨外層 ListView 內容堆疊。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [header, ...rows],
      );
    }
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
      AppDataTableVariant.plain => ListView(
          key: scrollKey,
          children: [
            ...rows,
            if (appendix != null) ...[
              SizedBox(height: Space.lg.h),
              appendix!,
            ],
          ],
        ),
    };
  }
}
