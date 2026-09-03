/// 浮層內單一專案選項（SPEC-004 §4.9）。
///
/// 圖示 + 名稱 + 摘要（節點數 · 票數）+ 健康徽章 slot + 不可用原因常駐
/// 文字。單一變體，`enabled` / `isCurrent` 為狀態（SPEC-004 4.9「變體」）。
///
/// 4.9「狀態矩陣」對 `selected` / `disabled` 態要求圖示與名稱改
/// [AppColors.accentStrong] / [AppColors.textDisabled]、摘要改
/// [AppColors.textPrimary] / [AppColors.textDisabled]。`name` / `summary`
/// / `reason` 依 [AppText.tone]（SPEC-004 §4.1「修飾參數優先序」）依狀態
/// 取色，圖示色由 [AppIcon.color] 承載（非文字，不經 [AppText]）。
library;

import 'package:flutter/material.dart' show Icons, InkWell;
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_icon.dart';
import 'app_text.dart';
import 'badge.dart';

/// 浮層內單一專案選項（SPEC-004 §4.9）。
///
/// | slot | 必填 | 說明 |
/// |------|------|------|
/// | [name] | 是 | 專案名稱，單行截斷 |
/// | [summary] | 是 | 摘要（呼叫端取 `projectSummaryLabel` 值），單行截斷 |
/// | [health] | 否 | 問題數為 0 時不傳 |
/// | [enabled] | 是 | 可用性；為 `false` 時 [reason] 必填 |
/// | [isCurrent] | 是 | 是否為目前開啟的專案（`selected` 態） |
/// | [reason] | `enabled` 為 `false` 時必填 | disabled 常駐原因（非 tooltip） |
/// | [onTap] | 是 | 點選回呼；`enabled` 為 `false` 時不呼叫 |
/// | [testKey] | 是 | `card-switcher-recent-<index>` |
class RecentProjectItem extends StatelessWidget {
  const RecentProjectItem({
    super.key,
    required this.name,
    required this.summary,
    required this.enabled,
    required this.isCurrent,
    required this.onTap,
    required this.testKey,
    this.health,
    this.reason,
  }) : assert(
         enabled || reason != null,
         // i18n-exempt: assert 訊息僅開發期可見，非 user-facing
         'reason 為必填：enabled 為 false 時必須提供不可用原因（SPEC-004 §4.9 slot 契約）',
       );

  /// 專案名稱（單行截斷，SPEC-004 4.9 內容政策）。
  final String name;

  /// 摘要文字，呼叫端取 `projectSummaryLabel` 值（單行截斷）。
  final String summary;

  /// 健康徽章 slot（`Badge.health`）；問題數為 0 時不傳。
  final Badge? health;

  /// 可用性；為 `false` 時視覺依 §4.0.1，[reason] 必填。
  final bool enabled;

  /// 是否為目前開啟的專案（`selected` 態，SPEC-004 4.9 狀態矩陣）。
  final bool isCurrent;

  /// disabled 常駐原因（同列文字，非 tooltip；呼叫端取
  /// `projectUnavailableReasonLabel` 值）。`enabled` 為 `false` 時必填。
  final String? reason;

  /// 點選回呼；`enabled` 為 `false` 時不呼叫。
  final VoidCallback onTap;

  /// 呼叫端定址 key（`card-switcher-recent-<index>`）。
  final Key testKey;

  bool get _isDisabled => !enabled;

  Color get _iconColor {
    if (_isDisabled) return AppColors.textDisabled;
    if (isCurrent) return AppColors.accentStrong;
    return AppColors.textSecondary;
  }

  AppTextTone get _nameTone {
    if (_isDisabled) return AppTextTone.textDisabled;
    if (isCurrent) return AppTextTone.accentStrong;
    return AppTextTone.textTitle;
  }

  AppTextTone get _summaryTone {
    if (_isDisabled) return AppTextTone.textDisabled;
    if (isCurrent) return AppTextTone.textPrimary;
    return AppTextTone.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticsLabel = isCurrent
        ? '$name，$summary，${l10n.currentProjectA11yLabel}'
        : '$name，$summary';

    return MergeSemantics(
      child: Semantics(
        key: testKey,
        button: true,
        enabled: enabled,
        selected: isCurrent,
        label: semanticsLabel,
        hint: _isDisabled ? reason : null,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LayoutSize.hitTargetMin,
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(Radius.md),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.surfaceIconTint : AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(Radius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIcon(
                icon: Icons.folder_outlined,
                size: IconSize.lg,
                color: _iconColor,
              ),
              SizedBox(width: Space.sm),
              Expanded(child: _buildTextBlock()),
              if (health != null) ...[SizedBox(width: Space.sm), health!],
            ],
          ),
          if (_isDisabled && reason != null) ...[
            SizedBox(height: Space.xxs),
            AppText(
              reason!,
              variant: AppTextVariant.body,
              maxLines: 2,
              tone: AppTextTone.textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(name, maxLines: 1, emphasis: true, tone: _nameTone),
        SizedBox(height: Space.xxs),
        AppText(summary, variant: AppTextVariant.caption, tone: _summaryTone),
      ],
    );
  }
}
