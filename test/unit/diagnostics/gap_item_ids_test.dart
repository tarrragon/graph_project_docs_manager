// 需求：[SPEC-001 §5 表二] 破洞項 id 的唯一產生點（0.6.0-W1-080）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/diagnostics/gap_item_ids.dart';

void main() {
  test('成分以 URI component 編碼後以冒號串接', () {
    expect(
      gapItemIdOf(['parse-failure', 'a b/c.md']),
      'parse-failure:a%20b%2Fc.md',
    );
  });

  test('同輪內成分相同者第二筆起加 #N 後綴', () {
    final alloc = GapItemIdAllocator();
    final ids = [
      for (var i = 0; i < 3; i++) alloc.next(['x', 'p']),
    ];
    expect(ids, ['x:p', 'x:p#2', 'x:p#3']);
    expect(alloc.next(['x', 'q']), 'x:q');
  });
}
