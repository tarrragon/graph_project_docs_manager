import 'dart:developer' as developer;

import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/validation_baseline.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

const String _tag = 'edit.validation';
const int _infoLevel = 800;
const int _warningLevel = 900;
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
  });

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
      _logMeasure('baseline', measure);
    } on Object catch (error) {
      developer.log(
        'baseline failed: ${error.runtimeType}', // i18n-exempt
        name: _tag,
        level: _warningLevel,
      );
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
      developer.log(
        'validation job failed: ${error.runtimeType}', // i18n-exempt
        name: _tag,
        level: _warningLevel,
      );
    });
  }

  void _logMeasure(String what, ValidationMeasure measure) {
    developer.log(
      '$what: ${measure.runtimeType} $_relativePath', // i18n-exempt
      name: _tag,
      level: _infoLevel,
    );
  }

  void _logStatus(ValidationStatus status) {
    developer.log(
      'validationCompleted: $status $_relativePath', // i18n-exempt
      name: _tag,
      level: status is ValidationPassed ? _infoLevel : _warningLevel,
    );
  }
}

/// 節點 ID：取檔名開頭的 `<前綴>-<編號>`（如 `SPEC-900.md`、
/// `EVT-X-001-a.md`）；取不到時回傳 null。
String? _nodeIdOf(String relativePath) {
  final name = relativePath.substring(relativePath.lastIndexOf('/') + 1);
  return _nodeIdPattern.firstMatch(name)?.group(0);
}
