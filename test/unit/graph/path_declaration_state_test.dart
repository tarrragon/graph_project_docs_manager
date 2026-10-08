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
      expect(r.paths.single.domain, 'graph');
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
      expect(_run(b, nd, files).isLocatable, isTrue);
      expect(_run(b, nd, ['src/x.dart']).isLocatable, isFalse);
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
      expect(r.paths.single.domain, 'graph');
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
      final r = _run(both, nd, ['lib/graph/::read']);
      expect(r.paths.single.path, 'lib/graph/');
      expect(r.paths.single.domain, 'graph');
    });
    test('N2 裸目錄補 /；有副檔名者不補', () {
      expect(_run(both, nd, ['lib/graph']).paths.single.domain, 'graph');
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
