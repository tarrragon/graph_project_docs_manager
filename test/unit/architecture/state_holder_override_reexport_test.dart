// 需求：0.6.0-W1-106.1，lib 不得重新匯出 StateHolderOverride（測試輔助 API）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _reexportToken = 'show StateHolderOverride';

/// 判定單一檔案內容是否含 StateHolderOverride 重新匯出。
bool reexportsStateHolderOverride(String source) =>
    source.contains(_reexportToken);

void main() {
  test('正向對照：含重新匯出的輸入判為違規', () {
    expect(
      reexportsStateHolderOverride(
        "export 'package:x/state/state_holder.dart'\n    show StateHolderOverride;",
      ),
      isTrue,
    );
    expect(reexportsStateHolderOverride("import 'package:x/y.dart';"), isFalse);
  });

  test('lib 下沒有任何檔案含 show StateHolderOverride', () {
    final hits =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => reexportsStateHolderOverride(f.readAsStringSync()))
            .map((f) => f.path)
            .toList()
          ..sort();
    expect(hits, isEmpty, reason: '命中重新匯出：\n${hits.join('\n')}');
  });
}
