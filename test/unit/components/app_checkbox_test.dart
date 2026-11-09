/// AppCheckbox 元件測試（SPEC-004 4.43）。
library;

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/components/components.dart';

import '../../helpers/helpers.dart';

void main() {
  const key = ValueKey('action-history-include-ticket-created');
  const labelText = 'Include ticket creation';

  Widget build({
    required bool value,
    ValueChanged<bool>? onChanged,
    String label = labelText,
  }) {
    return AppCheckbox(
      label: label,
      value: value,
      onChanged: onChanged ?? (_) {},
      testKey: key,
    );
  }

  testWidgetsAtEachSize('unchecked 與 checked 不溢位', (tester, size) async {
    await pumpHarness(tester, size: size, child: build(value: false));
    expectNoOverflow(tester);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await pumpHarness(tester, size: size, child: build(value: true));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgetsAtEachSize('點 label 呼叫 onChanged(!value) 恰一次', (
    tester,
    size,
  ) async {
    final calls = <bool>[];
    await pumpHarness(
      tester,
      size: size,
      child: build(value: false, onChanged: calls.add),
    );
    await tester.tap(find.text(labelText));
    expect(calls, [true]);
  });

  testWidgetsAtEachSize('點核取框呼叫 onChanged(!value)', (tester, size) async {
    final calls = <bool>[];
    await pumpHarness(
      tester,
      size: size,
      child: build(value: true, onChanged: calls.add),
    );
    await tester.tap(find.byType(Checkbox));
    expect(calls, [false]);
  });

  testWidgetsAtEachSize('語意含 label 並帶 checked 旗標', (tester, size) async {
    final handle = tester.ensureSemantics();
    await pumpHarness(tester, size: size, child: build(value: true));
    final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
    expect(data.label, contains(labelText));
    expect(data.flagsCollection.isChecked, CheckedState.isTrue);
    handle.dispose();
  });

  testWidgetsAtEachSize('最長 label 截斷不溢位', (tester, size) async {
    await pumpHarness(
      tester,
      size: size,
      child: SizedBox(
        width: 200,
        child: build(value: false, label: TestCopy.longToken),
      ),
    );
    expectNoOverflow(tester);
  });
}
