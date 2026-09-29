/// 「專案未就緒」共用呈現（SPEC-001 §2～§6 共用定義；`0.3.3-W3-389`）。
///
/// 五個非 Domain 畫面共用：依 [ProjectUnreadyReason] 三選一顯示文案，動作為
/// 前往 Domain 視圖。放在 App 層（依賴 `navigateTo` 與 l10n），非元件庫。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/components.dart';
import '../l10n/app_localizations.dart';
import 'graph_status.dart';
import 'router.dart';

/// 專案未就緒：`EmptyState.page` + 前往 Domain 視圖動作。
///
/// [stateKey]／[actionKey] 為各畫面錨點
/// （`state-<screen>-project-unready`／`action-<screen>-goto-domain`）。
class ProjectUnreadyView extends ConsumerWidget {
  const ProjectUnreadyView({
    super.key,
    required this.reason,
    required this.stateKey,
    required this.actionKey,
  });

  final ProjectUnreadyReason reason;
  final Key stateKey;
  final Key actionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      variant: EmptyStateVariant.page,
      testKey: stateKey,
      message: switch (reason) {
        ProjectUnreadyReason.notSelected =>
          l10n.projectUnreadyReasonNotSelected,
        ProjectUnreadyReason.loading => l10n.projectUnreadyReasonLoading,
        ProjectUnreadyReason.incompatible =>
          l10n.projectUnreadyReasonIncompatible,
      },
      actions: [
        AppButton(
          label: l10n.gotoDomainViewAction,
          testKey: actionKey,
          onPressed: () =>
              navigateTo(ref.read, AppDestination.domain, NavIntent.jump),
        ),
      ],
    );
  }
}
