// 需求：0.6.0-W1-106，lib 不得再 import flutter_riverpod 的 legacy API。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _legacyImport = 'flutter_riverpod/legacy.dart';

/// 判定單一檔案內容是否含 legacy import。
bool importsRiverpodLegacy(String source) => source.contains(_legacyImport);

void main() {
  test('正向對照：含 legacy import 的輸入判為違規', () {
    expect(
      importsRiverpodLegacy("import 'package:flutter_riverpod/legacy.dart';"),
      isTrue,
    );
    expect(
      importsRiverpodLegacy(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      ),
      isFalse,
    );
  });

  test('lib 下沒有任何檔案 import flutter_riverpod/legacy.dart', () {
    final hits =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => importsRiverpodLegacy(f.readAsStringSync()))
            .map((f) => f.path)
            .toList()
          ..sort();
    expect(hits, isEmpty, reason: '命中 legacy import：\n${hits.join('\n')}');
  });
}
