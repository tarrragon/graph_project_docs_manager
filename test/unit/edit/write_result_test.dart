import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';

/// 需求：[SPEC-009 FR-05] 寫入結果型別與三個可觀測時刻（test-design §3 V-1～V-3）。
Future<WriteResult> _writeTitle(EditSession session) =>
    session.writeField(field: 'title', newValue: '新標題');

String _describe(WriteObservation observation) => switch (observation) {
  WriteInProgress() => 'inProgress',
  WriteAccepted(:final result) => 'accepted:${_resultName(result)}',
  ValidationObserved(:final status) => 'validation:${_statusName(status)}',
};

String _resultName(WriteResult result) => switch (result) {
  Written() => 'written',
  Blocked(:final reason) => 'blocked:${reason.name}',
  IoFailed() => 'ioFailed',
};

String _statusName(ValidationStatus status) => switch (status) {
  ValidationRunning() => 'running',
  ValidationPassed() => 'passed',
  ValidationFailed() => 'failed',
  ValidationUnavailable(:final reason) => 'unavailable:${reason.name}',
};

void main() {
  test('V-1 三個時刻依序為寫入進行中、受理 written、驗證 running', () async {
    final h = await EditHarness.create(
      validator: FakeValidatorPort(
        validate: const [validatorOk, ValidatorHang()],
      ),
    );
    final session = await h.begin();
    final seen = <WriteObservation>[];
    session.observations.listen(seen.add);
    await _writeTitle(session);
    expect(seen.map(_describe), [
      'inProgress',
      'accepted:written',
      'validation:running',
    ]);
  });

  test('V-2 W≠M：只有受理 blocked(externallyModified)，無進行中與驗證', () async {
    final h = await EditHarness.create(validator: FakeValidatorPort());
    final session = await h.begin();
    h.files.readScript[1] = flipLastByte(h.target!);
    final seen = <WriteObservation>[];
    session.observations.listen(seen.add);
    await _writeTitle(session);
    await session.validationIdle;
    expect(seen.map(_describe), ['accepted:blocked:externallyModified']);
  });

  test('V-3 WriteResult 為封閉型別：窮舉 switch，blocked 帶三種原因之一', () {
    const results = <WriteResult>[
      Written(),
      Blocked(BlockedReason.externallyModified),
      Blocked(BlockedReason.snapshotFailed),
      Blocked(BlockedReason.rewriteNotIsolated),
      IoFailed(IoFailure(IoOperation.rename)),
    ];
    expect(results.map(_resultName), [
      'written',
      'blocked:externallyModified',
      'blocked:snapshotFailed',
      'blocked:rewriteNotIsolated',
      'ioFailed',
    ]);
    expect(BlockedReason.values, hasLength(3));
  });

  test('V-3 對照：ioFailed 有進行中與受理，且不啟動驗證', () async {
    final h = await EditHarness.create(validator: FakeValidatorPort());
    final session = await h.begin();
    h.files.failOp('rename');
    final seen = <WriteObservation>[];
    session.observations.listen(seen.add);
    await _writeTitle(session);
    await session.validationIdle;
    expect(seen.map(_describe), ['inProgress', 'accepted:ioFailed']);
  });
}
