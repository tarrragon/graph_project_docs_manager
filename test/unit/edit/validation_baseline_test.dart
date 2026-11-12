import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/validation_baseline.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';
import '../../helpers/spec009/manual_edit_timer.dart';

/// 需求：[SPEC-009 FR-05] baseline 差集判定、結束碼對應、`unavailable` 與驗證
/// 子行程逾時 30 秒（test-design §3 V-4～V-18）。
const Duration _validationTimeout = Duration(seconds: 30);
const String _ucTarget = 'docs/spec/x/SPEC-900.md';

class _Run {
  _Run(this.h, this.session, this.port, this.timer);

  final EditHarness h;
  final EditSession session;
  final FakeValidatorPort port;
  final ManualEditTimer timer;
  final List<WriteObservation> seen = [];

  ValidationStatus get lastStatus =>
      seen.whereType<ValidationObserved>().last.status;

  Future<void> advance(Duration duration) async {
    timer.advance(duration);
    await pumpEventQueue();
  }
}

Future<_Run> _start({
  List<ValidatorReply> validate = const [validatorOk],
  List<ValidatorReply> ucVerify = const [validatorOk],
}) async {
  final timer = ManualEditTimer();
  final port = FakeValidatorPort(
    validate: validate,
    ucVerify: ucVerify,
    timer: timer,
  );
  final h = await EditHarness.create(validator: port, timer: timer);
  final session = await h.begin();
  final run = _Run(h, session, port, timer);
  session.observations.listen(run.seen.add);
  await pumpEventQueue();
  return run;
}

ValidatorReply _uc(String uc, int count, {int firstLine = 4}) =>
    ValidatorExit(1, ucViolationOutput(uc, count, firstLine: firstLine));

Future<ValidationStatus> _write(
  _Run run, {
  String field = 'title',
  String value = '新標題',
}) async {
  await run.session.writeField(field: field, newValue: value);
  await run.session.validationIdle;
  return run.lastStatus;
}

void expectFailed(ValidationStatus status, int count) {
  expect(
    status,
    isA<ValidationFailed>().having((s) => s.newIssueCount, 'count', count),
  );
}

void expectUnavailable(ValidationStatus status, UnavailableReason reason) {
  expect(
    status,
    isA<ValidationUnavailable>().having((s) => s.reason, 'reason', reason),
  );
}

