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

  /// 目前排入的驗證與 baseline 全部完成。
  Future<void> get idle => _tail;

  /// 開始編輯或放棄並重讀：重跑 baseline。
  void startBaseline() {
    _enqueue(() async {
      _baseline = await _measure();
      _logMeasure('baseline', _baseline!);
    });
  }

  /// `written` 受理之後呼叫：先通知 `running`，再排入量測與判定。
  void validateAfterWrite() {
    _onStatus(const ValidationRunning());
    _enqueue(() async {
      final baseline =
          _baseline ?? const MeasureUnavailable(UnavailableReason.timedOut);
      final status = baseline is MeasureUnavailable
          ? ValidationUnavailable(baseline.reason)
          : await _judge(baseline);
      _logStatus(status);
      _onStatus(status);
    });
  }

  Future<ValidationStatus> _judge(ValidationMeasure baseline) async {
    final after = await _measure();
    final status = judgeAgainstBaseline(baseline, after);
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
