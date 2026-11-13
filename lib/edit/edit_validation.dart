import 'package:graph_project_docs_manager/edit/edit_log_event.dart';
import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/validation_baseline.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';
import 'package:graph_project_docs_manager/observability/log_enums.dart';
import 'package:graph_project_docs_manager/observability/log_sink.dart';
import 'package:graph_project_docs_manager/observability/log_values.dart';

final RegExp _nodeIdPattern = RegExp(r'^[A-Z]+(?:-[A-Z]+)*-\d+(?:\.\d+)*');

/// 需求：[SPEC-009 FR-05] 一個編輯 session 的寫入後驗證：開始編輯時量 baseline，
/// 每次 `written` 之後非同步量測並以差集判定；驗證一律排入同一條佇列依序執行，
/// 使「上一次寫入後的結果成為下一次的 baseline」成立，也使驗證不阻擋輸入。
/// 驗證失敗不回滾、不寫檔。
class ValidationCoordinator {
  ValidationCoordinator({
    required this._runner,
    required this._relativePath,
    required this._onStatus,
    LogSink<EditLogEvent>? logSink,
  }) : _log = logSink ?? defaultEditLogSink();

  final LogSink<EditLogEvent> _log;
  final EditValidatorRunner _runner;
  final String _relativePath;
  final void Function(ValidationStatus) _onStatus;

  ValidationMeasure? _baseline;
  Future<void> _tail = Future.value();
  Future<void> _baselineRun = Future.value();
  bool _baselinePending = false;
  int _epoch = 0;

  /// 已排入的寫入後驗證全部完成（不含 baseline 量測）。
  Future<void> get idle => _tail;

  /// baseline 量測完成（或已被丟棄）。
  Future<void> get baselineIdle => _baselineRun;

  /// baseline 量測尚未完成。寫入在 rename 前讀取此值（SPEC-009 FR-05 v1.7）。
  bool get baselinePending => _baselinePending;

  /// 開始編輯或放棄並重讀：重跑 baseline。量測不排入驗證佇列，使尚未完成的
  /// baseline 不阻擋寫入後驗證。
  void startBaseline() {
    final epoch = ++_epoch;
    _baseline = null;
    _baselinePending = true;
    _baselineRun = _measureBaseline(epoch);
  }

  Future<void> _measureBaseline(int epoch) async {
    try {
      final measure = await _measure();
      if (epoch != _epoch) return; // 已被丟棄：之後才完成的結果不採用
      _baseline = measure;
      _baselinePending = false;
      _logBaselineMeasured(measure);
    } on Object catch (error) {
      _logInternalFailure(EditLogEvent.baselineFailed, error);
    }
  }

  /// `written` 受理之後呼叫：先通知 `running`，再排入量測與判定。
  /// [baselineWasPending] 為 rename 前 baseline 尚未完成：丟棄該 baseline。
  void validateAfterWrite({required bool baselineWasPending}) {
    if (baselineWasPending) {
      _epoch++;
      _baseline = null;
      _baselinePending = false;
    }
    _onStatus(const ValidationRunning());
    _enqueue(() async {
      final status = await _judge(_baseline);
      _logStatus(status);
      _onStatus(status);
    });
  }

  /// 沒有可用 baseline：結果為 `baselineNotReady`，並以寫入後問題集合接替；
  /// baseline 為 unavailable：不量測；其餘做差集，寫入後無法判定時保留原
  /// baseline。
  Future<ValidationStatus> _judge(ValidationMeasure? baseline) async {
    if (baseline is MeasureUnavailable) {
      return ValidationUnavailable(baseline.reason);
    }
    final after = await _measure();
    final status = baseline == null
        ? const ValidationUnavailable(UnavailableReason.baselineNotReady)
        : judgeAgainstBaseline(baseline, after);
    if (after is MeasureReady) {
      _baseline = after;
    }
    return status;
  }

  /// 兩個驗證器依序量測；任一無法判定即停止。
  Future<ValidationMeasure> _measure() async {
    final outcomes = <ValidatorTool, ToolOutcome>{};
    for (final tool in ValidatorTool.values) {
      final outcome = await _runner.run(tool, _targetOf(tool));
      outcomes[tool] = outcome;
      if (outcome is ToolUnavailable) break;
    }
    return measureFromOutcomes(outcomes);
  }

  String _targetOf(ValidatorTool tool) => switch (tool) {
    ValidatorTool.docValidate => _nodeIdOf(_relativePath) ?? _relativePath,
    ValidatorTool.ucVerify => _relativePath,
  };

  void _enqueue(Future<void> Function() job) {
    _tail = _tail.then((_) => job()).catchError((Object error) {
      _logInternalFailure(EditLogEvent.validationJobFailed, error);
    });
  }

  /// 未預期例外：App 自身缺陷，歸 internal。
  void _logInternalFailure(EditLogEvent event, Object error) => _log(
    event,
    LogFields.empty,
    level: LogLevel.warning,
    source: ErrorSource.internal,
    error: error,
  );

  /// `_relativePath` 已是工作區相對路徑；以 `/` 為根轉成白名單路徑值。
  LogValue get _pathValue => LogValue.path('/', '/$_relativePath');

  void _logBaselineMeasured(ValidationMeasure measure) => _log(
    EditLogEvent.baselineMeasured,
    LogFields({
      EditLogKeys.path: _pathValue,
      EditLogKeys.measure: LogValue.enumValue(
        measure is MeasureReady
            ? EditMeasureKind.ready
            : EditMeasureKind.unavailable,
      ),
    }),
  );

  /// 失敗與無法判定不帶 error_source：驗證器端已各記一次（FR-02）。
  void _logStatus(ValidationStatus status) => _log(
    EditLogEvent.validationCompleted,
    LogFields({
      EditLogKeys.path: _pathValue,
      EditLogKeys.outcome: LogValue.enumValue(_outcomeOf(status)),
      ...switch (status) {
        ValidationFailed(:final newIssueCount) => {
          EditLogKeys.newIssueCount: LogValue.integer(newIssueCount),
        },
        ValidationUnavailable(:final reason) => {
          EditLogKeys.unavailableReason: LogValue.enumValue(reason),
        },
        _ => const <String, LogValue>{},
      },
    }),
    level: status is ValidationPassed ? LogLevel.info : LogLevel.warning,
  );
}

EditValidationOutcome _outcomeOf(ValidationStatus status) => switch (status) {
  ValidationPassed() => EditValidationOutcome.passed,
  ValidationFailed() => EditValidationOutcome.failed,
  _ => EditValidationOutcome.unavailable,
};

/// 節點 ID：取檔名開頭的 `<前綴>-<編號>`（如 `SPEC-900.md`、
/// `EVT-X-001-a.md`）；取不到時回傳 null。
String? _nodeIdOf(String relativePath) {
  final name = relativePath.substring(relativePath.lastIndexOf('/') + 1);
  return _nodeIdPattern.firstMatch(name)?.group(0);
}