void main() {
  group('差集判定', () {
    test('V-4 寫入前已含兩次提及，寫入後仍兩次：passed', () async {
      final run = await _start(
        ucVerify: [_uc(unregisteredUc, 2), _uc(unregisteredUc, 2)],
      );
      expect(await _write(run), isA<ValidationPassed>());
    });

    test('V-5 寫入後三次：failed，新增問題數 1（對照 V-4）', () async {
      final run = await _start(
        ucVerify: [_uc(unregisteredUc, 2), _uc(unregisteredUc, 3)],
      );
      expectFailed(await _write(run), 1);
    });

    test('V-6 行號位移不算新增問題', () async {
      final run = await _start(
        ucVerify: [
          _uc(unregisteredUc, 2),
          _uc(unregisteredUc, 2, firstLine: 5),
        ],
      );
      expect(await _write(run), isA<ValidationPassed>());
    });

    test('V-14 baseline 有問題、寫入後無問題：passed', () async {
      final run = await _start(ucVerify: [_uc(unregisteredUc, 1), validatorOk]);
      expect(await _write(run), isA<ValidationPassed>());
    });

    test('V-11 第一次寫入後的結果成為新 baseline', () async {
      final run = await _start(ucVerify: [validatorOk, _uc(unregisteredUc, 1)]);
      expectFailed(await _write(run), 1);
      expect(
        await _write(run, field: 'priority', value: 'P0'),
        isA<ValidationPassed>(),
      );
    });

    test('V-5 另一識別值：新增不同 UC 編號算新增問題', () async {
      final run = await _start(
        ucVerify: [
          _uc(unregisteredUc, 1),
          ValidatorExit(
            1,
            ucViolationOutput(unregisteredUc, 1) +
                ucViolationOutput(unregisteredUc2, 1),
          ),
        ],
      );
      expectFailed(await _write(run), 1);
    });

    test('doc validate：baseline 的既有問題不算，新增一條判 failed', () async {
      final run = await _start(
        validate: [
          const ValidatorExit(1, docValidateFailureBase),
          const ValidatorExit(
            1,
            '$docValidateFailureBase  - 缺少 producer：EVT 必須至少一個 producer\n',
          ),
        ],
      );
      expectFailed(await _write(run), 1);
    });

    test('doc validate 對照：問題集合與 baseline 相同為 passed', () async {
      final run = await _start(
        validate: const [ValidatorExit(1, docValidateFailureBase)],
      );
      expect(await _write(run), isA<ValidationPassed>());
    });
  });

  group('結束碼', () {
    test('V-7 baseline 結束碼 2、寫入後仍 2：不判 failed', () async {
      final run = await _start(ucVerify: const [ValidatorExit(2)]);
      expect(await _write(run), isA<ValidationPassed>());
    });

    test('V-8 baseline 結束碼 0、寫入後 2：failed（對照 V-7）', () async {
      final run = await _start(ucVerify: const [validatorOk, ValidatorExit(2)]);
      expectFailed(await _write(run), 1);
    });

    test('V-10 結束碼 3：unavailable(unexpectedExitCode)，不是 passed', () async {
      final run = await _start(ucVerify: const [validatorOk, ValidatorExit(3)]);
      expectUnavailable(
        await _write(run),
        UnavailableReason.unexpectedExitCode,
      );
    });

    test('V-10 stdout 無法解析：unavailable(unparsableOutput)', () async {
      final run = await _start(
        ucVerify: const [validatorOk, ValidatorExit(1, '完全不是預期格式')],
      );
      expectUnavailable(await _write(run), UnavailableReason.unparsableOutput);
    });
  });

  group('unavailable 與 baseline', () {
    test('V-9 baseline 為 unavailable：兩次寫入都是 unavailable', () async {
      final run = await _start(
        validate: const [ValidatorLaunchFail(), validatorOk],
      );
      expectUnavailable(await _write(run), UnavailableReason.executableMissing);
      expectUnavailable(
        await _write(run, field: 'priority', value: 'P0'),
        UnavailableReason.executableMissing,
      );
    });

    test('V-12 failed 之後沒有任何寫入、rename 或刪除（不回滾）', () async {
      final run = await _start(
        ucVerify: [_uc(unregisteredUc, 2), _uc(unregisteredUc, 3)],
      );
      await run.session.writeField(field: 'title', newValue: '新標題');
      run.h.files.ops.clear();
      await run.session.validationIdle;
      expectFailed(run.lastStatus, 1);
      expect(run.h.files.ops, isEmpty);
    });

    test('V-13 驗證範圍只限本次檔案：兩個驗證器各帶目標，無全專案呼叫', () async {
      final run = await _start();
      await _write(run);
      expect(run.port.callKeys, [
        (ValidatorTool.docValidate, 'SPEC-900'),
        (ValidatorTool.ucVerify, _ucTarget),
        (ValidatorTool.docValidate, 'SPEC-900'),
        (ValidatorTool.ucVerify, _ucTarget),
      ]);
    });
  });

  group('逾時 30 秒', () {
    test('V-15 寫入後 doc validate 永不完成：終止子行程、unavailable(timedOut)', () async {
      final run = await _start(validate: const [validatorOk, ValidatorHang()]);
      final result = await run.session.writeField(
        field: 'title',
        newValue: '新標題',
      );
      run.h.files.ops.clear();
      await pumpEventQueue();
      expect(run.port.killed, isEmpty);
      await run.advance(_validationTimeout);
      await run.session.validationIdle;
      expect(result, isA<Written>());
      expectUnavailable(run.lastStatus, UnavailableReason.timedOut);
      expect(run.port.killed.map((c) => c.tool), [ValidatorTool.docValidate]);
      expect(run.h.files.ops, isEmpty);
    });

    test('V-17 29.9 秒完成：子行程未被終止，passed（對照 V-15）', () async {
      final run = await _start(
        validate: const [
          validatorOk,
          ValidatorAfter(Duration(milliseconds: 29900), 0),
        ],
      );
      await run.session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      await run.advance(const Duration(milliseconds: 29900));
      await run.session.validationIdle;
      expect(run.port.killed, isEmpty);
      expect(run.lastStatus, isA<ValidationPassed>());
    });

    test('V-18 兩個子行程各自計時：合計 40 秒不構成逾時', () async {
      const twenty = Duration(seconds: 20);
      final run = await _start(
        validate: const [validatorOk, ValidatorAfter(twenty, 0)],
        ucVerify: const [validatorOk, ValidatorAfter(twenty, 0)],
      );
      await run.session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      await run.advance(twenty);
      await run.advance(twenty);
      await run.session.validationIdle;
      expect(run.port.killed, isEmpty);
      expect(run.lastStatus, isA<ValidationPassed>());
    });

    test('V-16 baseline 逾時：整次編輯 unavailable；discardAndReload 後恢復', () async {
      final run = await _start(ucVerify: const [ValidatorHang(), validatorOk]);
      await run.advance(_validationTimeout);
      expectUnavailable(await _write(run), UnavailableReason.timedOut);
      expectUnavailable(
        await _write(run, field: 'priority', value: 'P0'),
        UnavailableReason.timedOut,
      );
      await run.session.discardAndReload();
      await pumpEventQueue();
      expect(
        await _write(run, field: 'priority', value: 'P1'),
        isA<ValidationPassed>(),
      );
    });
  });

  group('baseline 與寫入的先後（v1.7）', () {
    const tenSeconds = Duration(seconds: 10);

    test(
      'V-19 baseline 未完成即寫入：unavailable(baselineNotReady)，延遲的 baseline 被丟棄',
      () async {
        final run = await _start(
          ucVerify: [
            const ValidatorAfter(tenSeconds, 0),
            _uc(unregisteredUc, 1),
          ],
        );
        expectUnavailable(
          await _write(run),
          UnavailableReason.baselineNotReady,
        );
        await run.advance(tenSeconds);
        expect(await _write(run, value: '另一個標題'), isA<ValidationPassed>());
      },
    );

    test('V-20 寫入後驗證 unavailable：保留原 baseline', () async {
      final run = await _start(
        validate: const [validatorOk, ValidatorHang(), validatorOk],
        ucVerify: [validatorOk, _uc(unregisteredUc, 1)],
      );
      await run.session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      await run.advance(_validationTimeout);
      await run.session.validationIdle;
      expectUnavailable(run.lastStatus, UnavailableReason.timedOut);
      expectFailed(await _write(run, field: 'priority', value: 'P0'), 1);
    });

    test('V-21 沒有可用 baseline：第一個取得的寫入後問題集合成為下一次 baseline', () async {
      final run = await _start(
        validate: const [validatorOk, ValidatorHang(), validatorOk],
        ucVerify: [const ValidatorAfter(tenSeconds, 0), _uc(unregisteredUc, 1)],
      );
      await run.session.writeField(field: 'title', newValue: '新標題');
      await pumpEventQueue();
      await run.advance(_validationTimeout);
      await run.session.validationIdle;
      expectUnavailable(run.lastStatus, UnavailableReason.baselineNotReady);
      expectUnavailable(
        await _write(run, field: 'priority', value: 'P0'),
        UnavailableReason.baselineNotReady,
      );
      expect(
        await _write(run, field: 'priority', value: 'P1'),
        isA<ValidationPassed>(),
      );
    });
  });
}
