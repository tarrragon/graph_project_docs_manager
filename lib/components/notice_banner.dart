/// NoticeBanner（SPEC-004 4.49）。
///
/// 區塊頂端的常駐說明列：訊息 + 0..1 個動作（`AppButton.secondary`）。
/// 不取代下方內容、不移動焦點；訊息以 `liveRegion` 播報。
library;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'app_text.dart';

/// [NoticeBanner] 的兩種變體（SPEC-004 4.49「變體」）。
enum NoticeBannerVariant {
  /// 區塊仍可操作、但使用者應知悉的狀況（底 `warningSurface`）。
  warning,

  /// 區塊主要操作已不可用，或剛發生的操作失敗（底 `errorSurface`）。
  negative,
}

/// SPEC-004 4.49：區塊橫幅。
///
/// | slot | 說明 |
/// |------|------|
/// | [variant] | 必填 |
/// | [message] | 必填，最多 4 行、末行截斷；由呼叫端依編輯狀態取值 |
/// | [action] | 選填，限 `AppButton.secondary`；不屬本元件的狀態 |
/// | [testKey] | 必填，定址 key |
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.variant,
    required this.message,
    required this.testKey,
    this.action,
  });

  /// 變體。
  final NoticeBannerVariant variant;

  /// 訊息（必填），最多 4 行。
  final String message;

  /// 動作鈕（選填），限 secondary。
  final AppButton? action;

  /// 呼叫端定址 key（編輯區橫幅：`panel-nodeDetail-edit-banner`）。
  final Key testKey;

  /// 訊息最大行數（SPEC-004 4.49 內容政策）。
  static const int _messageMaxLines = 4;

  bool get _isWarning => variant == NoticeBannerVariant.warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: testKey,
      width: double.infinity,
      padding: EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: _isWarning ? AppColors.warningSurface : AppColors.errorSurface,
        borderRadius: BorderRadius.circular(Radius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildMessageRow(), ?_buildActionRow()],
      ),
    );
  }

  Widget _buildMessageRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(
          icon: _isWarning
              ? Icons.warning_amber_rounded
              : Icons.error_outline_rounded,
          color: _isWarning ? AppColors.warning : AppColors.error,
        ),
        SizedBox(width: Space.sm),
        Expanded(
          child: Semantics(
            liveRegion: true,
            container: true,
            child: AppText.multiLine(message, maxLines: _messageMaxLines),
          ),
        ),
      ],
    );
  }

  /// 動作鈕在訊息下方另起一列，起始側對齊於訊息（越過圖示與間距）。
  Widget? _buildActionRow() {
    final button = action;
    if (button == null) return null;
    return Padding(
      padding: EdgeInsets.only(
        top: Space.sm,
        left: LayoutSize.iconMd + Space.sm,
      ),
      child: Align(alignment: AlignmentDirectional.centerStart, child: button),
    );
  }
}
