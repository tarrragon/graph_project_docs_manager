import 'package:graph_project_docs_manager/edit/corpus_parsed_source.dart';
import 'package:graph_project_docs_manager/edit/edit_file_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_port.dart';
import 'package:graph_project_docs_manager/edit/edit_git_runner.dart';
import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/field_rewrite.dart';
import 'package:graph_project_docs_manager/edit/session_write_list.dart';
import 'package:graph_project_docs_manager/edit/workspace_relative_path.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart'
    hide WorkspaceRelativePath;

export 'package:graph_project_docs_manager/edit/edit_git_runner.dart'
    show EditTimer;

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

  /// 本 App session 的寫入清單（SPEC-009 FR-08）。
  SessionWriteList get writeList => _context.writeList;

  static Future<EditWorkspace> open({
    required String root,
    required EditGitPort git,
    required EditFilePort files,
    EditTimer? timer,
    DateTime Function()? now,
    FieldRewriter? rewriter,
    EditValidatorPort? validator,
    LogSink<EditLogEvent>? logSink,
  }) async {
    final sink = logSink ?? defaultEditLogSink();
    final editTimer = timer ?? (duration) => Future<void>.delayed(duration);
    final runner = EditGitRunner(port: git, timer: editTimer, root: root);
    final reason = await _probeReadonlyReason(runner);
    final mode = reason == null ? EditMode.writable : EditMode.readOnly;
    _logMode(sink, mode, reason);
    return EditWorkspace._(
      mode,
      reason,
      EditGateContext(
        files: files,
        git: runner,
        now: now ?? DateTime.now,
        rewriter: rewriter ?? rewriteFrontmatterField,
        writeList: SessionWriteList(),
        workspaceRoot: root,
        validator: validator == null
            ? null
            : EditValidatorRunner(
                port: validator,
                timer: editTimer,
                logSink: sink,
              ),
        logSink: sink,
      ),
    );
  }

  static void _logMode(
    LogSink<EditLogEvent> sink,
    EditMode mode,
    EditReadonlyReason? reason,
  ) => sink(
    EditLogEvent.editModeDetermined,
    LogFields({
      EditLogKeys.mode: LogValue.enumValue(mode),
      if (reason != null)
        EditLogKeys.readonlyReason: LogValue.enumValue(reason),
    }),
  );

  static Future<EditReadonlyReason?> _probeReadonlyReason(
    EditGitRunner runner,
  ) async {
    final outcome = await runner.run(['rev-parse', '--is-inside-work-tree']);
    // 無法啟動、逾時、執行期例外都是「git 無法執行」：由 editModeDetermined
    // 的 gitMissing 表達，不另記失敗事件（SPEC-009 FR-07 v1.14）。
    if (outcome is! EditGitCompleted) return EditReadonlyReason.gitMissing;
    final result = outcome.result;
    final inside =
        result.exitCode == 0 &&
        String.fromCharCodes(result.stdout).trim() == 'true';
    return inside ? null : EditReadonlyReason.notGit;
  }

  /// 開始編輯：本 domain 自己讀取目標檔位元組作為 M（不取 Corpus 解析時的
  /// 內容）。寫入函式的唯一路徑入口，只收 [WorkspaceRelativePath]。
  Future<BeginEditingResult> beginEditing(
    WorkspaceRelativePath path, {
    CorpusParsedSource? corpusParsed,
  }) async {
    if (mode == EditMode.readOnly) return const EditingReadOnly();
    try {
      final baseline = await _context.files.read(path.absolute);
      return EditingStarted(
        EditSession(_context, path, baseline, corpusParsed: corpusParsed),
      );
    } on EditFileException catch (error) {
      (_context.logSink ?? defaultEditLogSink())(
        EditLogEvent.readIoFailed,
        LogFields({
          EditLogKeys.path: editLogPath(path.relative),
          EditLogKeys.operation: const LogValue.enumValue(
            IoOperation.readTarget,
          ),
          if (error.errorCode != null)
            EditLogKeys.errorCode: LogValue.integer(error.errorCode!),
        }),
        level: LogLevel.error,
        source: ErrorSource.platformIo,
      );
      return EditingReadFailed(
        IoFailure(IoOperation.readTarget, errorCode: error.errorCode),
      );
    }
  }
}
