// 需求：1.0.0-W3-553.17。寫入清單讀取端 provider：清單列隨 Edit domain 的
// 寫入與驗證結果重建；失敗計數只計 `failed`／`unavailable`（SPEC-001 §12）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/app/edit_providers.dart';
import 'package:graph_project_docs_manager/app/write_list_providers.dart';
import 'package:graph_project_docs_manager/edit/edit_session.dart';
import 'package:graph_project_docs_manager/workspace/current_workspace_provider.dart';
import 'package:graph_project_docs_manager/workspace/workspace_types.dart';

import '../../helpers/spec009/edit_gate_harness.dart';
import '../../helpers/spec009/fake_validator_port.dart';
import '../../helpers/spec009/frontmatter_fixtures.dart';

Future<(ProviderContainer, EditSession)> _setup(
  FakeValidatorPort validator,
) async {
  final h = await EditHarness.create(validator: validator);
  final session = await h.begin();
  final container = ProviderContainer(
    overrides: [editWorkspaceProvider.overrideWith((ref) async => h.workspace)],
  );
  addTearDown(container.dispose);
  await container.read(editWorkspaceProvider.future);
  return (container, session);
}

void main() {
  test('工作區未就緒：清單為空、計數 0', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentWorkspaceStateProvider.notifier).state =
        const WorkspaceUnset();

    expect(container.read(writeListEntriesProvider), isEmpty);
    expect(container.read(writeListFailureCountProvider), 0);
  });

  test('寫入受理後清單新增一列；驗證通過不計入失敗', () async {
    final (container, session) = await _setup(FakeValidatorPort());
    final entries = container.listen(writeListEntriesProvider, (_, _) {});
    expect(entries.read(), isEmpty);

    await session.writeField(field: 'title', newValue: 'a');
    await session.validationIdle;

    expect(entries.read().map((e) => (e.relativePath, e.field)), [
      (targetRelative, 'title'),
    ]);
    expect(container.read(writeListFailureCountProvider), 0);
  });

  test('驗證 failed 回來時計數立即加 1，並通知監聽者（不論面板是否開啟）', () async {
    final (container, session) = await _setup(
      FakeValidatorPort(
        ucVerify: [
          validatorOk,
          ValidatorExit(1, ucViolationOutput(unregisteredUc, 1)),
        ],
      ),
    );
    final counts = <int>[];
    container.listen<int>(
      writeListFailureCountProvider,
      (_, next) => counts.add(next),
    );
    expect(container.read(writeListFailureCountProvider), 0);

    await session.baselineIdle;
    await session.writeField(field: 'title', newValue: 'a');
    await session.validationIdle;

    expect(container.read(writeListFailureCountProvider), 1);
    expect(counts.last, 1);
  });

  test('驗證 unavailable 同樣計入（無法驗證不得視為通過）', () async {
    final (container, session) = await _setup(
      FakeValidatorPort(validate: [const ValidatorLaunchFail()]),
    );
    container.listen<int>(writeListFailureCountProvider, (_, _) {});

    await session.writeField(field: 'title', newValue: 'a');
    await session.validationIdle;

    expect(container.read(writeListFailureCountProvider), 1);
  });

  test('節點表：建圖不可用或尚無輪次時為空', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(writeListNodeIdByPathProvider), isEmpty);
  });
}
