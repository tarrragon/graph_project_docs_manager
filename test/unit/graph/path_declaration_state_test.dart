import 'package:flutter_test/flutter_test.dart';
import 'package:graph_project_docs_manager/corpus/non_domain_paths_reader.dart';
import 'package:graph_project_docs_manager/graph/path_declaration_state.dart';

import '../../helpers/spec001/path_declaration_builder.dart';

PathDeclarationReport _run(
  Map<String, List<String>?> bundles,
  NonDomainPathsReadResult nonDomain,
  List<String> files,
) => classifyTicketPaths(
  bundlePathPatterns: bundles,
  nonDomain: nonDomain,
  whereFiles: files,
);

PathLocationState _one(
  Map<String, List<String>?> bundles,
  NonDomainPathsReadResult nonDomain,
  String file,
) => _run(bundles, nonDomain, [file]).paths.single.state;

void main() {
  final both = buildBundlePathPatterns(
    declared: {
      'graph': ['lib/graph/'],
    },
  );
  final nd = nonDomainDeclared(['docs/']);

  group('P1 五種狀態', () {
    test('P1-1 命中 domain', () {
      final r = _run(both, nd, ['lib/graph/a.dart']);
      expect(r.paths.single.state, PathLocationState.domainHit);
      expect(r.paths.single.domains, ['graph']);
    });
    test('P1-2 非 domain 層', () {
      expect(_one(both, nd, 'docs/a.md'), PathLocationState.nonDomainLayer);
    });
    test('P1-3 無法定位', () {
      final r = _run(both, nd, ['src/a.dart']);
      expect(r.paths.single.state, PathLocationState.unlocatable);
      expect(r.unlocatableCount, 1);
    });
    test('P1-4 只有 path_patterns', () {
      final r = _run(both, nonDomainAbsent(), ['src/a.dart']);
      expect(r.paths.single.state, PathLocationState.nonDomainUndeclared);
      expect(r.unlocatableCount, 0);
    });
    test('P1-5 只有非 domain 清單', () {
      final b = buildBundlePathPatterns(absent: ['graph']);
      expect(_one(b, nd, 'src/a.dart'), PathLocationState.domainUndeclared);
    });
    test('P1-6 兩者皆無：整體未宣告', () {
      final b = buildBundlePathPatterns(absent: ['graph']);
      final r = _run(b, nonDomainAbsent(), ['lib/graph/a.dart']);
      expect(r.overallUndeclared, isTrue);
      expect(r.paths, isEmpty);
      expect(r.affectedPathCount, isNull);
    });
    test('P1-7 格式錯誤視為缺席，但宣告狀態可區分', () {
      final bad = _run(both, nonDomainMalformed(), ['src/a.dart']);
      final absent = _run(both, nonDomainAbsent(), ['src/a.dart']);
      expect(bad.paths.single.state, absent.paths.single.state);
      expect(bad.paths.single.state, PathLocationState.nonDomainUndeclared);
      expect(bad.nonDomainSide, NonDomainSideState.malformed);
      expect(absent.nonDomainSide, NonDomainSideState.absent);
      expect(
        _run(both, nd, ['src/a.dart']).nonDomainSide,
        NonDomainSideState.declared,
      );
    });
  });

  group('P2 部分宣告', () {
    Map<String, List<String>?> eight(List<String>? last) => {
      for (var i = 1; i <= 7; i++) 'd$i': ['lib/d$i/'],
      'd8': last,
    };

    test('P2-1 7/8 宣告：domain 未宣告', () {
      expect(
        _one(eight(null), nd, 'src/a.dart'),
        PathLocationState.domainUndeclared,
      );
    });
    test('P2-2 補 [] 後為無法定位，與 P2-1 不同', () {
      expect(_one(eight([]), nd, 'src/a.dart'), PathLocationState.unlocatable);
    });
    test('P2-3 缺席與 P2-1 同、與 P2-2 不同', () {
      final s = _one(eight(null), nd, 'src/a.dart');
      expect(s, PathLocationState.domainUndeclared);
      expect(s, isNot(_one(eight([]), nd, 'src/a.dart')));
    });
    test('P2-4 非 domain 缺席且部分宣告：domain 未宣告', () {
      expect(
        _one(eight(null), nonDomainAbsent(), 'src/a.dart'),
        PathLocationState.domainUndeclared,
      );
    });
  });

  group('P3 逐路徑與聚合', () {
    final b = buildBundlePathPatterns(
      declared: {
        'graph': ['lib/graph/'],
      },
      absent: ['other'],
    );
    final files = ['lib/graph/a.dart', 'docs/a.md', 'src/x.dart'];
    test('P3-1 逐路徑各自狀態', () {
      final r = _run(b, nd, files);
      expect(r.paths.map((p) => p.state), [
        PathLocationState.domainHit,
        PathLocationState.nonDomainLayer,
        PathLocationState.domainUndeclared,
      ]);
    });
    test('P3-2 高亮聯集', () {
      expect(_run(b, nd, files).highlightedDomains, {'graph'});
    });
    test('P3-3 任一命中即可定位；全未命中不可', () {
      expect(_run(b, nd, files).locatability, TicketLocatability.locatable);
      expect(
        _run(b, nd, ['src/x.dart']).locatability,
        TicketLocatability.notLocatable,
      );
    });
    test('P3-4 受影響路徑數 = 未宣告路徑數', () {
      expect(_run(b, nd, files).affectedPathCount, 1);
      expect(_run(b, nd, [...files, 'src/y.dart']).affectedPathCount, 2);
      expect(_run(both, nd, files).affectedPathCount, 0);
    });
    test('P3-5 flutter_balance 形態：兩側皆無為整體未宣告', () {
      final r = _run(
        buildBundlePathPatterns(absent: ['a', 'b']),
        nonDomainAbsent(),
        files,
      );
      expect(r.overallUndeclared, isTrue);
    });
  });

  group('X1、零 bundle、摘要不判定', () {
    test('X1 等長跨 bundle 全歸入，與插入順序無關，受影響路徑數仍為 1', () {
      final a = {
        'beta': <String>['docs/x/'],
        'alpha': <String>['docs/x/'],
      };
      final b = {
        'alpha': <String>['docs/x/'],
        'beta': <String>['docs/x/'],
      };
      final ra = _run(a, nd, ['docs/x/a.md']);
      final rb = _run(b, nd, ['docs/x/a.md']);
      expect(ra.paths.single.domains, ['alpha', 'beta']);
      expect(rb.paths.single.domains, ['alpha', 'beta']);
      expect(ra.highlightedDomains, {'alpha', 'beta'});
      expect(ra.paths, hasLength(1));
    });
    test('X1 多路徑：受影響路徑數以路徑計，高亮為聯集', () {
      final b = <String, List<String>?>{
        'alpha': ['docs/x/'],
        'beta': ['docs/x/'],
        'graph': ['lib/graph/'],
        'other': null,
      };
      final r = _run(b, nd, ['docs/x/a.md', 'lib/graph/a.dart', 'src/x.dart']);
      expect(r.paths, hasLength(3));
      expect(r.paths.first.domains, ['alpha', 'beta']);
      expect(r.affectedPathCount, 1);
      expect(r.highlightedDomains, {'alpha', 'beta', 'graph'});
    });
    test('K2 where.files 為空且非整體未宣告：undetermined，與 notLocatable 不同', () {
      final empty = _run(both, nd, []);
      expect(empty.overallUndeclared, isFalse);
      expect(empty.locatability, TicketLocatability.undetermined);
      final oneSide = _run(both, nonDomainAbsent(), []);
      expect(oneSide.locatability, TicketLocatability.undetermined);
      final withPath = _run(both, nd, ['src/x.dart']);
      expect(withPath.locatability, TicketLocatability.notLocatable);
    });
    test('零 bundle 有非 domain 清單：未命中為 domain 未宣告，非無法定位', () {
      expect(
        _one(<String, List<String>?>{}, nd, 'src/a.dart'),
        PathLocationState.domainUndeclared,
      );
      expect(
        _one(<String, List<String>?>{}, nd, 'docs/a.md'),
        PathLocationState.nonDomainLayer,
      );
    });
    test('零 bundle 且非 domain 缺席：整體未宣告', () {
      expect(
        _run(<String, List<String>?>{}, nonDomainAbsent(), [
          'a.dart',
        ]).overallUndeclared,
        isTrue,
      );
    });
    test('兩側皆無的摘要為 undetermined，與 notLocatable 不同', () {
      final none = _run(
        buildBundlePathPatterns(absent: ['a']),
        nonDomainAbsent(),
        ['x.dart'],
      );
      expect(none.locatability, TicketLocatability.undetermined);
      expect(none.locatability, isNot(TicketLocatability.notLocatable));
      expect(
        _run(both, nd, ['src/x.dart']).locatability,
        TicketLocatability.notLocatable,
      );
    });
  });

  group('跨 bundle 最長前綴與守衛鑑別力', () {
    test('最長前綴跨 bundle：lib/graph/ 勝過 lib/，與插入順序無關', () {
      final a = {
        'core': <String>['lib/'],
        'graph': <String>['lib/graph/'],
      };
      final b = {
        'graph': <String>['lib/graph/'],
        'core': <String>['lib/'],
      };
      expect(_run(a, nd, ['lib/graph/a.dart']).paths.single.domains, ['graph']);
      expect(_run(b, nd, ['lib/graph/a.dart']).paths.single.domains, ['graph']);
      expect(_run(a, nd, ['lib/x.dart']).paths.single.domains, ['core']);
    });
    test('守衛：/docs/ 宣告不命中字面上會命中的 /docs/a.md', () {
      expect(
        _one(both, nonDomainDeclared(['/docs/']), '/docs/a.md'),
        PathLocationState.unlocatable,
      );
    });
    test('守衛：./docs/、.. 段、glob 宣告不命中字面上會命中的路徑', () {
      expect(
        _one(both, nonDomainDeclared(['./docs/']), './docs/a.md'),
        PathLocationState.unlocatable,
      );
      expect(
        _one(both, nonDomainDeclared(['docs/../lib/']), 'docs/../lib/a.dart'),
        PathLocationState.unlocatable,
      );
      expect(
        _one(both, nonDomainDeclared(['docs/*.md']), 'docs/*.md'),
        PathLocationState.unlocatable,
      );
    });
    for (final c in ['?', '[', ']', '{', '}']) {
      test('守衛：含 glob 字元 $c 的宣告不命中字面上會命中的路徑', () {
        final pattern = 'docs/a${c}b/';
        expect(
          _one(both, nonDomainDeclared([pattern]), '${pattern}x.md'),
          PathLocationState.unlocatable,
        );
      });
    }
    test('FR-10 規則 2a：含非字串元素仍為 declared', () {
      final r = _run(
        both,
        NonDomainPathsReadDeclaredWithBadElements(
          path: 'docs/non-domain-paths.yaml',
          patterns: ['docs/'],
          nonStringElementCount: 1,
        ),
        ['docs/a.md'],
      );
      expect(r.nonDomainSide, NonDomainSideState.declared);
      expect(r.paths.single.state, PathLocationState.nonDomainLayer);
    });
  });

  group('比對語意', () {
    test('P4-1 空字串不命中；對照 lib/ 命中', () {
      final empty = buildBundlePathPatterns(
        declared: {
          'graph': [''],
        },
      );
      final ok = buildBundlePathPatterns(
        declared: {
          'graph': ['lib/'],
        },
      );
      expect(_one(empty, nd, 'lib/a.dart'), PathLocationState.unlocatable);
      expect(_one(ok, nd, 'lib/a.dart'), PathLocationState.domainHit);
    });
    test('P4-2 非 domain 側空字串不命中，其餘元素生效', () {
      final n = nonDomainDeclared(['', 'docs/a/']);
      expect(_one(both, n, 'src/b.dart'), PathLocationState.unlocatable);
      expect(_one(both, n, 'docs/a/x.md'), PathLocationState.nonDomainLayer);
    });
    test('P4-3 /docs/ 不命中；對照 docs/ 命中', () {
      expect(
        _one(both, nonDomainDeclared(['/docs/']), 'docs/a.md'),
        PathLocationState.unlocatable,
      );
      expect(
        _one(both, nonDomainDeclared(['docs/']), 'docs/a.md'),
        PathLocationState.nonDomainLayer,
      );
    });
    test('P4-4 無尾斜線為精確比對', () {
      final b = buildBundlePathPatterns(
        declared: {
          'graph': ['lib/a.dart'],
        },
      );
      expect(_one(b, nd, 'lib/a.dart'), PathLocationState.domainHit);
      expect(_one(b, nd, 'lib/a.dart.bak'), PathLocationState.unlocatable);
      expect(_one(b, nd, 'lib/a.dartx'), PathLocationState.unlocatable);
    });
    test('P4-5 其餘格式違規值不命中', () {
      final n = nonDomainDeclared(['./docs/', 'docs/../lib/', 'docs/*.md']);
      expect(_one(both, n, 'docs/a.md'), PathLocationState.unlocatable);
      expect(_one(both, n, 'lib/a.dart'), PathLocationState.unlocatable);
    });
    test('P4-6 同字串兩側皆有歸 domain，不回報衝突', () {
      final b = buildBundlePathPatterns(
        declared: {
          'graph': ['docs/x/'],
        },
      );
      final r = _run(b, nonDomainDeclared(['docs/x/']), ['docs/x/a.md']);
      expect(r.paths.single.state, PathLocationState.domainHit);
      expect(r.paths.single.domains, ['graph']);
    });
    test('P4-7 較長的非 domain 前綴勝出', () {
      final b = buildBundlePathPatterns(
        declared: {
          'graph': ['docs/x/'],
        },
      );
      expect(
        _one(b, nonDomainDeclared(['docs/x/y/']), 'docs/x/y/a.md'),
        PathLocationState.nonDomainLayer,
      );
    });
    test('P4-8 只有非 domain 含 docs/x/ 歸非 domain', () {
      expect(
        _one(both, nonDomainDeclared(['docs/x/']), 'docs/x/a.md'),
        PathLocationState.nonDomainLayer,
      );
    });
  });

  group('正規化與無預設推測', () {
    test('N1 ::read 後綴截除後歸 graph', () {
      final r = _run(both, nd, ['lib/graph::read']);
      expect(r.paths.single.path, 'lib/graph/');
      expect(r.paths.single.domains, ['graph']);
    });
    test('N2 裸目錄補 /；有副檔名者不補', () {
      expect(_run(both, nd, ['lib/graph']).paths.single.domains, ['graph']);
      expect(normalizeWhereFilesPath('lib/graph.dart'), 'lib/graph.dart');
      expect(_one(both, nd, 'lib/graph.dart'), PathLocationState.unlocatable);
    });
    test('N3 宣告值不補 /', () {
      final b = buildBundlePathPatterns(
        declared: {
          'graph': ['lib/graph'],
        },
      );
      expect(_one(b, nd, 'lib/graph/a.dart'), PathLocationState.unlocatable);
      expect(_one(b, nd, 'lib/graph'), PathLocationState.unlocatable);
    });
    test('D1 無 lib/<domain>/ 預設推測；對照宣告後命中', () {
      final none = buildBundlePathPatterns(
        declared: {
          'graph': ['src/'],
        },
      );
      expect(_one(none, nd, 'lib/graph/a.dart'), PathLocationState.unlocatable);
      expect(_one(both, nd, 'lib/graph/a.dart'), PathLocationState.domainHit);
    });
    test('E1 宣告缺席與顯式空清單可區分', () {
      final empty = buildBundlePathPatterns(declared: {'graph': []});
      final absent = buildBundlePathPatterns(absent: ['graph']);
      expect(_one(empty, nd, 'src/a.dart'), PathLocationState.unlocatable);
      expect(
        _one(absent, nd, 'src/a.dart'),
        PathLocationState.domainUndeclared,
      );
    });
  });
}
