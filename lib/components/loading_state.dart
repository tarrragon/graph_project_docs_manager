/// LoadingState（SPEC-004 §4.24）。
///
/// 骨架或進度 + 計數文字 + 取消，唯一承擔取消契約 C1–C8 與生命週期 L1–L2
/// （SPEC-003 §2.5、§2.8）的元件；三處出現畫面以「目標態」與「進度型別」
/// 參數差異化，元件本身不知道呼叫端是誰。取消鈕的 enabled／label 隨
/// [LoadingState.isCancelling] 切換，狀態存於呼叫端（SPEC-004 §2 傳值 +
/// callback 慣例），本元件不持有自己的取消狀態機。
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_button.dart';
import 'app_text.dart';
import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';

/// 骨架版位形狀（SPEC-004 §4.24「變體」）。
enum SkeletonLayout {
  /// 表格／矩陣版位：每列切為等寬區塊，模擬欄位。`state-domain-loading`。
  matrix,

  /// 節列表版位：交替寬版首列與縮排項目列。`state-gaps-scanning`。
  sections,
}

/// SPEC-001「載入中」「掃描中」狀態的唯一承載元件（SPEC-004 §4.24）。
///
/// 兩個具名建構子對應兩個變體：[LoadingState.skeleton]（分母未知，
/// indeterminate）與 [LoadingState.progressBar]（determinate，
/// `progress` = 已解析筆數 / 總數）。分母未知時不得顯示百分比或預估，
/// 不得自行推進（SPEC-003 §2.6 誠實性硬規則）——本元件對此的落實是
/// `skeleton` 變體完全不引用 [progress]。
class LoadingState extends StatefulWidget {
  /// 骨架變體：分母未知，shimmer + indeterminate + 計數文字。
  const LoadingState.skeleton({
    super.key,
    required this.message,
    required SkeletonLayout this.skeletonLayout,
    required this.isCancelling,
    required this.onCancel,
    required this.testKey,
    required this.cancelKey,
    this.countText,
    this.cancelLabel,
  }) : progress = null;

  /// 進度條變體：determinate，`progress` = 已解析筆數 / 總數。
  const LoadingState.progressBar({
    super.key,
    required this.message,
    required double this.progress,
    required this.isCancelling,
    required this.onCancel,
    required this.testKey,
    required this.cancelKey,
    this.countText,
    this.cancelLabel,
  }) : skeletonLayout = null;

  /// 訊息文字（呼叫端傳入 i18n key 取值），單行截斷。
  final String message;

  /// 計數文字（呼叫端傳入 i18n key 取值），單行截斷；不傳則不顯示。
  final String? countText;

  /// determinate 進度值（`progressBar` 變體專用），`isCancelling` 為
  /// `true` 時忽略、改為 indeterminate（C3：進度改 indeterminate）。
  final double? progress;

  /// 骨架版位形狀（`skeleton` 變體專用）。
  final SkeletonLayout? skeletonLayout;

  /// 是否正處於取消流程（C2–C4）；狀態存於呼叫端。
  final bool isCancelling;

  /// 取消鈕回呼；`isCancelling` 為 `true` 時鈕已 disabled，不會再被呼叫
  /// （C8 冪等由 [AppButton] 的 disabled 語意承擔）。
  final VoidCallback onCancel;

  /// 取消鈕文案覆寫（未取消中時生效），未傳則用元件預設
  /// `cancelLoadingAction`；取消中固定 `cancelInProgressAction`，不受本
  /// 參數影響。
  final String? cancelLabel;

  /// 呼叫端定址 key（`state-*-loading` / `state-gaps-scanning`）。
  final Key testKey;

  /// 取消鈕定址 key（`action-*-cancel-load` / `action-gaps-cancel-scan`）。
  final Key cancelKey;

