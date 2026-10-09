// SPEC-007 v1.28 FR-10 N-a：Layout 不自建 step id 索引、不以 flowKeyOf 比對
// next；next 邊的解析歸 Graph（0.5.0-W1-137 R3）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _selfResolvePattern = RegExp(
  r'\bflowKeyOf\s*\(|\b_?idIndex\b|\b_uniqueStepIndex\b',
);

/// 回傳原始碼中自建 step id 索引或以 flowKeyOf 比對的行。
List<String> selfResolvedStepIdLines(String source) => [
  for (final line in source.split('\n'))
    if (_selfResolvePattern.hasMatch(line)) line.trim(),
];

void main() {
  test('E2 正向對照：含自建 id 索引與 flowKeyOf 比對的樣本被攔下', () {
    const sample =
        'final idIndex = _idIndex(steps);\n'
        'final key = flowKeyOf(s.id);\n'
        'final ok = s.mainlineNextRefs;\n';
    expect(selfResolvedStepIdLines(sample), [
      'final idIndex = _idIndex(steps);',
      'final key = flowKeyOf(s.id);',
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
