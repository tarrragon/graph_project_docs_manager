// SPEC-009 測試設計 P-9：寫入函式的參數型別不接受 String（FR-04 驗收 #5）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _analyze(String file) async {
  final r = await Process.run('fvm', ['dart', 'analyze', file]);
  return '${r.stdout}${r.stderr}';
}

void main() {
  const dir = 'test/fixtures/edit/path_type';
  const slow = Timeout(Duration(minutes: 8));

  test('P-9 negative：String 呼叫有 error，位置在該呼叫行', () async {
    final out = await _analyze('$dir/negative.dart');
    final lines = File('$dir/negative.dart').readAsLinesSync();
    final callLine = lines.indexWhere((l) => l.contains("writeDocument('")) + 1;
    expect(out, contains('error'));
    expect(out, contains('negative.dart:$callLine:'));
  }, timeout: slow);

  test('P-9 positive：WorkspaceRelativePath 呼叫零 error', () async {
    final out = await _analyze('$dir/positive.dart');
    expect(out, isNot(contains('error')));
  }, timeout: slow);
}
