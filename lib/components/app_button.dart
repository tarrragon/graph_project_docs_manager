/// AppButton（SPEC-004 §4.4）。
///
/// SPEC-001「可用操作」欄所有有視覺承載的動作（十四種 + 格詳情卡兩種）
/// 唯一承載元件。三種變體對應三種強調層級，不承載任何非動作語意。
///
/// **與契約的一處差異（範圍限定）**：slot 契約表 `leading` 型別寫
/// `AppIcon?`，但 `AppIcon`（SPEC-004 4.2）尚未建立於 `lib/components/`，
/// 非本票（4.4）範圍。本檔改以 `Widget?` 承接，語意不變（`text` 變體專用
/// 的 leading 圖示 slot）；`AppIcon` 建立後可直接代入，型別相容。
library;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// [AppButton] 的三種變體（SPEC-004 §4.4「變體」）。
enum AppButtonVariant {
  /// 底 [AppColors.accent]、字 [AppColors.surfaceBase]。前進／主要動作。
  primary,

  /// 底 [AppColors.surfaceBase]、邊框 [AppColors.borderStrong]。次要動作。
  secondary,

  /// 無底無框、字 [AppColors.accent]，可帶 leading 圖示。低強調動作。
  text,
}

/// SPEC-001「可用操作」欄動作的唯一承載元件（SPEC-004 §4.4）。
///
/// 三個變體皆為單一 label slot 的動作按鈕；`text` 變體另有可選 leading
/// 圖示。無 loading 狀態——等待指示為畫面級（SPEC-003 §2.2），本元件內
/// 不放 spinner；取消鈕按下後的「取消中」由 `LoadingState`（SPEC-004
/// 4.24）以 `enabled=false` + label 換文案承載。
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.testKey,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.enabled = true,
    this.disabledReason,
    this.semanticExpanded,
  }) : assert(
         enabled || disabledReason != null,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'disabledReason 為必填：enabled 為 false 時必須提供原因（SPEC-004 §4.4 slot 契約）',
       ),
       assert(
         leading == null || variant == AppButtonVariant.text,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'leading 僅 text 變體可用（SPEC-004 §4.4 slot 契約）',
       );

  /// 按鈕文字（唯一內容 slot，禁止 icon-only）。呼叫端傳入 i18n key 取值。
  final String label;

  /// 點選（含 Space / Enter）觸發的回呼。`enabled` 為 `false` 時不呼叫。
  final VoidCallback onPressed;

  /// 測試錨點（SPEC-003 §2.9 `action-<screen>-<action>`）。
  final Key testKey;

  /// 三種強調層級之一，預設 [AppButtonVariant.primary]。
  final AppButtonVariant variant;

  /// 僅 [AppButtonVariant.text] 可用的 leading 圖示（見檔頭「與契約的一處
  /// 差異」）。語意樹排除（非操作內容）。
  final Widget? leading;

  /// 是否可互動，預設 `true`。為 `false` 時 [disabledReason] 必填。
  final bool enabled;

  /// disabled 時的常駐說明文字（同列顯示，非 tooltip；SPEC-003 §2.2、FR-06）。
  final String? disabledReason;

  /// 語意樹的展開狀態旗標（SPEC-004 §4.4 slot 契約）。`null` 時不附加該
  /// 旗標；非 `null` 時附加於本元件既有語意節點，供呼叫端標示本按鈕控制
  /// 的區塊是否展開（如 4.23 `BlockedState.withDetail` 檢視詳情鈕），
  /// 不需呼叫端外部包裹 `Semantics(expanded: ...)` 即可維持 `AppButton`
  /// 型別（回收 4.34 `ButtonRow` 的 `List<AppButton>` 型別限定）。
  final bool? semanticExpanded;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
  }

  _ButtonColors get _colors {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return const _ButtonColors(
          background: AppColors.accent,
          foreground: AppColors.surfaceBase,
          border: null,
        );
      case AppButtonVariant.secondary:
        return const _ButtonColors(
          background: AppColors.surfaceBase,
          foreground: AppColors.textPrimary,
          border: AppColors.borderStrong,
        );
      case AppButtonVariant.text:
        return _ButtonColors(
          background: Colors.transparent, // color-exempt 無底變體，非 token 語意色
          foreground: AppColors.accent,
          border: null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    // disabled：文字與圖示改 textDisabled（SPEC-004 §4.0.1）。
    final foreground = widget.enabled
        ? colors.foreground
        : AppColors.textDisabled;

    final Widget? leadingIcon = widget.leading == null
        ? null
        : ExcludeSemantics(
            child: SizedBox(
              width: LayoutSize.iconMd,
              height: LayoutSize.iconMd,
              child: widget.leading,
            ),
          );

    final button = TextButton(
      key: widget.testKey,
      onPressed: widget.enabled ? widget.onPressed : null,
      onFocusChange: _onFocusChange,
      style: TextButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: foreground,
        disabledForegroundColor: AppColors.textDisabled,
        disabledBackgroundColor: colors.background,
        side: colors.border == null
            ? null
            : BorderSide(color: colors.border!),
        padding: EdgeInsets.symmetric(horizontal: Space.md),
        minimumSize: Size(LayoutSize.hitTargetMin, LayoutSize.hitTargetMin),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radius.md),
        ),
        animationDuration: Motion.feedback,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            leadingIcon,
            SizedBox(width: Space.xs),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSize.body, color: foreground),
            ),
          ),
        ],
      ),
    );

    // focused：祖先鏈存在 decoration 非 null 的 DecoratedBox（SPEC-003
    // §2.10；SPEC-004 §4.0.1）。
    final decoratedButton = DecoratedBox(
      decoration: BoxDecoration(
        border: _focused
            ? Border.all(color: AppColors.accent)
            : Border.all(
                color: Colors.transparent, // color-exempt 未聚焦時不可見邊框佔位
              ),
        borderRadius: BorderRadius.circular(Radius.md),
      ),
      child: SizedBox(height: LayoutSize.hitTargetMin, child: button),
    );

    final Widget result = (widget.enabled || widget.disabledReason == null)
        ? decoratedButton
        // disabled 原因：同列常駐文字，非 tooltip（SPEC-003 §2.2、FR-06）。
        : Semantics(
            hint: widget.disabledReason,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                decoratedButton,
                SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    widget.disabledReason!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.caption,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );

    final semanticExpanded = widget.semanticExpanded;
    if (semanticExpanded == null) {
      return result;
    }

    // container: true 明確擁有語意節點（對齊 SPEC-004 4.7 NavItem 既有
    // 寫法：`Semantics(container: true) child: ExcludeSemantics(...)`）；
    // container: false（預設）的屬性向上併入祖先節點而非本元件自身按鈕
    // 節點，無法承載 expanded 旗標。內部視覺內容排除於語意樹，避免與外層
    // label / enabled 重複產生節點。
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      enabled: widget.enabled,
      hint: widget.disabledReason,
      expanded: semanticExpanded,
      child: ExcludeSemantics(child: result),
    );
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
