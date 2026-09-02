/// 泳道容器（SPEC-004 4.38、5.12）。
///
/// 泳道列（[AppText] 泳道名 + [SwimlaneNode] 置於步驟欄）× N 垂直、列間
/// 虛線；底部步驟箭頭列（裝飾，排除於語意樹）。0.1 以寫死座標的假資料
/// 靜態排版（SPEC-001 設計約束）——步驟欄寬非畫布量測值，本檔以私有常數
/// [_stepColumnWidth] 承載，SPEC-004 4.38「尺寸契約」明文「不設 token」。
///
/// 二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`）委派
/// `package:two_dimensional_scrollables` 的 [TableView]（`docs/tech-decisions.md`
/// 對矩陣／泳道視圖的定案）：泳道名欄以 `pinnedColumnCount: 1` 釘選；
/// `diagonalDragBehavior: DiagonalDragBehavior.free` 允許斜向拖曳雙軸同時
/// 位移（原巢狀 `SingleChildScrollView` 方案兩個正交方向的內建拖曳辨識器
/// 在同一手勢仲裁中互斥，斜向拖曳只有一軸生效，不滿足「位移比例 1:1」
/// 契約，正是本套件要解的問題）。滾輪與拖曳共用 [_hController] /
/// [_vController] 這組 `ScrollController`（`horizontalDetails` /
/// `verticalDetails` 皆掛同一顆 controller），滿足 5.12「與捲軸共用同一
/// offset」語意。至邊界生硬停止、無慣性：兩軸皆掛
/// [_NoInertiaScrollPhysics]（`ClampingScrollPhysics` 已提供無回彈，本類
/// 另關閉 ballistic 模擬取消放開後的慣性滑動，SPEC-004 4.38「互動反應」、
/// SPEC-003 §1.3）。
///
/// **契約值實測**：底部箭頭列原計畫以 `trailingPinnedRowCount: 1` 釘選在
/// 底，實測 `trailingPinnedRowCount` 搭配 `ScrollController.jumpTo` 大距離
/// 跳轉會觸發 `two_dimensional_scrollables` 0.5.4 內部
/// `_TwoDimensionalViewportElement._reuseChild` 的
/// `elementToReuse != null` 斷言失敗（`row == laneCount` 的釘選列找不到
/// 可重用的 element，與跳轉距離無關，小到 6 列同樣觸發）；改為一般
/// （非釘選）末列即可正常運作，且無此類例外。此為套件限制的實作層面
/// 迴避，非契約值變更——底部箭頭列位置仍在視覺上位於所有泳道列之後。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_icon.dart';
import 'app_text.dart';
import 'swimlane_node.dart';

/// 一條泳道：泳道名 + 節點（節點與其所在步驟欄，0 起算）。
class SwimlaneLane {
  const SwimlaneLane({required this.name, required this.nodes});

  /// 泳道名（資料值），對映 [AppText.body] 泳道名 slot。
  final String name;

  /// 該泳道的節點清單：`(節點, 所在步驟欄索引)`。假資料須保證每欄至多
  /// 一節點（SPEC-004 5.12「不重疊」，由測試斷言，非本元件強制）。
  final List<(SwimlaneNode node, int column)> nodes;
}

/// 泳道容器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [lanes] | 是（1..無上限） | 泳道清單，垂直排列 |
/// | [laneHighlight] | 否 | 選中 domain 的泳道名；命中列底改 [AppColors.surfaceIconTint] |
/// | [scrollKey] | 是 | `scroll-domain-swimlane` 定址 key |
/// | [dragKey] | 是 | `drag-domain-swimlane` 定址 key |
class SwimlaneGrid extends StatefulWidget {
  const SwimlaneGrid({
    super.key,
    required this.lanes,
    required this.scrollKey,
    required this.dragKey,
    this.laneHighlight,
  });

  /// 泳道清單（1..無上限）。
  final List<SwimlaneLane> lanes;

