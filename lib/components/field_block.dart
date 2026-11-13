/// FieldBlock（SPEC-004 4.48、5.17）。
///
/// 一個文件欄位的承載：label + 值格 + 提示格的垂直堆疊。寫入的結果與驗證
/// 狀態在提示格呈現，輸入元件只承載輸入層。容器自身無互動；寫入結果由
/// 呼叫端（`FieldList`，4.50）依 Edit domain 的狀態傳入，本元件不 watch。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/app_localizations.dart';
import '../tokens/tokens.dart';
import 'app_text.dart';

/// 寫入被拒的原因（SPEC-009 FR-05 `blocked`）。
enum FieldBlockedReason {
  /// 無法建立快照。
  snapshotFailed,

  /// 無法只改這個欄位。
  rewriteNotIsolated,

  /// 檔案已被外部修改：不在提示格顯示，由 4.50 橫幅承載。
  externallyModified,
}

/// 寫入後的驗證狀態（SPEC-009 FR-05 `ValidationStatus`）。
enum FieldValidation { running, passed, failed, unavailable }

/// 驗證不可用的原因（SPEC-009 FR-05 `unavailable(...)`）。
enum FieldValidationUnavailableReason {
  executableMissing,
  unexpectedExitCode,
  unparsableOutput,
  timedOut,
  baselineNotReady,
}

enum _Kind { writing, written, blocked, ioFailed }

/// 本欄最近一次寫入的呈現資料（SPEC-004 4.48 slot `writeState`）。
///
/// `null` 的 `FieldBlock.writeState` 代表本欄沒有寫入過（idle）。
@immutable
class FieldWriteState {
  /// 寫入進行中。
  const FieldWriteState.writing()
    : _kind = _Kind.writing,
      blockedReason = null,
      validation = null,
      unavailableReason = null,
      newIssueCount = 0,
      hasSnapshot = false;

  /// 受理，附驗證狀態；[validation] 為 `failed` 時帶 [newIssueCount]，為
  /// `unavailable` 時必須帶 [unavailableReason]。
  const FieldWriteState.written({
    required FieldValidation this.validation,
    this.unavailableReason,
    this.newIssueCount = 0,
    this.hasSnapshot = false,
  }) : _kind = _Kind.written,
       blockedReason = null,
       assert(
         validation != FieldValidation.unavailable || unavailableReason != null,
       );

  /// 寫入被拒。
  const FieldWriteState.blocked(FieldBlockedReason this.blockedReason)
    : _kind = _Kind.blocked,
      validation = null,
      unavailableReason = null,
      newIssueCount = 0,
      hasSnapshot = false;

  /// 讀寫失敗。
  const FieldWriteState.ioFailed()
    : _kind = _Kind.ioFailed,
      blockedReason = null,
      validation = null,
      unavailableReason = null,
      newIssueCount = 0,
      hasSnapshot = false;

  final _Kind _kind;

  /// `blocked` 的原因。
  final FieldBlockedReason? blockedReason;

  /// `written` 的驗證狀態。
  final FieldValidation? validation;

  /// `written` 且驗證不可用的原因。
  final FieldValidationUnavailableReason? unavailableReason;

  /// 驗證 `failed` 的新增問題數。
  final int newIssueCount;

  /// `written` 時是否有快照可取回。
  final bool hasSnapshot;

  /// 是否寫入進行中。
  bool get isWriting => _kind == _Kind.writing;

  /// 是否為提示格要顯示的寫入失敗（`externallyModified` 由 4.50 橫幅承載）。
  bool get isShownFailure =>
      _kind == _Kind.ioFailed ||
      (_kind == _Kind.blocked &&
          blockedReason != FieldBlockedReason.externallyModified);

  /// 是否為 `written`。
  bool get isWritten => _kind == _Kind.written;
}

