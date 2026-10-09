// SPEC-007 v1.28 FR-10 N-a：Layout 不自建 step id 索引、不以 flowKeyOf 比對
// next；next 邊的解析歸 Graph（0.5.0-W1-137 R3）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _selfResolvePatterns = [
  // 舊符號名與 flowKeyOf 比對。
  RegExp(r'\bflowKeyOf\s*\(|\b_?idIndex\b|\b_uniqueStepIndex\b'),
  // 以步驟 id 逐一比對。
  RegExp(r'\.id\s*[!=]='),
  // 以步驟 id 當 Map key 建索引（字面鍵、下標、putIfAbsent）。
  RegExp(r'\.id\s*:|\[[^\]]*\.id\s*\]|putIfAbsent\([^)]*\.id'),
];

/// 回傳原始碼中自建 step id 索引或逐一比對 id 的行；註解行（`//`、`///`）不計。
List<String> selfResolvedStepIdLines(String source) => [
  for (final raw in source.split('\n'))
    if (!raw.trimLeft().startsWith('//') &&
        _selfResolvePatterns.any((p) => p.hasMatch(raw)))
      raw.trim(),
];

void main() {
  test('E2 正向對照：每條規則的違規寫法被攔下，合法與註解寫法不被誤攔', () {
    const sample =
        'final idIndex = _idIndex(steps);\n'
        'final key = flowKeyOf(s.id);\n'
        'final hit = steps.where((t) => t.id == s.next);\n'
        'final byId = {for (final t in steps) t.id: t.index};\n'
        'final slot = byId[s.id];\n'
        'final ok = s.mainlineNextRefs;\n'
        'final pos = step.index;\n'
        '/// 不再以 flowKeyOf( 比對 next\n'
        '  // idIndex 與 t.id == x 已移除\n';
    expect(selfResolvedStepIdLines(sample), [
      'final idIndex = _idIndex(steps);',
      'final key = flowKeyOf(s.id);',
      'final hit = steps.where((t) => t.id == s.next);',
      'final byId = {for (final t in steps) t.id: t.index};',
      'final slot = byId[s.id];',
    ]);
  });

  test('lib/layout 不自建 step id 索引、不以 flowKeyOf 比對 next', () {
    final files = Directory('lib/layout')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final violations = {
      for (final f in files)
        if (selfResolvedStepIdLines(f.readAsStringSync()) case final v
            when v.isNotEmpty)
          f.path: v,
    };
    expect(violations, isEmpty);
  });
}