  /// 選中 domain 的泳道名；`null` 時無列高亮。容器無自身狀態集，本欄位
  /// 由呼叫端傳入（SPEC-004 4.38「狀態矩陣」）。
  final String? laneHighlight;

  /// `scroll-domain-swimlane` 捲動互動定址 key，掛在 [TableView] 本身
  /// （滾輪與捲軸互動的定址對象）。
  final Key scrollKey;

  /// `drag-domain-swimlane` 拖曳互動定址 key，以 `KeyedSubtree` 包裹同一顆
  /// [TableView]——拖曳與捲動是同一個互動表面，兩個 key 定址的是同一組
  /// offset（見本檔 dartdoc）。
  final Key dragKey;

  @override
  State<SwimlaneGrid> createState() => _SwimlaneGridState();
}

class _SwimlaneGridState extends State<SwimlaneGrid> {
  final ScrollController _hController = ScrollController();
  final ScrollController _vController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.laneHighlight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToHighlight());
    }
  }

  @override
  void didUpdateWidget(covariant SwimlaneGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.laneHighlight != oldWidget.laneHighlight &&
        widget.laneHighlight != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToHighlight());
    }
  }

  @override
  void dispose() {
    _hController.dispose();
    _vController.dispose();
    super.dispose();
  }

  /// 自詳情卡「在泳道中檢視」進入：直接 `jumpTo` 使命中列 rect 與
  /// viewport 有交集（SPEC-004 4.38「互動反應」，不用漸進動畫）。
  void _jumpToHighlight() {
    if (!mounted || !_vController.hasClients) {
      return;
    }
    final index = widget.lanes.indexWhere(
      (lane) => lane.name == widget.laneHighlight,
    );
    if (index < 0) {
      return;
    }
    final rowHeight = LayoutSize.laneRowHeight.h;
    final rowTop = index * rowHeight;
    final rowBottom = rowTop + rowHeight;
    final viewport = _vController.position.viewportDimension;
    final current = _vController.position.pixels;
    final alreadyVisible = rowTop >= current && rowBottom <= current + viewport;
    if (alreadyVisible) {
      return;
    }
    final target = rowBottom > current + viewport
        ? rowBottom - viewport
        : rowTop;
    _vController.jumpTo(
      target.clamp(0.0, _vController.position.maxScrollExtent),
    );
  }

  int get _stepColumnCount {
    var maxColumn = -1;
    for (final lane in widget.lanes) {
      for (final entry in lane.nodes) {
        if (entry.$2 > maxColumn) {
          maxColumn = entry.$2;
        }
      }
    }
    return maxColumn < 0 ? 1 : maxColumn + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final laneCount = widget.lanes.length;
    final stepColumnCount = _stepColumnCount;

    return KeyedSubtree(
      key: widget.dragKey,
      child: TableView.builder(
        key: widget.scrollKey,
        diagonalDragBehavior: DiagonalDragBehavior.free,
        horizontalDetails: ScrollableDetails.horizontal(
          controller: _hController,
          physics: const _NoInertiaScrollPhysics(),
        ),
        verticalDetails: ScrollableDetails.vertical(
          controller: _vController,
          physics: const _NoInertiaScrollPhysics(),
        ),
        pinnedColumnCount: 1,
        // +1：欄 0 為釘選的泳道名欄；列 laneCount 為底部箭頭列（一般列，
        // 非 trailingPinnedRowCount 釘選——實測 trailingPinnedRowCount 搭配
        // jumpTo 大距離跳轉會觸發 two_dimensional_scrollables 0.5.4 內部
        // child-reuse 例外，見本檔頂端 dartdoc「契約值實測」段）。
        columnCount: stepColumnCount + 1,
        rowCount: laneCount + 1,
        columnBuilder: (column) => TableSpan(
          extent: FixedTableSpanExtent(
            column == 0 ? LayoutSize.laneLabelWidth.w : _stepColumnWidth.w,
          ),
        ),
        rowBuilder: (row) {
          if (row == laneCount) {
            return TableSpan(extent: FixedTableSpanExtent(_arrowRowHeight.h));
          }
          final highlighted = widget.lanes[row].name == widget.laneHighlight;
          return TableSpan(
            extent: FixedTableSpanExtent(LayoutSize.laneRowHeight.h),
            backgroundDecoration: highlighted
                ? const TableSpanDecoration(color: AppColors.surfaceIconTint)
                : null,
            // 列間虛線：與 Section 容器（section.dart）的私有虛線繪製類別
            // 視覺重複（同色 token、同線寬、同短劃長度），因該類為
            // section.dart 私有型別本票不改該檔，改在本檔自寫等效實作；
            // 待後續回填共用元件庫時應抽出共用的 dashed painter 供兩者引用。
            foregroundDecoration: row < laneCount
                ? const _DashedBottomDecoration()
                : null,
          );
        },
        cellBuilder: (context, vicinity) {
          if (vicinity.row == laneCount) {
            return TableViewCell(child: _buildArrowCell(vicinity.column));
          }
          return TableViewCell(
            child: _buildLaneCell(
              context,
              l10n,
              widget.lanes[vicinity.row],
              vicinity.column,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLaneCell(
    BuildContext context,
    AppLocalizations l10n,
    SwimlaneLane lane,
    int column,
  ) {
    if (column == 0) {
      return Semantics(
        label: l10n.laneA11yLabel(lane.name),
        container: true,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppText(lane.name, maxLines: 1),
          ),
        ),
      );
    }
    final stepColumn = column - 1;
    final node = lane.nodes
        .where((entry) => entry.$2 == stepColumn)
        .map((entry) => entry.$1)
        .firstOrNull;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xs.w),
      child: Center(child: node ?? const SizedBox.shrink()),
    );
  }

  Widget _buildArrowCell(int column) {
    if (column == 0) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: Center(
        child: AppIcon(
          icon: Icons.arrow_forward,
          size: IconSize.sm,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }
}

/// 步驟欄寬：假資料座標值，非畫布量測值（SPEC-004 4.38「尺寸契約」明文
/// 不設 token）。
const double _stepColumnWidth = 96;

/// 底部箭頭列高：裝飾列，非畫布量測值，理由同 [_stepColumnWidth]。
const double _arrowRowHeight = 28;

/// 泳道列的列間虛線裝飾：於列底畫等距短劃。與 Section 容器
/// （section.dart）的私有虛線繪製類別視覺等效（同色
/// `AppColors.borderStrong`、線寬 1、短劃 4、間隔 3），因該類為私有型別
/// 無法跨檔重用，本檔自寫一份；待後續回填共用元件庫票次時應抽出共用實作
/// （見本檔 rowBuilder 的行內註解）。
class _DashedBottomDecoration extends TableSpanDecoration {
  const _DashedBottomDecoration();

  static const double _strokeWidth = 1;
  static const double _dashWidth = 4;
  static const double _dashGap = 3;

  @override
  void paint(TableSpanDecorationPaintDetails details) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = _strokeWidth;
    final y = details.rect.bottom;
    var x = details.rect.left;
    while (x < details.rect.right) {
      final segmentEnd = math.min(x + _dashWidth, details.rect.right);
      details.canvas.drawLine(Offset(x, y), Offset(segmentEnd, y), paint);
      x += _dashWidth + _dashGap;
    }
  }
}

/// 無慣性 clamping 捲動物理：拖曳位移 1:1 反映於 offset、至邊界生硬停止
/// （`ClampingScrollPhysics` 已提供無回彈），並關閉放開後的 ballistic
/// 模擬取消慣性滑動（SPEC-004 4.38「互動反應」、SPEC-003 §1.3）。
class _NoInertiaScrollPhysics extends ClampingScrollPhysics {
  const _NoInertiaScrollPhysics({super.parent});

  @override
  _NoInertiaScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _NoInertiaScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) =>
      null;
}
