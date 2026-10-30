/// 泳道容器（SPEC-004 4.38、5.12）。
///
/// 泳道列（[AppText] 泳道名 + [SwimlaneNode] 置於步驟欄）× N 垂直、列間
/// 虛線；底部步驟箭頭列（裝飾，排除於語意樹）。節點的列與欄由呼叫端以
/// Layout 真實布局供給（SPEC-001 設計約束）——步驟欄寬非畫布量測值，本檔以私有常數
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

/// 泳道列種類（SPEC-004 4.38 `lanes` slot）。
enum SwimlaneLaneKind {
  /// 「畫面」列：列首走 i18n `swimlaneScreenLaneName`，不可點、不高亮。
  screen,

  /// domain 列：列首顯示 [SwimlaneLane.name] 原值，不經 i18n。
  domain,

  /// 「未定位」列：列首走 i18n `swimlaneUnplacedLaneName`，不可點、不高亮。
  unplaced,
}

/// 邊形狀（SPEC-004 4.38 `edges` slot）。
enum SwimlaneEdgeShape { straight, arc }

/// 一條步驟間的邊：起訖步驟欄號（0 起算）與形狀。
class SwimlaneEdge {
  const SwimlaneEdge({
    required this.fromColumn,
    required this.toColumn,
    required this.shape,
  });

  final int fromColumn;
  final int toColumn;
  final SwimlaneEdgeShape shape;
}

/// 一條泳道：泳道名 + 節點（節點與其所在步驟欄，0 起算）。
class SwimlaneLane {
  const SwimlaneLane({
    required this.name,
    required this.nodes,
    this.domainId,
    this.kind = SwimlaneLaneKind.domain,
  });

  /// 泳道名（資料值），對映 [AppText.body] 泳道名 slot。僅 `kind` 為
  /// [SwimlaneLaneKind.domain] 時作為列首顯示。
  final String name;

  /// 列種類，預設 [SwimlaneLaneKind.domain]。
  final SwimlaneLaneKind kind;

  /// 該泳道對映的 domain 識別碼；`null` 時泳道名格維持唯讀（無
  /// [SwimlaneGrid.onSelectDomain] 輸入端，呼叫端未提供 domain 對映關係）。
  final String? domainId;

  /// 該泳道的節點清單：`(節點, 所在步驟欄索引)`。每欄至多一節點
  /// （SPEC-004 5.12「不重疊」）由 `swim_lane_layout.dart` 保證：欄號是步驟
  /// 的排列，每步驟獨佔一欄；非本元件強制。
  final List<(SwimlaneNode node, int column)> nodes;
}

/// 泳道容器。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [lanes] | 是（1..無上限） | 泳道清單，垂直排列 |
/// | [laneHighlight] | 否 | 選中 domain 的 domainId（比對 [SwimlaneLane.domainId]）；命中列底改 [AppColors.surfaceIconTint] |
/// | [onSelectDomain] | 否 | 點泳道名格觸發，傳入該列 [SwimlaneLane.domainId]；`null`
/// 或該列 `domainId` 為 `null` 時泳道名格維持唯讀（與 `MatrixGrid.onSelectDomain`
/// 同一「選 domain」動作，兩模式共用同一點擊區域與焦點行為） |
/// | [scrollKey] | 是 | `scroll-domain-swimlane` 定址 key |
/// | [dragKey] | 是 | `drag-domain-swimlane` 定址 key |
class SwimlaneGrid extends StatefulWidget {
  const SwimlaneGrid({
    super.key,
    required this.lanes,
    required this.scrollKey,
    required this.dragKey,
    this.laneHighlight,
    this.onSelectDomain,
    this.edges = const [],
    this.locateColumn,
  });

  /// 欄定位入口（SPEC-004 4.38）：步驟欄索引（0 起算）；與列定位同一
  /// post-frame 另做水平 `jumpTo` 使該欄與 viewport 相交。`null` 或沒有
  /// 列定位（[laneHighlight] 為 `null`）時不做水平捲動。
  final int? locateColumn;

  /// 泳道清單（1..無上限）；列數取自輸入。
  final List<SwimlaneLane> lanes;

  /// 步驟間的邊；空清單時不渲染邊列。
  final List<SwimlaneEdge> edges;

  /// 選中 domain 的 domainId；`null` 時無列高亮。容器無自身狀態集，本欄位
  /// 由呼叫端傳入（SPEC-004 4.38「狀態矩陣」）。
  final String? laneHighlight;

