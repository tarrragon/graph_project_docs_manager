/// BlockedState（SPEC-004 4.23）。
///
/// 「這個專案不適用本 App」+ 版本值 + 說明 + 切換專案出口（恆可用，
/// SPEC-001 FR-07）；0.1 不渲染「以純檔案模式檢視」（SPEC-003 §3.1，
/// 降級策略延後，見 SPEC-004 4.23）。填滿父容器、內容置中，`withDetail`
/// 變體額外提供可展開的 schema 版本比對面板（`plain` 無此能力）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'button_row.dart';
import 'section.dart';

/// [BlockedState] 的兩種變體（SPEC-004 4.23「變體」）。
enum BlockedStateVariant {
  /// 訊息 + 說明（可缺）+ 版本值（可缺）+ 切換專案動作。不是框架專案、
  /// 無可消費的型別表時使用。
  plain,

  /// 加「檢視詳情」次要按鈕與可展開的 schema 版本比對面板。schema
  /// 不相容時使用。
  withDetail,
}

/// SPEC-004 4.23：專案不適用本 App 的阻擋態。
///
/// | slot | `plain` | `withDetail` |
/// |------|---------|--------------|
/// | [message] | 必填 | 必填 |
/// | [explanation] | 選填 | 選填 |
/// | [version] | 選填（純顯示版本值） | 不使用 |
/// | [appVersion] / [projectVersion] | 不使用 | 必填 |
/// | [onSwitchProject] | 必填 | 必填 |
/// | [isDetailExpanded] / [onToggleDetail] | 不使用 | 必填 |
/// | [testKey] | 必填 | 必填 |
class BlockedState extends StatelessWidget {
  /// `plain` 變體：無展開能力，[version] 為選填的純顯示版本值。
  const BlockedState.plain({
    super.key,
    required this.message,
    required this.onSwitchProject,
    required this.testKey,
    this.explanation,
    this.version,
  }) : variant = BlockedStateVariant.plain,
       appVersion = null,
       projectVersion = null,
       isDetailExpanded = false,
       onToggleDetail = null;

  /// `withDetail` 變體：加「檢視詳情」按鈕與可展開的 schema 版本比對面板；
  /// 展開態存於呼叫端（[isDetailExpanded] / [onToggleDetail]）。
  const BlockedState.withDetail({
    super.key,
    required this.message,
    required this.appVersion,
    required this.projectVersion,
    required this.onSwitchProject,
    required this.isDetailExpanded,
    required this.onToggleDetail,
    required this.testKey,
    this.explanation,
  }) : variant = BlockedStateVariant.withDetail,
       version = null;

  /// 兩種變體之一。
  final BlockedStateVariant variant;

  /// 訊息（必填），三行末行截斷。
  final String message;

  /// 說明（選填），四行末行截斷。
  final String? explanation;

  /// `plain` 的純顯示版本值（選填），單行截斷。`withDetail` 不使用。
  final String? version;

  /// App 支援版本值（`withDetail` 必填），單行截斷。
  final String? appVersion;

  /// 專案版本值（`withDetail` 必填），單行截斷。
  final String? projectVersion;

  /// 切換專案回呼；呼叫端開啟 `SwitcherOverlay`（不改變本狀態，SPEC-003
  /// §2.7）。
  final VoidCallback onSwitchProject;

  /// 詳情面板展開態（`withDetail` 必填）；狀態存於呼叫端。
  final bool isDetailExpanded;

  /// 展開態切換回呼（`withDetail` 必填）。
  final VoidCallback? onToggleDetail;

  /// 呼叫端定址 key（例：`state-domain-not-framework`）。
  final Key testKey;

  bool get _isWithDetail => variant == BlockedStateVariant.withDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: LayoutSize.detailPaneWidth * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildMessageBlock(),
          if (explanation != null) ...[
            SizedBox(height: Space.xs),
            AppText(explanation!, variant: AppTextVariant.body, maxLines: 4),
          ],
          SizedBox(height: Space.lg),
          _buildActions(l10n),
          if (_isWithDetail) _buildDetailPanel(context, l10n),
        ],
      ),
    );

    final body = Container(
      key: testKey,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: content,
    );

    if (!_isWithDetail) {
      return body;
    }

    return Focus(
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: body,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        isDetailExpanded) {
      onToggleDetail!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMessageBlock() {
    final versionText = version;
    return Semantics(
      header: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppText(
            message,
            variant: AppTextVariant.body,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
          if (versionText != null) ...[
            SizedBox(height: Space.xxs),
            AppText(versionText, variant: AppTextVariant.mono),
          ],
        ],
      ),
    );
  }

  /// 動作列，兩變體皆由 `ButtonRow`[`AppButton` × N]（SPEC-004 4.23
  /// 「變體」）承載。`withDetail` 的「檢視詳情」鈕以 `AppButton.semanticExpanded`
  /// 附加展開語意（SPEC-004 4.4），不需外部包裹即維持 `AppButton` 型別。
  Widget _buildActions(AppLocalizations l10n) {
    final switchButton = AppButton(
      label: l10n.projectSwitcherEntryLabel,
      onPressed: onSwitchProject,
      testKey: const ValueKey('action-domain-switch-project'),
    );

    if (!_isWithDetail) {
      return ButtonRow(
        alignment: ButtonRowAlignment.center,
        children: [switchButton],
      );
    }

    final onToggle = onToggleDetail;
    return ButtonRow(
      alignment: ButtonRowAlignment.center,
      children: [
        switchButton,
        AppButton(
          label: l10n.viewSchemaDetailAction,
          variant: AppButtonVariant.secondary,
          onPressed: onToggle!,
          testKey: const ValueKey('action-domain-schema-detail'),
          semanticExpanded: isDetailExpanded,
        ),
      ],
    );
  }

  Widget _buildDetailPanel(BuildContext context, AppLocalizations l10n) {
    return AnimatedSize(
      duration: Motion.transition(context),
      alignment: Alignment.topCenter,
      child: isDetailExpanded
          ? Padding(
              padding: EdgeInsets.only(top: Space.lg),
              child: Container(
                key: const ValueKey('panel-domain-schema-detail'),
                padding: EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  border: Border.all(color: AppColors.borderStrong),
                  borderRadius: BorderRadius.circular(Radius.md),
                ),
                child: Section(
                  variant: SectionVariant.static,
                  header: const SizedBox.shrink(),
                  testKey: const ValueKey('section-domain-schema-detail'),
                  items: [
                    AppText(
                      l10n.schemaAppVersionLabel,
                      variant: AppTextVariant.caption,
                    ),
                    AppText(appVersion!, variant: AppTextVariant.mono),
                    AppText(
                      l10n.schemaProjectVersionLabel,
                      variant: AppTextVariant.caption,
                    ),
                    AppText(projectVersion!, variant: AppTextVariant.mono),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
