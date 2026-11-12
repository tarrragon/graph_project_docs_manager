/// WriteLogRow（SPEC-004 4.51、5.19）。
///
/// 寫入清單面板的一列，代表本 session 發出過的一次寫入。垂直分行：路徑與
/// 欄位名、所屬專案、寫入結果、驗證狀態、取回說明、快照期限。本元件只依
/// 傳入的識別欄位與 Edit domain 組好的取回指令渲染，不組字、不顯示欄位值、
/// 不 watch 任何狀態（§2）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';
import 'app_text.dart';
import 'badge.dart';
import 'field_block.dart';

/// SPEC-004 4.51：寫入清單列。
class WriteLogRow extends StatelessWidget {
  /// [writeState] 為 `written` 時必須帶 [restoreCommand]。
  const WriteLogRow({
    super.key,
    required this.index,
    required this.path,
    required this.fieldKey,
    required this.projectName,
    required this.writeState,
    required this.testKey,
    this.restoreCommand,
    this.onPathTap,
  });

  /// 路徑按鈕錨點前綴（`action-writeLog-goto-node-<index>`）。
  static Key pathButtonKey(int index) =>
      ValueKey('action-writeLog-goto-node-$index');

  /// 取回說明小標錨點。
  static const Key restoreHeadingKey = ValueKey('write-log-restore-heading');

  /// 快照期限說明錨點。
  static const Key expiryNoteKey = ValueKey('write-log-expiry-note');

  /// 寫入結果徽章錨點。
  static const Key resultBadgeKey = ValueKey('write-log-result-badge');

  /// 驗證徽章錨點。
  static const Key validationBadgeKey = ValueKey('write-log-validation-badge');

  /// 發出順序，自 0 起。
  final int index;

  /// 工作區相對路徑（資料值，不進 i18n）。
  final String path;

  /// frontmatter 鍵名字面值。
  final String fieldKey;

  /// 寫入發出時的專案名稱。
  final String projectName;

  /// 這次寫入的結果與驗證狀態（寫入中、written、blocked、ioFailed）。
  final FieldWriteState writeState;

  /// Edit domain 依 SPEC-009 FR-02 組好的完整取回指令；`written` 時必填。
  final String? restoreCommand;

  /// 路徑點擊；`null` 時路徑為不可點的 `AppText.mono`。
  final VoidCallback? onPathTap;

  /// 呼叫端定址 key（`card-writeLog-row-<index>`）。
  final Key testKey;

