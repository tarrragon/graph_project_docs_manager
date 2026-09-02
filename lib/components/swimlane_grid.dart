/// 泳道容器（SPEC-004 4.38、5.12）。
///
/// 泳道列（[AppText] 泳道名 + [SwimlaneNode] 置於步驟欄）× N 垂直、列間
/// 虛線；底部步驟箭頭列（裝飾，排除於語意樹）。0.1 以寫死座標的假資料
/// 靜態排版（SPEC-001 設計約束）——步驟欄寬非畫布量測值，本檔以私有常數
/// [_stepColumnWidth] 承載，SPEC-004 4.38「尺寸契約」明文「不設 token」。
///
/// 二維捲動 + 拖曳（`scroll-domain-swimlane`、`drag-domain-swimlane`）共用
/// 同一組 offset：以單一 `(_dx, _dy)` state 承載，滾輪（`Listener` 收
/// `PointerScrollEvent`）與拖曳（`GestureDetector.onPanUpdate`）兩種輸入
/// 路徑都直接改變同一組欄位，非各自建立獨立的捲動狀態。位移比例 1:1、
/// 至邊界生硬停止、無慣性：以 `clamp` 手動限制 offset 範圍，不經
/// `Scrollable` 的 ballistic 慣性模擬（SPEC-004 4.38「互動反應」、
/// SPEC-003 §1.3）。未採巢狀 `SingleChildScrollView`（水平 + 垂直）：兩個
/// 正交方向的內建拖曳辨識器在同一手勢仲裁中互斥，斜向拖曳只有一軸生效，
/// 無法滿足「位移比例 1:1」（雙軸同時）契約。
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  /// `scroll-domain-swimlane` 捲動互動定址 key（滾輪 `Listener`）。
  final Key scrollKey;

  /// `drag-domain-swimlane` 拖曳互動定址 key（`GestureDetector`），與
  /// [scrollKey] 共用同一組 offset（見本檔 dartdoc）。
  final Key dragKey;

  @override
  State<SwimlaneGrid> createState() => _SwimlaneGridState();
}

class _SwimlaneGridState extends State<SwimlaneGrid> {
  double _dx = 0;
  double _dy = 0;

  double _maxDx = 0;
  double _maxDy = 0;

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

  /// 自詳情卡「在泳道中檢視」進入：直接改 offset 使命中列 rect 與
  /// viewport 有交集（SPEC-004 4.38「互動反應」，不用漸進動畫）。
  void _jumpToHighlight() {
    if (!mounted) {
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
    // _maxDy 於上一次 build 已依當時 viewport 算好；viewport 高度用
    // `_maxDy` 反推不可行（無獨立欄位存 viewport 尺寸），改由呼叫端
    // 觸發後的下一次 build 以 LayoutBuilder 現算的 viewport 判斷。
    setState(() {
      final alreadyVisible = rowTop >= _dy && rowBottom <= _dy + _lastViewportHeight;
      if (!alreadyVisible) {
        final target = rowBottom > _dy + _lastViewportHeight
            ? rowBottom - _lastViewportHeight
            : rowTop;
        _dy = target.clamp(0.0, _maxDy);
      }
    });
  }

  double _lastViewportHeight = 0;

  void _applyDelta(Offset delta) {
    setState(() {
      _dx = (_dx - delta.dx).clamp(0.0, _maxDx);
      _dy = (_dy - delta.dy).clamp(0.0, _maxDy);
    });
  }

  int get _columnCount {
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
    final columnCount = _columnCount;
    final contentWidth =
        LayoutSize.laneLabelWidth.w + columnCount * _stepColumnWidth.w;
    final contentHeight =
        widget.lanes.length * LayoutSize.laneRowHeight.h + _arrowRowHeight.h;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : contentWidth;
        final viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : contentHeight;
        _maxDx = math.max(0.0, contentWidth - viewportWidth);
        _maxDy = math.max(0.0, contentHeight - viewportHeight);
        _lastViewportHeight = viewportHeight;
        _dx = _dx.clamp(0.0, _maxDx);
        _dy = _dy.clamp(0.0, _maxDy);

        return ClipRect(
          child: Listener(
            key: widget.scrollKey,
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _applyDelta(-event.scrollDelta);
              }
            },
            child: GestureDetector(
              key: widget.dragKey,
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => _applyDelta(details.delta),
              child: Transform.translate(
                offset: Offset(-_dx, -_dy),
                // 內容尺寸可能大於 viewport（二維捲動的前提）；祖先
                // `LayoutBuilder` 常給出 tight 上界，`SizedBox` 的
                // `enforce()` 會把內容夾回 viewport 大小。`OverflowBox`
                // 忽略父層傳入約束，讓內容依真實內容尺寸排版，超出部分
                // 由外層 `ClipRect` 裁切、由 `Transform.translate` 位移
                // 顯示範圍。
                child: OverflowBox(
                  minWidth: contentWidth,
                  maxWidth: contentWidth,
                  minHeight: contentHeight,
                  maxHeight: contentHeight,
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final lane in widget.lanes)
                        _buildLaneRow(context, l10n, lane, columnCount),
                      _buildArrowRow(columnCount),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLaneRow(
    BuildContext context,
    AppLocalizations l10n,
    SwimlaneLane lane,
    int columnCount,
  ) {
    final nodesByColumn = <int, SwimlaneNode>{
      for (final entry in lane.nodes) entry.$2: entry.$1,
    };
    final highlighted = lane.name == widget.laneHighlight;

    return Semantics(
      label: l10n.laneA11yLabel(lane.name),
      container: true,
      child: Container(
        height: LayoutSize.laneRowHeight.h,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.surfaceIconTint : null,
          border: Border(
            bottom: BorderSide(color: AppColors.borderStrong, width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: LayoutSize.laneLabelWidth.w,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(lane.name, maxLines: 1),
                ),
              ),
            ),
            for (var column = 0; column < columnCount; column++)
              SizedBox(
                width: _stepColumnWidth.w,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: Space.xs.w),
                  child: Center(
                    child: nodesByColumn[column] ?? const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrowRow(int columnCount) {
    return ExcludeSemantics(
      child: SizedBox(
        height: _arrowRowHeight.h,
        child: Row(
          children: [
            SizedBox(width: LayoutSize.laneLabelWidth.w),
            for (var column = 0; column < columnCount; column++)
              SizedBox(
                width: _stepColumnWidth.w,
                child: Center(
                  child: AppIcon(
                    icon: Icons.arrow_forward,
                    size: IconSize.sm,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
          ],
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
