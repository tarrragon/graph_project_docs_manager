// SPEC-009 測試設計 P-9：寫入函式的參數型別不接受 String（FR-04 驗收 #5）。
//
// negative 以 .txt 入庫，執行時複製到 .dart_tool/（已被 git 忽略）再分析，
// 否則全 repo `dart analyze` 會分析到刻意寫錯的檔案而紅燈。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _analyze(String file) async {
  final r = await Process.run('fvm', ['dart', 'analyze', file]);
  return '${r.stdout}${r.stderr}';
}

void main() {
  const dir = 'test/fixtures/edit/path_type';
  const slow = Timeout(Duration(minutes: 8));
  final tmp = Directory('.dart_tool/p9_negative');

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('P-9 negative：String 呼叫有 error，位置在該呼叫行', () async {
    tmp.createSync(recursive: true);
    final source = File('$dir/negative.dart.txt').readAsLinesSync();
    File('${tmp.path}/negative.dart').writeAsStringSync(source.join('\n'));
    final out = await _analyze('${tmp.path}/negative.dart');
    final callLine =
        source.indexWhere((l) => l.contains("writeDocument('")) + 1;
    expect(out, contains('error'));
    expect(out, contains('negative.dart:$callLine:'));
  }, timeout: slow);

  test('P-9 positive：WorkspaceRelativePath 呼叫零 error', () async {
    final out = await _analyze('$dir/positive.dart');
    expect(out, isNot(contains('error')));
  }, timeout: slow);
}
