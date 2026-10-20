// 需求：[SPEC-001 §5〈專案層級宣告狀態一行〉；UC-02 ticket 定位；0.5.0-W1-119.2]
// Graph 專案層宣告彙整：bundle 宣告數、非 domain 側狀態、各票受影響路徑數
// 加總；整體未宣告時不提供路徑數（P3-4）。
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/corpus_scanner.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/graph/path_declaration_state.dart';
import 'package:graph_project_docs_manager/graph/project_path_declaration.dart';

RawNode _bundle(String id, {Object? patterns, bool declared = true}) => RawNode(
  path: 'docs/spec/$id/domain-map.md',
  typeName: 'DomainBundle',
  frontmatter: {'id': id, if (declared) 'path_patterns': patterns},
);

RawNode _ticket(String id, List<Object?> files) => RawNode(
  path: 'docs/work-logs/v0/tickets/$id.md',
  typeName: 'Ticket',
  frontmatter: {
    'id': id,
    'where': {'files': files},
  },
);

final _declared = NonDomainPathsReadDeclared(['docs/']);
const _absent = NonDomainPathsReadAbsent();

void main() {
  group('bundle 宣告數與非 domain 側', () {
    test('S1 5／8 宣告、清單有：計數與側別', () {
      final nodes = [
        for (var i = 0; i < 8; i++)
          _bundle('b$i', patterns: ['lib/b$i/'], declared: i < 5),
      ];

      final d = summarizeProjectPathDeclaration(
        rawNodes: nodes,
        nonDomain: _declared,
      );

      expect(d.declaredBundleCount, 5);
      expect(d.totalBundleCount, 8);
      expect(d.nonDomainSide, NonDomainSideState.declared);
      expect(d.overallUndeclared, isFalse);
      expect(d.hasGap, isTrue);
    });

    test('S2（守衛）兩側完整宣告 → 無缺口；S1 為正向對照', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [
          _bundle('a', patterns: ['lib/a/']),
        ],
        nonDomain: _declared,
      );

      expect(d.hasGap, isFalse);
    });

    test('S3 顯式空清單 path_patterns: [] 算已宣告', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [_bundle('a', patterns: <String>[])],
        nonDomain: _declared,
      );

      expect(d.declaredBundleCount, 1);
      expect(d.hasGap, isFalse);
    });

    test('S4 兩側皆無 → overallUndeclared，且為缺口', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [_bundle('a', declared: false)],
        nonDomain: _absent,
      );

      expect(d.overallUndeclared, isTrue);
      expect(d.hasGap, isTrue);
      expect(d.affectedPathCount, isNull);
    });

    test('S5 非 domain 清單格式錯誤與缺席是不同側別', () {
      final bundles = [
        _bundle('a', patterns: ['lib/a/']),
      ];
      final malformed = summarizeProjectPathDeclaration(
        rawNodes: bundles,
        nonDomain: NonDomainPathsReadMalformed(
          path: 'docs/nd.yaml',
          reason: NonDomainPathsWholeFileReason.yamlInvalid,
        ),
      );
      final absent = summarizeProjectPathDeclaration(
        rawNodes: bundles,
        nonDomain: _absent,
      );

      expect(malformed.nonDomainSide, NonDomainSideState.malformed);
      expect(absent.nonDomainSide, NonDomainSideState.absent);
      expect(malformed.affectedPathCount, absent.affectedPathCount);
    });
  });

  group('受影響路徑數：各票加總', () {
    test('S6 兩張票各有未命中的路徑 → 加總', () {
      // domain 側完整、清單缺 → 未命中者為 nonDomainUndeclared。
      final d = summarizeProjectPathDeclaration(
        rawNodes: [
          _bundle('a', patterns: ['lib/a/']),
          _ticket('T1', ['lib/a/x.dart', 'docs/one.md', 'docs/two.md']),
          _ticket('T2', ['docs/three.md']),
        ],
        nonDomain: _absent,
      );

      expect(d.affectedPathCount, 3);
    });

    test('S7 無票或票無 where.files → 0（非 null）', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [
          _bundle('a', patterns: ['lib/a/']),
          const RawNode(
            path: 'docs/t.md',
            typeName: 'Ticket',
            frontmatter: {'id': 'T9'},
          ),
        ],
        nonDomain: _absent,
      );

      expect(d.affectedPathCount, 0);
    });

    test('S8 where.files 內非字串元素略過', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [
          _bundle('a', patterns: ['lib/a/']),
          _ticket('T1', ['docs/one.md', 7, null]),
        ],
        nonDomain: _absent,
      );

      expect(d.affectedPathCount, 1);
    });

    test('S9 非 Ticket 型別的節點不計入', () {
      final d = summarizeProjectPathDeclaration(
        rawNodes: [
          _bundle('a', patterns: ['lib/a/']),
          RawNode(
            path: 'docs/p.md',
            typeName: 'PROP',
            frontmatter: const {
              'id': 'PROP-1',
              'where': {
                'files': ['docs/one.md'],
              },
            },
          ),
        ],
        nonDomain: _absent,
      );

      expect(d.affectedPathCount, 0);
    });

    test('S10（E1）清單從缺席變已宣告且涵蓋路徑 → 受影響數由 N 變 0', () {
      final nodes = [
        _bundle('a', patterns: ['lib/a/']),
        _ticket('T1', ['docs/one.md']),
      ];
      final before = summarizeProjectPathDeclaration(
        rawNodes: nodes,
        nonDomain: _absent,
      );
      final after = summarizeProjectPathDeclaration(
        rawNodes: nodes,
        nonDomain: _declared,
      );

      expect(before.affectedPathCount, 1);
      expect(after.affectedPathCount, 0);
    });
  });
}
