/// 寫入清單面板（SPEC-003 §3.12、SPEC-001 §12）。
///
/// 主視窗內的面板（不是獨立視窗）：由側欄底部「寫入清單」開啟，讀取記憶體中
/// 的本 session 寫入清單（新的在上）；Esc 或關閉鈕關閉，開啟時焦點落在關閉鈕。
/// 只讀取，不寫入清單。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/jump_targets.dart';
import '../../app/project_switcher_providers.dart';
import '../../app/router.dart';
import '../../app/write_list_providers.dart';
import '../../components/components.dart';
import '../../edit/restore_instruction.dart';
import '../../edit/session_write_list.dart';
import '../../edit/write_result.dart';
import '../../l10n/app_localizations.dart';
import '../../state/state_holder.dart';
import '../../tokens/tokens.dart';

/// 面板開合；`true` 時由組裝根掛載 [WriteLogPanel]。
final writeLogOpenProvider = stateHolderProvider<bool>((ref) => false);

/// 需求：[SPEC-001 §12 列的內容] 清單列對應的 [FieldWriteState]：清單只記錄
/// 受理為 `written` 的寫入；尚無驗證狀態時顯示「驗證中」。
FieldWriteState writeStateOf(WriteListEntry entry) {
  final hasSnapshot = entry.snapshotSha != null;
  return switch (entry.validationStatus) {
    null || ValidationRunning() => FieldWriteState.written(
      validation: FieldValidation.running,
      hasSnapshot: hasSnapshot,
    ),
    ValidationPassed() => FieldWriteState.written(
      validation: FieldValidation.passed,
      hasSnapshot: hasSnapshot,
    ),
    ValidationFailed(:final newIssueCount) => FieldWriteState.written(
      validation: FieldValidation.failed,
      newIssueCount: newIssueCount,
      hasSnapshot: hasSnapshot,
    ),
    ValidationUnavailable(:final reason) => FieldWriteState.written(
      validation: FieldValidation.unavailable,
      unavailableReason: _unavailableReasonOf(reason),
      hasSnapshot: hasSnapshot,
    ),
  };
}

/// 元件庫的原因枚舉沒有 `baselineNotReady`，暫以最接近的「非預期結束碼」呈現。
FieldValidationUnavailableReason _unavailableReasonOf(UnavailableReason r) =>
    switch (r) {
      UnavailableReason.executableMissing =>
        FieldValidationUnavailableReason.executableMissing,
      UnavailableReason.unexpectedExitCode ||
      UnavailableReason.baselineNotReady =>
        FieldValidationUnavailableReason.unexpectedExitCode,
      UnavailableReason.unparsableOutput =>
        FieldValidationUnavailableReason.unparsableOutput,
      UnavailableReason.timedOut => FieldValidationUnavailableReason.timedOut,
    };

class WriteLogPanel extends ConsumerWidget {
  const WriteLogPanel({super.key});

  void _close(WidgetRef ref) {
    ref.read(writeLogOpenProvider.notifier).state = false;
  }

  /// 面板關閉，節點詳情顯示該節點；`returnTo` 不變（SPEC-003 §3.12：面板不是
  /// 畫面，沒有可返回的來源畫面），故不經 [navigateTo] 的 jump 規則。
  void _gotoNode(WidgetRef ref, String nodeId) {
    _close(ref);
    ref.read(nodeDetailTargetProvider.notifier).state = nodeId;
    ref.read(selectedDestinationProvider.notifier).state =
        AppDestination.nodeDetail;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(writeListEntriesProvider);
    final projectName = ref.watch(currentProjectNameProvider) ?? '';
    final nodeIds = ref.watch(writeListNodeIdByPathProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _close(ref),
      },
      child: FocusScope(
        autofocus: true,
        child: SizedBox(
          width: LayoutSize.overlayWidth * 2,
          height: LayoutSize.overlayWidth * 2,
          child: Panel.scrollable(
            key: Key(
              entries.isEmpty ? 'state-writeLog-empty' : 'state-writeLog-list',
            ),
            scrollKey: const Key('scroll-writeLog-list'),
            footer: AppButton(
              label: l10n.cellDetailCloseAction,
              onPressed: () => _close(ref),
              variant: AppButtonVariant.text,
              autofocus: true,
              testKey: const Key('action-writeLog-close'),
            ),
            children: [
              AppText.singleLine(
                l10n.writeLogTitle,
                variant: AppTextVariant.subtitle,
              ),
              if (entries.isEmpty)
                AppText.multiLine(l10n.writeLogEmptyMessage, maxLines: null),
              for (var i = entries.length - 1; i >= 0; i--)
                _row(ref, i, entries[i], projectName, nodeIds),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    WidgetRef ref,
    int index,
    WriteListEntry e,
    String project,
    Map<String, String> nodeIds,
  ) {
    final nodeId = nodeIds[e.relativePath];
    return WriteLogRow(
      index: index,
      path: e.relativePath,
      fieldKey: e.field,
      projectName: project,
      writeState: writeStateOf(e),
      restoreCommand: restoreInstruction(
        relativePath: e.relativePath,
        snapshotSha: e.snapshotSha,
      ),
      onPathTap: nodeId == null ? null : () => _gotoNode(ref, nodeId),
      testKey: Key('card-writeLog-row-$index'),
    );
  }
}
