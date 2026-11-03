// 需求：0.6.0-W1-106.1，lib 不得重新匯出 StateHolderOverride（測試輔助 API）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 整段 export 指令（從 export 到下一個 ;，允許跨行），捕捉 URI 與組合子。
final _exportDirective = RegExp(r'''\bexport\s+['"]([^'"]+)['"]([^;]*);''');
final _showClause = RegExp(r'\bshow\b([^;]*)');

/// 判定單一檔案內容是否把 StateHolderOverride 匯出到模組外。
///
/// 前提：lib 內禁止 export state_holder 的 extension，所以不另外偵測
/// 遞移匯出（A export B、B export state_holder）。
/// 目標為 state/state_holder.dart 時：無 show、使用 hide、或 show 清單含
/// StateHolderOverride 皆判違規。
bool reexportsStateHolderOverride(String source) {
  return _exportDirective.allMatches(source).any((m) {
    if (!m.group(1)!.endsWith('state/state_holder.dart')) return false;
    final combinators = m.group(2)!;
    if (combinators.contains(RegExp(r'\bhide\b'))) return true;
    final show = _showClause.firstMatch(combinators);
    if (show == null) return true;
    return RegExp(r'\bStateHolderOverride\b').hasMatch(show.group(1)!);
  });
}

void main() {
  const target = 'package:x/state/state_holder.dart';
  final violations = <String, String>{
    '裸 export': "export '$target';",
    'hide 其他成員': "export '$target' hide Foo;",
    'show 多名且非第一個': "export '$target' show Foo, StateHolderOverride;",
    'show 後換行': "export '$target'\n    show\n    StateHolderOverride;",
    '單名 show': "export '$target'\n    show StateHolderOverride;",
  };
  violations.forEach((name, source) {
    test('正向對照：$name 判為違規', () {
      expect(reexportsStateHolderOverride(source), isTrue);
    });
  });

  test('合法輸入：只 show 其他符號、import 與無關 export 判為合法', () {
    expect(
      reexportsStateHolderOverride("export '$target' show Foo, Bar;"),
      isFalse,
    );
    expect(reexportsStateHolderOverride("import '$target';"), isFalse);
    expect(reexportsStateHolderOverride("export 'package:x/y.dart';"), isFalse);
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