  static const _lineGap = Space.xs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final written = writeState.isWritten;
    assert(!written || restoreCommand != null);
    final result = _resultBadge(l10n);
    final validation = written ? _validationBadge(l10n) : null;
    final resultNote = _resultNote(l10n);
    final validationNote = _validationNote(l10n);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _a11yLabel(l10n, result.label, validation?.label),
      child: DecoratedBox(
        key: testKey,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _separated([
              _pathAndField(),
              AppText.singleLine(
                l10n.writeLogProjectLabel(projectName),
                variant: AppTextVariant.caption,
              ),
              _badgeLine(result, resultBadgeKey),
              if (resultNote != null)
                AppText.multiLine(resultNote, maxLines: null),
              if (validation != null)
                _badgeLine(validation, validationBadgeKey),
              if (validationNote != null)
                AppText.multiLine(validationNote, maxLines: null),
              if (written) ..._restoreLines(l10n),
              if (written && writeState.hasSnapshot) _expiryNote(l10n),
            ]),
          ),
        ),
      ),
    );
  }

  /// 行間 `Space.xs`。
  List<Widget> _separated(List<Widget> lines) => [
    for (var i = 0; i < lines.length; i++) ...[
      if (i > 0) SizedBox(height: _lineGap),
      lines[i],
    ],
  ];

  /// 路徑與欄位名同一行，水平互斥、各自截斷，路徑在前。
  Widget _pathAndField() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(child: _pathCell()),
      SizedBox(width: Space.sm),
      Flexible(child: AppText.singleLine(fieldKey)),
    ],
  );

  Widget _pathCell() {
    final onTap = onPathTap;
    if (onTap == null) {
      return AppText.singleLine(path, variant: AppTextVariant.mono);
    }
    return AppButton(
      label: path,
      onPressed: onTap,
      variant: AppButtonVariant.text,
      testKey: pathButtonKey(index),
    );
  }

  Widget _badgeLine(_BadgeSpec spec, Key key) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Badge.category(key: key, label: spec.label, tone: spec.tone),
  );

  _BadgeSpec _resultBadge(AppLocalizations l10n) {
    if (writeState.isWriting) {
      return _BadgeSpec(l10n.fieldWriteInProgress, BadgeTone.neutral);
    }
    if (writeState.isWritten) {
      return _BadgeSpec(l10n.writeResultWritten, BadgeTone.positive);
    }
    final blocked = writeState.blockedReason != null;
    return _BadgeSpec(
      blocked ? l10n.writeResultBlocked : l10n.writeResultIoFailed,
      BadgeTone.negative,
    );
  }

  _BadgeSpec _validationBadge(AppLocalizations l10n) =>
      switch (writeState.validation!) {
        FieldValidation.running => _BadgeSpec(
          l10n.validationRunning,
          BadgeTone.neutral,
        ),
        FieldValidation.passed => _BadgeSpec(
          l10n.validationPassed,
          BadgeTone.positive,
        ),
        FieldValidation.failed => _BadgeSpec(
          l10n.validationFailed(writeState.newIssueCount),
          BadgeTone.negative,
        ),
        FieldValidation.unavailable => _BadgeSpec(
          l10n.validationUnavailable,
          BadgeTone.warning,
        ),
      };

  /// 寫入結果說明：僅 `blocked`／`ioFailed`。
  String? _resultNote(AppLocalizations l10n) {
    if (writeState.isWriting || writeState.isWritten) return null;
    return switch (writeState.blockedReason) {
      FieldBlockedReason.externallyModified =>
        l10n.writeResultExternallyModified,
      FieldBlockedReason.snapshotFailed => l10n.fieldBlockedSnapshotFailed,
      FieldBlockedReason.rewriteNotIsolated =>
        l10n.fieldBlockedRewriteNotIsolated,
      null => l10n.fieldIoFailed,
    };
  }

  /// 驗證不可用原因：僅 `unavailable`。
  String? _validationNote(AppLocalizations l10n) {
    if (!writeState.isWritten ||
        writeState.validation != FieldValidation.unavailable) {
      return null;
    }
    return switch (writeState.unavailableReason!) {
      FieldValidationUnavailableReason.executableMissing =>
        l10n.validationUnavailableExecutableMissing,
      FieldValidationUnavailableReason.unexpectedExitCode =>
        l10n.validationUnavailableUnexpectedExitCode,
      FieldValidationUnavailableReason.unparsableOutput =>
        l10n.validationUnavailableUnparsableOutput,
      FieldValidationUnavailableReason.timedOut =>
        l10n.validationUnavailableTimedOut,
    };
  }

  /// 取回說明：小標 + `AppText.code`（指令為資料值，不進 i18n）。
  List<Widget> _restoreLines(AppLocalizations l10n) => [
    AppText.singleLine(
      l10n.writeLogColumnRestore,
      key: restoreHeadingKey,
      variant: AppTextVariant.caption,
    ),
    AppText.code(restoreCommand!),
  ];

  /// 快照期限說明：最多兩行、末行截斷。不經 `AppText`：`AppText.caption` 恆單行，
  /// 而 4.51 內容政策要求兩行（與 4.48 提示格同理）。
  Widget _expiryNote(AppLocalizations l10n) => Text(
    l10n.writeLogSnapshotExpiryNote,
    key: expiryNoteKey,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: AppFontSize.caption.sp,
      color: AppColors.textSecondary,
    ),
  );

  /// 列朗讀；非 `written` 列省略驗證段。
  String _a11yLabel(
    AppLocalizations l10n,
    String resultLabel,
    String? validationLabel,
  ) {
    final hasValidation = validationLabel != null;
    final label = l10n.writeLogRowA11yLabel(
      l10n.writeLogColumnPath,
      path,
      l10n.writeLogColumnField,
      fieldKey,
      l10n.writeLogColumnResult,
      resultLabel,
      hasValidation ? l10n.writeLogColumnValidation : '',
      validationLabel ?? '',
    );
    return hasValidation
        ? label
        : label.replaceFirst(RegExp(r'\s*[，,]\s*$'), '');
  }
}

class _BadgeSpec {
  const _BadgeSpec(this.label, this.tone);

  final String label;
  final BadgeTone tone;
}