  /// 點泳道名格觸發，傳入該列 [SwimlaneLane.domainId]。`null` 時泳道名格
  /// 維持既有唯讀樣式（既有呼叫點不受影響）。
  final ValueChanged<String>? onSelectDomain;

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
    final laneChanged = widget.laneHighlight != oldWidget.laneHighlight;
    final columnChanged = widget.locateColumn != oldWidget.locateColumn;
    if ((laneChanged || columnChanged) && widget.laneHighlight != null) {
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
    _jumpToColumn();
    final index = widget.lanes.indexWhere(_isHighlighted);
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

  /// 欄定位：釘選的泳道名欄不計入捲動範圍，步驟欄 c 的左緣 offset 為
  /// `c * 欄寬`；jumpTo 使該欄緊貼釘選欄右側（與 viewport 相交）。
  void _jumpToColumn() {
    final column = widget.locateColumn;
    if (column == null || !_hController.hasClients) {
      return;
    }
    final position = _hController.position;
    final colLeft = column * _stepColumnWidth.w;
    final colRight = colLeft + _stepColumnWidth.w;
    final current = position.pixels;
    if (colLeft >= current &&
        colRight <= current + position.viewportDimension) {
      return;
    }
    _hController.jumpTo(colLeft.clamp(0.0, position.maxScrollExtent));
  }

  /// 只有 domain 列受 [SwimlaneGrid.laneHighlight] 高亮，以 domainId 精確比對。
  bool _isHighlighted(SwimlaneLane lane) =>
      lane.kind == SwimlaneLaneKind.domain &&
      lane.domainId == widget.laneHighlight;

  int get _stepColumnCount {
    var maxColumn = _maxNodeColumn;
    for (final edge in widget.edges) {
      maxColumn = math.max(maxColumn, math.max(edge.fromColumn, edge.toColumn));
    }
    return maxColumn < 0 ? 1 : maxColumn + 1;
  }

  int get _maxNodeColumn {
    var maxColumn = -1;
    for (final lane in widget.lanes) {
      for (final entry in lane.nodes) {
        if (entry.$2 > maxColumn) {
          maxColumn = entry.$2;
        }
      }
    }
    return maxColumn;
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
        rowCount: laneCount + 1 + (widget.edges.isEmpty ? 0 : 1),
        columnBuilder: (column) => TableSpan(
          extent: FixedTableSpanExtent(
            column == 0 ? LayoutSize.laneLabelWidth.w : _stepColumnWidth.w,
          ),
        ),
        rowBuilder: (row) {
          if (row == laneCount) {
            return TableSpan(extent: FixedTableSpanExtent(_arrowRowHeight.h));
          }
          if (row > laneCount) {
            return TableSpan(extent: FixedTableSpanExtent(_edgeRowHeight.h));
          }
          final highlighted = _isHighlighted(widget.lanes[row]);
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
          if (vicinity.row > laneCount) {
            if (vicinity.column == 0) {
              return const TableViewCell(child: SizedBox.shrink());
            }
            // 整個邊列合併為單一 cell（欄 1..末欄）：TableView 對合併 cell
            // 只要任一部分在 viewport 內即建構並整塊佈局，邊段不依附起始格，
            // 起點欄捲出後仍隨畫布 1:1 位移繪製（SPEC-004 4.38）。
            return TableViewCell(
              columnMergeStart: 1,
              columnMergeSpan: stepColumnCount,
              child: _buildEdgeRow(),
            );
          }
          return TableViewCell(
            child: _buildLaneCell(
              context,
              l10n,
              widget.lanes[vicinity.row],
              vicinity.column,
              widget.onSelectDomain,
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
    ValueChanged<String>? onSelectDomain,
  ) {
    if (column == 0) {
      final domainId = lane.domainId;
      final title = switch (lane.kind) {
        SwimlaneLaneKind.screen => l10n.swimlaneScreenLaneName,
        SwimlaneLaneKind.unplaced => l10n.swimlaneUnplacedLaneName,
        SwimlaneLaneKind.domain => lane.name,
      };
      if (lane.kind != SwimlaneLaneKind.domain ||
          domainId == null ||
          onSelectDomain == null) {
        return Semantics(
          label: l10n.laneA11yLabel(title),
          container: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText.singleLine(title),
            ),
          ),
        );
      }
      // 與 MatrixGrid._DomainHeaderCell 同一「選 domain」動作，共用點擊
      // 區域與焦點行為（SPEC-003 §3.1）。
      return Semantics(
        key: Key('action-domain-select-$domainId'),
        button: true,
        label: l10n.laneA11yLabel(lane.name),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onSelectDomain(domainId),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText.singleLine(lane.name),
            ),
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

  /// 邊列：整列一個合併 cell，每條邊依起訖欄號定位，寬度只涵蓋自身欄段
  /// （非全寬），邊數多時不放大每條邊的繪製面積。
  ///
  /// 成本：最左可見欄跨欄時合併 cell 的錨點改變，整個邊列重建，成本為
  /// O(邊數)；在同一欄內捲動只做圖層位移，不重建。
  Widget _buildEdgeRow() {
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final edge in widget.edges) _buildEdgeShape(edge)],
      ),
    );
  }

  Widget _buildEdgeShape(SwimlaneEdge edge) {
    final span = (edge.toColumn - edge.fromColumn).abs() + 1;
    return Positioned(
      left: _stepColumnWidth.w * math.min(edge.fromColumn, edge.toColumn),
      top: 0,
      bottom: 0,
      width: _stepColumnWidth.w * span,
      child: CustomPaint(
        key: Key(
          'swimlane-edge-${edge.shape.name}-${edge.fromColumn}-${edge.toColumn}',
        ),
        painter: _EdgePainter(edge.shape),
      ),
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

/// 步驟欄寬：固定常數，非畫布量測值（SPEC-004 4.38「尺寸契約」明文
/// 不設 token）。
const double _stepColumnWidth = 96;

/// 底部箭頭列高：裝飾列，非畫布量測值，理由同 [_stepColumnWidth]。
const double _arrowRowHeight = 28;

/// 邊列高：裝飾列，非畫布量測值，理由同 [_stepColumnWidth]。
const double _edgeRowHeight = 28;

/// 邊繪製：`straight` 為水平直線，`arc` 為向上拱起的弧線。
class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.shape);

  final SwimlaneEdgeShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final midY = size.height / 2;
    switch (shape) {
      case SwimlaneEdgeShape.straight:
        canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
      case SwimlaneEdgeShape.arc:
        final path = Path()
          ..moveTo(0, midY)
          ..quadraticBezierTo(size.width / 2, 0, size.width, midY);
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => oldDelegate.shape != shape;
}

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
  ) => null;
}
