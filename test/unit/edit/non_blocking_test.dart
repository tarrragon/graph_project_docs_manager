import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/edit/write_result.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';

/// 需求：[SPEC-009 NFR-01] 驗證不阻擋輸入（test-design §3 N-1、N-2）。
/// 寫入受理延遲以量測填入規格，不作 pass／fail 斷言（D1）。
void main() {
  test('N-1 驗證永不完成：WriteResult 在驗證完成前即可取得', () async {
    final h = await EditHarness.create(
      validator: FakeValidatorPort(
        validate: const [validatorOk, ValidatorHang()],
      ),
    );
    final session = await h.begin();
    final seen = <WriteObservation>[];
    session.observations.listen(seen.add);
    final result = await session.writeField(field: 'title', newValue: '新標題');
    expect(result, isA<Written>());
    expect(seen.whereType<ValidationObserved>().map((o) => o.status), [
      isA<ValidationRunning>(),
    ]);
  });

  test('N-2 驗證仍為 running：對同一檔的另一欄位修正可受理並 written', () async {
    final h = await EditHarness.create(
      validator: FakeValidatorPort(
        validate: const [validatorOk, ValidatorHang()],
      ),
    );
    final session = await h.begin();
    await session.writeField(field: 'title', newValue: '新標題');
    final second = await session.writeField(field: 'priority', newValue: 'P0');
    expect(second, isA<Written>());
  });
}
