import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

export 'package:graph_project_docs_manager/edit/edit_git_runner.dart'
    show EditTimer;

const String _tag = 'edit.workspace';
const int _errorLevel = 900;

/// 工作區的編輯模式（由 Edit 在工作區開啟時判定，不放進 Workspace）。
enum EditMode { writable, readOnly }

/// 唯讀降級的原因（SPEC-001 §1〈唯讀降級〉）：[notGit] 資料夾不是 git
/// repo；[gitMissing] `git` 無法執行（找不到、逾時或行程錯誤）。
enum EditReadonlyReason { notGit, gitMissing }

/// `beginEditing` 的結果。
sealed class BeginEditingResult {
  const BeginEditingResult();
}

/// 已開始編輯，[session] 持有 M。
final class EditingStarted extends BeginEditingResult {
  const EditingStarted(this.session);

  final EditSession session;
}

/// 工作區唯讀降級：不產生 session，無任何寫入路徑可達。
final class EditingReadOnly extends BeginEditingResult {
  const EditingReadOnly();
}

/// 開始編輯時讀取失敗，不進入編輯。
final class EditingReadFailed extends BeginEditingResult {
  const EditingReadFailed(this.failure);

  final IoFailure failure;
}

/// 需求：[SPEC-009 FR-01] 編輯工作區：開啟時以工作區根探測 `git`，不是 git
/// repo 或 `git` 無法執行即唯讀降級；之後每次寫入不重判（編輯中 `git` 失效
/// 由閘門步驟 3 回傳 `snapshotFailed`，不靜默放行）。
class EditWorkspace {
  EditWorkspace._(this.mode, this.readonlyReason, this._context);

  final EditMode mode;

  /// 唯讀降級原因；[mode] 為 writable 時為 null。
  final EditReadonlyReason? readonlyReason;
  final EditGateContext _context;

  static Future<EditWorkspace> open({
    required String root,
    required EditGitPort git,
    required EditFilePort files,
    EditTimer? timer,
    DateTime Function()? now,
    FieldRewriter? rewriter,
    EditValidatorPort? validator,
  }) async {
    final editTimer = timer ?? (duration) => Future<void>.delayed(duration);
    final runner = EditGitRunner(port: git, timer: editTimer, root: root);
    final reason = await _probeReadonlyReason(runner);
    final mode = reason == null ? EditMode.writable : EditMode.readOnly;
    developer.log('edit mode: ${mode.name}', name: _tag); // i18n-exempt
    return EditWorkspace._(
      mode,
      reason,
      EditGateContext(
        files: files,
        git: runner,
        now: now ?? DateTime.now,
        rewriter: rewriter ?? rewriteFrontmatterField,
        validator: validator == null
            ? null
            : EditValidatorRunner(port: validator, timer: editTimer),
      ),
    );
  }

  static Future<EditReadonlyReason?> _probeReadonlyReason(
    EditGitRunner runner,
  ) async {
    final result = await runner.run(['rev-parse', '--is-inside-work-tree']);
    if (result == null) return EditReadonlyReason.gitMissing;
    final inside =
        result.exitCode == 0 &&
        String.fromCharCodes(result.stdout).trim() == 'true';
    return inside ? null : EditReadonlyReason.notGit;
  }

  /// 開始編輯：本 domain 自己讀取目標檔位元組作為 M（不取 Corpus 解析時的
  /// 內容）。寫入函式的唯一路徑入口，只收 [WorkspaceRelativePath]。
  Future<BeginEditingResult> beginEditing(WorkspaceRelativePath path) async {
    if (mode == EditMode.readOnly) return const EditingReadOnly();
    try {
      final baseline = await _context.files.read(path.absolute);
      return EditingStarted(EditSession(_context, path, baseline));
    } on EditFileException catch (error) {
      developer.log(
        'beginEditing read failed: code=${error.errorCode}', // i18n-exempt
        name: _tag,
        level: _errorLevel,
      );
      return EditingReadFailed(
        IoFailure(IoOperation.readTarget, errorCode: error.errorCode),
      );
    }
  }
}
