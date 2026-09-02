/// 問題標記（SPEC-004 §4.6）。
///
/// 修飾既有節點或欄位的問題標記，可點擊跳轉破洞報告（SPEC-001 FR-05 兩級
/// 損壞 + 追溯缺口）。三變體皆恆可用（無 `disabled` 態，SPEC-004 4.6
/// 「跳轉破洞報告恆可用」）、顯示皆靜態（不做閃爍或呼吸動畫）。
///
/// | 變體 | 用途 |
/// |------|------|
/// | [IssueMarker.damagedEdge] | 邊損壞：虛線框包住 [child]（`RelationItem`），child 文字色不覆寫 |
/// | [IssueMarker.damagedDetail] | 詳情損壞：警示圖示 + 可選計數／說明 |
/// | [IssueMarker.gap] | 追溯缺口：虛線框 + `gapMarkerLabel` 文字 |
library;

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_icon.dart';
import 'badge.dart';

/// 三個變體（SPEC-004 4.6「變體」表）。
enum IssueMarkerVariant {
  /// 邊損壞：虛線框包住 `child`，點擊 → jump 破洞報告。
  damagedEdge,

  /// 詳情損壞：警示圖示 + 可選計數／說明，點擊 → jump 破洞報告。
  damagedDetail,

  /// 追溯缺口：虛線框 + 文字，點擊 → jump 破洞報告。
  gap,
}

/// 問題標記（SPEC-004 §4.6）。
///
/// 無 `disabled` 態：三變體皆恆可點擊。點擊呼叫 [onTap] 恰一次，呼叫端
/// 負責執行 jump 至 `nav-page-gaps`（SPEC-003 §3.3、§3.4、§3.6）。
class IssueMarker extends StatelessWidget {
  const IssueMarker._({
    super.key,
    required this.variant,
    required this.onTap,
    required this.testKey,
    this.child,
    this.count,
    this.explanation,
  });

  /// 邊損壞：虛線框包住 [child]（`RelationItem`），child 文字色維持自身
  /// `textPrimary`，不由本元件覆寫（SPEC-004 4.6「使用 design token」）。
  const IssueMarker.damagedEdge({
    Key? key,
    required Widget child,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: IssueMarkerVariant.damagedEdge,
         child: child,
         onTap: onTap,
         testKey: testKey,
       );

  /// 詳情損壞：警示圖示恆顯示，[count] 與 [explanation] 皆可選
  /// （工具列右側計數 / 票列末欄純圖示 / 節點詳情欄位級說明三形態）。
  const IssueMarker.damagedDetail({
    Key? key,
    int? count,
    String? explanation,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: IssueMarkerVariant.damagedDetail,
         count: count,
         explanation: explanation,
         onTap: onTap,
         testKey: testKey,
       );

  /// 追溯缺口：虛線框 + `gapMarkerLabel` 可見文字（zh「缺口」/ en「Gap」）。
  const IssueMarker.gap({
    Key? key,
    required VoidCallback onTap,
    required Key testKey,
  }) : this._(
         key: key,
         variant: IssueMarkerVariant.gap,
         onTap: onTap,
         testKey: testKey,
       );

  /// 變體。
  final IssueMarkerVariant variant;

  /// 點擊回呼；呼叫端執行 jump 至破洞報告。
  final VoidCallback onTap;

  /// 呼叫端定址 key（`badge-tickets-corrupted` /
  /// `badge-traceability-broken-<layer>` / 欄位級 `action-nodeDetail-goto-gaps`）。
  final Key testKey;

  /// `damagedEdge` 必填：被包住的節點（`RelationItem`）。
  final Widget? child;

  /// `damagedDetail` 可選：損壞計數（經 `Badge.count` 顯示）。
  final int? count;

  /// `damagedDetail` 可選：欄位級說明文字（呼叫端傳入
  /// `fieldCorruptedMessage` 等既有 key 的值）。
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (variant) {
      case IssueMarkerVariant.damagedEdge:
        return _buildDamagedEdge(l10n);
      case IssueMarkerVariant.damagedDetail:
        return _buildDamagedDetail(l10n);
      case IssueMarkerVariant.gap:
        return _buildGap(l10n);
    }
  }

  /// child 的既有語意標籤（若有）與本元件的 [AppLocalizations.damagedEdgeMarkerLabel]
  /// 合併為一個朗讀節點（SPEC-004 4.6「{child 標籤}，damagedEdgeMarkerLabel」）。
  Widget _buildDamagedEdge(AppLocalizations l10n) {
    return MergeSemantics(
      key: testKey,
      child: Semantics(
        button: true,
        label: l10n.damagedEdgeMarkerLabel,
        child: _hitTarget(
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            child: CustomPaint(
              painter: const _DashedBoxPainter(),
              child: Padding(
                padding: EdgeInsets.all(Space.xxs.w),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDamagedDetail(AppLocalizations l10n) {
    final String? suffix = count != null
        ? l10n.corruptedTicketsBadge(count!)
        : explanation;
    final String label = suffix == null
        ? l10n.damagedDetailMarkerLabel
        : '${l10n.damagedDetailMarkerLabel}, $suffix';

    return Semantics(
      key: testKey,
      button: true,
      label: label,
      child: _hitTarget(
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  icon: Icons.warning_amber_rounded,
                  size: IconSize.sm,
                  color: AppColors.error,
                ),
                if (count != null) ...[
                  SizedBox(width: Space.xs.w),
                  Badge.count(count: count!),
                ],
                if (explanation != null) ...[
                  SizedBox(width: Space.xs.w),
                  Flexible(
                    child: Text(
                      explanation!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.caption.sp,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGap(AppLocalizations l10n) {
    return Semantics(
      key: testKey,
      button: true,
      label: l10n.gapMarkerLabel,
      child: _hitTarget(
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: CustomPaint(
            painter: const _DashedBoxPainter(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Space.sm.w,
                vertical: Space.xxs.h,
              ),
              child: ExcludeSemantics(
                child: Text(
                  l10n.gapMarkerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.caption.sp,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 最小命中區補足（SPEC-004 4.6 尺寸契約：
  /// `LayoutSize.hitTargetMin` × `LayoutSize.hitTargetMin`，圖示形態以
  /// 透明命中區補足，不放大視覺）。
  Widget _hitTarget({required Widget child}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: LayoutSize.hitTargetMin,
        minHeight: LayoutSize.hitTargetMin,
      ),
      child: Center(child: child),
    );
  }
}

/// 虛線框繪製（`damagedEdge` / `gap` 共用；`Border` 不支援虛線樣式，改用
/// [CustomPainter] 逐段畫短劃，樣式沿用 `lib/components/section.dart` 的
/// 頂部虛線繪製慣例，延伸至四邊）。
class _DashedBoxPainter extends CustomPainter {
  const _DashedBoxPainter();

  static const double _dashWidth = 4;
  static const double _dashGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 1;
    _drawDashedLine(canvas, paint, const Offset(0, 0), Offset(size.width, 0));
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width, 0),
      Offset(size.width, size.height),
    );
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width, size.height),
      Offset(0, size.height),
    );
    _drawDashedLine(canvas, paint, Offset(0, size.height), const Offset(0, 0));
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final delta = end - start;
    final distance = delta.distance;
    final direction = distance == 0 ? Offset.zero : delta / distance;
    var travelled = 0.0;
    while (travelled < distance) {
      final dashEnd = (travelled + _dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        start + direction * travelled,
        start + direction * dashEnd,
        paint,
      );
      travelled += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) => false;
}
