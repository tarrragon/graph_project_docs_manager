import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spec007/graph_build_support.dart';
import '../../helpers/spec007/raw_node_builder.dart';

const _a = '0.1.0-W1-001';
const _b = '0.1.0-W1-002';

void main() {
  group('G5 relatedTo 1-hop 對稱聯集（FR-05）', () {
    test('G5-1 E1 鑑別：A 列出 B、B 未列出 A，邊 {A,B} 存在，宣告來源 {A}', () {
      final nodeB = buildRawNode(id: _b);
      final event = buildGraphEvent([
        buildRawNode(id: _a, extra: {'relatedTo': [_b]}),
        nodeB,
      ]);
      expect(edgeKeys(event), {'association|$_a|$_b|$_a'});
      // 未宣告的一端仍可由邊集合查得對方；只讀 B 自身欄位得空。
      final neighborsOfB = [
        for (final e in event.edges)
          if (e.from == _b || e.to == _b) e.from == _b ? e.to : e.from,
      ];
      expect(neighborsOfB, [_a]);
      // 對照：只讀 B 自身的 relatedTo 欄位查不到 A。
      expect(nodeB.frontmatter['relatedTo'], isNull);
    });

    test('G5-2 A、B 互列：一條邊，宣告來源 {A, B}', () {
      final event = buildGraphEvent([
        buildRawNode(id: _a, extra: {'relatedTo': [_b]}),
        buildRawNode(id: _b, extra: {'relatedTo': [_a]}),
      ]);
      expect(edgeKeys(event), {'association|$_a|$_b|$_a,$_b'});
      expect(event.edgeCount, 1);
    });

    test('G5-3 端點依字典序：(B,A) 與 (A,B) 宣告順序建圖，比對鍵相同', () {
      final nodeA = buildRawNode(id: _a, extra: {'relatedTo': [_b]});
      final nodeB = buildRawNode(id: _b);
      final ab = buildGraphEvent([nodeA, nodeB]);
      final ba = buildGraphEvent([nodeB, nodeA]);
      expect(edgeKeys(ab), edgeKeys(ba));

      // B 單向列出 A：起點排序仍為 (A, B)，宣告來源為 {B}。
      final reversed = buildGraphEvent([
        buildRawNode(id: _a),
        buildRawNode(id: _b, extra: {'relatedTo': [_a]}),
      ]);
      expect(edgeKeys(reversed), {'association|$_a|$_b|$_b'});
    });
  });
}
