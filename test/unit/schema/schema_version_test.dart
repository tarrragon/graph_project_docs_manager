// 版本比較單一實作（SPEC-006-test-design.md S5-7；0.3.0-W3-533）。
//
// 依賴方向：test/unit/schema/ 不得 import lib/corpus/、lib/diagnostics/。

import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/schema/schema_version.dart';

void main() {
  group('isHigherThanBuiltinSchemaVersion', () {
    test('S5-7：2.40.3 對 2.40.10 判為低於（數值逐段比較，非字串比較）', () {
      // 若採字串比較，"2.40.3" > "2.40.10" 會成立（'3' > '1'）。
      expect(isHigherThanBuiltinSchemaVersion('2.40.3', '2.40.10'), isFalse);
    });

    test('版本相同判為不高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.40.3', '2.40.3'), isFalse);
    });

    test('版本較高判為高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.41.0', '2.40.3'), isTrue);
    });

    test('段數不足補零：2.40 對 2.40.0 判為不高於', () {
      expect(isHigherThanBuiltinSchemaVersion('2.40', '2.40.0'), isFalse);
    });

    test('無法解析為整數的段落視為高於（安全預設拒絕降級出口）', () {
      expect(isHigherThanBuiltinSchemaVersion('2.x.0', '2.40.3'), isTrue);
    });
  });
}
