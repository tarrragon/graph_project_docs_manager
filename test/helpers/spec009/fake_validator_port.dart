import 'dart:async';

import 'package:graph_project_docs_manager/edit/edit_validator_port.dart';
import 'package:graph_project_docs_manager/edit/validation_baseline.dart';

import 'manual_edit_timer.dart';

/// [FakeValidatorPort] 對一次呼叫的回應。
sealed class ValidatorReply {
  const ValidatorReply();
}

/// 立即以指定結束碼與 stdout 結束。
final class ValidatorExit extends ValidatorReply {
  const ValidatorExit(this.code, [this.stdout = '']);

  final int code;
  final String stdout;
}

/// 行程無法啟動（`uv` 或 doc CLI 不存在）。
final class ValidatorLaunchFail extends ValidatorReply {
  const ValidatorLaunchFail();
}

/// 永不完成。
final class ValidatorHang extends ValidatorReply {
  const ValidatorHang();
}

/// 於虛擬時間 [delay] 之後以指定結束碼完成（需傳入計時器）。
final class ValidatorAfter extends ValidatorReply {
  const ValidatorAfter(this.delay, this.code, [this.stdout = '']);

  final Duration delay;
  final int code;
  final String stdout;
}

const ValidatorExit validatorOk = ValidatorExit(0);

/// 需求：[SPEC-009-test-design §1.4] 依 CLI 名稱回傳 `(結束碼, stdout)`；可設定
/// 無法執行、永不完成、於指定虛擬時間完成；記錄呼叫與被終止的子行程。
///
/// 回應依驗證器各自的呼叫序消耗：第 n 次呼叫取該驗證器清單的第 n 項，用盡後
/// 重複最後一項。
class FakeValidatorPort implements EditValidatorPort {
  FakeValidatorPort({
    List<ValidatorReply> validate = const [validatorOk],
    List<ValidatorReply> ucVerify = const [validatorOk],
    this.timer,
  }) : _script = {
         ValidatorTool.docValidate: validate,
         ValidatorTool.ucVerify: ucVerify,
       };

  final Map<ValidatorTool, List<ValidatorReply>> _script;
  final ManualEditTimer? timer;
  final List<EditValidatorInvocation> calls = [];
  final List<EditValidatorInvocation> killed = [];
  final Map<ValidatorTool, int> _counts = {};

  List<(ValidatorTool, String)> get callKeys => [
    for (final call in calls) (call.tool, call.target),
  ];

  @override
  Future<EditValidatorCall> start(EditValidatorInvocation invocation) async {
    calls.add(invocation);
    final script = _script[invocation.tool]!;
    final index = _counts[invocation.tool] ?? 0;
    _counts[invocation.tool] = index + 1;
    final reply = script[index < script.length ? index : script.length - 1];
    if (reply is ValidatorLaunchFail) {
      throw const EditValidatorLaunchException('fake: cannot launch');
    }
    return _FakeCall(this, invocation, _resultOf(reply));
  }

  Future<EditValidatorResult> _resultOf(ValidatorReply reply) =>
      switch (reply) {
        ValidatorExit() => Future.value(
          EditValidatorResult(exitCode: reply.code, stdout: reply.stdout),
        ),
        ValidatorAfter() =>
          timer!
              .call(reply.delay)
              .then(
                (_) => EditValidatorResult(
                  exitCode: reply.code,
                  stdout: reply.stdout,
                ),
              ),
        _ => Completer<EditValidatorResult>().future,
      };
}

class _FakeCall implements EditValidatorCall {
  _FakeCall(this._port, this._invocation, this.result);

  final FakeValidatorPort _port;
  final EditValidatorInvocation _invocation;

  @override
  final Future<EditValidatorResult> result;

  @override
  void kill() => _port.killed.add(_invocation);
}
