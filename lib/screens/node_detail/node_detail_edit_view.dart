/// 節點詳情編輯模式的畫面組裝（SPEC-001 §6〈編輯模式〉；SPEC-003 §3.6）。
///
/// 只組裝既有元件：正常態的「編輯欄位」鈕與其讀取失敗說明、編輯中的
/// `FieldList`。狀態與寫入由 `NodeDetailEditNotifier` 承載。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/components/components.dart';
import 'package:graph_project_docs_manager/edit/field_domain_source.dart';
import 'package:graph_project_docs_manager/l10n/app_localizations.dart';

import 'field_input_mapping.dart';
import 'node_detail_edit_notifier.dart';
import 'node_detail_fixtures.dart';
import 'node_detail_providers.dart';
import 'node_detail_state.dart';

/// 正常態的「編輯欄位」鈕（`action-nodeDetail-edit`）與讀取失敗說明。
///
/// 唯讀降級時 disabled，原因同唯讀降級徽章文字（SPEC-001 §1）；該節點型別
/// 沒有 1.0 可編輯欄位時不渲染。
class NodeDetailEditEntry extends ConsumerWidget {
  const NodeDetailEditEntry({super.key, required this.node});

  final NodeDetailFixture node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (editableFieldKeysFor(node.type).isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final reason = ref.watch(readonlyWorkspaceReasonProvider);
    final failed = ref.watch(nodeDetailEditReadFailedProvider) == node.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ButtonRow(
          children: [
            AppButton(
              label: l10n.editFieldsAction,
              variant: AppButtonVariant.secondary,
              enabled: reason == null,
              disabledReason: reason == null ? null : _reasonText(l10n, reason),
              onPressed: () => _begin(ref),
              testKey: const Key('action-nodeDetail-edit'),
            ),
          ],
        ),
        if (failed)
          Badge.tag(
            key: const Key('badge-nodeDetail-edit-read-failed'),
            label: l10n.nodeDetailEditReadFailedMessage,
          ),
      ],
    );
  }

  String _reasonText(AppLocalizations l10n, ReadonlyWorkspaceReason reason) =>
      switch (reason) {
        ReadonlyWorkspaceReason.notGit => l10n.readonlyWorkspaceNotGitBadge,
        ReadonlyWorkspaceReason.gitMissing =>
          l10n.readonlyWorkspaceGitMissingBadge,
      };

  /// 需求：[SPEC-003 §3.6 編輯欄位] 讀取成功進入編輯中；notFound 轉原始檔
  /// 已消失（不出現 SnackBar）；其他讀取失敗維持正常並顯示說明。
  Future<void> _begin(WidgetRef ref) async {
    final failedHolder = ref.read(nodeDetailEditReadFailedProvider.notifier);
    failedHolder.state = null;
    final result = await ref
        .read(nodeDetailEditProvider.notifier)
        .begin(
          nodeId: node.id,
          nodeType: node.type,
          relativePath: node.filePath,
        );
    switch (result) {
      case NodeDetailEditBeginResult.started ||
          NodeDetailEditBeginResult.unavailable:
        return;
      case NodeDetailEditBeginResult.missing:
        ref.read(nodeDetailStateProvider.notifier).state = NodeDetailMissing(
          nodeId: node.id,
          lastKnownPath: node.filePath,
        );
      case NodeDetailEditBeginResult.readFailed:
        failedHolder.state = node.id;
    }
  }
}

/// 編輯中的 `FieldList`（`panel-nodeDetail-field-list`）：取代分隔線以上
/// 整區。可編輯欄位一律以文字輸入呈現：1.0 沒有機器定義的值域（SPEC-009
/// FR-09〈值域來源〉），選取類元件的選項來源另待上游補值域。
class NodeDetailEditFieldList extends ConsumerWidget {
  const NodeDetailEditFieldList({
    super.key,
    required this.edit,
    required this.filePath,
  });

  final NodeDetailEditState edit;
  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(nodeDetailEditProvider.notifier);
    final source = ref.watch(fieldDomainSourceProvider);
    return FieldList(
      testKey: const Key('panel-nodeDetail-field-list'),
      banner: _banner(l10n),
      writeInProgress: edit.writeInProgress,
      isBlocked: edit.phase == NodeDetailEditPhase.blocked,
      onDiscardAndReload: () =>
          notifier.discardAndReload(lastKnownPath: filePath),
      doneButton: AppButton(
        label: l10n.editDoneAction,
        onPressed: notifier.done,
        testKey: const Key('action-nodeDetail-edit-done'),
      ),
      fields: [for (final key in edit.fieldKeys) _field(key, source, notifier)],
    );
  }

  NoticeBanner? _banner(AppLocalizations l10n) {
    final blocked = edit.phase == NodeDetailEditPhase.blocked;
    if (edit.phase == NodeDetailEditPhase.editing) return null;
    return NoticeBanner(
      variant: blocked
          ? NoticeBannerVariant.negative
          : NoticeBannerVariant.warning,
      message: blocked
          ? l10n.editBannerExternallyModifiedBlocked
          : l10n.editBannerExternallyModifiedWarning,
      testKey: const Key('panel-nodeDetail-edit-banner'),
      action: AppButton(
        label: l10n.editDiscardAndReloadAction,
        variant: AppButtonVariant.secondary,
        onPressed: () {},
        testKey: FieldList.reloadActionKey,
      ),
    );
  }

  FieldBlock _field(
    String key,
    FieldDomainSource source,
    NodeDetailEditNotifier notifier,
  ) {
    final multi =
        inputElementFor(edit.nodeType, key, source) ==
        FieldInputElement.multiLine;
    final writeState = edit.writeStates[key];
    final value = edit.values[key] ?? '';
    void onSubmitted(String draft) => notifier.submit(key, draft);
    void onDirty(bool dirty) => notifier.setDirty(key, dirty);
    final failed = writeState?.isShownFailure ?? false;
    final input = multi
        ? AppTextInput.multiLine(
            value: value,
            onSubmitted: onSubmitted,
            semanticLabel: key,
            testKey: Key('input-nodeDetail-field-$key'),
            hasError: failed,
            onDirtyChanged: onDirty,
          )
        : AppTextInput.singleLine(
            value: value,
            onSubmitted: onSubmitted,
            semanticLabel: key,
            testKey: Key('input-nodeDetail-field-$key'),
            hasError: failed,
            onDirtyChanged: onDirty,
          );
    return FieldBlock.editable(
      key: ValueKey('field-$key-${edit.generation}'),
      label: key,
      value: input,
      testKey: Key('card-nodeDetail-field-$key'),
      writeState: writeState,
      isDirty: edit.dirty.contains(key),
      isMultiLine: multi,
      requiredEmpty: edit.requiredEmpty.contains(key),
    );
  }
}