/// 提示格的一則訊息。
class _Hint {
  const _Hint(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// SPEC-004 4.48：表單欄位容器，兩變體 `editable`／`readOnly`。
class FieldBlock extends StatelessWidget {
  /// `editable`：值格放輸入元件之一，呈現寫入結果與驗證狀態。
  const FieldBlock.editable({
    super.key,
    required this.label,
    required this.value,
    required this.testKey,
    this.supportingText,
    this.isError = false,
    this.writeState,
    this.isDirty = false,
    this.isMultiLine = false,
    this.requiredEmpty = false,
    this.outOfDomainValue,
  }) : _readOnly = false;

  /// `readOnly`：值格放 `AppText`（`body`；ID、路徑、日期用 `mono`），無寫入。
  const FieldBlock.readOnly({
    super.key,
    required this.label,
    required AppText this.value,
    required this.testKey,
  }) : _readOnly = true,
       supportingText = null,
       isError = false,
       writeState = null,
       isDirty = false,
       isMultiLine = false,
       requiredEmpty = false,
       outOfDomainValue = null;

  /// 提示格錨點（測試與語意定位用）。
  static const Key hintKey = ValueKey('field-block-hint');

  /// label 錨點。
  static const Key labelKey = ValueKey('field-block-label');

  /// 驗證狀態、原因、取回方式之間的分隔。
  static const String hintSeparator = ' ';

  /// 提示或錯誤文字最大行數（4.48 內容政策）。
  static const int _hintMaxLines = 3;

  final bool _readOnly;

  /// 欄位 label：frontmatter 鍵名字面值，不進 i18n。
  final String label;

  /// 值格（`editable`：輸入元件之一；`readOnly`：`AppText`）。
  final Widget value;

  /// 呼叫端提供的補充提示（最低優先序）。
  final String? supportingText;

  /// `true` 時 [supportingText] 以錯誤色呈現。
  final bool isError;

  /// 本欄最近一次寫入；`null` 為 idle。
  final FieldWriteState? writeState;

  /// 值格回報有未送出的草稿（4.44 `onDirtyChanged`）。
  final bool isDirty;

  /// 值格為多行輸入（未送出提示的提交鍵不同）。
  final bool isMultiLine;

  /// 必填欄位送出空白，呼叫端未發出寫入（SPEC-009 FR-09）。
  final bool requiredEmpty;

  /// 目前值不在可選值內時的原值（4.45、4.46、4.47 的 outOfDomain）。
  final String? outOfDomainValue;

  /// 呼叫端定址 key（`card-nodeDetail-field-<fieldKey>`）。
  final Key testKey;

  /// 優先序：writing > 寫入失敗 > 必填空白 > 未送出 > written > outOfDomain
  /// > supportingText；同一時間只取一則（4.48 狀態矩陣）。
  _Hint? _resolveHint(AppLocalizations l10n) {
    if (_readOnly) return _Hint(l10n.fieldNotEditableHint);
    final state = writeState;
    if (state != null && state.isWriting) {
      return _Hint(l10n.fieldWriteInProgress);
    }
    if (state != null && state.isShownFailure) {
      return _Hint(_failureText(l10n, state), isError: true);
    }
    if (requiredEmpty) return _Hint(l10n.fieldRequiredEmpty, isError: true);
    if (isDirty) {
      return _Hint(
        isMultiLine
            ? l10n.fieldDraftUnsentHintMultiLine
            : l10n.fieldDraftUnsentHint,
      );
    }
    if (state != null && state.isWritten) return _writtenHint(l10n, state);
    final outOfDomain = outOfDomainValue;
    if (outOfDomain != null) {
      return _Hint(l10n.fieldValueOutOfDomain(outOfDomain));
    }
    final support = supportingText;
    return support == null ? null : _Hint(support, isError: isError);
  }

  String _failureText(AppLocalizations l10n, FieldWriteState state) =>
      switch (state.blockedReason) {
        FieldBlockedReason.snapshotFailed => l10n.fieldBlockedSnapshotFailed,
        FieldBlockedReason.rewriteNotIsolated =>
          l10n.fieldBlockedRewriteNotIsolated,
        _ => l10n.fieldIoFailed,
      };

  _Hint _writtenHint(AppLocalizations l10n, FieldWriteState state) {
    final validation = switch (state.validation!) {
      FieldValidation.running => l10n.validationRunning,
      FieldValidation.passed => l10n.validationPassed,
      FieldValidation.failed => l10n.validationFailed(state.newIssueCount),
      FieldValidation.unavailable =>
        '${l10n.validationUnavailable}$hintSeparator'
            '${_unavailableReason(l10n, state.unavailableReason!)}',
    };
    final text = state.hasSnapshot
        ? '$validation$hintSeparator${l10n.fieldSeeWriteLogHint}'
        : validation;
    return _Hint(text, isError: state.validation == FieldValidation.failed);
  }

  String _unavailableReason(
    AppLocalizations l10n,
    FieldValidationUnavailableReason reason,
  ) => switch (reason) {
    FieldValidationUnavailableReason.executableMissing =>
      l10n.validationUnavailableExecutableMissing,
    FieldValidationUnavailableReason.unexpectedExitCode =>
      l10n.validationUnavailableUnexpectedExitCode,
    FieldValidationUnavailableReason.unparsableOutput =>
      l10n.validationUnavailableUnparsableOutput,
    FieldValidationUnavailableReason.timedOut =>
      l10n.validationUnavailableTimedOut,
    FieldValidationUnavailableReason.baselineNotReady =>
      l10n.validationUnavailableBaselineNotReady,
  };

  @override
  Widget build(BuildContext context) {
    final hint = _resolveHint(AppLocalizations.of(context));
    return Column(
      key: testKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.singleLine(label, key: labelKey, secondary: true),
        SizedBox(height: Space.xs),
        Semantics(hint: hint?.text, child: value),
        if (hint != null) ...[
          SizedBox(height: Space.xs),
          _HintCell(hint: hint),
        ],
      ],
    );
  }
}

/// 提示格：`caption` 字級、最多三行末行截斷；`liveRegion` 播報，內容改變時
/// 靜態替換、不移動焦點（4.48 狀態變更提示）。
///
/// 不經 `AppText`：`AppText.caption` 恆單行，而 4.48 內容政策要求提示最多
/// 三行，且錯誤色不在 `AppTextTone` 內。
class _HintCell extends StatelessWidget {
  const _HintCell({required this.hint});

  final _Hint hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: FieldBlock.hintKey,
      liveRegion: true,
      container: true,
      child: Text(
        hint.text,
        maxLines: FieldBlock._hintMaxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppFontSize.caption.sp,
          color: hint.isError ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }
}