  bool get _isSkeleton => skeletonLayout != null;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmerController;
  Duration? _shimmerDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget._isSkeleton) {
      return;
    }
    final duration = Motion.skeletonCycle(context);
    if (duration == _shimmerDuration) {
      return;
    }
    _shimmerDuration = duration;
    _shimmerController?.dispose();
    // disableAnimations 時骨架靜態：不建立 controller，改用固定不透明度
    // （SPEC-004 §4.24 互動反應「骨架」列）。
    _shimmerController = duration == Duration.zero
        ? null
        : (AnimationController(vsync: this, duration: duration)
            ..repeat(reverse: true));
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cancelLabelText = widget.isCancelling
        ? l10n.cancelInProgressAction
        : (widget.cancelLabel ?? l10n.cancelLoadingAction);

    final cancelButton = AppButton(
      label: cancelLabelText,
      onPressed: widget.onCancel,
      testKey: widget.cancelKey,
      variant: AppButtonVariant.secondary,
      enabled: !widget.isCancelling,
      // disabled 時 disabledReason 為 AppButton 必填（SPEC-004 §4.4）；取消
      // 中的說明已由鈕文案本身承載（cancelInProgressAction），此處傳空字串
      // 只滿足必填 assert，不重複渲染同一段文字。
      disabledReason: widget.isCancelling ? '' : null,
    );

    final body = widget._isSkeleton
        ? _buildSkeletonBody(context, l10n, cancelButton)
        : _buildProgressBarBody(context, l10n, cancelButton);

    return Container(
      key: widget.testKey,
      padding: EdgeInsets.all(Space.md.r),
      child: body,
    );
  }

  Widget _buildSkeletonBody(
    BuildContext context,
    AppLocalizations l10n,
    Widget cancelButton,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Semantics(
            label: l10n.loadingSkeletonA11yLabel,
            child: _shimmerController == null
                ? _SkeletonArea(
                    layout: widget.skeletonLayout!,
                    opacity: 1,
                  )
                : AnimatedBuilder(
                    animation: _shimmerController!,
                    builder: (context, _) => _SkeletonArea(
                      layout: widget.skeletonLayout!,
                      opacity: 0.5 + 0.5 * _shimmerController!.value,
                    ),
                  ),
          ),
        ),
        SizedBox(height: Space.sm.h),
        _messageFooter(cancelButton),
      ],
    );
  }

  Widget _buildProgressBarBody(
    BuildContext context,
    AppLocalizations l10n,
    Widget cancelButton,
  ) {
    // C3：取消中時進度改 indeterminate，計數凍結由呼叫端不再更新
    // countText 承擔（本元件只忽略 progress）。
    final effectiveProgress = widget.isCancelling ? null : widget.progress;
    final semanticsValue = effectiveProgress == null
        ? null
        : l10n.progressA11yLabel((effectiveProgress * 100).round(), 100);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutSize.detailPaneWidth.w * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              value: semanticsValue,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radius.sm),
                child: LinearProgressIndicator(
                  value: effectiveProgress,
                  minHeight: Space.sm.h,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ),
            SizedBox(height: Space.sm.h),
            _messageFooter(cancelButton),
          ],
        ),
      ),
    );
  }

  Widget _messageFooter(Widget cancelButton) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm.w,
            children: [
              AppText(widget.message, maxLines: 1),
              if (widget.countText != null)
                Semantics(
                  liveRegion: true,
                  child: AppText(
                    widget.countText!,
                    variant: AppTextVariant.caption,
                    secondary: true,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: Space.sm.w),
        cancelButton,
      ],
    );
  }
}

/// 骨架版位區塊（純視覺，不承載互動）。以 [ListView] 承載固定列數，
/// 高度不足時自然裁切（不觸發 overflow，SPEC-004 §4.24「`kMinWindowSize`
/// 下的行為」）。
class _SkeletonArea extends StatelessWidget {
  const _SkeletonArea({required this.layout, required this.opacity});

  final SkeletonLayout layout;
  final double opacity;

  static const int _rowCount = 12;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.surfaceChip.withValues(alpha: opacity);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rowCount,
      separatorBuilder: (context, index) => SizedBox(height: Space.xs.h),
      itemBuilder: (context, index) => _buildRow(color, index),
    );
  }

  Widget _buildRow(Color color, int index) {
    final height = LayoutSize.rowHeightRelaxed.h;
    if (layout == SkeletonLayout.matrix) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (var col = 0; col < 4; col++) ...[
              if (col > 0) SizedBox(width: Space.xs.w),
              Expanded(child: _block(color)),
            ],
          ],
        ),
      );
    }
    final isHeader = index.isEven;
    return Padding(
      padding: EdgeInsets.only(
        left: isHeader ? 0 : LayoutSize.treeIndent.w,
      ),
      child: SizedBox(
        height: height,
        width: isHeader ? double.infinity : LayoutSize.detailPaneWidth.w,
        child: _block(color),
      ),
    );
  }

  Widget _block(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radius.sm),
      ),
    );
  }
}
